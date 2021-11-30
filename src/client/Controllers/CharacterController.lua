-- Imports
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Packages = ReplicatedStorage:WaitForChild("Packages")
local Components = script.Parent.Parent.Components

local CharacterComponent = require(Components.Character)
local Knit = require(Packages.Knit)
local Signal = require(Packages.Signal)
local Janitor = require(Packages.Janitor)

--[=[
    @class CharacterController
    @client

    Controls anything related to the character.
]=]
local CharacterController = Knit.CreateController {
    Name = "CharacterController";
}

--[=[
    @prop Character Character
    @within CharacterController

    The current Character component.
]=]
--[=[
    @prop CharacterPosition Vector3
    @within CharacterController

    The position of the character model, updated every frame that the character exists.
]=]
--[=[
    @prop CharacterEnum table
    @within CharacterController

    Same as ``Character.Enum``, from the Character Component.
]=]
--[=[
    @prop _janitor Janitor
    @within CharacterController
    @private

    Controls the cleanup of the character and all associated events.
]=]
--[=[
    @prop _timePassed number
    @within CharacterController
    @private

    The amount of time passed since the last character update. Since there is a fixed frame rate to guarantee the accuracy of the gameplay physics, 
    this number will always represent whatever is left over from the last physics update, to be continued on the next frame.
]=]
--[=[
    @prop CharacterAdded GoodSignal
    @within CharacterController
    @tag events

    Event that fires whenever a new character is created.

    Called with:
    ```
    character: Character -- The new character component
    characterPosition: Vector3 -- The spawn position of the character
    ```
]=]
--[=[
    @prop CharacterMoved GoodSignal
    @within CharacterController
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
    @prop CharacterDied GoodSignal
    @within CharacterController
    @tag events

    Event that fires when the character dies.

    Called with:
    ```
    position: Vector3 -- The true position of the character model at the moment it dies
    ```
]=]
--[=[
    @prop CharacterStateChanged GoodSignal
    @within Character
    @tag events

    Event that fires when the character changes states.

    Called with:
    ```
    state: StateChanged -- The new state of the character
    ```
]=]
--[=[
    @prop CharacterDestroyed GoodSignal
    @within CharacterController
    @tag events

    Event that fires when the character is destroyed. Is not called with anything.
]=]
function CharacterController:KnitInit()
    -- Create variables
    self.CharacterEnum = CharacterComponent.Enum;
    self.CharacterPosition = Vector3.new(0,0,0)
    self._janitor = Janitor.new()
    self._timePassed = 0
    self._died = workspace:WaitForChild("Oof")

    -- Create events
    self.Character = nil
    self.CharacterAdded = Signal.new()
    self.CharacterMoved = Signal.new()
    self.CharacterDied = Signal.new()
    self.CharacterDestroyed = Signal.new()
    self.CharacterStateChanged = Signal.new()

    -- step the character based on the fixed frame rate
    game:GetService("RunService").RenderStepped:Connect(function(dt)
        -- get the character
        local character = self.Character

        if character ~= nil then
            -- update the character
            character:Step(dt)

            -- update stored character position
            -- note that although we already checked if the character was nil, the character could have died during the character:Step(dt) call, so we have to check again
            if character ~= nil and character:IsAlive() then
                self.CharacterPosition = character.Position
            end
        end
    end)
end

function CharacterController:KnitStart()
    local InputController = Knit.GetController("InputController")

    InputController.StateChanged.Jump:Connect(function(state)
        local character = self.Character

        if character then
            character:Jump(state)
        end
    end)

    -- TEMP
    local MapController = Knit.GetController("MapController")
    MapController:LoadMap("TestMap")

    CharacterController.CharacterDestroyed:Connect(function()
        task.delay(1.3, function()
            MapController:ReloadMap()
            CharacterController:CreateCharacter()
        end)
    end)

    CharacterController:CreateCharacter()

    --[[
    UserInputService.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.Keyboard then
            if input.KeyCode == Enum.KeyCode.Q then
                MapController:ReloadMap()
                CharacterController:CreateCharacter()
            end
        end
    end)
    
    Knit.GetController("CameraController"):SetState(Knit.GetController("CameraController").Enum.State.Following)]]
end

--[=[
    @within CharacterController

    Creates a new character, and will destroy the current character if one already exists.
]=]
function CharacterController:CreateCharacter()
    -- verify that no character currently exists
    if self.Character then
        self.Character:Destroy()
    end

    -- get the start position of the character
    local MapController = Knit.GetController("MapController")
    local map = MapController.Map
    local startPosition = MapController.StartPosition

    if not map or not startPosition then
        warn("Tried to create a character, but no map is currently loaded.")
        return
    end

    -- create the new character and bind events
    local character = CharacterComponent.new(startPosition)
    
    self._janitor:Add(character.Moved:Connect(function(...)
        self.CharacterMoved:Fire(...)
    end))

    self._janitor:Add(character.Died:Connect(function(pos, win)
        if not win then
            self._died.TimePosition = 0.1
            self._died:Play()
        end
        
        self.CharacterDied:Fire(pos, win)
    end))

    self._janitor:Add(character.StateChanged:Connect(function(...)
        self.CharacterStateChanged:Fire(...)
    end))

    self._janitor:Add(character.Destroyed:Connect(function(...)
        if self.Character == character then
            self.Character = nil
        end

        self.CharacterDestroyed:Fire(...)

        -- cleanup all associated character events and data
        self._janitor:Cleanup()
    end))

    -- reset time passed
    self._timePassed = 0

    -- store character
    self.Character = character
    self.CharacterPosition = character.Position

    -- fire the added event
    self.CharacterAdded:Fire(character, character.Position)
end

return CharacterController