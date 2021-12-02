-- Imports
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Packages = ReplicatedStorage:WaitForChild("Packages")

local Knit = require(Packages.Knit)

-- PhysicsService
local DataService = Knit.CreateService {
    Name = "DataService";
    CollisionGroups = {};
    Client = {};
}

return DataService