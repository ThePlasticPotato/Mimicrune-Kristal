---@class TenseIntroDarknessController : Object
local TenseIntroDarknessController, super = Class(Object)

function TenseIntroDarknessController:init(target)
    super.init(self, 0, 0, SCREEN_WIDTH, SCREEN_HEIGHT)

    self.target = target
    self.timer = 0
    self.fumes = {}
    self.rim_fumes = {}
    self.banishing = false
    self.banish_timer = 0
    self.remove_timer = 0
    self.full_alpha = 0
    self.border_fume_count = 72
    self.loose_fume_count = 36
    self.rim_fume_count = 64
    self.mass_start_radius = 420
    self.mass_settle_radius = 230
    self.mass_squeeze_radius = 150
    self.mass_radius = self.mass_start_radius

    self:addFX(ShaderFX('pixelize', {
        size = {SCREEN_WIDTH, SCREEN_HEIGHT},
        factor = 2
    }))

    for i = 1, self.rim_fume_count do
        self:addRimFume(i)
    end

    for i = 1, self.border_fume_count do
        self:addBorderFume(i)
    end

    for i = 1, self.loose_fume_count do
        self:addLooseFume(i)
    end
end

function TenseIntroDarknessController:addRimFume(index)
    local angle = ((index - 1) / self.rim_fume_count) * math.pi * 2
    local target_x, target_y = self:getTargetPosition()

    table.insert(self.rim_fumes, {
        angle = angle,
        radius = MathUtils.random(30, 54),
        phase = MathUtils.random(0, math.pi * 2),
        rotation = MathUtils.random(-1, 1),
        rotdir = MathUtils.randomInt(0, 1) == 0 and -1 or 1,
        spin = MathUtils.random(-0.006, 0.006),
        x = target_x + math.cos(angle) * self.mass_radius,
        y = target_y + math.sin(angle) * self.mass_radius
    })
end

function TenseIntroDarknessController:addFume(angle, start_distance, target_distance, radius, spin, delay)
    local x, y = self:getTargetPosition()

    table.insert(self.fumes, {
        angle = angle,
        distance = start_distance,
        start_distance = start_distance,
        target_distance = target_distance,
        radius = radius,
        start_radius = radius,
        spin = spin,
        phase = MathUtils.random(0, math.pi * 2),
        rotation = MathUtils.random(-1, 1),
        rotdir = MathUtils.randomInt(0, 1) == 0 and -1 or 1,
        delay = delay,
        disintegration = -1,
        x = x + math.cos(angle) * start_distance,
        y = y + math.sin(angle) * start_distance
    })
end

function TenseIntroDarknessController:addBorderFume(index)
    local perimeter = (SCREEN_WIDTH + SCREEN_HEIGHT) * 2
    local pos = ((index - 1) / self.border_fume_count) * perimeter
    local x, y

    if pos < SCREEN_WIDTH then
        x = pos
        y = -54
    elseif pos < SCREEN_WIDTH + SCREEN_HEIGHT then
        x = SCREEN_WIDTH + 54
        y = pos - SCREEN_WIDTH
    elseif pos < (SCREEN_WIDTH * 2) + SCREEN_HEIGHT then
        x = SCREEN_WIDTH - (pos - SCREEN_WIDTH - SCREEN_HEIGHT)
        y = SCREEN_HEIGHT + 54
    else
        x = -54
        y = SCREEN_HEIGHT - (pos - (SCREEN_WIDTH * 2) - SCREEN_HEIGHT)
    end

    local target_x, target_y = self:getTargetPosition()
    local angle = MathUtils.angle(target_x, target_y, x + MathUtils.random(-20, 20), y + MathUtils.random(-20, 20))
    local start_distance = MathUtils.dist(target_x, target_y, x, y)
    local spin_dir = index % 2 == 0 and 1 or -1

    self:addFume(
        angle,
        start_distance,
        MathUtils.random(115, 175),
        MathUtils.random(34, 58),
        MathUtils.random(0.003, 0.008) * spin_dir,
        MathUtils.random(0, 24)
    )
end

function TenseIntroDarknessController:addLooseFume(index)
    local angle = ((index / self.loose_fume_count) * math.pi * 2) + MathUtils.random(-0.28, 0.28)
    local spin_dir = index % 2 == 0 and 1 or -1

    self:addFume(
        angle,
        MathUtils.random(300, 450),
        MathUtils.random(66, 120),
        MathUtils.random(18, 38),
        MathUtils.random(0.007, 0.016) * spin_dir,
        MathUtils.random(8, 58)
    )
end

function TenseIntroDarknessController:getTargetPosition()
    if self.target and self.target.parent and self.parent and self.target.getRelativePosFor then
        return self.target:getRelativePosFor(self)
    elseif self.target then
        return self.target.x, self.target.y
    end
    return SCREEN_WIDTH / 2, SCREEN_HEIGHT / 2
end

