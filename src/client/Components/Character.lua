-- Imports
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Packages = ReplicatedStorage:WaitForChild("Packages")
local Assets = ReplicatedStorage:WaitForChild("Assets")
local Shared = ReplicatedStorage:WaitForChild("Shared")

local Signal = require(Packages.Signal)
local Spring = require(Packages.Spring)
local Linecast = require(Shared.Linecast)

local EffectComponent = require(script.Parent.Effect)

-- constants
local CHARACTER_BASE = Assets.Character
local CHARACTER_HEIGHT = CHARACTER_BASE.PrimaryPart.Size.Y
local CHARACTER_WIDTH = CHARACTER_BASE.PrimaryPart.Size.Z

local SPEED = 10.3761348898*2--*1.1
local MOVEMENT_DIRECTION = Vector3.new(0,0,1)
local MAX_SLOPE_ANGLE = math.rad(40)

local DEFAULT_GRAVITY = -8.76*SPEED--*(1.1^2)
local DEFUALT_JUMP_VELOCITY = math.sqrt(-4*2*DEFAULT_GRAVITY)
local DEFAULT_STEP_HEIGHT = 0.5
local DEFAULT_TERMINAL_VELOCITY = -2.6*SPEED

local FLYING_GRAVITY = -3*SPEED
local FLYING_TERMINAL_VELOCITY = -SPEED/1.25

local Z_VECTOR3 = Vector3.new(0,0,1)
local Y_VECTOR3 = Vector3.new(0,1,0)
local XZ_VECTOR3 = Vector3.new(1,0,1)
local DEFAULT_CFRAME = CFrame.fromMatrix(Vector3.new(), Vector3.new(0,0,1):Cross(Vector3.new(0,1,0)), Vector3.new(0,1,0), Vector3.new(0,0,-1))

--[=[
    @class Character

    Handles the movement physics and state of the created character model.
]=]
local Character = {}
Character.__index = Character

-- Enumerations
Character.Enum = {}

--[=[
    @interface State
    @tag enum
    @within Character
    
    .Default 0 -- Default movement state
    .Flying 1 -- Flying movement state

    Represents the movement state of the character.
]=]
Character.Enum.State = {
    Default = 0;
    Flying = 1;
}

--[=[
    @function new
    @within Character

    @param startPosition Vector3? -- Starting position of the character, defaults to <0,0,0>
    @param collisionGroup string? -- Collision group of the character, defaults to "Collidables"
    @param imageProps [State: string]? -- The image properties of the character, give each state its own image. Defaults to default character image properties.

    @return Character -- generated Character object

    Generates a character model at ``startPosition``, and builds a Character object to handle its physics. 
    You can update the collision group as time goes on by calling ``:SetCollisionGroup(string)``.
]=]

