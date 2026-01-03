-- Hi! I'm submitting a building mechanic like Build A Boat , an inventory system with data saving of the items and a shop system.

-- ServerScriptService --> SystemsServer(Folder) --> BuildingSystem(Folder)

-- Handles all the plot management , building and placing on players plot
local Plots : Folder = game.Workspace:FindFirstChild("Plots")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Players = game:GetService("Players")
local PlotManager = {}
local available : {Model} = Plots:GetChildren()
local ownedPlots : {Model} = {}
local Packets = require(ReplicatedStorage.Shared.Packages.Packets)
local objectTemplates = ReplicatedStorage.Shared.ObjectTemplates
local InventoryServer = require(ServerScriptService.SystemsServer.InventorySystem.InventoryServer)
local Types = require(ReplicatedStorage.Shared.Types)
local PlacementValidator = require(ReplicatedStorage.Shared.PlacementValidator)
local Data = require(ServerScriptService.SystemsServer.Configuration.Data)

-- give each player that joins a plot and make it unavailable
function PlotManager.Init()
	Packets.getPlot.OnServerInvoke = function(player)
		return PlotManager.GetPlot(player)
	end
	Players.PlayerAdded:Connect(PlotManager.OnPlayerAdded)
	Players.PlayerRemoving:Connect(PlotManager.OnPlayerRemoving)
	Packets.placeObject.OnServerEvent:Connect(PlotManager.Place)
	Packets.deleteObject.OnServerEvent:Connect(PlotManager.Delete)
	Packets.launch.OnServerEvent:Connect(PlotManager.Launch)
end

function PlotManager.OnPlayerAdded(player : Player) 
	if ownedPlots[player.UserId] or not player:IsA("Player") then
		return
	end
	local newPlot = table.remove(available)
	newPlot.Name = player.Name.. "'s Plot"
	player.RespawnLocation = newPlot:FindFirstChild("SpawnLocation")
	ownedPlots[player.UserId] = newPlot
	
	local char = player.Character or player.CharacterAdded:Wait()
	
	local function onCharacterAdded(char)
		local humanoid : Humanoid = char:WaitForChild("Humanoid")
		humanoid.Died:Connect(function()
			PlotManager.OnCharacterAdded(player)
		end)
	end
	
	task.spawn(onCharacterAdded , char)
	player.CharacterAdded:Connect(onCharacterAdded)
end

-- remove plot from player once they leave the game and make it available
function PlotManager.OnPlayerRemoving(player : Player)
	if not ownedPlots[player.UserId] or not player:IsA("Player") then
		return
	end
	ownedPlots[player.UserId].Name = "Plot"
	table.insert(available , ownedPlots[player.UserId])
	ownedPlots[player.UserId] = nil
	
	if player:GetAttribute("Launched") then
		PlotManager.Launch(player)
	end
	
end

-- handles player's respawn
function PlotManager.OnCharacterAdded(player)
	if not player:GetAttribute("Launched") then
		return
	end
	
	local plot : Model? = ownedPlots[player.UserId]
	
	if not plot then
		return
	end
	
	for _, object : Model in plot.Objects:GetChildren() do
		if object:IsA("Model") and Data.GetObjectData(object.Name) then
			object:Destroy()
			InventoryServer.RegisterObject(player , object)
		end
	end	
	PlotManager.Launch(player)
end

-- return plot of a player
function PlotManager.GetPlot(player : Player) : Model
   return ownedPlots[player.UserId]
end

function PlotManager.Place(player : Player , objectName : string  , objectCF : CFrame )
	local inventory : Types.inventory = InventoryServer.GetInventory(player)
	if not inventory or PlotManager.GetStackData(inventory , objectName).Amount == 0 then
		return
	end
	
	local plot : Model? = ownedPlots[player.UserId]
	local objectTemplate : Model? = objectTemplates[objectName]
	if not plot or not objectTemplate or not Data.GetObjectData(objectName) then
		return
	end
	if not PlacementValidator.WithinBounds(plot , objectTemplate:GetExtentsSize() , objectCF) then
		return
	end
	
	local newObject = objectTemplate:Clone()
	newObject:PivotTo(objectCF)
	
	local intersect , overlappingObject = PlacementValidator.IntersectingObject(plot , objectTemplate:GetExtentsSize() , objectCF)
	if intersect and overlappingObject then
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = newObject.PrimaryPart
		weld.Part1 = overlappingObject
		weld.Parent = newObject
	
	end
	
	newObject.Parent = plot.Objects
	InventoryServer.UnregisterObject(player , newObject)
end

function PlotManager.Delete(player : Player , object : Part)
	local plot : Model? = ownedPlots[player.UserId]
	
	if not plot or not object:IsDescendantOf(plot.Objects) then
		return
	end
	
	local actualObject = object
	
	-- keeps looping until we find the model that is parented to the object folder
	while actualObject.Parent ~= plot.Objects do
		actualObject = actualObject.Parent
	end
	
	actualObject:Destroy()
	InventoryServer.RegisterObject(player , actualObject)
end

function PlotManager.Launch(player : Player)
	local plot : Model? = PlotManager.GetPlot(player)
	if not plot then
		return
	end
	
	local actualPlot : Part = plot.Plot
	
	if not player:GetAttribute("Launched") then
		player:SetAttribute("Launched" , true)
		local objectsFolder : Folder = plot.Objects

		for _ , object : BasePart  in objectsFolder:GetDescendants() do
			if object:IsA("BasePart") then
				object.Anchored = false
			end
		end

		actualPlot.Color = Color3.fromRGB(0, 0, 255)
		local velocity = actualPlot.AssemblyLinearVelocity
		actualPlot.AssemblyLinearVelocity = Vector3.new(50 , velocity.Y, velocity.Z)
		
	else
		player:SetAttribute("Launched" , false)
		local actualPlot : Part = plot.Plot
		actualPlot.Color = Color3.fromRGB(40, 127, 71)
		local velocity = actualPlot.AssemblyLinearVelocity
		actualPlot.AssemblyLinearVelocity = Vector3.new(0 , velocity.Y, velocity.Z)
	end
end

function PlotManager.GetStackData(inventory : Types.inventory , objectName : string)
	for _ , stack in inventory.Inventory do
		if stack.Name == objectName then
			return stack
		end
	end
end




return PlotManager

-- ServerScriptService --> SystemsServer(Folder) --> InventorySystem(Folder)
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

-- ServerScriptService --> SystemsServer(Folder) --> ShopSystem(Folder)
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

-- ServerScriptService --> SystemsServer(Folder) --> Configurations
local Data = {}

Data.Objects = {
	
	Brick = {
		ImageID = 119927858691427,
		Price = 100
	},
	
	Wood = {
		ImageID = 102419410921260,
		Price = 50
	},
	
	Ice = {
		ImageID = 128689214655358,
		Price = 20
	}	
}

function Data.GetObjectData(objectName : string)
	return Data.Objects[objectName]
end

return Data
