---@class Follower
local Follower, super = HookSystem.hookScript(Follower)

function Follower:getStepVolume()
    local walk_speed = self.target and self.target.getCurrentSpeed and self.target:getCurrentSpeed(self.target.state == "RUN") or 4
    if (Footsteps:getConfig("half_volume_followers")) then
        return math.min(Footsteps:getConfig("step_volume") * (walk_speed / 4), Footsteps:getConfig("step_volume_max")) / 2
    end
    return math.min(Footsteps:getConfig("step_volume") * (walk_speed / 4), Footsteps:getConfig("step_volume_max"))
end

return Follower