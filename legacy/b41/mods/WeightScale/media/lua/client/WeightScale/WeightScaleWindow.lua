WeightScale = WeightScale or {};

WeightScale.WindowUI = ISCollapsableWindow:derive("WeightScale.WindowUI");

function WeightScale.WindowUI:close()
	self:setVisible(false);
	self:removeFromUIManager();
	WeightScale.WindowUI.instance = nil;
end

function WeightScale.WindowUI:update()
	local dist = self.playerObj:DistToSquared(self.square:getX(), self.square:getY());
	if dist > 1 then
		self:close();
	end
	local calories = string.format("%.3f", self.nutritionObj:getCalories());
	local carbohydrates = string.format("%.3f", self.nutritionObj:getCarbohydrates());
	local lipids = string.format("%.3f", self.nutritionObj:getLipids());
	local proteins = string.format("%.3f", self.nutritionObj:getProteins());
	local name = self.descriptorObj:getForename() .. " " ..  self.descriptorObj:getSurname();
	local weight = string.format("%.3f", self.nutritionObj:getWeight());
	local weightChange = self.nutritionObj:isDecWeight() and getText("IGUI_Losing_weight") or self.nutritionObj:isIncWeightLot() and getText("IGUI_Gaining_weight_fast") or self.nutritionObj:isIncWeight() and getText("IGUI_Gaining_weight") or getText("IGUI_Weight_stable");
	if self.nutritionObj:isDecWeight() and self.nutritionObj:getCalories() < 0 then
		weightChange = getText("IGUI_Losing_weight_fast");
	end;
	self.name_label.name = getText("IGUI_WeightScale_NameLabel") .. ": " .. name;
	self.weight_label.name = getText("IGUI_WeightScale_WeightLabel") .. ": " .. weight;
	self.weightChange_label.name = getText("IGUI_WeightScale_WeightChangeLabel") .. ": " .. weightChange;
	self.calories_label.name = getText("IGUI_WeightScale_CaloriesLabel") .. ": " .. calories;
	self.carbohydrates_label.name = getText("IGUI_WeightScale_CarbohydratesLabel") .. ": " .. carbohydrates;
	self.lipids_label.name = getText("IGUI_WeightScale_LipidsLabel") .. ": " .. lipids;
	self.proteins_label.name = getText("IGUI_WeightScale_ProteinsLabel") .. ": " .. proteins;
end

function WeightScale.WindowUI:initialise()
	local y = 25;
	local labels = {
		name_label = getText("IGUI_WeightScale_NameLabel") .. ": ",
		weight_label = getText("IGUI_WeightScale_WeightLabel") .. ": ",
		weightChange_label = getText("IGUI_WeightScale_WeightChangeLabel") .. ": ",
		calories_label = getText("IGUI_WeightScale_CaloriesLabel") .. ": ",
		carbohydrates_label = getText("IGUI_WeightScale_CarbohydratesLabel") .. ": ",
		lipids_label = getText("IGUI_WeightScale_LipidsLabel") .. ": ",
		proteins_label = getText("IGUI_WeightScale_ProteinsLabel") .. ": ",
	};
	for labelID, labelText in pairs(labels) do
		self[labelID] = ISLabel:new(10, y, self.font_height_medium, labelText, 1, 1, 1, 1, UIFont.NewMedium, true);
		self[labelID]:initialise();
		self[labelID]:instantiate();
		self:addChild(self[labelID]);
		y = y + self.font_height_medium;
	end;
	self:setHeight(y + 20);
end

function WeightScale.WindowUI:new(playerObj, square)
	local o = ISCollapsableWindow:new(getCore():getScreenWidth() / 2 - 100 ,getCore():getScreenHeight() / 2 - 0, 320, 200);
	setmetatable(o, self)
	self.__index = self;
	o.playerObj = playerObj;
	o.square = square;
	o.nutritionObj = playerObj:getNutrition();
	o.descriptorObj = playerObj:getDescriptor();
	o.font_height_small = getTextManager():getFontHeight(UIFont.NewSmall);
	o.font_height_medium = getTextManager():getFontHeight(UIFont.NewMedium);
	o.showBackground = true;
	o.showBorder = true;
	o.backgroundColor = {r=0, g=0, b=0, a=1};
	o.moveWithMouse = true;
	o.anchorLeft = true;
	o.anchorRight = true;
	o.anchorTop = true;
	o.anchorBottom = true;

	if WeightScale.WindowUI.instance then
		WeightScale.WindowUI.instance:close();
	end
	WeightScale.WindowUI.instance = o;

	return o;
end
