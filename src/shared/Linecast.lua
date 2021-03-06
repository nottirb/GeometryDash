--[=[
    @class SharedModules

    Contains all shared modules located in ``ReplicatedStorage/Shared``.
]=]

--[=[
    Linecasts from an origin in a given direction. Returns the closest object hit, if present. 

    @function Linecast
    @within SharedModules

    @param origin Vector3 -- The origin of the boxcast
    @param direction Vector3 -- The direction of the boxcast
    @param upVector Vector3 -- The up vector of the boxcast
    @param height number -- The height of the box to cast
    @param raycastParams RaycastParams -- The raycast parameters
    @param minLength number -- the minimum length of any returned cast, defaults to 0

    @return RaycastResult -- The result of the linecast
    @return number -- The final length of the linecast
]=]
local function Linecast(origin, direction, upVector, height, accuracy, raycastParams, minLength)
    -- store best result and the length of that result for returning and comparison
    local bestResult, smallestLength

    -- calcuate starting position and step sizes
    local startPos = origin - 0.5*upVector*height
    local yStepSize = upVector*height/accuracy

    -- iterate as a box from startPos -> endPos with (accuracy + 1)^2 raycasts
    for y = 0, accuracy do
        local castOrigin = startPos + y*yStepSize 
        local raycastResult = workspace:Raycast(castOrigin, direction, raycastParams)

        -- compare result to existing result, and if the length of the cast is smaller, set it to the new best result
        if raycastResult then
            local castLength = (raycastResult.Position - castOrigin).Magnitude

            if (bestResult == nil or castLength < smallestLength) and (minLength == nil or castLength >= minLength) then
                bestResult = raycastResult
                smallestLength = castLength
            end
        end
    end

    -- return best result and its length
    return bestResult, smallestLength
end

-- return boxcast function
return Linecast