--[=[
    @prop ClassName string
    @within Character

    Will always be "Character". Used to check the class name of the object.
]=]
--[=[
    @prop State State
    @within Character

    The state of the character.
]=]
--[=[
    @prop Model Model
    @within Character

    Represents the character model of the Character. Contains the RootPart.
]=]
--[=[
    @prop RootPart BasePart
    @within Character

    Represents the root part of the character model, all of the physics originates at the position of the root part. The Position of the Character object is the same as the root part's position.
]=]
--[=[
    @prop Speed number
    @within Character

    The unsigned horizontal velocity of the character (in studs/second). Used as the basis for physics calculations.
]=]
--[=[
    @prop Position Vector3
    @within Character

    The position of the root part. Origin of all the physics calculations, regardless of state.
]=]
--[=[
    @prop Velocity Vector3
    @within Character

    The unsigned velocity of the player. What this means is that it does not depend on the direction of gravity, or the movement direction of the player. In effect, it is relative to the actual character model.
]=]
--[=[
    @prop Died GoodSignal
    @within Character
    @tag events

    Event that fires when the character dies.

    Called with:
    ```
    position: Vector3 -- The true position of the character model at the moment it dies
    ```
]=]
--[=[
    @prop Moved GoodSignal
    @within Character
    @tag events

    Event that fires when the character moves. Takes into account the player ground offset, and fires with the fake model position rather than the true player position,
    since the true player position is only necessary for physics calculations.

    Called with:
    ```
    newPosition: Vector3 -- The new position of the character model
    oldPosition: Vector3 -- The old position of the character model
    characterOffset: number -- The offset of the character to reach the ground (in world space)
    ```
]=]
--[=[
    @prop StateChanged GoodSignal
    @within Character
    @tag events

    Event that fires when the character changes states.

    Called with:
    ```
    state: StateChanged -- The new state of the character
    ```
]=]
--[=[
    @prop Destroyed GoodSignal
    @within Character
    @tag events

    Event that fires when the character is destroyed. Is not called with anything.
]=]
function Character.new(collisionGroup, imageProps)
    -- Pre-build
    local characterModel = CHARACTER_BASE:Clone()
    local rootPart = characterModel:WaitForChild("RootPart")
    local imageLabel = rootPart:WaitForChild("SurfaceGui"):WaitForChild("ImageLabel")
    characterModel.Parent = workspace -- temp

    local defaultImageProps = {
        [Character.Enum.State.Default] = "rbxassetid://8129619631";
        [Character.Enum.State.Flying] = "rbxassetid://8129619341";
    }

    imageProps = imageProps or defaultImageProps;

    for state, id in next, defaultImageProps do
        if not imageProps[state] then
            imageProps[state] = id
        end
    end

    imageLabel.Image = imageProps[Character.Enum.State.Default]

    local raycastParams = RaycastParams.new()
    raycastParams.CollisionGroup = collisionGroup or "Collidables"
    raycastParams.FilterDescendantsInstances = {}
    raycastParams.FilterType = Enum.RaycastFilterType.Blacklist

    -- Create Class object
    local self = setmetatable({}, Character)

    -- Add public properties
    self.ClassName = "Character"
    self.State = Character.Enum.State.Default
    self.Model = characterModel
    self.RootPart = rootPart
    self.Speed = SPEED
    self.Position = Vector3.new(0, 1, 0)
    self.Velocity = Vector3.new(0, 0, SPEED)
    
    -- Create events
    self.Died = Signal.new()
    self.Destroyed = Signal.new()
    self.Moved = Signal.new()
    self.StateChanged = Signal.new()

    -- Add private properties
    self._alive = true
    self._gravityDirection = -1
    self._stepHeight = DEFAULT_STEP_HEIGHT
    self._raycastParams = raycastParams
    self._timePassed = 0
    self._jumpTime = 0
    self._grounded = false
    self._imageProps = imageProps
    self._imageLabel = imageLabel
    self._walkEffect = EffectComponent.new(self, Vector3.new(0,math.sin(math.rad(150)),math.cos(math.rad(150))).Unit, "ParticleEmitter", "Walk", Vector3.new(-0.85,-1,-1))
    self._trailEffect = EffectComponent.new(self, Vector3.new(0,0,-1), "Trail", "Trail")
    self._trailEffect:Enable(false)
    self._flightTrailEffect = EffectComponent.new(self, Vector3.new(0,0,-1), "Trail", "FlightTrail", Vector3.new(0.9,0.6,-0.9))
    self._flightTrailEffect:Enable(false)
    
    local function clock()
        return self._timePassed
    end
    
    self._rotationSpring = Spring.new(0, clock)
    self._rotationSpring.Speed = 50

    -- Set default position
    characterModel:SetPrimaryPartCFrame(DEFAULT_CFRAME + self.Position)

    -- Return new object
    return self
end

--[=[
    @within Character

    Destroys the Character object by destroying the character model, cleaning up events, and killing its metatable.
]=]
function Character:Destroy()
    self.Model:Destroy()
    self.Died:Destroy()
    self.Moved:Destroy()
    self.StateChanged:Destroy()
    self.Destroyed:Fire()
    self.Destroyed:Destroy()
end

--[=[
    @within Character

    @param position Vector3? -- The position that the character is killed at

    Kills the Character, eventually calling ``:Destroy()`` on it aswell.
]=]
function Character:Kill(position)
    if self._alive then
        self._alive = false
        self.Died:Fire(position or self.Position)

        -- temp
        self:Destroy()
    end
end

