-- ISUIElement sized to the readout rectangle and registered with the UI
-- manager only while the readout is on screen, drawing with texture blits and
-- rectangles only (no drawText, so the player's font size option can never
-- change the look). The element sits at screen centre + the maquette offsets
-- (docs/maquettes/v2/js app.js anchor()) and everything inside is drawn in
-- element local coordinates, 0,0 being its top left.
-- A full screen element used to swallow every mouse release in the game:
-- UIManager.updateMouseButtons asks each element under the cursor to consume
-- the event, and zombie.ui.UIElement.onRightMouseUp answers "consumed" when
-- the Lua handler returns nothing, which ISUIElement:onRightMouseUp does.
-- The world context menu only fires on the ungated path, so it never opened.
-- See docs/API-COMPAT.md for the proof behind every call here.
require "WeightScale/WeightScaleGeo"
require "WeightScale/WeightScaleCore"

WeightScale = WeightScale or {}
WeightScale.HUD = ISUIElement:derive("WeightScale.HUD")
local HUD = WeightScale.HUD
local Geo = WeightScale.Geo
local Core = WeightScale.Core

local CREAM = {0.933, 0.910, 0.847}   -- 238,232,216 / 255
local DIM   = {0.596, 0.573, 0.510}   -- 152,146,130 / 255

local TEX_NAMES = {"plate", "beam", "poise", "slab"}
local TEX_PATH = "media/textures/WeightScale/"

local function loadTextures()
    if HUD._tex then return HUD._tex end
    local t = {}
    for i = 1, #TEX_NAMES do
        local name = TEX_NAMES[i]
        if getTexture then
            t[name] = getTexture(TEX_PATH .. name .. ".png")
        end
    end
    if getTexture then
        t.glyphs = getTexture(TEX_PATH .. "glyphs.png")
    end
    HUD._tex = t
    return t
end

-- Glyph metrics, mirrors docs/maquettes/v2/assets/glyphs.json. Kept inline so
-- the HUD does not depend on parsing JSON at runtime.
local GLYPH_NUM = {
    base = 37,
    glyphs = {
        ["0"] = {sx=0,   sy=0, w=17, h=25, xo=1, yo=13, xa=19},
        ["1"] = {sx=19,  sy=0, w=12, h=24, xo=2, yo=13, xa=19},
        ["2"] = {sx=33,  sy=0, w=17, h=24, xo=1, yo=13, xa=19},
        ["3"] = {sx=52,  sy=0, w=17, h=25, xo=1, yo=13, xa=19},
        ["4"] = {sx=71,  sy=0, w=19, h=24, xo=0, yo=13, xa=19},
        ["5"] = {sx=92,  sy=0, w=16, h=25, xo=1, yo=13, xa=19},
        ["6"] = {sx=110, sy=0, w=17, h=25, xo=1, yo=13, xa=19},
        ["7"] = {sx=129, sy=0, w=18, h=24, xo=0, yo=13, xa=19},
        ["8"] = {sx=149, sy=0, w=17, h=25, xo=1, yo=13, xa=19},
        ["9"] = {sx=168, sy=0, w=17, h=25, xo=1, yo=13, xa=19},
        ["."] = {sx=187, sy=0, w=6,  h=6,  xo=1, yo=32, xa=9},
    },
}
local GLYPH_UNIT = {
    base = 30,
    glyphs = {
        k = {sx=195, sy=0, w=14, h=21, xo=2, yo=9,  xa=15},
        g = {sx=211, sy=0, w=14, h=22, xo=1, yo=14, xa=16},
        l = {sx=227, sy=0, w=4,  h=21, xo=2, yo=9,  xa=7},
        [" "] = {sx=233, sy=0, w=2, h=1, xo=0, yo=39, xa=7},
        b = {sx=237, sy=0, w=14, h=21, xo=2, yo=9,  xa=16},
    },
}

local function glyphMeasure(set, text)
    local w = 0
    for i = 1, #text do
        local g = set.glyphs[string.sub(text, i, i)]
        if g then w = w + g.xa end
    end
    return w
