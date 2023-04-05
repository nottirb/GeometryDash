-- Imports
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local Client = ReplicatedStorage:WaitForChild("Client")

local Knit = require(Packages.Knit)
local ReplicaController = require(Packages.ReplicaService)

-- Add Controllers
Knit.AddControllers(Client.Controllers)

-- Start Knit
Knit.Start():andThen(function()
	ReplicaController:RequestData()
end)