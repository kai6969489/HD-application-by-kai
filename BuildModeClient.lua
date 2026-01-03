local ContextActionService = game:GetService("ContextActionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local camera = workspace.CurrentCamera
local Types = require(ReplicatedStorage.Shared.Types)
local Players = game:GetService("Players")
local player = Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()
local selectionBoxTemplate = ReplicatedStorage.Shared.SelectionBox
local Packets = require(ReplicatedStorage.Shared.Packages.Packets)
local objTemplates = ReplicatedStorage.Shared.ObjectTemplates
local placementValidator = require(ReplicatedStorage.Shared.PlacementValidator)
local mouse = player:GetMouse()
-- Actions 
local RENDER_PREVIEW = "render preview"
local ON_MOUSE_CLICK = "on mouse click"
local TOGGLE_DELETE_MODE = "toggle delete mode"
local ROTATE = "rotate"

-- gets mouse position in 3d space
local function castMouse()
	local mouseLocation = UserInputService:GetMouseLocation()
	local ray = camera:ViewportPointToRay(mouseLocation.X , mouseLocation.Y)
	local rayCastParams = RaycastParams.new()
	rayCastParams.FilterDescendantsInstances = {character}
	rayCastParams.FilterType = Enum.RaycastFilterType.Exclude
	return workspace:Raycast(ray.Origin , ray.Direction * 1000 , rayCastParams)
end

-- snaps a position to the grid
-- gridSize = how big each grid square is
local function SnapToGrid(gridSize, pos): Vector3
	return Vector3.new(
		-- snap x to grid
		math.round(pos.X / gridSize) * gridSize,

		-- y stays the same, no snapping here
		pos.Y,
		-- snap z to grid
		math.round(pos.Z / gridSize) * gridSize
	)
end

local BuildModeClient = {}
BuildModeClient.__index = BuildModeClient

function BuildModeClient.new()
	local self = setmetatable({
		Plot =  Packets.getPlot:Fire(player),
		Preview = nil,
		Rotation = 0,
		GridSize = 1,
		DeleteMode = false
	} , BuildModeClient)
	self:InitPreview()
	player:GetAttributeChangedSignal("Launched"):Connect(function(...)self:OnLaunch(...) end)
	-- connections 
	ContextActionService:BindAction(ON_MOUSE_CLICK, function(...) self:OnMouseClick(...) end , false , Enum.UserInputType.MouseButton1)
	ContextActionService:BindAction(TOGGLE_DELETE_MODE , function(...) self:ToggleDeleteMode(...) end , false , Enum.KeyCode.X)
	ContextActionService:BindAction(ROTATE , function(...) self:Rotate(...) end , false , Enum.KeyCode.R)
	return self
end


function BuildModeClient:RenderPreview()
	if not self.Preview then
		return
	end
	local hit : RaycastResult = castMouse()
	
	if not hit or not hit.Position then 
		return
	end  
	
	local position = if self.GridSize > 0 then SnapToGrid(self.GridSize , hit.Position) else hit.Position

	local cf = CFrame.new(position) * CFrame.Angles(0 , self.Rotation , 0)
	self.Preview:PivotTo(cf)
	
	self.Preview.SelectionBox.Color3 = if placementValidator.WithinBounds(self.Plot , self.Preview:GetExtentsSize() , cf) 
		then
		Color3.fromRGB(0 , 255 , 0)
		else
		Color3.fromRGB(255 , 0 , 0)
end

function BuildModeClient:PreparePreviewModel()
	if self.Preview then
		self.Preview:Destroy()
	end
	
	for _ , stackDisplay in player.PlayerGui.Inventory.Frame.ScrollingFrame:GetChildren() do
		if stackDisplay:GetAttribute("Selected") then
			self.Preview = objTemplates[stackDisplay.Name]:Clone()
		end
	end

	local selectionBox = selectionBoxTemplate:Clone()
	selectionBox.Adornee =  self.Preview 
	selectionBox.Parent = self.Preview
	
	if  self.Preview:IsA("Model") then
		for _ , part in  self.Preview :GetChildren() do
			if part:IsA("BasePart") then
				part.Transparency = 0.5
				part.CanQuery = false
				part.CanCollide = false
			end
		end
		end
	self.Preview.Parent = workspace
end

function BuildModeClient:InitPreview()
	self:PreparePreviewModel()
	RunService:BindToRenderStep(RENDER_PREVIEW , Enum.RenderPriority.Camera.Value , function(...) 
		self:RenderPreview(...) 
	end)
end

function BuildModeClient:Rotate(_ , state , _)
	if state == Enum.UserInputState.Begin then
		self.Rotation += math.rad(90)
	end
end


function BuildModeClient:OnMouseClick(_ , state , _)
	if state ~= Enum.UserInputState.Begin then 
		return
	end
	if not self.DeleteMode then
		self:TryPlace()
	else
		
		self:TryDelete()
	end
end

function BuildModeClient:TryPlace()
	Packets.placeObject:Fire(self.Preview.Name , self.Preview:GetPivot())
end

function BuildModeClient:TryDelete()
	local hit = castMouse()
	if hit and hit.Instance and hit.Instance:IsDescendantOf(self.Plot.Objects) then
		Packets.deleteObject:Fire(hit.Instance)
	end
end

function BuildModeClient:ToggleDeleteMode(_ , state, _)
	if state ~= Enum.UserInputState.Begin then
		return
	end
	if not self.DeleteMode then
		mouse.Icon = "rbxassetid://78551592752597"
		self.DeleteMode = true 
	else
		mouse.Icon = "rbxasset://SystemCursors/Arrow"
		self.DeleteMode = false
	end
end

function BuildModeClient:OnLaunch()
	if player:GetAttribute("Launched") then
		self:Off()
	end
end

function BuildModeClient:Off()
	if self.Preview then
		self.Preview:Destroy()
	end
-- disconnect 
RunService:UnbindFromRenderStep(RENDER_PREVIEW)
ContextActionService:UnbindAction(ON_MOUSE_CLICK)
ContextActionService:UnbindAction(TOGGLE_DELETE_MODE)
ContextActionService:UnbindAction(ROTATE)

mouse.Icon = "rbxasset://SystemCursors/Arrow"
self.DeleteMode = false
end

return BuildModeClient