end

-- B42 PROVEN: ISUIElement:drawSubTexture(texture, subX, subY, subW, subH, x, y, w, h, a, r, g, b)
-- B41 UNPROVEN: guarded, skips the glyph rather than erroring.
function HUD:drawGlyphs(set, text, x, y, rgb, alpha)
    local tex = loadTextures().glyphs
    if not tex or type(self.drawSubTexture) ~= "function" then return end
    local pen = x
    for i = 1, #text do
        local g = set.glyphs[string.sub(text, i, i)]
        if g then
            if g.w > 0 and g.h > 0 then
                self:drawSubTexture(tex, g.sx, g.sy, g.w, g.h,
                    pen + g.xo, y - set.base + g.yo, g.w, g.h,
                    alpha, rgb[1], rgb[2], rgb[3])
            end
            pen = pen + g.xa
        end
    end
end

-- boxW is the width to centre the text within, measured from baseX (NOT
-- always Geo.slab.w: the beam head centres within the slab, the panel
-- centres within its own, narrower, box -- see the maquette's numeral() vs
-- nativePanel() in docs/maquettes/v2/js/draw-readout.js). baseYOffset is
-- likewise per style: the slab uses +32 off its own y, the panel draws at a
-- fixed 38 off its own top (nativePanel() again). Passing the wrong box
-- here is exactly the 2026-09-18 bug: the panel's background stayed at the
-- contract's 152x52 while the text centred on the beam's 288-wide slab and
-- spilled out the right edge.
function HUD:drawNumeral(baseX, baseY, w, unit, alpha, boxW, baseYOffset)
    boxW = boxW or Geo.slab.w
    baseYOffset = baseYOffset or 32
    local val = Core.format(w, unit)
    local nw = glyphMeasure(GLYPH_NUM, val)
    local uw = glyphMeasure(GLYPH_UNIT, unit)
    local x = math.floor(baseX + (boxW - (nw + 9 + uw)) / 2 + 0.5)
    local base = baseY + baseYOffset
    self:drawGlyphs(GLYPH_NUM, val, x, base, CREAM, alpha)
    self:drawGlyphs(GLYPH_UNIT, unit, x + nw + 9, base, DIM, alpha)
end

-- Graduation ticks and band zones, painted at ax,ay (readout top left).
function HUD:drawGraduation(ax, ay, w)
    local t = Geo.track
    local active = Core.bandOf(w)
    local k = Geo.weight.min
    while k <= Geo.weight.max + 0.001 do
        local major = (math.floor(k) % t.majorEvery == 0) or k == Geo.weight.min or k == Geo.weight.max
        local h = major and t.majorH or t.minorH
        local x = math.floor(Core.mapX(k) + 0.5) - (major and 1 or 0)
        local a, r, g, b
        if major then a, r, g, b = 0.95, 48/255, 42/255, 31/255 else a, r, g, b = 0.72, 74/255, 66/255, 50/255 end
        self:drawRect(ax + x, ay + t.tickBaseY - h, major and 2 or 1, h, a, r, g, b)
        k = k + t.minorEvery
    end

    for i = 1, #Geo.bands do
        local band = Geo.bands[i]
        local x0 = math.floor(Core.mapX(Core.lower(i)) + 0.5)
        local x1 = math.floor(Core.mapX(band.upTo) + 0.5)
        local on = (band == active)
        local alpha = on and 1 or 0.40
        local r, gc, bl = band.colour[1] / 255, band.colour[2] / 255, band.colour[3] / 255
        self:drawRect(ax + x0, ay + t.bandY, x1 - x0, t.bandH, alpha, r, gc, bl)
        if on then
            self:drawRect(ax + x0, ay + t.bandY - 2, x1 - x0, t.bandH + 4, alpha, r, gc, bl)
            self:drawRect(ax + x0 - 1, ay + t.bandY - 3, x1 - x0 + 2, 1, 0.85, 28/255, 24/255, 18/255)
            self:drawRect(ax + x0 - 1, ay + t.bandY + t.bandH + 2, x1 - x0 + 2, 1, 0.85, 28/255, 24/255, 18/255)
        end
        if i > 1 then
            self:drawRect(ax + x0, ay + t.bandY - 3, 1, t.bandH + 3, 0.9, 40/255, 35/255, 26/255)
        end
    end
    self:drawRect(ax + math.floor(Core.mapX(Geo.weight.min) + 0.5), ay + t.bandY + t.bandH,
        t.w + 1, 1, 0.55, 40/255, 35/255, 26/255)
