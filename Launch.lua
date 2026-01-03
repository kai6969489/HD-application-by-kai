local Players = game:GetService("Players")
local player = Players.LocalPlayer
local launchButton : TextButton = player.PlayerGui.LaunchButton.Launch
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Packets = require(ReplicatedStorage.Shared.Packages.Packets)
local buildModeClient = require(ReplicatedStorage.SystemsClient.BuildingSystem.BuildModeClient)
local LaunchSystem = {}

function LaunchSystem.Init()
	local con = launchButton.MouseButton1Click:Connect(LaunchSystem.Launch)
	
	Players.PlayerRemoving:Connect(function()
		con:Disconnect()
	end)
	
end

function LaunchSystem.Launch()
	Packets.launch:Fire()
end

return LaunchSystem
