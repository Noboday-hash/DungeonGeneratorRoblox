local turn = false

game.UserInputService.InputBegan:Connect(function(inp, cht)
	if inp.KeyCode == Enum.KeyCode.K then
		for _, item in pairs(game.Workspace:GetDescendants()) do
			if item.Name == "Roof" then
				if turn == false then
					item.Transparency = 0.9
				elseif turn == true then
					item.Transparency = 0
				end
			end
		end
	end
	
	turn = not turn
end)