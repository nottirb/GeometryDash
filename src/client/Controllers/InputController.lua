-- Imports
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Packages = ReplicatedStorage:WaitForChild("Packages")

local Knit = require(Packages.Knit)
local Signal = require(Packages.Signal)

--[=[
    @class InputController
    @client

    Controls anything related to player input.
]=]
local InputController = Knit.CreateController {
    Name = "InputController"
}

--[=[
    @prop _states [string: boolean]
    @within InputController

    :::warning
    This property is **private**, but has not been identified as such to make it easier to understand the ``StateChanged`` property regardless of docs settings. 
    You should use the ``:IsActive()`` method to check states.
    :::

    Holds all of the input related states (controlled by pressing/holding an input using any of the selected keybinds).
]=]
--[=[
    @prop StateChanged [string: GoodSignal]
    @within InputController
    @tag events

    Holds all of the events which are called whenever a state changes.

    For instance, you might have a boolean state called ``Jump``, which is also a member of ``InputController._states``.
    In this case ``Jump`` would also be a member of ``InputController, and would be fired whenever the ``Jump`` state changes from true -> false, or false -> true.

    All events here will be called with:
    ```
    boolean active -- whether or not the state is active (key/button pressed or not)
    ```
]=]
--[=[
    @prop Keybinds [string: any?[]]
    @within InputController

    Holds all of the keybind data. Keybind data is setup such that you have a string equal to any number of ``Enum.UserInputType``'s or ``Enum.KeyCode``'s.
]=]
--[=[
    @prop PrimaryInput string
    @within InputController

    Explicity states what the primary input is, which can be any one of the following:
        - "Mouse"
        - "Gamepad"
        - "Touch"
    
    Note that the keyboard is not considered to be a "primary input", as it is not directly used to interact with the UI or world space.
]=]
function InputController:KnitInit()
    -- Setup states
    local states = {
        Jump = false;
    }

    -- Setup state change events
    local stateChanged = {}
    for stateName, _ in next, states do
        stateChanged[stateName] = Signal.new()
    end

    -- Store state and event data
    self._states = states
    self.StateChanged = stateChanged

    -- Primary input type
    self.PrimaryInputChanged = Signal.new()
    self.PrimaryInput = self:_determinePrimaryInput()
    self._lastInputType = nil
end

function InputController:KnitStart()
    -- Load Keybinds, ideally this would be loaded via a service that stores player keybind data globally, but since this project is temporary, this is fine.
    local keybinds = {}

    keybinds.Jump = {
        Enum.KeyCode.Space, 
        Enum.KeyCode.Up,
        Enum.KeyCode.ButtonA,
        Enum.UserInputType.MouseButton1,
        Enum.UserInputType.Touch
    }

    self.Keybinds = keybinds

    -- Connect keybinds to input
    local function inputSwitched(input, _gameProcessed, active)
        -- get input data for faster parsing
        local inputType = input.UserInputType
        local isKeyboard = inputType == Enum.UserInputType.Keyboard
        local isGamepad = inputType == Enum.UserInputType.Gamepad1
        local keyCode = input.KeyCode

        -- check all keybinds for changes
        for stateName, keybindData in next, keybinds do
            if self._states[stateName] ~= active then
                -- iterate through keybind data to check for changes
                for _, keybindInput in ipairs(keybindData) do
                    if (keybindInput == inputType)
                    or (isKeyboard and keybindInput == keyCode)
                    or (isGamepad and keybindInput == keyCode) then
                        -- update state
                        self._states[stateName] = active
                        self.StateChanged[stateName]:Fire(active)

                        -- break out of the loop
                        break
                    end
                end
            end
        end

        -- recalculate primary input
        self:_determinePrimaryInput(inputType)
    end

    -- UserInputService binds
    UserInputService.InputBegan:Connect(function(input, _gameProcessed)
        -- keybinds and primary input detection
        inputSwitched(input, _gameProcessed, true)
    end)

    UserInputService.InputEnded:Connect(function(input, _gameProcessed)
        -- keybinds and primary input detection
        inputSwitched(input, _gameProcessed, false)
    end)

    UserInputService.InputChanged:Connect(function(input, _gameProcessed)
        -- primary input detection
        self:_determinePrimaryInput(input.UserInputType)
    end)

    -- temp
    print(self.PrimaryInput)
    self.PrimaryInputChanged:Connect(function(primaryInput, oldPrimaryInput)
        print("New:", primaryInput, "Old:", oldPrimaryInput)
    end)
end

function InputController:_determinePrimaryInput(inputType)
    -- local variables
    local currentPrimaryInput = self.PrimaryInput
    local newPrimaryInput

    -- validate input type, don't recalculate if the input type didn't change
    if self._lastInputType == inputType and currentPrimaryInput ~= nil then
        return currentPrimaryInput

    else
        self._lastInputType = inputType
    end

    -- add bias based on input type, if present
    if inputType ~= nil then
        -- we only care about certain input types when calculating a new input based on a bias
        if inputType == Enum.UserInputType.Touch then
            newPrimaryInput = "Touch"

        elseif inputType == Enum.UserInputType.Gamepad1 then
            newPrimaryInput = "Gamepad"

        elseif inputType == Enum.UserInputType.MouseButton1 
                or inputType == Enum.UserInputType.MouseButton2 
                or inputType == Enum.UserInputType.MouseButton3
                or inputType == Enum.UserInputType.MouseMovement
                or inputType == Enum.UserInputType.MouseWheel then
                    newPrimaryInput = "Mouse"
        end
        
    -- otherwise make some unbiased determinations
    else
        newPrimaryInput = UserInputService.MouseEnabled and "Mouse" 
            or UserInputService.GamepadEnabled and "Gamepad" 
            or UserInputService.TouchEnabled and "Touch" 
            or "Mouse"
    end

    -- update primary input if we determined that we should use a new input
    if newPrimaryInput ~= nil and currentPrimaryInput ~= newPrimaryInput then
        self.PrimaryInputChanged:Fire(newPrimaryInput, currentPrimaryInput)
        self.PrimaryInput = newPrimaryInput
    end

    -- return the updated primary input, if we couldn't determine a new primary input, return the current one
    return newPrimaryInput or currentPrimaryInput
end

--[=[
    @within InputController

    @param stateName string -- the state to check

    @return boolean? -- whether or not the state is active

    Checks if a given input state is active or not (whether or not a key/button associated with a keybind is pressed or not).
    Returns nil if the state does not exist
]=]
function InputController:IsActive(stateName)
    return self._states[stateName]
end

return InputController