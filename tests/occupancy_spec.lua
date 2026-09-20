-- Bench for the scale reading everyone on it, and a viewer within one square
-- seeing the same reading (task 2026-09-20), run under lua5.1 (no PZ runtime).
-- Stubs mirror the real game objects: square:getMovingObjects() is a Java
-- ArrayList (size()/get(i), 0-based, out of range throws, NOT a Lua table),
-- IsoAnimal extends IsoPlayer and carries a decoy Nutrition, zombies answer
-- getOnlineID() = -1 in SP and share persistent outfit ids, instanceof() is
-- the game's global. Detect + Main are driven end to end; HUD/sound state is
-- what is asserted.
package.path = "src/lua/client/?.lua;" .. package.path

local nAssert = 0
local function check(cond, msg)
    nAssert = nAssert + 1
    if not cond then
        io.stderr:write("FAIL: " .. msg .. "\n")
        os.exit(1)
    end
end

-- fake UI manager + ISUIElement (same shape as tests/hud_spec.lua) ----------
UIManager = { ui = {} }
function UIManager.AddUI(el) table.insert(UIManager.ui, el) end
function UIManager.RemoveElement(el)
    for i = #UIManager.ui, 1, -1 do
        if UIManager.ui[i] == el then table.remove(UIManager.ui, i) end
    end
end
local function registered(el)
    local n = 0
    for i = 1, #UIManager.ui do if UIManager.ui[i] == el then n = n + 1 end end
    return n
end
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

local core = { getScreenWidth = function() return 1920 end, getScreenHeight = function() return 1080 end }
function getCore() return core end
local NOW = 1000
function getTimestampMs() return NOW end
local function mkEvent() return { Add = function() end } end
Events = {
    OnGameStart = mkEvent(), OnPlayerUpdate = mkEvent(), OnResolutionChange = mkEvent(),
    OnTick = mkEvent(), OnFillWorldObjectContextMenu = mkEvent(),
}
function getNumActivePlayers() return 2 end

-- the game's instanceof(obj, "ClassName") -----------------------------------
function instanceof(o, class) return type(o) == "table" and o.classes ~= nil and o.classes[class] == true end

-- Java ArrayList stand in: only size()/get(i), 0-based, get out of range throws.
local function javaList(items)
    local list = {}
    function list:size() return #items end
    function list:get(i)
        if type(i) ~= "number" or i < 0 or i >= #items then error("IndexOutOfBoundsException: " .. tostring(i)) end
        return items[i + 1]
    end
    return list
end

-- world: squares keyed x,y,z; the scale sits at SX,SY --------------------------
local SX, SY = 10, 10
local ROOM_A, ROOM_B = { name = "clinic" }, { name = "hall" }
local squares = {}
local movingCalls = 0
local function squareAt(x, y, z)
    local key = x .. "," .. y .. "," .. (z or 0)
    local sq = squares[key]
    if not sq then
        sq = { x = x, y = y, z = z or 0, room = ROOM_A, occupants = {}, scale = (x == SX and y == SY and (z or 0) == 0) }
        function sq:getX() return self.x end
        function sq:getY() return self.y end
        function sq:getZ() return self.z end
        function sq:getRoom() return self.room end
        function sq:getObjects()
            local objs = {}
            if self.scale then
                objs[1] = { getSprite = function()
                    return { getName = function() return "location_community_medical_01_8" end }
                end }
            end
            return javaList(objs)
        end
        function sq:getMovingObjects()
            movingCalls = movingCalls + 1
            return javaList(self.occupants)
        end
        squares[key] = sq
    end
    return sq
end
local cell = { getGridSquare = function(self, x, y, z) return squareAt(x, y, z) end }
function getCell() return cell end

local SOUND = {}
local PLAYERS = {}
local function put(obj, x, y, z)
    if obj.sq then
        for i, o in ipairs(obj.sq.occupants) do
            if o == obj then table.remove(obj.sq.occupants, i) break end
        end
    end
    obj.sq = squareAt(x, y, z or 0)
    table.insert(obj.sq.occupants, obj)
end
local function remove(obj)
    for i, o in ipairs(obj.sq.occupants) do
        if o == obj then table.remove(obj.sq.occupants, i) break end
    end
    obj.sq = nil
end
local function makePlayer(n, kg)
    local p = { classes = { IsoPlayer = true, IsoGameCharacter = true }, kg = kg, dead = false }
    function p:getCurrentSquare() return self.sq end
    function p:getNutrition() return { getWeight = function() return p.kg end } end
    function p:isDead() return self.dead end
    function p:playSound(name) table.insert(SOUND, { n = n, name = name }) end
    PLAYERS[n] = p
    return p
