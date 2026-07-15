local AgonySquare, super = Class(Bullet)

function AgonySquare:init(target_x, target_y, angle, radius, size, radial_speed, orbit_speed)
    super.init(self, target_x, target_y)

    self.target_x = target_x
    self.target_y = target_y
    self.orbit_angle = angle
    self.orbit_radius = radius
    self.start_radius = radius
    self.size = size
    self.radial_speed = radial_speed
    self.orbit_speed = orbit_speed
    self.rotation = MathUtils.random(-math.pi, math.pi)
    self.rotation_speed = MathUtils.random(0.025, 0.055)
        * (MathUtils.randomInt(0, 1) == 0 and -1 or 1)
    self.wobble_phase = MathUtils.random(0, math.pi * 2)
    self.age = 0
    self.spawn_duration = 12
    self.spawn_finished = false
    self.velocity_x = 0
    self.velocity_y = 0

    -- This object is positioned from its center, like the procedural squares
    -- in the Tense intro, and uses screen-pixel dimensions rather than the
    -- usual doubled bullet-sprite scale.
    self:setOrigin(0, 0)
    self:setScale(1)
    self.width = size
    self.height = size
    -- Keep collision centered on the procedural shape. A circle also stays
    -- stable while the square violently rotates during its approach.
    self.collider = CircleCollider(self, 0, 0, size * 0.44)

    -- The powerless Goner soul cannot dissolve these. They also persist when
    -- touched so invulnerability, rather than bullet removal, handles a hit.
    self.destroy_on_hit = false
    self.remove_offscreen = false
    self.collidable = false

    self:updatePosition()
end

function AgonySquare:onWaveSpawn(wave)
    -- Wave-spawned bullets normally derive damage from their selected enemy.
    -- Keep that behavior, but do not silently become harmless if an encounter
    -- starts this wave directly and therefore has no selected attacker.
    local attack = self.attacker and self.attacker.attack or 12
    self.damage = attack * 5
end

function AgonySquare:updatePosition()
    local wobble = math.sin((self.age / 7) + self.wobble_phase) * 0.035
    local angle = self.orbit_angle + wobble
    self.x = self.target_x + math.cos(angle) * self.orbit_radius
    self.y = self.target_y + math.sin(angle) * self.orbit_radius
end

function AgonySquare:beginMissDissolve(rebound_x, rebound_y)
    if self.disintegration then return end

    self.disintegration = 0
    self.disintegration_duration = 12
    -- Keep the fragment live just long enough for the soul collision pass to
    -- observe the center contact, regardless of child update order.
    self.rebound_harm_timer = 2

    local speed = math.max(
        MathUtils.dist(0, 0, self.velocity_x, self.velocity_y),
        self.radial_speed * self:getClosingSpeed() * 0.8
    )
    local outward_x = math.cos(self.orbit_angle)
    local outward_y = math.sin(self.orbit_angle)

    self.rebound_vx = rebound_x or outward_x * speed
    self.rebound_vy = rebound_y or outward_y * speed
    self.rebound_spin = self.rotation_speed * MathUtils.random(2.5, 4.5)
        * (MathUtils.randomInt(0, 1) == 0 and -1 or 1)
end

function AgonySquare:getClosingAmount()
    return MathUtils.clamp(1 - math.max(self.orbit_radius, 0) / self.start_radius, 0, 1)
end

function AgonySquare:getClosingSpeed()
    local amount = self:getClosingAmount()
    return MathUtils.lerp(0.7, 2.4, amount ^ 1.25)
end

function AgonySquare:update()
    self.age = self.age + DTMULT

    if not self.spawn_finished and self.age >= self.spawn_duration then
        self.spawn_finished = true
        self.collidable = true
    end

    if not self.spawn_finished then
        -- Materialize in place so the incoming angles and open sector can be
        -- read before the much faster enclosure begins.
        self.rotation = self.rotation + self.rotation_speed * 1.4 * DTMULT
        super.update(self)
        return
    end

    if self.disintegration then
        self.disintegration = self.disintegration
            + (DTMULT / self.disintegration_duration)
        self.x = self.x + self.rebound_vx * DTMULT
        self.y = self.y + self.rebound_vy * DTMULT
        self.rebound_vx = self.rebound_vx * (0.985 ^ DTMULT)
        self.rebound_vy = self.rebound_vy * (0.985 ^ DTMULT)
        self.rotation = self.rotation + self.rebound_spin * DTMULT
        self.rebound_harm_timer = MathUtils.approach(
            self.rebound_harm_timer,
            0,
            DTMULT
        )
        if self.rebound_harm_timer <= 0 then
            self.collidable = false
        end

        if self.disintegration >= 1 then
            self:remove()
            return
        end

        super.update(self)
        return
    end

    local old_x, old_y = self.x, self.y
    local closing_speed = self:getClosingSpeed()
    self.orbit_radius = self.orbit_radius - self.radial_speed * closing_speed * DTMULT
    self.orbit_angle = self.orbit_angle
        + self.orbit_speed * MathUtils.lerp(0.7, 1.8, self:getClosingAmount()) * DTMULT
    self.rotation = self.rotation + self.rotation_speed * DTMULT

    -- Every member of a ring shares its radial speed, so clamping them to a
    -- common impact radius produces one clean central collision rather than
    -- a sequence of unstable pairwise shoves.
    local impact_radius = 6
    local reached_center = self.orbit_radius <= impact_radius
    if reached_center then
        self.orbit_radius = impact_radius
    end
    self:updatePosition()
    self.velocity_x = (self.x - old_x) / math.max(DTMULT, 0.001)
    self.velocity_y = (self.y - old_y) / math.max(DTMULT, 0.001)

    if reached_center and not self.disintegration then
        local outward_x = math.cos(self.orbit_angle)
        local outward_y = math.sin(self.orbit_angle)
        local tangent_x, tangent_y = -outward_y, outward_x
        local speed = math.max(
            MathUtils.dist(0, 0, self.velocity_x, self.velocity_y),
            self.radial_speed * closing_speed
        )
        local tangent_direction = self.slot_index % 2 == 0 and 1 or -1
        self:beginMissDissolve(
            outward_x * speed + tangent_x * speed * 0.16 * tangent_direction,
            outward_y * speed + tangent_y * speed * 0.16 * tangent_direction
        )
        if self.wave and self.wave.onAgonyRingImpact then
            self.wave:onAgonyRingImpact(self.ring_id)
        end
    end

    super.update(self)
