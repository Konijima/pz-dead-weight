-- Presence detection, one state slot per local player (splitscreen, task
-- 2026-09-18 point A): is that player standing on a medical scale tile. The
-- tile is walkable (verified in game), so only the square under the player
-- is ever looked at, and only when that square changed since the last check
-- for THAT player: a still player still costs one call and one comparison
-- per player per throttled tick, nothing more. Fires onScaleOn(n, square)/
-- onScaleOff(n) once per transition, n being the player index (the facing
-- path keys off these).
-- Occupancy (task 2026-09-20): the scale reads everyone on it and a viewer
-- within Detect.viewDistance() squares, same z and same room, sees the same reading.
-- On viewer square change ONLY the block within reach is scanned for scales
-- (cached as scales, nearest first, a few at most); while any is cached the
-- nearest one that has something to weigh is read every throttled tick (the
-- nearest one when none has; it is kept as scaleSquare) and onOccupancy(n, kg|nil, selfOn, wasEmpty,
-- wasSelf, inReach, settled) fires when the one decimal total changes. A change caused by
-- someone else must hold for Detect.debounce polls (a zombie crossing the
-- tile must not flicker the readout); the viewer's own step on/off is instant.
-- See docs/API-COMPAT.md for which calls are proven on which build.
require "WeightScale/WeightScaleCore"
require "WeightScale/WeightScaleOccupants"

WeightScale = WeightScale or {}
WeightScale.Detect = WeightScale.Detect or {}
local Detect = WeightScale.Detect

Detect.spriteNames = {
    ["location_community_medical_01_8"] = true,
    ["location_community_medical_01_9"] = true,
}

Detect.tickEvery = 6          -- every few ticks, not every frame
Detect.radius = 2             -- default squares a viewer may stand from the scale
Detect.rescanEvery = 10       -- polls between scans for a scale put back after one was lost
Detect.rescanFor = 600        -- polls the search lasts (about a minute), then it stops
Detect.maxScales = 4          -- scales in reach that are ever considered, nearest first
Detect.losEvery = 5           -- polls between line of sight checks of the watched scale
Detect.maxRadius = 5          -- ceiling for the sandbox value (scan is (2R+1)^2 squares)
Detect.debounce = 2           -- polls a non self change must hold
Detect.players = Detect.players or {}  -- [n] = {tick, onScale, lastSquare, ...}
Detect.onScaleOn = nil        -- function(n, square)
Detect.onScaleOff = nil       -- function(n)
Detect.onOccupancy = nil      -- set by WeightScaleMain, see above

local function stateFor(n)
    local s = Detect.players[n]
    if not s then
        s = { tick = 0, onScale = false, lastSquare = false, pendingFace = false,
              scales = {},        -- scale squares within reach, own tile then nearest first
              ownSquare = nil,    -- the viewer's own square while it holds a scale
              scaleSquare = nil,  -- the one shown: nearest with something to weigh, else nearest
              rescanLeft = 0,     -- polls left to look for a scale put back after it vanished
              losTick = 0,        -- polls since the last line of sight check
              shownKey = false,   -- one decimal total on screen, false = empty
              selfOn = false,     -- viewer was on the tile at the last apply
              emptySeen = {},     -- [scale square] = true once this viewer read THAT scale empty
              shownSquare = nil,  -- the scale the reading on screen belongs to
              pendKey = nil, pendN = 0, buf = {} }
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
-- every scale answers for itself. Confirmed in game: the column sits on the
-- side OPPOSITE the sprite's `Facing`, so the player must face away from
-- `Facing`, not toward it (confirmed for one of the two placed scales; see
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

local function roomOf(square)
    if type(square.getRoom) ~= "function" then return nil end
    return square:getRoom()
end

-- A scale is read only if the viewer could see it: a wall, a closed door or a
-- barricade between the two squares hides it, a window or an open door does
-- not. LosUtil.lineClear(cell, x0, y0, z0, x1, y1, z1, ignoreDoors) is the
-- game's own vision test between two squares (exposed to Lua, see
-- docs/API-COMPAT.md); it returns an enum whose name is "Blocked" when hidden.
-- Anything unexpected (API missing, call throws) counts as visible, which is
-- the behaviour before this check existed.
local function lineOfSight(from, to)
    if from == to then return true end
    if type(LosUtil) == "nil" or type(getCell) ~= "function" then return true end
    if type(from.getX) ~= "function" or type(to.getX) ~= "function" then return true end
    local ok, r = pcall(function()
        local cell = getCell()
        if not cell or type(LosUtil.lineClear) ~= "function" then return "Clear" end
        return LosUtil.lineClear(cell, from:getX(), from:getY(), from:getZ(),
                                 to:getX(), to:getY(), to:getZ(), false)
    end)
    return not ok or tostring(r) ~= "Blocked"
