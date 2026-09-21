-- Bench for WeightScaleSound, run under lua5.1: the cue follows the options
-- "Sound Volume" slider itself (mod file sounds are outside the FMOD VCA it drives).
package.path = "src/lua/client/?.lua;" .. package.path
local n = 0
local function check(cond, msg)
    n = n + 1
    if not cond then io.stderr:write("FAIL: " .. msg .. "\n") os.exit(1) end
end

require "WeightScale/WeightScaleSound"
local Sound = WeightScale.Sound

local LOG, SETV = {}, {}
local function player(local_)
    local p = {}
    local emitter = { setVolume = function(self, h, v) SETV[#SETV + 1] = { h = h, v = v } end }
    function p:getEmitter() return emitter end
    if local_ then
        function p:playSoundLocal(name) LOG[#LOG + 1] = "local:" .. name return 77 end
    end
    function p:playSound(name) LOG[#LOG + 1] = "net:" .. name return 78 end
    return p
end
local function reset() LOG, SETV = {}, {} end

-- no getCore at all: full volume, plain local play
getCore = nil
Sound.playOn(player(true))
check(#LOG == 1 and LOG[1] == "local:WeightScaleOn" and #SETV == 0, "no getCore: plays at full volume, got " .. table.concat(LOG, ","))
reset()
Sound.playOff(player(false))
check(#LOG == 1 and LOG[1] == "net:WeightScaleOff", "no playSoundLocal: falls back to playSound")

local VOL = 1
getCore = function() return { getRealOptionSoundVolume = function() return VOL end } end
reset(); VOL = 1
Sound.playOn(player(true))
check(#LOG == 1 and #SETV == 0, "slider at max: played, volume untouched")
reset(); VOL = 0
Sound.playOn(player(true)); Sound.playOff(player(true))
check(#LOG == 0, "slider at zero: nothing plays")
reset(); VOL = 0.3
Sound.playOn(player(true))
check(#LOG == 1 and #SETV == 1 and SETV[1].h == 77 and math.abs(SETV[1].v - 0.3) < 1e-9, "slider at 0.3: the sound handle is scaled to 0.3")
reset(); VOL = 0.5
local p = player(true)
p.playSoundLocal = function(self, name) LOG[#LOG + 1] = name return 0 end
Sound.playOn(p)
check(#SETV == 0, "a zero handle is never scaled")
getCore = function() return {} end
reset()
Sound.playOn(player(true))
check(#LOG == 1, "getCore without the volume call: full volume")
Sound.playOn(nil)
check(#LOG == 1, "no player: nothing")

print(n .. " assertions passed")
