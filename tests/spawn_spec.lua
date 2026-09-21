-- Bench for the Digital Scale's loot and world spawn (server Lua, Build 42),
-- run under lua5.1 with the game API stubbed: distributions, sandbox reads,
-- the new chunk toilet hook, the room qualifying rules and the sprite chosen
-- for the wall the scale stands against.
package.path = "src/lua/server/?.lua;" .. package.path

local nAssert = 0
local function check(cond, msg)
    nAssert = nAssert + 1
    if not cond then io.stderr:write("FAIL: " .. msg .. "\n") os.exit(1) end
end

-- game stand ins ---------------------------------------------------------------
local LOADED = {}
local function mkEvent() return { Add = function(_, f) end } end
local handlers = {}
Events = { OnFillContainer = { Add = function(f) handlers.fill = f end }, OnPreDistributionMerge = { Add = function(f) handlers.merge = f end },
           LoadChunk = { Add = function(f) handlers.chunk = f end } }
SandboxVars = nil
local CLIENT = false
function isClient() return CLIENT end
IsoDirections = { N = "N", S = "S", E = "E", W = "W" }
local NEXT = 0
function ZombRand(n) NEXT = NEXT + 1 return 0 end
function getCell() return {} end
function getSprite(name) return { name = name } end
local ADDED = {}
IsoObject = { new = function(_, sq, sprite) return { sq = sq, spriteName = sprite.name } end }
-- like the game: only a real ItemContainer is one (a plain table here with getItems)
function instanceof(o, cls) return cls == "ItemContainer" and type(o) == "table" and rawget(o, "getItems") ~= nil end
local onNew = {}
MapObjects = { OnNewWithSprite = function(name, fn, prio) onNew[name] = fn end }

local function javaList(items)
    local l = {}
    function l:size() return #items end
    function l:get(i) if i < 0 or i >= #items then error("IndexOutOfBounds") end return items[i + 1] end
    return l
end

-- a 3 x 4 bathroom at x 0..2, y 0..3; the door is on the south edge of (1,3)
local ROOM = { name = "bathroom" }
function ROOM:getName() return self.name end
function ROOM:getRoomDef() return { getID = function() return 77 end } end
local grid, squares = {}, {}
local FURN = {}                       -- "x,y" -> true for a square holding furniture
local function key(x, y) return x .. "," .. y end
local function inRoom(x, y) return x >= 0 and x <= 2 and y >= 0 and y <= 3 end
local function propsOf(furn)
    return { has = function(_, p) return furn and p == "IsMoveAble" end }
