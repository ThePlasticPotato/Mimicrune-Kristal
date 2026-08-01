---@class Snow : Weather
local Snow, super = Class("Weather")

function Snow:init(intensity, wind_strength, wind_direction)
    super.init(self, intensity)
    self.type = "snow"
    self.has_overlay = true
    self.wind_strength = wind_strength or 0
    self.wind_direction = wind_direction or 0
    self.spawn_accumulator = 0
    self.max_flakes = 140
end

function Snow:spawnFlake()
    local target = self.addto or self:getTarget()
    if not target then return end
    local screen_x = MathUtils.random(-20, SCREEN_WIDTH + 20)
    local x, y = self:getRelativePos(screen_x, MathUtils.random(-30, -5), target)
    self:addPiece(Snowflake(
        TableUtils.pick({"a", "b", "c", "d"}),
        x, y,
        MathUtils.random(1.2, 3.2) * math.max(self.intensity, 0.4),
        MathUtils.random(-2.5, 2.5),
        MathUtils.random(1.5, 4),
        self
    ))
end

function Snow:update()
    super.update(self)
    if self.paused or self.ending then return end
    self.spawn_accumulator = self.spawn_accumulator + DT * (8 + self.intensity * 12)
    while self.spawn_accumulator >= 1 and #self.pieces < self.max_flakes do
        self.spawn_accumulator = self.spawn_accumulator - 1
        self:spawnFlake()
    end
end

function Snow:drawOverlay(overlay)
    overlay:drawColdTint(MathUtils.clamp(0.08 + self.intensity * 0.08, 0, 0.3))
end

return Snow
