-- World spawn: a Digital Scale on the floor of a big enough bathroom, against
-- a wall, in rooms the player has NEVER seen (Build 42 only, server side and
-- single player: never on a multiplayer client, see docs/API-COMPAT.md).
--
-- "Never seen" is the game's own new chunk: MapObjects.OnNewWithSprite fires
-- once per square, only while a chunk with no data on disk is generated (the
-- same gate vanilla uses to populate zombies, IsoChunk.addZombies). A chunk
-- that was ever loaded is saved and never new again, so a visited town never
-- gets a scale and a room never gets a second one. RoomDef.explored is NOT
-- used: the game marks a whole building explored the moment it is spotted
-- from outside.
-- The hook is on toilet sprites (every bathroom has one), and only queues the
-- square: the chunk's other squares are not built yet while it fires, so the
-- room is examined at Events.LoadChunk, once the chunk is complete.
if type(isClient) == "function" and isClient() then return end

WeightScale = WeightScale or {}
WeightScale.Spawn = WeightScale.Spawn or {}
local Spawn = WeightScale.Spawn

Spawn.defaultChance = 20      -- percent of the qualifying bathrooms, DeadWeight.HomeScaleFloor
Spawn.minSquares = 8          -- room area, counting only loaded squares
Spawn.minFree = 3             -- clear floor squares the room keeps besides the scale
Spawn.priority = 5

-- every toilet tile (fixtures_bathroom_01_0..11, fixtures_bathroom_02_*),
-- read off media/newtiledefinitions.tiles.txt (CustomName = Toilet)
Spawn.toilets = {
    "fixtures_bathroom_01_0", "fixtures_bathroom_01_1", "fixtures_bathroom_01_2", "fixtures_bathroom_01_3",
    "fixtures_bathroom_01_4", "fixtures_bathroom_01_5", "fixtures_bathroom_01_6", "fixtures_bathroom_01_7",
    "fixtures_bathroom_01_8", "fixtures_bathroom_01_9", "fixtures_bathroom_01_10", "fixtures_bathroom_01_11",
    "fixtures_bathroom_02_4", "fixtures_bathroom_02_5", "fixtures_bathroom_02_14", "fixtures_bathroom_02_15",
    "fixtures_bathroom_02_24", "fixtures_bathroom_02_25", "fixtures_bathroom_02_26", "fixtures_bathroom_02_27",
}

-- The scale faces away from the wall it stands against (its slab is drawn
-- set back toward the wall, tools/gen-scale-art.py): a wall to the north
-- takes the S sprite, west takes E, south takes N, east takes W.
Spawn.spriteFor = {
    N = "deadweight_digital_01_0", W = "deadweight_digital_01_1",
    S = "deadweight_digital_01_2", E = "deadweight_digital_01_3",
}
local DIRS = { "N", "W", "S", "E" }

-- One console line per bathroom examined (a new chunk only, a handful per
-- town), to diagnose "why no scale here" from console.txt.
function Spawn.log(msg) print("[DeadWeight] spawn: " .. msg) end
local function where(sq) return sq.getX and (sq:getX() .. "," .. sq:getY()) or (tostring(sq.x) .. "," .. tostring(sq.y)) end

function Spawn.chance()
    local c = type(SandboxVars) == "table" and type(SandboxVars.DeadWeight) == "table"
        and SandboxVars.DeadWeight.HomeScaleFloor
    if type(c) ~= "number" then return Spawn.defaultChance end
    return math.max(0, math.min(100, c))
end

local function dirOf(name) return IsoDirections and IsoDirections[name] end

local function neighbour(sq, name)
    local d = dirOf(name)
    return d and type(sq.getAdjacentSquare) == "function" and sq:getAdjacentSquare(d) or nil
end

-- is anything but the floor on this square
local function hasFurniture(sq)
    if type(sq.getObjects) ~= "function" then return true end
    local objs = sq:getObjects()
    local floor = type(sq.getFloor) == "function" and sq:getFloor() or nil
    for i = 0, objs:size() - 1 do
        local o = objs:get(i)
        if o ~= floor and o ~= nil then
            local sprite = type(o.getSprite) == "function" and o:getSprite()
            local props = sprite and type(sprite.getProperties) == "function" and sprite:getProperties()
            -- walls and door frames are part of the room's shell, anything
            -- movable, holding items or with a surface is furniture
            if props and (props:has("IsMoveAble") or props:has("container") or props:has("Surface")
                or props:has("IsTableTop") or props:has("BlocksPlacement")) then
                return true
            end
            if type(instanceof) == "function" and (instanceof(o, "IsoWorldInventoryObject")
                or instanceof(o, "IsoThumpable") or instanceof(o, "IsoDoor") or instanceof(o, "IsoWindow")) then
                return true
            end
        end
    end
    return false
end

local function clear(sq)
    if type(sq.isFree) == "function" and not sq:isFree(false) then return false end
    return not hasFurniture(sq)