-- Casting utility
--[=[
    @within Character

    @param collisionGroup string -- sets the collision group for the character, defaults to "Collidables"

    Sets the raycast collision group for the physics engine
]=]
function Character:SetCollisionGroup(collisionGroup)
    self._raycastParams.CollisionGroup = collisionGroup or "Collidables"
end

--[=[
    @within Character
    @private

    @param position Vector3 -- The position of the character when making the forward linecast.
    @param castLength number -- The length of the forward cast, keep in mind that this is added to half of the width of the character. Effectively beginning the cast from the character's side.

    @return RaycastResult? -- The result of casting a line of rays forwards
    @return number? -- The length of the smallest ray in the linecast

    Casts a line of rays forwards in a vertical fashion.
]=]
function Character:_castForwards(position, castLength)
    local halfWidth = CHARACTER_WIDTH/2
    local result, length = Linecast(position, MOVEMENT_DIRECTION*(castLength + halfWidth), Y_VECTOR3, CHARACTER_HEIGHT*0.99, 22, self._raycastParams)

    if result and length then
        return result, length - halfWidth
    end
end

--[=[
    @within Character
    @private

    @param position Vector3 -- The position of the character when making the forward linecast.
    @param castLength number -- The length of the upward cast, keep in mind that this is added to half of the height of the character. Effectively beginning the cast from the character's "head."

    @return RaycastResult? -- The result of casting a line of rays forwards
    @return number? -- The length of the smallest ray in the linecast

    Casts a line of rays up in a horizontal fashion.
]=]
function Character:_castUp(position, castLength)
    local halfHeight = CHARACTER_HEIGHT/2
    local result, length = Linecast(position, Vector3.new(0, -self._gravityDirection*(castLength + halfHeight), 0), Z_VECTOR3, CHARACTER_WIDTH, 22, self._raycastParams)

    if result and length then
        return result, length - halfHeight
    end
end

--[=[
    @within Character
    @private

    @param position Vector3 -- The position of the character when making the forward linecast.
    @param castLength number -- The length of the downward cast, keep in mind that this is added to half of the height of the character. Effectively beginning the cast from the character's "feet."

    @return RaycastResult? -- The result of casting a line of rays forwards
    @return number? -- The length of the smallest ray in the linecast

    Casts a line of rays down in a horizontal fashion.
]=]
function Character:_castDown(position, castLength)
    local halfHeight = CHARACTER_HEIGHT/2
    local result, length = Linecast(position, Vector3.new(0, self._gravityDirection*(castLength + CHARACTER_HEIGHT/2), 0), Z_VECTOR3, CHARACTER_WIDTH, 22, self._raycastParams)

    if result and length then
        return result, length - halfHeight
    end
end

--[=[
    @within Character
    @private

    @param position Vector3? -- The position of the character, defaults to self.Position

    @return number? -- The height the character can step up, if applicable. If this is not returned (i.e. if it is nil), then the character should not step up.

    Checks if the character should step up at a given position.
]=]
function Character:_shouldStepUp(position)
    -- defaults
    position = position or self.Position

    -- upcast, then forward cast, then downcast
    -- we need to go back by 0.05 studs because the upcast will otherwise go through the object we're trying to cast onto
    local upCastPosition = position - MOVEMENT_DIRECTION*0.05
    local upResult = self:_castUp(upCastPosition, self._stepHeight)

    if not upResult then
        -- we need to cast forwards from the upCastPosition + <0, stepHeight, 0>, because now we need to go forwards and then cast downwards to get the stepheight
        local forwardsCastPosition = upCastPosition - Vector3.new(0, self._gravityDirection*self._stepHeight, 0)
        local forwardsResult = self:_castForwards(forwardsCastPosition, 0.05 + self._stepHeight)

        -- ensure there is a platform we can step onto (with enough space), for slopes this also ensures it is <= 45 degrees
        if not forwardsResult then
            local downCastPosition = forwardsCastPosition + MOVEMENT_DIRECTION*(0.05 + self._stepHeight)
            local downResult, downCastLength = self:_castDown(downCastPosition, self._stepHeight)

            if downResult then
                return self._stepHeight - downCastLength + 0.01
            end
        end
    end

    return false
end

