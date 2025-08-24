local HealingParticles, super = Class(Object)

function HealingParticles:init(x, y)
    super.init(self, x, y)
    self.particles = {}
    self.particle_timer = 0
    self.sprite = Assets.getTexture("effects/kindness_gradient")
    self.heal_sprite = Assets.getTexture("effects/restoration")
    self.fade = 0
    self.fade_in = true
end

function HealingParticles:update()
    -- code here gets called every frame, before any draws
    -- to only update while the mod is selected, check self.selected (or self.fade)

    if (self.fade < 1 and self.fade_in) then
        self.fade = math.min(1, self.fade + DT * 0.2)
    end
    if (self.fade > 0 and not self.fade_in) then
        self.fade = math.max(0, self.fade - DT)
    end

    local to_remove = {}
    for _,particle in ipairs(self.particles) do
        particle.radius = particle.radius
        particle.radius = particle.radius - (DT)
        particle.y = particle.y - particle.speed * (DTMULT * 2)

        if particle.radius <= 0 then
            table.insert(to_remove, particle)
        end
    end

    for _,particle in ipairs(to_remove) do
        Utils.removeFromTable(self.particles, particle)
    end

    self.particle_timer = self.particle_timer + DT
    if self.particle_timer >= 0.25 then
        self.particle_timer = 0
        local radius = Utils.random() * 16 + 5
        local plusRand = Utils.random() > 0.5
        table.insert(self.particles, {radius = radius, x = Utils.random() * SCREEN_WIDTH, y = SCREEN_HEIGHT + radius, max_radius = radius, speed = Utils.random() * 0.5 + 0.5, has_plus = plusRand})
    end
end

function HealingParticles:draw()
    -- code here gets drawn to the background every frame!!
    -- make sure to check  self.fade  or  self.selected  here

    if self.fade > 0 then
        love.graphics.setBlendMode("add")

        for _,particle in ipairs(self.particles) do
            if (not particle.has_plus) then
                local alpha = (particle.radius / particle.max_radius) * self.fade

                Draw.setColor(100/255, 1, 100/255, alpha)
                love.graphics.circle("fill", particle.x, particle.y, particle.radius)
            end
        end

        love.graphics.setBlendMode("alpha")
        for _,particle in ipairs(self.particles) do
            if (particle.has_plus) then
                local alpha = (particle.radius / particle.max_radius) * self.fade
                local scale = math.min(1.2, particle.radius /2 *alpha)
                Draw.setColor(1,1,1,alpha)
                Draw.draw(self.heal_sprite, particle.x, particle.y, 0, scale, scale, 8, 8)
            end
        end
        Draw.setColor(1, 1, 1, 0.25 * self.fade)
        Draw.draw(self.sprite, self.x, self.y)
    end
end

return HealingParticles