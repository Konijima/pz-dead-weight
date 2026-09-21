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
--
-- Everything lying on the plate counts once for the tile, whatever the sandbox
-- settings: world item getUnequippedWeight, a dropped bag includes its
-- contents. A scale with something on it reads it for a viewer within reach,
-- as if someone stood there (a dead body is a separate object and is not
-- weighed). Sandbox option DeadWeight.WeighCarried (default off) only decides
-- whether each PLAYER occupant also adds what it carries
-- (inventory:getContentsWeight(), worn items and bag contents at 100%, NOT
-- getInventoryWeight which counts worn at 30% nor getCapacityWeight which is 0
-- for unlimited carry admins). Zombies and animals stay body only.
require "WeightScale/WeightScaleGeo"
require "WeightScale/WeightScaleCore"
require "WeightScale/WeightScaleScales"

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

-- Sandbox flag, read on every poll (SandboxVars is a plain table, one lookup);
-- nil anywhere on the path means off.
function Occupants.weighCarried()
    local sv = type(SandboxVars) == "table" and SandboxVars.DeadWeight
    return type(sv) == "table" and sv.WeighCarried == true
end

-- kg carried by the local player: the whole inventory tree, worn included.
local function carriedWeight(o)
    local inv = type(o.getInventory) == "function" and o:getInventory()
    local w = inv and type(inv.getContentsWeight) == "function" and inv:getContentsWeight()
    if type(w) == "number" then return w end
    return 0
end

-- Multiplayer relay of a player's mass, no server file. Two things about a
-- remote player are not replicated to this client: their backpack contents,
-- and their Nutrition weight beyond the moment it was last synced in full
-- (the regular stat syncs carry thirst, hunger and so on, not the weight), so
-- a remote body reads a little stale while the local one keeps drifting.
-- Each client therefore publishes the body and carried kg of its own local
-- players in the player's modData, and the game ships it: IsoObject:
-- transmitModData() on a client sends ObjectModDataPacket, the server relays
-- it to the clients near that player, and the receiving client stores it on
-- the remote IsoPlayer (vanilla does the same for IsoPlayer:setUnwanted and
-- the hotbar). Sent while the player is on a plate that some viewer reads, on
-- change past one decimal, plus a slow heartbeat so a viewer who arrives late
-- catches up. The carried figure is 0 unless the sandbox option is on. The
-- local player uses the very numbers it publishes, so every viewer and the
-- player add the same one decimal figures and read the same total.
-- Nothing is sent in singleplayer or on a client with the API missing.
local FIELD_BODY = "DeadWeightBody"
local FIELD_CARRIED = "DeadWeightCarried"
Occupants.heartbeatMs = 3000
local sent = {}   -- [local player index] = { body, carried, at = ms }

local function nowMs()
    if type(getTimestampMs) == "function" then return getTimestampMs() end
    if type(os) == "table" and type(os.time) == "function" then return os.time() * 1000 end
    return 0
end

local function onMultiplayerClient()
    return type(isClient) == "function" and isClient() and true or false
end

local function tenth(kg) return math.floor(kg * 10 + 0.5) / 10 end

-- Publishes a LOCAL player's body and carried kg (multiplayer only) and returns
-- the figures to use for it, the one decimal ones that were published.
local function publishMass(o, body, carried)
    if not onMultiplayerClient() then return body, carried end
    local qb, qc = tenth(body), tenth(carried)
    if type(o.getModData) ~= "function" or type(o.transmitModData) ~= "function" then return qb, qc end
    local key = type(o.getPlayerNum) == "function" and o:getPlayerNum() or 0
    local st = sent[key]
    local now = nowMs()
    if st and st.body == qb and st.carried == qc and now - st.at < Occupants.heartbeatMs then return qb, qc end
    local md = o:getModData()
    if not md then return qb, qc end
    md[FIELD_BODY], md[FIELD_CARRIED] = qb, qc
    sent[key] = { body = qb, carried = qc, at = now }
    o:transmitModData()
    return qb, qc
end

-- a published figure of a REMOTE player, nil when none has arrived. Clamped:
-- the value comes from another client.
local function published(o, field, max)
    local md = type(o.getModData) == "function" and o:getModData()
    local v = md and md[field]
    if type(v) ~= "number" or v ~= v then return nil end
    return math.max(0, math.min(max, v))
