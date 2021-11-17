-- Imports
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Packages = ReplicatedStorage:WaitForChild("Packages")
local Components = script.Parent.Parent.Components
local Knit = require(Packages.Knit)
local CharacterComponent = require(Components.Character)

-- CharacterController
local CharacterController = Knit.CreateController {
    Name = "CharacterController"
}

function CharacterController:KnitStart()
    print("Knit start")
    workspace.CurrentCamera.CameraType = Enum.CameraType.Scriptable

    -- TEMP
    UserInputService.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.Keyboard then
            if input.KeyCode == Enum.KeyCode.Q then
                CharacterController:CreateCharacter()
            elseif input.KeyCode == Enum.KeyCode.Space or input.KeyCode == Enum.KeyCode.Up then
                if self.Character then
                    self.Character:Jump(true)
                end
            end
        end
    end)

    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.Keyboard then
            if input.KeyCode == Enum.KeyCode.Space or input.KeyCode == Enum.KeyCode.Up then
                if self.Character then
                    self.Character:Jump(false)
                end
            end
        end
    end)

    game:GetService("RunService").RenderStepped:Connect(function(dt)
        local char = self.Character

        if char then
            char:Step(dt)

            if char and char.Alive then
                workspace.CurrentCamera.CFrame = CFrame.Angles(0,-math.pi/2,0) + char.Position + Vector3.new(-10,0,0)
            end
        end
    end)
end

function CharacterController:CreateCharacter()
    print("create character")

    if self.Character then
        self.Character:Destroy()
    end

    local character = CharacterComponent.new()
    character.Died:Connect(function()
        print("died")
        if self.Character == character then
            self.Character = nil
        end
    end)

    self.Character = character

    if UserInputService:IsKeyDown(Enum.KeyCode.Space) or UserInputService:IsKeyDown(Enum.KeyCode.Up) then
        character:Jump(true)
    end
end

return CharacterController