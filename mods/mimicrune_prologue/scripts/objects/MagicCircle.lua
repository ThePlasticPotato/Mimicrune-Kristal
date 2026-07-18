---@class MagicCircle : Object
---@overload fun(x?: number, y?: number, color?: table) : MagicCircle
local MagicCircle, super = Class(Object)

function MagicCircle:init(x, y, color)
    super.init(self, 0, 0, SCREEN_WIDTH, SCREEN_HEIGHT)

    self.parallax_x = 0
    self.parallax_y = 0
    self.debug_select = false

    self.center_x = x or SCREEN_WIDTH / 2
    self.center_y = y or SCREEN_HEIGHT / 2
    self.circle_color = color or {1, 1, 1, 1}
    self.progress = 0
    self.intensity = 0
    self.radius = 170
    self.shader_rotation = 0
    self.rotation_speed = 0.22

    self.follow_target = nil
    self.follow_local_x = 0
    self.follow_local_y = 0
    self.shader = Assets.newShader("magic_circle")
end

function MagicCircle:setCenter(x, y)
    self.center_x = x or self.center_x
    self.center_y = y or self.center_y
end

function MagicCircle:setFollowTarget(target, local_x, local_y)
    self.follow_target = target
    self.follow_local_x = local_x or 0
    self.follow_local_y = local_y or 0
end

function MagicCircle:getCenter()
    if self.follow_target and not self.follow_target:isRemoved() then
        local local_x = type(self.follow_local_x) == "function"
            and self.follow_local_x(self.follow_target) or self.follow_local_x
        local local_y = type(self.follow_local_y) == "function"
            and self.follow_local_y(self.follow_target) or self.follow_local_y
        return self.follow_target:localToScreenPos(local_x, local_y)
    end
    return self.center_x, self.center_y
end

function MagicCircle:update()
    super.update(self)
    self.shader_rotation = self.shader_rotation + DT * self.rotation_speed
end

function MagicCircle:draw()
    if self.progress <= 0 or self.intensity <= 0 or self.alpha <= 0 then return end

    local center_x, center_y = self:getCenter()
    self.shader:send("center", {center_x, center_y})
    self.shader:send("circleColor", {
        self.circle_color[1],
        self.circle_color[2],
        self.circle_color[3]
    })
    self.shader:send("progress", self.progress)
    self.shader:send("intensity", self.intensity)
    self.shader:send("circleRadius", self.radius)
    self.shader:send("rotation", self.shader_rotation)

    love.graphics.push("all")
    love.graphics.origin()
    love.graphics.setBlendMode("add")
    love.graphics.setShader(self.shader)
    Draw.setColor(1, 1, 1, self.alpha * (self.circle_color[4] or 1))
    love.graphics.rectangle("fill", 0, 0, SCREEN_WIDTH, SCREEN_HEIGHT)
    love.graphics.pop()
end

return MagicCircle
