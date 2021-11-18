-- Imports
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Packages = ReplicatedStorage:WaitForChild("Packages")
local Assets = ReplicatedStorage:WaitForChild("Assets")
local Shared = ReplicatedStorage:WaitForChild("Shared")

local Signal = require(Packages.Signal)
local Linecast = require(Shared.Linecast)

local MOVEMENT_DIRECTION = Vector3.new(0,0,1)
local CHARACTER_BASE = Assets.Character
local DEFAULT_SPEED = 10.3761348898*2
local DEFAULT_GRAVITY = -8.76*DEFAULT_SPEED
local DEFAULT_JUMP_VELOCITY = math.sqrt(-8*DEFAULT_GRAVITY)
local DEFAULT_STEP_HEIGHT = 0.5
local TERMINAL_VELOCITY = -2.6*DEFAULT_SPEED
local CHARACTER_HEIGHT = CHARACTER_BASE.PrimaryPart.Size.Y
local CHARACTER_WIDTH = CHARACTER_BASE.PrimaryPart.Size.Z

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
function Character:IsGrounded(position)
    return self:CastDown(position or self.Position, 0.1)
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

function Character:Jump(enabled)
    self.Jumping = enabled or false
end

function Character:MoveTo(position)
    local currentPosition = self.Position
    local offset = (position - currentPosition).Magnitude

    self.Moved:Fire(position, currentPosition, offset)
    self.Model:SetPrimaryPartCFrame(DEFAULT_CFRAME + position)
end

-- edge case for this is probably if we hit the ground and are jumping, we should switch up the velocity?
function Character:UpdatePosition(position, velocity, dt)
    local xVelocity = (velocity*MOVEMENT_DIRECTION).Magnitude
    local yVelocity = velocity.Y

    if yVelocity > 0 then
        -- check if we can go up first
        do
            local upCastLength = yVelocity*dt
            local upResult = self:CastUp(position, upCastLength)

            -- kill the player if they hit a ceiling
            if upResult then
                self:Kill()
                return
            end

            position += -self.GravityDirection*Vector3.new(0, upCastLength, 0)
        end

        -- now check if we can go forwards
        do
            local forwardCastLength = xVelocity*dt
            local forwardResult, forwardLength = self:CastForwards(position, forwardCastLength)

            -- if we hit something, check if we can step up, otherwise kill the player
            if forwardResult then
                -- try to step up
                local stepHeight = self:ShouldStepUp(self.Position + MOVEMENT_DIRECTION*forwardLength)

                -- keep going if we can step up
                if stepHeight then
                    -- get the amount of time actually spent moving
                    local newdt = dt - dt*(forwardLength/forwardCastLength)

                    -- move forwards by forwardsLength, add the stepHeight to our position, then re-cast to move the full distance
                    position += MOVEMENT_DIRECTION*forwardLength + Vector3.new(0, stepHeight, 0)
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

    elseif yVelocity < 0 then
        -- check if we can go forwards first
        do
            local forwardCastLength = xVelocity*dt
            local forwardResult, forwardLength = self:CastForwards(position, forwardCastLength)

            if forwardResult then
                -- try to step up
                local stepHeight = self:ShouldStepUp(self.Position + MOVEMENT_DIRECTION*forwardLength)

                -- keep going if we can step up
                if stepHeight then
                    -- get the amount of time actually spent moving, and adjust that amount for the rest of the casts
                    local dtSpent = dt*(forwardLength/forwardCastLength)
                    local newdt = dt - dtSpent
                    dt = dtSpent

                    -- move forwards by forwardsLength, add the stepHeight to our position, then re-cast to move the full distance
                    position += MOVEMENT_DIRECTION*forwardLength + Vector3.new(0, stepHeight, 0)
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
            local stepHeight = self:ShouldStepUp(self.Position + MOVEMENT_DIRECTION*forwardLength)

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

    return position
end

function Character:Step(dt)
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

        -- otherwise apply gravity
        else
            velocity += Vector3.new(0, dt*DEFAULT_GRAVITY*self.Speed/DEFAULT_SPEED, 0)
        end
    elseif self.State == Character.Enum.State.Flying then
        print("flying")
    end

    -- account for terminal velocity
    velocity = velocity*XZ_VECTOR3 + Vector3.new(0, math.max(velocity.Y, TERMINAL_VELOCITY), 0)

    -- move the character and update velocity
    local position = self:UpdatePosition(self.Position, velocity, dt)

    if position then
        -- check if the character is grounded
        local isGrounded, groundDistance = self:IsGrounded(position)

        -- if we're moving downwards, but also grounded, then cancel out the downwards velocity and move the character to the ground
        if isGrounded and groundDistance and velocity.Y < 0 then
            velocity *= XZ_VECTOR3
            position += Vector3.new(0, self.GravityDirection*groundDistance, 0)
        end

        self.Grounded = isGrounded ~= nil
        self:MoveTo(position)
        self.Position = position
    end

    self.Velocity = velocity
end

return Character