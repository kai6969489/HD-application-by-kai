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
