---@class Follower : Character
local Follower, super = HookSystem.hookScript(Follower)

function Follower:returnToFollowing(speed)
    if (not Pathfinder:getConfig("replace_return_to_following")) then
        super.returnToFollowing(self, speed)
        return
    end
    local tx, ty = self:getTargetPosition()
    local offset = { self:getTarget().x - tx, self:getTarget().y - ty }
    self.following = false
    self:pathfindChase(self:getTarget(), { refollow = true, once = true, after = function () self.following = true end, offset = function ()
        local tx, ty = self:getTargetPosition()
        return { tx - self:getTarget().x, ty - self:getTarget().y }
    end})
end

return Follower