-- General physics
--[=[
    @within Character

    @param state State -- State to set the character to

    Sets the state of the character.
]=]
function Character:SetState(state)
    if state ~= self.State then
        -- set state
        self.State = state

        -- state specific updates
        if state == Character.Enum.State.Default then
            self._rotationSpring.Target = self._rotationSpring.Position

        elseif state == Character.Enum.State.Flying then
            self.Velocity = self.Velocity*XZ_VECTOR3 + Vector3.new(0, math.clamp(self.Velocity.Y, FLYING_TERMINAL_VELOCITY, -FLYING_TERMINAL_VELOCITY))
            self._rotationSpring.Target = -math.pi/8*self.Velocity.Y/FLYING_TERMINAL_VELOCITY
            self._rotationSpring.Position = self._rotationSpring.Target
        end

        -- update character image
        self._imageLabel.Image = self._imageProps[state]

        -- fire event
        self.StateChanged:Fire(state)
    end
end

--[=[
    @within Character
    @private

    @param position Vector3? -- The position of the character, defaults to self.Position
    @param velocity Vector3? -- The velocity of the character, defaults to self.Velocity

    @return RaycastResult? -- The result of the linecast towards the ground
    @return number -- The length of the linecast towards the ground
]=]
function Character:_isGrounded(position, velocity)
    -- defaults
    position, velocity = position or self.Position, velocity or self.Velocity

    -- cast downwards
    local downResult, downLength = self:_castDown(position, 0.2)

    -- return the downward cast if we're going down
    if downResult and velocity.Y < 0 then
        return downResult, downLength

    -- otherwise if we're flying and going up, return an upward cast
    elseif self.State == Character.Enum.State.Flying and velocity.Y > 0 then
        return self:_castUp(position, 0.2)
    end
end

--[=[
    @within Character
    
    @return boolean -- whether or not the character is grounded

    Returns whether or not the character was calculated to be grounded on the most recent physics step. 
    This should be used by any outside source trying to figure out if the character is grounded as it does not require any additional calculations by the internal physics engine.
]=]
function Character:IsGrounded()
    return self._grounded
end

--[=[
    @within Character
    
    @return boolean -- whether or not the character is alive

    Returns whether or not the character is alive. In other words, whether or not the physics engine has decide to kill the player or not.
]=]
function Character:IsAlive()
    return self._alive
end

--[=[
    @within Character

    Switches the direction of gravity. 
    The player will keep their velocity relative to the world space, meaning that since the ``Velocity`` property is relative to the character, its Y value will switch.
]=]
function Character:SwitchGravity()
    self._gravityDirection *= -1
    self.Velocity *= Vector3.new(1, -1, 1)
end

--[=[
    @within Character

    @param enabled boolean -- whether the character should jump or not

    Tells the internal physics engine whether or not the character should jump when they are grounded.
]=]
function Character:Jump(enabled)
    self.Jumping = enabled or false
end

--[=[
    @within Character
    @private

    @param position Vector3 -- The position the character model should be moved to
    @param groundOffset number -- The offset to shift the character model by so that they can reach the ground.

    Moves the character to a given position, calls the ``.Moved`` event with 
    ```
    (
        Vector3, -- The new position of the character, including the ground offset
        Vector3 -- The previous position of the character, including the ground offset
    )
    ```
]=]
function Character:_moveTo(position, groundOffset)
    -- get the last position of the character
    local lastPosition = self._lastPosition
    local newPosition = position + Vector3.new(0, self._gravityDirection*groundOffset, 0)

    -- update the internal last position
    self._lastPosition = newPosition

    -- update trail rotation
    self._flightTrailEffect:Rotate(DEFAULT_CFRAME*CFrame.Angles(self._rotationSpring.Position + math.pi, 0, 0))

    -- fire the .Moved event and set the character model's cframe to match the position and rotation of the character.
    self.Moved:Fire(newPosition, lastPosition, self._gravityDirection*groundOffset)
    self.Model:SetPrimaryPartCFrame(DEFAULT_CFRAME*CFrame.Angles(self._rotationSpring.Position, 0, 0) + newPosition)
end

-- edge case for this is probably if we hit the ground and are jumping, we should switch up the velocity?