end

-- Direction 1: the beam head, the default style.
function HUD:drawBeam(ax, ay, st, unit)
    local tex = loadTextures()
    local b, p, s = Geo.beam, Geo.poise, Geo.slab
    local dy = ay + st.dy
    local alpha = st.alpha

    if tex.plate then self:drawTexture(tex.plate, ax, dy, alpha, 1, 1, 1) end
    self:drawGraduation(ax, dy, st.reading)

    -- Rotate the beam about its own pivot: DrawTextureAngle rotates about the
    -- point given, so the centre supplied is offset from the pivot along the
    -- current angle by half the beam length (B42 PROVEN; B41 UNPROVEN, guarded).
    local angleRad = st.angle * math.pi / 180
    if tex.beam and type(self.DrawTextureAngle) == "function" then
        local half = b.len / 2
        local cx = ax + b.pivotX + half * math.cos(angleRad)
        local cy = dy + b.pivotY + half * math.sin(angleRad)
        self:DrawTextureAngle(tex.beam, cx, cy, st.angle)
    elseif tex.beam then
        -- B41 fallback: no rotation available, draw the beam level.
        self:drawTexture(tex.beam, ax + b.pivotX, dy + b.pivotY - b.h / 2, alpha, 1, 1, 1)
    end

    local L = Core.mapX(st.reading) - b.pivotX
    local poiseX = ax + b.pivotX + L * math.cos(angleRad) - p.w / 2
    local poiseY = dy + b.pivotY + L * math.sin(angleRad) - p.h / 2
    if tex.poise then self:drawTexture(tex.poise, poiseX, poiseY, alpha, 1, 1, 1) end

    local st2 = Geo.stops
    self:drawRect(ax + st2.x, dy + b.pivotY - st2.gap - 1, st2.w, 2, 0.92, 214/255, 208/255, 188/255)
    self:drawRect(ax + st2.x, dy + b.pivotY + st2.gap - 1, st2.w, 2, 0.92, 214/255, 208/255, 188/255)
    self:drawRect(ax + st2.x + st2.w, dy + b.pivotY - st2.gap - 1, 1, st2.gap * 2 + 2, 0.30, 214/255, 208/255, 188/255)

    if tex.slab then self:drawTexture(tex.slab, ax + s.x, dy + s.y, alpha, 1, 1, 1) end
    local band = Core.bandOf(st.reading)
    self:drawRect(ax + s.x, dy + s.y, s.w, 2, alpha, band.colour[1] / 255, band.colour[2] / 255, band.colour[3] / 255)
    self:drawNumeral(ax + s.x, dy + s.y, st.reading, unit, alpha, s.w, 32)
end

-- Direction 2: the native panel fallback style.
function HUD:drawPanel(ax, ay, st, unit)
    local p = Geo.panel
    local dy = ay + st.dy
    local band = Core.bandOf(st.reading)
    self:drawRect(ax, dy, p.w, p.h, st.alpha * 0.74, 0, 0, 0)
    if type(self.drawRectBorder) == "function" then
        self:drawRectBorder(ax, dy, p.w, p.h, st.alpha * 0.34, 1, 1, 1)
    else
        self:drawRectBorderFallback(ax, dy, p.w, p.h, st.alpha * 0.34, 1, 1, 1)
    end
    self:drawRect(ax, dy, 3, p.h, st.alpha, band.colour[1] / 255, band.colour[2] / 255, band.colour[3] / 255)
    self:drawNumeral(ax + 3, dy, st.reading, unit, st.alpha, p.w - 3, 38)
