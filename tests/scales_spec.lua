-- Bench for the one scale table (WeightScale.Scales) and what reads it,
-- run under lua5.1 (no PZ runtime). Stubs mirror the game: square:getObjects()
-- is a Java list (size()/get(i), 0-based), a sprite answers getName().
package.path = "src/lua/client/?.lua;" .. package.path

local nAssert = 0
local function check(cond, msg)
    nAssert = nAssert + 1
    if not cond then
        io.stderr:write("FAIL: " .. msg .. "\n")
        os.exit(1)
    end
end

IsoDirections = { N = { name = "N" }, S = { name = "S" }, E = { name = "E" }, W = { name = "W" } }

require "WeightScale/WeightScaleDetect"
local Scales, Detect = WeightScale.Scales, WeightScale.Detect

-- forSprite: medical, digital, unknown, nil
local m8 = Scales.forSprite("location_community_medical_01_8")
local m9 = Scales.forSprite("location_community_medical_01_9")
check(m8 and m8.kind == "medical" and m8.style == "beam", "medical _8 is a medical beam scale")
check(m8.plate[1] == 0.33 and m8.plate[2] == 0.43, "medical _8 plate centre is unchanged")
check(m9.plate[1] == 0.48 and m9.plate[2] == 0.37, "medical _9 plate centre is unchanged")
check(m8.half == 0.28 and m8.plateTop == 0.04 and m9.half == 0.28 and m9.plateTop == 0.04, "medical half and plateTop unchanged")
check(m8.standable == true and m8.faceColumn == true and m8.range == "medical", "medical scale: standable, faces its column")
for i = 0, 3 do
    local d = Scales.forSprite("deadweight_digital_01_" .. i)
    check(d and d.kind == "digital" and d.style == "panel", "digital sprite " .. i .. " is a digital panel scale")
    check(d.standable == true and d.faceColumn == false and d.range == "digital", "digital sprite " .. i .. ": standable, no column")
end
check(Scales.forSprite("deadweight_digital_01_4") == nil, "a fifth digital sprite is not registered")
check(Scales.forSprite("location_community_medical_01_7") == nil, "an unknown sprite is not a scale")
check(Scales.forSprite(nil) == nil and Scales.forSprite("") == nil, "nil and empty names are not scales")

-- Detect reads the table: entry of a square, facingFor nil for a digital scale
local function squareWith(name, facing)
    local obj = {
        getSprite = function() return { getName = function() return name end } end,
        getFacing = function() return facing end,
    }
    return { getObjects = function()
        return { size = function() return 1 end, get = function(_, i) return obj end }
    end }
end

local med = squareWith("location_community_medical_01_8", IsoDirections.E)
local dig = squareWith("deadweight_digital_01_0", IsoDirections.E)
local other = squareWith("floors_interior_tilesandwood_01_10", IsoDirections.E)
check(Detect.scaleEntryOn(med) == m8, "scaleEntryOn returns the medical entry")
check(Detect.scaleEntryOn(dig) == Scales.forSprite("deadweight_digital_01_0"), "scaleEntryOn returns the digital entry")
check(Detect.scaleEntryOn(other) == nil and Detect.scaleEntryOn(nil) == nil, "scaleEntryOn is nil without a scale")
check(Detect.facingFor(med) == IsoDirections.W, "medical scale still faces opposite its Facing")
check(Detect.facingFor(dig) == IsoDirections.N, "a digital scale facing S is read looking north, whatever its Facing property says")
for i, want in ipairs({ "N", "W", "S", "E" }) do
    local sq = squareWith("deadweight_digital_01_" .. (i - 1), IsoDirections.E)
    check(Detect.facingFor(sq) == IsoDirections[want], "digital sprite " .. (i - 1) .. " turns the player " .. want)
end
check(Detect.facingFor(other) == nil, "no scale, no facing")

print("scales_spec: " .. nAssert .. " assertions OK")
