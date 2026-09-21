-- Per-user prefs: unit (kg|lb). The readout style follows the scale type now
-- (WeightScaleScales.lua); an old prefs file with a style= line still loads. Uses getFileWriter /
-- getFileReader, both B41 and B42 stable core Lua API (unchanged across
-- builds; used by countless mods' save files). Must survive a missing or
-- garbage file without erroring.
WeightScale = WeightScale or {}
WeightScale.Prefs = WeightScale.Prefs or {}
local Prefs = WeightScale.Prefs

Prefs.FILE = "WeightScale_prefs.ini"
Prefs.unit = "kg"

local function sanitizeUnit(v)
    if v == "kg" or v == "lb" then return v end
    return "kg"
end

function Prefs.load()
    Prefs.unit = "kg"
    if not getFileReader then return end

    local ok, reader = pcall(getFileReader, Prefs.FILE, false)
    if not ok or not reader then return end

    local okRead = pcall(function()
        while true do
            local line = reader:readLine()
            if not line then break end
            local key, value = string.match(line, "^(%a+)=(.*)$")
            if key == "unit" then
                Prefs.unit = sanitizeUnit(value)
            end
        end
    end)
    pcall(function() reader:close() end)
    if not okRead then
        Prefs.unit = "kg"
    end
end

function Prefs.save()
    if not getFileWriter then return end
    -- getFileWriter(name, overwrite, append) mirrors the common mod pattern.
    local ok, writer = pcall(getFileWriter, Prefs.FILE, true, false)
    if not ok or not writer then return end
    pcall(function()
        writer:write("unit=" .. Prefs.unit .. "\n")
    end)
    pcall(function() writer:close() end)
end

function Prefs.toggleUnit()
    Prefs.unit = (Prefs.unit == "kg") and "lb" or "kg"
    Prefs.save()
end
