-- Pure-Lua bench for WeightScaleCore, run under lua5.1 (no PZ runtime).
package.path = "src/lua/client/?.lua;" .. package.path
require("WeightScale/WeightScaleGeo")
require("WeightScale/WeightScaleCore")
local Core = WeightScale.Core

local nAssert = 0
local function check(cond, msg)
    nAssert = nAssert + 1
    if not cond then
        io.stderr:write("FAIL: " .. msg .. "\n")
        os.exit(1)
    end
end

local function roundpx(v) return math.floor(v + 0.5) end

-- mapX contact points, from docs/maquettes/captures/v2/contact-bandes.txt
local contacts = {
    {35, 30}, {50, 64}, {65, 99}, {75, 122}, {85, 145}, {100, 179}, {130, 248},
}
for i = 1, #contacts do
    local w, px = contacts[i][1], contacts[i][2]
    check(roundpx(Core.mapX(w)) == px, "mapX(" .. w .. ") rounds to " .. px .. ", got " .. roundpx(Core.mapX(w)))
end

-- bandOf inclusivity, at each threshold and just around it.
local cases = {
    {49.9, "emaciated"}, {50.0, "emaciated"}, {50.1, "tresMaigre"},
    {64.9, "tresMaigre"}, {65.0, "tresMaigre"}, {65.1, "maigre"},
    {74.9, "maigre"}, {75.0, "normal"}, {75.1, "normal"},
    {84.9, "normal"}, {85.0, "surpoids"}, {85.1, "surpoids"},
    {99.9, "surpoids"}, {100.0, "obese"}, {100.1, "obese"},
    {35.0, "emaciated"}, {130.0, "obese"},
}
for i = 1, #cases do
    local w, id = cases[i][1], cases[i][2]
    local got = Core.bandOf(w).id
    check(got == id, "bandOf(" .. w .. ") expected " .. id .. ", got " .. got)
end

-- format: one decimal, always.
local fmtCases = {
    {80, "kg", "80.0"}, {80, "lb", "176.4"}, {35, "kg", "35.0"},
    {130, "kg", "130.0"}, {45.32, "lb", "99.9"},
}
for i = 1, #fmtCases do
    local kg, unit, expect = fmtCases[i][1], fmtCases[i][2], fmtCases[i][3]
    local got = Core.format(kg, unit)
    check(got == expect, "format(" .. kg .. "," .. unit .. ") expected " .. expect .. ", got " .. got)
    local dot = string.find(got, "%.")
    check(dot ~= nil, "format(" .. kg .. "," .. unit .. ") has no decimal point: " .. got)
    local decimals = #got - dot
    check(decimals == 1, "format(" .. kg .. "," .. unit .. ") has " .. decimals .. " decimals: " .. got)
end

-- hitTest: idle is a dead readout (no dead zone over the map), a visible HUD
-- reacts inside its rect and passes through outside it, edges are inclusive
-- top/left and exclusive bottom/right, and a fully faded-out leaving frame
-- (alpha <= 0) is not clickable even though sample() still calls it visible.
local hrect = { x = 100, y = 100, w = 50, h = 20 }
check(Core.hitTest("idle", 110, 110, hrect) == false, "hitTest idle inside rect should be false")
check(Core.hitTest("on", 110, 110, hrect) == true, "hitTest visible inside rect should be true")
check(Core.hitTest("on", 90, 90, hrect) == false, "hitTest visible outside rect should be false")
check(Core.hitTest("on", hrect.x, hrect.y, hrect) == true, "hitTest top-left corner inclusive")
check(Core.hitTest("on", hrect.x + hrect.w - 1, hrect.y + hrect.h - 1, hrect) == true,
    "hitTest bottom-right last inside pixel should be true")
check(Core.hitTest("on", hrect.x + hrect.w, hrect.y + hrect.h, hrect) == false,
    "hitTest bottom-right corner exclusive")
check(Core.hitTest("off", 110, 110, hrect, 0) == false, "hitTest fully faded (alpha 0) should be false")
check(Core.hitTest("off", 110, 110, hrect, 0.01) == true, "hitTest barely visible (alpha > 0) should be true")

