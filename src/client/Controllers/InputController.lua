-- Imports
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Packages = ReplicatedStorage:WaitForChild("Packages")
local Knit = require(Packages.Knit)

-- CharacterController
local InputController = Knit.CreateController {
    Name = "InputController"
}

function InputController:KnitStart()
    -- 
end

return InputController