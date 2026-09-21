-- Convenience context menu option (task 2026-09-18, point B): "Step on
-- Scale" at the TOP of the right click menu, for players who use the mouse.
-- Selecting it only queues a normal walk to the scale's square; detection,
-- the HUD, the sounds, and the turn toward the scale's column (point B,
-- 2026-09-18: Detect.updateFacing) already fire on arrival by themselves
-- (see WeightScaleDetect.lua) -- this module draws nothing and tracks no
-- state.
-- Hooked on Events.OnFillWorldObjectContextMenu, honouring the vanilla
-- `test` convention (ISWorldObjectContextMenu.lua, e.g. ISBBQMenu.lua): a
-- cheap early return when another handler already confirmed an option, and
-- `ISWorldObjectContextMenu.setTest()` once we know we would add ours.
-- See docs/API-COMPAT.md for every call proven here.
require "WeightScale/WeightScaleScales"
require "WeightScale/WeightScaleDetect"
require "WeightScale/WeightScaleOccupants"

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

-- Reuses the mod's one scale table (WeightScale.Scales, by sprite name): scans
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
        if WeightScale.Scales.forSprite(name) then
            -- a scale on a counter or table (drawn lifted by the surface's
            -- render offset) cannot be stepped on and holds no animal
            local lift = obj.getRenderYOffset and obj:getRenderYOffset()
            local square = obj.getSquare and obj:getSquare()
            if square and not (type(lift) == "number" and lift > 0) then return square end
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

-- The animal the player holds, if any (Build 42 only: an AnimalInventoryItem
-- in a hand, see ISPutAnimalInHutch.lua; on Build 41 instanceof is simply
-- false and the option never appears). Not offered on a multiplayer client:
-- ISDropWorldItemAction:complete runs on the server only and calls
-- AddWorldInventoryItem with transmit false, so no client is told about the
-- new animal and it vanishes for everyone (seen with two clients, 2026-09-20),
-- unlike vanilla's inventory Drop, which is completed by the client too. See
-- docs/BACKLOG.md.
local function heldAnimal(playerObj)
    if not playerObj or type(instanceof) ~= "function" then return nil end
    if type(isClient) == "function" and isClient() then return nil end
    for _, getter in ipairs({ "getPrimaryHandItem", "getSecondaryHandItem" }) do
        local item = type(playerObj[getter]) == "function" and playerObj[getter](playerObj)
        if item and instanceof(item, "AnimalInventoryItem") then return item end
    end
    return nil
end

-- Keeping the animal on the plate for a few seconds. A freshly dropped animal
-- wanders off at once, before the reading is worth looking at, so once the drop
-- has spawned it (found on the scale square by its animal id, which
-- IsoAnimal.copyFrom carries over from the item) it is told to stand still with
-- the game's own animal:getBehavior():setBlockMovement(true) (vanilla lua uses
-- it while feeding and watering, ISAnimalContextMenu.lua; it stops the animal
-- and keeps wandering off) and released Menu.holdMs later. The game would
-- release it by itself only after a far longer time. The tick handler exists
-- only while an animal is pending and checks every few ticks, so an idle
-- scale costs nothing. UNPROVEN in game; in multiplayer the server owns the
-- animal, so the block may have no effect there (docs/API-COMPAT.md).
Menu.holdMs = 3500          -- how long the animal stays put once it is down
Menu.holdGiveUpMs = 30000   -- stop waiting for the drop after this (walk, unequip)
local HOLD_EVERY = 6        -- ticks between checks
local pending = {}          -- { id, square, giveUp, animal, releaseAt }
local ticks = 0

local function nowMs()
    return type(getTimestampMs) == "function" and getTimestampMs() or 0
end

local function findAnimal(square, id)
    if type(square.getMovingObjects) ~= "function" then return nil end
    local list = square:getMovingObjects()
    if not list then return nil end
    for i = 0, list:size() - 1 do
        local o = list:get(i)
        if instanceof(o, "IsoAnimal") and type(o.getAnimalID) == "function" and o:getAnimalID() == id then
            return o
        end
    end
    return nil
end

local function setBlock(animal, on)
    local behavior = type(animal.getBehavior) == "function" and animal:getBehavior()
    if behavior and type(behavior.setBlockMovement) == "function" then behavior:setBlockMovement(on) end
end

-- The behaviour flag alone did not keep a real animal on the plate in the first
-- game test, so while it is held the animal is also pinned where it landed: on
-- every tick, if it drifted, it is put back and its movement stopped. One
-- animal for a few seconds, and only while a drop is pending or held. Skipped
-- on a multiplayer client, which does not own the animal.
local function pin(p)
    local a = p.animal
    if isClient and isClient() then return end
    if type(a.getX) ~= "function" or type(a.setX) ~= "function" or type(a.setY) ~= "function" then return end
    if math.abs(a:getX() - p.x) < 0.02 and math.abs(a:getY() - p.y) < 0.02 then return end
    a:setX(p.x); a:setY(p.y)
    if type(a.setNextX) == "function" then a:setNextX(p.x); a:setNextY(p.y) end
    if type(a.setLastX) == "function" then a:setLastX(p.x); a:setLastY(p.y) end
    if type(a.stopAllMovementNow) == "function" then a:stopAllMovementNow() end
    p.pinned = (p.pinned or 0) + 1
