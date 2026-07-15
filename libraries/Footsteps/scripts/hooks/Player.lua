---@class Player
local Player, super = HookSystem.hookScript(Player)

function Player:getStepVolume()
    return math.min(Footsteps:getConfig("step_volume") * (self:getCurrentSpeed(self.state == "RUN") / 4), Footsteps:getConfig("step_volume_max"))
end

return Player