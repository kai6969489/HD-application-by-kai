local Players = game:GetService("Players")
local player = Players.LocalPlayer
local moneyText: TextLabel = player.PlayerGui:WaitForChild("Money").Frame.TextLabel

local Money = {}

function Money.Init()
	moneyText.Text = player.Money.Value
	player.Money.Changed:Connect(function()
		moneyText.Text = player.Money.Value
	end)
	
end

return Money
