-- Presence detection: is the local player (player 0 only) standing on a
-- medical scale tile. The tile is walkable (verified in game), so only the
-- square under the player is ever looked at, and only when that square
-- changed since the last check: on a still player the tick costs one call
-- and one comparison. Fires onScaleOn/onScaleOff once per transition.
-- See docs/API-COMPAT.md for which calls are proven on which build.
WeightScale = WeightScale or {}
WeightScale.Detect = WeightScale.Detect or {}
local Detect = WeightScale.Detect

Detect.spriteNames = {
    ["location_community_medical_01_8"] = true,
    ["location_community_medical_01_9"] = true,
}

Detect.tickEvery = 6          -- every few ticks, not every frame
Detect._tick = 0
Detect._onScale = false
Detect._lastSquare = false    -- false, not nil: a nil square is a real state
Detect.onScaleOn = nil        -- set by WeightScaleMain: function(square)
Detect.onScaleOff = nil       -- function()

local function hasScaleSprite(square)
    if not square or not square.getObjects then return false end
    local objs = square:getObjects()
    if not objs then return false end
    local n = objs:size()
    for i = 0, n - 1 do
        local obj = objs:get(i)
        local sprite = obj and obj.getSprite and obj:getSprite()
        local name = sprite and sprite.getName and sprite:getName()
        if name and Detect.spriteNames[name] then
            return true
        end
    end
    return false
end

local function playerSquare(playerObj)
    if playerObj.getCurrentSquare then
        local square = playerObj:getCurrentSquare()
        if square then return square end
    end
    if playerObj.getSquare then
        return playerObj:getSquare()
    end
    return nil
end

function Detect.update()
    Detect._tick = Detect._tick + 1
    if Detect._tick % Detect.tickEvery ~= 0 then return end

    local playerObj = getSpecificPlayer and getSpecificPlayer(0) or (getPlayer and getPlayer())
    if not playerObj then return end

    local square = playerSquare(playerObj)
    if square == Detect._lastSquare then return end
    Detect._lastSquare = square

    local onNow = square ~= nil and hasScaleSprite(square)

    if onNow and not Detect._onScale then
        Detect._onScale = true
        if Detect.onScaleOn then Detect.onScaleOn(square) end
    elseif not onNow and Detect._onScale then
        Detect._onScale = false
        if Detect.onScaleOff then Detect.onScaleOff() end
    end
end
