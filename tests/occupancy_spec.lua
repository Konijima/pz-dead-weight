-- Bench for the scale reading everyone on it, and a viewer within one square
-- seeing the same reading (task 2026-09-20), run under lua5.1 (no PZ runtime).
-- Stubs mirror the real game objects: square:getMovingObjects() is a Java
-- ArrayList (size()/get(i), 0-based, out of range throws, NOT a Lua table),
-- IsoAnimal extends IsoPlayer and carries a decoy Nutrition, zombies answer
-- getOnlineID() = -1 in SP and share persistent outfit ids, instanceof() is
-- the game's global. Detect + Main are driven end to end; HUD/sound state is
-- what is asserted. Floor items (once per tile, readable with nobody on the tile)
-- and the DeadWeight.WeighCarried sandbox option (carried mass per player) are covered in section 13: their stubs
-- keep getWorldObjects a Java list of IsoWorldInventoryObject-likes and items
-- answer getUnequippedWeight(), a dropped bag's already including contents.
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
        sq.floor = {}
        function sq:getWorldObjects()
            local wos = {}
            for i, item in ipairs(self.floor) do
                local wo = { getItem = function() return item end }
                -- world items carry their 0..1 offset inside the square; a bare item has none
                if item.ox then
                    wo.getOffX = function() return item.ox end
                    wo.getOffY = function() return item.oy end
                    if not item.noLift then
                        wo.getOffZ = function() return item.oz or 0 end
                        wo.setOffset = function(_, x, y, z) item.oz = z; item.lifts = (item.lifts or 0) + 1 end
                    end
                end
                wos[i] = wo
            end
            return javaList(wos)
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
    -- world position: the square's corner plus a 0..1 spot inside it (centre by default)
    obj.getX = function(self) return self.sq.x + (self.sx or 0.5) end
    obj.getY = function(self) return self.sq.y + (self.sy or 0.5) end
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
    p.carried = 0
    function p:getInventory() return { getContentsWeight = function() return p.carried end } end
    function p:isLocalPlayer() return true end
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
check(sounds() == "WeightScaleOn@0", "the doctor who had watched the scale empty hears the patient step on, got " .. sounds())
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
check(sounds() == "WeightScaleOn@0", "a second occupant is silent, got " .. sounds())
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
check(mode(0) == "off" and sounds() == "WeightScaleOn@0,WeightScaleOff@0", "empty scale: the observer hears the off cue, got " .. sounds())
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
put(doc, 13, 10)
tick(0, 4)
check(mode(0) == "idle" and Detect.players[0].scaleSquare == nil, "3 squares away sees nothing by default")
put(doc, 12, 10)
tick(0, 2)
check(mode(0) == "on" and near(hud(0).target, 72.41), "2 squares away reads the scale by default")
local savedSandbox = SandboxVars
local function leaveAndSettle()
    put(doc, 20, 20); tick(0, 4)
    NOW = NOW + Core.T.offEnd + 1
    hud(0):tick()
