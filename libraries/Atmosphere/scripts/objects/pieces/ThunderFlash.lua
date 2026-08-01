---@class ThunderFlash : Object
local ThunderFlash, super = Class(Object)

function ThunderFlash:init(handler)
    super.init(self)
    self.parallax_x, self.parallax_y = 0, 0
    self.handler = handler
    self.timer = 0
    self.duration = 0.35
    self:setLayer(((handler.addto == Game.battle) and BATTLE_LAYERS["below_ui"] or WORLD_LAYERS["below_ui"]) - 0.5)
end

function ThunderFlash:update()
    super.update(self)
    if self.handler.paused then return end
    self.timer = self.timer + DT
    if self.timer >= self.duration then self:remove() end
end

function ThunderFlash:draw()
    super.draw(self)
    local progress = self.timer / self.duration
    local pulse = (progress < 0.18) and (progress / 0.18) or (1 - progress) / 0.82
    love.graphics.setBlendMode("add")
    Draw.setColor(0.85, 0.9, 1, MathUtils.clamp(pulse, 0, 1) * 0.8)
    love.graphics.rectangle("fill", 0, 0, SCREEN_WIDTH, SCREEN_HEIGHT)
    love.graphics.setBlendMode("alpha")
    Draw.setColor(1, 1, 1, 1)
end

return ThunderFlash
