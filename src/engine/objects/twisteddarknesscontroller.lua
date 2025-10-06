local TwistedDarknessController, super = Class(Object)

function TwistedDarknessController:init(layer, shrink, tails)
    super.init(self, 0, 0, SCREEN_WIDTH, SCREEN_HEIGHT)
    self:setPosition(0, 0)
    self:setLayer(layer or WORLD_LAYERS["bottom"])
    self.timer = 0
    self.tails = tails
    self.shrink = shrink or false
    self.spawn_speed = 30
    self.spawn_timer = self.spawn_speed
    self.streak_timer = self.spawn_speed / 4
    self.fumes = {}
    self.streaks = {}
    self:addFX(ShaderFX('pixelize', {
        size = {SCREEN_WIDTH, SCREEN_HEIGHT},
        factor = 2
    }))

    for i = 1, 20 do
        table.insert(self.fumes,
            { (SCREEN_WIDTH/2)+40 + i * 25, 330, MathUtils.random(20, 40), self.timer + MathUtils.random(-30, 30), MathUtils.random(-1, 1), MathUtils.random(-1, 1, 1), 0, false, false })
    end

    for i = 1, 20 do
        table.insert(self.fumes,
            { (SCREEN_WIDTH/2)-5 + i * 25, -10, MathUtils.random(20, 40), self.timer +
            MathUtils.random(-30, 30), MathUtils.random(-1, 1), MathUtils.random(-1, 1, 1), 0, false, false })
    end

    -- for i = 1, 40 do
    --     table.insert(self.fumes,
    --         { -10, -5 + i * 25, MathUtils.random(20, 40), self.timer +
    --         MathUtils.random(-30, 30), MathUtils.random(-1, 1), MathUtils.random(-1, 1, 1), 0, false, false })
    -- end


    for i = 1, 30 do
        table.insert(self.fumes,
            { 650, -5 + i * 25, MathUtils.random(20, 40), self.timer +
            MathUtils.random(-30, 30), MathUtils.random(-1, 1), MathUtils.random(-1, 1, 1), 0, false, false })
    end

    for i = 1, 20 do
        table.insert(self.fumes,
            { 400, 330 + i * 25, MathUtils.random(20, 40), self.timer +
            MathUtils.random(-30, 30), MathUtils.random(-1, 1), MathUtils.random(-1, 1, 1), 0, false, false })
    end

    for i = 1, 15 do
        table.insert(self.fumes,
            { 385 + MathUtils.random(-5, 5), 340 + i * 25, MathUtils.random(20, 40), self.timer +
            MathUtils.random(-30, 30), MathUtils.random(-1, 1), MathUtils.random(-1, 1, 1), 0, false, false })
    end

    for i = 1, 10 do
        table.insert(self.fumes,
            { 365 + MathUtils.random(-5, 5), 365 + i * 25, MathUtils.random(20, 40), self.timer +
            MathUtils.random(-30, 30), MathUtils.random(-1, 1), MathUtils.random(-1, 1, 1), 0, false, false })
    end

    for i = 1, 5 do
        table.insert(self.fumes,
            { 345 + MathUtils.random(-5, 5), 388 + i * 25, MathUtils.random(20, 40), self.timer +
            MathUtils.random(-30, 30), MathUtils.random(-1, 1), MathUtils.random(-1, 1, 1), 0, false, false })
    end
    -- for i = 1, 8 do
    --     table.insert(self.fumes, {MathUtils.random(0, SCREEN_WIDTH), MathUtils.random(-30, SCREEN_HEIGHT + 30), MathUtils.random(20, 40), self.timer + MathUtils.random(-30, 30), MathUtils.random(-1, 1), MathUtils.random(-1, 1, 1), 0})
    -- end
end

