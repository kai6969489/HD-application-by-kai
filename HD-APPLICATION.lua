local Plots : Folder = game.Workspace:FindFirstChild("Plots")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Players = game:GetService("Players")
local PlotManager = {}
--plots that nobody owns yet
local available : {Model} = Plots:GetChildren()

--plots currently owned by players (keyed by UserId)
local ownedPlots : {Model} = {}

--networking
local Packets = require(ReplicatedStorage.Shared.Packages.Packets)

--object templates players can place
local objectTemplates = ReplicatedStorage.Shared.ObjectTemplates

--inventory system
local InventoryServer = require(ServerScriptService.SystemsServer.InventorySystem.InventoryServer)

--shared types
local Types = require(ReplicatedStorage.Shared.Types)

-- config / object data
local Data = require(ServerScriptService.SystemsServer.Configuration.Data)

--setup remotes + player events
function PlotManager.Init()
	Packets.getPlot.OnServerInvoke = function(player)
		return PlotManager.GetPlot(player)
	end
	Players.PlayerAdded:Connect(PlotManager.OnPlayerAdded)
	Players.PlayerRemoving:Connect(PlotManager.OnPlayerRemoving)
	Packets.placeObject.OnServerEvent:Connect(PlotManager.Place)
	Packets.deleteObject.OnServerEvent:Connect(PlotManager.Delete)
	Packets.launch.OnServerEvent:Connect(PlotManager.Launch)
	Packets.clearAll.OnServerEvent:Connect(PlotManager.ClearAll)
end

-- give player a plot when they join
function PlotManager.OnPlayerAdded(player : Player)
	
	if ownedPlots[player.UserId] or not player:IsA("Player") then
		return -- already has plot or invalid
	end
	
	local newPlot = table.remove(available) -- grabs available plots
	newPlot.Name = player.Name .. "'s Plot" -- rename plot to plr name
	player.RespawnLocation = newPlot:FindFirstChild("SpawnLocation")-- set plr respawn location
	ownedPlots[player.UserId] = newPlot	-- mark plot as owned
	
	local char = player.Character or player.CharacterAdded:Wait()
	
	-- handle deaths so launch state stays correct
	local function onCharacterAdded(char)
		local humanoid : Humanoid = char:WaitForChild("Humanoid")
		humanoid.Died:Connect(function()
			PlotManager.OnCharacterAdded(player)
		end)
	end
	
	task.spawn(onCharacterAdded , char)
	player.CharacterAdded:Connect(onCharacterAdded)
end

function PlotManager.ClearAll(player : Player)
	-- get player's plot
	local plot = PlotManager.GetPlot(player)

	if not plot then
		return
	end

	-- grab the objects folder
	local objectFolder : Folder = plot:FindFirstChild("Objects")

	if not objectFolder or not objectFolder:GetChildren() then 
		return
	end

	-- loop through all placed objects
	for _, object in objectFolder:GetChildren() do
		if object:IsA("Model") then
			-- give item back to player
			InventoryServer.RegisterObject(player, object)

			-- delete from plot
			object:Destroy()
		end
	end
end

-- cleanup when player leaves
function PlotManager.OnPlayerRemoving(player : Player)
	if not PlotManager.GetPlot(player) or not player:IsA("Player") then
		return
	end
	
	if player:GetAttribute("Launched") then
		PlotManager.Launch(player)
	end
	
	-- making plot available again
	ownedPlots[player.UserId].Name = "Plot"
	table.insert(available , ownedPlots[player.UserId])
	ownedPlots[player.UserId] = nil
	
end

-- called after death if plr launched
-- to reset models and launch state
function PlotManager.OnCharacterAdded(player)
	if not player:GetAttribute("Launched") then
		return
	end
	PlotManager.ClearAll(player)
	PlotManager.Launch(player)
end

-- return plot of a player
function PlotManager.GetPlot(player : Player) : Model
   return ownedPlots[player.UserId]
end

