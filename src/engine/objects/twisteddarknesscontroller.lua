---@class TwistedDarknessController : Object
local TwistedDarknessController, super = Class(Object)

-----@class Fume
-----@field x number X Position of this fume
-----@field y number Y Position of this fume
-----@field radius number
-----@field time number
-----@field rotation number
-----@field rotdir number
-----@field acceleration number
-----@field shrink boolean
-----@field tail boolean
-----@field disintegration number
-----@field halt_x number
-----@field halt_y number
-----@field halt_rotation number

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
    self.full_alpha = 1

    self.disintegrate_regions = {}

    self:addFX(ShaderFX('pixelize', {
        size = {SCREEN_WIDTH, SCREEN_HEIGHT},
        factor = 2
    }))

    for i = 1, 20 do
        table.insert(self.fumes,
            { (SCREEN_WIDTH/2)+40 + i * 25, 330, MathUtils.random(20, 40), self.timer + MathUtils.random(-30, 30), MathUtils.random(-1, 1), MathUtils.random(-1, 1, 1), 0, false, false, -1 })
    end

    for i = 1, 20 do
        table.insert(self.fumes,
            { (SCREEN_WIDTH/2)-5 + i * 25, -10, MathUtils.random(20, 40), self.timer +
            MathUtils.random(-30, 30), MathUtils.random(-1, 1), MathUtils.randomInt(-1, 1), 0, false, false, -1 })
    end

    -- for i = 1, 40 do
    --     table.insert(self.fumes,
    --         { -10, -5 + i * 25, MathUtils.random(20, 40), self.timer +
    --         MathUtils.random(-30, 30), MathUtils.random(-1, 1), MathUtils.random(-1, 1, 1), 0, false, false })
    -- end


    for i = 1, 30 do
        table.insert(self.fumes,
            { 650, -5 + i * 25, MathUtils.random(20, 40), self.timer +
            MathUtils.random(-30, 30), MathUtils.random(-1, 1), MathUtils.randomInt(-1, 1), 0, false, false, -1 })
    end

    for i = 1, 20 do
        table.insert(self.fumes,
            { 400, 330 + i * 25, MathUtils.random(20, 40), self.timer +
            MathUtils.random(-30, 30), MathUtils.random(-1, 1), MathUtils.randomInt(-1, 1), 0, false, false, -1 })
    end

    for i = 1, 15 do
        table.insert(self.fumes,
            { 385 + MathUtils.random(-5, 5), 340 + i * 25, MathUtils.random(20, 40), self.timer +
            MathUtils.random(-30, 30), MathUtils.random(-1, 1), MathUtils.randomInt(-1, 1), 0, false, false, -1 })
    end

    for i = 1, 10 do
        table.insert(self.fumes,
            { 365 + MathUtils.random(-5, 5), 365 + i * 25, MathUtils.random(20, 40), self.timer +
            MathUtils.random(-30, 30), MathUtils.random(-1, 1), MathUtils.randomInt(-1, 1), 0, false, false, -1 })
    end

    for i = 1, 5 do
        table.insert(self.fumes,
            { 345 + MathUtils.random(-5, 5), 388 + i * 25, MathUtils.random(20, 40), self.timer +
            MathUtils.random(-30, 30), MathUtils.random(-1, 1), MathUtils.randomInt(-1, 1), 0, false, false, -1 })
    end
    -- for i = 1, 8 do
    --     table.insert(self.fumes, {MathUtils.random(0, SCREEN_WIDTH), MathUtils.random(-30, SCREEN_HEIGHT + 30), MathUtils.random(20, 40), self.timer + MathUtils.random(-30, 30), MathUtils.random(-1, 1), MathUtils.random(-1, 1, 1), 0})
    -- end
end

---@return boolean
function TwistedDarknessController:isInDisintegrationRegion(x, y)
    for _, region in ipairs(self.disintegrate_regions) do
        local relative_pos = (region.getRelativePosFor and region.parent and {region:getRelativePosFor(self)}) or {region.x, region.y}
        local dist = MathUtils.dist(relative_pos[1], relative_pos[2], x, y)
        if (math.abs(dist) <= region.radius) then
            --Kristal.Console:log("disintegrating fume at " .. x .. ", " .. y)
            return true
        end
    end
    return false
end

