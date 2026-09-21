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
--   range       which weight range the HUD maps ("medical" = Geo.weight)
-- The medical numbers were measured off the sprite art (Tiles2x.pack,
-- location_community_medical_01_8 and _9), see WeightScaleOccupants. The
-- digital slab is drawn by tools/gen-scale-art.py: 0.6 tile square centred
-- (half 0.3), 4/96 tile thick; plateTop is unproven until placed in game.
WeightScale = WeightScale or {}
WeightScale.Scales = WeightScale.Scales or {}
local Scales = WeightScale.Scales

local function medical(cx, cy)
    return {
        kind = "medical", style = "beam", plate = { cx, cy }, half = 0.28,
        plateTop = 0.04, standable = true, faceColumn = true, range = "medical",
    }
end

local function digital()
    return {
        kind = "digital", style = "panel", plate = { 0.5, 0.5 }, half = 0.3,
        plateTop = 0.04, standable = true, faceColumn = false, range = "digital",
    }
end

Scales.byName = {
    ["location_community_medical_01_8"] = medical(0.33, 0.43),
    ["location_community_medical_01_9"] = medical(0.48, 0.37),
    ["deadweight_digital_01_0"] = digital(),
    ["deadweight_digital_01_1"] = digital(),
    ["deadweight_digital_01_2"] = digital(),
    ["deadweight_digital_01_3"] = digital(),
}

-- the entry of a sprite name, nil when it is not a scale
function Scales.forSprite(name)
    if not name then return nil end
    return Scales.byName[name]
end
