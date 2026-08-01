---@class AshParticle : Object
local AshParticle, super = Class(Object)

function AshParticle:init(sprite, x, y, speed, handler)
    super.init(self, x, y)
    self.handler = handler
    self.speed = speed
    self.phase = MathUtils.random(0, math.pi * 2)
    self.ash = Sprite("world/dust/" .. sprite)
    self.ash:setOrigin(0.5, 0.5)
    self:setLayer(((handler.addto == Game.battle) and BATTLE_LAYERS["below_ui"] or WORLD_LAYERS["below_ui"]) - 1)
    handler:configureHeightPiece(
        self, MathUtils.random(12, SCREEN_HEIGHT * 0.75), true)
end

function AshParticle:update()
    super.update(self)
    if self.handler.paused then return end
    self.x = self.x - self.speed * DTMULT
    self.y = self.y + math.sin(Kristal.getTime() * 4 + self.phase) * 0.9 * DTMULT
    self.rotation = self.rotation + DT * 1.5
    local screen_x = self:localToScreenPos(0, 0)
    if screen_x < -40 then self:remove() end
end

function AshParticle:draw()
    super.draw(self)
    love.graphics.setBlendMode("add")
    self.ash:drawAlpha(0.7)
    love.graphics.setBlendMode("alpha")
end

return AshParticle