end
local function makeAnimal(kg)
    -- IsoAnimal extends IsoPlayer: Nutrition exists but is NOT its weight.
    local a = { classes = { IsoAnimal = true, IsoPlayer = true, IsoGameCharacter = true } }
    function a:getNutrition() return { getWeight = function() return 999 end } end
    function a:getData() return { getWeight = function() return kg end } end
    function a:isDead() return false end
    return a
end
local zombieIds = 0
local function makeZombie(id, outfit)
    zombieIds = zombieIds + 1
    local z = { classes = { IsoZombie = true, IsoGameCharacter = true } }
    function z:getOnlineID() return -1 end
    function z:getID() return id end
    function z:getPersistentOutfitID() return outfit or 0x00050001 end
    function z:isDead() return false end
    return z
end
function getSpecificPlayer(n) return PLAYERS[n] end

require("WeightScale/WeightScaleMain")
local Core, Detect, Main, Occupants = WeightScale.Core, WeightScale.Detect, WeightScale.Main, WeightScale.Occupants
Main.onGameStart()
Detect.tickEvery = 1

local function tick(n, times)
    for _ = 1, times or 1 do Detect.update(n, PLAYERS[n]) end
end
local function hud(n) return Main.huds[n] end
local function mode(n) return hud(n) and hud(n).mode or "none" end
local function sounds() local s = {} for i = 1, #SOUND do s[i] = SOUND[i].name .. "@" .. SOUND[i].n end return table.concat(s, ",") end
local function near(a, b) return a ~= nil and math.abs(a - b) < 1e-6 end

