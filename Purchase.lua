local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local Data = require(script.Parent.Parent.Configuration.Data)
local Inventory = require(script.Parent.Parent.InventorySystem.InventoryServer)
local objTemplates : Folder = ReplicatedStorage.Shared.ObjectTemplates

local Purchase = {}

function Purchase.Validate(player : Player , objectName : string) : boolean

	if not Data.GetObjectData(objectName) or not Players:GetPlayerByUserId(player.UserId) or not objTemplates[objectName] then
		return
	end
	
	local money : IntValue = player:FindFirstChild("Money")
	local object = objTemplates[objectName]  
	local price = Data.GetObjectData(objectName).Price
	
	if money.Value >= price then
		money.Value -= price
		Inventory.RegisterObject(player , object)
		return true
	else
		return false
	end
end

return Purchase