--[=[
    @within Character
    @private

    @param position Vector3 -- the position of the character
    @param velocity Vector3 -- the velocity of the character
    @param dt number -- the time passed since the last internal physics update

    @return Vector3 -- the new calculated position of the character

    The core movement physics updating system for the Character object. 
    It calculates where the character should now be given a current position, velocity, and an amount of time passed.

    If the character hits something and the physics system determines that the character should die, it will call the ``:Kill()`` function with the current physics position.
]=]
function Character:_updatePosition(position, velocity, dt)
    debug.profilebegin("UpdatePosition")

    -- get various values that are reused
    local xVelocity, yVelocity = (velocity*MOVEMENT_DIRECTION).Magnitude, velocity.Y
    local state = self.State
    local gravityDirection = Vector3.new(0, self._gravityDirection, 0)

    -- check if we can go up if our velocity indicates we're moving up
    if yVelocity > 0 then
        local upCastLength = yVelocity*dt
        local upResult, upResultLength = self:_castUp(position, upCastLength)

        -- kill the player if they hit kill block or the ceiling
        if upResult and (upResult.Instance.Name == "Kill" or state ~= Character.Enum.State.Flying) then
            self:Kill(position)
            return
        end

        position += -gravityDirection*(upResult and upResultLength or upCastLength)
    end

    -- move forwards as far as possible
    do
        local forwardCastLength = xVelocity*dt
        local forwardResult, forwardLength = self:_castForwards(position, forwardCastLength)

        if forwardResult then
            -- kill the player if they hit kill block
            if forwardResult.Instance.Name == "Kill" then
                self:Kill(position)
                return
            end

            -- try to step up
            local stepHeight = state == Character.Enum.State.Default and self:_shouldStepUp(position + MOVEMENT_DIRECTION*forwardLength)

            -- keep going if we can step up
            if stepHeight then
                -- get the amount of time actually spent moving, and adjust that amount for the rest of the casts
                local dtSpent = dt*(forwardLength/forwardCastLength)
                local newdt = dt - dtSpent
                dt = dtSpent

                -- move forwards by forwardsLength, add the stepHeight to our position, then re-cast to move the full distance
                position += MOVEMENT_DIRECTION*forwardLength - gravityDirection*stepHeight
                position = self:_updatePosition(position, velocity*XZ_VECTOR3, newdt)

            -- otherwise kill the player, they hit a wall larger than the step height
            else
                self:Kill(position)
                return
            end
            
        else
            -- move forwards by forwardCastLength
            position += MOVEMENT_DIRECTION*forwardCastLength
        end
    end

    -- move down as far as possible if our velocity indicates we are moving down
    if yVelocity < 0 then
        local downCastLength = -yVelocity*dt
        local downResult, downLength = self:_castDown(position, downCastLength)

        -- kill the player if they hit a kill block
        if downResult and downResult.Instance.Name == "Kill" then
            self:Kill(position)
            return
        end

        -- move down by the length of the downwards cast if it exists, otherwise move down the full distance
        if downResult and downLength then
            position += gravityDirection*downLength
        else
            position += gravityDirection*downCastLength
        end
    end


    -- return our position
    debug.profileend()
    return position
end