-- 1. Occupants: kg per type, dead and unknown skipped ------------------------
local pl = makePlayer(0, 72.4)
check(near(Occupants.weightOf(pl), 72.4), "a player weighs its Nutrition")
local an = makeAnimal(45)
check(near(Occupants.weightOf(an), 45), "an animal weighs getData():getWeight(), not its (decoy) Nutrition")
local z1, z2 = makeZombie(101), makeZombie(102)
check(z1:getPersistentOutfitID() == z2:getPersistentOutfitID(), "stub: two zombies share an outfit id")
check(near(Occupants.weightOf(z1), Core.zombieWeight(101)), "a zombie weighs the hallucinated weight of its id")
check(Occupants.weightOf(z1) ~= Occupants.weightOf(z2), "zombies in the same outfit do not collide")
local zMP = makeZombie(7)
function zMP:getOnlineID() return 4242 end
check(near(Occupants.weightOf(zMP), Core.zombieWeight(4242)), "in MP the shared online id is the key, not the local id")
local dead = makePlayer(9, 60)
dead.dead = true
check(Occupants.weightOf(dead) == nil, "a dead player does not count")
check(Occupants.weightOf({ classes = { BaseVehicle = true } }) == nil, "an unknown moving object does not count")
local buf = {}
local sq0 = squareAt(50, 50)
sq0.occupants = { pl, an, z1, dead, { classes = {} } }
Occupants.read(sq0, buf)
check(#buf == 3 and near(buf[1], 72.4) and near(buf[2], 45), "read lists only the counting occupants, got " .. #buf)
Occupants.read(squareAt(51, 51), buf)
check(#buf == 0, "read clears the reused buffer")
sq0.occupants = {}
PLAYERS[9] = nil

-- 2. viewer alone on the tile: immediate, with the on sound -------------------
local doc = makePlayer(0, 80)      -- viewer 0 (doctor / self)
local pat = makePlayer(1, 72.4)    -- a patient, also a local player in splitscreen tests below
movingCalls = 0
put(doc, 5, 5)
tick(0, 3)
check(mode(0) == "none" and movingCalls == 0, "far from every scale: no HUD and the tile is never read")
put(doc, SX, SY)
tick(0)
check(mode(0) == "on" and near(hud(0).target, 80), "stepping on reads its own weight at once, target " .. tostring(hud(0) and hud(0).target))
check(sounds() == "WeightScaleOn@0", "stepping on an empty scale plays the on cue, got " .. sounds())
tick(0, 5)
check(sounds() == "WeightScaleOn@0" and registered(hud(0)) == 1, "standing still is silent, one element")
put(doc, 11, 10)   -- still within reach, empty scale
tick(0)
check(mode(0) == "off", "stepping off an occupied-by-me scale starts the leaving move")
check(sounds() == "WeightScaleOn@0,WeightScaleOff@0", "stepping off plays the off cue, got " .. sounds())
NOW = NOW + Core.T.offEnd + 1
hud(0):tick()
check(mode(0) == "idle" and registered(hud(0)) == 0, "the leaving move ends idle and unregistered")
SOUND = {}

-- 3. doctor at 1 square, same room, sees the patient ------------------------
local doctorSq = { 11, 10 }
put(doc, doctorSq[1], doctorSq[2])
put(pat, SX, SY)
tick(0)
check(mode(0) == "idle", "a non self change waits: first poll does not show the patient")
tick(0)
check(mode(0) == "on" and near(hud(0).target, 72.4), "second poll: the doctor reads the patient's 72.4")
check(#SOUND == 0, "a pure observer never hears a cue, got " .. sounds())
check(Detect.players[0].scaleSquare == squareAt(SX, SY), "the scale square is cached for the viewer")

-- 4. nutrition drift below the shown decimal churns nothing --------------------
local t0 = hud(0).t0
pat.kg = 72.41
tick(0, 4)
check(hud(0).t0 == t0 and near(hud(0).target, 72.4), "a sub decimal drift does not retarget")

-- 5. second occupant retargets (true sum, no cap), zombie crossing is debounced ----------
local zom = makeZombie(555)
put(zom, SX, SY)
tick(0)
check(near(hud(0).target, 72.4), "one poll of a new occupant does not change the reading")
remove(zom)
tick(0, 3)
check(near(hud(0).target, 72.4) and hud(0).from == nil, "a zombie crossing for one poll never flickers the readout")
NOW = NOW + Core.T.onEnd + 10   -- the readout has settled on the patient
put(zom, SX, SY)
tick(0, 2)
check(near(hud(0).target, 72.41 + Core.zombieWeight(555)), "a held second occupant adds to the total, got " .. hud(0).target)
check(near(hud(0).from, 72.4), "retarget slides from the reading on screen, got " .. tostring(hud(0).from))
check(registered(hud(0)) == 1 and #UIManager.ui == 1, "retarget keeps one element registered")
check(#SOUND == 0, "a second occupant is silent")
local zom2 = makeZombie(556)
put(zom2, SX, SY)
tick(0, 3)
check(near(hud(0).target, 72.41 + Core.zombieWeight(555) + Core.zombieWeight(556)), "three occupants read their true sum, no cap")
remove(zom2); remove(zom)
tick(0, 2)
check(near(hud(0).target, 72.41), "occupants leaving drops back to the patient, got " .. hud(0).target)
remove(pat)
tick(0)
check(mode(0) == "on", "the patient leaving is debounced too")
tick(0)
check(mode(0) == "off" and #SOUND == 0, "empty scale: the observer's readout leaves, silently")
NOW = NOW + Core.T.offEnd + 1
hud(0):tick()

-- 6. animal weight via getData(), alone on the tile ----------------------------
local cow = makeAnimal(45)
put(cow, SX, SY)
tick(0, 2)
check(mode(0) == "on" and near(hud(0).target, 45), "an animal on the scale reads getData():getWeight()")
remove(cow)
tick(0, 2)
NOW = NOW + Core.T.offEnd + 1
hud(0):tick()

-- 7. different room sees nothing, 2 squares away sees nothing -----------------
put(pat, SX, SY)
put(doc, 20, 20)
tick(0)
squareAt(11, 10).room = ROOM_B
put(doc, 11, 10)
local before = movingCalls
tick(0, 4)
check(mode(0) == "idle" and Detect.players[0].scaleSquare == nil, "a viewer in another room sees nothing")
check(movingCalls == before, "and the tile is not read for them")
squareAt(11, 10).room = ROOM_A
put(doc, 12, 10)
tick(0, 4)
check(mode(0) == "idle" and Detect.players[0].scaleSquare == nil, "2 squares away sees nothing")
put(doc, 11, 11)  -- dz 0, 1 square diagonally
tick(0, 2)
check(mode(0) == "on" and near(hud(0).target, 72.41), "1 square away on the diagonal counts")
-- nil == nil counts as the same room (outdoors); nil vs a room does not.
squareAt(11, 11).room = nil
put(doc, 20, 20); tick(0)
put(doc, 11, 11); tick(0)
check(Detect.players[0].scaleSquare == nil, "an outdoor viewer does not see an indoor scale")
squareAt(SX, SY).room = nil
put(doc, 20, 20); tick(0)
put(doc, 11, 11); tick(0)
check(Detect.players[0].scaleSquare == squareAt(SX, SY), "no room on both sides counts as the same room")
squareAt(SX, SY).room = ROOM_A
squareAt(11, 11).room = ROOM_A
put(doc, 20, 20); tick(0)

-- 8. walking away clears the cache, drops the readout at once, stops reading ---
put(doc, 11, 10)
tick(0, 3)
check(mode(0) == "on", "back beside the scale the doctor sees the patient again")
put(doc, 14, 10)
tick(0)
check(Detect.players[0].scaleSquare == nil, "walking away clears the cached scale square")
check(mode(0) == "off", "walking out of reach drops the readout at once")
check(#SOUND == 0, "walking away from an observed scale is silent")
before = movingCalls
pat.kg = 90
tick(0, 5)
check(movingCalls == before, "away from every scale the tile is not read any more")
NOW = NOW + Core.T.offEnd + 1
hud(0):tick()
pat.kg = 72.4

-- 9. viewer's own move is immediate even beside a debounced world -------------
put(doc, 11, 10)
tick(0, 2)
check(mode(0) == "on", "doctor watching the patient")
SOUND = {}
put(doc, SX, SY)          -- doctor steps on, now 152 kg
tick(0)
check(near(hud(0).target, 152.4) and #SOUND == 0, "stepping on a busy scale retargets at once and is silent")
put(doc, 11, 10)
tick(0)
check(near(hud(0).target, 72.4) and #SOUND == 0, "stepping off with a patient still on it retargets, no off cue")
remove(pat)
tick(0, 2)
check(mode(0) == "off" and #SOUND == 0, "the patient leaving afterwards: still no cue for an observer")
NOW = NOW + Core.T.offEnd + 1
hud(0):tick()

-- 10. me plus one: only the FIRST person, empty -> occupied, makes a sound -----
SOUND = {}
put(doc, SX, SY)
tick(0)
check(sounds() == "WeightScaleOn@0", "first person on an empty scale: on cue")
put(pat, SX, SY)
tick(0, 2)
check(near(hud(0).target, 152.4) and sounds() == "WeightScaleOn@0", "second occupant: retarget, silent")
remove(pat)
tick(0, 2)
check(near(hud(0).target, 80) and sounds() == "WeightScaleOn@0", "second occupant leaving: retarget, silent")
put(doc, 11, 10)
tick(0)
check(sounds() == "WeightScaleOn@0,WeightScaleOff@0", "last person leaving (self): the off cue, got " .. sounds())
NOW = NOW + Core.T.offEnd + 1
hud(0):tick()

-- 11. splitscreen: player 0 on the scale, player 1 beside it -------------------
SOUND = {}
put(doc, SX, SY)
put(pat, 11, 10)               -- pat = local player 1, watching
tick(0)
tick(1, 2)
check(mode(0) == "on" and mode(1) == "on", "both local players get a readout")
check(hud(0) ~= hud(1) and near(hud(0).target, 80) and near(hud(1).target, 80), "the same reading on both, own HUD each")
check(sounds() == "WeightScaleOn@0", "only the player on the scale hears the cue, got " .. sounds())
put(pat, SX, SY)                -- player 1 steps on too
tick(1)
check(near(hud(1).target, 152.4), "player 1 stepping on sees the true total at once")
tick(0, 2)
check(near(hud(0).target, 152.4) and sounds() == "WeightScaleOn@0", "player 0 sees the second occupant after the debounce, silent")
put(pat, 11, 10)
tick(1)
tick(0, 2)
check(near(hud(0).target, 80) and near(hud(1).target, 80), "both fall back to player 0's weight")
check(sounds() == "WeightScaleOn@0", "player 1 stepping off a still occupied scale is silent")
Detect.clear(1)
check(Detect.players[1] == nil, "clearing a slot drops its state")

-- 12. an occupant-less B41 style tile (no getMovingObjects) still reads self ---
local old = squareAt(30, 30)
old.scale = true
old.getMovingObjects = nil
SX, SY = 30, 30
squareAt(30, 30).scale = true
Detect.clear(0)
put(doc, 30, 30)
SOUND = {}
tick(0)
check(mode(0) == "on" and near(hud(0).target, 80), "without getMovingObjects the viewer still reads itself")

print(nAssert .. " assertions passed")
check(nAssert > 0, "no assertions ran")
