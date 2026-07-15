local AgonyUndertowBlob, super = Class("agonyblob")

function AgonyUndertowBlob:init(x, y, direction, speed, exit_x)
    super.init(self, x, y, direction, speed)

    self.exit_x = exit_x
    self.travel_sign = math.cos(direction) >= 0 and 1 or -1
    self.spawn_x = x
    self.spawn_y = y
    self.flight_age = 0
    self.target_speed = speed
    self.physics.speed = 0
    self.launched = false
    self.spawn_progress = 0
    self.spawn_duration = 7
    self.dissolve_progress = nil
    self.dissolve_duration = 12
    self.exit_smear_length = nil

    self:setScale(1)
    self.destroy_on_hit = false
    self.remove_offscreen = false
    self.collidable = false

    local travel_width = speed + 7
    local collider_x = self.travel_sign > 0 and -speed or -7
    self.collider = Hitbox(self, collider_x, -3, travel_width, 6)
end

function AgonyUndertowBlob:hasReachedExit()
    if self.travel_sign > 0 then
        return self.x >= self.exit_x
    end
    return self.x <= self.exit_x
end

function AgonyUndertowBlob:beginDissolve()
    if self.dissolve_progress then return end

    self.dissolve_progress = 0
    self.exit_smear_length = math.max(
        48,
        MathUtils.dist(self.spawn_x, self.spawn_y, self.x, self.y) + 22
    )
    self.collidable = false
    self.can_graze = false
end

function AgonyUndertowBlob:update()
    self.flight_age = self.flight_age + DTMULT

    if not self.launched then
        self.spawn_progress = math.min(1, self.spawn_progress + DTMULT / self.spawn_duration)
        if self.spawn_progress >= 1 then
            self.launched = true
            self.physics.speed = self.target_speed
            self.collidable = true
        end
    end

    super.update(self)

    if self.launched and not self.dissolve_progress and self:hasReachedExit() then
        self:beginDissolve()
    end

    if self.dissolve_progress then
        self.dissolve_progress = self.dissolve_progress + DTMULT / self.dissolve_duration
        if self.dissolve_progress >= 1 then
            self:remove()
        end
    end
end

function AgonyUndertowBlob:getSmearLength()
    if self.exit_smear_length then
        return self.exit_smear_length
    end
    return math.max(
        8,
        MathUtils.dist(self.spawn_x, self.spawn_y, self.x, self.y) + 14
    )
end

function AgonyUndertowBlob:drawWindup()
    local progress = self.spawn_progress
    local pulse = math.sin(progress * math.pi * 7)
    local reach = 5 + progress * 27
    local height = 2 + progress * 9 + math.abs(pulse) * 4
    local jitter = math.sin(progress * math.pi * 17 + self.spawn_y) * (1 - progress) * 5

    Draw.setColor(1, 0, 0, 0.55 + progress * 0.45)
    love.graphics.setLineWidth(2)
    love.graphics.polygon(
        "line",
        -9, jitter,
        reach * 0.32, -height,
        reach, 0,
        reach * 0.32, height
    )
    love.graphics.line(-13 - progress * 8, jitter, reach + 5, jitter)

    Draw.setColor(0, 0, 0, 0.9)
    love.graphics.polygon(
        "fill",
        -6, jitter,
        reach * 0.3, -math.max(1, height - 3),
        reach - 4, 0,
        reach * 0.3, math.max(1, height - 3)
    )
end

function AgonyUndertowBlob:getRibbonPoints(smear_length, inset, dissolve)
    local points = {}
    local sections = math.max(5, math.ceil(smear_length / 24))

    for index = 0, sections do
        local progress = index / sections
        local x = -smear_length + smear_length * progress
        local taper = MathUtils.lerp(1.4, 6.5, progress)
        local ragged = math.sin(index * 4.17 + self.spawn_y * 0.19) * 1.5
        local tear = math.sin(index * 8.31 + self.flight_age * 0.22) * dissolve * 7
        table.insert(points, x - dissolve * (index % 3) * 3)
        table.insert(points, -math.max(0.5, taper + ragged - inset) + tear)
    end

    for index = sections, 0, -1 do
        local progress = index / sections
        local x = -smear_length + smear_length * progress
        local taper = MathUtils.lerp(1.4, 6.5, progress)
        local ragged = math.cos(index * 3.71 + self.spawn_y * 0.13) * 1.5
        local tear = math.cos(index * 7.47 + self.flight_age * 0.19) * dissolve * 7
        table.insert(points, x - dissolve * ((index + 1) % 3) * 3)
        table.insert(points, math.max(0.5, taper + ragged - inset) + tear)
    end

    return points
end

function AgonyUndertowBlob:draw()

    love.graphics.push()
    love.graphics.rotate(self.physics.direction)

    if not self.launched then
        self:drawWindup()
        love.graphics.pop()
        Draw.setColor(1, 1, 1, 1)
        return
    end

    local smear_length = self:getSmearLength()
    local dissolve = self.dissolve_progress or 0

    love.graphics.setLineWidth(2)
    Draw.setColor(1, 0, 0, 1 - dissolve)
    love.graphics.polygon("line", self:getRibbonPoints(smear_length, 0, dissolve))
    Draw.setColor(0, 0, 0, 1 - dissolve)
    love.graphics.polygon("fill", self:getRibbonPoints(smear_length, 2.2, dissolve))

    Draw.setColor(1, 0, 0, (1 - dissolve) * 0.7)
    love.graphics.line(-smear_length * 0.92, -1, -5, -1)

    Draw.setColor(1, 0, 0, 1 - dissolve)
    love.graphics.rectangle("line", -6, -6, 12, 12)
    Draw.setColor(0, 0, 0, 1 - dissolve)
    love.graphics.rectangle("fill", -4, -4, 8, 8)

    love.graphics.pop()
    Draw.setColor(1, 1, 1, 1)
end

return AgonyUndertowBlob
