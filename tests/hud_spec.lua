-- Bench for the HUD's UI manager lifecycle, splitscreen fan-out and the
-- step on/off sounds, run under lua5.1 (no PZ runtime). Minimal stubs for
-- exactly what the mod calls: ISUIElement:derive/new, the four bound
-- setters, addToUIManager/removeFromUIManager (the real jar names, both
-- deferred through toAdd/toRemove), getCore/getTimestampMs/Events,
-- getSpecificPlayer/getNumActivePlayers, and the per-player viewport
-- getters (getPlayerScreenLeft/Top/Width/Height).
package.path = "src/lua/client/?.lua;" .. package.path

local nAssert = 0
local function check(cond, msg)
    nAssert = nAssert + 1
    if not cond then
        io.stderr:write("FAIL: " .. msg .. "\n")
        os.exit(1)
    end
end

-- fake UI manager --------------------------------------------------------
UIManager = { ui = {} }
function UIManager.AddUI(el) table.insert(UIManager.ui, el) end
function UIManager.RemoveElement(el)
    for i = #UIManager.ui, 1, -1 do
        if UIManager.ui[i] == el then table.remove(UIManager.ui, i) end
    end
end
local function registered(el)
    local n = 0
    for i = 1, #UIManager.ui do
        if UIManager.ui[i] == el then n = n + 1 end
    end
    return n
end

-- fake ISUIElement -------------------------------------------------------
ISUIElement = {}
ISUIElement.__index = ISUIElement
function ISUIElement:derive(name)
    local o = {}
    setmetatable(o, self)
    self.__index = self
    o.Type = name
    return o
end
function ISUIElement:new(x, y, w, h)
    local o = {}
    setmetatable(o, self)
    self.__index = self
    o.x, o.y, o.width, o.height = x, y, w, h
    return o
end
function ISUIElement:setX(x) self.x = x end
function ISUIElement:setY(y) self.y = y end
function ISUIElement:setWidth(w) self.width = w end
function ISUIElement:setHeight(h) self.height = h end
function ISUIElement:addToUIManager() UIManager.AddUI(self) end
function ISUIElement:removeFromUIManager() UIManager.RemoveElement(self) end

-- fake game: screen, players, viewports, sounds --------------------------
local SCREEN = { w = 1920, h = 1080 }
local core = {
    getScreenWidth = function() return SCREEN.w end,
    getScreenHeight = function() return SCREEN.h end,
}
function getCore() return core end

local NOW = 1000
function getTimestampMs() return NOW end

local events = {}
local function mkEvent(name)
    events[name] = {}
    return { Add = function(fn) table.insert(events[name], fn) end }
end
Events = {
    OnGameStart = mkEvent("OnGameStart"),
    OnPlayerUpdate = mkEvent("OnPlayerUpdate"),
    OnResolutionChange = mkEvent("OnResolutionChange"),
    OnTick = mkEvent("OnTick"),
    -- WeightScaleMain now also requires WeightScaleMenu (task 2026-09-18,
    -- point B), which registers itself on this event at load time; this
    -- bench does not exercise the menu (see tests/menu_spec.lua), it only
    -- needs the require chain not to error.
    OnFillWorldObjectContextMenu = mkEvent("OnFillWorldObjectContextMenu"),
}
local function fire(name, ...)
    for i = 1, #events[name] do events[name][i](...) end
end

-- Players: table keyed by 0-based index, nil = empty/disconnected slot.
-- playSound is recorded so the sound bench can check what fired and for whom.
local SOUND_LOG = {}
local PLAYERS = {}
local function makePlayer(n)
    return {
        getPlayerNum = function(self) return n end,
        getNutrition = function() return nil end,
        isDead = function() return false end,
        playSound = function(self, name) table.insert(SOUND_LOG, { n = n, name = name }) end,
    }
end
PLAYERS[0] = makePlayer(0)
function getSpecificPlayer(n) return PLAYERS[n] end

local ACTIVE = 1
function getNumActivePlayers() return ACTIVE end