end

local function holdTick()
    ticks = ticks + 1
    local t = nowMs()
    local looking = false
    for i = #pending, 1, -1 do
        local p = pending[i]
        if p.animal then
            if t >= p.releaseAt then
                setBlock(p.animal, false)
                print("[DeadWeight] animal released, put back " .. (p.pinned or 0) .. " times")
                table.remove(pending, i)
            else
                pin(p)
            end
        else
            looking = true
        end
    end
    if looking and ticks % HOLD_EVERY == 0 then
        for i = #pending, 1, -1 do
            local p = pending[i]
            if not p.animal then
                p.animal = findAnimal(p.square, p.id)
                if p.animal then
                    setBlock(p.animal, true)
                    p.releaseAt = t + Menu.holdMs
                    -- centred on the plate: it lands at the tile middle, which is
                    -- only near the plate's own centre
                    p.x, p.y = WeightScale.Occupants.plateCentre(p.square)
                    print("[DeadWeight] animal held at " .. p.x .. "," .. p.y)
                    pin(p)
                elseif t >= p.giveUp then
                    print("[DeadWeight] animal drop never seen, gave up")
                    table.remove(pending, i)
                end
            end
        end
    end
    if #pending == 0 then Events.OnTick.Remove(holdTick) end
end

local function holdAnimalOnce(item, square)
    local animal = type(item.getAnimal) == "function" and item:getAnimal()
    local id = animal and type(animal.getAnimalID) == "function" and animal:getAnimalID()
    if type(id) ~= "number" then return end
    if #pending == 0 then Events.OnTick.Add(holdTick) end
    pending[#pending + 1] = { id = id, square = square, giveUp = nowMs() + Menu.holdGiveUpMs }
end

-- "Put animal on scale": walk to a square NEXT to the scale (never onto it, so
-- the player is not weighed with the animal; luautils.walkAdj with the scale
-- square excluded also walks a player who stands on it off), then place the
-- held animal on the scale square the way vanilla places any item next to
-- you (ISPlace3DItemCursor.lua: ISUnequipAction "place" then
-- ISDropWorldItemAction with isPlaceItem). IsoGridSquare.AddWorldInventoryItem
-- turns an animal item into a live IsoAnimal at the square's centre
-- (x + 0.5, y + 0.5), which is on the plate of both scale sprites, and plays
-- the animal's put down sound. UNPROVEN in game, see docs/API-COMPAT.md.
local function onPutAnimal(playerObj, square)
    local item = heldAnimal(playerObj)
    if not item then return end
    if not luautils.walkAdj(playerObj, square, false, { square }) then return end
    if playerObj:isEquipped(item) then
        ISTimedActionQueue.add(ISUnequipAction:new(playerObj, item, 1, "place"))
    end
    local action = ISDropWorldItemAction:new(playerObj, item, square, 0.5, 0.5, 0, 0, false)
    action.isPlaceItem = true
    -- turn towards the scale before the drop starts and keep facing it while it
    -- runs, the way ISPutAnimalInHutch does (waitToStart returns true while the
    -- character is still turning). Set on this instance only: the server's own
    -- copy of the action, built from the vanilla class, is untouched.
    local x, y = square:getX() + 0.5, square:getY() + 0.5
    local vanillaUpdate = action.update
    function action:waitToStart()
        self.character:faceLocation(x, y)
        return self.character:shouldBeTurning()
    end
    function action:update()
        self.character:faceLocation(x, y)
        if vanillaUpdate then vanillaUpdate(self) end
    end
    ISTimedActionQueue.add(action)
    holdAnimalOnce(item, square)
end

local function addOption(context, label, playerObj, onSelectFn, square)
    local option
    if type(context.addOptionOnTop) == "function" then
        option = context:addOptionOnTop(label, playerObj, onSelectFn, square)
    else
        option = context:addOption(label, playerObj, onSelectFn, square)
    end
    option.iconTexture = icon()
    return option
end

function Menu.OnFillWorldObjectContextMenu(player, context, worldobjects, test)
    if test and ISWorldObjectContextMenu.Test then return true end

    local square = findScaleSquare(worldobjects)
    if not square then return end

    local playerObj = getSpecificPlayer and getSpecificPlayer(player)
    local onIt = playerOnSquare(playerObj, square)
    local animal = heldAnimal(playerObj)
    if onIt and not animal then return end

    if test then return ISWorldObjectContextMenu.setTest() end

    if not onIt then
        addOption(context, getText and getText("ContextMenu_WeightScale_StepOn") or "Step on Scale",
            playerObj, onSelect, square)
    end
    -- added last so it sits on top: a player holding an animal came for this
    if animal then
        addOption(context, getText and getText("ContextMenu_WeightScale_PutAnimal") or "Put Animal on Scale",
            playerObj, onPutAnimal, square)
    end
end

Events.OnFillWorldObjectContextMenu.Add(Menu.OnFillWorldObjectContextMenu)