function TenseIntroDarknessController:banish()
    if self.banishing then
        return
    end

    self.banishing = true
    self.banish_timer = 0

    for _, fume in ipairs(self.fumes) do
        fume.banish_start_distance = fume.distance
        fume.banish_start_angle = fume.angle
        fume.banish_start_radius = fume.radius
        fume.dissolve_x = fume.x
        fume.dissolve_y = fume.y
        fume.dissolve_rotation = fume.rotation
        fume.disintegration = 0
    end

    for _, fume in ipairs(self.rim_fumes) do
        fume.dissolve_x = fume.x
        fume.dissolve_y = fume.y
        fume.dissolve_rotation = fume.rotation
        fume.disintegration = 0
    end
end

function TenseIntroDarknessController:update()
    super.update(self)

    self.timer = self.timer + DTMULT
    self.full_alpha = MathUtils.approach(self.full_alpha, 1, 0.06 * DTMULT)

    if self.banishing then
        self.banish_timer = MathUtils.approach(self.banish_timer, 1, 0.035 * DTMULT)
        self.remove_timer = self.remove_timer + DTMULT
    end

    local settle_amount = MathUtils.clamp(self.timer / 120, 0, 1)
    settle_amount = 1 - ((1 - settle_amount) * (1 - settle_amount) * (1 - settle_amount))
    local squeeze_amount = MathUtils.clamp((self.timer - 135) / 45, 0, 1)
    squeeze_amount = squeeze_amount * squeeze_amount
    local target_mass_radius = MathUtils.lerp(self.mass_start_radius, self.mass_settle_radius, settle_amount)

    if not self.banishing then
        target_mass_radius = MathUtils.lerp(target_mass_radius, self.mass_squeeze_radius, squeeze_amount)
    end

    if self.banishing then
        self.mass_radius = MathUtils.approach(self.mass_radius, self.mass_radius + 18, 0.5 * DTMULT)
    else
        self.mass_radius = MathUtils.approach(self.mass_radius, target_mass_radius, 2.5 * DTMULT)
    end

    for _, fume in ipairs(self.fumes) do
        local active_amount = MathUtils.clamp((self.timer - fume.delay) / 90, 0, 1)
        active_amount = active_amount * active_amount
        local wobble = math.sin((self.timer / 8) + fume.phase) * 12

        if self.banishing then
            fume.disintegration = MathUtils.approach(fume.disintegration, 1, 0.018 * DTMULT)
            fume.distance = MathUtils.approach(fume.distance, fume.banish_start_distance + 28, 0.75 * DTMULT)
            fume.angle = fume.banish_start_angle + (fume.spin * self.banish_timer * 18)
            fume.radius = fume.banish_start_radius
        else
            local closing_distance = MathUtils.lerp(fume.target_distance, fume.target_distance * 0.55, squeeze_amount)
            local target_distance = MathUtils.lerp(fume.start_distance, closing_distance, active_amount)
            fume.distance = MathUtils.approach(fume.distance, target_distance, (1.5 + active_amount * 5) * DTMULT)
            fume.angle = fume.angle + fume.spin * DTMULT * (1 + active_amount * 2.5)
        end

        fume.rotation = fume.rotation + (0.055 * fume.rotdir * DTMULT)
        local target_x, target_y = self:getTargetPosition()
        fume.x = target_x + math.cos(fume.angle) * (fume.distance + wobble)
        fume.y = target_y + math.sin(fume.angle) * (fume.distance + wobble)
    end

    for _, fume in ipairs(self.rim_fumes) do
        local wobble = math.sin((self.timer / 7) + fume.phase) * 10
        local radius = self.mass_radius + wobble

        if self.banishing then
            fume.disintegration = MathUtils.approach(fume.disintegration, 1, 0.018 * DTMULT)
            radius = radius + (self.banish_timer * 24)
        else
            fume.angle = fume.angle + fume.spin * DTMULT
        end

        fume.rotation = fume.rotation + (0.045 * fume.rotdir * DTMULT)

        local target_x, target_y = self:getTargetPosition()
        fume.x = target_x + math.cos(fume.angle) * radius
        fume.y = target_y + math.sin(fume.angle) * radius
    end

    if self.banishing and self.remove_timer > 64 then
        self:remove()
    end
end

function TenseIntroDarknessController:drawRotatedRectangle(mode, x, y, width, height, angle)
    love.graphics.push()
    love.graphics.translate(x, y)
    love.graphics.rotate(angle)
    love.graphics.setLineWidth(4)
    love.graphics.rectangle(mode, -width / 2, -height / 2, width, height)
    love.graphics.pop()
end

function TenseIntroDarknessController:drawFumeOutline(x, y, radius, rotation, alpha)
    Draw.setColor(1, 0, 0, alpha)
    self:drawRotatedRectangle("line", x, y, radius, radius, rotation)
end

function TenseIntroDarknessController:drawFumeFill(x, y, radius, rotation, alpha)
    Draw.setColor(0, 0, 0, alpha)
    self:drawRotatedRectangle("fill", x, y, math.max(1, radius - 2), math.max(1, radius - 2), rotation)