-- Per-player viewport: defaults to the full screen when a player has no
-- entry, so player 0 with no VIEWPORTS override reproduces the exact
-- pre-splitscreen formula (task point A2, "single player unchanged").
local VIEWPORTS = {}
function getPlayerScreenLeft(n) return (VIEWPORTS[n] and VIEWPORTS[n].left) or 0 end
function getPlayerScreenTop(n) return (VIEWPORTS[n] and VIEWPORTS[n].top) or 0 end
function getPlayerScreenWidth(n) return (VIEWPORTS[n] and VIEWPORTS[n].w) or SCREEN.w end
function getPlayerScreenHeight(n) return (VIEWPORTS[n] and VIEWPORTS[n].h) or SCREEN.h end

require("WeightScale/WeightScaleMain")
local Geo, Core = WeightScale.Geo, WeightScale.Core
local Detect, Prefs, Main = WeightScale.Detect, WeightScale.Prefs, WeightScale.Main

-- 1. mod loaded, player idle: nothing at all in the UI manager.
check(#UIManager.ui == 0, "loading the mod must not register anything")
fire("OnGameStart")
check(#UIManager.ui == 0, "an idle mod must not register anything")
fire("OnPlayerUpdate", PLAYERS[0])
check(#UIManager.ui == 0, "ticking while idle must not register anything")
check(#SOUND_LOG == 0, "no sound while idle")

-- 2. stepping on player 0's scale builds and registers its HUD, at the
--    readout size, at the SAME anchor as before splitscreen existed.
Detect.onScaleOn(0)
local hud = Main.huds[0]
check(hud ~= nil, "stepping on builds player 0's HUD")
check(registered(hud) == 1, "stepping on registers the HUD once, got " .. registered(hud))
check(#UIManager.ui == 1, "nothing else may be registered")
check(hud.width == Geo.readout.w, "element width must be the beam readout width")
check(hud.height == Geo.readout.h, "element height must be the beam readout height")
check(hud.x == math.floor(SCREEN.w / 2 + Geo.offset.dx), "element x is the beam anchor, single player unchanged")
check(hud.y == math.floor(SCREEN.h / 2 + Geo.offset.dy), "element y is the beam anchor, single player unchanged")
check(#SOUND_LOG == 1 and SOUND_LOG[1].name == "WeightScaleOn" and SOUND_LOG[1].n == 0,
    "stepping on plays WeightScaleOn once for player 0")

-- 3. clicks: the element is the readout, local coordinates, alpha gated.
NOW = NOW + 200
check(hud:hitLocal(0, 0) == true, "top left of the element is a hit")
check(hud:hitLocal(Geo.readout.w - 1, Geo.readout.h - 1) == true, "last inside pixel is a hit")
check(hud:hitLocal(-1, 10) == false, "left of the element is not a hit")
check(hud:hitLocal(Geo.readout.w, 10) == false, "right of the element is not a hit")
check(hud:onMouseDown(10, 10) == true, "left click inside toggles and is consumed")
check(Prefs.unit == "lb", "left click toggles kg -> lb, got " .. tostring(Prefs.unit))
check(hud:onRightMouseDown(10, 10) == true, "right click inside toggles and is consumed")
check(Prefs.style == "panel", "right click toggles beam -> panel, got " .. tostring(Prefs.style))
check(hud.width == Geo.panel.w, "the element follows the panel style width")
check(hud.height == Geo.panel.h, "the element follows the panel style height")
check(hud.y == math.floor(SCREEN.h / 2 + Geo.panel.dy), "the element follows the panel offset")
hud:onMouseDown(10, 10)
hud:onRightMouseDown(10, 10)
check(Prefs.unit == "kg" and Prefs.style == "beam", "toggles are reversible")

-- 4. resolution change keeps the element on the readout rectangle.
SCREEN.w, SCREEN.h = 1280, 720
fire("OnResolutionChange", 1920, 1080, 1280, 720)
check(hud.x == math.floor(1280 / 2 + Geo.offset.dx), "resolution change moves the element")
check(hud.width == Geo.readout.w, "resolution change keeps the readout width")
SCREEN.w, SCREEN.h = 1920, 1080

-- 5. stepping off keeps it until the leaving animation is over, then drops it.
Detect.onScaleOff(0)
check(#SOUND_LOG == 2 and SOUND_LOG[2].name == "WeightScaleOff" and SOUND_LOG[2].n == 0,
    "stepping off plays WeightScaleOff once for player 0")
NOW = NOW + Core.T.offEnd - 1
fire("OnPlayerUpdate", PLAYERS[0])
check(registered(hud) == 1, "the HUD stays while the leaving animation plays")
check(hud:hitLocal(10, 10) == true, "a fading leaving frame is still clickable while alpha > 0")
check(#SOUND_LOG == 2, "no extra sound while the leaving animation is still running")
NOW = NOW + 1
fire("OnPlayerUpdate", PLAYERS[0])
check(registered(hud) == 0, "the leaving animation over, the HUD is unregistered")
check(#UIManager.ui == 0, "nothing is left in the UI manager")
check(hud.mode == "idle", "the HUD is idle once unregistered")
check(hud:onRightMouseDown(10, 10) == false, "an idle HUD consumes no click")
check(#SOUND_LOG == 2, "letting the leaving animation finish plays no extra sound")

-- 6. on/off cycles never leave two elements registered. onScaleOn/Off are
--    called directly here (bypassing Detect.update's own transition guard,
--    on purpose) to check HUD:show()/hide() are themselves idempotent.
for i = 1, 4 do
    Detect.onScaleOn(0)
    check(registered(hud) == 1, "cycle " .. i .. " registers exactly one element")
    Detect.onScaleOn(0)
    check(registered(hud) == 1, "cycle " .. i .. " re-entry must not add a second element")
    Detect.onScaleOff(0)
    NOW = NOW + Core.T.offEnd
    fire("OnPlayerUpdate", PLAYERS[0])
    check(#UIManager.ui == 0, "cycle " .. i .. " leaves the UI manager empty")
end

-- 6b. the real path: Detect.update() itself must fire the sound exactly
--     once per transition, never while idle and never twice while still on
--     the scale (task point B bench). A fake square carries the scale
--     sprite; tickEvery is dropped to 1 so one call is one check.
Detect.tickEvery = 1
SOUND_LOG = {}
local function scaleObj()
    return { getSprite = function()
        return { getName = function() return "location_community_medical_01_8" end }
    end }
end
local function scaleSquare(onScale)
    return { getObjects = function()
        return {
            size = function() return onScale and 1 or 0 end,
            get = function(_, i) return scaleObj() end,
        }
    end }
end
local CURRENT = false
PLAYERS[0].getCurrentSquare = function() return scaleSquare(CURRENT) end
for i = 1, 5 do Detect.update(0, PLAYERS[0]) end
check(#SOUND_LOG == 0, "walking around off the scale plays no sound")
CURRENT = true
Detect.update(0, PLAYERS[0])
for i = 1, 5 do Detect.update(0, PLAYERS[0]) end
check(#SOUND_LOG == 1 and SOUND_LOG[1].name == "WeightScaleOn",
    "stepping on plays WeightScaleOn exactly once, got " .. #SOUND_LOG)
for i = 1, 10 do Detect.update(0, PLAYERS[0]) end
check(#SOUND_LOG == 1, "standing still on the scale never plays the on-sound twice")
CURRENT = false
Detect.update(0, PLAYERS[0])
for i = 1, 5 do Detect.update(0, PLAYERS[0]) end
check(#SOUND_LOG == 2 and SOUND_LOG[2].name == "WeightScaleOff",
    "stepping off plays WeightScaleOff exactly once, got " .. #SOUND_LOG)
PLAYERS[0].getCurrentSquare = nil
Detect.tickEvery = 6
NOW = NOW + Core.T.offEnd + 1
fire("OnPlayerUpdate", PLAYERS[0])

-- 7. splitscreen: a second local player gets its own HUD, its own square,
--    its own sound, and never crosses with player 0's (task point A1/A2/B).
PLAYERS[1] = makePlayer(1)
ACTIVE = 2
VIEWPORTS[0] = { left = 0, top = 0, w = 960, h = 1080 }
VIEWPORTS[1] = { left = 960, top = 0, w = 960, h = 1080 }
SOUND_LOG = {}
Detect.onScaleOn(0)
Detect.onScaleOn(1)
local hud0, hud1 = Main.huds[0], Main.huds[1]
check(hud0 ~= nil and hud1 ~= nil, "both players get their own HUD instance")
check(hud0 ~= hud1, "the two players' HUDs are different objects")
check(registered(hud0) == 1 and registered(hud1) == 1, "both HUDs are registered independently")
check(hud0.x == math.floor(0 + 960 / 2 + Geo.offset.dx), "player 0 anchors to its own half of the screen")
check(hud1.x == math.floor(960 + 960 / 2 + Geo.offset.dx), "player 1 anchors to its own half of the screen")
check(#SOUND_LOG == 2, "two step-ons play two sounds, got " .. #SOUND_LOG)
check(SOUND_LOG[1].n == 0 and SOUND_LOG[2].n == 1, "each on-sound went to its own player's emitter")

Detect.onScaleOff(0)
NOW = NOW + Core.T.offEnd + 1
fire("OnPlayerUpdate", PLAYERS[0])
check(registered(hud0) == 0, "player 0 leaving the scale removes only player 0's element")
check(registered(hud1) == 1, "player 1's element never crosses to player 0's transition")
check(SOUND_LOG[3].name == "WeightScaleOff" and SOUND_LOG[3].n == 0, "off-sound went to player 0 only")
Detect.onScaleOff(1)
NOW = NOW + Core.T.offEnd + 1
fire("OnPlayerUpdate", PLAYERS[1])
check(registered(hud1) == 0, "player 1's element is dropped on its own leaving transition")

-- 8. viewport math for 1, 2 (side by side) and 4 player layouts, using
--    stubbed viewport values, read straight off HUD:anchor (task point A5).
VIEWPORTS = { [0] = { left = 0, top = 0, w = 1920, h = 1080 } }
local ax, ay = hud0:anchor("beam")
check(ax == math.floor(1920 / 2 + Geo.offset.dx) and ay == math.floor(1080 / 2 + Geo.offset.dy),
    "1-player layout: anchor is plain screen centre")

VIEWPORTS = {
    [0] = { left = 0, top = 0, w = 960, h = 1080 },
    [1] = { left = 960, top = 0, w = 960, h = 1080 },
}
ax, ay = hud0:anchor("beam")
check(ax == math.floor(0 + 480 + Geo.offset.dx) and ay == math.floor(1080 / 2 + Geo.offset.dy),
    "2-player layout: player 0 centres on the left half")
ax, ay = hud1:anchor("beam")
check(ax == math.floor(960 + 480 + Geo.offset.dx) and ay == math.floor(1080 / 2 + Geo.offset.dy),
    "2-player layout: player 1 centres on the right half")

VIEWPORTS = {
    [0] = { left = 0,    top = 0,   w = 960, h = 540 },
    [1] = { left = 960,  top = 0,   w = 960, h = 540 },
    [2] = { left = 0,    top = 540, w = 960, h = 540 },
    [3] = { left = 960,  top = 540, w = 960, h = 540 },
}
local hud2 = WeightScale.HUD:new(2)
local hud3 = WeightScale.HUD:new(3)
ax, ay = hud0:anchor("beam")
check(ax == math.floor(480 + Geo.offset.dx) and ay == math.floor(270 + Geo.offset.dy), "4-player: top-left quadrant")
ax, ay = hud1:anchor("beam")
check(ax == math.floor(1440 + Geo.offset.dx) and ay == math.floor(270 + Geo.offset.dy), "4-player: top-right quadrant")
ax, ay = hud2:anchor("beam")
check(ax == math.floor(480 + Geo.offset.dx) and ay == math.floor(810 + Geo.offset.dy), "4-player: bottom-left quadrant")
ax, ay = hud3:anchor("beam")
check(ax == math.floor(1440 + Geo.offset.dx) and ay == math.floor(810 + Geo.offset.dy), "4-player: bottom-right quadrant")
hud2:destroy()
hud3:destroy()
VIEWPORTS = {}
ACTIVE = 2

-- 9. a player slot going nil (disconnect) removes its element and clears
--    its Detect state; nothing may leak (task point A3).
Detect.onScaleOn(1)
hud1 = Main.huds[1]
check(registered(hud1) == 1, "player 1 is back on the scale before disconnecting")
PLAYERS[1] = nil
ACTIVE = 1
fire("OnPlayerUpdate", PLAYERS[0])
check(registered(hud1) == 0, "a disconnected player's element is removed from the UI manager")
check(Main.huds[1] == nil, "a disconnected player's HUD reference is dropped")
check(Detect.players[1] == nil, "a disconnected player's Detect state is cleared")

print(nAssert .. " assertions passed")
check(nAssert > 0, "no assertions ran")
