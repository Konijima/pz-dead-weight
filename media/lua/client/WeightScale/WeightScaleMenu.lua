-- Convenience context menu option (task 2026-09-18, point B): "Step on
-- Scale" at the TOP of the right click menu, for players who use the mouse.
-- Selecting it only queues a normal walk to the scale's square; detection,
-- the HUD and the sounds already fire on arrival by themselves (see
-- WeightScaleDetect.lua) -- this module draws nothing and tracks no state.
-- Hooked on Events.OnFillWorldObjectContextMenu, honouring the vanilla
-- `test` convention (ISWorldObjectContextMenu.lua, e.g. ISBBQMenu.lua): a
-- cheap early return when another handler already confirmed an option, and
-- `ISWorldObjectContextMenu.setTest()` once we know we would add ours.
-- See docs/API-COMPAT.md for every call proven here.
require "WeightScale/WeightScaleDetect"

WeightScale = WeightScale or {}
WeightScale.Menu = WeightScale.Menu or {}
local Menu = WeightScale.Menu

local TEX_PATH = "media/textures/WeightScale/weightscale_icon.png"
local _icon    -- cached texture, requested once no matter how many opens

local function icon()
    if _icon == nil and getTexture then
        _icon = getTexture(TEX_PATH) or false
    end
    return _icon or nil
end

-- Reuses the mod's one sprite list (WeightScaleDetect.spriteNames): scans
-- the clicked objects, then that object's own square, exactly as vanilla
-- handlers do (e.g. ISBBQMenu.lua walks worldobjects' squares). `worldobjects`
-- is the plain Lua array table ISObjectClickHandler.doRClick builds with
-- table.insert and ISWorldObjectContextMenu.createMenu walks with
-- ipairs(worldobjects) (proven in ISWorldObjectContextMenu.lua and
-- ISBBQMenu.lua) -- NOT a Java list, so it has no :size()/:get(). The
-- clicked entries can be any IsoObject subclass (IsoWorldInventoryObject,
-- IsoDeadBody, IsoPlayer, IsoZombie...), so every accessor stays guarded.
local function findScaleSquare(worldobjects)
    if not worldobjects then return nil end
    for _, obj in ipairs(worldobjects) do
        local sprite = obj and obj.getSprite and obj:getSprite()
        local name = sprite and sprite.getName and sprite:getName()
        if name and WeightScale.Detect.spriteNames[name] then
            local square = obj.getSquare and obj:getSquare()
            if square then return square end
        end
    end
    return nil
end

local function playerOnSquare(playerObj, square)
    if not playerObj or not playerObj.getCurrentSquare then return false end
    return playerObj:getCurrentSquare() == square
end

local function onSelect(playerObj, square)
    ISTimedActionQueue.add(ISWalkToTimedAction:new(playerObj, square))
end

function Menu.OnFillWorldObjectContextMenu(player, context, worldobjects, test)
    if test and ISWorldObjectContextMenu.Test then return true end

    local square = findScaleSquare(worldobjects)
    if not square then return end

    local playerObj = getSpecificPlayer and getSpecificPlayer(player)
    if playerOnSquare(playerObj, square) then return end

    if test then return ISWorldObjectContextMenu.setTest() end

    local label = getText and getText("ContextMenu_WeightScale_StepOn") or "Step on Scale"
    local option
    if type(context.addOptionOnTop) == "function" then
        option = context:addOptionOnTop(label, playerObj, onSelect, square)
    else
        option = context:addOption(label, playerObj, onSelect, square)
    end
    option.iconTexture = icon()
end

Events.OnFillWorldObjectContextMenu.Add(Menu.OnFillWorldObjectContextMenu)
