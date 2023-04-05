-- Imports
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Packages = ReplicatedStorage:WaitForChild("Packages")
local Assets = ReplicatedStorage:WaitForChild("Assets")

local TrailBase = Assets.TrailBase
local Janitor = require(Packages.Janitor)

-- Constants
local X_VECTOR3 = Vector3.new(1,0,0)
local BASE_EFFECTS = {
    Walk = { -- Character walk effect
        Texture = "rbxassetid://8131342280";
        Size = NumberSequence.new{
            NumberSequenceKeypoint.new(0, 0.15),
            NumberSequenceKeypoint.new(1, 0)
        };
        Transparency = NumberSequence.new{
            NumberSequenceKeypoint.new(0, 0),
            NumberSequenceKeypoint.new(1, 1)
        };
        Lifetime = NumberRange.new(0.2, 0.4),
        SpreadAngle = Vector2.new(30, 0);
        Rate = 100;
        Speed = NumberRange.new(4,10);
        EmissionDirection = Enum.NormalId.Front;
        Acceleration = Vector3.new(0, -35, 0);
    };
    Trail = { -- Character trail effect
        Transparency = NumberSequence.new{
            NumberSequenceKeypoint.new(0, 0),
            NumberSequenceKeypoint.new(1, 1)
        };
        Lifetime = 0.3
    };
    FlightTrail = {
        Transparency = NumberSequence.new{
            NumberSequenceKeypoint.new(0, 0.15),
            NumberSequenceKeypoint.new(1, 1)
        };
        Lifetime = 0.3;
    };
    Death = { -- Character death effect
        Texture = "rbxassetid://8131342280";
        Color = ColorSequence.new{
            ColorSequenceKeypoint.new(0, Color3.new(0,1,1)),
            ColorSequenceKeypoint.new(1, Color3.new(0,1,1))
        };
        Transparency = NumberSequence.new{
            NumberSequenceKeypoint.new(0, 0),
            NumberSequenceKeypoint.new(1, 1)
        };
        Size = NumberSequence.new{
            NumberSequenceKeypoint.new(0, 0.25),
            NumberSequenceKeypoint.new(1, 0.05)
        };
        SpreadAngle = Vector2.new(180, 0);
        Lifetime = NumberRange.new(0.2, 0.5),
        Rate = 250;
        Speed = NumberRange.new(20,30);
        EmissionDirection = Enum.NormalId.Front;
    }
}

--[=[
    @class Effect
    
    Creates and handles effects in the world space.
]=]
local Effect = {}
Effect.__index = Effect

--[[
    @param type string -- the ClassName of the object to insert

    Builds an effect object from a given class name
]]
local function buildObject(type)
    if type == "ParticleEmitter" then
        local object = Instance.new("Part")
        object.Anchored = true
        object.CanCollide = false
        object.CanTouch = false
        object.Size = Vector3.new(0.1,0.1,0.1)
        object.Transparency = 1

        local effectObject = Instance.new(type)

        return object, effectObject

    elseif type == "Trail" then
        local object = TrailBase:Clone()
        local effectObject = object:FindFirstChild("Trail") or object:WaitForChild("Trail")

        return object, effectObject
    end
end

--[=[
    @within Effect

    @param location Character|Vector3 -- The location in world space, or a Character object, that the effect should be tied to
    @param direction Vector3 -- The lookVector of the effect, all effects are front-facing
    @param type ClassName -- The class name of the effect to create
    @param props [string: any?] | string -- The properties of the effect object created from the given type. If a string is provided it uses BASE_EFFECTS[props]
    @param offset Vector3? -- The offset of the effect, in the world space.
    @param timeAlive number? -- The duration the effect should last for, defaults to inf

    @return Effect -- the Effect object created

    Creates a new Effect, can either be in the world space (Vector3), or tied to a ``Character`` object.
]=]
function Effect.new(location, direction, type, props, offset, timeAlive)
    offset = offset or Vector3.new()

    local self = setmetatable({}, Effect)

    -- build basic object
    local angle = CFrame.fromMatrix(Vector3.new(), X_VECTOR3, direction:Cross(-X_VECTOR3), -direction)

    -- build effect
    local object, effectObject = buildObject(type)

    if typeof(props) == "string" then
        props = BASE_EFFECTS[props]
    end
    
    for prop, value in next, props do
        effectObject[prop] = value
    end

    object.CFrame = angle
    effectObject.Parent = object

    -- public variables
    self.Object = effectObject

    -- private variables
    self._angle = angle
    self._offset = offset
    self._janitor = Janitor.new()

    -- handle object stuff
    if typeof(location) == "Vector3" then
        object.CFrame = angle + location + offset

    elseif typeof(location) == "table" and location.ClassName == "Character" and location:IsAlive() then
        local character = location
        
        self._janitor:Add(character.Moved:Connect(function(position)
            if self._rotation then
                object.CFrame = self._rotation * CFrame.new(offset) + position
            else
                object.CFrame = angle + offset + position
            end
        end))

        self._janitor:Add(character.Died:Connect(function()
            self.Enabled = false;
        end))

        self._janitor:Add(character.Destroyed:Connect(function()
            self:Destroy();
        end))
    end

    object.Parent = workspace

    -- delete after a certain amount of time
    if timeAlive ~= nil then
        task.delay(timeAlive, function()
            if self and object ~= nil then
                self:Enable(false)
                task.delay(3, function()
                    self:Destroy()
                end)
            end
        end)
    end

    -- cleanup stuff
    self._janitor:Add(object)

    return self
end

--[=[
    @within Effect

    Destroys and cleans up the Effect.
]=]
function Effect:Destroy()
    self._janitor:Cleanup()
    self._janitor:Destroy()
    setmetatable(self, nil)
end

--[=[
    @within Effect
    
    @param enabled boolean -- Whether or not the effect is enabled

    Disables/Enables the effect
]=]
function Effect:Enable(enabled)
    self.Object.Enabled = enabled
end

--[=[
    @within Effect

    @param rotation CFrame -- the new rotation of the effect object

    Sets the rotation of an effect, to be set the next time the character moves. This can only be used if the effect is tied to a ``Character`` component.
]=]
function Effect:Rotate(rotation)
    self._rotation = rotation
end

--[=[
    @within Effect

    @param offset Vector3? -- the new offset of the effect object, defaults to <0,0,0>

    Sets the offset of an effect, to be set the next time the character moves. This can only be used if the effect is tied to a ``Character`` component.
]=]
function Effect:SetOffset(offset)
    self._offset = offset or Vector3.new()
end

-- return Component
return Effect