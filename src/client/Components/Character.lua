-- Imports
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Packages = ReplicatedStorage:WaitForChild("Packages")
local Assets = ReplicatedStorage:WaitForChild("Assets")
local Shared = ReplicatedStorage:WaitForChild("Shared")

local Signal = require(Packages.Signal)
local Spring = require(Packages.Spring)
local Linecast = require(Shared.Linecast)

local MOVEMENT_DIRECTION = Vector3.new(0,0,1)
local CHARACTER_BASE = Assets.Character
local DEFAULT_SPEED = 10.3761348898*2
local DEFAULT_GRAVITY = -8.76*DEFAULT_SPEED
local DEFAULT_JUMP_VELOCITY = math.sqrt(-8*DEFAULT_GRAVITY)
local DEFAULT_STEP_HEIGHT = 0.5
local DEFAULT_TERMINAL_VELOCITY = -2.6*DEFAULT_SPEED
local FLYING_GRAVITY = -3*DEFAULT_SPEED
local FLYING_TERMINAL_VELOCITY = -DEFAULT_SPEED/1.25
local CHARACTER_HEIGHT = CHARACTER_BASE.PrimaryPart.Size.Y
local CHARACTER_WIDTH = CHARACTER_BASE.PrimaryPart.Size.Z
local MAX_SLOPE_ANGLE = math.rad(40)

local Z_VECTOR3 = Vector3.new(0,0,1)
local Y_VECTOR3 = Vector3.new(0,1,0)
local XZ_VECTOR3 = Vector3.new(1,0,1)
local DEFAULT_CFRAME = CFrame.fromMatrix(Vector3.new(), Vector3.new(0,0,1):Cross(Vector3.new(0,1,0)), Vector3.new(0,1,0), Vector3.new(0,0,-1))
local INVERTED_CFRAME = CFrame.fromMatrix(Vector3.new(), Vector3.new(0,0,1):Cross(Vector3.new(0,-1,0)), Vector3.new(0,-1,0), Vector3.new(0,0,-1))

--[=[
    @class Character
]=]
local Character = {}
Character.__index = Character

-- Enumerations
Character.Enum = {}
Character.Enum.State = {
    Default = 0;
    Flying = 1;
}

function Character.new()
    local self = setmetatable({}, Character)
    
    local characterModel = CHARACTER_BASE:Clone()
    local rootPart = characterModel:WaitForChild("RootPart")
    characterModel.Parent = workspace

    local raycastParams = RaycastParams.new()
    raycastParams.FilterDescendantsInstances = {characterModel}
    raycastParams.FilterType = Enum.RaycastFilterType.Blacklist

    self.Alive = true
    self.State = Character.Enum.State.Default
    self.Model = characterModel
    self.RootPart = rootPart
    self.Speed = DEFAULT_SPEED
    self.GravityDirection = -1
    self.Position = Vector3.new(0, 1, 0)
    self.Velocity = Vector3.new(0, 0, DEFAULT_SPEED)
    self.StepHeight = DEFAULT_STEP_HEIGHT
    self.RaycastParams = raycastParams

    self.TimePassed = 0
    self.Clock = function()
        return self.TimePassed
    end

    self.RotationSpring = Spring.new(0, self.Clock)
    self.RotationSpring.Speed = 50

    self.Died = Signal.new()
    self.Destroyed = Signal.new()
    self.Moved = Signal.new()

    characterModel:SetPrimaryPartCFrame(DEFAULT_CFRAME + self.Position)

    return self
end

function Character:Destroy()
    self.Model:Destroy()
    self.Died:Destroy()
    self.Moved:Destroy()
    self.Destroyed:Fire()
    self.Destroyed:Destroy()
    setmetatable(self, nil)
end

function Character:Kill(position)
    if self.Alive then
        self.Alive = false
        self.Died:Fire(position or self.Position)

        -- temp
        self:Destroy()
    end
end

-- Casting utility
function Character:CastForwards(position, castLength)
    local halfWidth = CHARACTER_WIDTH/2
    local result, length = Linecast(position, MOVEMENT_DIRECTION*(castLength + halfWidth), Y_VECTOR3, CHARACTER_HEIGHT*0.99, 22, self.RaycastParams)

    if result and length then
        return result, length - halfWidth
    end
end

