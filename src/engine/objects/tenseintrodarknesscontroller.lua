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
    self.light_burst_timer = 0
    self.light_burst_duration = 2.0
    self.light_burst_delay = 0.025
    self.light_burst_radius = 0
    self.light_burst_max_radius = MathUtils.dist(SCREEN_WIDTH / 2, SCREEN_HEIGHT / 2, 0, 0) + 220
    self.squeeze_start = 115
    self.struggle_push_duration = 14
    self.struggle_hold_duration = 18
    self.squeeze_duration = 32
    self.struggle_glow_start_radius = 76
    self.struggle_glow_end_radius = 28

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
    self.light_burst_timer = 0
    self.light_burst_radius = 0

    Assets.playSound("revival", 1.0, 1.25)

    if self.target and self.target.soul_glow then
        self.target.soul_glow.m = 28
        self.target.soul_glow.momentum = -1.25
    end

    for _, fume in ipairs(self.rim_fumes) do
        fume.dissolve_x = fume.x
        fume.dissolve_y = fume.y
        fume.dissolve_rotation = fume.rotation
    end
end

function TenseIntroDarknessController:getStruggleGlowRadius()
    if not self.target or not self.target.soul_glow or not self.target.soul_glow.visible then
        return 0
    end

    return math.max(0, self.target.soul_glow.radius + self.target.soul_glow.scale_offset)
end

function TenseIntroDarknessController:getSqueezeAmount()
    local squeeze_time = self.squeeze_start + self.struggle_push_duration + self.struggle_hold_duration
    local squeeze_amount = MathUtils.clamp((self.timer - squeeze_time) / self.squeeze_duration, 0, 1)
    return squeeze_amount * squeeze_amount
end

function TenseIntroDarknessController:getStruggleGlowTargetRadius()
    local elapsed = self.timer - self.squeeze_start

    if elapsed <= 0 then
        return 0
    elseif elapsed < self.struggle_push_duration then
        local amount = elapsed / self.struggle_push_duration
        return Utils.ease(0, self.struggle_glow_start_radius, amount, "out-back")
    elseif elapsed < self.struggle_push_duration + self.struggle_hold_duration then
        local hold_time = elapsed - self.struggle_push_duration
        local hold_amount = hold_time / self.struggle_hold_duration
        local pulse = math.sin(hold_time / 3) * MathUtils.lerp(10, 4, hold_amount)
        return self.struggle_glow_start_radius + pulse
    else
        local amount = self:getSqueezeAmount()
        local pulse = math.sin((elapsed - self.struggle_push_duration - self.struggle_hold_duration) / 5) * MathUtils.lerp(4, 1, amount)
        return Utils.ease(self.struggle_glow_start_radius, self.struggle_glow_end_radius, amount, "in-out-back") + pulse
    end
end

function TenseIntroDarknessController:updateStruggleGlow()
    if not self.target or not self.target.soul_glow then
        return
    end

    local glow = self.target.soul_glow

    if self.banishing then
        if self.light_burst_timer < self.light_burst_delay then
            glow.m = 28
            glow.momentum = -1.5
            glow.visible = true
        else
            glow.m = 80
            glow.momentum = 3.25
            glow.visible = true
        end
    elseif self.timer < self.squeeze_start then
        glow.momentum = 0
        glow.visible = false
    else
        local squeeze_amount = self:getSqueezeAmount()
        local target_radius = self:getStruggleGlowTargetRadius()
        glow.radius = MathUtils.approach(glow.radius, target_radius, Utils.ease(5, 1.4, squeeze_amount, "in-out-elastic") * DTMULT)
        glow.m = target_radius
        glow.momentum = 0
        if (glow.visible == false) then
            Assets.playSound("snd_greatshine", 1.0, 0.75)
        end
        glow.visible = true
    end
end

function TenseIntroDarknessController:startFumeDissolve(fume)
    if fume.disintegration and fume.disintegration >= 0 then
        return
    end

    local target_x, target_y = self:getTargetPosition()
    fume.disintegration = 0
    fume.dissolve_angle = MathUtils.angle(target_x, target_y, fume.x, fume.y)
    fume.dissolve_speed = 0.35 + (fume.radius / 120)
end