--[=[
    @within Character

    @param dt number -- The amount of time passed since the last physics step. This is not automatically calculated for debugging and other reasons.

    Updates the internal clock, and handles the core physics calculations of the Character object. 
    Moves the character model, determines whether or not the character is grounded, and rotates the model accordingly.
]=]
function Character:Step(dt)
    debug.profilebegin("CharacterStep")

    -- update the time passed for the internal clock
    self._timePassed += dt
    self._jumpTime += dt

    -- don't step if the character isn't alive
    if self._alive ~= true then
        return
    end

    -- get various values that are reused
    local velocity, speed = self.Velocity, self.Speed
    local jumping = self.Jumping

    -- calculate the velocity based on the current state of the character
    if self.State == Character.Enum.State.Default then
        -- move forwards
        velocity = velocity*Y_VECTOR3 + MOVEMENT_DIRECTION*speed

        -- if we're grounded and jumping, and not moving upwards, then change the velocity to go up
        if self:IsGrounded() and jumping and velocity.Y <= 0 then
            velocity = velocity*XZ_VECTOR3 + Vector3.new(0, DEFUALT_JUMP_VELOCITY*speed/SPEED, 0)
            self._jumpTime = 0

        -- otherwise apply gravity, rotate the character if we're not grounded
        else
            velocity += Vector3.new(0, dt*DEFAULT_GRAVITY*speed/SPEED, 0)

            if not self:IsGrounded() then
                self._rotationSpring.Target += self._gravityDirection*2.4*math.pi*dt
                self._rotationSpring.Speed = 125
            end
        end

        -- account for terminal velocity
        velocity = velocity*XZ_VECTOR3 + Vector3.new(0, math.max(velocity.Y, DEFAULT_TERMINAL_VELOCITY), 0)

    elseif self.State == Character.Enum.State.Flying then
        -- move forwards
        velocity = velocity*Y_VECTOR3 + MOVEMENT_DIRECTION*speed

        -- if we're jumping then accelerate upwards, otherwise accelerate downwards
        velocity += Vector3.new(0, (self.Jumping and -1 or 1)*dt*FLYING_GRAVITY*speed/SPEED, 0)

        -- account for terminal velocity
        velocity = velocity*XZ_VECTOR3 + Vector3.new(0, math.clamp(velocity.Y, FLYING_TERMINAL_VELOCITY, -FLYING_TERMINAL_VELOCITY), 0)
    end

    -- move the character
    local position = self:_updatePosition(self.Position, velocity, dt)

    if position and self:IsAlive() then
        -- check if the character is grounded
        local groundResult, groundDistance = self:_isGrounded(position, velocity)

        -- if we're moving downwards, but also grounded, then cancel out the downwards velocity and move the character to the ground
        if groundResult and groundDistance then
            position += Vector3.new(0, -math.sign(velocity.Y)*self._gravityDirection*groundDistance, 0)
            velocity *= XZ_VECTOR3

            -- in the default state, have the character match the rotation of the ground
            if self.State == Character.Enum.State.Default then
                -- get the normal and rotation of the surface the character is standing on
                local normal = groundResult.Normal
                local surfaceRotation = self._gravityDirection*math.atan2(normal.Z, -self._gravityDirection*normal.Y)

                -- if the surface rotation is greater than the max slope angle, kill the character
                if math.abs(surfaceRotation) > MAX_SLOPE_ANGLE + 0.01 then
                    self:Kill()
                    
                -- otherwise, set the target rotation to match the surface rotation
                else
                    local currentTargetRotation = self._rotationSpring.Target
                    local rotationRemainder = currentTargetRotation % (math.pi/2)
                    local nearestRightAngle

                    if surfaceRotation > 0 then
                        nearestRightAngle = rotationRemainder < math.pi/4 and currentTargetRotation - rotationRemainder or currentTargetRotation - math.pi/2 + rotationRemainder
                    else
                        nearestRightAngle = rotationRemainder < math.pi/4 and currentTargetRotation - rotationRemainder or currentTargetRotation + math.pi/2 - rotationRemainder
                    end

                    self._rotationSpring.Target = nearestRightAngle + surfaceRotation

                    if not self.Jumping then
                        self._rotationSpring.Speed = 50
                    end

                    local groundOffset = math.abs(math.sin(surfaceRotation))
                    self:_moveTo(position, groundOffset)
                end

            -- otherwise just move the character to the new position
            else
                self:_moveTo(position, 0)
            end

        -- otherwise just move the character to the new position
        else
            self:_moveTo(position, 0)
        end
        
        -- if we're flying then calculate the rotation based on the vertical velocity of the character.
        if self.State == Character.Enum.State.Flying then
            self._rotationSpring.Target = -math.pi/8*velocity.Y/FLYING_TERMINAL_VELOCITY
        end  

        -- update internal and external variables
        self._grounded = groundResult ~= nil
        self.Position = position
        self.Velocity = velocity

        -- effects
        if self:IsAlive() then
            self._walkEffect:Enable(self._grounded or self._jumpTime < 0.0425)

            if self.State == Character.Enum.State.Default then
                self._trailEffect:Enable(self.Velocity.Magnitude > self.Speed*2)
                self._flightTrailEffect:Enable(false)

            elseif self.State == Character.Enum.State.Flying then
                self._trailEffect:Enable(false)
                self._flightTrailEffect:Enable(true)
            end
        end
    end

    debug.profileend()
end

-- return the Character component
return Character