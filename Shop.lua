local Players = game:GetService("Players")
local player = Players.LocalPlayer
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ObjectTemplates = ReplicatedStorage.Shared.ObjectTemplates
local ShopFrame : Frame = player.PlayerGui.Shop.Frame
local Packets = require(ReplicatedStorage.Shared.Packages.Packets)
local scrollFrame = ShopFrame.ScrollingFrame
local ContextActionService = game:GetService("ContextActionService")
local TOGGLE__SHOP = "toggle shop"
local template : Frame = script.Template
local Janitor = require(ReplicatedStorage.Shared.Packages.Janitor)


local items = ObjectTemplates:GetChildren()

table.sort(items , function(a , b )
	return a:GetAttribute("Price") < b:GetAttribute("Price")
end)

-- signals 

local Shop = {}

function Shop.Init()
	
	local myJanitor = Janitor.new()
	
	ContextActionService:BindAction(TOGGLE__SHOP , Shop.ToggleShop__ , false , Enum.KeyCode.F)
	
	player:GetAttributeChangedSignal("Launched"):Connect(function()
		if player:GetAttribute("Launched") then
			ContextActionService:UnbindAction(TOGGLE__SHOP)
			ShopFrame.Visible = false
			
		else
			ContextActionService:BindAction(TOGGLE__SHOP , Shop.ToggleShop__ , false , Enum.KeyCode.F)
		end
	end)
	
	for _, item in ipairs(items) do
		if not (item:IsA("Model") or item:IsA("BasePart")) then continue end
		
		local newFrame = template:Clone()
		newFrame.Name = item.Name
		local imageLabel , button = newFrame:WaitForChild("ImageLabel") , newFrame:WaitForChild("TextButton")
		
		if imageLabel and button then
			imageLabel.Image = "rbxassetid://" .. item:GetAttribute("ImageID")
			button.Text = item:GetAttribute("Price")
			
			myJanitor:Add(button.MouseButton1Click:Connect(function(...) 
				Packets.tryPurchase:Fire(item.Name) end) , "Disconnect")
		end
		
		newFrame.Visible = true
		newFrame.Parent = scrollFrame
	end
	
	Players.PlayerRemoving:Connect(function()
		ContextActionService:UnbindAction(TOGGLE__SHOP)
		myJanitor:Cleanup()
	end)
end

function Shop.ToggleVisibility()
	ShopFrame.Visible = not ShopFrame.Visible
end

function Shop.ToggleShop__(_ , state ,_)
	if state ~= Enum.UserInputState.Begin then 
		return 
	end
	Shop.ToggleVisibility()
end


return Shop