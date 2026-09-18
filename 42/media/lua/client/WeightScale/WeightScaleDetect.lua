-- Presence detection: is the local player (player 0 only) on, or next to, a
-- medical scale. Ticks every few frames, fires onScaleOn/onScaleOff once per
-- transition. See docs/API-COMPAT.md for which calls are proven on which build.
WeightScale = WeightScale or {}
WeightScale.Detect = WeightScale.Detect or {}
local Detect = WeightScale.Detect

Detect.spriteNames = {
    ["location_community_medical_01_8"] = true,
    ["location_community_medical_01_9"] = true,
}

Detect.tickEvery = 6          -- every few ticks, not every frame
Detect._tick = 0
Detect._onScale = false
Detect.onScaleOn = nil        -- set by WeightScaleMain: function(square)
Detect.onScaleOff = nil       -- function()

local function hasScaleSprite(square)
    if not square or not square.getObjects then return false end
    local objs = square:getObjects()
    if not objs then return false end
    local n = objs:size()
    for i = 0, n - 1 do
        local obj = objs:get(i)
        local sprite = obj and obj.getSprite and obj:getSprite()
        local name = sprite and sprite.getName and sprite:getName()
        if name and Detect.spriteNames[name] then
            return true
        end
    end
    return false
end

-- B41 UNPROVEN: IsoGridSquare:isSolid(). Guarded; if missing, treat the
-- square as walkable (matches the verified fact that the scale tile walks).
local function isWalkable(square)
    if not square then return false end
    if type(square.isSolid) ~= "function" then return true end
    local ok, solid = pcall(function() return square:isSolid() end)
    if not ok then return true end
    return not solid
end

-- B41 UNPROVEN: IsoObject:getCell()/IsoCell:getGridSquare(x,y,z). Guarded;
-- if missing, adjacency is skipped (only the exact square is checked).
local function neighbours(square)
    local out = {}
    if not square or not square.getCell then return out end
    local ok, cell = pcall(function() return square:getCell() end)
    if not ok or not cell or not cell.getGridSquare then return out end
    local x, y, z = square:getX(), square:getY(), square:getZ()
    local deltas = { {1,0}, {-1,0}, {0,1}, {0,-1} }
    for i = 1, #deltas do
        local d = deltas[i]
        local okSq, sq = pcall(function() return cell:getGridSquare(x + d[1], y + d[2], z) end)
        if okSq and sq then out[#out + 1] = sq end
    end
    return out
end

local function findScaleSquare(playerObj)
    if not playerObj then return nil end
    local square = nil
    if playerObj.getCurrentSquare then
        square = playerObj:getCurrentSquare()
    end
    if not square and playerObj.getSquare then
        square = playerObj:getSquare()
    end
    if not square then return nil end

    if hasScaleSprite(square) and isWalkable(square) then
        return square
    end
    if not isWalkable(square) then
        local near = neighbours(square)
        for i = 1, #near do
            if hasScaleSprite(near[i]) then
                return near[i]
            end
        end
    end
    return nil
end

function Detect.update()
    Detect._tick = Detect._tick + 1
    if Detect._tick % Detect.tickEvery ~= 0 then return end

    local playerObj = getSpecificPlayer and getSpecificPlayer(0) or (getPlayer and getPlayer())
    if not playerObj then return end

    local square = findScaleSquare(playerObj)
    local onNow = square ~= nil

    if onNow and not Detect._onScale then
        Detect._onScale = true
        if Detect.onScaleOn then Detect.onScaleOn(square) end
    elseif not onNow and Detect._onScale then
        Detect._onScale = false
        if Detect.onScaleOff then Detect.onScaleOff() end
    end
end
