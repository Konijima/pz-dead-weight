-- Who is standing on a scale tile, and what each one weighs in kg (task
-- 2026-09-20: the scale reads everyone on it, a doctor nearby reads it too).
-- The game API lives here so WeightScaleCore stays pure. One call,
-- square:getMovingObjects() (a Java ArrayList, 0-based, dead bodies are not in
-- it), then a type test per object:
--   IsoAnimal   extends IsoPlayer, so it is tested FIRST; weight is
--               animal:getData():getWeight(), NOT Nutrition.
--   IsoZombie   has no weight: Core.zombieWeight of a per zombie unique id.
--               getPersistentOutfitID is NOT that id: it encodes female bit |
--               outfit index << 16 | seed variant 1..500 (PersistentOutfits.java),
--               so zombies in the same outfit collide. getOnlineID (>= 0 only
--               in MP, shared by every client) else IsoMovingObject:getID (SP
--               counter) is unique.
--   IsoPlayer   Nutrition:getWeight(), also readable on remote players.
-- Anything else, and anything dead, is skipped. See docs/API-COMPAT.md.
require "WeightScale/WeightScaleGeo"
require "WeightScale/WeightScaleCore"

WeightScale = WeightScale or {}
WeightScale.Occupants = WeightScale.Occupants or {}
local Occupants = WeightScale.Occupants

local function isA(o, class)
    return type(instanceof) == "function" and instanceof(o, class) and true or false
end

local function isDead(o)
    return type(o.isDead) == "function" and o:isDead() and true or false
end

local function playerWeight(o)
    local nutrition = type(o.getNutrition) == "function" and o:getNutrition()
    local w = nutrition and type(nutrition.getWeight) == "function" and nutrition:getWeight()
    if type(w) == "number" then return w end
    return nil
end

local function animalWeight(o)
    local data = type(o.getData) == "function" and o:getData()
    local w = data and type(data.getWeight) == "function" and data:getWeight()
    if type(w) == "number" then return w end
    return nil
end

local function zombieKey(o)
    local id = type(o.getOnlineID) == "function" and o:getOnlineID()
    if type(id) == "number" and id >= 0 then return id end
    id = type(o.getID) == "function" and o:getID()
    if type(id) == "number" then return id end
    return 0
end

-- kg of one moving object, nil when it does not count.
function Occupants.weightOf(o)
    if not o or isDead(o) then return nil end
    if isA(o, "IsoAnimal") then return animalWeight(o) end
    if isA(o, "IsoZombie") then return WeightScale.Core.zombieWeight(zombieKey(o)) end
    if isA(o, "IsoPlayer") then return playerWeight(o) end
    return nil
end

-- Fills `out` (reused by the caller, cleared here so nothing is allocated per
-- poll) with one kg per occupant and returns it. selfObj is the local viewer
-- when standing on the tile: only used if getMovingObjects is missing (B41
-- UNPROVEN), so the viewer alone still reads its own weight as before.
function Occupants.read(square, out, selfObj)
    for i = #out, 1, -1 do out[i] = nil end
    if not square then return out end
    if type(square.getMovingObjects) ~= "function" then
        if selfObj then out[1] = playerWeight(selfObj) or WeightScale.Geo.weight.start end
        return out
    end
    local list = square:getMovingObjects()
    if not list then return out end
    for i = 0, list:size() - 1 do
        local w = Occupants.weightOf(list:get(i))
        if w then out[#out + 1] = w end
    end
    return out
end