end

-- kg carried by a REMOTE player (multiplayer): the figure that player's client
-- published, 0 when none has arrived, so a remote player then reads body only.
function Occupants.remoteLoad(o)
    return published(o, FIELD_CARRIED, 1000) or 0
end

-- kg of a REMOTE player's body: the published figure, else its Nutrition weight
-- as replicated to this client (possibly a little stale).
local function remoteBody(o)
    return published(o, FIELD_BODY, 1000) or playerWeight(o)
end

-- body and carried kg of a player occupant, nil body when unknown; carried is
-- 0 unless `carry`. Animals (IsoAnimal is an IsoPlayer) and zombies are not
-- handled here: they never carry anything.
local function massOf(o, carry)
    if type(o.isLocalPlayer) == "function" and o:isLocalPlayer() then
        local body = playerWeight(o)
        if not body then return nil end
        return publishMass(o, body, carry and carriedWeight(o) or 0)
    end
    local body = remoteBody(o)
    if not body then return nil end
    return body, carry and Occupants.remoteLoad(o) or 0
end

-- Only what stands or lies on the plate counts, not everything in the square.
-- Each scale sprite draws its plate at its own spot in the tile and about
-- 0.55 tile across, so the area is a box of half-size `half` around a per
-- sprite centre (tile fractions, x grows right-down on screen, y grows
-- left-down, i.e. towards the front). Centre, half and plateTop come from the
-- sprite's entry in WeightScale.Scales. The medical centres were measured off
-- the sprite art itself (Tiles2x.pack, location_community_medical_01_8 and
-- _9: the plate pixels below the column, converted to tile coordinates with
-- the plate top about 4 px above the ground), not by eye. A square whose
-- sprite is unknown falls back to the middle of the tile with plateHalf and
-- plateTop below (also the medical values). A character or item
-- outside the box is visibly beside the scale and is left out; anything that
-- cannot tell where it is counts, as the whole tile did before. Sandbox
-- option DeadWeight.WholeSquare (default off, nil reads as off) turns the
-- area off, then the whole square counts as it did in 1.1.0.
Occupants.plateHalf = 0.28
Occupants.plateTop = 0.04   -- see liftOntoPlate
local MIDDLE = { 0.5, 0.5 }

function Occupants.plateOnly()
    local sv = type(SandboxVars) == "table" and SandboxVars.DeadWeight
    return not (type(sv) == "table" and sv.WholeSquare == true)
end

-- the plate box of the scale sprite on this square, from its Scales entry
-- ({plate, half, plateTop}); an unknown sprite gets the middle of the tile
-- with the default half and plateTop. One walk of the square's few objects,
-- once per read
local DEFAULT_BOX = { plate = MIDDLE, half = Occupants.plateHalf, plateTop = Occupants.plateTop }

local function plateOf(square)
    if type(square.getObjects) ~= "function" then return DEFAULT_BOX end
    local objs = square:getObjects()
    if not objs then return DEFAULT_BOX end
    for i = 0, objs:size() - 1 do
        local obj = objs:get(i)
        local sprite = obj and type(obj.getSprite) == "function" and obj:getSprite()
        local name = sprite and type(sprite.getName) == "function" and sprite:getName()
        local e = name and WeightScale.Scales.forSprite(name)
        if e then return e end   -- the entry itself, no allocation per read
    end
    return DEFAULT_BOX
end

-- world x, y of the plate centre of the scale on this square (used to stand a
-- dropped animal in the middle of the plate, WeightScaleMenu)
function Occupants.plateCentre(square)
    local c = plateOf(square).plate
    return square:getX() + c[1], square:getY() + c[2]
end

local function inArea(box, fx, fy)
    local h = box.half + 1e-6   -- float slack: a spot exactly on the edge is on
    return math.abs(fx - box.plate[1]) <= h and math.abs(fy - box.plate[2]) <= h
end

-- a floor item: its 0..1 offset inside the square
local function itemOnPlate(box, wo)
    if not Occupants.plateOnly() then return true end
    if type(wo.getOffX) ~= "function" or type(wo.getOffY) ~= "function" then return true end
    local ox, oy = wo:getOffX(), wo:getOffY()
    if type(ox) ~= "number" or type(oy) ~= "number" then return true end
    return inArea(box, ox, oy)