--placing system
function PlotManager.Place(player : Player , objectName : string  , objectCF : CFrame )
	local inventory : Types.inventory = InventoryServer.GetInventory(player)
	
	if not inventory or PlotManager.GetStackData(inventory , objectName).Amount == 0 then
		return
	end -- sanity check for if player really has the object
	
	local plot : Model? =PlotManager.GetPlot(player)
	local objectTemplate : Model? = objectTemplates[objectName]
	-- invalid placement
	if not plot or not objectTemplate or not Data.GetObjectData(objectName) then
		return
	end

	-- outside plot bounds -> stop
	if not PlotManager.WithinBounds(plot, objectTemplate:GetExtentsSize(), objectCF) then
		return
	end
	
	--clone and position object
	local newObject = objectTemplate:Clone()
	newObject:PivotTo(objectCF)
	
	local intersect , overlappingObject = PlotManager.Intersecting(plot , objectTemplate:GetExtentsSize() , objectCF)
	-- check if objects are intersecting and get the object its intersecting with
	
	if intersect and overlappingObject then
		-- if its intersecting weld it together
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = newObject.PrimaryPart
		weld.Part1 = overlappingObject
		weld.Parent = newObject
	
	end
	
	newObject.Parent = plot.Objects
	-- remove from inventory
	InventoryServer.UnregisterObject(player , newObject)
end

function PlotManager.Delete(player : Player , object : Part)
	local plot : Model? = PlotManager.GetPlot(player)
	
	if not plot or not object:IsDescendantOf(plot.Objects) then
		return
	end
	
	local actualObject = object
	
	-- climb up until we hit the model in Objects folder
	-- (model is parented to the Objects folder)
	while actualObject.Parent ~= plot.Objects do
		actualObject = actualObject.Parent
	end
	
	actualObject:Destroy()
	InventoryServer.RegisterObject(player , actualObject)
	-- delete from plot and registers it back to the inventory
end

function PlotManager.Launch(player : Player)
	local plot : Model? = ownedPlots[player.UserId]
	if not plot then
		warn("Error")
		return
	end
	
	local actualPlot : Part = plot.Plot
	
	if not player:GetAttribute("Launched") then
		player:SetAttribute("Launched" , true)
		local objectsFolder : Folder = plot.Objects
		
		-- unanchor everything in the ship ( so it can move )
		for _ , object : BasePart  in objectsFolder:GetDescendants() do
			if object:IsA("BasePart") then
				object.Anchored = false
			end
		end

		actualPlot.Color = Color3.fromRGB(0, 0, 255)
		actualPlot.AssemblyLinearVelocity = actualPlot.CFrame.LookVector * 50
		print("Launch")
	else
		-- setting it back to normal
		player:SetAttribute("Launched" , false)
		local actualPlot : Part = plot.Plot
		actualPlot.Color = Color3.fromRGB(40, 127, 71)
		actualPlot.AssemblyLinearVelocity = actualPlot.CFrame.LookVector * 0
		print("Unlaunch")
	end
end

-- get inventory stack for an object
function PlotManager.GetStackData(inventory : Types.inventory , objectName : string)
	for _ , stack in inventory.Inventory do
		if stack.Name == objectName then
			return stack
		end
	end
end

function PlotManager.WithinBounds(plot : Model , objectSize : Vector3 , worldCF : CFrame) : boolean
	local plotCF , plotSize = plot:GetBoundingBox()
	local objectCF = plotCF:ToObjectSpace(worldCF)
	--create corners in X/Z
	--corner coordinates are generated using:
	--(-1,  1), ( 1, -1), ( 1,  1), (-1, -1)
	local cornerpoints = {}
	for _ , x in pairs({-1, 1}) do
		for _ , z in pairs({-1 , 1}) do
			table.insert(cornerpoints , objectCF:PointToWorldSpace(Vector3.new(x * objectSize.X / 2 , 0 , z * objectSize.Z / 2))) 
			-- Convert the local corner into plot-local space
			-- then insert each corner in cornerpoints table
		end
	end

	for _ , point : Vector3 in cornerpoints do
		if math.abs(point.X) > plotSize.X / 2 or math.abs(point.Z) > plotSize.Z / 2 then
			return false
			--check each corner point against the plot bounds
			--If ANY corner is outside the plot, placement is invalid
		end
	end
	return true -- ALL corners inside plot so placement is valid
end

function PlotManager.Intersecting(plot : Model , objectSize : Vector3 , worldCF : CFrame) : boolean
	local params = OverlapParams.new()
	params:AddToFilter(plot.Objects)-- folder
	params.FilterType = Enum.RaycastFilterType.Include
	-- ONLY considers object in Objects folder to be intersecting

	local overlappingPart : {Instance} = workspace:GetPartBoundsInBox(worldCF , objectSize , params) -- creates a box surrounding object

	if #overlappingPart > 0 then -- if another object is inside the box then its intersecting
		return true , overlappingPart[1]
	else
		return false
	end
end

return PlotManager