-- Prefs parser survives garbage / missing file: stub getFileReader.
require("WeightScale/WeightScalePrefs")
local Prefs = WeightScale.Prefs

_G.getFileReader = nil
Prefs.load()
check(Prefs.unit == "kg" and Prefs.style == "beam", "Prefs.load() with no getFileReader should default")

local function makeReader(lines)
    local i = 0
    return {
        readLine = function()
            i = i + 1
            return lines[i]
        end,
        close = function() end,
    }
end

_G.getFileReader = function() return makeReader({"garbage!!", "unit=lb", "style=potato", "###"}) end
Prefs.load()
check(Prefs.unit == "lb", "Prefs.load() should parse unit=lb out of garbage, got " .. tostring(Prefs.unit))
check(Prefs.style == "beam", "Prefs.load() should reject an unknown style, got " .. tostring(Prefs.style))

_G.getFileReader = function() return nil end
Prefs.load()
check(Prefs.unit == "kg" and Prefs.style == "beam", "Prefs.load() with a nil reader should default")

_G.getFileReader = function() error("boom") end
local ok = pcall(Prefs.load)
check(ok, "Prefs.load() must not throw when getFileReader errors")

-- sumWeights: every occupant added, clamped to the scale range, nil when empty.
check(Core.sumWeights({}) == nil, "sumWeights of an empty tile is nil")
check(Core.sumWeights({72.5}) == 72.5, "one occupant reads its own weight")
check(math.abs(Core.sumWeights({60, 70}) - 130) < 1e-9, "two occupants add up")
check(Core.sumWeights({80, 80}) == 130, "two occupants over the range pin at the max")
check(Core.sumWeights({80, 80, 80}) == 130, "three occupants still pin at the max")
check(Core.sumWeights({3}) == 35, "a very light occupant is clamped up to the min")
check(Core.sumWeights({"x", false}) == nil, "non numbers are ignored")

-- zombieWeight: deterministic, 60.0 to 90.0, one decimal, spread over ids.
local seen, distinct, lo, hi = {}, 0, math.huge, -math.huge
for id = 0, 999 do
    local w = Core.zombieWeight(id)
    check(w == Core.zombieWeight(id), "zombieWeight is deterministic for id " .. id)
    check(w >= 60 and w <= 90, "zombieWeight in 60..90, id " .. id .. " gave " .. w)
    check(math.abs(w * 10 - math.floor(w * 10 + 0.5)) < 1e-6, "zombieWeight has one decimal, id " .. id)
    if not seen[w] then seen[w] = true; distinct = distinct + 1 end
    lo, hi = math.min(lo, w), math.max(hi, w)
end
check(distinct >= 250, "zombieWeight spreads over ids, distinct values: " .. distinct)
check(lo < 62 and hi > 88, "zombieWeight covers the range, got " .. lo .. ".." .. hi)
local same = 0
for id = 1, 999 do if Core.zombieWeight(id) == Core.zombieWeight(id - 1) then same = same + 1 end end
check(same < 10, "neighbouring ids rarely share a weight, got " .. same)
check(Core.zombieWeight(nil) == Core.zombieWeight(0), "a missing id falls back to id 0")

-- sample with `from`: default path unchanged, slide starts at `from`.
local T = Core.T
local a = Core.sample("on", T.slideStart, 100)
local b = Core.sample("on", T.slideStart, 100, nil)
check(a.reading == b.reading and a.reading == 35, "no from: the slide starts at the scale minimum")
check(math.abs(Core.sample("on", T.slideStart, 100, 90).reading - 90) < 1e-6, "from: the slide starts at from")
check(math.abs(Core.sample("on", T.settleStart - 0.001, 100, 90).reading - 100) < 0.05, "from: the slide still ends at the target")
check(Core.sample("on", T.settleStart + 10, 100, 90).reading == 100, "from: settled reading is the target")
local down = Core.sample("on", T.slideStart + T.slide / 2, 60, 120).reading
check(down < 120 and down > 60, "from above the target slides downward, got " .. down)

print(nAssert .. " assertions passed")
check(nAssert > 0, "no assertions ran")
