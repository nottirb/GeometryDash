-- Imports
local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local Services = ServerScriptService:WaitForChild("Services")

local Knit = require(Packages.Knit)

-- Add Services
Knit.AddServices(Services)

-- Start Knit
Knit.Start():andThen(function()
	-- do something
end):catch(warn)