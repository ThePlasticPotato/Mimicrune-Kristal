local TitanDarknessController, super = Class(Object)

function TitanDarknessController:init(layer, shrink)
    super.init(self, 0, 0, SCREEN_WIDTH, SCREEN_HEIGHT)
    self:setPosition(0, 0)
    self:setLayer(layer or WORLD_LAYERS["bottom"])
    self.timer = 0
    self.shrink = shrink or false
    self.spawn_speed = 30
    self.spawn_timer = self.spawn_speed
    self.fumes = {}
    self:addFX(ShaderFX('pixelize', {
        size = {SCREEN_WIDTH, SCREEN_HEIGHT},
        factor = 2
    }))
    for i = 1, 8 do
        table.insert(self.fumes, {Utils.random(0, SCREEN_WIDTH), Utils.random(-30, SCREEN_HEIGHT + 30), Utils.random(20, 40), self.timer + Utils.random(-30, 30)})
    end
end

function TitanDarknessController:update()
    super.update(self)
    self:setLayer(WORLD_LAYERS["bottom"])
    self.timer = self.timer + DTMULT
    self.spawn_timer = self.spawn_timer - DTMULT
    if self.spawn_timer < 0 then
        self.spawn_timer = self.spawn_timer + self.spawn_speed
        table.insert(self.fumes, {Utils.random(0, SCREEN_WIDTH), SCREEN_HEIGHT + 30, Utils.random(20, 40), self.timer})
    end

    local to_remove = {}
    for index, fume in ipairs(self.fumes) do
        local x, y, radius = self:getFumeInformation(index)
        if y < -(radius + 30) or radius < 0 then table.insert(to_remove, fume) end
    end

    for _, fume in ipairs(to_remove) do
        Utils.removeFromTable(self.fumes, fume)
    end
end

function TitanDarknessController:getFumeInformation(index)
    local x, y, radius, time = Utils.unpack(self.fumes[index])
    time = self.timer - time
    x = x + math.sin(time / 4) * 4
    y = y - time * 1.9
    if (self.shrink) then radius = radius - time * 0.1 end
    return x, y, radius, time
end
function TitanDarknessController:draw()
    super.draw(self)

    Draw.setColor(0.2, 0.2, 0.2)
    for index, _ in ipairs(self.fumes) do
        local x, y, radius = self:getFumeInformation(index)
        love.graphics.setLineWidth(4)
        love.graphics.circle("line", x, y, radius)
    end

    Draw.setColor(COLORS.black)
    for index, _ in ipairs(self.fumes) do
        local x, y, radius = self:getFumeInformation(index)
        love.graphics.circle("fill", x, y, radius - 2)
    end
end

return TitanDarknessController