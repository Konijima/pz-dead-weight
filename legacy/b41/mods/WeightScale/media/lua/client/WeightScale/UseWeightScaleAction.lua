WeightScale = WeightScale or {};

WeightScale.UseWeightScaleAction = ISBaseTimedAction:derive("WeightScale.UseWeightScaleAction");

function WeightScale.UseWeightScaleAction:isValid()
	return not self.character:isDead();
end

function WeightScale.UseWeightScaleAction:waitToStart()
	self.character:faceLocation(self.faceDir.x, self.faceDir.y);
	return self.character:shouldBeTurning();
end

function WeightScale.UseWeightScaleAction:start()
	
end

function WeightScale.UseWeightScaleAction:update()
	self.character:faceLocation(self.faceDir.x, self.faceDir.y);
end

function WeightScale.UseWeightScaleAction:stop()
    ISBaseTimedAction.stop(self);
end

function WeightScale.UseWeightScaleAction:perform()
	ISBaseTimedAction.perform(self);

	local weightScaleWindow = WeightScale.WindowUI:new(self.character, self.square);
	weightScaleWindow:initialise();
	weightScaleWindow:addToUIManager();
end

function WeightScale.UseWeightScaleAction:new(playerObj, square, facing)
	local o = {};
	setmetatable(o, self);
	self.__index = self;
	o.character = playerObj;
	o.stopOnWalk = true;
	o.stopOnRun = true;
	o.maxTime = 50;
	o.square = square;
	o.facing = facing;

	-- Adjust facing
	local x, y = square:getX(), square:getY();
	if facing == "E" then
		x = x - 1;
	elseif facing == "S" then
		y = y - 1;
	elseif facing == "W" then
		x = x + 1;
	elseif facing == "N" then
		y = y + 1;
	end
	o.faceDir = { x = x, y = y };

	return o;
end