end

function AgonySquare:drawPiece(x, y, size, rotation, alpha)
    love.graphics.push()
    love.graphics.translate(x, y)
    love.graphics.rotate(rotation)

    Draw.setColor(0, 0, 0, alpha)
    love.graphics.rectangle("fill", -size / 2, -size / 2, size, size)
    Draw.setColor(1, 0, 0, alpha)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", -size / 2, -size / 2, size, size)

    love.graphics.pop()
end

function AgonySquare:drawShape(alpha)
    local pulse = 1 + math.sin((self.age / 4) + self.wobble_phase) * 0.07
    local outward_angle = self.orbit_angle - self.rotation
    local outward_x, outward_y = math.cos(outward_angle), math.sin(outward_angle)

    self:drawPiece(
        outward_x * self.size * 0.82,
        outward_y * self.size * 0.82,
        self.size * 0.36,
        self.age * 0.025,
        alpha * 0.55
    )
    self:drawPiece(0, 0, self.size * pulse, 0, alpha)
end

function AgonySquare:drawDissolving()
    local canvas_size = math.ceil(self.size * 4)
    local center = canvas_size / 2
    local canvas = Draw.pushCanvas(canvas_size, canvas_size)
    love.graphics.translate(center, center)
    self:drawShape(1)
    Draw.popCanvas(true)

    local shader = Assets.getShader("dissolve")
    local last_shader = love.graphics.getShader()
    shader:send("texsize", {canvas_size, canvas_size})
    shader:send(
        "dissolve_value",
        1 - math.sqrt(MathUtils.clamp(self.disintegration, 0, 1))
    )
    shader:send("dissolve_mix", 0.45)
    shader:send("dissolve_noise_scale", 8)
    shader:send("dissolve_use_screen_coords", 0)
    shader:send("dissolve_origin", {0, 0})
    shader:send("dissolve_size", {canvas_size, canvas_size})
    shader:send("dissolve_gradient", Assets.getTexture("misc/bwradial"))

    love.graphics.setShader(shader)
    Draw.setColor(1, 1, 1, 1)
    Draw.drawCanvas(canvas, -center, -center)
    love.graphics.setShader(last_shader)
    Draw.unlockCanvas(canvas)
end

function AgonySquare:drawSpawning()
    local progress = MathUtils.clamp(self.age / self.spawn_duration, 0, 1)
    local tick = math.floor(self.age * 2)
    local jitter = (1 - progress) * 9
    local jitter_x = math.sin((tick + self.wobble_phase) * 12.9898) * jitter
    local jitter_y = math.sin((tick + self.wobble_phase) * 7.233) * jitter * 0.65
    local scale

    if progress < 0.16 then
        scale = MathUtils.lerp(0.05, 2.8, progress / 0.16)
    elseif progress < 0.34 then
        scale = MathUtils.lerp(2.8, 0.35, (progress - 0.16) / 0.18)
    elseif progress < 0.55 then
        scale = MathUtils.lerp(0.35, 1.75, (progress - 0.34) / 0.21)
    elseif progress < 0.73 then
        scale = MathUtils.lerp(1.75, 0.72, (progress - 0.55) / 0.18)
    else
        scale = MathUtils.lerp(0.72, 1, (progress - 0.73) / 0.27)
    end

    -- A stretched, displaced copy creates a one-frame horizontal tear behind
    -- the main strobing shape.
    love.graphics.push()
    love.graphics.translate(-jitter_x * 0.8, jitter_y * 0.25)
    love.graphics.scale(scale * 1.3, math.max(0.15, scale * 0.55))
    self:drawShape(0.28 * (1 - progress))
    love.graphics.pop()

    local strobe_alpha = ((tick % 5 == 1) and progress < 0.78) and 0.12 or 1
    love.graphics.push()
    love.graphics.translate(jitter_x, jitter_y)
    love.graphics.scale(scale, scale)
    self:drawShape(strobe_alpha)
    love.graphics.pop()

    Draw.setColor(1, 0, 0, (1 - progress) * 0.8)
    love.graphics.setLineWidth(2)
    love.graphics.line(-self.size * 2.2, jitter_y, self.size * 2.2, -jitter_y)
end

function AgonySquare:draw()
    super.draw(self)

    if self.disintegration then
        self:drawDissolving()
    elseif not self.spawn_finished then
        self:drawSpawning()
    else
        self:drawShape(1)
    end
    Draw.setColor(1, 1, 1, 1)
end

return AgonySquare
