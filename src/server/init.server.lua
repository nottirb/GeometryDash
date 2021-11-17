-- Imports
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Packages = ReplicatedStorage:WaitForChild("Packages")
local Knit = require(Packages.Knit)

-- Load services
Knit.AddServices(script.Services)

-- Start Knit
Knit.Start():andThen(function()

end):catch(warn)