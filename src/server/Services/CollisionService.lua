-- Imports
local PhysicsService = game:GetService("PhysicsService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Packages = ReplicatedStorage:WaitForChild("Packages")

local Knit = require(Packages.Knit)

-- PhysicsService
local CollisionService = Knit.CreateService {
    Name = "CollisionService";
    CollisionGroups = {};
    Client = {};
}

function CollisionService:GetCollisionGroup(name)
    if self.CollisionGroups[name] ~= nil then
        return name

    else
        PhysicsService:CreateCollisionGroup(name)
        self.CollisionGroups[name] = true

        return name
    end
end

function CollisionService.Client:GetCollisionGroup(name)
    if self.Server.CollisionGroups[name] ~= nil then
        return name
    end
end

function Knit:KnitInit()
    self:GetCollisionGroup("Collidables")
    self:GetCollisionGroup("Actions")
end

return CollisionService