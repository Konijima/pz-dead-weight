-- Bench for WeightScaleMenu, run under lua5.1 (no PZ runtime). Stubs exactly
-- what the module calls: Events, getSpecificPlayer, getTexture, getText,
-- ISWorldObjectContextMenu's test flag, a recording ISContextMenu (with and
-- without addOptionOnTop), ISTimedActionQueue.add and ISWalkToTimedAction:new.
package.path = "src/lua/client/?.lua;" .. package.path

local nAssert = 0
local function check(cond, msg)
    nAssert = nAssert + 1
    if not cond then
        io.stderr:write("FAIL: " .. msg .. "\n")
        os.exit(1)
    end
end

local TICKERS = {}
Events = {
    OnFillWorldObjectContextMenu = { Add = function() end },
    OnTick = {
        Add = function(f) TICKERS[#TICKERS + 1] = f end,
        Remove = function(f) for i = #TICKERS, 1, -1 do if TICKERS[i] == f then table.remove(TICKERS, i) end end end,
    },
}
local CLOCK = 1000
function getTimestampMs() return CLOCK end
ISWorldObjectContextMenu = {
    Test = false,
    setTest = function() ISWorldObjectContextMenu.Test = true; return true end,
}

local textureCalls = 0
function getTexture(path) textureCalls = textureCalls + 1; return { path = path } end
function getText(key) return key end

local PLAYERS = {}
function getSpecificPlayer(n) return PLAYERS[n] end

local QUEUE = {}
ISTimedActionQueue = { add = function(action) table.insert(QUEUE, action) end }
ISWalkToTimedAction = {}
function ISWalkToTimedAction:new(character, location)
    return { character = character, location = location }
end

require "WeightScale/WeightScaleDetect"
require "WeightScale/WeightScaleMenu"
local Menu = WeightScale.Menu

local function player(square) return { getCurrentSquare = function() return square end } end
local function scaleObj(square) return { getSprite = function() return { getName = function() return "location_community_medical_01_8" end } end, getSquare = function() return square end } end
local function otherObj(square) return { getSprite = function() return { getName = function() return "some_other_sprite" end } end, getSquare = function() return square end } end
-- `worldobjects` as ISObjectClickHandler.doRClick builds it and
-- ISWorldObjectContextMenu.createMenu reads it: a plain Lua array table,
-- walked with ipairs -- proven in ISWorldObjectContextMenu.lua and
-- ISBBQMenu.lua (both vanilla, client install). NOT a Java list: giving this
-- stub a :size()/:get() would be the code's own wrong assumption again, not
-- vanilla, so it deliberately has neither.
local function list(items) return items end

local function newContext(withTop)
    local ctx = { options = {} }
    function ctx:addOption(name, target, onSelect, ...)
        local opt = { name = name, target = target, onSelect = onSelect, p1 = ... }
        table.insert(self.options, opt)
        return opt
    end
    if withTop then
        function ctx:addOptionOnTop(name, target, onSelect, ...)
            local opt = { name = name, target = target, onSelect = onSelect, p1 = ... }
            table.insert(self.options, 1, opt)
            return opt
        end
    end
    return ctx
end

-- 1/2/4: appears once, on top, for a scale object; absent for another object.
local square = { id = "scale-square", getX = function() return 30 end, getY = function() return 40 end }
PLAYERS[0] = player(nil)
local ctxTop = newContext(true)
Menu.OnFillWorldObjectContextMenu(0, ctxTop, list({ scaleObj(square) }), false)
check(#ctxTop.options == 1, "one option added for a scale object")
check(ctxTop.options[1].name == "ContextMenu_WeightScale_StepOn", "option carries the translation key")
table.insert(ctxTop.options, 1, { name = "unrelated" })
local ctxTop2 = newContext(true)
Menu.OnFillWorldObjectContextMenu(0, ctxTop2, list({ scaleObj(square), scaleObj(square) }), false)
check(#ctxTop2.options == 1, "never added twice when several matching objects are present")
check(ctxTop2.options[1].name == "ContextMenu_WeightScale_StepOn", "the single option is inserted on top")

local ctxOther = newContext(true)
Menu.OnFillWorldObjectContextMenu(0, ctxOther, list({ otherObj(square) }), false)
check(#ctxOther.options == 0, "absent for a non-scale object")

-- 4b: fallback to addOption when addOptionOnTop is not present at runtime.
local ctxNoTop = newContext(false)
Menu.OnFillWorldObjectContextMenu(0, ctxNoTop, list({ scaleObj(square) }), false)
check(#ctxNoTop.options == 1, "falls back to addOption when addOptionOnTop is absent")

-- 3: absent (and cheap) when test requires it per the vanilla convention.
ISWorldObjectContextMenu.Test = true
local ctxTestSkip = newContext(true)
local r = Menu.OnFillWorldObjectContextMenu(0, ctxTestSkip, list({ scaleObj(square) }), true)
check(r == true, "test pass returns true immediately once ISWorldObjectContextMenu.Test is set")
check(#ctxTestSkip.options == 0, "no option allocated during the cheap test early exit")
ISWorldObjectContextMenu.Test = false
local ctxTestFound = newContext(true)
r = Menu.OnFillWorldObjectContextMenu(0, ctxTestFound, list({ scaleObj(square) }), true)
check(r == true, "test pass reports true when a scale is found")
check(#ctxTestFound.options == 0, "no option allocated on a test pass, only setTest()")
check(ISWorldObjectContextMenu.Test == true, "setTest() marks the shared test flag")

-- 5: hidden when the player already stands on the scale's square.
ISWorldObjectContextMenu.Test = false
PLAYERS[0] = player(square)
local ctxOnScale = newContext(true)
Menu.OnFillWorldObjectContextMenu(0, ctxOnScale, list({ scaleObj(square) }), false)
check(#ctxOnScale.options == 0, "hidden when the player already stands on the scale's square")
PLAYERS[0] = player(nil)

-- 5b: a scale drawn lifted onto a counter (render offset > 0) offers no step on.
PLAYERS[0] = player(nil)
local liftedObj = scaleObj(square)
liftedObj.getRenderYOffset = function() return 34 end
local ctxLift = newContext(true)
Menu.OnFillWorldObjectContextMenu(0, ctxLift, list({ liftedObj }), false)
check(#ctxLift.options == 0, "no Step on Scale for a scale sitting on a counter")
local floorObj = scaleObj(square)
floorObj.getRenderYOffset = function() return 0 end
local ctxFloor = newContext(true)
Menu.OnFillWorldObjectContextMenu(0, ctxFloor, list({ floorObj }), false)
check(#ctxFloor.options == 1, "Step on Scale kept for a scale on the floor")

-- 6: selecting queues one walk for the RIGHT player to the RIGHT square,
--    a two player case.
local squareA, squareB = { id = "A" }, { id = "B" }
PLAYERS[0] = player(nil)
PLAYERS[1] = player(nil)
local ctxA = newContext(true)
Menu.OnFillWorldObjectContextMenu(0, ctxA, list({ scaleObj(squareA) }), false)
local ctxB = newContext(true)
Menu.OnFillWorldObjectContextMenu(1, ctxB, list({ scaleObj(squareB) }), false)
QUEUE = {}
ctxA.options[1].onSelect(ctxA.options[1].target, ctxA.options[1].p1)
check(#QUEUE == 1, "selecting queues exactly one action")
check(QUEUE[1].character == PLAYERS[0], "the walk targets player 0, the one who opened the menu")
check(QUEUE[1].location == squareA, "the walk targets player 0's own scale square")
QUEUE = {}
ctxB.options[1].onSelect(ctxB.options[1].target, ctxB.options[1].p1)
check(QUEUE[1].character == PLAYERS[1], "the walk targets player 1 in the two player case")
check(QUEUE[1].location == squareB, "the walk targets player 1's own scale square, not player 0's")

-- 7: icon texture requested once across many menu opens (the module already
-- opened several menus above, so the cache is warm; further opens must not
-- call getTexture again).
for i = 1, 5 do
    local ctx = newContext(true)
    Menu.OnFillWorldObjectContextMenu(0, ctx, list({ scaleObj(square) }), false)
    check(ctx.options[1].iconTexture ~= nil, "the option carries an icon texture")
end
check(textureCalls == 1, "the icon texture is requested exactly once across many menu opens, got " .. textureCalls)

-- 8: regression (game crash 2026-09-18, "Object tried to call nil in
--    findScaleSquare"): `list()` above is the plain Lua array table vanilla
--    actually hands OnFillWorldObjectContextMenu (ISObjectClickHandler.lua
--    table.insert, walked with ipairs in ISWorldObjectContextMenu.lua /
--    ISBBQMenu.lua), not a Java list. Every call above already exercises
--    this true shape; against the old code (worldobjects:size()) this line
--    alone throws "attempt to call method 'size' (a nil value)", the exact
--    failure from console.txt. These cases cover the mixed-class worldobjects
--    reality (IsoDeadBody/IsoPlayer/etc lack getSprite; nil sprite; nil name)
--    plus an empty click.
local ctxNoSprite = newContext(true)
local noGetSprite = { getSquare = function() return square end }
Menu.OnFillWorldObjectContextMenu(0, ctxNoSprite, list({ noGetSprite }), false)
check(#ctxNoSprite.options == 0, "an entry without getSprite (e.g. IsoDeadBody/IsoPlayer) is skipped, not a crash")

local ctxNilSprite = newContext(true)
local nilSpriteObj = { getSprite = function() return nil end, getSquare = function() return square end }
Menu.OnFillWorldObjectContextMenu(0, ctxNilSprite, list({ nilSpriteObj }), false)
check(#ctxNilSprite.options == 0, "an object with a nil sprite is skipped, not a crash")

local ctxNilName = newContext(true)
local nilNameObj = { getSprite = function() return { getName = function() return nil end } end, getSquare = function() return square end }
Menu.OnFillWorldObjectContextMenu(0, ctxNilName, list({ nilNameObj }), false)
check(#ctxNilName.options == 0, "a sprite with a nil name is skipped, not a crash")

local ctxEmpty = newContext(true)
Menu.OnFillWorldObjectContextMenu(0, ctxEmpty, list({}), false)
check(#ctxEmpty.options == 0, "an empty worldobjects list is a no-op, not a crash")

-- 9: "Put animal on scale" (Build 42). Stubs mirror vanilla: instanceof is a
--    global taking the class name, hands are getPrimaryHandItem/getSecondaryHandItem,
--    luautils.walkAdj queues its own walk and returns true.
local ANIMAL = { kind = "AnimalInventoryItem" }
local BOTTLE = { kind = "Food" }
function instanceof(o, class) return o ~= nil and o.kind == class end
local walkAdjArgs
luautils = { walkAdj = function(chr, sq, keep, exclude)
    walkAdjArgs = { chr = chr, sq = sq, keep = keep, exclude = exclude }
    ISTimedActionQueue.add({ walk = sq })
    return walkAdjArgs.ok ~= false
end }
ISUnequipAction = {}
function ISUnequipAction:new(chr, item, time, why) return { unequip = item, why = why } end
ISDropWorldItemAction = {}
function ISDropWorldItemAction:new(chr, item, sq, x, y, z, rot, multi)
    return { drop = item, sq = sq, x = x, y = y, z = z }
end
local function holder(sq, primary, secondary, equipped)
    local p = player(sq)
    function p:getPrimaryHandItem() return primary end
    function p:getSecondaryHandItem() return secondary end
    function p:isEquipped(item) return equipped == item end
    return p
end
local function labels(ctx) local t = {} for i, o in ipairs(ctx.options) do t[i] = o.name end return table.concat(t, ",") end

PLAYERS[0] = holder(nil, ANIMAL, nil, ANIMAL)
local ctxA1 = newContext(true)
Menu.OnFillWorldObjectContextMenu(0, ctxA1, list({ scaleObj(square) }), false)
check(labels(ctxA1) == "ContextMenu_WeightScale_PutAnimal,ContextMenu_WeightScale_StepOn",
    "holding an animal adds Put Animal on top of Step on Scale, got " .. labels(ctxA1))

PLAYERS[0] = holder(nil, BOTTLE, nil, BOTTLE)
local ctxA2 = newContext(true)
Menu.OnFillWorldObjectContextMenu(0, ctxA2, list({ scaleObj(square) }), false)
check(labels(ctxA2) == "ContextMenu_WeightScale_StepOn", "holding something else adds no animal option")

PLAYERS[0] = holder(nil, nil, ANIMAL, nil)
local ctxA3 = newContext(true)
Menu.OnFillWorldObjectContextMenu(0, ctxA3, list({ scaleObj(square) }), false)
check(#ctxA3.options == 2, "an animal in the secondary hand counts too")

-- standing on the scale while holding the animal: no Step on, still Put Animal
PLAYERS[0] = holder(square, ANIMAL, nil, ANIMAL)
local ctxA4 = newContext(true)
Menu.OnFillWorldObjectContextMenu(0, ctxA4, list({ scaleObj(square) }), false)
check(labels(ctxA4) == "ContextMenu_WeightScale_PutAnimal", "on the scale with an animal: only Put Animal, got " .. labels(ctxA4))

-- multiplayer client: the drop would be server only and the animal vanishes
isClient = function() return true end
PLAYERS[0] = holder(nil, ANIMAL, nil, ANIMAL)
local ctxA6 = newContext(true)
Menu.OnFillWorldObjectContextMenu(0, ctxA6, list({ scaleObj(square) }), false)
check(labels(ctxA6) == "ContextMenu_WeightScale_StepOn", "no Put Animal on an MP client, got " .. labels(ctxA6))
isClient = nil

-- test pass reports true and allocates nothing
ISWorldObjectContextMenu.Test = false
local ctxA5 = newContext(true)
check(Menu.OnFillWorldObjectContextMenu(0, ctxA5, list({ scaleObj(square) }), true) == true, "test pass sees the animal case")
check(#ctxA5.options == 0, "no option on a test pass")
ISWorldObjectContextMenu.Test = false

-- selecting: walk next to the scale excluding its square, unequip, then place
local opt = ctxA4.options[1]
QUEUE = {}
opt.onSelect(opt.target, opt.p1)
check(walkAdjArgs.sq == square and walkAdjArgs.exclude[1] == square, "walks adjacent to the scale, never onto it")
check(#QUEUE == 3, "walk, unequip, drop are queued, got " .. #QUEUE)
check(QUEUE[2].unequip == ANIMAL and QUEUE[2].why == "place", "the animal is unequipped first")
check(QUEUE[3].drop == ANIMAL and QUEUE[3].sq == square and QUEUE[3].x == 0.5 and QUEUE[3].y == 0.5, "then dropped on the scale square, middle")
check(QUEUE[3].isPlaceItem == true, "flagged as a place action so vanilla checks adjacency")

-- it turns towards the scale first: waitToStart faces the square middle and
-- reports whether the character is still turning; update keeps facing and
-- still runs the vanilla update
local faced, turning = nil, true
local chr = { faceLocation = function(_, x, y) faced = { x, y } end, shouldBeTurning = function() return turning end }
local act = QUEUE[3]
act.character = chr
check(act:waitToStart() == true and faced[1] == 30.5 and faced[2] == 40.5, "waitToStart faces the middle of the scale square and waits while turning")
turning = false
check(act:waitToStart() == false, "waitToStart lets the drop begin once the character faces the scale")
faced = nil
act:update()
check(faced ~= nil, "update keeps facing the scale during the drop")

-- not equipped (in a bag hand? no: no unequip step); walk refused: nothing queued
PLAYERS[0] = holder(nil, ANIMAL, nil, nil)
QUEUE = {}
opt.onSelect(PLAYERS[0], square)
check(#QUEUE == 2 and QUEUE[2].drop == ANIMAL, "an unequipped animal skips the unequip step")
walkAdjArgs = { ok = false }
QUEUE = {}
walkAdjArgs.ok = false
luautils.walkAdj = function() return false end
opt.onSelect(PLAYERS[0], square)
check(#QUEUE == 0, "no drop is queued when no square next to the scale is reachable")
-- the animal was put down meanwhile: selecting does nothing
PLAYERS[0] = holder(nil, nil, nil, nil)
opt.onSelect(PLAYERS[0], square)
check(#QUEUE == 0, "no animal in hand any more: nothing queued")
instanceof = nil
PLAYERS[0] = player(nil)

-- 10: the animal stays on the plate for Menu.holdMs once it has spawned.
local function tick(n) for _ = 1, n do for _, f in ipairs({ unpack(TICKERS) }) do f() end end end
local blocks = {}
local spawned = {}
local function javaList(t) return { size = function() return #t end, get = function(_, i) return t[i + 1] end } end
local ax, ay, stops = 10.5, 20.5, 0
local animalObj = { kind = "IsoAnimal", getAnimalID = function() return 77 end,
    getX = function() return ax end, getY = function() return ay end,
    setX = function(_, v) ax = v end, setY = function(_, v) ay = v end,
    stopAllMovementNow = function() stops = stops + 1 end,
    getBehavior = function() return { setBlockMovement = function(_, on) blocks[#blocks + 1] = on end } end }
local function sq9()  -- a scale square with the _9 sprite, plate centre (0.48, 0.37)
    local obj = { getSprite = function() return { getName = function() return "location_community_medical_01_9" end } end }
    return { getMovingObjects = function() return javaList(spawned) end,
             getX = function() return 100 end, getY = function() return 200 end,
             getObjects = function() return javaList({ obj }) end }
end
local holdSquare = sq9()
local carried = { kind = "AnimalInventoryItem", getAnimal = function() return { getAnimalID = function() return 77 end } end }
luautils = { walkAdj = function() return true end }
instanceof = function(o, class) return o ~= nil and o.kind == class end
PLAYERS[0] = holder(nil, carried, nil, nil)
local ctxH = newContext(true)
Menu.OnFillWorldObjectContextMenu(0, ctxH, list({ scaleObj(holdSquare) }), false)
QUEUE = {}
ctxH.options[1].onSelect(ctxH.options[1].target, ctxH.options[1].p1)
check(#TICKERS == 1, "a tick handler exists while an animal is pending")
tick(12)
check(#blocks == 0, "nothing is blocked before the animal has spawned")
spawned[1] = { kind = "IsoAnimal", getAnimalID = function() return 5 end }   -- someone else's animal
tick(12)
check(#blocks == 0, "another animal on the square is not held")
spawned[2] = animalObj
CLOCK = 4000
tick(6)
check(#blocks == 1 and blocks[1] == true, "the dropped animal is told to stand still")
check(math.abs(ax - 100.48) < 1e-9 and math.abs(ay - 200.37) < 1e-9, "the animal is moved to the plate centre of the sprite, got " .. ax .. "," .. ay)
ax = 11.4                      -- it tries to walk off the plate
tick(1)
check(math.abs(ax - 100.48) < 1e-9 and stops == 2, "a drifting animal is put back where it landed and stopped")
tick(1)
check(stops == 2, "an animal that stays put is left alone")
CLOCK = 4000 + Menu.holdMs - 1
tick(12)
check(#blocks == 1, "still held before holdMs has passed")
CLOCK = 4000 + Menu.holdMs + 1
tick(6)
check(#blocks == 2 and blocks[2] == false, "released once holdMs has passed")
check(#TICKERS == 0, "the tick handler is removed when nothing is pending")

-- the drop never happens (walk cancelled): give up, block nothing, no leak
spawned = {}
blocks = {}
holdSquare = sq9()
PLAYERS[0] = holder(nil, carried, nil, nil)
ctxH = newContext(true)
Menu.OnFillWorldObjectContextMenu(0, ctxH, list({ scaleObj(holdSquare) }), false)
CLOCK = 20000
ctxH.options[1].onSelect(ctxH.options[1].target, ctxH.options[1].p1)
CLOCK = 20000 + Menu.holdGiveUpMs + 1
tick(6)
check(#blocks == 0 and #TICKERS == 0, "a drop that never comes is given up on, nothing blocked")
instanceof = nil

print(nAssert .. " assertions passed")
check(nAssert > 0, "no assertions ran")
