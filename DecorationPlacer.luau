local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DecorationPlacer = {}

local decorFolder: Folder = ReplicatedStorage:WaitForChild("Decorations") :: Folder
local rng = Random.new()

local decorLimit: number = 6
local maxTries: number = 10
local shrink: number = 0.8

function DecorationPlacer.AddDecor(room: Model): ()
	if not room or not room:IsA("Model") then
		return
	end

	local spawns: {BasePart} = {}
	for _, thing: Instance in ipairs(room:GetDescendants()) do
		if thing:IsA("BasePart") and thing.Name == "DecorSpawn" then
			table.insert(spawns, thing :: BasePart)
		end
	end

	local options: {Model} = {}
	for _, thing: Instance in ipairs(decorFolder:GetChildren()) do
		if thing:IsA("Model") then
			table.insert(options, thing :: Model)
		end
	end

	if #spawns == 0 or #options == 0 then
		return
	end

	for i: number = #spawns, 2, -1 do
		local j: number = rng:NextInteger(1, i)
		spawns[i], spawns[j] = spawns[j], spawns[i]
	end

	local placed: number = 0

	for _, spot: BasePart in ipairs(spawns) do
		if placed >= decorLimit then
			break
		end

		local count: number = rng:NextInteger(0, 2)
		for _: number = 1, count do
			if placed >= decorLimit then
				break
			end

			local template: Model = options[rng:NextInteger(1, #options)]
			local success: boolean = false

			for _: number = 1, maxTries do
				local clone: Model = template:Clone() :: Model
				for _, part: Instance in ipairs(clone:GetDescendants()) do
					if part:IsA("BasePart") then
						local basePart: BasePart = part :: BasePart
						basePart.Anchored = true
						basePart.CanCollide = true
					end
				end

				local x: number = (rng:NextNumber() - 0.5) * spot.Size.X * shrink
				local z: number = (rng:NextNumber() - 0.5) * spot.Size.Z * shrink
				local top: Vector3 = spot.Position + spot.CFrame.UpVector * (spot.Size.Y / 2)
				local pos: Vector3 = top + spot.CFrame.RightVector * x + spot.CFrame.LookVector * z

				local box: CFrame, size: Vector3 = clone:GetBoundingBox()
				local pivot: CFrame = clone:GetPivot()
				local floorY: number = box.Position.Y - size.Y / 2
				local drop: number = pivot.Position.Y - floorY

				local spin: number = math.rad(rng:NextInteger(0, 359))
				local target: CFrame = CFrame.new(pos + spot.CFrame.UpVector * drop) * CFrame.Angles(0, spin, 0)

				local offset: CFrame = pivot:ToObjectSpace(box)
				local checkBox: CFrame = target * offset

				local filter = OverlapParams.new()
				filter.FilterType = Enum.RaycastFilterType.Exclude
				filter.FilterDescendantsInstances = {clone}

				local clear: boolean = true
				for _, part: BasePart in ipairs(workspace:GetPartBoundsInBox(checkBox, size, filter)) do
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

	for _, spot: BasePart in ipairs(spawns) do
		spot.Transparency = 1
		spot.CanCollide = false
	end
end

return DecorationPlacer