end
check(Detect.viewDistance() == 2, "ViewDistance defaults to 2 when the option is missing")
SandboxVars = { DeadWeight = { ViewDistance = 1 } }
leaveAndSettle()
put(doc, 12, 10); tick(0, 4)
check(Detect.viewDistance() == 1 and Detect.players[0].scaleSquare == nil, "ViewDistance 1: 2 squares away sees nothing")
SandboxVars = { DeadWeight = { ViewDistance = 0 } }
put(doc, 20, 20); tick(0, 2)
put(doc, 11, 10); tick(0, 4)
check(Detect.viewDistance() == 0 and Detect.players[0].scaleSquare == nil, "ViewDistance 0: even 1 square away sees nothing")
SandboxVars = { DeadWeight = { ViewDistance = 3 } }
put(doc, 20, 20); tick(0, 2)
put(doc, 13, 10); tick(0, 2)
check(Detect.viewDistance() == 3 and mode(0) == "on", "ViewDistance 3: 3 squares away reads the scale")
SandboxVars = { DeadWeight = { ViewDistance = 99 } }
check(Detect.viewDistance() == Detect.maxRadius, "an absurd ViewDistance is clamped")
SandboxVars = { DeadWeight = { ViewDistance = "x" } }
check(Detect.viewDistance() == 2, "a non numeric ViewDistance falls back to the default")
SandboxVars = savedSandbox
leaveAndSettle()
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
local nSound = #SOUND
put(doc, 14, 10)
tick(0)
check(Detect.players[0].scaleSquare == nil, "walking away clears the cached scale square")
check(mode(0) == "off", "walking out of reach drops the readout at once")
check(#SOUND == nSound, "walking away from an observed scale is silent")
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
check(mode(0) == "off" and sounds() == "WeightScaleOff@0", "the patient leaving afterwards: the observer hears the off cue, got " .. sounds())
NOW = NOW + Core.T.offEnd + 1
hud(0):tick()

-- 10. me plus one: only empty -> occupied and occupied -> empty make a sound -----
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
check(sounds() == "WeightScaleOn@0", "only the player who stepped on hears the cue, player 1 arrived at an occupied scale, got " .. sounds())
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

-- 13. Floor items once per tile always, WeighCarried adds carried mass per player --------
local function item(kg, ox, oy) return { ox = ox, oy = oy, getUnequippedWeight = function() return kg end } end
local function sandbox(v) SandboxVars = v end
local function total(sq) return Core.sumWeights(Occupants.read(sq, {})) end
local hero = makePlayer(3, 70)
hero.carried = 12.5
local sqW, sqN = squareAt(60, 60), squareAt(61, 60)   -- a tile and its neighbour
sqW.occupants = { hero }
sqW.floor = { item(3) }
sqN.floor = { item(40) }
sandbox(nil)
check(near(total(sqW), 73), "no SandboxVars at all: body + the floor, not what is carried")
sandbox({})
check(near(total(sqW), 73), "no SandboxVars.DeadWeight: body + the floor")
sandbox({ DeadWeight = {} })
check(near(total(sqW), 73), "option unset (nil): body + the floor")
sandbox({ DeadWeight = { WeighCarried = false } })
check(near(total(sqW), 73), "option off: body + the floor, carried ignored")
sandbox({ DeadWeight = { WeighCarried = "true" } })
check(near(total(sqW), 73), "only a real boolean true turns carried on")
sandbox({ DeadWeight = { WeighCarried = true } })
check(near(total(sqW), 70 + 12.5 + 3), "on: body + carried + the tile's floor, got " .. tostring(total(sqW)))
local b = Occupants.read(sqW, {})
check(#b == 2 and near(b[1], 82.5) and near(b[2], 3), "the player's entry includes carried, floor is one tile entry")
sqW.floor = { item(3), item(2.25), item(8) }
check(near(total(sqW), 70 + 12.5 + 13.25), "several floor items add up once for the tile")
sqW.floor = { item(6) }   -- a dropped bag: its item weight already includes contents
check(near(total(sqW), 88.5), "a dropped bag counts the weight its item reports (contents included)")
sqW.floor = { {}, item(1), { getUnequippedWeight = function() return "x" end } }
check(near(total(sqW), 70 + 12.5 + 1), "floor entries without a usable weight are skipped")
sqW.floor = {}
check(near(total(sqW), 82.5) and #Occupants.read(sqW, {}) == 1, "no floor items: no extra entry")
-- a neighbouring square's floor never counts
sqW.floor = { item(3) }
check(near(total(sqW), 85.5), "an item on the neighbouring square does not add")
-- only the plate counts: the middle of the square, not its corners
sqW.occupants = { hero }
sqW.floor = { item(5, 0.5, 0.5), item(7, 0.85, 0.5), item(11, 0.5, 0.1), item(13, 0.1, 0.9) }
check(near(total(sqW), 70 + 12.5 + 5), "only the item on the plate counts, corner items are left out, got " .. tostring(total(sqW)))
sqW.floor = { item(5, 0.77, 0.23), item(7, 0.79, 0.5), item(11, 0.5, 0.21) }
check(near(total(sqW), 70 + 12.5 + 5), "the plate edge is plateHalf (0.28) from the centre on each axis, got " .. tostring(total(sqW)))
sqW.floor = { item(4, 0.85, 0.85), item(2) }
check(near(total(sqW), 70 + 12.5 + 2), "an object without an offset counts, one with a far offset does not, got " .. tostring(total(sqW)))
sqW.floor = { item(3) }

-- an item on the plate is raised onto it once, one off the plate is not touched
local top = Occupants.plateTop
local low, high, beside, lifted = item(2, 0.5, 0.5), item(3, 0.45, 0.55), item(4, 0.9, 0.1), item(5, 0.55, 0.5)
lifted.oz = top
sqW.floor = { low, high, beside, lifted }
total(sqW); total(sqW)
check(low.oz == top and low.lifts == 1, "an item on the plate is lifted to the plate top, once")
check(high.oz == top and high.lifts == 1, "every item on the plate is lifted")
check(beside.lifts == nil and beside.oz == nil, "an item beside the plate is not touched")
check(lifted.lifts == nil, "an item already at the plate top is left alone")
local stuck = item(6, 0.5, 0.5)
stuck.noLift = true
sqW.floor = { stuck }
check(near(total(sqW), 70 + 12.5 + 6), "without getOffZ/setOffset the item still counts, just not lifted")
sandbox({ DeadWeight = { WeighCarried = false } })
local rest = item(2, 0.5, 0.5)
sqW.floor = { rest }
total(sqW)
check(rest.lifts == 1, "option off: the floor item is still lifted onto the plate")
sandbox({ DeadWeight = { WeighCarried = true } })
sqW.floor = { item(3) }

-- floor items count on their own: a scale with an item on it reads it
sqW.occupants = {}
local fo = Occupants.read(sqW, {})
check(#fo == 1 and near(fo[1], 3) and near(Core.sumWeights(fo), 3), "floor items on an empty tile read on their own")
sqW.occupants = { { classes = {} }, dead }
check(near(total(sqW), 3), "non counting occupants leave only the floor")
sandbox({ DeadWeight = { WeighCarried = false } })
check(#Occupants.read(sqW, {}) == 1 and near(total(sqW), 3), "option off: floor items on an empty tile still read")
sandbox({ DeadWeight = { WeighCarried = true } })
-- zombie and animal stay body only, floor still counts once
local zomW, animW = makeZombie(900), makeAnimal(45)
animW.getInventory = function() return { getContentsWeight = function() return 99 end } end
animW.isLocalPlayer = function() return true end
zomW.getInventory = animW.getInventory
sqW.occupants = { zomW, animW }
check(near(total(sqW), Core.zombieWeight(900) + 45 + 3), "zombie and animal read body only, plus the tile floor once")
-- a remote player: no inventory read, the relay hook decides
local far = makePlayer(4, 65)
far.carried = 50
far.isLocalPlayer = function() return false end
sqW.occupants = { far }
sqW.floor = {}
check(near(total(sqW), 65), "a remote player carries 0 until a relay supplies it")
local realHook = Occupants.remoteLoad
Occupants.remoteLoad = function(o) return o == far and 7 or 0 end
check(near(total(sqW), 72), "Occupants.remoteLoad is the seam a relay plugs into")
Occupants.remoteLoad = realHook
-- the modData relay (multiplayer): a local player publishes what it carries,
-- a remote player's published figure is read back
Occupants.remoteLoad = realHook
far.md = {}
function far:getModData() return self.md end
check(near(total(sqW), 65), "remote player with no published figure reads body only")
far.md.DeadWeightCarried = 12.5
check(near(total(sqW), 77.5), "remote player: the published carried weight is added")
far.md.DeadWeightCarried = "junk"
check(near(total(sqW), 65), "a non numeric published figure counts as 0")
far.md.DeadWeightCarried = -4
check(near(total(sqW), 65), "a negative published figure counts as 0")
far.md.DeadWeightCarried = 1e9
check(near(total(sqW), 65 + 1000), "a huge published figure is clamped")
far.md.DeadWeightCarried = nil
far.md.DeadWeightBody = 66.4
check(near(total(sqW), 66.4), "remote player: the published body replaces the (stale) Nutrition weight")
far.md.DeadWeightBody = "junk"
check(near(total(sqW), 65), "a bad published body falls back to the Nutrition weight")
far.md.DeadWeightBody = -3
check(near(Occupants.read(sqW, {})[1], 0), "a negative published body is clamped to 0, got " .. tostring(Occupants.read(sqW, {})[1]))
far.md.DeadWeightBody = nil

local me = makePlayer(6, 70)
me.carried = 10.04
me.md, me.transmits = {}, 0
function me:getModData() return self.md end
function me:getPlayerNum() return 6 end
function me:transmitModData() self.transmits = self.transmits + 1 end
local clock = 1000
local realNow = getTimestampMs
getTimestampMs = function() return clock end
sqW.occupants = { me }
sqW.floor = {}
total(sqW)
check(me.transmits == 0, "singleplayer (no isClient): nothing is transmitted")
isClient = function() return true end
total(sqW)
check(me.transmits == 1 and me.md.DeadWeightCarried == 10, "multiplayer: the carried weight is published, one decimal, got " .. tostring(me.md.DeadWeightCarried))
check(near(total(sqW), 70 + 10.0) and math.abs(total(sqW) - 80) < 1e-9, "multiplayer: the local player adds the published one decimal figure, not the exact one")
total(sqW)
check(me.transmits == 1, "unchanged: nothing more is sent inside the heartbeat")
me.carried = 10.02
total(sqW)
check(me.transmits == 1, "a change under one decimal of the last sent figure sends nothing")
me.carried = 12
total(sqW)
check(me.transmits == 2 and me.md.DeadWeightCarried == 12, "a change past one decimal is sent")
clock = clock + Occupants.heartbeatMs + 1
total(sqW)
check(me.transmits == 3, "the heartbeat resends the same figure")
sandbox({ DeadWeight = { WeighCarried = false } })
clock = clock + Occupants.heartbeatMs + 1
total(sqW)
check(me.transmits == 4 and me.md.DeadWeightCarried == 0 and me.md.DeadWeightBody == 70, "option off: the body is still published, the carried figure is 0")
check(near(total(sqW), 70), "option off: the local player reads its body only")
sandbox({ DeadWeight = { WeighCarried = true } })
me.kg = 70.04
clock = clock + Occupants.heartbeatMs + 1
check(near(total(sqW), 70 + 12), "the local body is the published one decimal figure, not the exact one")
me.kg = 70.06
check(near(total(sqW), 70.1 + 12) and me.md.DeadWeightBody == 70.1, "a body change past one decimal is published and used")
me.kg = 70
me.transmitModData = nil
me.carried = 20
total(sqW)
check(near(total(sqW), 90), "a build without transmitModData still reads locally, sends nothing")
isClient = nil
getTimestampMs = realNow
sqW.occupants = {}
PLAYERS[6] = nil

-- missing API degrades to body only
local plain = makePlayer(5, 60)
plain.getInventory = nil
sqW.occupants = { plain }
sqW.floor = { item(4) }
sqW.getWorldObjects = nil
check(near(total(sqW), 60), "no getInventory and no getWorldObjects: body only")
plain.getInventory = function() return { } end
check(near(total(sqW), 60), "an inventory without getContentsWeight: body only")
plain.getInventory = function() return nil end
check(near(total(sqW), 60), "a nil inventory: body only")
plain.isLocalPlayer = nil
plain.carried = 9
plain.getInventory = function() return { getContentsWeight = function() return 9 end } end
check(near(total(sqW), 60), "no isLocalPlayer: treated as remote, body only")
sqW.occupants = {}
PLAYERS[3], PLAYERS[4], PLAYERS[5] = nil, nil, nil

-- end to end: the one decimal key dedupes, floor items alone open the HUD for a viewer in reach
SOUND = {}
Detect.clear(0)
sandbox({ DeadWeight = { WeighCarried = true } })
doc.carried = 5
squareAt(SX, SY).floor = {}
put(doc, SX, SY)
tick(0)
check(mode(0) == "on" and near(hud(0).target, 85), "on the scale with the option on the viewer reads body + carried, " .. tostring(hud(0) and hud(0).target))
local t1 = hud(0).t0
doc.carried = 5.04
tick(0, 4)
check(hud(0).t0 == t1 and near(hud(0).target, 85), "a sub decimal change of the total churns nothing")
squareAt(SX, SY).floor = { item(2) }
tick(0)
check(near(hud(0).target, 85), "a floor item is debounced like any non self change")
tick(0, 2)
check(near(hud(0).target, 87.04), "a held floor item adds to the reading, got " .. tostring(hud(0).target))
sandbox(nil)
tick(0, 3)
check(near(hud(0).target, 82), "option off again: carried gone, the floor item stays, got " .. tostring(hud(0).target))
sandbox({ DeadWeight = { WeighCarried = true } })
put(doc, 11, 10)
tick(0, 3)
check(mode(0) == "on" and near(hud(0).target, 2), "stepping off beside the item: the item alone keeps the reading, got " .. tostring(hud(0).target))
put(doc, 14, 10)
tick(0, 3)
check(mode(0) == "off", "walking out of reach closes the reading")
NOW = NOW + Core.T.offEnd + 1
hud(0):tick()
check(mode(0) == "idle" and registered(hud(0)) == 0, "out of reach: the HUD leaves the UI manager")
SOUND = {}
put(doc, 11, 10)
tick(0, 3)
check(mode(0) == "on" and near(hud(0).target, 2), "approaching an item alone on the scale opens the reading, got " .. tostring(hud(0).target))
check(#SOUND == 0, "approaching an item already on the scale is silent")
sandbox(nil)
tick(0, 3)
check(mode(0) == "on" and near(hud(0).target, 2), "option off: the item alone still reads, got " .. tostring(hud(0).target))
squareAt(SX, SY).floor = {}
tick(0, 3)
check(mode(0) == "off", "taking the item away closes the reading")
NOW = NOW + Core.T.offEnd + 1
hud(0):tick()
squareAt(SX, SY).floor = {}
sandbox(nil)
doc.carried = 0

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

-- 14. plate area: a character counts only while on the plate, not the square --
sandbox(nil)
SX, SY = 40, 40
squareAt(40, 40).scale = true
squareAt(40, 40).occupants = {}
Detect.clear(0)
if hud(0) then hud(0):startOff(); NOW = NOW + Core.T.offEnd + 1; hud(0):tick() end
SOUND = {}
doc.sx, doc.sy = 0.95, 0.9
put(doc, 40, 40)
tick(0, 3)
check(mode(0) ~= "on" and #SOUND == 0, "standing in the corner of the scale square: no reading, no cue, got " .. sounds())
doc.sx, doc.sy = 0.5, 0.5
tick(0)
check(mode(0) == "on" and near(hud(0).target, 80), "stepping onto the plate reads at once")
check(sounds() == "WeightScaleOn@0", "the on cue plays when the viewer reaches the plate, got " .. sounds())
doc.sx, doc.sy = 0.95, 0.9
tick(0)
check(mode(0) == "off" and sounds() == "WeightScaleOn@0,WeightScaleOff@0", "stepping off the plate inside the square plays the off cue, got " .. sounds())
doc.sx, doc.sy = 0.5, 0.5
tick(0)
-- another character: a zombie in the corner is not weighed, on the plate it is
local zc = makeZombie(777)
zc.sx, zc.sy = 0.1, 0.1
put(zc, 40, 40)
tick(0, 4)
check(near(hud(0).target, 80), "a zombie in the corner of the square is not weighed, got " .. tostring(hud(0).target))
zc.sx, zc.sy = 0.55, 0.45
tick(0, 3)
check(near(hud(0).target, 80 + Core.zombieWeight(777)), "the same zombie on the plate is, got " .. tostring(hud(0).target))
local edge = Occupants.plateHalf
local sq30 = squareAt(90, 90)   -- no scale sprite: the middle of the tile
check(Occupants.onPlate(sq30, { getX = function() return 90 + 0.5 + edge end, getY = function() return 90.5 end }), "the plate edge is inside")
check(not Occupants.onPlate(sq30, { getX = function() return 90.5 end, getY = function() return 90.5 + edge + 0.01 end }), "just past the edge is outside")
check(Occupants.onPlate(sq30, {}), "a character that cannot tell its position counts")
check(Occupants.onPlate(nil, doc), "no square: counts")
remove(zc)
tick(0, 3)
check(near(hud(0).target, 80), "the zombie leaves, back to the viewer alone")

-- 15. DeadWeight.WholeSquare: off by default (plate area), on means the whole square counts ---
sandbox(nil)
check(Occupants.plateOnly() == true, "no SandboxVars: the plate area is on")
sandbox({ DeadWeight = {} })
check(Occupants.plateOnly() == true, "option unset (nil): the plate area is on")
sandbox({ DeadWeight = { WholeSquare = false } })
check(Occupants.plateOnly() == true, "whole square off")
local corner = { getX = function() return 40.95 end, getY = function() return 40.9 end }
check(Occupants.onPlate(squareAt(40, 40), corner) == false, "whole square off: a character in the corner is off the plate")
sandbox({ DeadWeight = { WholeSquare = true } })
check(Occupants.plateOnly() == false, "whole square on")
check(Occupants.onPlate(squareAt(40, 40), corner) == true, "whole square on: a character in the corner counts, the whole square does")
local pp = makePlayer(6, 70)
local sqP = squareAt(62, 60)
sqP.occupants = { pp }
local far = item(5, 0.9, 0.9)
sqP.floor = { far }
sandbox({ DeadWeight = { WeighCarried = true, WholeSquare = false } })
check(near(total(sqP), 70) and far.lifts == nil, "plate area: the item in the corner is not weighed nor lifted, got " .. tostring(total(sqP)))
sandbox({ DeadWeight = { WeighCarried = true, WholeSquare = true } })
check(near(total(sqP), 75), "whole square: the item in the corner is weighed, got " .. tostring(total(sqP)))
local mid = item(2, 0.5, 0.5)
sqP.floor = { mid }
total(sqP)
check(mid.lifts == nil, "whole square: nothing is lifted onto the plate")
sqP.occupants = {}
PLAYERS[6] = nil
sandbox(nil)

-- 16. cues for a viewer who watches the scale: what happens AT it is heard -----
sandbox({ DeadWeight = { WeighCarried = true } })
Detect.clear(0)
if hud(0) then hud(0):startOff(); NOW = NOW + Core.T.offEnd + 1; hud(0):tick() end
squareAt(40, 40).occupants = {}
squareAt(40, 40).floor = {}
doc.sx, doc.sy = 0.5, 0.5
put(doc, 41, 40)
SOUND = {}
tick(0, 3)
check(mode(0) ~= "on" and #SOUND == 0, "watching an empty scale: nothing yet")
local visitor = makePlayer(7, 60)
put(visitor, 40, 40)
tick(0, 3)
check(mode(0) == "on" and sounds() == "WeightScaleOn@0", "someone else steps on the watched scale: the observer hears the on cue, got " .. sounds() .. " mode " .. tostring(mode(0)))
remove(visitor)
PLAYERS[7] = nil
tick(0, 3)
check(mode(0) == "off" and sounds() == "WeightScaleOn@0,WeightScaleOff@0", "and steps off: the observer hears the off cue, got " .. sounds())
NOW = NOW + Core.T.offEnd + 1
hud(0):tick()
SOUND = {}
squareAt(40, 40).floor = { item(4, 0.5, 0.5) }
tick(0, 3)
check(mode(0) == "on" and near(hud(0).target, 4) and sounds() == "WeightScaleOn@0", "an item dropped on the watched scale: on cue, got " .. sounds())
squareAt(40, 40).floor = {}
tick(0, 3)
check(mode(0) == "off" and sounds() == "WeightScaleOn@0,WeightScaleOff@0", "the item taken away: off cue, got " .. sounds())
NOW = NOW + Core.T.offEnd + 1
hud(0):tick()
sandbox(nil)

-- 16b. a scale picked up and put back while a viewer stays in range ----------
do
    local sqS = squareAt(90, 90)
    sqS.scale = true
    put(pat, 90, 90)
    put(doc, 91, 90)
    tick(0, 3)
    check(mode(0) == "on", "viewer in range reads the scale")
    sqS.scale = false                         -- someone picks it up
    tick(0, 4)
    check(mode(0) == "off" and Detect.players[0].scaleSquare == nil, "picked up: the reading goes")
    NOW = NOW + Core.T.offEnd + 1
    hud(0):tick()
    tick(0, 3 * Detect.rescanEvery)           -- a while later, still nothing there
    check(mode(0) ~= "on", "no scale, no reading")
    sqS.scale = true                          -- set down again, the viewer never moved
    tick(0, 3 * Detect.rescanEvery)
    check(mode(0) == "on" and Detect.players[0].scaleSquare == sqS, "put back: the viewer reads it again without moving")
    -- the search is bounded: once it has run out, only a move finds a scale
    sqS.scale = false
    tick(0, 4)
    NOW = NOW + Core.T.offEnd + 1
    hud(0):tick()
    tick(0, Detect.rescanFor + Detect.rescanEvery)
    sqS.scale = true
    tick(0, 3 * Detect.rescanEvery)
    check(mode(0) ~= "on" and Detect.players[0].rescanLeft == 0, "the search for a lost scale stops after rescanFor polls")
    put(doc, 92, 90); tick(0, 3)
    put(doc, 91, 90); tick(0, 3)
    check(mode(0) == "on", "moving still finds it")
    sqS.scale = false
    remove(pat)
    put(doc, 20, 20); tick(0, 4)
    NOW = NOW + Core.T.offEnd + 1
    hud(0):tick()
    sqS.occupants = {}
end

-- 16c. line of sight: a wall or shut door between viewer and scale hides it ---
do
    local blocked, calls = false, 0
    local function result(name) return setmetatable({}, { __tostring = function() return name end }) end   -- a Java enum, not a string
    LosUtil = { lineClear = function(_, x0, y0, z0, x1, y1, z1, ignoreDoors)
        calls = calls + 1
        return result(blocked and "Blocked" or "Clear")
    end }
    local sqL = squareAt(95, 95)
    sqL.scale = true
    put(pat, 95, 95)
    put(doc, 20, 20); tick(0, 2)
    put(doc, 97, 95); tick(0, 3)
    check(mode(0) == "on" and calls > 0, "clear line of sight: the scale is read")
    blocked = true                            -- a wall goes up, the viewer never moved
    tick(0, 2 * Detect.losEvery)
    check(mode(0) == "off" or mode(0) == "idle", "wall built between: the reading goes, got " .. mode(0))
    check(Detect.players[0].scaleSquare == nil, "and the scale is dropped")
    NOW = NOW + Core.T.offEnd + 1
    hud(0):tick()
    tick(0, 3 * Detect.rescanEvery)
    check(mode(0) ~= "on", "the wall stays: still nothing")
    blocked = false                           -- the wall comes down
    tick(0, 3 * Detect.rescanEvery)
    check(mode(0) == "on", "wall removed: the viewer reads it again without moving")
    -- walking up to a scale behind a wall finds nothing, on the scale itself always reads
    put(doc, 20, 20); tick(0, 4)
    NOW = NOW + Core.T.offEnd + 1
    hud(0):tick()
    blocked = true
    put(doc, 97, 95); tick(0, 4)
    check(Detect.players[0].scaleSquare == nil, "arriving behind a wall: no scale found")
    put(doc, 95, 95); tick(0, 3)
    check(Detect.players[0].scaleSquare == sqL and mode(0) == "on", "standing on the scale needs no line of sight")
    blocked = false
    -- the game call throwing or missing keeps the old behaviour
    LosUtil = { lineClear = function() error("boom") end }
    put(doc, 20, 20); tick(0, 4)
    NOW = NOW + Core.T.offEnd + 1
    hud(0):tick()
    put(doc, 97, 95); tick(0, 3)
    check(mode(0) == "on", "lineClear throwing counts as visible")
    LosUtil = nil
    put(doc, 20, 20); tick(0, 4)
    NOW = NOW + Core.T.offEnd + 1
    hud(0):tick()
    put(doc, 97, 95); tick(0, 3)
    check(mode(0) == "on", "no LosUtil at all counts as visible")
    remove(pat)
    put(doc, 20, 20); tick(0, 4)
    NOW = NOW + Core.T.offEnd + 1
    hud(0):tick()
    sqL.scale = false
    sqL.occupants = {}
end

-- 16d. two scales side by side: the nearest one with something to weigh wins --
do
    sandbox(nil)
    local sA, sB = squareAt(100, 100), squareAt(101, 100)
    sA.scale, sB.scale = true, true
    local p2 = makePlayer(7, 60)
    local function settle()
        NOW = NOW + Core.T.offEnd + 1
        hud(0):tick()
    end
    put(pat, 20, 21); put(p2, 20, 22); put(doc, 20, 20); tick(0, 4)
    -- the viewer stands one square from B and two from A, patient only on A
    put(pat, 100, 100)
    put(doc, 102, 100); tick(0, 4)
    check(Detect.players[0].scales[1] == sB and Detect.players[0].scales[2] == sA, "both scales in reach, nearest first")
    check(mode(0) == "on" and near(hud(0).target, 72.4), "the near scale is empty: the occupied far one is read, got " .. tostring(hud(0) and hud(0).target))
    check(Detect.players[0].scaleSquare == sA, "the scale being read is the occupied one")
    put(p2, 101, 100); tick(0, 4)
    check(near(hud(0).target, 60) and Detect.players[0].scaleSquare == sB, "both occupied: the nearest wins, got " .. tostring(hud(0).target))
    remove(p2); put(p2, 20, 22); tick(0, 4)
    check(near(hud(0).target, 72.4) and Detect.players[0].scaleSquare == sA, "the near one empties: back to the far one")
    remove(pat); put(pat, 20, 21); tick(0, 4)
    check(mode(0) == "off" and Detect.players[0].scaleSquare == sB, "both empty: nothing read, the nearest stands for the scale")
    settle()
    -- the occupied scale is picked up while the other stays: reading moves on, and it returns when set down
    put(pat, 100, 100); put(p2, 101, 100); tick(0, 4)
    check(near(hud(0).target, 60), "one on each, the near one is read")
    sB.scale = false
    tick(0, 4)
    check(near(hud(0).target, 72.4) and Detect.players[0].scaleSquare == sA, "the near scale picked up: the other one is read")
    sB.scale = true
    tick(0, 3 * Detect.rescanEvery)
    check(near(hud(0).target, 60) and Detect.players[0].scaleSquare == sB, "set down again: the near one is read again")
    -- standing on the far scale yourself: you are on it, it is nearest at distance 0
    put(doc, 100, 100); tick(0, 4)
    check(Detect.players[0].scaleSquare == sA and Detect.players[0].scales[1] == sA, "on a scale: it comes first in the list")
    remove(pat); remove(p2)
    put(doc, 20, 20); tick(0, 4)
    settle()
    sA.scale, sB.scale = false, false
    sA.occupants, sB.occupants = {}, {}
end

-- 17. each scale sprite has its own plate spot in the tile -------------------
local function spriteObj(name) return { getSprite = function() return { getName = function() return name end } end } end
local function spriteSquare(x, y, name)
    local sq = squareAt(x, y)
    sq.objects = { spriteObj(name) }
    sq.getObjects = function(self) return { size = function() return #self.objects end, get = function(_, i) return self.objects[i + 1] end } end
    sq.occupants = {}
    return sq
end
sandbox(nil)
local sq8 = spriteSquare(80, 80, "location_community_medical_01_8")
local sq9 = spriteSquare(81, 80, "location_community_medical_01_9")
local sqU = spriteSquare(82, 80, "some_other_sprite")
local function at(sq, fx, fy) return { getX = function() return sq.x + fx end, getY = function() return sq.y + fy end } end
check(Occupants.onPlate(sq8, at(sq8, 0.33, 0.43)) == true, "sprite _8: its own plate centre is on the plate")
check(Occupants.onPlate(sq8, at(sq8, 0.5, 0.72)) == false, "sprite _8: the front of the tile is beside the plate")
check(Occupants.onPlate(sq9, at(sq9, 0.48, 0.37)) == true, "sprite _9: its own plate centre is on the plate")
check(Occupants.onPlate(sq9, at(sq9, 0.5, 0.72)) == false, "sprite _9: the front of the tile is beside the plate")
check(Occupants.onPlate(sq9, at(sq9, 0.33, 0.43)) == true, "sprite _9: a spot both plates share is on it")
check(Occupants.onPlate(sqU, at(sqU, 0.5, 0.5)) == true and Occupants.onPlate(sqU, at(sqU, 0.9, 0.9)) == false, "an unknown sprite falls back to the middle of the tile")

print(nAssert .. " assertions passed")
check(nAssert > 0, "no assertions ran")
