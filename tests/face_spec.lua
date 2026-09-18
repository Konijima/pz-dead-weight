-- Bench for the "face the scale's column" feature (task 2026-09-18, point B),
-- run under lua5.1 (no PZ runtime). Stubs exactly what Detect calls:
-- square:getObjects() (Java-list shape, same style as tests/hud_spec.lua),
-- obj:getFacing() (IsoDirections values, faithfully opaque tokens here --
-- the module never inspects them, only threads them through to
-- faceDirection), and the player accessors isPlayerMoving/faceDirection/
-- isAiming/hasTimedActions, each individually absent-able to prove the
-- unproven-API guards.
package.path = "src/lua/client/?.lua;" .. package.path

local nAssert = 0
local function check(cond, msg)
    nAssert = nAssert + 1
    if not cond then
        io.stderr:write("FAIL: " .. msg .. "\n")
        os.exit(1)
    end
end

-- IsoDirections stand-ins: opaque, distinct tokens (the module never does
-- more than pass one of these through to faceDirection).
local DIR_E, DIR_S = { name = "E" }, { name = "S" }

local function scaleObj(dir)
    return {
        getSprite = function()
            return { getName = function() return "location_community_medical_01_8" end }
        end,
        getFacing = function() return dir end,
    }
end

local function scaleSquare(onScale, dir)
    return { getObjects = function()
        return {
            size = function() return onScale and 1 or 0 end,
            get = function(_, i) return scaleObj(dir) end,
        }
    end }
end

local function makePlayer(overrides)
    local p = { moving = false, aiming = false, busy = false, turns = {} }
    p.isPlayerMoving = function(self) return self.moving end
    p.faceDirection = function(self, dir) table.insert(self.turns, dir) end
    p.isAiming = function(self) return self.aiming end
    p.hasTimedActions = function(self) return self.busy end
    for k, v in pairs(overrides or {}) do p[k] = v end
    return p
end

require "WeightScale/WeightScaleDetect"
local Detect = WeightScale.Detect
Detect.tickEvery = 1

