WeightScale = WeightScale or {};

---@type ArrayList
WeightScale.AllSprites = WeightScale.AllSprites or ArrayList.new();
WeightScale.AllSprites:add("location_community_medical_01_8");
WeightScale.AllSprites:add("location_community_medical_01_9");

local function doWeightMyself(playerObj, square, facing)
    if luautils.walkAdj(playerObj, square) then
        local x, y, z = square:getX(), square:getY(), square:getZ();
        ISTimedActionQueue.add(ISPathFindAction:pathToLocationF(playerObj, math.floor(x) + 0.5, math.floor(y) + 0.5, z));
        ISTimedActionQueue.add(WeightScale.UseWeightScaleAction:new(playerObj, square, facing));
    end
end

local function onFillWorldObjectContextMenu(player, context, worldobjects)
    local playerObj = getSpecificPlayer(player);

    if not playerObj or playerObj:getVehicle() then return; end

	for _, obj in ipairs(worldobjects) do
        local sprite = obj:getSprite();
        if sprite then
            local props = sprite:getProperties();
            local spriteName = sprite:getName();
            if WeightScale.AllSprites:contains(spriteName) then
                context:addOptionOnTop(getText("ContextMenu_WeightMySelf"), playerObj, doWeightMyself, obj:getSquare(), props:Val("Facing") or "E");
                return;
            end
        end
	end
end
Events.OnFillWorldObjectContextMenu.Add(onFillWorldObjectContextMenu);