end

-- a door or doorway on any edge of this square (a window is not one: a
-- window wall is as good a wall as any, the scale just stands under it)
local function hasOpening(sq)
    for _, name in ipairs(DIRS) do
        local n = neighbour(sq, name)
        if n then
            if (type(sq.getDoorTo) == "function" and sq:getDoorTo(n))
                or (type(sq.getDoorFrameTo) == "function" and sq:getDoorFrameTo(n)) then
                return true
            end
        end
    end
    return false
end

local DIRS8 = { "N", "S", "E", "W", "NW", "NE", "SW", "SE" }

-- How crowded the square's surroundings are: furniture on the room's squares
-- around it, diagonals included. The scale goes where this is lowest, in the
-- open stretch of wall, not in a corner squeezed between a tub and a toilet.
local function crowd(sq, room)
    local c = 0
    for _, name in ipairs(DIRS8) do
        local n = neighbour(sq, name)
        if n and n:getRoom() == room and hasFurniture(n) then c = c + 1 end
    end
    return c
end

local OPPOSITE = { N = "S", S = "N", E = "W", W = "E" }

-- Is this square the front of a piece of furniture next to it (the space in
-- front of a toilet, a sink, a counter, a washing machine)? The tile's own
-- Facing property says which side its front is on; a scale there would sit
-- in the way of whoever uses it.
local function inFrontOfFurniture(sq)
    for _, name in ipairs(DIRS) do
        local n = neighbour(sq, name)
        if n and type(n.getObjects) == "function" then
            local objs = n:getObjects()
            for i = 0, objs:size() - 1 do
                local o = objs:get(i)
                local sprite = o and type(o.getSprite) == "function" and o:getSprite()
                local props = sprite and type(sprite.getProperties) == "function" and sprite:getProperties()
                -- ISMoveableSpriteProps reads it as props:has("Facing") / props:get("Facing")
                if props and type(props.has) == "function" and props:has("Facing")
                    and props:get("Facing") == OPPOSITE[name] then
                    return true
                end
            end
        end
    end
    return false
end

-- the direction of a plain wall on this square's edge with the outside of
-- the room behind it, nil when there is none (or more than one: a corner is
-- fine, the first one wins)
local function wallSide(sq, room)
    for _, name in ipairs(DIRS) do
        local n = neighbour(sq, name)
        if n and n:getRoom() ~= room and ((type(sq.isWallTo) == "function" and sq:isWallTo(n))
                or (type(sq.getWindowTo) == "function" and sq:getWindowTo(n))) then
            return name
        end
    end
    return nil
end