end

function TenseIntroDarknessController:drawFumePieces(x, y, radius, rotation, alpha)
    self:drawFumeOutline(x, y, radius, rotation, alpha)
    self:drawFumeFill(x, y, radius, rotation, alpha)
end

function TenseIntroDarknessController:drawFumeBatch(fumes)
    for _, fume in ipairs(fumes) do
        self:drawFumeOutline(fume.x, fume.y, fume.radius, fume.rotation, fume.alpha)
    end

    for _, fume in ipairs(fumes) do
        self:drawFumeFill(fume.x, fume.y, fume.radius, fume.rotation, fume.alpha)
    end
end

function TenseIntroDarknessController:drawSolidMass(radius, alpha)
    local target_x, target_y = self:getTargetPosition()

    love.graphics.stencil(function()
        love.graphics.circle("fill", target_x, target_y, radius, 96)
    end, "replace", 1, false)

    love.graphics.setStencilTest("equal", 0)
    Draw.setColor(0, 0, 0, alpha)
    love.graphics.rectangle("fill", 0, 0, SCREEN_WIDTH, SCREEN_HEIGHT)
    love.graphics.setStencilTest()
end

function TenseIntroDarknessController:drawDissolvingFumes(fumes, disintegration, mass_radius, mass_alpha)
    local canvas = Draw.pushCanvas(SCREEN_WIDTH, SCREEN_HEIGHT)

    self:drawSolidMass(mass_radius, mass_alpha)
    self:drawFumeBatch(fumes)

    Draw.popCanvas(true)

    local shader = Assets.getShader("dissolve")
    local last_shader = love.graphics.getShader()

    shader:send("texsize", {SCREEN_WIDTH, SCREEN_HEIGHT})
    local dissolve_progress = math.sqrt(MathUtils.clamp(disintegration, 0, 1))
    shader:send("dissolve_value", 1 - dissolve_progress)
    shader:send("dissolve_mix", 0.38)
    shader:send("dissolve_noise_scale", 8.0)
    shader:send("dissolve_origin", {0, 0})
    shader:send("dissolve_size", {SCREEN_WIDTH, SCREEN_HEIGHT})
    shader:send("dissolve_gradient", Assets.getTexture("misc/bwradial"))

    love.graphics.setShader(shader)
    Draw.setColor(1, 1, 1, 1)
    Draw.drawCanvas(canvas, 0, 0)
    love.graphics.setShader(last_shader)
    Draw.unlockCanvas(canvas)
end

function TenseIntroDarknessController:draw()
    super.draw(self)

    local banish_alpha = self.banishing and MathUtils.clamp(1 - (self.banish_timer * 0.35), 0, 1) or 1
    local mass_alpha = self.full_alpha * banish_alpha
    local fumes = {}
    local dissolving_fumes = {}
    local disintegration = 0

    for _, fume in ipairs(self.rim_fumes) do
        local alpha = self.full_alpha * banish_alpha
        if fume.disintegration and fume.disintegration >= 0 then
            table.insert(dissolving_fumes, {
                x = MathUtils.lerp(fume.dissolve_x, fume.x, 0.2),
                y = MathUtils.lerp(fume.dissolve_y, fume.y, 0.2),
                radius = fume.radius,
                rotation = MathUtils.lerp(fume.dissolve_rotation, fume.rotation, 0.2),
                alpha = alpha
            })
            disintegration = math.max(disintegration, fume.disintegration)
        else
            table.insert(fumes, {
                x = fume.x,
                y = fume.y,
                radius = fume.radius,
                rotation = fume.rotation,
                alpha = alpha
            })
        end
    end

    for _, fume in ipairs(self.fumes) do
        if fume.radius > 0 then
            local alpha = self.full_alpha * banish_alpha * MathUtils.clamp((self.timer - fume.delay) / 20, 0, 1)
            if fume.disintegration and fume.disintegration >= 0 then
                table.insert(dissolving_fumes, {
                    x = MathUtils.lerp(fume.dissolve_x, fume.x, 0.2),
                    y = MathUtils.lerp(fume.dissolve_y, fume.y, 0.2),
                    radius = fume.radius,
                    rotation = MathUtils.lerp(fume.dissolve_rotation, fume.rotation, 0.2),
                    alpha = alpha
                })
                disintegration = math.max(disintegration, fume.disintegration)
            else
                table.insert(fumes, {
                    x = fume.x,
                    y = fume.y,
                    radius = fume.radius,
                    rotation = fume.rotation,
                    alpha = alpha
                })
            end
        end
    end

    self:drawFumeBatch(fumes)

    if #dissolving_fumes > 0 then
        self:drawDissolvingFumes(dissolving_fumes, disintegration, self.mass_radius, mass_alpha)
    end

    if (disintegration < 0.8) then
        self:drawSolidMass(self.mass_radius, mass_alpha)
    end

    Draw.setColor(1, 1, 1, 1)
end

return TenseIntroDarknessController
