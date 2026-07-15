---@class Character : Object
---@field in_water boolean
local Character, super = HookSystem.hookScript(Character)

function Character:init(actor, x, y)
    super.init(self,actor,x,y)
    self.in_water = false
    self.water_depth = 0
end

function Character:getStepVolume()
    return math.min(Footsteps:getConfig("step_volume") * (1), Footsteps:getConfig("step_volume_max"))
end

function Character:onFootstep(num)
    super.onFootstep(self, num)
    if (Game:getFlag("audible_footsteps", false) and Game.world and Game.world.map) then
        local randpitch = MathUtils.random(-0.15, 0.15)
        num = MathUtils.wrap(num, 1, 3)
        local sound, pitch = Game.world:getStepSound(self.x, self.y, num, self.actor)
        if (self.in_water) then
            sound = "step/water_" .. ((self.water_depth < 3) and "shallow" or "deep") .. tostring(num)
        end
        Assets.stopAndPlaySound(sound, self:getStepVolume(), pitch or (1 + randpitch))
    end
    if self.in_water then
        --find a lake nearby (real)
        ---@type SmallLake
        local lake = Game.world.map:getEvent("smalllake")
        if lake then
            if (self.x <= (lake.x + lake.width/2)) and (self.x >= (lake.x - lake.width/2)) and (self.y <= (lake.y + lake.height/2)) and (self.y >= (lake.y - lake.height/2)) then
                local screenPosX, screenPosY = lake:screenToLocalPos(self:localToScreenPos(self.width/2, self.height - self.water_depth))
                lake:spawnSplash(screenPosX, screenPosY, 20, 1.5, 1.5)
                --Kristal.Console:log("splsih splash")
            end
        end
    end
end

return Character