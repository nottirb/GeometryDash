-- Imports
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Packages = ReplicatedStorage:WaitForChild("Packages")
local Knit = require(Packages.Knit)

-- Load controllers
Knit.AddControllers(script.Controllers)

-- Start Knit
Knit.Start():andThen(function()
    print("Knit started")
end):catch(warn)