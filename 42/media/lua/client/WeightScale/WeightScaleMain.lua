-- Wires the modules to game events. It computes nothing itself; it only
-- starts/stops the HUDs, feeds them the total on the scale, and calls into
-- Detect every tick (Detect.update for presence, Detect.updateFacing for
-- the queued once-per-step-on turn toward the scale's column, point B
-- 2026-09-18).
-- Splitscreen (task 2026-09-18, point A): one HUD instance and one Detect
-- state slot per local player, keyed by player index; Prefs stays the one
-- shared file (WeightScalePrefs.lua is untouched).
require "WeightScale/WeightScaleGeo"
require "WeightScale/WeightScaleCore"
require "WeightScale/WeightScaleDetect"
require "WeightScale/WeightScaleHUD"
require "WeightScale/WeightScalePrefs"
require "WeightScale/WeightScaleSound"
require "WeightScale/WeightScaleMenu"
require "WeightScale/WeightScaleCharScreen"

WeightScale = WeightScale or {}
WeightScale.Main = WeightScale.Main or {}
local Main = WeightScale.Main

Main.huds = Main.huds or {}   -- [n] = WeightScale.HUD instance
Main.MAX_PLAYERS = 4          -- PZ's own splitscreen ceiling
Main._lastCount = Main._lastCount or 0

local function activeCount()
    return (getNumActivePlayers and getNumActivePlayers()) or 1
end

function Main.hudFor(n)
    local hud = Main.huds[n]
    if not hud then
        -- Built but deliberately NOT added to the UI manager: a HUD only
        -- registers itself while its readout is on screen, so an idle
        -- player's mod owns no pixel and consumes no mouse event anywhere.
        hud = WeightScale.HUD:new(n)
        Main.huds[n] = hud
    end
    return hud
end

-- A slot going nil, dying, or disconnecting drops its element and its
-- Detect state: nothing may be left registered or tracked for it (point A3).
function Main.pruneInactive()
    for n = 0, Main.MAX_PLAYERS - 1 do
        local hud = Main.huds[n]
        if hud then
            local p = getSpecificPlayer and getSpecificPlayer(n)
            local gone = (not p) or (p.isDead and p:isDead())
            if gone then
                hud:destroy()
                Main.huds[n] = nil
                WeightScale.Detect.clear(n)
            end
        end
    end
end

-- Recompute every shown HUD's viewport-based position: required whenever the
-- number of active (splitscreen) players changes, on top of a resolution
-- change (point A2).
function Main.reapplyAllBounds()
    for n, hud in pairs(Main.huds) do
        if hud.shown then hud:applyBounds() end
    end
end

function Main.checkPlayerCount()
    local c = activeCount()
    if c ~= Main._lastCount then
        Main._lastCount = c
        Main.reapplyAllBounds()
    end
end

function Main.onGameStart()
    WeightScale.Prefs.load()
    Main._lastCount = activeCount()

    -- Occupancy drives the HUD (task 2026-09-20). Sound rule: every viewer
    -- hears the cue on THEIR OWN client when the scale goes empty -> occupied
    -- (they had watched it empty, or they are the one stepping on) or occupied
    -- -> empty while it is still in reach, whether a person or only an item
    -- caused it. Nothing travels over the network: each client detects the same
    -- change and plays the non 3D cue itself. Walking up to a scale that is
    -- already occupied, a second or later occupant, and walking out of reach
    -- (inReach false, unless the viewer was the one on it) all change the
    -- reading in silence.
    WeightScale.Detect.onOccupancy = function(n, kg, selfOn, wasEmpty, wasSelf, inReach, settled, entry)
        local playerObj = getSpecificPlayer and getSpecificPlayer(n)
        if kg then
            local hud = Main.hudFor(n)
            if wasEmpty then hud:startOn(kg, entry) else hud:retarget(kg, entry) end
            if wasEmpty and (settled or selfOn) then WeightScale.Sound.playOn(playerObj) end
        else
            local hud = Main.huds[n]
            if hud then hud:startOff() end
            if inReach or wasSelf then WeightScale.Sound.playOff(playerObj) end
        end
    end
end

-- OnPlayerUpdate exists on both builds (fires once per active player per
-- game tick), unlike some newer per-frame events. Detect throttles
-- internally, per player. getPlayerNum is B42 PROVEN (client lua, e.g.
-- ISFitnessUI.lua); nil-guarded, falling back to player 0.
function Main.onPlayerUpdate(playerObj)
    if not playerObj then return end
    local n = (playerObj.getPlayerNum and playerObj:getPlayerNum()) or 0
    WeightScale.Detect.update(n, playerObj)
    WeightScale.Detect.updateFacing(n, playerObj)
    local hud = Main.huds[n]
    if hud then hud:tick() end
    Main.pruneInactive()
    Main.checkPlayerCount()
end

function Main.onResolutionChange(oldW, oldH, newW, newH)
    for n, hud in pairs(Main.huds) do
        hud:onResolutionChange(oldW, oldH, newW, newH)
    end
end

-- B41 UNPROVEN: OnPlayerUpdate (no evidence either way in the 2022 release,
-- kept in git history at 6631165). Falls back to the always-present OnTick,
-- looping every active local player index ourselves (getNumActivePlayers/
-- getSpecificPlayer(n): B42 PROVEN, client lua e.g. Fishing/FishingHandler.lua;
-- B41 status per docs/API-COMPAT.md).
function Main.onTick()
    local c = activeCount()
    for n = 0, c - 1 do
        local playerObj = getSpecificPlayer and getSpecificPlayer(n)
        WeightScale.Detect.update(n, playerObj)
        WeightScale.Detect.updateFacing(n, playerObj)
        local hud = Main.huds[n]
        if hud then hud:tick() end
    end
    Main.pruneInactive()
    Main.checkPlayerCount()
end

Events.OnGameStart.Add(Main.onGameStart)
if Events.OnPlayerUpdate then
    Events.OnPlayerUpdate.Add(Main.onPlayerUpdate)
else
    Events.OnTick.Add(Main.onTick)
end
Events.OnResolutionChange.Add(Main.onResolutionChange)
