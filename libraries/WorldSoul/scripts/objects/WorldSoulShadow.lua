---@class WorldSoulShadow : HeightShadow
local WorldSoulShadow, super = Class(HeightShadow)

---@param owner WorldSoul
function WorldSoulShadow:init(owner)
    super.init(self, owner)
    self.height_depth_offset = -0.25
end

function WorldSoulShadow:syncOwner()
    super.syncOwner(self)
    self.layer = self.owner.layer - 0.001
end

function WorldSoulShadow:draw()
    if not self:shouldDraw() then return end

    local coordinates = self:getSurfaceCoordinates()
    local previous_comparison, previous_value = love.graphics.getStencilTest()
    if coordinates then
        love.graphics.stencil(function()
            love.graphics.polygon("fill", coordinates)
        end, "replace", 1)
        love.graphics.setStencilTest("equal", 1)
    end

    local distance = self.owner:getHeightShadowOffset()
    local scale = MathUtils.clamp(1 - distance / 180, 0.5, 1)
    local r, g, b, a = love.graphics.getColor()
    Draw.setColor(0, 0, 0, self.owner:getHeightShadowAlpha())
    love.graphics.ellipse("fill", 0, 0, 5 * scale, 2 * scale)
    love.graphics.setColor(r, g, b, a)

    if previous_comparison then
        love.graphics.setStencilTest(previous_comparison, previous_value)
    else
        love.graphics.setStencilTest()
    end
end

function WorldSoulShadow:drawHeightOcclusionMask()
    self:draw()
end

return WorldSoulShadow
