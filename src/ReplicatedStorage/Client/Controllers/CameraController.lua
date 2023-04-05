-- Imports
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Packages = ReplicatedStorage:WaitForChild("Packages")

local Knit = require(Packages.Knit)
local Spring = require(Packages.Spring)
local Janitor = require(Packages.Janitor)

-- Constants
local CAMERA_ANGLE = CFrame.Angles(0,-math.pi/2,0)
local CAMERA_OFFSET = Vector3.new(-17, 6, 8)
local FLYING_CAMERA_OFFSET = Vector3.new(-17, 14, 8)
local Y_GIVE = 4

local XZ_VECTOR3 = Vector3.new(1, 0, 1)

--[=[
    @class CameraController
    @client

    Controls anything related to the camera.
]=]
local CameraController = Knit.CreateController {
    Name = "CameraController"
}


--[=[
    @interface State
    @tag enum
    @within CameraController
    
    .Following 0 -- Following a character
    .Menu 1 -- In the menu
    .Fixed 2 -- Unchanging, fixed to the most recent camera position

    Represents the movement state of the character.
]=]
CameraController.Enum = {
    State = {
        Following = 0;
        Menu = 1;
        Fixed = 2;
    }
}

--[=[
    @prop Camera Camera
    @within CameraController

    The current camera object for the player.
]=]
--[=[
    @prop _ySpring Spring
    @within CameraController
    @private

    The ``Spring`` that determines the y position of the camera.
]=]
--[=[
    @prop _stateJanitor Janitor
    @within CameraController
    @private

    The ``Janitor`` that handles the cleanup of the connections set up whenever the camera state changes.
]=]
--[=[
    @prop State State
    @within CameraController

    The current state of the camera.
]=]
function CameraController:KnitInit()
    -- get/create objects
    local camera = workspace.CurrentCamera
    local ySpring = Spring.new(0)

    ySpring.Speed = 25

    -- update camera object according to this project's specifications
    camera.CameraType = Enum.CameraType.Scriptable

    -- store variables
    self.Camera = camera
    self._ySpring = ySpring
    self._stateJanitor = Janitor.new()
    self.State = -1
end

function CameraController:KnitStart()
    self:SetState(CameraController.Enum.State.Following)
end

--[=[
    @within CameraController

    @param state State -- The State to set the camera to

    Sets the camera state to the given state, if not already set.
]=]
function CameraController:SetState(state)
    if state ~= self.State then
        self._stateJanitor:Cleanup()
        self.State = state

        if state == CameraController.Enum.State.Following then
            local CharacterController = Knit.GetController("CharacterController")

            local ySpring = self._ySpring
            local yPosition = 0

            self._stateJanitor:Add(CharacterController.CharacterMoved:Connect(function(position, _, characterOffset)
                local character = CharacterController.Character

                if self.State == CameraController.Enum.State.Following and character ~= nil then
                    if character.State == character.Enum.State.Default then
                        -- break up positional data
                        local xzPosition = position*XZ_VECTOR3
                        local charYPosition = position.Y - characterOffset
                        local yOffset = yPosition + CAMERA_OFFSET.Y - charYPosition
                        local absYOffset = math.abs(yOffset)

                        -- recalculate y position
                        if yOffset > Y_GIVE then -- camera needs to go down
                            yPosition = yPosition - (absYOffset - Y_GIVE + (2 - absYOffset%2))
                        elseif yOffset < -Y_GIVE then -- camera needs to go up
                            yPosition = yPosition + (absYOffset - Y_GIVE + (2 - absYOffset%2))
                        end

                        ySpring.Target = yPosition

                        -- set overall position
                        self.Camera.CFrame = CAMERA_ANGLE + xzPosition + Vector3.new(0, ySpring.Position, 0) + CAMERA_OFFSET
                    elseif character.State == character.Enum.State.Flying then
                        self.Camera.CFrame = CAMERA_ANGLE + position*XZ_VECTOR3 + FLYING_CAMERA_OFFSET
                    end
                end
            end))
        end
    end
end

return CameraController