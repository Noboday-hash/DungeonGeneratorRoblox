local ServerScriptService = game:GetService("ServerScriptService")
local DungeonGenerator = require(ServerScriptService:WaitForChild("DungeonGenerator"))
local startingRoom = workspace:WaitForChild("Room")


DungeonGenerator.Start(startingRoom)