end

-- Squares a viewer may stand from the scale: sandbox DeadWeight.ViewDistance
-- (integer, default 2), read where the scan runs (viewer square change only).
-- Missing, non numeric or out of range falls back to Detect.radius / clamps.
function Detect.viewDistance()
    local sv = type(SandboxVars) == "table" and SandboxVars.DeadWeight
    local v = type(sv) == "table" and sv.ViewDistance
    if type(v) ~= "number" or v ~= v then return Detect.radius end
    return math.max(0, math.min(Detect.maxRadius, math.floor(v)))
end

-- Every scale square within Detect.viewDistance() of `square` (same z, same
-- room, in line of sight; nil == nil counts as the same room), the viewer's own
-- tile first, then nearest first, at most Detect.maxScales of them. Runs on
-- viewer square change (and the slow rescan after a loss), never per tick.
-- getCell():getGridSquare(x, y, z) is the standard client lookup; missing API
-- or unloaded squares just find nothing.
local function findScales(square)
    local out = {}
    if hasScaleSprite(square) then out[1] = square end
    if type(square.getX) ~= "function" or type(square.getY) ~= "function"
        or type(square.getZ) ~= "function" or type(getCell) ~= "function" then
        return out
    end
    local cell = getCell()
    if not cell or type(cell.getGridSquare) ~= "function" then return out end
    local x, y, z = square:getX(), square:getY(), square:getZ()
    local room = roomOf(square)
    local R = Detect.viewDistance()
    local found = {}
    for dx = -R, R do
        for dy = -R, R do
            local d = dx * dx + dy * dy
            if d > 0 then
                local sq = cell:getGridSquare(x + dx, y + dy, z)
                if sq and hasScaleSprite(sq) and roomOf(sq) == room and lineOfSight(square, sq) then
                    found[#found + 1] = { sq = sq, d = d, order = #found }
                end
            end
        end
    end
    -- nearest first; equal distances keep scan order
    table.sort(found, function(p, q)
        if p.d ~= q.d then return p.d < q.d end
        return p.order < q.order
    end)
    for i = 1, #found do
        if #out >= Detect.maxScales then break end
        out[#out + 1] = found[i].sq
    end
    return out
end

-- One poll of the scales in reach. The nearest scale that has something to
-- weigh wins (a scale is read only while it is the one shown); when none has,
-- the nearest one stands for the empty reading. key is the one decimal total
-- (Core.format) so nutrition drift below 0.05 kg churns nothing; false means
-- empty. The viewer counts only while standing on the plate itself, not
-- anywhere in the square (Occupants.onPlate); s.onScale stays square based
-- for the facing turn.
-- Cues belong to ONE scale (docs/BACKLOG.md, two scales in reach): the on cue
-- needs this viewer to have read that very scale empty first (emptySeen), the
-- off cue needs the scale that was on screen to still be in reach and now
-- empty (shownSquare). A different scale coming into or leaving reach only
-- moves the reading, in silence.
local function poll(n, s, playerObj)
    local Occ, Core = WeightScale.Occupants, WeightScale.Core
    local vs = playerSquare(playerObj)
    -- the sight line is rechecked every few polls, and only for scales other
    -- than the viewer's own square (a wall built or a door shut in between)
    local checkSight = false
    if #s.scales > 0 then
        s.losTick = s.losTick + 1
        if s.losTick >= Detect.losEvery then
            s.losTick = 0
            checkSight = vs ~= nil
        end
    end
    -- drop a scale that was picked up or hidden while watched, and keep looking
    -- for a while so the same scale set down again, or the view opened again,
    -- is found without the viewer having to move (lastSquare false also
    -- re-reads the viewer's tile). One small object walk per scale.
    local dropped = false
    local i = 1
    while i <= #s.scales do
        local sq = s.scales[i]
        if not hasScaleSprite(sq) or (checkSight and not lineOfSight(vs, sq)) then
            table.remove(s.scales, i)
            s.emptySeen[sq] = nil
            dropped = true
        else
            i = i + 1
        end
    end
    if dropped then
        s.lastSquare = false
        s.rescanLeft = Detect.rescanFor
    end
    local chosen, total, selfOn
    local nRead = #s.scales
    for j = 1, #s.scales do
        local sq = s.scales[j]
        local on = s.onScale and sq == s.ownSquare and Occ.onPlate(sq, playerObj)
        local occ = Occ.read(sq, s.buf, on and playerObj or nil)
        local t = Core.sumWeights(occ)
        if t then chosen, total, selfOn = sq, t, on nRead = j break end
        s.emptySeen[sq] = true
    end
    -- scales past the occupied one were not read this poll: their state is unknown
    for j = nRead + 1, #s.scales do s.emptySeen[s.scales[j]] = nil end
    if not chosen and #s.scales > 0 then
        chosen = s.scales[1]
        selfOn = s.onScale and chosen == s.ownSquare and Occ.onPlate(chosen, playerObj)
    end
    selfOn = selfOn and true or false
    s.scaleSquare = chosen
    local key = total and WeightScale.Core.format(total, "kg") or false
    -- settled: this viewer had already watched THIS scale sit empty before
    -- the change being applied, so the reading appearing is something
    -- happening at the scale (someone or an item lands) and not the viewer
    -- walking up to a scale that was already occupied. Only the former earns
    -- a cue. The flag is kept through the debounce and cleared once applied.
    local settled = total ~= nil and s.emptySeen[chosen] == true
    -- the scale that was on screen is out of reach (or gone): the reading
    -- leaves in silence and at once, even if another scale is still in reach
    local shownInReach = false
    for j = 1, #s.scales do
        if s.scales[j] == s.shownSquare then shownInReach = true break end
    end
    local lost = s.shownSquare ~= nil and not shownInReach
    local selfChanged = selfOn ~= s.selfOn
    if key == s.shownKey then
        if total then s.shownSquare = chosen end   -- same total, maybe read off another scale
        s.pendKey, s.pendN = nil, 0
        s.selfOn = selfOn
        return
    end
    -- someone else's arrival or departure must survive Detect.debounce polls;
    -- the viewer's own move, or the scale going out of reach, applies at once.
    if not selfChanged and s.scaleSquare and not lost then
        if s.pendKey == key then s.pendN = s.pendN + 1 else s.pendKey, s.pendN = key, 1 end
        if s.pendN < Detect.debounce then return end
    end
    local wasEmpty, wasSelf = s.shownKey == false, s.selfOn
    s.shownKey, s.selfOn = key, selfOn
    if key then s.emptySeen[chosen], s.shownSquare = nil, chosen else s.shownSquare = nil end
    s.pendKey, s.pendN = nil, 0
    if Detect.onOccupancy then Detect.onOccupancy(n, total, selfOn, wasEmpty, wasSelf, shownInReach, settled) end
end

-- n is the player index (0-based, as getSpecificPlayer/getPlayerNum use it).
function Detect.update(n, playerObj)
    local s = stateFor(n)
    s.tick = s.tick + 1
    if s.tick % Detect.tickEvery ~= 0 then return end
    if not playerObj then return end

    local square = playerSquare(playerObj)
    -- after losing a scale: a slow look around, on top of the square change scan
    local rescan = false
    if s.rescanLeft > 0 then
        s.rescanLeft = s.rescanLeft - 1
        rescan = s.rescanLeft % Detect.rescanEvery == 0
    end
    if square ~= s.lastSquare or rescan then
        local prev = s.lastSquare
        s.lastSquare = square

        local onNow = square ~= nil and hasScaleSprite(square)

        if onNow and s.onScale and prev and prev ~= square then
            -- stepped straight from one scale onto the next: a new scale to
            -- face, and a half confirmed change belongs to the old one
            s.pendingFace = Detect.facingFor(square) or false
            s.pendKey, s.pendN = nil, 0
        elseif onNow and not s.onScale then
            s.onScale = true
            s.pendingFace = Detect.facingFor(square) or false
            if Detect.onScaleOn then Detect.onScaleOn(n, square) end
        elseif not onNow and s.onScale then
            s.onScale = false
            s.pendingFace = false
            if Detect.onScaleOff then Detect.onScaleOff(n) end
        end
        s.scales = square and findScales(square) or {}
        -- what was read empty only counts for scales still in reach
        local seen = {}
        for _, sq in ipairs(s.scales) do seen[sq] = s.emptySeen[sq] end
        s.emptySeen = seen
        s.ownSquare = onNow and square or nil
        s.scaleSquare = s.scales[1]
    end

    -- Idle away from every scale: none in reach and nothing on screen, no call.
    if #s.scales > 0 or s.shownKey ~= false then poll(n, s, playerObj) end
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
