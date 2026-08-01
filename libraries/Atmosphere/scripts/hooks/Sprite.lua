---@class Sprite : Object
local Sprite, super = HookSystem.hookScript(Sprite)

function Sprite:drawAlpha(alpha)
    local r,g,b,a = self:getDrawColor()
    a = alpha
    local function drawSprite(...)
        if self.crossfade_alpha > 0 and self.crossfade_texture ~= nil then
            Draw.setColor(r, g, b, self.crossfade_out and MathUtils.lerp(a, 0, self.crossfade_alpha) or alpha)
            Draw.draw(self.texture, ...)

            Draw.setColor(r, g, b, MathUtils.lerp(0, a, self.crossfade_alpha))
            Draw.draw(self.crossfade_texture, ...)
        else
            Draw.setColor(r, g, b, alpha)
            Draw.draw(self.texture, ...)
        end
    end
    if self.texture then
        if self.wrap_texture_x or self.wrap_texture_y then
            local screen_l, screen_u = love.graphics.inverseTransformPoint(0, 0)
            local screen_r, screen_d = love.graphics.inverseTransformPoint(SCREEN_WIDTH, SCREEN_HEIGHT)

            local x1, y1 = math.min(screen_l, screen_r), math.min(screen_u, screen_d)
            local x2, y2 = math.max(screen_l, screen_r), math.max(screen_u, screen_d)

            local x_offset = math.floor(x1 / self.texture:getWidth()) * self.texture:getWidth()
            local y_offset = math.floor(y1 / self.texture:getHeight()) * self.texture:getHeight()

            local wrap_width = math.ceil((x2 - x_offset) / self.texture:getWidth())
            local wrap_height = math.ceil((y2 - y_offset) / self.texture:getHeight())

            if self.wrap_texture_x and self.wrap_texture_y then
                for i = 1, wrap_width do
                    for j = 1, wrap_height do
                        drawSprite(x_offset + (i-1) * self.texture:getWidth(), y_offset + (j-1) * self.texture:getHeight())
                    end
                end
            elseif self.wrap_texture_x then
                for i = 1, wrap_width do
                    drawSprite(x_offset + (i-1) * self.texture:getWidth(), 0)
                end
            elseif self.wrap_texture_y then
                for j = 1, wrap_height do
                    drawSprite(0, y_offset + (j-1) * self.texture:getHeight())
                end
            end
        else
            drawSprite()
        end
    end

    Object.draw(self)
end

return Sprite