function Character:CastUp(position, castLength)
    local halfHeight = CHARACTER_HEIGHT/2
    local result, length = Linecast(position, Vector3.new(0, -self.GravityDirection*(castLength + halfHeight), 0), Z_VECTOR3, CHARACTER_WIDTH, 22, self.RaycastParams)

    if result and length then
        return result, length - halfHeight
    end
end

function Character:CastDown(position, castLength)
    local halfHeight = CHARACTER_HEIGHT/2
    local result, length = Linecast(position, Vector3.new(0, self.GravityDirection*(castLength + CHARACTER_HEIGHT/2), 0), Z_VECTOR3, CHARACTER_WIDTH, 22, self.RaycastParams)

    if result and length then
        return result, length - halfHeight
    end
end

-- General physics
function Character:SetState(state)
    self.State = state

    if state == Character.Enum.State.Default then
        self.RotationSpring.Target = self.RotationSpring.Position

    elseif state == Character.Enum.State.Flying then
        self.Velocity = self.Velocity*XZ_VECTOR3 + Vector3.new(0, math.clamp(self.Velocity.Y, FLYING_TERMINAL_VELOCITY, -FLYING_TERMINAL_VELOCITY))
        self.RotationSpring.Target = -math.pi/8*self.Velocity.Y/FLYING_TERMINAL_VELOCITY
        self.RotationSpring.Position = self.RotationSpring.Target
    end
end

function Character:IsGrounded(position, velocity)
    local downResult, downLength = self:CastDown(position or self.Position, 0.2)

    if downResult and velocity.Y < 0 then
        return downResult, downLength
    elseif self.State == Character.Enum.State.Flying and velocity.Y > 0 then
        return self:CastUp(position or self.Position, 0.2)
    end
end

function Character:ShouldStepUp(position)
    -- upcast, then forward cast, then downcast
    -- we need to go back by 0.05 studs because the upcast will otherwise go through the object we're trying to cast onto
    local upCastPosition = position - MOVEMENT_DIRECTION*0.05
    local upResult = self:CastUp(upCastPosition, self.StepHeight)

    if not upResult then
        -- we need to cast forwards from the upCastPosition + <0, stepHeight, 0>, because now we need to go forwards and then cast downwards to get the stepheight
        local forwardsCastPosition = upCastPosition - Vector3.new(0, self.GravityDirection*self.StepHeight, 0)
        local forwardsResult = self:CastForwards(forwardsCastPosition, 0.05 + self.StepHeight)

        -- ensure there is a platform we can step onto (with enough space), for slopes this also ensures it is <= 45 degrees
        if not forwardsResult then
            local downCastPosition = forwardsCastPosition + MOVEMENT_DIRECTION*(0.05 + self.StepHeight)
            local downResult, downCastLength = self:CastDown(downCastPosition, self.StepHeight)

            if downResult then
                return self.StepHeight - downCastLength + 0.01
            end
        end
    end

    return false
end

function Character:SwitchGravity()
    self.GravityDirection *= -1
    self.Velocity *= Vector3.new(1, -1, 1)
end

function Character:Jump(enabled)
    self.Jumping = enabled or false
end

function Character:MoveTo(position, groundOffset)
    local currentPosition = self.Position
    local offset = (position - currentPosition).Magnitude

    self.Moved:Fire(position, currentPosition, offset)
    self.Model:SetPrimaryPartCFrame(DEFAULT_CFRAME*CFrame.Angles(self.RotationSpring.Position, 0, 0) + position + Vector3.new(0, self.GravityDirection*groundOffset, 0))
end