function TwistedDarknessController:update()
    super.update(self)
    self:setLayer(BATTLE_LAYERS["bottom"])
    self.timer = self.timer + DTMULT
    self.spawn_timer = self.spawn_timer - DTMULT
    self.streak_timer = self.streak_timer - DTMULT
    if self.spawn_timer < 0 then
        self.spawn_timer = self.spawn_timer + MathUtils.random(5, self.spawn_speed)
        local height = MathUtils.random(0, SCREEN_HEIGHT)
        if (height > 330) then height = MathUtils.random(0, SCREEN_HEIGHT) end
        table.insert(self.fumes, {SCREEN_WIDTH + 30, height, MathUtils.random(20, 40), self.timer, MathUtils.random(-1, 1), MathUtils.random(-1, 1, 1), 0, true, true})
    end
    if (self.streak_timer < 0) then
        self.streak_timer = self.streak_timer + MathUtils.random(1, (self.spawn_speed / 4))
        local height = MathUtils.random(0, SCREEN_HEIGHT)
        if (height > 330) then height = MathUtils.random(0, SCREEN_HEIGHT) end
        table.insert(self.streaks, {SCREEN_WIDTH + 30 + MathUtils.random(0, 30), height, MathUtils.random(20, 40), 0, self.timer})
    end

    local to_remove = {}
    local to_remove_streaks = {}
    for index, fume in ipairs(self.fumes) do
        local x, y, radius = self:getFumeInformation(index)
        if x < -(radius + 30) or radius < 0 then table.insert(to_remove, fume) end
    end

    for index,streak in ipairs(self.streaks) do
        local x, y, width = self:getStreakInformation(index)
        if x < -(width + 30) then table.insert(to_remove_streaks, streak) end
    end

    for _, fume in ipairs(to_remove) do
        TableUtils.removeValue(self.fumes, fume)
    end
    for _, streak in ipairs(to_remove_streaks) do
        TableUtils.removeValue(self.streaks, streak)
    end
end

function TwistedDarknessController:getFumeInformation(index)
    local x, y, radius, time, rotation, rotdir, acceleration, shrink, tail = TableUtils.unpack(self.fumes[index])
    time = self.timer - time
    if (rotdir == 0) then rotdir = 1 end
    if (shrink) then 
        acceleration = acceleration + (time / 8)
        x = x - time * (4.9 + acceleration)
        y = y + math.sin(time / 4) * 8
    else
        y = y + math.sin(time/4) * 8
    end
    rotation = rotation + ((time / 4) * rotdir)
    if (self.shrink and shrink) then radius = radius - time * 0.25 end
    return x, y, radius, time, rotation, tail
end

function TwistedDarknessController:getStreakInformation(index)
    local x, y, width, speed, time = TableUtils.unpack(self.streaks[index])

    time = self.timer - time
    speed = speed + (time / 4)
    x = x - time * (12 + speed)
    width = width + (time)
    return x, y, width, speed, time
end

function TwistedDarknessController:drawRotatedRectangle(mode, x, y, width, height, angle)
	-- We cannot rotate the rectangle directly, but we
	-- can move and rotate the coordinate system.
	love.graphics.push()
	love.graphics.translate(x, y)
	love.graphics.rotate(angle)
    love.graphics.setLineWidth(4)
	love.graphics.rectangle(mode, -width/2, -height/2, width, height) -- origin in the middle
	love.graphics.pop()
end

function TwistedDarknessController:draw()
    local iterated = {}

    Draw.setColor(0.2, 0, 0, Game.battle.transition_timer / 10)
    love.graphics.setLineWidth(2)

    for index, _ in ipairs(self.streaks) do
        local x, y, width = self:getStreakInformation(index)
        love.graphics.line(x-width*2, y, x, y)
    end

    Draw.setColor(1,1,1,1)

    super.draw(self)

    Draw.setColor(1,0,0,Game.battle.transition_timer / 10)

    for index, _ in ipairs(self.fumes) do
        local x, y, radius, time, rotation, tail = self:getFumeInformation(index)
        --tails
        table.insert(iterated, {x, y, radius, time, rotation})
        if (self.tails and tail) then
            self:drawRotatedRectangle("line", x+(1.5 * radius), y-(math.sin(time / 4) * 8), radius/4, radius/4, rotation)
            self:drawRotatedRectangle("line", x+(1 * radius), y-(math.sin(time / 4) * 2), radius/2, radius/2, rotation)
        end
        self:drawRotatedRectangle("line", x, y, radius, radius, rotation)
        
    end

    Draw.setColor(0,0,0,Game.battle.transition_timer / 10)
    for index, value in ipairs(iterated) do
        local x, y, radius, time, rotation, tail = TableUtils.unpack(value)
        if (self.tails and tail) then
            self:drawRotatedRectangle("fill", x+(1.5 * radius), y-(math.sin(time / 4) * 8), (radius/4)-2, (radius/4)-2, rotation)
            self:drawRotatedRectangle("fill", x+(1 * radius), y-(math.sin(time / 4) * 2), (radius/2)-2, (radius/2)-2, rotation)
        end
        self:drawRotatedRectangle("fill", x, y, radius-2, radius-2, rotation)
    end

    love.graphics.rectangle("fill", 400, 330, SCREEN_WIDTH, SCREEN_HEIGHT)

    Draw.setColor(1,1,1,1)
end

return TwistedDarknessController