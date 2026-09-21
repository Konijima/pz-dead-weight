-- The one table of every scale sprite the mod knows, keyed by sprite name.
-- Pure data, no game API (bench friendly): Detect finds scales by it,
-- Occupants reads each plate box off it, the context menu recognises a
-- clicked scale by it. A new scale is one entry here, not a lookup added in
-- several modules.
--   kind        "medical" (the clinic beam scale) or "digital" (home scale)
--   style       "beam" (beam head HUD) or "panel" (the native panel)
--   plate       {cx, cy} centre of the weighing area inside the tile, tile
--               fractions (x grows right-down on screen, y grows left-down)
--   half        half size of the square weighing area around plate
--   plateTop    height of the plate's top above the ground, tile fractions
--   standable   a character may stand on it
--   faceColumn  the scale has a column the player turns to face on stepping on
--   faceDir     a fixed direction ("N","S","E","W") the player turns to on
--               stepping on, for a scale with no column: they look at the
--               reading, so away from the side its screen text reads from
--   range       which weight range the HUD maps ("medical" = Geo.weight)
-- The medical numbers were measured off the sprite art (Tiles2x.pack,
-- location_community_medical_01_8 and _9), see WeightScaleOccupants. The
-- digital slab is drawn by tools/gen-scale-art.py: 0.34 tile square, 0.13 behind the centre
-- (a bathroom scale is about 30 cm), 2.5/96 tile thick; half 0.2 leaves room to stand on it; plateTop is unproven until placed in game.
WeightScale = WeightScale or {}
WeightScale.Scales = WeightScale.Scales or {}
local Scales = WeightScale.Scales

local function medical(cx, cy)
    return {
        kind = "medical", style = "beam", plate = { cx, cy }, half = 0.28,
        plateTop = 0.04, standable = true, faceColumn = true, range = "medical",
    }
end

-- the slab is drawn BACK_SHIFT (0.13, tools/gen-scale-art.py) behind the tile
-- centre, away from the side it faces: (rx, ry) is the direction it faces
local FACE_NAME = { ["0,1"] = "N", ["1,0"] = "W", ["0,-1"] = "S", ["-1,0"] = "E" }
local function digital(rx, ry)
    return {
        faceDir = FACE_NAME[rx .. "," .. ry],
        kind = "digital", style = "panel", plate = { 0.5 - 0.13 * rx, 0.5 - 0.13 * ry }, half = 0.2,
        plateTop = 0.03, standable = true, faceColumn = false, range = "digital",
    }
end

Scales.byName = {
    ["location_community_medical_01_8"] = medical(0.33, 0.43),
    ["location_community_medical_01_9"] = medical(0.48, 0.37),
    ["deadweight_digital_01_0"] = digital(0, 1),    -- S
    ["deadweight_digital_01_1"] = digital(1, 0),    -- E
    ["deadweight_digital_01_2"] = digital(0, -1),   -- N
    ["deadweight_digital_01_3"] = digital(-1, 0),   -- W
}

-- the entry of a sprite name, nil when it is not a scale
function Scales.forSprite(name)
    if not name then return nil end
    return Scales.byName[name]
end