function TenseIntroDarknessController:update()
    super.update(self)

    self.timer = self.timer + DTMULT
    self.full_alpha = MathUtils.approach(self.full_alpha, 1, 0.06 * DTMULT)

    if self.banishing then
        self.banish_timer = MathUtils.approach(self.banish_timer, 1, 0.035 * DTMULT)
        self.light_burst_timer = self.light_burst_timer + DT
        local burst_amount = MathUtils.clamp((self.light_burst_timer - self.light_burst_delay) / self.light_burst_duration, 0, 1)
        self.light_burst_radius = Utils.ease(0, self.light_burst_max_radius, burst_amount, "in-quint")
        self.remove_timer = self.remove_timer + DTMULT
    end

    self:updateStruggleGlow()

    local settle_amount = MathUtils.clamp(self.timer / 120, 0, 1)
    settle_amount = 1 - ((1 - settle_amount) * (1 - settle_amount) * (1 - settle_amount))
    local squeeze_amount = self:getSqueezeAmount()
    local target_mass_radius = MathUtils.lerp(self.mass_start_radius, self.mass_settle_radius, settle_amount)

    if not self.banishing then
        target_mass_radius = MathUtils.lerp(target_mass_radius, self.mass_squeeze_radius, squeeze_amount)
    end

    if self.banishing then
        self.mass_radius = math.max(self.mass_radius, self.light_burst_radius)
    else
        self.mass_radius = MathUtils.approach(self.mass_radius, target_mass_radius, 2.5 * DTMULT)
    end

    local glow_radius = self:getStruggleGlowRadius()
    local glow_x, glow_y = self:getTargetPosition()

    local to_remove = {}
    for _, fume in ipairs(self.fumes) do
        local active_amount = MathUtils.clamp((self.timer - fume.delay) / 90, 0, 1)
        active_amount = active_amount * active_amount
        local wobble = math.sin((self.timer / 8) + fume.phase) * 12

        if fume.disintegration and fume.disintegration >= 0 then
            fume.disintegration = MathUtils.approach(fume.disintegration, 1, 0.018 * DTMULT)
            fume.x = fume.x + math.cos(fume.dissolve_angle) * fume.dissolve_speed * DTMULT
            fume.y = fume.y + math.sin(fume.dissolve_angle) * fume.dissolve_speed * DTMULT
            fume.rotation = fume.rotation + (0.035 * fume.rotdir * DTMULT)
            if fume.disintegration >= 1 then
                table.insert(to_remove, fume)
            end
        else
            local closing_distance = MathUtils.lerp(fume.target_distance, fume.target_distance * 0.55, squeeze_amount)
            local target_distance = MathUtils.lerp(fume.start_distance, closing_distance, active_amount)
            fume.distance = MathUtils.approach(fume.distance, target_distance, (1.5 + active_amount * 5) * DTMULT)
            fume.angle = fume.angle + fume.spin * DTMULT * (1 + active_amount * 2.5)

            fume.rotation = fume.rotation + (0.055 * fume.rotdir * DTMULT)
            local target_x, target_y = self:getTargetPosition()
            fume.x = target_x + math.cos(fume.angle) * (fume.distance + wobble)
            fume.y = target_y + math.sin(fume.angle) * (fume.distance + wobble)
        end

        if not self.banishing and glow_radius > 0 and fume.disintegration < 0 then
            local dist = MathUtils.dist(glow_x, glow_y, fume.x, fume.y)
            if dist <= glow_radius * 1.2 then
                self:startFumeDissolve(fume)
            end
        elseif self.banishing and fume.disintegration < 0 then
            local dist = MathUtils.dist(glow_x, glow_y, fume.x, fume.y)
            if dist <= self.light_burst_radius + fume.radius then
                self:startFumeDissolve(fume)
            end
        end
    end

    for _, fume in ipairs(to_remove) do
        TableUtils.removeValue(self.fumes, fume)
    end

    for _, fume in ipairs(self.rim_fumes) do
        local wobble = math.sin((self.timer / 7) + fume.phase) * 10
        local radius = self.mass_radius + wobble

        if self.banishing then
            radius = math.max(radius, self.light_burst_radius + wobble)
        else
            fume.angle = fume.angle + fume.spin * DTMULT
        end

        fume.rotation = fume.rotation + (0.045 * fume.rotdir * DTMULT)

        local target_x, target_y = self:getTargetPosition()
        fume.x = target_x + math.cos(fume.angle) * radius
        fume.y = target_y + math.sin(fume.angle) * radius
    end

    if self.target and self.target.sprite and self.banishing then
        local soul_fade = MathUtils.clamp((self.light_burst_radius - 18) / 96, 0, 1)
        self.target.sprite.alpha = 1 - soul_fade
    end

    if self.banishing and self.light_burst_timer >= self.light_burst_duration + self.light_burst_delay then
        if Game and Game.fader then
            Game.fader.fade_color = COLORS.white
            Game.fader.alpha = 1
            Game.fader.state = "NONE"
        end
        if self.target and self.target.sprite then
            self.target.sprite.alpha = 1
        end
        if self.target and self.target.soul_glow then
            self.target.soul_glow.m = 64
            self.target.soul_glow.momentum = 2
            self.target.soul_glow.visible = true
        end
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