-- edge case for this is probably if we hit the ground and are jumping, we should switch up the velocity?
function Character:UpdatePosition(position, velocity, dt)
    --debug.profilebegin("UpdatePosition")
    self.TimePassed += dt

    local xVelocity = (velocity*MOVEMENT_DIRECTION).Magnitude
    local yVelocity = velocity.Y

    if yVelocity > 0 then
        -- check if we can go up first
        do
            local upCastLength = yVelocity*dt
            local upResult, upResultLength = self:CastUp(position, upCastLength)

            -- kill the player if they hit a ceiling
            if upResult and self.State ~= Character.Enum.State.Flying then
                self:Kill()
                return
            end

            position += -self.GravityDirection*Vector3.new(0, upResult and upResultLength or upCastLength, 0)
        end

        -- now check if we can go forwards
        do
            local forwardCastLength = xVelocity*dt
            local forwardResult, forwardLength = self:CastForwards(position, forwardCastLength)

            -- if we hit something, check if we can step up, otherwise kill the player
            if forwardResult then
                -- try to step up
                local stepHeight = self.State == Character.Enum.State.Default and self:ShouldStepUp(position + MOVEMENT_DIRECTION*forwardLength)

                -- keep going if we can step up
                if stepHeight then
                    -- get the amount of time actually spent moving
                    local newdt = dt - dt*(forwardLength/forwardCastLength)

                    -- move forwards by forwardsLength, add the stepHeight to our position, then re-cast to move the full distance
                    position += MOVEMENT_DIRECTION*forwardLength - Vector3.new(0, self.GravityDirection*stepHeight, 0)
                    position = self:UpdatePosition(position, velocity*XZ_VECTOR3, newdt)

                -- otherwise kill the player, they hit a wall larger than the step height
                else
                    self:Kill()
                    return
                end
                
            else
                -- move forwards by forwardCastLength
                position += MOVEMENT_DIRECTION*forwardCastLength
            end
        end

    elseif yVelocity <= 0 then
        -- check if we can go forwards first
        do
            local forwardCastLength = xVelocity*dt
            local forwardResult, forwardLength = self:CastForwards(position, forwardCastLength)

            if forwardResult then
                -- try to step up
                local stepHeight = self.State == Character.Enum.State.Default and self:ShouldStepUp(position + MOVEMENT_DIRECTION*forwardLength)

                -- keep going if we can step up
                if stepHeight then
                    -- get the amount of time actually spent moving, and adjust that amount for the rest of the casts
                    local dtSpent = dt*(forwardLength/forwardCastLength)
                    local newdt = dt - dtSpent
                    dt = dtSpent

                    -- move forwards by forwardsLength, add the stepHeight to our position, then re-cast to move the full distance
                    position += MOVEMENT_DIRECTION*forwardLength - Vector3.new(0, self.GravityDirection*stepHeight, 0)
                    position = self:UpdatePosition(position, velocity*XZ_VECTOR3, newdt)

                -- otherwise kill the player, they hit a wall larger than the step height
                else
                    self:Kill()
                    return
                end
                
            else
                -- move forwards by forwardCastLength
                position += MOVEMENT_DIRECTION*forwardCastLength
            end
        end

        -- go down as far as possible
        do
            local downCastLength = -yVelocity*dt
            local downResult, downLength = self:CastDown(position, downCastLength)

            -- move down by the length of the downwards cast if it exists, otherwise move down the full distance
            if downResult and downLength then
                position += self.GravityDirection*Vector3.new(0, downLength, 0)
            else
                position += self.GravityDirection*Vector3.new(0, downCastLength, 0)
            end
        end

    else
        local forwardCastLength = xVelocity*dt
        local forwardResult, forwardLength = self:CastForwards(position, forwardCastLength)

        if forwardResult then
            -- try to step up
            local stepHeight = self.State == Character.Enum.State.Default and self:ShouldStepUp(position + MOVEMENT_DIRECTION*forwardLength)

            -- keep going if we can step up
            if stepHeight then
                -- get the amount of time actually spent moving
                local newdt = dt - dt*(forwardLength/forwardCastLength)

                -- move forwards by forwardsLength, add the stepHeight to our position, then re-cast to move the full distance
                position += MOVEMENT_DIRECTION*forwardLength + Vector3.new(0, stepHeight, 0)
                position = self:UpdatePosition(position, velocity, newdt)

            -- otherwise kill the player, they hit a wall larger than the step height
            else
                self:Kill()
                return
            end
                
        else
            -- move forwards by forwardCastLength
            position += MOVEMENT_DIRECTION*forwardCastLength
        end
    end

    --debug.profileend()

    return position
end

