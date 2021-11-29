local PhysicsService = game:GetService("PhysicsService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Packages = ReplicatedStorage:WaitForChild("Packages")

local Knit = require(Packages.Knit)

local WAY_OUT_THERE = CFrame.new(100000,100000,100000)

local Map = {}
Map.__index = Map

local actionObjects = "Actions"
local collidableObjects = "Collidables"

Map.CollisionGroups = {
    Actions = actionObjects;
    Collidables = collidableObjects
}

local currentMap

function Map.new(baseMap, leftVision, rightVision)
    -- return existing map if the base map is the same as the current base map
    if currentMap and currentMap._base == baseMap then
        return currentMap
    
    -- otherwise if we have an existing map, destroy it
    elseif currentMap then
        currentMap:Destroy()
    end

    -- create Map object
    local self = setmetatable({}, Map)

    -- get/build objects
    local staticsFolder = baseMap.Statics:Clone()
    local baseChunks = baseMap.Chunks
    local chunksFolder = Instance.new("Folder")

    for _, staticInstance in ipairs(staticsFolder:GetDescendants()) do
        if staticInstance:IsA("BasePart") then
            PhysicsService:SetPartCollisionGroup(staticInstance, collidableObjects)
        end
    end

    chunksFolder.Parent = workspace
    staticsFolder.Parent = workspace

    -- build chunks data
    local chunks = {}

    for _, baseFolder in ipairs(baseChunks:GetChildren()) do
        -- build this chunk's data
        local chunkFolder = baseFolder:Clone()
        local chunkIndex = tonumber(chunkFolder.Name)
        local chunkData = {
            Folder = chunkFolder;
            Actions = {};
            Collidables = chunkFolder.Collidables:GetChildren();
            Uncollidables = chunkFolder.Uncollidables:GetChildren();
        }

        for index, part in ipairs(chunkFolder.Actions:GetChildren()) do
            local gui = part:FindFirstChild("SurfaceGui")
            local image = gui and gui:FindFirstChild("ImageLabel")

            if image then
                image.ImageTransparency = 1
            end

            chunkData.Actions[index] = {
                Instance = part;
                CFrame = part.CFrame;
                Image = image;
            }

            -- move super far away
            part.CFrame = WAY_OUT_THERE
        end

        for index, part in ipairs(chunkFolder.Collidables:GetChildren()) do
            local gui = part:FindFirstChild("SurfaceGui")
            local image = gui and gui:FindFirstChild("ImageLabel")

            if image then
                image.ImageTransparency = 1
            end

            chunkData.Collidables[index] = {
                Instance = part;
                CFrame = part.CFrame;
                Image = image;
            }

            -- move super far away
            part.CFrame = WAY_OUT_THERE
        end

        for index, part in ipairs(chunkFolder.Uncollidables:GetChildren()) do
            local gui = part:FindFirstChild("SurfaceGui")
            local image = gui and gui:FindFirstChild("ImageLabel")

            if image then
                image.ImageTransparency = 1
            end

            chunkData.Uncollidables[index] = {
                Instance = part;
                CFrame = part.CFrame;
                Image = image;
            }

            -- move super far away
            part.CFrame = WAY_OUT_THERE
        end

        -- store chunk data
        chunkFolder.Parent = chunksFolder
        chunks[chunkIndex] = chunkData
    end

    -- store objects
    self._currentChunk = 1;
    self._base = baseMap
    self._settings = require(baseMap.Settings)
    self._chunks = chunks
    self._leftVision = leftVision or 5
    self._rightVision = rightVision or 10
    self._insertAnimation = function() end
    self._deleteAnimation = function() end

    self.Chunks = {}
    self.StaticsFolder = staticsFolder
    self.ChunksFolder = chunksFolder

    currentMap = self

    return self
end

function Map:Destroy()
    self.StaticsFolder:Destroy()
    self.ChunksFolder:Destroy()
    self.Chunks = nil
    self._chunks = nil
    self._base = nil
    setmetatable(self, nil)
end

function Map:Reload()
    -- clear existing chunks
    for index, chunkData in next, self.Chunks do
        -- update part CFrame's
        for _, data in ipairs(chunkData.Actions) do
            data.Instance.CFrame = WAY_OUT_THERE
        end

        for _, data in ipairs(chunkData.Collidables) do
            data.Instance.CFrame = WAY_OUT_THERE
        end

        for _, data in ipairs(chunkData.Uncollidables) do
            data.Instance.CFrame = WAY_OUT_THERE
        end

        -- delete chunk data reference
        chunkData[index] = nil
    end

    -- load starter chunks
    local startPosition = self._settings.StartPosition
    local startChunk = (startPosition.Z - startPosition.Z%2)/2
    local newChunks = {}

    for chunkIndex = math.max(1, startChunk - self._leftVision), startChunk + self._rightVision do
        -- hard load chunk without any animations
        local chunkData = self._chunks[chunkIndex]

        -- build chunk data for this chunk (if data exists)
        if chunkData then
            -- update part CFrame's
            for _, data in ipairs(chunkData.Actions) do
                data.Instance.CFrame = data.CFrame
                
                if data.Image then
                    data.Image.ImageTransparency = 0
                end
            end
            
            for _, data in ipairs(chunkData.Collidables) do
                data.Instance.CFrame = data.CFrame
                
                if data.Image then
                    data.Image.ImageTransparency = 0
                end
            end

            for _, data in ipairs(chunkData.Uncollidables) do
                data.Instance.CFrame = data.CFrame

                if data.Image then
                    data.Image.ImageTransparency = 0
                end
            end

            -- store this chunk's data
            newChunks[chunkIndex] = chunkData
        end
    end

    -- update object information
    self._currentChunk = startChunk
    self.Chunks = newChunks

    local insertIndex, deleteIndex = 0, 0
    local insertAnimation, deleteAnimation

    for index, animationData in next, self._settings.AnimationZones do
        if index <= startChunk then
            local insert = animationData.Insert
            local delete = animationData.Delete

            if insert ~= nil and (insertAnimation == nil or index > insertIndex) then
                insertAnimation = insert
                insertIndex = index
            end
            
            if delete ~= nil and (deleteAnimation == nil or index > deleteIndex) then
                deleteAnimation = delete
                deleteIndex = index
            end
        end
    end

    self._deleteAnimation = deleteAnimation
    self._insertAnimation = insertAnimation

    return newChunks, startPosition
end

function Map:Move(character, newPosition)
    local newChunk = math.max(1, newPosition.Z - newPosition.Z%2)/2
    local currentChunk = self._currentChunk
    self._currentChunk = newChunk

    if newChunk > currentChunk then
        local delete = self._deleteAnimation
        local insert = self._insertAnimation

        -- remove chunks
        for chunkIndex = currentChunk - self._leftVision, newChunk - self._leftVision do
            if chunkIndex >= 1 then
                local chunkData = self.Chunks[chunkIndex]

                if chunkData ~= nil then
                    -- delete objects
                    for _, data in ipairs(chunkData.Collidables) do
                        task.spawn(delete, data.Instance, data.CFrame, data.Image)
                    end
        
                    for _, data in ipairs(chunkData.Actions) do
                        task.spawn(delete, data.Instance, data.CFrame, data.Image)
                    end
        
                    for _, data in ipairs(chunkData.Uncollidables) do
                        task.spawn(delete, data.Instance, data.CFrame, data.Image)
                    end

                    -- delete reference
                    self.Chunks[chunkIndex] = nil
                end
            end
        end

        -- add chunks
        for chunkIndex = currentChunk + self._rightVision, newChunk + self._rightVision do
            -- get chunk data
            local chunkData = self._chunks[chunkIndex]

            -- build chunk data for this chunk (if data exists)
            if chunkData then
                -- build actions, collidables, and uncollidables and make them visible
                for _, data in ipairs(chunkData.Collidables) do
                    PhysicsService:SetPartCollisionGroup(data.Instance, collidableObjects)
                    task.spawn(insert, data.Instance, data.CFrame, data.Image)
                end

                for _, data in ipairs(chunkData.Actions) do
                    PhysicsService:SetPartCollisionGroup(data.Instance, actionObjects)
                    task.spawn(insert, data.Instance, data.CFrame, data.Image)
                end

                for _, data in ipairs(chunkData.Uncollidables) do
                    task.spawn(insert, data.Instance, data.CFrame, data.Image)
                end

                -- store this chunk's data
                self.Chunks[chunkIndex] = chunkData
            end
        end

        -- update animations
        for chunkIndex = currentChunk + 1, newChunk do
            local animationData = self._settings.AnimationZones[chunkIndex]

            if animationData ~= nil then
                local newInsert = animationData.Insert
                local newDelete = animationData.Delete
                local reached = animationData.ZoneReached

                if newInsert ~= nil then
                    self._insertAnimation = newInsert
                end

                if newDelete ~= nil then
                    self._deleteAnimation = newDelete
                end

                if reached ~= nil then
                    task.spawn(reached, character, self)
                end
            end
        end
    end
end

return Map