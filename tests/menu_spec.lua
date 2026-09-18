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

Events = { OnFillWorldObjectContextMenu = { Add = function() end } }
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
local function list(items) return { size = function() return #items end, get = function(_, i) return items[i + 1] end } end

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
local square = { id = "scale-square" }
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

print(nAssert .. " assertions passed")
check(nAssert > 0, "no assertions ran")
