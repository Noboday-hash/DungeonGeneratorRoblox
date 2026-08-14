local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RoomTemplate: Model = ReplicatedStorage:WaitForChild("Room") :: Model
local DecorPlacer = require(script:WaitForChild("DecorationPlacer"))

local DungeonGenerator = {}

local initialized: {[Model]: boolean} = {}
local occupants: {[Model]: {[Player]: boolean}} = {}
local generated: {[Model]: boolean} = {}
local occupiedSpawns: {[BasePart]: boolean} = {}

function DungeonGenerator.SetupRoom(currentRoom: Model): ()
	if initialized[currentRoom] then
		return
	end

	local detector: BasePart? = currentRoom:FindFirstChild("RoomDetector", true) :: BasePart?
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

		local player: Player? = Players:GetPlayerFromCharacter(hit.Parent)
		if not player then
			return
		end

		local roomPlayers: {[Player]: boolean}? = occupants[currentRoom]
		if not roomPlayers then
			return
		end
		roomPlayers[player] = true

		if generated[currentRoom] then
			return
		end
		generated[currentRoom] = true

		for _, object: Instance in ipairs(currentRoom:GetDescendants()) do
			if not object:IsA("BasePart") or object.Name ~= "RoomSpawn" then
				continue
			end

			local spawnPoint: BasePart = object :: BasePart
			if occupiedSpawns[spawnPoint] then
				continue
			end

			local check = OverlapParams.new()
			check.FilterType = Enum.RaycastFilterType.Exclude
			check.FilterDescendantsInstances = {spawnPoint}

			local blocked: boolean = false
			for _, part: BasePart in ipairs(workspace:GetPartsInPart(spawnPoint, check)) do
				if part.Name == "RoomDetector" then
					blocked = true
					break
				end
			end

			if blocked then
				occupiedSpawns[spawnPoint] = true
				continue
			end

			occupiedSpawns[spawnPoint] = true

			local spawnedRoom: Model = RoomTemplate:Clone() :: Model
			spawnedRoom.Parent = workspace
			spawnedRoom:PivotTo(spawnPoint.CFrame)

			DungeonGenerator.SetupRoom(spawnedRoom)
			DecorPlacer.AddDecor(spawnedRoom)
		end
	end)

	detector.TouchEnded:Connect(function(hit: BasePart)
		if not hit or not hit.Parent then
			return
		end

		local player: Player? = Players:GetPlayerFromCharacter(hit.Parent)
		if not player then
			return
		end

		local roomPlayers: {[Player]: boolean}? = occupants[currentRoom]
		if not roomPlayers then
			return
		end

		roomPlayers[player] = nil
		if not next(roomPlayers) then
			occupants[currentRoom] = nil
		end
	end)
end

function DungeonGenerator.Start(startingRoom: Model): ()
	if not startingRoom or not startingRoom:IsA("Model") then
		error("DungeonGenerator.Start requires a Model.")
	end

	DungeonGenerator.SetupRoom(startingRoom)

	if generated[startingRoom] then
		DecorPlacer.AddDecor(startingRoom)
		return
	end
	generated[startingRoom] = true

	for _, object: Instance in ipairs(startingRoom:GetDescendants()) do
		if not object:IsA("BasePart") or object.Name ~= "RoomSpawn" then
			continue
		end

		local spawnPoint: BasePart = object :: BasePart
		if occupiedSpawns[spawnPoint] then
			continue
		end

		local check = OverlapParams.new()
		check.FilterType = Enum.RaycastFilterType.Exclude
		check.FilterDescendantsInstances = {spawnPoint}

		local blocked: boolean = false
		for _, part: BasePart in ipairs(workspace:GetPartsInPart(spawnPoint, check)) do
			if part.Name == "RoomDetector" then
				blocked = true
				break
			end
		end

		if blocked then
			occupiedSpawns[spawnPoint] = true
			continue
		end

		occupiedSpawns[spawnPoint] = true

		local spawnedRoom: Model = RoomTemplate:Clone() :: Model
		spawnedRoom.Parent = workspace
		spawnedRoom:PivotTo(spawnPoint.CFrame)

		DungeonGenerator.SetupRoom(spawnedRoom)
		DecorPlacer.AddDecor(spawnedRoom)
	end

	DecorPlacer.AddDecor(startingRoom)
end

return DungeonGenerator