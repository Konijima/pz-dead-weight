-- Per-user prefs: unit (kg|lb) and style (beam|panel). Uses getFileWriter /
-- getFileReader, both B41 and B42 stable core Lua API (unchanged across
-- builds; used by countless mods' save files). Must survive a missing or
-- garbage file without erroring.
WeightScale = WeightScale or {}
WeightScale.Prefs = WeightScale.Prefs or {}
local Prefs = WeightScale.Prefs

Prefs.FILE = "WeightScale_prefs.ini"
Prefs.unit = "kg"
Prefs.style = "beam"

local function sanitizeUnit(v)
    if v == "kg" or v == "lb" then return v end
    return "kg"
end

local function sanitizeStyle(v)
    if v == "beam" or v == "panel" then return v end
    return "beam"
end

function Prefs.load()
    Prefs.unit = "kg"
    Prefs.style = "beam"
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
            elseif key == "style" then
                Prefs.style = sanitizeStyle(value)
            end
        end
    end)
    pcall(function() reader:close() end)
    if not okRead then
        Prefs.unit = "kg"
        Prefs.style = "beam"
    end
end

function Prefs.save()
    if not getFileWriter then return end
    -- getFileWriter(name, overwrite, append) mirrors the common mod pattern.
    local ok, writer = pcall(getFileWriter, Prefs.FILE, true, false)
    if not ok or not writer then return end
    pcall(function()
        writer:write("unit=" .. Prefs.unit .. "\n")
        writer:write("style=" .. Prefs.style .. "\n")
    end)
    pcall(function() writer:close() end)
end

function Prefs.toggleUnit()
    Prefs.unit = (Prefs.unit == "kg") and "lb" or "kg"
    Prefs.save()
end

function Prefs.toggleStyle()
    Prefs.style = (Prefs.style == "beam") and "panel" or "beam"
    Prefs.save()
end
