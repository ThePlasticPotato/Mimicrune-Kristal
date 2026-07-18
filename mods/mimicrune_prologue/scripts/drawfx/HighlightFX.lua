---@class HighlightFX : FXBase
---@overload fun(...) : HighlightFX
local HighlightFX, super = Class(FXBase)

--- Creates a directional rim highlight.
---@param alpha? number
---@param highlight? table
---@param direction? number The direction from the object to the light source, in radians.
---@param priority? number
function HighlightFX:init(alpha, highlight, direction, priority)
    super.init(self, priority)

    self.alpha = alpha or 0.75
    self.highlight = highlight or {1, 1, 1, 1}
    self.strength = 1

    self.direction = direction or -math.pi / 2
    self.light_source = nil
end

function HighlightFX:getAlpha()
    return self.alpha
end

function HighlightFX:getHighlight()
    return self.highlight[1], self.highlight[2], self.highlight[3], self.highlight[4] or 1
end

function HighlightFX:getLightStrength()
    return self.strength
end

function HighlightFX:setLightStrength(strength)
    self.strength = math.max(0, strength or 1)
end

function HighlightFX:setHighlight(r, g, b, a)
    if not r then
        self.highlight = {0, 0, 0, 0}
    else
        self.highlight = {r, g, b, a or 1}
    end
end

function HighlightFX:getLightDirection()
    if self.light_source then
        local center_x, center_y = self.parent:localToScreenPos(self.parent.width / 2, self.parent.height / 2)
        local source_x, source_y
        if self.light_source.getScreenPosition then
            source_x, source_y = self.light_source:getScreenPosition()
        elseif self.light_source.localToScreenPos then
            source_x, source_y = self.light_source:localToScreenPos(0, 0)
        else
            source_x, source_y = self.light_source.x, self.light_source.y
        end

        if source_x and source_y and (source_x ~= center_x or source_y ~= center_y) then
            return MathUtils.angle(center_x, center_y, source_x, source_y)
        end
    end

    return self.direction
end

function HighlightFX:getLightSource()
    return self.light_source
end

function HighlightFX:getConfiguredLightDirection()
    return self.direction
end

--- Sets the direction from the object to the light source, in radians.
function HighlightFX:setLightDirection(direction)
    self.direction = direction or -math.pi / 2
    self.light_source = nil
end

--- Uses a fixed screen-space point as the light source.
---@param x number|table The screen-space x coordinate, or an `{x=x, y=y}` supplier.
---@param y? number The screen-space y coordinate.
function HighlightFX:setLightSource(x, y)
    if type(x) == "table" then
        self.light_source = x
    else
        self.light_source = {["x"] = x, ["y"] = y}
    end
end

function HighlightFX:isActive()
    return super.isActive(self) and self:getAlpha() > 0 and self:getLightStrength() > 0
end

function HighlightFX:draw(texture)
    local hr, hg, hb, ha = self:getHighlight()
    local intensity = MathUtils.clamp(self:getAlpha() * self:getLightStrength(), 0, 1)

    local canvas
    if intensity < 1 then
        canvas = Draw.pushCanvas(SCREEN_WIDTH, SCREEN_HEIGHT)
    end

    if ha > 0 then
        local last_shader = love.graphics.getShader()
        local shader = Kristal.Shaders["AddColor"]
        love.graphics.setShader(shader)
        shader:send("inputcolor", {hr, hg, hb})
        shader:send("amount", ha * intensity)
        Draw.drawCanvas(texture)
        love.graphics.setShader(last_shader)
    elseif not canvas then
        Draw.drawCanvas(texture)
    end

    local sx, sy = self.parent:getFullScale()
    local direction = self:getLightDirection()

    local offset_x = -math.cos(direction) * math.abs(sx) * 2
    local offset_y = -math.sin(direction) * math.abs(sy) * 2

    if math.abs(offset_x) < 0.000001 then offset_x = 0 end
    if math.abs(offset_y) < 0.000001 then offset_y = 0 end

    Draw.setColor(0, 0, 0)
    Draw.draw(texture, offset_x, offset_y)

    if canvas then
        Draw.popCanvas()

        Draw.setColor(1, 1, 1)
        Draw.drawCanvas(texture)

        Draw.setColor(1, 1, 1, intensity)
        Draw.draw(canvas)
    end

    Draw.setColor(1, 1, 1, 1)
end

return HighlightFX
