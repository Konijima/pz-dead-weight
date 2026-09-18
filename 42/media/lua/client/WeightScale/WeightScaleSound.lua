-- Step on/off cue, one shot per transition, from the stepping player's own
-- emitter: `playerObj:playSound(name)` (B42 PROVEN, ISWorldObjectContextMenu.lua
-- and ISInventoryPage.lua both call it on a player instance; B41 UNPROVEN).
-- The sound scripts (sounds_weightscale.txt) declare is3D = false, so this
-- carries no world sound radius and cannot draw zombies, unlike an is3D
-- clip with a distanceMax. Guarded so a missing playSound API on B41 never
-- breaks the HUD; see docs/API-COMPAT.md.
WeightScale = WeightScale or {}
WeightScale.Sound = WeightScale.Sound or {}
local Sound = WeightScale.Sound

Sound.ON = "WeightScaleOn"
Sound.OFF = "WeightScaleOff"

local function play(playerObj, name)
    if not playerObj then return end
    if type(playerObj.playSound) ~= "function" then return end
    playerObj:playSound(name)
end

function Sound.playOn(playerObj) play(playerObj, Sound.ON) end
function Sound.playOff(playerObj) play(playerObj, Sound.OFF) end
