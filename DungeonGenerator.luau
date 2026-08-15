-- Discord: @noboday | Roblox: NbdayDev | GitHub: Noboday-hash

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RoomTemplate: Model = ReplicatedStorage:WaitForChild("Room") :: Model
local DecorFolder: Folder = ReplicatedStorage:WaitForChild("Decorations") :: Folder

local CONFIG = {
	DecorLimit = 6,
	MaxTries = 10,
	Shrink = 0.8,
	UseSeed = false,
	Seed = 1337,
	DebugVisuals = false,
	MinDecorSize = Vector3.new(0.5, 0.5, 0.5),
}

local rng = Random.new(CONFIG.UseSeed and CONFIG.Seed or tick())

local decorCategories: {[string]: {Model}} = {}

for _, item in ipairs(DecorFolder:GetChildren()) do
	if item:IsA("Model") then
		local cat = item:GetAttribute("Category") or "General"

		decorCategories[cat] = decorCategories[cat] or {}
		table.insert(decorCategories[cat], item)
	end
end

-- grab a themed pool or just yeet everything together as fallback
local function getDecorPool(category: string?): {Model}
	if category and decorCategories[category] and #decorCategories[category] > 0 then
		return decorCategories[category]
	end

	local all: {Model} = {}

	for _, pool in pairs(decorCategories) do
		for _, m in ipairs(pool) do
			table.insert(all, m)
		end
	end

	return all
end

-- skip tiny or broken templates before we waste time cloning them
local function validateTemplate(template: Model): boolean
	local _, size = template:GetBoundingBox()

	if size.X < CONFIG.MinDecorSize.X or size.Y < CONFIG.MinDecorSize.Y or size.Z < CONFIG.MinDecorSize.Z then
		return false
	end

	return true
end

-- debug overlay so i can see where the overlap box landed green = good
local function drawDebugBox(parent: Instance, cframe: CFrame, size: Vector3, color: Color3)
	if not CONFIG.DebugVisuals then
		return
	end

	local box = Instance.new("BoxHandleAdornment")

	box.Adornee = workspace.Terrain
	box.CFrame = cframe
	box.Size = size
	box.Color3 = color
	box.Transparency = 0.5
	box.AlwaysOnTop = true
	box.ZIndex = 5
	box.Parent = parent

	task.delay(5, function()
		box:Destroy()
	end)
end

