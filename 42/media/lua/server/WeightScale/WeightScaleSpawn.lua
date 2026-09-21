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
Spawn.minSquares = 9          -- room area, counting only loaded squares
Spawn.minFree = 5             -- clear floor squares the room keeps besides the scale
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

-- a door, doorway or window on any edge of this square
local function hasOpening(sq)
    for _, name in ipairs(DIRS) do
        local n = neighbour(sq, name)
        if n then
            if (type(sq.getDoorTo) == "function" and sq:getDoorTo(n))
                or (type(sq.getDoorFrameTo) == "function" and sq:getDoorFrameTo(n))
                or (type(sq.getWindowTo) == "function" and sq:getWindowTo(n))
                or (type(sq.getWindowFrameTo) == "function" and sq:getWindowFrameTo(n)) then
                return true
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
        if n and n:getRoom() ~= room and type(sq.isWallTo) == "function" and sq:isWallTo(n) then
            return name
        end
    end
    return nil
end

-- Where the scale may stand: a clear floor square of the room, against a
-- wall, on no doorway and not next to one (the way in stays open).
function Spawn.candidates(room)
    local squares = room:getSquares()
    local out, free = {}, 0
    if not squares or squares:size() < Spawn.minSquares then return out, 0 end
    for i = 0, squares:size() - 1 do
        local sq = squares:get(i)
        if clear(sq) then
            free = free + 1
            if not hasOpening(sq) then
                local side = wallSide(sq, room)
                if side then
                    local nearDoor = false
                    for _, name in ipairs(DIRS) do
                        local n = neighbour(sq, name)
                        if n and n:getRoom() == room and hasOpening(n) then nearDoor = true break end
                    end
                    if not nearDoor then out[#out + 1] = { sq = sq, side = side } end
                end
            end
        end
    end
    return out, free
end

local function isBathroom(room)
    local name = room and type(room.getName) == "function" and room:getName()
    return type(name) == "string" and name:find("bathroom", 1, true) ~= nil
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
    local pct = Spawn.chance()
    if pct <= 0 then return nil end
    if (roll or ZombRand(100)) >= pct then return nil end
    if hasScale(room) then return nil end
    local list, free = Spawn.candidates(room)
    if #list == 0 or free - 1 < Spawn.minFree then return nil end
    local pick = list[(roll and 1) or (ZombRand(#list) + 1)]
    local sq = pick.sq
    local obj = IsoObject.new(getCell(), sq, getSprite(Spawn.spriteFor[pick.side]))
    sq:AddSpecialObject(obj)
    if type(sq.RecalcProperties) == "function" then sq:RecalcProperties() end
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
