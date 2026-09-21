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

-- playSoundLocal (jar IsoGameCharacter.playSoundLocal, calls playSoundImpl)
-- plays on this machine only. Plain playSound goes through the character's
-- emitter, which in multiplayer may also be replicated to other clients, so a
-- viewer could hear the cue twice (own copy plus the replicated one, seen with
-- two clients on one computer, replication itself UNPROVEN). Every viewer plays
-- its own cue anyway, so local only is what we want; playSound stays the
-- fallback where playSoundLocal is missing (B41 UNPROVEN).
--
-- The options "Sound Volume" slider drives the FMOD Studio VCA
-- vca:/Settings_Sfx (SoundManager.setSoundVolume), which only reaches bank
-- events. A mod .ogg is a plain file sound on its own channel group
-- (FMODSoundEmitter.FileSound, channelGroupInGameNonBankSounds), outside that
-- mixer, so at volume 0 the cue was still heard (seen 2026-09-20). We apply the
-- slider ourselves: getCore():getRealOptionSoundVolume() (0..1, jar Core, the
-- same option MainOptions.lua edits); 0 plays nothing, below 1 the returned
-- sound handle is scaled with emitter:setVolume(handle, v) (jar
-- CharacterSoundEmitter.setVolume). Missing getCore means full volume as before.
local function soundVolume()
    if type(getCore) ~= "function" then return 1 end
    local core = getCore()
    if not core or type(core.getRealOptionSoundVolume) ~= "function" then return 1 end
    local v = core:getRealOptionSoundVolume()
    if type(v) ~= "number" then return 1 end
    return math.max(0, math.min(1, v))
end

local function play(playerObj, name)
    if not playerObj then return end
    local vol = soundVolume()
    if vol <= 0 then return end
    local handle
    if type(playerObj.playSoundLocal) == "function" then
        handle = playerObj:playSoundLocal(name)
    elseif type(playerObj.playSound) == "function" then
        handle = playerObj:playSound(name)
    end
    if vol < 1 and type(handle) == "number" and handle ~= 0
        and type(playerObj.getEmitter) == "function" then
        local emitter = playerObj:getEmitter()
        if emitter and type(emitter.setVolume) == "function" then emitter:setVolume(handle, vol) end
    end
end

function Sound.playOn(playerObj) play(playerObj, Sound.ON) end
function Sound.playOff(playerObj) play(playerObj, Sound.OFF) end
