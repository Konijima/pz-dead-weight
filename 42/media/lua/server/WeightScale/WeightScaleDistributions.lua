-- Loot: the Digital Scale can turn up in bathroom counters (Build 42 only,
-- the item Mov_DeadWeightDigital lives in the B42 tile pack and script, see
-- tools/sync.sh). The lists are extended in OnPreDistributionMerge, the hook
-- vanilla's own SuburbsDistributions uses, so the change is merged with the
-- rest. Weight comes from the DeadWeight.HomeScaleSpawn sandbox option (0 =
-- never). Only containers filled from now on are affected: a container
-- already rolled in an existing save keeps what it has.
-- Lists that do not exist in this build are skipped, never indexed: a nil
-- index here would stop every mod merging after this one.
WeightScale = WeightScale or {}
WeightScale.Distributions = WeightScale.Distributions or {}
local D = WeightScale.Distributions

D.item = "Mov_DeadWeightDigital"
D.default = 3
-- Counters only (the cupboards under a basin): a bathroom scale does not
-- belong in a wall medicine cabinet or on a shelf (seen in game, 2026-09-21).
D.lists = {
    "BathroomCounter", "BathroomCounterEmpty", "BathroomCounterMotel", "BathroomCounterNoMeds",
}

-- the sandbox weight, D.default when the option is not readable yet
function D.weight()
    local w = type(SandboxVars) == "table" and type(SandboxVars.DeadWeight) == "table"
        and SandboxVars.DeadWeight.HomeScaleSpawn
    if type(w) ~= "number" then return D.default end
    return math.max(0, math.min(20, w))
end

function D.merge()
    local w = D.weight()
    if w <= 0 then return 0 end
    if type(ProceduralDistributions) ~= "table" or type(ProceduralDistributions.list) ~= "table" then return 0 end
    local added = 0
    for _, name in ipairs(D.lists) do
        local list = ProceduralDistributions.list[name]
        if type(list) == "table" and type(list.items) == "table" then
            table.insert(list.items, D.item)
            table.insert(list.items, w)
            added = added + 1
        end
    end
    return added
end

-- A weighted roll can pick the item more than once per container (rolls = 4
-- on a counter, seen in game 2026-09-21: "Digital Scale (2)"), and a bathroom
-- has several counters. After a container is filled, keep one scale in it and
-- take the extras out; and once a container of a room has one, the room's
-- other containers get none (best effort: remembered for the session, a room
-- is filled in one go when its chunk loads). OnFillContainer runs right after
-- the fill, before anything is shown or sent, so removing needs no transmit.
local givenRoom = {}

local function roomKeyOf(container)
    local parent = type(container.getParent) == "function" and container:getParent()
    local sq = parent and type(parent.getSquare) == "function" and parent:getSquare()
    local room = sq and type(sq.getRoom) == "function" and sq:getRoom()
    if not room then return nil end
    local def = type(room.getRoomDef) == "function" and room:getRoomDef()
    return def and type(def.getID) == "function" and def:getID() or room
end

function D.limit(roomName, containerType, container)
    -- OnFillContainer also fires with an ItemPickerJava.ItemPickerContainer
    -- (zombie bags, seen in game 2026-09-21: "attempted index: getItems of
    -- non-table"), which is not an ItemContainer and cannot be indexed from Lua.
    if type(instanceof) == "function" then
        if not instanceof(container, "ItemContainer") then return end
    elseif type(container) ~= "table" then
        return
    end
    if type(container.getItems) ~= "function" then return end
    local items = container:getItems()
    local mine = {}
    for i = 0, items:size() - 1 do
        local it = items:get(i)
        if it and type(it.getType) == "function" and it:getType() == D.item then mine[#mine + 1] = it end
    end
    if #mine == 0 then return end
    local key = roomKeyOf(container)
    local keep = 1
    if key and givenRoom[key] ~= nil and givenRoom[key] ~= container then keep = 0 end
    for i = keep + 1, #mine do container:Remove(mine[i]) end
    if keep == 1 and key then givenRoom[key] = container end
end

if Events and Events.OnFillContainer and Events.OnFillContainer.Add then
    Events.OnFillContainer.Add(D.limit)
end

if Events and Events.OnPreDistributionMerge and Events.OnPreDistributionMerge.Add then
    Events.OnPreDistributionMerge.Add(D.merge)
end
