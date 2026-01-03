local Players = game:GetService("Players")
local player = Players.LocalPlayer
local InventoryFrame : Frame = player.PlayerGui.Inventory.Frame
local ContextActionService = game:GetService("ContextActionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Packets = require(ReplicatedStorage.Shared.Packages.Packets)
local TOGGLE_INVENTORY = "toggle inventory"
local Types = require(ReplicatedStorage.Shared.Types)
local InventoryGUI = player.PlayerGui.Inventory
local scrollingFrame = InventoryGUI.Frame.ScrollingFrame
local template = scrollingFrame.Template
local buildModeClient = require(ReplicatedStorage.SystemsClient.BuildingSystem.BuildModeClient)
local objTemplates = ReplicatedStorage.Shared.ObjectTemplates
local Janitor = require(ReplicatedStorage.Shared.Packages.Janitor)

local InventoryClient = {}

InventoryClient.InBuildMode = false
InventoryClient.Placer = nil
InventoryClient.Updating = false
InventoryClient.ClientInventory = nil
InventoryClient.SelectedObject = nil
InventoryClient.Janitors = {}

function InventoryClient.Init()
	
	InventoryClient.UpdateInventoryData()
	
	InventoryClient.Janitors[player.UserId] = Janitor.new()
	local myJanitor = InventoryClient.Janitors[player.UserId]
	
	ContextActionService:BindAction(TOGGLE_INVENTORY , InventoryClient.ToggleInventoryVisibility , false , Enum.KeyCode.B)
	myJanitor:Add(Packets.updateInventory.OnClientEvent:Connect(function(updatedInv)
		InventoryClient.ClientInventory = updatedInv
		InventoryClient.Update()
	end) , "Disconnect")
	
	player:GetAttributeChangedSignal("Launched"):Connect(function() 
		if player:GetAttribute("Launched") then
			ContextActionService:UnbindAction(TOGGLE_INVENTORY)
			InventoryFrame.Visible = false
			
		else
			ContextActionService:BindAction(TOGGLE_INVENTORY , InventoryClient.ToggleInventoryVisibility , false , Enum.KeyCode.B)
		end
	end)
	
	myJanitor:Add(function()
		InventoryClient.Janitors[player.UserId] = nil
		InventoryClient.ClientInventory = nil
		InventoryClient.SelectedObject = nil
		
		if InventoryClient.Placer then
			InventoryClient.Placer:Off()
			InventoryClient.Placer = nil
		end
	end)
	
	Players.PlayerRemoving:Connect(InventoryClient.OnPlayerRemoving)
end

function InventoryClient.UpdateInventoryData()
	InventoryClient.ClientInventory = Packets.updateInventory:Fire()
end

function InventoryClient.OnPlayerRemoving()
	ContextActionService:UnbindAction(TOGGLE_INVENTORY)
	InventoryClient.Janitors[player.UserId]:Cleanup()
end

function InventoryClient.Update()
	
	local myJanitor = InventoryClient.Janitors[player.UserId]

	while InventoryClient.Updating do task.wait() end
	InventoryClient.Updating = true
	
		for _ , stackDisplay in scrollingFrame:GetChildren() do
			if stackDisplay:IsA("ImageButton") and stackDisplay ~= template then
				stackDisplay:Destroy()
			end
		end
		
		
		-- creates display for the stacks
		for _ , stack in InventoryClient.ClientInventory.Inventory do
			local stackDisplay = template:Clone()
			stackDisplay.Name = stack.Name
			stackDisplay.Image = stack.Image
			stackDisplay:WaitForChild("Amount").Text = stack.Amount
			stackDisplay.Visible = true
			stackDisplay.Parent = scrollingFrame
			
			myJanitor:Add(stackDisplay.MouseButton1Click:Connect(function()
				if InventoryClient.SelectedObject == stack.Name then
					InventoryClient.SelectingObject(nil) -- when selected stack is clicked it gets deselected
					InventoryClient.ToggleBuildMode(false)
				 
				else
					InventoryClient.SelectingObject(stack.Name) -- if not selected object is clicked it gets selected
					
					if not InventoryClient.Placer then
					  InventoryClient.ToggleBuildMode(true)
					
					else
						--InventoryClient.Placer:InitPreview()
					   InventoryClient.Placer:PreparePreviewModel()
					end
				end
			end) , "Disconnect" )
		end 
		
		InventoryClient.SelectingObject(InventoryClient.SelectedObject) -- selected object that's not deselect is selected after update
		InventoryClient.Updating = false
end

function InventoryClient.ToggleBuildMode(on : boolean)
	if on and InventoryClient.SelectedObject then
		InventoryClient.Placer = buildModeClient.new()
	else
		InventoryClient.Placer:Off()
		InventoryClient.Placer = nil
	end
end

-- selects an object and highlights it
function InventoryClient.SelectingObject(stackName : string) : string?
	InventoryClient.SelectedObject = if stackName then stackName else nil
	local selectedStackDisplay = if InventoryClient.SelectedObject ~= nil then 
		scrollingFrame:FindFirstChild(InventoryClient.SelectedObject)
		
		else
			nil

	for _ , stackDisplay in scrollingFrame:GetChildren() do
		
		if stackDisplay:IsA("ImageButton") and stackDisplay ~= template then 
			if stackDisplay == selectedStackDisplay then
				stackDisplay.BackgroundColor3 = Color3.new(1, 0.333333, 0)
				stackDisplay:SetAttribute("Selected" , true)
				
			else
				stackDisplay.BackgroundColor3 = Color3.new(1, 1 , 1)
				InventoryClient.InBuildMode = false
				stackDisplay:SetAttribute("Selected" , false)
			
			end	
		end
	end
	return InventoryClient.SelectedObject
end

function InventoryClient.ToggleInventoryVisibility(_ , state , _)
	if state ~= Enum.UserInputState.Begin then 
		return 
	end
	InventoryFrame.Visible = not InventoryFrame.Visible
	
	if  not InventoryClient.Visible then
		if InventoryClient.Placer then
			InventoryClient.SelectingObject(nil)
			InventoryClient.ToggleBuildMode(false)
		end
	end
end

return InventoryClient