function TwistedDarknessController:update()
    super.update(self)
    self.timer = self.timer + DTMULT
    self.spawn_timer = self.spawn_timer - DTMULT
    self.streak_timer = self.streak_timer - DTMULT
    self.full_alpha = MathUtils.approach(self.full_alpha, (Game.battle and StringUtils.contains(Game.battle.state, "DEFENDING")) and 0.25 or 1, DT * 4)
    if self.spawn_timer < 0 then
        self.spawn_timer = self.spawn_timer + MathUtils.random(5, self.spawn_speed)
        local height = MathUtils.random(0, SCREEN_HEIGHT)
        if (height > 330) then height = MathUtils.random(0, SCREEN_HEIGHT) end
        table.insert(self.fumes, {SCREEN_WIDTH + 30, height, MathUtils.random(20, 40), self.timer, MathUtils.random(-1, 1), MathUtils.randomInt(-1, 1), 0, true, true, -1})
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
        local x, y, radius, _, rotation = self:getFumeInformation(index)
        local disintegration = fume[10] or -1
        if self:isInDisintegrationRegion(x, y) and disintegration < 0 then
            disintegration = 0
            fume[11] = x
            fume[12] = y
            fume[13] = rotation
        end
        if disintegration >= 0 then
            disintegration = disintegration + 0.025 * DTMULT
            fume[10] = disintegration
        end
        if x < -(radius + 30) or radius < 0 or disintegration >= 1 then table.insert(to_remove, fume) end
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
    local x, y, radius, time, rotation, rotdir, acceleration, shrink, tail, disintegration, halt_x, halt_y, halt_rotation = TableUtils.unpack(self.fumes[index])
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
    if (disintegration and disintegration >= 0) then
        halt_x = halt_x or x
        halt_y = halt_y or y
        halt_rotation = halt_rotation or rotation

        local halt_amount = MathUtils.clamp(disintegration, 0, 1)
        halt_amount = 1 - ((1 - halt_amount) * (1 - halt_amount) * (1 - halt_amount))
        x = MathUtils.lerp(x, halt_x, halt_amount)
        y = MathUtils.lerp(y, halt_y, halt_amount)
        rotation = MathUtils.lerp(rotation, halt_rotation, halt_amount)
    end
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

function TwistedDarknessController:drawStreaks()
    Draw.setColor(0.2, 0, 0, math.min(Game.battle.transition_timer / 10, self.full_alpha))
    love.graphics.setLineWidth(2)

    for index, _ in ipairs(self.streaks) do
        local x, y, width = self:getStreakInformation(index)
        love.graphics.line(x-width*2, y, x, y)
    end

    Draw.setColor(1,1,1,1)
end

function TwistedDarknessController:drawFumePieces(x, y, radius, time, rotation, tail, red_alpha, black_alpha)
    Draw.setColor(1, 0, 0, red_alpha)
    if (self.tails and tail) then
        self:drawRotatedRectangle("line", x+(1.5 * radius), y-(math.sin(time / 4) * 8), radius/4, radius/4, rotation)
        self:drawRotatedRectangle("line", x+(1 * radius), y-(math.sin(time / 4) * 2), radius/2, radius/2, rotation)
    end
    self:drawRotatedRectangle("line", x, y, radius, radius, rotation)

    Draw.setColor(0, 0, 0, black_alpha)
    if (self.tails and tail) then
        self:drawRotatedRectangle("fill", x+(1.5 * radius), y-(math.sin(time / 4) * 8), (radius/4)-2, (radius/4)-2, rotation)
        self:drawRotatedRectangle("fill", x+(1 * radius), y-(math.sin(time / 4) * 2), (radius/2)-2, (radius/2)-2, rotation)
    end
    self:drawRotatedRectangle("fill", x, y, radius-2, radius-2, rotation)
end

function TwistedDarknessController:drawDissolvingFume(x, y, radius, time, rotation, tail, disintegration)
    local size = math.ceil((radius * 4) + 16)
    local center = (size / 2) - (radius * 0.5)
    local canvas = Draw.pushCanvas(size, size)

    self:drawFumePieces(
        center,
        center,
        radius,
        time,
        rotation,
        tail,
        math.min(Game.battle.transition_timer / 10, self.full_alpha),
        Game.battle.transition_timer / 10
    )

    Draw.popCanvas(true)

    local shader = Assets.getShader("dissolve")
    local last_shader = love.graphics.getShader()

    shader:send("texsize", {size, size})
    local dissolve_progress = math.sqrt(MathUtils.clamp(disintegration, 0, 1))
    shader:send("dissolve_value", 1 - dissolve_progress)
    shader:send("dissolve_mix", 0.38)
    shader:send("dissolve_noise_scale", 3.0)
    shader:send("dissolve_origin", {0, 0})
    shader:send("dissolve_size", {size, size})
    shader:send("dissolve_gradient", Assets.getTexture("misc/bwgradient"))

    love.graphics.setShader(shader)
    Draw.setColor(1, 1, 1, 1)
    Draw.drawCanvas(canvas, x - center, y - center)
    love.graphics.setShader(last_shader)
    Draw.unlockCanvas(canvas)
end

function TwistedDarknessController:drawFumes()
    local iterated = {}
    local red_alpha = math.min(Game.battle.transition_timer / 10, self.full_alpha)
    local black_alpha = Game.battle.transition_timer / 10
    Draw.setColor(1,0,0, red_alpha)

    for index, _ in ipairs(self.fumes) do
        local x, y, radius, time, rotation, tail = self:getFumeInformation(index)
        local disintegration = self.fumes[index][10] or -1
        if disintegration >= 0 then
            self:drawDissolvingFume(x, y, radius, time, rotation, tail, disintegration)
        else
        --tails
            Draw.setColor(1,0,0, red_alpha)
            table.insert(iterated, {x, y, radius, time, rotation, tail})
            if (self.tails and tail) then
                self:drawRotatedRectangle("line", x+(1.5 * radius), y-(math.sin(time / 4) * 8), radius/4, radius/4, rotation)
                self:drawRotatedRectangle("line", x+(1 * radius), y-(math.sin(time / 4) * 2), radius/2, radius/2, rotation)
            end
            self:drawRotatedRectangle("line", x, y, radius, radius, rotation)
        end
    end

    Draw.setColor(0,0,0, black_alpha)
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

function TwistedDarknessController:draw()
    self:drawStreaks()

    super.draw(self)

    self:drawFumes()
end

return TwistedDarknessController
