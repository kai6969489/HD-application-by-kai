--// Services
local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

--//Systems
local PlotManager = require(ServerScriptService.SystemsServer.BuildingSystem.PlotManager)
local Purchase = require(ServerScriptService.SystemsServer.ShopSystem.Purchase)
local Inventory = require(ServerScriptService.SystemsServer.InventorySystem.InventoryServer)

--// Packages
local Packets = require(ReplicatedStorage.Shared.Packages.Packets)

-- signals 

local function OnPlayerAdded(plr : Player)
	local money = Instance.new("IntValue")
	money.Value = 10000
	money.Name = "Money"
	money.Parent = plr
	
	plr:SetAttribute("Launched" , false)
end

Packets.tryPurchase.OnServerEvent:Connect(Purchase.Validate)

Players.PlayerAdded:Connect(OnPlayerAdded)
PlotManager.Init()
Inventory.Init()