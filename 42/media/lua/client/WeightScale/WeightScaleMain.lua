-- Wires the modules to game events. Nothing here computes geometry or motion;
-- it only starts/stops the HUD and feeds it the player's weight.
require "WeightScale/WeightScaleGeo"
require "WeightScale/WeightScaleCore"
require "WeightScale/WeightScaleDetect"
require "WeightScale/WeightScaleHUD"
require "WeightScale/WeightScalePrefs"

WeightScale = WeightScale or {}
WeightScale.Main = WeightScale.Main or {}
local Main = WeightScale.Main

local function currentWeightKg()
    local playerObj = getSpecificPlayer and getSpecificPlayer(0)
    if not playerObj then return WeightScale.Geo.weight.start end
    local nutrition = playerObj.getNutrition and playerObj:getNutrition()
    local w = nutrition and nutrition.getWeight and nutrition:getWeight()
    if type(w) ~= "number" then return WeightScale.Geo.weight.start end
    return w
end

function Main.onGameStart()
    WeightScale.Prefs.load()
    if not Main.hud then
        Main.hud = WeightScale.HUD:new()
        Main.hud:addToUIManager()
    end

    WeightScale.Detect.onScaleOn = function()
        Main.hud:startOn(currentWeightKg())
    end
    WeightScale.Detect.onScaleOff = function()
        Main.hud:startOff()
    end
end

-- OnPlayerUpdate exists on both builds (fires once per player per game tick),
-- unlike some newer per-frame events. Detect throttles internally.
function Main.onPlayerUpdate(playerObj)
    if not Main.hud then return end
    if playerObj ~= getSpecificPlayer(0) then return end
    WeightScale.Detect.update()
end

function Main.onResolutionChange(oldW, oldH, newW, newH)
    if Main.hud then
        Main.hud:onResolutionChange(oldW, oldH, newW, newH)
    end
end

-- B41 UNPROVEN: OnPlayerUpdate (no legacy evidence either way). Falls back to
-- the always-present OnTick, at the cost of Detect throttling its own work.
function Main.onTick()
    WeightScale.Detect.update()
end

Events.OnGameStart.Add(Main.onGameStart)
if Events.OnPlayerUpdate then
    Events.OnPlayerUpdate.Add(Main.onPlayerUpdate)
else
    Events.OnTick.Add(Main.onTick)
end
Events.OnResolutionChange.Add(Main.onResolutionChange)
