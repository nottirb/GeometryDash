local rays = {}
local visualized = {}

local folder = Instance.new("Folder")
folder.Parent = workspace

local function clearVisualizations()
    for i = #visualized, 1, -1 do
        local rayPart = visualized[i]
        rayPart.CFrame = CFrame.new(1000000,10000000,1000000)
        rays[#rays+1] = rayPart
    end
end

local function visualizeRay(start, finish, length) 
    local rayPart

    length = length or (finish - start).Magnitude

    if #rays > 0 then
        rayPart = rays[#rays]
        rays[#rays] = nil
    else
        rayPart = Instance.new("Part")
        rayPart.Anchored = true
        rayPart.BrickColor = BrickColor.Red()
        rayPart.Transparency = 0.2
        rayPart.Parent = folder
    end

    rayPart.Size = Vector3.new(0.05, 0.05, length)
    rayPart.CFrame = CFrame.new(start, finish) * CFrame.new(0, 0, -length/2)

    visualized[#visualized+1] = rayPart
end

local function boxcast(origin, direction, upVector, height, accuracy, raycastParams, minLength, shouldVisualize)
    clearVisualizations()

    shouldVisualize = true

    local newParams = RaycastParams.new()
    newParams.FilterDescendantsInstances = {raycastParams.FilterDescendantsInstances[1], folder}
    newParams.FilterType = Enum.RaycastFilterType.Blacklist

    -- store best result and the length of that result for returning and comparison
    local bestResult, smallestLength

    -- calcuate starting position and step sizes
    local yStepSize = upVector*height/accuracy

    -- iterate as a box from startPos -> endPos with (accuracy + 1)^2 raycasts
    for x = 0, 0 do
        local xPosition = origin - 0.5*upVector*height

        for y = 0, accuracy do
            local castOrigin = xPosition + y*yStepSize 
            local raycastResult = workspace:Raycast(castOrigin, direction, newParams)

            -- compare result to existing result, and if the length of the cast is smaller, set it to the new best result
            if raycastResult then
                local castLength = (raycastResult.Position - castOrigin).Magnitude

                if (bestResult == nil or castLength < smallestLength) and (minLength == nil or castLength >= minLength) then
                    bestResult = raycastResult
                    smallestLength = castLength
                end

                if shouldVisualize then
                    visualizeRay(castOrigin, castOrigin + direction*castLength/direction.Magnitude, castLength)
                end
            elseif shouldVisualize then
                visualizeRay(castOrigin, castOrigin + direction)
            end
        end
    end

    --[[if shouldVisualize then
        repeat
            task.wait()
        until game:GetService("UserInputService"):IsMouseButtonPressed(Enum.UserInputType.MouseButton2)
        
        repeat
            task.wait()
        until not game:GetService("UserInputService"):IsMouseButtonPressed(Enum.UserInputType.MouseButton2)
    end]]

    -- return best result and its length
    return bestResult, smallestLength
end

-- return boxcast function
return boxcast