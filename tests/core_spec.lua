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

print(nAssert .. " assertions passed")
check(nAssert > 0, "no assertions ran")
