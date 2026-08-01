---@class Volcanic : Hot
local Volcanic, super = Class("Hot")

function Volcanic:init(intensity)
    super.init(self, intensity)
    self.type = "volcanic"
    self.spawn_accumulator = 0
    self.max_ash = 80
end

function Volcanic:spawnAsh()
    local target = self.addto or self:getTarget()
    if not target then return end
    local x, y = self:getRelativePos(SCREEN_WIDTH + 20, MathUtils.random(0, SCREEN_HEIGHT), target)
    self:addPiece(AshParticle(TableUtils.pick({"a", "b", "c", "d", "e"}), x, y, MathUtils.random(3, 7) * self.intensity, self))
end

function Volcanic:update()
    super.update(self)
    if self.paused or self.ending then return end
    self.spawn_accumulator = self.spawn_accumulator + DT * (3 + self.intensity * 4)
    while self.spawn_accumulator >= 1 and #self.pieces < self.max_ash do
        self.spawn_accumulator = self.spawn_accumulator - 1
        self:spawnAsh()
    end
end

return Volcanic
