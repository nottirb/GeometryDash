--[=[
   Boxcasts from an origin in a given direction. Returns the closest object hit, if present. 

   @param origin Vector3 -- The origin of the boxcast
   @param direction Vector3 -- The direction of the boxcast
   @param upVector Vector3 -- The up vector of the boxcast
   @param height number -- The height of the box to cast
   @param width number -- The width of the box to cast
   @param raycastParams RaycastParams -- The raycast parameters
]=]
local function boxcast(origin, direction, upVector, height, width, accuracy, raycastParams)
    -- store best result and the length of that result for returning and comparison
    local bestResult, smallestLength

    -- calculate right vector
    local rightVector = direction:Cross(upVector).unit

    -- calcuate starting position and step sizes
    local startPos = origin - 0.5*rightVector*width - 0.5*upVector*height
    local xStepSize = rightVector*width/accuracy
    local yStepSize = upVector*height/accuracy

    -- iterate as a box from startPos -> endPos with (accuracy + 1)^2 raycasts
    for x = 0, accuracy do
        local xPosition = startPos + x*xStepSize

        for y = 0, accuracy do
            local castOrigin = xPosition + y*yStepSize 
            local raycastResult = workspace:Raycast(castOrigin, direction, raycastParams)

            -- compare result to existing result, and if the length of the cast is smaller, set it to the new best result
            if raycastResult then
                local castLength = (raycastResult.Position - castOrigin).Magnitude

                if bestResult == nil or castLength < smallestLength then
                    bestResult = raycastResult
                    smallestLength = castLength
                end
            end
        end
    end

    -- return best result and its length
    return bestResult, smallestLength
end

-- return boxcast function
return boxcast