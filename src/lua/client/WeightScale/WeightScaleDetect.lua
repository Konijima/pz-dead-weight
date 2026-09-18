-- Presence detection, one state slot per local player (splitscreen, task
-- 2026-09-18 point A): is that player standing on a medical scale tile. The
-- tile is walkable (verified in game), so only the square under the player
-- is ever looked at, and only when that square changed since the last check
-- for THAT player: a still player still costs one call and one comparison
-- per player per throttled tick, nothing more. Fires onScaleOn(n, square)/
-- onScaleOff(n) once per transition, n being the player index.
-- See docs/API-COMPAT.md for which calls are proven on which build.
WeightScale = WeightScale or {}
WeightScale.Detect = WeightScale.Detect or {}
local Detect = WeightScale.Detect

Detect.spriteNames = {
    ["location_community_medical_01_8"] = true,
    ["location_community_medical_01_9"] = true,
}

Detect.tickEvery = 6          -- every few ticks, not every frame
Detect.players = Detect.players or {}  -- [n] = {tick, onScale, lastSquare}
Detect.onScaleOn = nil        -- set by WeightScaleMain: function(n, square)
Detect.onScaleOff = nil       -- function(n)

local function stateFor(n)
    local s = Detect.players[n]
    if not s then
        s = { tick = 0, onScale = false, lastSquare = false }
        Detect.players[n] = s
    end
    return s
end

-- Drops a player's detection state, e.g. once its HUD element is removed
-- (disconnect/death/nil slot): no stale state may keep a slot alive.
function Detect.clear(n)
    Detect.players[n] = nil
end

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

-- n is the player index (0-based, as getSpecificPlayer/getPlayerNum use it).
function Detect.update(n, playerObj)
    local s = stateFor(n)
    s.tick = s.tick + 1
    if s.tick % Detect.tickEvery ~= 0 then return end
    if not playerObj then return end

    local square = playerSquare(playerObj)
    if square == s.lastSquare then return end
    s.lastSquare = square

    local onNow = square ~= nil and hasScaleSprite(square)

    if onNow and not s.onScale then
        s.onScale = true
        if Detect.onScaleOn then Detect.onScaleOn(n, square) end
    elseif not onNow and s.onScale then
        s.onScale = false
        if Detect.onScaleOff then Detect.onScaleOff(n) end
    end
end