function TenseIntroDarknessController:setDissolveShader(fume)
    if not fume.disintegration or fume.disintegration < 0 then
        return false, nil
    end

    local shader = Assets.getShader("dissolve")
    local last_shader = love.graphics.getShader()
    local target_x, target_y = self:getTargetPosition()
    local dissolve_radius = self.banishing and math.max(self.light_burst_radius, 96) or math.max(self:getStruggleGlowRadius() * 1.35, 96)

    shader:send("texsize", {SCREEN_WIDTH, SCREEN_HEIGHT})
    local dissolve_progress = math.sqrt(MathUtils.clamp(fume.disintegration, 0, 1))
    shader:send("dissolve_value", 1 - dissolve_progress)
    shader:send("dissolve_mix", 0.38)
    shader:send("dissolve_noise_scale", 8.0)
    shader:send("dissolve_origin", {target_x - dissolve_radius, target_y - dissolve_radius})
    shader:send("dissolve_size", {dissolve_radius * 2, dissolve_radius * 2})
    shader:send("dissolve_use_screen_coords", 1)
    shader:send("dissolve_gradient", Assets.getTexture("misc/bwradial"))

    love.graphics.setShader(shader)
    return true, last_shader
end

function TenseIntroDarknessController:clearDissolveShader(enabled, last_shader)
    if enabled then
        love.graphics.setShader(last_shader)
    end
end

function TenseIntroDarknessController:drawFumeOutline(fume)
    Draw.setColor(1, 0, 0, fume.alpha)
    local dissolve, last_shader = self:setDissolveShader(fume)
    self:drawRotatedRectangle("line", fume.x, fume.y, fume.radius, fume.radius, fume.rotation)
    self:clearDissolveShader(dissolve, last_shader)
end

function TenseIntroDarknessController:drawFumeFill(fume)
    Draw.setColor(0, 0, 0, fume.alpha)
    local dissolve, last_shader = self:setDissolveShader(fume)
    self:drawRotatedRectangle("fill", fume.x, fume.y, math.max(1, fume.radius - 2), math.max(1, fume.radius - 2), fume.rotation)
    self:clearDissolveShader(dissolve, last_shader)
end

function TenseIntroDarknessController:drawFumePieces(x, y, radius, rotation, alpha)
    self:drawFumeOutline({x = x, y = y, radius = radius, rotation = rotation, alpha = alpha})
    self:drawFumeFill({x = x, y = y, radius = radius, rotation = rotation, alpha = alpha})
end

function TenseIntroDarknessController:drawFumeBatch(fumes)
    for _, fume in ipairs(fumes) do
        self:drawFumeOutline(fume)
    end

    for _, fume in ipairs(fumes) do
        self:drawFumeFill(fume)
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

function TenseIntroDarknessController:drawLightBurst()
    if not self.banishing or self.light_burst_radius <= 0 then
        return
    end

    local target_x, target_y = self:getTargetPosition()

    Draw.setColor(220/255, 1, 220/255, 0.25)
    love.graphics.circle("fill", target_x-1, target_y-1, self.light_burst_radius * 1.6)
    Draw.setColor(250/255, 1, 250/255, 0.5)
    love.graphics.circle("fill", target_x-1, target_y-1, self.light_burst_radius *1.2)
    Draw.setColor(1, 1, 1, 1)
    love.graphics.circle("fill", target_x-1, target_y-1, self.light_burst_radius, 128)
end

function TenseIntroDarknessController:draw()
    super.draw(self)

    local banish_alpha = self.banishing and MathUtils.clamp(1 - (self.banish_timer * 0.35), 0, 1) or 1
    local mass_alpha = self.full_alpha
    local fumes = {}

    for _, fume in ipairs(self.rim_fumes) do
        table.insert(fumes, {
            x = fume.x,
            y = fume.y,
            radius = fume.radius,
            rotation = fume.rotation,
            alpha = self.full_alpha
        })
    end

    for _, fume in ipairs(self.fumes) do
        if fume.radius > 0 then
            local alpha = self.full_alpha * banish_alpha * MathUtils.clamp((self.timer - fume.delay) / 20, 0, 1)
            if fume.disintegration and fume.disintegration >= 0 then
                table.insert(fumes, {
                    x = fume.x,
                    y = fume.y,
                    radius = fume.radius,
                    rotation = fume.rotation,
                    alpha = alpha,
                    disintegration = fume.disintegration
                })
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

    self:drawLightBurst()

    self:drawFumeBatch(fumes)

    if not self.banishing or self.light_burst_radius < self.light_burst_max_radius then
        self:drawSolidMass(self.mass_radius, mass_alpha)
    end

    Draw.setColor(1, 1, 1, 1)
end

return TenseIntroDarknessController