end

-- B42 PROVEN: ISUIElement:drawRectBorder exists (ISUIElement.lua) and draws
-- the same 1px inset border this fallback builds from four rects, so it is
-- used directly via inheritance (self:drawRectBorder resolves to it as long
-- as HUD does not define its own method of that name, see below). Kept for
-- B41, where the method is UNPROVEN, under a different name so it never
-- shadows the native one.
function HUD:drawRectBorderFallback(x, y, w, h, a, r, g, b)
    self:drawRect(x, y, w, 1, a, r, g, b)
    self:drawRect(x, y + h - 1, w, 1, a, r, g, b)
    self:drawRect(x, y, 1, h, a, r, g, b)
    self:drawRect(x + w - 1, y, 1, h, a, r, g, b)
end

-- Anchored to the CENTRE OF THIS PLAYER'S OWN SCREEN REGION, splitscreen or
-- not (task 2026-09-18, point A2). getPlayerScreenLeft/Top/Width/Height(n)
-- are B42 PROVEN (client lua, e.g. Hotbar/ISHotbar.lua:214-217,
-- PZAPI/ui/atoms/Node.lua:118-119) and B41 UNPROVEN, guarded here: with one
-- local player, left/top are 0 and width/height are the full screen, which
-- collapses to the exact same anchor this always used.
function HUD:anchor(kind)
    local n = self.playerNum or 0
    local left, top, w, h
    if getPlayerScreenLeft and getPlayerScreenTop and getPlayerScreenWidth and getPlayerScreenHeight then
        left, top = getPlayerScreenLeft(n), getPlayerScreenTop(n)
        w, h = getPlayerScreenWidth(n), getPlayerScreenHeight(n)
    else
        left, top = 0, 0
        w, h = getCore():getScreenWidth(), getCore():getScreenHeight()
    end
    local o = (kind == "beam") and Geo.offset or Geo.panel
    return math.floor(left + w / 2 + o.dx), math.floor(top + h / 2 + o.dy)
end

function HUD:readoutRect()
    local style = WeightScale.Prefs and WeightScale.Prefs.style or "beam"
    local ax, ay = self:anchor(style)
    if style == "beam" then
        return ax, ay, Geo.readout.w, Geo.readout.h
    end
    return ax, ay, Geo.panel.w, Geo.panel.h
end

-- Moves and resizes the element onto the current style's readout rectangle.
-- Called whenever the readout appears, the style changes or the resolution
-- changes; the drawing below never has to know where the element ended up.
function HUD:applyBounds()
    local x, y, w, h = self:readoutRect()
    self:setX(x)
    self:setY(y)
    self:setWidth(w)
    self:setHeight(h)
end

function HUD:show()
    self:applyBounds()
    if self.shown then return end
    self:addToUIManager()
    self.shown = true
end

function HUD:hide()
    if not self.shown then return end
    self:removeFromUIManager()
    self.shown = false
end

function HUD:render()
    if self.mode == "idle" then return end
    local t = getTimestampMs() - self.t0
    local st = Core.sample(self.mode, t, self.target, self.from)
    if not st.visible then return end
    local unit = WeightScale.Prefs and WeightScale.Prefs.unit or "kg"
    local style = WeightScale.Prefs and WeightScale.Prefs.style or "beam"
    if style == "beam" then
        self:drawBeam(0, 0, st, unit)
    else
        self:drawPanel(0, 0, st, unit)
    end
end

-- Lifecycle, driven once per player tick by WeightScaleMain: nothing is
-- registered with the UI manager once the leaving animation has run out, so
-- the mod owns no screen space at all while the player is off the scale.
-- No table is built here, unlike Core.sample, so the tick path stays free of
-- allocations; T.offEnd is exactly sample()'s own visibility cutoff.
function HUD:tick()
    if self.mode ~= "off" then return end
    if getTimestampMs() - self.t0 < Core.T.offEnd then return end
    self.mode = "idle"
    self:hide()