end

-- a character (player, animal, zombie): world position minus the square's
-- corner, both floats and the square's ints in the same world units. box is
-- the plateOf result, looked up once per read by the caller.
local function charOnPlate(box, square, o)
    if type(o.getX) ~= "function" or type(o.getY) ~= "function"
        or type(square.getX) ~= "function" or type(square.getY) ~= "function" then return true end
    local x, y, sx, sy = o:getX(), o:getY(), square:getX(), square:getY()
    if type(x) ~= "number" or type(y) ~= "number" or type(sx) ~= "number" or type(sy) ~= "number" then
        return true
    end
    return inArea(box, x - sx, y - sy)
end

function Occupants.onPlate(square, o)
    if not square or not o or not Occupants.plateOnly() then return true end
    return charOnPlate(plateOf(square), square, o)
end

-- The game drops an item at height 0 (getApparentZ only knows tables and other
-- marked surfaces), so a small item lands under the plate's top and hides
-- behind it. Anything found on the plate below plateTop (tile fractions, about
-- the plate's thickness, tune by eye) is raised onto it with the game's own
-- setOffset, which redraws the chunk and syncs the item to the server and the
-- other clients; an item already at that height is left alone, so this writes
-- once per item. plateTop is the scale's own (Scales entry), Occupants.plateTop
-- for an unknown sprite.
local function liftOntoPlate(box, wo)
    if not Occupants.plateOnly() then return end   -- the whole square counts: nothing to sit on
    if type(wo.getOffX) ~= "function" or type(wo.getOffY) ~= "function"
        or type(wo.getOffZ) ~= "function" or type(wo.setOffset) ~= "function" then return end
    local oz = wo:getOffZ()
    if type(oz) ~= "number" or oz >= box.plateTop - 0.001 then return end
    wo:setOffset(wo:getOffX(), wo:getOffY(), box.plateTop)
end

-- kg of the floor items lying on the plate. getWorldObjects is a Java
-- ArrayList of IsoWorldInventoryObject (0-based); each holds one InventoryItem
-- and its 0..1 offset inside the square (getOffX/getOffY). An object that
-- cannot tell its offset counts, as the whole tile did before.
local function floorWeight(square, plate)
    if type(square.getWorldObjects) ~= "function" then return 0 end
    local list = square:getWorldObjects()
    if not list then return 0 end
    local sum = 0
    for i = 0, list:size() - 1 do
        local wo = list:get(i)
        if wo and itemOnPlate(plate, wo) then
            liftOntoPlate(plate, wo)
            local item = type(wo.getItem) == "function" and wo:getItem()
            local w = item and type(item.getUnequippedWeight) == "function" and item:getUnequippedWeight()
            if type(w) == "number" then sum = sum + w end
        end
    end
    return sum
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
-- UNPROVEN), so the viewer alone still reads its own weight as before. One
-- extra entry holds the tile's floor items (counted even with nobody on the
-- tile); with WeighCarried on, a player's entry also includes what it carries.
function Occupants.read(square, out, selfObj)
    for i = #out, 1, -1 do out[i] = nil end
    if not square then return out end
    local carry = Occupants.weighCarried()
    local plate = Occupants.plateOnly() and plateOf(square) or DEFAULT_BOX
    if type(square.getMovingObjects) ~= "function" then
        if selfObj and (not Occupants.plateOnly() or charOnPlate(plate, square, selfObj)) then
            local body, carried = massOf(selfObj, carry)
            out[1] = (body or WeightScale.Geo.weight.start) + (carried or 0)
        end
    else
        local list = square:getMovingObjects()
        if not list then return out end
        for i = 0, list:size() - 1 do
            local o = list:get(i)
            local w = Occupants.weightOf(o)
            if w and (not Occupants.plateOnly() or charOnPlate(plate, square, o)) then
                if isA(o, "IsoPlayer") and not isA(o, "IsoAnimal") then
                    local body, carried = massOf(o, carry)
                    if body then w = body + carried end
                end
                out[#out + 1] = w
            end
        end
    end
    local f = floorWeight(square, plate)
    if f > 0 then out[#out + 1] = f end
    return out
end
