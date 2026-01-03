local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local Data = require(script.Parent.Parent.Configuration.Data)
local Types = require(ReplicatedStorage.Shared.Types)
local Janitor = require(ReplicatedStorage.Shared.Packages.Janitor)
local Packets = require(ReplicatedStorage.Shared.Packages.Packets)
local HTTPSERVICE = game:GetService("HttpService")
local DataStoreService = game:GetService("DataStoreService")
local InventoryDataStore = DataStoreService:GetDataStore("InventoryDataStore")

local InventoryServer = {}

InventoryServer.AllInventories = {}
InventoryServer.Janitors = {}
InventoryServer.HasLoaded = {}

function InventoryServer.Init()
	
	Players.PlayerAdded:Connect(InventoryServer.OnPlayerAdded)
	Players.PlayerRemoving:Connect(InventoryServer.OnPlayerRemoving)
end

function InventoryServer.OnPlayerAdded(player : Player)
	-- creates new janitor
	local newJanitor = Janitor.new()
	InventoryServer.Janitors[player.UserId] = newJanitor
	
	-- creates new inventory
	local newInventory : Types.inventory = {
		Inventory = {},	
	}
	InventoryServer.AllInventories[player.UserId] = newInventory
	InventoryServer.LoadData(player)
	Packets.updateInventoryData.OnServerInvoke = InventoryServer.GetInventory(player)
	-- cleanup
	newJanitor:Add(function()
		InventoryServer.AllInventories[player.UserId] = nil
		InventoryServer.Janitors[player.UserId] = nil
	end, true)
end


function InventoryServer.OnPlayerRemoving(player : Player)
	InventoryServer.SaveData(player)
	InventoryServer.Janitors[player.UserId]:Cleanup()
end

-- registers new objects to player inventory
function InventoryServer.RegisterObject(player : Player , object)
	if not Data.GetObjectData(object.Name) or not InventoryServer.AllInventories[player.UserId] then
		warn("Error: Invalid object or player")
		return 
	end
	
	local inventory : Types.inventory = InventoryServer.AllInventories[player.UserId]
	
	-- check if there is a stack for the item
	local foundStack = nil
	
	for _ , stack in inventory.Inventory do
		if stack.Name == object.Name then
			stack.Amount += 1 
			foundStack = stack
			break
		end
	end
	
	if not foundStack then
		
		local newStack : Types.stack = {
			
			Name = object.Name,
			Amount = 1,
			Image = "rbxassetid://" .. Data.GetObjectData(object.Name).ImageID,
		}
		
		table.insert(inventory.Inventory , newStack)
	end
	Packets.updateInventory:FireClient(player , inventory)
end

function InventoryServer.UnregisterObject(player : Player , object)
	
	if not Data.GetObjectData(object.Name) or not Players:GetPlayerByUserId(player.UserId) then
		return 
	end
	
	local inventory : Types.inventory = InventoryServer.AllInventories[player.UserId]
	
	local foundStack = nil
	
	for _ , stack in inventory.Inventory do
		if stack.Name  == object.Name then
			foundStack = stack
			break
		end
	end
	
	if not foundStack or foundStack.Amount == 0 then 
		return
	end
	
	foundStack.Amount -= 1
	Packets.updateInventory:FireClient(player , inventory)
end

function InventoryServer.SaveData(player : Player , plot)
	
	if not InventoryServer.HasLoaded[player.UserId]then 
		return
	end
	
	local plot = game.Workspace.Plots:FindFirstChild(player.Name.. "'s Plot")
	
	if not plot then
		warn("No plot found")
		return
	end
	
	for _ , object in plot.Objects:GetChildren() do
		if object:IsA("Model") then
			InventoryServer.RegisterObject(player , object)
			object:Destroy()
		end
	end
	
	
	local inv : Types.inventory = InventoryServer.AllInventories[player.UserId]

	if not inv then
		return
	end

	
	local modifiedInv = {
		Inventory = {}
	}
	
	for _ , stack in inv.Inventory do
		table.insert(modifiedInv.Inventory , {
			Name = stack.Name,
			Amount = stack.Amount,
			Image = stack.Image,
		})
	end
	
	local dataString = HTTPSERVICE:JSONEncode(modifiedInv)
	
	local success , result = false , nil
	local TIME_OUT  = 5
	local currentTime = os.time()
	
	while not success do
		if os.time() - currentTime > TIME_OUT then
			return
		end
		
		success , result = pcall(function()
			InventoryDataStore:SetAsync(player.UserId , dataString)
			print("saved data")
			if not success then task.wait(1) end
		end)
	end
end

function InventoryServer.LoadData(player : Player)
	
	local dataString = InventoryDataStore:GetAsync(player.UserId)
	if not dataString then
		InventoryServer.HasLoaded[player.UserId] = true
		return
	end
	
	local savedData = HTTPSERVICE:JSONDecode(dataString)
	
	local inv : Types.inventory = {
		Inventory = {}
	}

	for _ , stack in savedData.Inventory do 
		local objectData = Data.GetObjectData(stack.Name)
		
		if not objectData then
			return
		end
		
		local stack : Types.stack = {
			Name = stack.Name,
			Amount = stack.Amount,
			Image = "rbxassetid://" .. objectData.ImageID,
		}
		
		table.insert(inv.Inventory , stack)
	end
	
	InventoryServer.AllInventories[player.UserId] = inv
	InventoryServer.HasLoaded[player.UserId] = true
	print(InventoryServer.HasLoaded[player.UserId])
	InventoryServer.Janitors[player.UserId]:Add(function()
		InventoryServer.HasLoaded[player.UserId] = nil
	end)
	
	print("loaded data")
	
	Packets.updateInventory:FireClient(player , inv)
end

function InventoryServer.GetInventory(player : Player) : Types.inventory
	while not InventoryServer.AllInventories[player.UserId] do
		task.wait()
	end
	return InventoryServer.AllInventories[player.UserId]
end

return InventoryServer
