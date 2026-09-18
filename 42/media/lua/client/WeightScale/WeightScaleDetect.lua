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
        s = { tick = 0, onScale = false, lastSquare = false, pendingFace = false }
        Detect.players[n] = s
    end
    return s
end

-- Drops a player's detection state, e.g. once its HUD element is removed
-- (disconnect/death/nil slot): no stale state may keep a slot alive.
function Detect.clear(n)
    Detect.players[n] = nil
end

local function scaleObjectOn(square)
    if not square or not square.getObjects then return nil end
    local objs = square:getObjects()
    if not objs then return nil end
    local n = objs:size()
    for i = 0, n - 1 do
        local obj = objs:get(i)
        local sprite = obj and obj.getSprite and obj:getSprite()
        local name = sprite and sprite.getName and sprite:getName()
        if name and Detect.spriteNames[name] then
            return obj
        end
    end
    return nil
end

local function hasScaleSprite(square)
    return scaleObjectOn(square) ~= nil
end

-- Face the scale's column (task 2026-09-18, point B): each placed scale
-- carries its own `Facing` sprite property (N/S/E/W, proven per tile in
-- media/newtiledefinitions.tiles.txt: location_community_medical_01_8 = E,
-- _9 = S), read live off the object with IsoObject:getFacing() (PROVEN
-- client lua, ISAddTakeDispenserBottle.lua, comparable directly against the
-- IsoDirections.N/S/E/W globals) -- no hardcoded per-sprite table needed,
-- every scale answers for itself. [vu] 2026-09-18: in-game test showed the
-- opposite of the earlier deduction -- the column sits on the side OPPOSITE
-- the sprite's `Facing`, so the player must face away from `Facing`, not
-- toward it (confirmed for one of the two placed scales; see
-- docs/TEST-EN-JEU.md for the other orientation still to check).
local OPPOSITE_FACING = {}
if IsoDirections then
    OPPOSITE_FACING[IsoDirections.N] = IsoDirections.S
    OPPOSITE_FACING[IsoDirections.S] = IsoDirections.N
    OPPOSITE_FACING[IsoDirections.E] = IsoDirections.W
    OPPOSITE_FACING[IsoDirections.W] = IsoDirections.E
end

function Detect.facingFor(square)
    local obj = scaleObjectOn(square)
    if not obj or type(obj.getFacing) ~= "function" then return nil end
    local facing = obj:getFacing()
    if facing == nil then return nil end
    return OPPOSITE_FACING[facing] or facing
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
        s.pendingFace = Detect.facingFor(square) or false
        if Detect.onScaleOn then Detect.onScaleOn(n, square) end
    elseif not onNow and s.onScale then
        s.onScale = false
        s.pendingFace = false
        if Detect.onScaleOff then Detect.onScaleOff(n) end
    end
end

-- Consumes the one queued turn for a player once they have actually
-- stopped on the plate: never while still walking (foot traffic across the
-- tile must not be yanked), never twice (cleared the instant it fires, and
-- again the instant the player leaves the square in Detect.update above, so
-- it only re-arms on a fresh step-on), and never over aiming or another
-- timed action already in progress. Cheap while idle: one field read and
-- return for every player who isn't mid-turn, no new per-frame scan. Called
-- every tick from WeightScaleMain (both OnPlayerUpdate and the OnTick
-- fallback), independent of Detect.update's own square-change throttle,
-- because "has the player stopped yet" can change on any tick.
--
-- This single mechanism also covers the context menu path (point C): the
-- walk it queues (WeightScaleMenu.lua) leaves the character motionless and
-- standing on the scale square once it completes, which is exactly the
-- state this function waits for -- so a cancelled walk, or one that ends
-- adjacent to the square rather than on it, never arms a turn at all, and a
-- completed one is turned by this same code, once, with no separate
-- face-on-arrival plumbing and no risk of turning twice.
function Detect.updateFacing(n, playerObj)
    local s = Detect.players[n]
    if not s or not s.pendingFace or not playerObj then return end
    if type(playerObj.isPlayerMoving) ~= "function"
        or type(playerObj.faceDirection) ~= "function" then
        return -- API unproven on this build: no turn, no crash
    end
    if playerObj:isPlayerMoving() then return end
    if (type(playerObj.isAiming) == "function" and playerObj:isAiming())
        or (type(playerObj.hasTimedActions) == "function" and playerObj:hasTimedActions()) then
        return
    end
    playerObj:faceDirection(s.pendingFace)
    s.pendingFace = false
end
