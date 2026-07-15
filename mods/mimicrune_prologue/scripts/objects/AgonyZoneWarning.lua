local AgonyZoneWarning, super = Class(Object)

function AgonyZoneWarning:init(x, y, width, height, duration)
    super.init(self, x, y)

    self.width = width
    self.height = height
    self.duration = duration or 0.65
    self.age = 0
    self.layer = BATTLE_LAYERS["below_soul"]
end

function AgonyZoneWarning:update()
    self.age = self.age + DT
    if self.age >= self.duration then
        self:remove()
        return
    end
    super.update(self)
end

function AgonyZoneWarning:draw()
    super.draw(self)

    local progress = MathUtils.clamp(self.age / self.duration, 0, 1)
    local pulse = 0.45 + math.abs(math.sin(self.age * 34)) * 0.35
    local alpha = pulse * (0.55 + progress * 0.45)
    local left = -self.width / 2
    local top = -self.height / 2

    Draw.setColor(1, 0, 0, alpha * 0.16)
    love.graphics.rectangle("fill", left, top, self.width, self.height)

    Draw.setColor(1, 0, 0, alpha)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", left, top, self.width, self.height)

    love.graphics.setLineWidth(1)
    for y = top + 4, top + self.height - 2, 7 do
        love.graphics.line(left + 2, y, left + self.width - 2, y)
    end

    Draw.setColor(1, 1, 1, 1)
end

return AgonyZoneWarning