function Character:Step(dt)
    --debug.profilebegin("CharacterStep")

    -- don't step if the character isn't alive
    if self.Alive ~= true then
        return
    end

    -- get current velocity
    local velocity = self.Velocity

    -- update velocity based on state
    if self.State == Character.Enum.State.Default then
        -- move forwards
        velocity = velocity*Y_VECTOR3 + MOVEMENT_DIRECTION*self.Speed

        -- if we're grounded and jumping, and not moving upwards, then change the velocity to go up
        if self.Grounded and self.Jumping and velocity.Y <= 0 then
            velocity = velocity*XZ_VECTOR3 + Vector3.new(0, DEFAULT_JUMP_VELOCITY*self.Speed/DEFAULT_SPEED, 0)

        -- otherwise apply gravity, rotate the character if we're not grounded
        else
            velocity += Vector3.new(0, dt*DEFAULT_GRAVITY*self.Speed/DEFAULT_SPEED, 0)

            if not self.Grounded then
                self.RotationSpring.Target += self.GravityDirection*2.4*math.pi*dt
                self.RotationSpring.Speed = 125
                --self.RotationSpring.Position = self.RotationSpring.Target
            end
        end

        -- account for terminal velocity
        velocity = velocity*XZ_VECTOR3 + Vector3.new(0, math.max(velocity.Y, DEFAULT_TERMINAL_VELOCITY), 0)

    elseif self.State == Character.Enum.State.Flying then
        -- move forwards
        velocity = velocity*Y_VECTOR3 + MOVEMENT_DIRECTION*self.Speed

        -- if we're jumping then accelerate upwards, otherwise accelerate downwards
        velocity += Vector3.new(0, (self.Jumping and -1 or 1)*dt*FLYING_GRAVITY*self.Speed/DEFAULT_SPEED, 0)
        velocity = velocity*XZ_VECTOR3 + Vector3.new(0, math.clamp(velocity.Y, FLYING_TERMINAL_VELOCITY, -FLYING_TERMINAL_VELOCITY), 0)
    end

    -- move the character and update velocity
    local position = self:UpdatePosition(self.Position, velocity, dt)

    if position and self.Alive then
        -- check if the character is grounded
        local isGrounded, groundDistance = self:IsGrounded(position, velocity)

        -- if we're moving downwards, but also grounded, then cancel out the downwards velocity and move the character to the ground
        if isGrounded and groundDistance then
            position += Vector3.new(0, -math.sign(velocity.Y)*self.GravityDirection*groundDistance, 0)
            velocity *= XZ_VECTOR3

            -- match the rotation of the ground in the default state
            if self.State == Character.Enum.State.Default then
                local normal = isGrounded.Normal
                local surfaceRotation = self.GravityDirection*math.atan2(normal.Z, -self.GravityDirection*normal.Y)

                if math.abs(surfaceRotation) > MAX_SLOPE_ANGLE + 0.01 then
                    self:Kill()
                else
                    -- set the target rotation to match the surface rotation (if not jumping)
                    --if not self.Jumping then
                        local currentTargetRotation = self.RotationSpring.Target

                        --[[
                        if currentTargetRotation < 0 then
                            currentTargetRotation += 2*math.pi
                            self.RotationSpring.Position += 2*math.pi
                            self.RotationSpring.Target = currentTargetRotation
                        end]]
                        

                        local rotationRemainder = currentTargetRotation % (math.pi/2)
                        local nearestRightAngle

                        if surfaceRotation > 0 then
                            nearestRightAngle = rotationRemainder < math.pi/4 and currentTargetRotation - rotationRemainder or currentTargetRotation - math.pi/2 + rotationRemainder
                        else
                            nearestRightAngle = rotationRemainder < math.pi/4 and currentTargetRotation - rotationRemainder or currentTargetRotation + math.pi/2 - rotationRemainder
                        end

                        self.RotationSpring.Target = nearestRightAngle + surfaceRotation

                        if not self.Jumping then
                            self.RotationSpring.Speed = 50
                        end
                    --end

                    local groundOffset = math.abs(math.sin(surfaceRotation))
                    self:MoveTo(position, groundOffset)
                end
            else
                self:MoveTo(position, 0)
            end
        else
            self:MoveTo(position, 0)
        end
        
        if self.State == Character.Enum.State.Flying then
            self.RotationSpring.Target = -math.pi/8*velocity.Y/FLYING_TERMINAL_VELOCITY
        end  

        self.Grounded = isGrounded ~= nil
        self.Position = position
    end

    if self._gravitySwitched then
        self._gravitySwitched = false
        self:SwitchGravity()
    end

    self.Velocity = velocity
    --debug.profileend()
end

return Character