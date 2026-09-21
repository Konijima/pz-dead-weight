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

if Events and Events.OnPreDistributionMerge and Events.OnPreDistributionMerge.Add then
    Events.OnPreDistributionMerge.Add(D.merge)
end
