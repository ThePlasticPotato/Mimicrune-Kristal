---@class Actor : Class
local Actor, super = HookSystem.hookScript(Actor)

function Actor:getPathfindingHitbox()
    if self.hitbox then
        local x, y, w, h = unpack(self.hitbox)
        return (x or 0) - 2, (y or 0) -2, (w or self:getWidth()) + 2, (h or self:getHeight()) + 2
    else
        return -2, -2, self:getWidth()+2, self:getHeight()+2
    end
end

return Actor