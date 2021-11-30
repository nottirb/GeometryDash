-- Imports
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Packages = ReplicatedStorage:WaitForChild("Packages")
local Components = script.Parent.Parent.Components

local MapComponent = require(Components.Map)
local Maps = ReplicatedStorage:WaitForChild("Maps")
local Knit = require(Packages.Knit)

-- Constants
local LEFT_VISION = 2
local RIGHT_VISION = 15

--[=[
    @class MapController
    @client

    Controls anything related to the map.
]=]
local MapController = Knit.CreateController {
    Name = "MapController"
}

--[=[
    @prop Map Map?
    @within MapController

    The current ``Map`` component.
]=]
--[=[
    @prop StartPosition Vector3?
    @within MapController

    The starting position on the current map.
]=]
--[=[
    @prop Chunks Chunks
    @within MapController

    The chunks of the current map. See: ``Map`` for the ``Chunks`` interface.
]=]
function MapController:KnitInit()
    -- store variables
    self.Map = nil
    self.StartPosition = nil
    self._music = workspace:WaitForChild("Music")
end

function MapController:KnitStart()
    local CharacterController = Knit.GetController("CharacterController")

    CharacterController.CharacterMoved:Connect(function(position)
        local character = CharacterController.Character
        local map = self.Map

        if character ~= nil and character:IsAlive() and map ~= nil then
            -- move the map according to character movement
            map:Move(character, position)
        end
    end)

    CharacterController.CharacterDied:Connect(function(_, win)
        if win then
            if self.Map ~= nil then
                self.Map._attempt = 0
            end
        end
        self._music:Stop()
    end)

    CharacterController.CharacterStateChanged:Connect(function(...)
        self:ChangeState(...)
    end)
end

function MapController:ChangeState(state, speed)
    local CharacterController = Knit.GetController("CharacterController")

    local map = self.Map
    local _state = self._state

    if map ~= nil and state ~= _state then
        local statics = map.StaticsFolder
        if statics ~= nil then
            local floors = statics:FindFirstChild("Floor")
            local ceilings = statics:FindFirstChild("Ceiling")
            local stateName = state == CharacterController.CharacterEnum.State.Default and "Default" or "Flying"

            local tweenInfo = TweenInfo.new(speed or 0.3, Enum.EasingStyle.Quint)

            if floors then
                for _, floor in ipairs(floors:GetChildren()) do
                    if floor.Name == stateName then
                        local tween = TweenService:Create(floor, tweenInfo, {
                            CFrame = floor.CFrame + Vector3.new(0,25,0);
                        })

                        tween:Play()
                    else
                        local tween = TweenService:Create(floor, tweenInfo, {
                            CFrame = floor.CFrame - Vector3.new(0,25,0);
                        })

                        tween:Play()
                    end
                end
            end

            if ceilings then
                for _, ceiling in ipairs(ceilings:GetChildren()) do
                    if ceiling.Name == stateName then
                        local tween = TweenService:Create(ceiling, tweenInfo, {
                            CFrame = ceiling.CFrame - Vector3.new(0,25,0);
                        })

                        tween:Play()
                    else
                        local tween = TweenService:Create(ceiling, tweenInfo, {
                            CFrame = ceiling.CFrame + Vector3.new(0,25,0);
                        })

                        tween:Play()
                    end
                end
            end
        end

        self._state = state
    end
end

--[=[
    @within MapController

    @param mapName string -- The name of the map to load
    @param leftVision number -- The vision the player should have to the left, defaults to LEFT_VISION
    @param rightVision number -- The vision the player should have to the left defaults to RIGHT_VISION

    @return Map? -- the map loaded, returns nil if the map with the given name does not exist
    
    Loads a map from a base located in ``ReplicatedStorage/Maps``. Displays a warning if the map does not exist.
]=]
function MapController:LoadMap(mapName, leftVision, rightVision)
    local mapFolder = Maps:FindFirstChild(mapName)

    if mapFolder then
        -- create and store the map component
        local map = MapComponent.new(mapFolder, leftVision or LEFT_VISION, rightVision or RIGHT_VISION)

        -- update local state
        local CharacterController = Knit.GetController("CharacterController")
        self._state = CharacterController.CharacterEnum.State.Default

        self:ReloadMap(map)
        self.Map = map

        return map
    else
        warn("Tried to load a map that does not exist:", mapName)
    end
end

--[=[
    @within MapController

    @param map Map? -- The map to use, only necessary if you want to reload a specific Map object. Defaults to ``self.Map``.
    
    Reloads a Map around the starter position of the Map. Nearby chunks load instantly and do not run any animations.
]=]
function MapController:ReloadMap(map)
    map = map or self.Map

    if map ~= nil then
        local CharacterController = Knit.GetController("CharacterController")

        local chunks, startPosition = map:Reload()
        self.StartPosition = startPosition
        self.Chunks = chunks

        self._music.TimePosition = 13.25
        self._music:Play()

        self:ChangeState(CharacterController.CharacterEnum.State.Default, 0)
    end
end

return MapController