-- Bench for the HUD's UI manager lifecycle, run under lua5.1 (no PZ runtime).
-- Minimal stubs for exactly what the mod calls: ISUIElement:derive/new, the
-- four bound setters, addToUIManager/removeFromUIManager (which call
-- UIManager.AddUI/RemoveElement, the real names, both deferred lists in the
-- jar), plus getCore/getTimestampMs/Events/getSpecificPlayer.
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

-- fake game ---------------------------------------------------------------
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
}

local PLAYER = { getNutrition = function() return nil end }
function getSpecificPlayer(n) if n == 0 then return PLAYER end end

require("WeightScale/WeightScaleMain")
local Geo, Core = WeightScale.Geo, WeightScale.Core
local Detect, Prefs = WeightScale.Detect, WeightScale.Prefs

local function fire(name, ...)
    for i = 1, #events[name] do events[name][i](...) end
end

-- 1. mod loaded, player idle: nothing at all in the UI manager.
check(#UIManager.ui == 0, "loading the mod must not register anything")
fire("OnGameStart")
local hud = WeightScale.Main.hud
check(hud ~= nil, "OnGameStart builds the HUD")
check(#UIManager.ui == 0, "an idle HUD must not be registered, got " .. #UIManager.ui)
fire("OnPlayerUpdate", PLAYER)
check(#UIManager.ui == 0, "ticking while idle must not register the HUD")

-- 2. stepping on the scale registers it exactly once, at the readout size.
Detect.onScaleOn()
check(registered(hud) == 1, "stepping on registers the HUD once, got " .. registered(hud))
check(#UIManager.ui == 1, "nothing else may be registered")
check(hud.width == Geo.readout.w, "element width must be the beam readout width")
check(hud.height == Geo.readout.h, "element height must be the beam readout height")
check(hud.x == math.floor(SCREEN.w / 2 + Geo.offset.dx), "element x is the beam anchor")
check(hud.y == math.floor(SCREEN.h / 2 + Geo.offset.dy), "element y is the beam anchor")

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
Detect.onScaleOff()
NOW = NOW + Core.T.offEnd - 1
fire("OnPlayerUpdate", PLAYER)
check(registered(hud) == 1, "the HUD stays while the leaving animation plays")
check(hud:hitLocal(10, 10) == true, "a fading leaving frame is still clickable while alpha > 0")
NOW = NOW + 1
fire("OnPlayerUpdate", PLAYER)
check(registered(hud) == 0, "the leaving animation over, the HUD is unregistered")
check(#UIManager.ui == 0, "nothing is left in the UI manager")
check(hud.mode == "idle", "the HUD is idle once unregistered")
check(hud:onRightMouseDown(10, 10) == false, "an idle HUD consumes no click")

-- 6. on/off cycles never leave two elements registered.
for i = 1, 4 do
    Detect.onScaleOn()
    check(registered(hud) == 1, "cycle " .. i .. " registers exactly one element")
    Detect.onScaleOn()
    check(registered(hud) == 1, "cycle " .. i .. " re-entry must not add a second element")
    Detect.onScaleOff()
    NOW = NOW + Core.T.offEnd
    fire("OnPlayerUpdate", PLAYER)
    check(#UIManager.ui == 0, "cycle " .. i .. " leaves the UI manager empty")
end

print(nAssert .. " assertions passed")
check(nAssert > 0, "no assertions ran")
