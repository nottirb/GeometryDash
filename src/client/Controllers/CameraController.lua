-- Imports
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Packages = ReplicatedStorage:WaitForChild("Packages")
local Knit = require(Packages.Knit)

-- CameraController
local CameraController = Knit.CreateController {
    Name = "CameraController"
}

function CameraController:KnitStart()
    
end

function CameraController:Update()

end

return CameraController