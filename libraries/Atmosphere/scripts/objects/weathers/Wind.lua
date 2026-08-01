---@class Wind : Weather
---@field blowing_leaves boolean
---@field direction number
local Wind, super = Class("Weather")

---@param intensity number?
---@param blowing_leaves boolean?
---@param direction number? `-1` blows left and `1` blows right.
function Wind:init(intensity, blowing_leaves, direction)
    super.init(self, intensity)
    self.type = "wind"
    self.has_sfx = true
    self.blowing_leaves = blowing_leaves == true
    self.direction = (direction or -1) >= 0 and 1 or -1
    self.gust_timer = MathUtils.random(2.5, 5)
    self.leaf_queue = 0
    self.leaf_timer = 0
end

function Wind:getAmbientTrack()
    local tracks = {"light", "moderate", "strong"}
    return "wind/" .. tracks[MathUtils.clamp(math.ceil(self.intensity), 1, #tracks)]
end

---@param enabled boolean
function Wind:setBlowingLeaves(enabled)
    self.blowing_leaves = enabled == true
    if not self.blowing_leaves then self.leaf_queue = 0 end
end

function Wind:spawnLeaf()
    local target = self.addto or self:getTarget()
    if not target then return end
    local screen_x = self.direction < 0 and (SCREEN_WIDTH + 40) or -40
    local screen_y = MathUtils.random(-20, SCREEN_HEIGHT * 0.75)
    local x, y = self:getRelativePos(screen_x, screen_y, target)
    self:addPiece(WindLeaf(x, y, MathUtils.random(5, 9) * math.max(self.intensity, 0.5), self))
end

function Wind:update()
    super.update(self)
    if self.paused or self.ending then return end

    self.gust_timer = self.gust_timer - DT
    if self.gust_timer <= 0 then
        if self.has_sfx then
            Assets.stopAndPlaySound("gust", self:isInside() and 0.15 or 0.55, MathUtils.random(0.9, 1.1))
        end
        if self.blowing_leaves then self.leaf_queue = math.random(3, 8) end
        self.gust_timer = MathUtils.random(math.max(1.5, 5 - self.intensity), math.max(3, 9 - self.intensity))
    end

    if self.blowing_leaves and self.leaf_queue > 0 then
        self.leaf_timer = self.leaf_timer - DT
        if self.leaf_timer <= 0 then
            self:spawnLeaf()
            self.leaf_queue = self.leaf_queue - 1
            self.leaf_timer = MathUtils.random(0.08, 0.28)
        end
    end
end

return Wind