-- 1/2: stepping on and stopping turns the player once, facing the scale's
-- own `Facing` direction (Detect.facingFor reads it straight off the
-- object, no per-sprite table).
local square = scaleSquare(true, DIR_E)
local p = makePlayer({ moving = true })
p.getCurrentSquare = function() return square end
Detect.update(0, p)
check(#p.turns == 0, "arriving does not turn before the player has stopped")
Detect.updateFacing(0, p)
check(#p.turns == 0, "no turn while still moving")
p.moving = false
Detect.updateFacing(0, p)
check(#p.turns == 1 and p.turns[1] == DIR_E, "turns once, toward the scale's own Facing direction")
Detect.updateFacing(0, p)
Detect.updateFacing(0, p)
check(#p.turns == 1, "never turns a second time while still standing on the scale")

-- 3: a different placed scale (Facing = S) turns the player south, proving
-- the direction is read per object, not a hardcoded constant.
local squareS = scaleSquare(true, DIR_S)
local pS = makePlayer()
pS.getCurrentSquare = function() return squareS end
Detect.update(1, pS)
Detect.updateFacing(1, pS)
check(#pS.turns == 1 and pS.turns[1] == DIR_S, "a Facing=S scale turns the player south")

-- 4: walking across without ever stopping never turns (leaving clears the
-- queued turn set by Detect.update's onScaleOn transition).
local pCross = makePlayer({ moving = true })
pCross.getCurrentSquare = function() return square end
Detect.update(2, pCross)
Detect.updateFacing(2, pCross) -- still moving: nothing queued to fire yet
check(#pCross.turns == 0, "still walking across: no turn yet")
pCross.getCurrentSquare = function() return scaleSquare(false) end
Detect.update(2, pCross) -- steps off before ever stopping
pCross.moving = false
Detect.updateFacing(2, pCross)
check(#pCross.turns == 0, "walked across without stopping: never turned, even after leaving")

-- 5: turning away afterwards is never forced back (only Detect.update's own
-- onScaleOn transition arms a new turn).
local pFree = makePlayer()
pFree.getCurrentSquare = function() return square end
Detect.update(3, pFree)
Detect.updateFacing(3, pFree)
check(#pFree.turns == 1, "turned once on arrival")
pFree.moving = false
Detect.updateFacing(3, pFree)
Detect.updateFacing(3, pFree)
check(#pFree.turns == 1, "free to turn away afterward: not forced back while still on the scale")

-- 6: re-armed only after leaving and stepping on again.
pFree.getCurrentSquare = function() return scaleSquare(false) end
Detect.update(3, pFree)
pFree.getCurrentSquare = function() return square end
Detect.update(3, pFree)
Detect.updateFacing(3, pFree)
check(#pFree.turns == 2, "re-armed by a fresh step-on after leaving the square")

-- 7: cancelled/incomplete walk (the context menu path, point C) -- never
-- arriving on the square never arms a turn, proven by never calling
-- Detect.update with the scale square at all.
local pCancelled = makePlayer()
pCancelled.getCurrentSquare = function() return scaleSquare(false) end
Detect.update(4, pCancelled)
Detect.updateFacing(4, pCancelled)
check(#pCancelled.turns == 0, "a walk that never lands on the scale square never turns")

-- 8: missing API (B41 unproven) does nothing, never crashes.
local pNoMove = makePlayer()
pNoMove.getCurrentSquare = function() return square end
pNoMove.isPlayerMoving = nil
Detect.update(5, pNoMove)
Detect.updateFacing(5, pNoMove)
check(#pNoMove.turns == 0, "missing isPlayerMoving: no turn, no crash")

local pNoFace = makePlayer()
pNoFace.getCurrentSquare = function() return square end
pNoFace.faceDirection = nil
Detect.update(6, pNoFace)
Detect.updateFacing(6, pNoFace)
check(#pNoFace.turns == 0, "missing faceDirection: no turn, no crash")

-- 9: a sprite with no Facing property (getFacing missing or nil) queues
-- nothing and never turns.
local squareNoFacing = { getObjects = function()
    return {
        size = function() return 1 end,
        get = function(_, i) return {
            getSprite = function() return { getName = function() return "location_community_medical_01_8" end } end,
        } end,
    }
end }
local pNoFacing = makePlayer()
pNoFacing.getCurrentSquare = function() return squareNoFacing end
Detect.update(7, pNoFacing)
Detect.updateFacing(7, pNoFacing)
check(#pNoFacing.turns == 0, "an object with no getFacing() never turns")

-- 10: aiming or another timed action blocks the turn (point 5), without
-- losing it -- once clear, the turn still fires.
local pAim = makePlayer({ aiming = true })
pAim.getCurrentSquare = function() return square end
Detect.update(8, pAim)
Detect.updateFacing(8, pAim)
check(#pAim.turns == 0, "aiming: no turn while aiming")
pAim.aiming = false
Detect.updateFacing(8, pAim)
check(#pAim.turns == 1, "turn fires once aiming stops, still on the scale")

local pBusy = makePlayer({ busy = true })
pBusy.getCurrentSquare = function() return square end
Detect.update(9, pBusy)
Detect.updateFacing(9, pBusy)
check(#pBusy.turns == 0, "another timed action in progress: no turn yet")
pBusy.busy = false
Detect.updateFacing(9, pBusy)
check(#pBusy.turns == 1, "turn fires once the other timed action clears")

-- 11: two players independent (splitscreen, point 5's own "per player").
local squareA, squareB = scaleSquare(true, DIR_E), scaleSquare(true, DIR_S)
local pA, pB = makePlayer(), makePlayer()
pA.getCurrentSquare = function() return squareA end
pB.getCurrentSquare = function() return squareB end
Detect.update(10, pA)
Detect.update(11, pB)
Detect.updateFacing(10, pA)
check(#pA.turns == 1 and #pB.turns == 0, "player 10 turns without touching player 11's state")
Detect.updateFacing(11, pB)
check(#pA.turns == 1 and #pB.turns == 1 and pB.turns[1] == DIR_S,
    "player 11 turns independently, toward its own scale's Facing")

Detect.tickEvery = 6

print(nAssert .. " assertions passed")
check(nAssert > 0, "no assertions ran")
