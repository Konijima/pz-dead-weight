-- Pure logic, no game API. Ported 1:1 from docs/maquettes/v2/js/anim.js so the
-- bench can compare Lua against the maquette's own sampler. Kahlua is Lua 5.1:
-- no goto, no bit ops, no string.format reliance.
require "WeightScale/WeightScaleGeo"

WeightScale = WeightScale or {}
WeightScale.Core = WeightScale.Core or {}
local WeightScaleCore = WeightScale.Core
local Geo = WeightScale.Geo
local W = Geo.weight

local function clamp(v, lo, hi)
    if v < lo then return lo end
    if v > hi then return hi end
    return v
end

local function clamp01(v)
    return clamp(v, 0, 1)
end

function WeightScaleCore.mapX(w)
    local t = (clamp(w, W.min, W.max) - W.min) / (W.max - W.min)
    return Geo.track.x0 + t * Geo.track.w
end

function WeightScaleCore.unmapX(x)
    local t = (x - Geo.track.x0) / Geo.track.w
    return W.min + t * (W.max - W.min)
end

function WeightScaleCore.bandOf(w)
    for i = 1, #Geo.bands do
        local b = Geo.bands[i]
        local hit
        if b.inc then hit = (w <= b.upTo) else hit = (w < b.upTo) end
        if hit then return b end
    end
    return Geo.bands[#Geo.bands]
end

-- lower bound of band index i (1-based), mirrors anim.js lower(i) (0-based).
function WeightScaleCore.lower(i)
    if i <= 1 then return W.min end
    return Geo.bands[i - 1].upTo
end

-- One decimal, always, never zero and never two. Kahlua's string.format is not
-- trusted for "%.1f" so this rounds and builds the string itself.
function WeightScaleCore.format(kg, unit)
    local v = kg
    if unit == "lb" then v = kg * 2.20462 end
    local scaled = v * 10
    -- round half away from zero, integer arithmetic only.
    local rounded
    if scaled >= 0 then
        rounded = math.floor(scaled + 0.5)
    else
        rounded = -math.floor(-scaled + 0.5)
    end
    local whole = math.floor(rounded / 10)
    local frac = rounded - whole * 10
    if frac < 0 then frac = -frac end
    return tostring(whole) .. "." .. tostring(frac)
end

WeightScaleCore.ease = {
    outCubic = function(t) return 1 - math.pow(1 - t, 3) end,
    outQuad = function(t) return 1 - (1 - t) * (1 - t) end,
    inQuad = function(t) return t * t end,
    inOutCubic = function(t)
        if t < 0.5 then
            return 4 * t * t * t
        end
        return 1 - math.pow(-2 * t + 2, 3) / 2
    end,
}

local T = {
    appear = 160, tipDur = 140, hold = 120, slide = 800,
    settle = 1400, tau = 340, freq = 2.3,
    offFall = 120, offFade = 220,
}
T.slideStart = T.tipDur + T.hold
T.settleStart = T.slideStart + T.slide
T.onEnd = T.settleStart + T.settle
T.offEnd = T.offFall + T.offFade
WeightScaleCore.T = T

-- Pure hit test for the readout rectangle: no hit while idle (nothing drawn,
-- so no dead zone over the map), no hit once the leaving animation has fully
-- faded (alpha <= 0, still "visible" for a frame or two under sample()'s
-- offEnd cutoff but nothing on screen to click on). rect is {x, y, w, h};
-- alpha is optional, treated as fully opaque when omitted.
function WeightScaleCore.hitTest(mode, x, y, rect, alpha)
    if mode == "idle" then return false end
    if alpha ~= nil and alpha <= 0 then return false end
    if x < rect.x or x >= rect.x + rect.w then return false end
    if y < rect.y or y >= rect.y + rect.h then return false end
    return true
end

-- Total kg on the scale: every occupant's weight added, true value, never
-- clamped to the scale's own range (task 2026-09-20): a chicken reads under 35
-- kg and two people read their real sum above 130 kg. The beam alone stays
-- inside the range (mapX clamps the position), so it rests at either end and
-- the numeral tells the truth. Floors at 0 so a negative sum cannot happen.
-- nil when nobody is on it; non numbers in the list are ignored.
function WeightScaleCore.sumWeights(list)
    local sum, count = 0, 0
    for i = 1, #list do
        local w = list[i]
        if type(w) == "number" then
            sum = sum + w
            count = count + 1
        end
    end
    if count == 0 then return nil end
    if sum < 0 then sum = 0 end
    return sum
end

-- A zombie has no weight in the game, so it gets a hallucinated one: a pure
-- function of an id that is unique per zombie (see WeightScaleOccupants), about
-- 60.0 to 90.0 kg at one decimal, never fat, not all equal. Integer maths kept
-- under 2^53 (Kahlua doubles, no bit ops); the half word swap breaks the
-- linearity of the multiply, so consecutive ids do not walk in a straight line.
local ZW_MOD = 2147483647
function WeightScaleCore.zombieWeight(id)
    local x = math.floor(math.abs(tonumber(id) or 0)) % ZW_MOD + 1
    for _ = 1, 3 do
        x = (x * 48271) % ZW_MOD
        x = ((x % 65536) * 31337 + math.floor(x / 65536)) % ZW_MOD
    end
    return (600 + x % 301) / 10
end

-- mode "on" | "off"; t in ms from the start of that move; target in kg.
-- from (optional, kg, default the scale minimum) is where the slide starts,
-- so a retarget can glide from the current reading instead of from the stop.
-- Returns { alpha, dy, angle, reading, visible }, same fields as anim.js sample().
function WeightScaleCore.sample(mode, t, target, from)
    local ease = WeightScaleCore.ease
    local s = { alpha = 1, dy = 0, angle = 0, reading = target, visible = true }

    if mode == "off" then
        local f = clamp01(t / T.offFall)
        s.angle = Geo.beam.maxDeg * ease.outQuad(f)
        local g = clamp01((t - T.offFall) / T.offFade)
        s.alpha = 1 - ease.inQuad(g)
        s.dy = 8 * ease.inQuad(g)
        s.visible = t < T.offEnd
        return s
    end

    s.alpha = ease.outCubic(clamp01(t / T.appear))
    s.dy = 10 * (1 - ease.outCubic(clamp01(t / T.appear)))
    if t < T.slideStart then
        s.angle = -Geo.beam.maxDeg * ease.outQuad(clamp01(t / T.tipDur))
        s.reading = W.min
    elseif t < T.settleStart then
        local p = ease.inOutCubic(clamp01((t - T.slideStart) / T.slide))
        s.angle = -Geo.beam.maxDeg
        local w0 = from or W.min
        if target < W.min or target > W.max or w0 < W.min or w0 > W.max then
            -- outside the scale range the beam is pinned at an end, so the
            -- numeral counts in kg instead of through the (clamped) beam x.
            s.reading = w0 + (target - w0) * p
        else
            local x0 = WeightScaleCore.mapX(w0)
            s.reading = WeightScaleCore.unmapX(x0 + (WeightScaleCore.mapX(target) - x0) * p)
        end
    else
        local u = (t - T.settleStart) / 1000
        s.angle = -Geo.beam.maxDeg * math.exp(-u * 1000 / T.tau) *
            math.cos(2 * math.pi * T.freq * u)
        s.reading = target
    end
    return s
end
