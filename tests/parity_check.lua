-- Compares WeightScaleCore.sample() against the maquette's own anim.js
-- sampler (dumped by tests/parity_dump.js as mode\tt\talpha\tdy\tangle\treading\tvisible).
package.path = "src/lua/client/?.lua;" .. package.path
require("WeightScale/WeightScaleGeo")
require("WeightScale/WeightScaleCore")
local Core = WeightScale.Core

local path = arg[1]
if not path then
    io.stderr:write("FAIL: usage: parity_check.lua <tsv file>\n")
    os.exit(1)
end
local f = io.open(path, "r")
if not f then
    io.stderr:write("FAIL: cannot open " .. path .. "\n")
    os.exit(1)
end

local EPS = 1e-6
local n = 0
for line in f:lines() do
    if line ~= "" then
        local mode, t, alpha, dy, angle, reading, visible =
            line:match("^(%a+)\t([%-%d%.eE]+)\t([%-%d%.eE]+)\t([%-%d%.eE]+)\t([%-%d%.eE]+)\t([%-%d%.eE]+)\t(%d)$")
        if not mode then
            io.stderr:write("FAIL: cannot parse line: " .. line .. "\n")
            os.exit(1)
        end
        t = tonumber(t)
        local target = 62.7
        local s = Core.sample(mode, t, target)
        n = n + 1
        local function near(a, b, label)
            if math.abs(a - b) > EPS then
                io.stderr:write(string.format(
                    "FAIL: %s t=%s %s: lua=%.9f js=%.9f diff=%.9f\n",
                    mode, t, label, a, b, math.abs(a - b)))
                os.exit(1)
            end
        end
        near(s.alpha, tonumber(alpha), "alpha")
        near(s.dy, tonumber(dy), "dy")
        near(s.angle, tonumber(angle), "angle")
        near(s.reading, tonumber(reading), "reading")
        local visNum = s.visible and 1 or 0
        if visNum ~= tonumber(visible) then
            io.stderr:write(string.format("FAIL: %s t=%s visible: lua=%d js=%s\n", mode, t, visNum, visible))
            os.exit(1)
        end
    end
end
f:close()

if n == 0 then
    io.stderr:write("FAIL: parity check ran zero comparisons\n")
    os.exit(1)
end
print(n .. " parity rows matched within " .. EPS)