-- slaps props onto DecorSpawn pads shuffles pads so its not always the same ones
-- drops 0-2 items per pad bails when we hit the limit
-- each prop gets a random spin and collision checked so nothing clips
local function addDecor(room: Model)
	if not room or not room:IsA("Model") then
		return
	end

	local spawns: {BasePart} = {}

	for _, thing in ipairs(room:GetDescendants()) do
		if thing:IsA("BasePart") and thing.Name == "DecorSpawn" then
			table.insert(spawns, thing)
		end
	end

	if #spawns == 0 then
		return
	end

	-- shuffle cuz i dont want the same 3 pads every time
	for i = #spawns, 2, -1 do
		local j = rng:NextInteger(1, i)

		spawns[i], spawns[j] = spawns[j], spawns[i]
	end

	local placed = 0

	for _, spot in ipairs(spawns) do
		if placed >= CONFIG.DecorLimit then
			break
		end

		local category = spot:GetAttribute("DecorCategory")
		local options = getDecorPool(category)

		if #options == 0 then
			continue
		end

		local count = rng:NextInteger(0, 2)

		for _ = 1, count do
			if placed >= CONFIG.DecorLimit then
				break
			end

			local template = options[rng:NextInteger(1, #options)]

			if not validateTemplate(template) then
				continue
			end

			local success = false

			-- brute force random positions until one works or we run out of tries
			for _ = 1, CONFIG.MaxTries do
				local clone = template:Clone()

				for _, part in ipairs(clone:GetDescendants()) do
					if part:IsA("BasePart") then
						part.Anchored = true
						part.CanCollide = true
					end
				end

				-- random point inside the pad pulled inward so we dont hug walls
				local x = (rng:NextNumber()-0.5) * spot.Size.X * CONFIG.Shrink
				local z = (rng:NextNumber()-0.5) * spot.Size.Z * CONFIG.Shrink

				local top = spot.Position + spot.CFrame.UpVector * (spot.Size.Y / 2)
				local pos = top + spot.CFrame.RightVector * x + spot.CFrame.LookVector * z

				-- align bottom of the prop with the pad surface
				local box, size = clone:GetBoundingBox()
				local pivot = clone:GetPivot()

				local floorY = box.Position.Y - size.Y / 2
				local drop = pivot.Position.Y - floorY

				local spin = math.rad(rng:NextInteger(0, 359))
				local target = CFrame.new(pos + spot.CFrame.UpVector * drop) * CFrame.Angles(0, spin, 0)

				-- pivot might not match bounding box center so we offset the check
				local offset = pivot:ToObjectSpace(box)
				local checkBox = target * offset

				drawDebugBox(clone, checkBox, size, Color3.fromRGB(0, 255, 0))

				-- collision chec make sure we aint clipping into existing stuff
				local filter = OverlapParams.new()

				filter.FilterType = Enum.RaycastFilterType.Exclude
				filter.FilterDescendantsInstances = {clone}

				local clear = true

				for _, part in ipairs(workspace:GetPartBoundsInBox(checkBox, size, filter)) do
					if not part:IsDescendantOf(clone) and part.CanCollide then
						clear = false

						break
					end
				end

				if clear then
					clone:PivotTo(target)
					clone.Parent = spot.Parent

					success = true

					break
				end

				clone:Destroy()
			end

			if success then
				placed += 1
			end
		end
	end

	-- hide the spawn pads
	for _, spot in ipairs(spawns) do
		spot.Transparency = 1
		spot.CanCollide = false
	end
end

-- -----------------------------------------------------------------------------

local DungeonGenerator = {}

local initialized: {[Model]: boolean} = {}
local occupants: {[Model]: {[Player]: boolean}} = {}
local generated: {[Model]: boolean} = {}
local occupiedSpawns: {[BasePart]: boolean} = {}

-- checks if a RoomSpawn is blocked by an existing RoomDetector
-- if clear clones the room template and sets it up
local function spawnRoomAt(spawnPoint: BasePart)
	if occupiedSpawns[spawnPoint] then
		return
	end

	local check = OverlapParams.new()

	check.FilterType = Enum.RaycastFilterType.Exclude
	check.FilterDescendantsInstances = {spawnPoint}

	local blocked = false

	for _, part in ipairs(workspace:GetPartsInPart(spawnPoint, check)) do
		if part.Name == "RoomDetector" then
			blocked = true

			break
		end
	end

	if blocked then
		occupiedSpawns[spawnPoint] = true

		return
	end

	occupiedSpawns[spawnPoint] = true

	local newRoom = RoomTemplate:Clone()

	newRoom.Parent = workspace
	newRoom:PivotTo(spawnPoint.CFrame)

	DungeonGenerator.SetupRoom(newRoom)
	addDecor(newRoom)
end

-- hooks up the room detector and tracks players
-- initialized guard prevents if called again by accident
function DungeonGenerator.SetupRoom(currentRoom: Model)
	if initialized[currentRoom] then
		return
	end

	local detector = currentRoom:FindFirstChild("RoomDetector", true)

	if not detector or not detector:IsA("BasePart") then
		return
	end

	initialized[currentRoom] = true
	occupants[currentRoom] = {}
	generated[currentRoom] = false

	detector.Touched:Connect(function(hit: BasePart)
		if not hit or not hit.Parent then
			return
		end

		local player = Players:GetPlayerFromCharacter(hit.Parent)

		if not player then
			return
		end

		local roomPlayers = occupants[currentRoom]

		if not roomPlayers then
			return
		end

		roomPlayers[player] = true

		if generated[currentRoom] then
			return
		end

		generated[currentRoom] = true

		for _, object in ipairs(currentRoom:GetDescendants()) do
			if object:IsA("BasePart") and object.Name == "RoomSpawn" then
				spawnRoomAt(object)
			end
		end
	end)

	detector.TouchEnded:Connect(function(hit: BasePart)
		if not hit or not hit.Parent then
			return
		end

		local player = Players:GetPlayerFromCharacter(hit.Parent)

		if not player then
			return
		end

		local roomPlayers = occupants[currentRoom]

		if not roomPlayers then
			return
		end

		roomPlayers[player] = nil

		if not next(roomPlayers) then
			occupants[currentRoom] = nil
		end
	end)
end

-- fire once to start dungeon generation
function DungeonGenerator.Start(startingRoom: Model)
	if not startingRoom or not startingRoom:IsA("Model") then
		error("DungeonGenerator.Start requires a Model.")
	end

	DungeonGenerator.SetupRoom(startingRoom)

	if generated[startingRoom] then
		addDecor(startingRoom)

		return
	end

	generated[startingRoom] = true

	for _, object in ipairs(startingRoom:GetDescendants()) do
		if object:IsA("BasePart") and object.Name == "RoomSpawn" then
			spawnRoomAt(object)
		end
	end

	addDecor(startingRoom)
end

return DungeonGenerator