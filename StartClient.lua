local ReplicatedStorage = game:GetService("ReplicatedStorage")

local UI = require(ReplicatedStorage:WaitForChild("UI"))
local ContextActionService = game:GetService("ContextActionService")
local buildModeClient = require(ReplicatedStorage.SystemsClient.BuildingSystem.BuildModeClient)

UI()