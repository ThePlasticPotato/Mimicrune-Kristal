local AgonyMarker, super = Class(Object)

function AgonyMarker:init(x, y, direction)
    super.init(self, x, y)
    self.layer = BATTLE_LAYERS["below_bullets"]
    self.age = 0
    self.duration = 46
    self.direction = direction
end

function AgonyMarker:update()
    self.age = self.age + DTMULT
    if self.age >= self.duration then
        self:remove()
        return
    end
    super.update(self)
end

function AgonyMarker:draw()
    super.draw(self)

    local progress = MathUtils.clamp(self.age / self.duration, 0, 1)
    local pulse = 0.58 + math.abs(math.sin(self.age / 2.5)) * 0.3
    local alpha = ((1 - progress) ^ 0.35) * pulse
    local outer_size = MathUtils.lerp(52, 14, progress)

    Draw.setColor(1, 0, 0, alpha)
    love.graphics.setLineWidth(2)
    love.graphics.push()
    love.graphics.rotate((self.age / 20) * self.direction)
    love.graphics.rectangle("line", -outer_size / 2, -outer_size / 2, outer_size, outer_size)
    love.graphics.pop()
    love.graphics.line(-8, 0, 8, 0)
    love.graphics.line(0, -8, 0, 8)
    Draw.setColor(1, 1, 1, 1)
end

return AgonyMarker