end

function HUD:startOn(targetKg)
    self.mode = "on"
    self.t0 = getTimestampMs()
    self.target = targetKg
    self.from = nil
    self:show()
end

-- The total on the scale changed while the readout is up (a second occupant,
-- one leaving): slide from what is on screen now to the new value, in the
-- same beam tip, without restarting the appear fade or touching the UI
-- manager (the element stays registered once). Off or idle: a plain startOn.
function HUD:retarget(targetKg)
    if self.mode ~= "on" then return self:startOn(targetKg) end
    local now = getTimestampMs()
    self.from = Core.sample("on", now - self.t0, self.target, self.from).reading
    self.target = targetKg
    self.t0 = now - Core.T.slideStart
end

function HUD:startOff()
    if self.mode == "idle" then return end
    self.mode = "off"
    self.t0 = getTimestampMs()
end

-- Clicks: the element IS the readout rectangle now, so the game never hands
-- it a click from anywhere else. Core.hitTest still runs, in element local
-- coordinates, because it also rules out the frames where the readout is
-- there but invisible (idle, or faded out at the end of the leaving move).
local HIT_RECT = { x = 0, y = 0, w = 0, h = 0 }

function HUD:currentAlpha()
    if self.mode == "idle" then return 0 end
    local st = Core.sample(self.mode, getTimestampMs() - self.t0, self.target, self.from)
    return st.alpha
end

function HUD:hitLocal(x, y)
    HIT_RECT.w = self.width
    HIT_RECT.h = self.height
    return Core.hitTest(self.mode, x, y, HIT_RECT, self:currentAlpha())
end

function HUD:onMouseDown(x, y)
    if not self:hitLocal(x, y) then return false end
    if WeightScale.Prefs then WeightScale.Prefs.toggleUnit() end
    return true
end

function HUD:onRightMouseDown(x, y)
    if not self:hitLocal(x, y) then return false end
    if WeightScale.Prefs then WeightScale.Prefs.toggleStyle() end
    -- The style pref is shared (one file), so a toggle by whichever player's
    -- readout was clicked must resize/reposition every OTHER player's
    -- readout too, not just this one (task 2026-09-18, point A4).
    for i = 1, #HUD._all do
        local h = HUD._all[i]
        if h.shown then h:applyBounds() end
    end
    return true
end

-- All live instances, one per displayed local player. Used only to fan a
-- shared-prefs style toggle out to every readout; HUD:destroy() below keeps
-- this from growing across a player's whole disconnect/reconnect life.
HUD._all = HUD._all or {}

function HUD.new(cls, playerNum)
    local o = ISUIElement:new(0, 0, Geo.readout.w, Geo.readout.h)
    setmetatable(o, cls)
    cls.__index = cls
    o.mode = "idle"
    o.t0 = 0
    o.target = Geo.weight.start
    o.shown = false
    o.playerNum = playerNum or 0
    -- No setAlwaysOnTop: it is a no-op before the element is instantiated
    -- (ISUIElement:setAlwaysOnTop guards on self.javaObject, which only
    -- exists once addToUIManager has run), so the approved look never had
    -- it. An element added last is drawn last anyway.
    -- plain ISUIElement paints no background/border unless told to; nothing
    -- to disable, unlike ISPanel-derived windows.
    table.insert(HUD._all, o)
    return o
end

-- A player slot going away (disconnect, death, nil, task point A3): remove
-- the element from the UI manager and drop every reference to it, so
-- nothing about it can leak.
function HUD:destroy()
    self:hide()
    for i = #HUD._all, 1, -1 do
        if HUD._all[i] == self then table.remove(HUD._all, i) end
    end
end

function HUD:onResolutionChange(oldW, oldH, newW, newH)
    self:applyBounds()
end