end
local function mk(x, y)
    local sq = { x = x, y = y, added = {} }
    local floor = { getSprite = function() return { getName = function() return "floors_01" end, getProperties = function() return propsOf(false) end } end }
    sq.floor = floor
    function sq:getFloor() return floor end
    function sq:getRoom() return inRoom(x, y) and ROOM or nil end
    function sq:isFree() return not FURN[key(x, y)] end
    function sq:getObjects()
        local objs = { floor }
        if FURN[key(x, y)] then
            objs[2] = { getSprite = function() return { getName = function() return "fix" end, getProperties = function() return propsOf(true) end } end }
        end
        for _, o in ipairs(self.added) do
            objs[#objs + 1] = { getSprite = function() return { getName = function() return o.spriteName end } end }
        end
        return javaList(objs)
    end
    function sq:getAdjacentSquare(d)
        local dx, dy = 0, 0
        if d == "N" then dy = -1 elseif d == "S" then dy = 1 elseif d == "W" then dx = -1 else dx = 1 end
        return grid[key(x + dx, y + dy)]
    end
    function sq:isWallTo(n)
        if inRoom(x, y) == inRoom(n.x, n.y) then return false end
        return not (x == 1 and y == 3 and n.y == 4)   -- the doorway is not a wall
    end
    function sq:getDoorTo(n) return (x == 1 and y == 3 and n.y == 4) and {} or nil end
    function sq:AddSpecialObject(o) table.insert(self.added, o) end
    function sq:RecalcProperties() end
    return sq
end
for x = -1, 3 do for y = -1, 4 do grid[key(x, y)] = mk(x, y) end end
for x = 0, 2 do for y = 0, 3 do squares[#squares + 1] = grid[key(x, y)] end end
function ROOM:getSquares() return javaList(squares) end

local function reset()
    for _, sq in pairs(grid) do sq.added = {} end
    FURN = {}
end

require("WeightScale/WeightScaleDistributions")
require("WeightScale/WeightScaleSpawn")
local D, Spawn = WeightScale.Distributions, WeightScale.Spawn
local LOG = {}
Spawn.log = function(m) LOG[#LOG + 1] = m end

-- 1. loot ------------------------------------------------------------------------
ProceduralDistributions = { list = { BathroomCounter = { items = { "Comb", 6 } }, BathroomCabinet = { items = {} } } }
local cabinet = ProceduralDistributions.list.BathroomCabinet
check(handlers.merge == D.merge, "the merge is hooked on OnPreDistributionMerge")
check(D.merge() == 1, "only the counter list exists in this stub: the others are skipped")
local items = ProceduralDistributions.list.BathroomCounter.items
check(items[3] == "Mov_DeadWeightDigital" and items[4] == 3, "item and default weight 3 appended")
check(#cabinet.items == 0, "a wall medicine cabinet never gets a scale")
SandboxVars = { DeadWeight = { HomeScaleSpawn = 0 } }
ProceduralDistributions.list.BathroomCounter.items = {}
check(D.merge() == 0 and #ProceduralDistributions.list.BathroomCounter.items == 0, "weight 0 adds nothing")
SandboxVars = { DeadWeight = { HomeScaleSpawn = 99 } }
check(D.weight() == 20, "the weight is clamped to 20")
ProceduralDistributions = nil
check(D.merge() == 0, "no ProceduralDistributions table: no crash")
SandboxVars = nil

-- 1b. one scale per container, one per room -------------------------------------
check(handlers.fill == D.limit, "the fill is checked on OnFillContainer")
local function itemOf(t) return { getType = function() return t end } end
local function container(items, roomId)
    local c = { list = items }
    function c:getItems()
        local l = {}
        function l:size() return #c.list end
        function l:get(i) return c.list[i + 1] end
        return l
    end
    function c:Remove(it) for i, x in ipairs(c.list) do if x == it then table.remove(c.list, i) break end end end
    if roomId then
        c.getParent = function() return { getSquare = function() return { getRoom = function() return {
            getRoomDef = function() return { getID = function() return roomId end } end } end } end } end
    end
    return c
end
local twice = container({ itemOf("Comb"), itemOf("Mov_DeadWeightDigital"), itemOf("Mov_DeadWeightDigital") }, 5)
D.limit("bathroom", "counter", twice)
check(#twice.list == 2 and twice.list[1]:getType() == "Comb", "a container holding two scales keeps one and its other items")
local other = container({ itemOf("Mov_DeadWeightDigital") }, 5)
D.limit("bathroom", "counter", other)
check(#other.list == 0, "a second counter of the same room gets none")
local elsewhere = container({ itemOf("Mov_DeadWeightDigital") }, 6)
D.limit("bathroom", "counter", elsewhere)
check(#elsewhere.list == 1, "another room keeps its scale")
D.limit("bathroom", "counter", twice)
check(#twice.list == 2, "re-checking the container that already holds the room's scale changes nothing")
D.limit("x", "y", nil)
-- ItemPickerContainer (zombie bags): userdata that throws on any index
local picker = setmetatable({}, { __index = function() error("attempted index: getItems of non-table") end })
check(pcall(D.limit, "x", "y", picker), "an ItemPickerContainer argument is ignored, not indexed")

-- 2. the toilet hook and queue ---------------------------------------------------
check(handlers.chunk == Spawn.process, "the rooms are examined at LoadChunk")
check(onNew["fixtures_bathroom_01_0"] == Spawn.onNewToilet and onNew["fixtures_bathroom_02_27"] == Spawn.onNewToilet,
    "toilet tiles are hooked")
FURN[key(0, 0)] = true      -- the toilet
FURN[key(2, 0)] = true      -- the sink
FURN[key(0, 1)] = true      -- the tub
FURN[key(0, 2)] = true
Spawn.onNewToilet({ getSquare = function() return grid[key(0, 0)] end })
check(Spawn.pendingCount() == 1, "the toilet square is queued, not examined yet")

-- 3. qualifying: the room is big enough and the roll passes -------------------------
SandboxVars = { DeadWeight = { HomeScaleFloor = 100 } }
local sq = Spawn.tryRoom(grid[key(0, 0)], 0)
check(sq ~= nil, "a big bathroom with a free wall square gets a scale")
local obj = sq.added[1]
check(obj and obj.spriteName:find("deadweight_digital_01_", 1, true) == 1, "a Digital Scale object was added")
check(not (sq.x == 1 and sq.y == 3), "not on the doorway")
check(not (sq.x == 1 and sq.y == 2) and not (sq.x == 0 and sq.y == 3) and not (sq.x == 2 and sq.y == 3),
    "not next to the door (the way in stays open)")
check(not FURN[key(sq.x, sq.y)], "on a clear square")
local expect = { }
-- the wall it stands against decides the sprite
local wallN = sq.y == 0 and "deadweight_digital_01_0"
local wallW = sq.x == 0 and "deadweight_digital_01_1"
local wallE = sq.x == 2 and "deadweight_digital_01_3"
check(obj.spriteName == (wallN or wallW or wallE), "the sprite faces away from its wall, got " .. tostring(obj.spriteName))

check(#LOG > 0 and LOG[#LOG]:find("placed at", 1, true), "the placement is logged")

-- 4. only once per room and only in a bathroom ------------------------------------
check(Spawn.tryRoom(grid[key(0, 0)], 0) == nil, "a room that already has a scale gets no second one")
reset()
ROOM.name = "kitchen"
check(Spawn.tryRoom(grid[key(0, 0)], 0) == nil, "only bathrooms")
ROOM.name = "bathroom"

-- 5. the chance and the size ------------------------------------------------------
SandboxVars = { DeadWeight = { HomeScaleFloor = 0 } }
check(Spawn.tryRoom(grid[key(0, 0)], 0) == nil, "chance 0 never spawns")
SandboxVars = { DeadWeight = { HomeScaleFloor = 20 } }
check(Spawn.tryRoom(grid[key(0, 0)], 50) == nil, "a roll above the chance does not spawn")
SandboxVars = { DeadWeight = { HomeScaleFloor = 100 } }
for x = 0, 2 do for y = 0, 3 do if not (x == 1 and y == 3) then FURN[key(x, y)] = true end end end
check(Spawn.tryRoom(grid[key(0, 0)], 0) == nil, "a room full of furniture gets no scale")
reset()
local full = squares
squares = { grid[key(0, 0)], grid[key(1, 0)], grid[key(0, 1)], grid[key(1, 1)] }   -- a 2 x 2 closet
check(Spawn.tryRoom(grid[key(0, 0)], 0) == nil, "a small bathroom has no room for a scale")
squares = full

-- 6. process: one roll per room however many toilets it holds --------------------
reset()
FURN[key(0, 0)] = true
Spawn.onNewToilet({ getSquare = function() return grid[key(0, 0)] end })
Spawn.onNewToilet({ getSquare = function() return grid[key(2, 0)] end })
ZombRand = function(n) return 0 end
Spawn.process()
local placed = 0
for _, s in pairs(grid) do placed = placed + #s.added end
check(placed == 1, "two toilets in one room: one scale at most, got " .. placed)
check(Spawn.pendingCount() == 0, "the queue is drained")

-- 7. never on a client -----------------------------------------------------------
CLIENT = true
package.loaded["WeightScale/WeightScaleSpawn"] = nil
onNew = {}
require("WeightScale/WeightScaleSpawn")
check(next(onNew) == nil, "a multiplayer client registers no spawn hook")

print(nAssert .. " assertions passed")