-- Where the scale may stand: a clear floor square of the room, against a
-- wall or window wall, on no doorway, not next to one (the way in stays
-- open) and not in front of a fixture or piece of furniture.
function Spawn.candidates(room)
    local squares = room:getSquares()
    local out, free = {}, 0
    -- why clear squares were turned down, for the console line; edge and
    -- walled count every square of the room (clear or not) that touches the
    -- outside, and how many of those edges the game calls a wall
    local why = { opening = 0, nowall = 0, neardoor = 0, nilnb = 0, front = 0, notfree = 0, furn = 0, edge = 0, walled = 0 }
    if not squares then return out, 0, why end
    for i = 0, squares:size() - 1 do
        local sq = squares:get(i)
        local isfree = type(sq.isFree) ~= "function" or sq:isFree(false)
        local furn = hasFurniture(sq)
        for _, name in ipairs(DIRS) do
            local n = neighbour(sq, name)
            if n and n:getRoom() ~= room then
                why.edge = why.edge + 1
                if type(sq.isWallTo) == "function" and sq:isWallTo(n) then why.walled = why.walled + 1 end
            end
        end
        if not isfree then why.notfree = why.notfree + 1 elseif furn then why.furn = why.furn + 1 end
        if isfree and not furn then
            free = free + 1
            if hasOpening(sq) then
                why.opening = why.opening + 1
            else
                local side = wallSide(sq, room)
                if not side then
                    why.nowall = why.nowall + 1
                    for _, name in ipairs(DIRS) do if not neighbour(sq, name) then why.nilnb = why.nilnb + 1 break end end
                else
                    local nearDoor = false
                    for _, name in ipairs(DIRS) do
                        local n = neighbour(sq, name)
                        if n and n:getRoom() == room and hasOpening(n) then nearDoor = true break end
                    end
                    if nearDoor then why.neardoor = why.neardoor + 1
                    elseif inFrontOfFurniture(sq) then why.front = why.front + 1
                    else out[#out + 1] = { sq = sq, side = side, crowd = crowd(sq, room) } end
                end
            end
        end
    end
    return out, free, why
end

local function isBathroom(room)
    local name = room and type(room.getName) == "function" and room:getName()
    return type(name) == "string" and name:find("bathroom", 1, true) ~= nil
end

-- A home scale belongs in a home: the building must hold a bedroom, a living
-- room or a motel room. A public restroom (stalls, a paper towel dispenser, in
-- a gas station or an office) is named "bathroom" too. If the building cannot
-- be read the room is let through rather than the feature silently dying.
local HOMEY = { bedroom = true, livingroom = true, motelroom = true }

function Spawn.residential(room)
    local b = type(room.getBuilding) == "function" and room:getBuilding()
    local def = b and type(b.getDef) == "function" and b:getDef()
    local rooms = def and type(def.getRooms) == "function" and def:getRooms()
    if not rooms then return true end
    for i = 0, rooms:size() - 1 do
        local name = rooms:get(i):getName()
        if HOMEY[name] then return true end
    end
    return false
end

-- our own four sprites: the client folder's Scales table is not loaded on a
-- dedicated server
local ours = {}
for _, name in pairs(Spawn.spriteFor) do ours[name] = true end

local function hasScale(room)
    local squares = room:getSquares()
    for i = 0, squares:size() - 1 do
        local objs = squares:get(i):getObjects()
        for j = 0, objs:size() - 1 do
            local sprite = objs:get(j):getSprite()
            local name = sprite and sprite:getName()
            if name and ours[name] then return true end
        end
    end
    return false
end

-- Place one scale in the room of this square if it qualifies. Returns the
-- placed square or nil. `roll` is the percent die, injectable for the bench.
function Spawn.tryRoom(square, roll)
    local room = square and type(square.getRoom) == "function" and square:getRoom()
    if not isBathroom(room) then return nil end
    local at = where(square)
    if not Spawn.residential(room) then Spawn.log("bathroom at " .. at .. " is not in a home, none") return nil end
    local pct = Spawn.chance()
    if pct <= 0 then return nil end
    local die = roll or ZombRand(100)
    if die >= pct then Spawn.log("bathroom at " .. at .. ", roll " .. die .. " >= " .. pct .. "%, none") return nil end
    if hasScale(room) then Spawn.log("bathroom at " .. at .. " already has one") return nil end
    local list, free, why = Spawn.candidates(room)
    local n = room:getSquares():size()
    if n < Spawn.minSquares or #list == 0 or free - 1 < Spawn.minFree then
        Spawn.log("bathroom at " .. at .. ": " .. n .. " squares, " .. free .. " clear, " .. #list .. " wall spots, no room (room edges " .. why.edge .. ", of which walls " .. why.walled .. "; opening "
            .. why.opening .. ", no wall " .. why.nowall .. ", near a door " .. why.neardoor .. ", in front of furniture " .. why.front .. ", unloaded neighbour " .. why.nilnb
            .. "; squares not free " .. why.notfree .. ", with furniture " .. why.furn .. ")")
        return nil
    end
    -- only the roomiest spots stay in the running
    local best = list[1].crowd
    for _, c in ipairs(list) do if c.crowd < best then best = c.crowd end end
    local open = {}
    for _, c in ipairs(list) do if c.crowd == best then open[#open + 1] = c end end
    local pick = open[(roll and 1) or (ZombRand(#open) + 1)]
    local sq = pick.sq
    local obj = IsoObject.new(getCell(), sq, getSprite(Spawn.spriteFor[pick.side]))
    sq:AddSpecialObject(obj)
    if type(sq.RecalcProperties) == "function" then sq:RecalcProperties() end
    Spawn.log("bathroom at " .. at .. ": placed at " .. where(sq) .. ", wall " .. pick.side)
    return sq
end

-- the toilets seen in the chunk being generated, examined at LoadChunk
local pending, seenRooms = {}, {}
local hooked = false

function Spawn.process()
    local list = pending
    pending = {}
    for _, sq in ipairs(list) do
        local room = type(sq.getRoom) == "function" and sq:getRoom()
        local def = room and type(room.getRoomDef) == "function" and room:getRoomDef()
        local key = def and type(def.getID) == "function" and def:getID() or room
        if key and not seenRooms[key] then
            seenRooms[key] = true     -- one roll per room, however many toilets it has
            Spawn.tryRoom(sq)
        end
    end
end

function Spawn.onNewToilet(obj)
    local sq = obj and type(obj.getSquare) == "function" and obj:getSquare()
    if not sq then return end
    Spawn.log("toilet in a new chunk at " .. where(sq))
    pending[#pending + 1] = sq
end

function Spawn.pendingCount() return #pending end

function Spawn.register()
    if hooked then return end
    hooked = true
    if type(MapObjects) == "table" or type(MapObjects) == "userdata" then
        for _, name in ipairs(Spawn.toilets) do
            MapObjects.OnNewWithSprite(name, Spawn.onNewToilet, Spawn.priority)
        end
    end
    if Events and Events.LoadChunk and Events.LoadChunk.Add then Events.LoadChunk.Add(Spawn.process) end
end

Spawn.register()
