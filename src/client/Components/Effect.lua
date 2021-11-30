local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Packages = ReplicatedStorage:WaitForChild("Packages")
local Assets = ReplicatedStorage:WaitForChild("Assets")

local TrailBase = Assets.TrailBase
local Janitor = require(Packages.Janitor)

local X_VECTOR3 = Vector3.new(1,0,0)
local BASE_EFFECTS = {
    Walk = {
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
    Trail = {
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
    Death = {
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

local Effect = {}
Effect.__index = Effect

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

function Effect:Destroy()
    self._janitor:Cleanup()
    self._janitor:Destroy()
    setmetatable(self, nil)
end

function Effect:Enable(enabled)
    self.Object.Enabled = enabled
end

function Effect:Rotate(rotation)
    self._rotation = rotation
end

function Effect:SetOffset(offset)
    self._offset = offset or Vector3.new()
end

return Effect