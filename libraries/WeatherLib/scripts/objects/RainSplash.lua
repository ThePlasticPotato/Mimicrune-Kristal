local RainSplash, super = Class(Object)

function RainSplash:init(x, y, addto, splashsize)
    super.init(self, x, y)

    self.splash_size = splashsize

    if Game.stage and Game.stage.weather_layer then
        self:setLayer(Game.stage.weather_layer - 1)
    elseif addto == Game.world then
        self:setLayer(WORLD_LAYERS["below_ui"] - 1)
    elseif addto == Game.battle then
        self:setLayer(BATTLE_LAYERS["below_ui"] - 1)
    end

    self.timer = 0
    self.duration = 0.3

    self.droplets = {}
    local count = math.random(3, 5)
    for i = 1, count do
        local angle = (i / count) * math.pi * 2 + math.random() * 0.5 - 0.25
        local speed = math.random(6, 14)
        table.insert(self.droplets, {
            x = 0, y = 0,
            vx = math.cos(angle) * speed * 0.5,
            vy = math.sin(angle) * speed * 0.25 - math.random(3, 6),
            size = math.random() * 0.8 + 0.4,
        })
    end
    -- self:addFX(ShaderFX('pixelize', {
    --     size = {SCREEN_WIDTH, SCREEN_HEIGHT},
    --     factor = 2
    -- }, true))
end

function RainSplash:update()
    super.update(self)
    self.timer = self.timer + DT
    if self.timer >= self.duration then
        self:remove()
        return
    end
    for _, d in ipairs(self.droplets) do
        d.x = d.x + d.vx * DTMULT
        d.y = d.y + d.vy * DTMULT
        d.vy = d.vy + 0.3 * DTMULT
    end
end

function RainSplash:draw()
    super.draw(self)

    local progress = self.timer / self.duration
    local alpha = (1 - progress) * 0.65

    love.graphics.setBlendMode("add")

    -- Expanding ring ripple
    Draw.setColor(0.7, 0.8, 1, alpha * 0.5)
    love.graphics.setLineWidth(1)
    love.graphics.ellipse("line", 0, 0, progress * 5 + 0.5 * self.splash_size, progress * 3.5 + 0.35 * self.splash_size)

    -- Small scatter droplets
    Draw.setColor(0.8, 0.9, 1, alpha)
    for _, d in ipairs(self.droplets) do
        love.graphics.circle("fill", d.x, d.y, d.size)
    end

    love.graphics.setBlendMode("alpha")
    Draw.setColor(1, 1, 1, 1)
end

return RainSplash
