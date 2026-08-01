---@class WeatherOverlay : Object
---@field handler Weather
---@field paused boolean
local WeatherOverlay, super = Class(Object)

function WeatherOverlay:init(handler)
    super.init(self)
    self.parallax_x, self.parallax_y = 0, 0
    self.handler = handler
    self.paused = false
    self.fog_offset = 0
    self.heat_offset = 0
    self:updateLayer()
end

function WeatherOverlay:updateLayer()
    if self.parent == Game.battle then
        self:setLayer(BATTLE_LAYERS["below_ui"])
    else
        self:setLayer(WORLD_LAYERS["below_ui"])
    end
end

function WeatherOverlay:onAdd(parent)
    super.onAdd(self, parent)
    self:updateLayer()
end

function WeatherOverlay:update()
    super.update(self)
    if self.paused or self.handler.paused then return end
    self.fog_offset = (self.fog_offset + DT * (5 + self.handler.intensity * 4)) % 320
    self.heat_offset = self.heat_offset + DT
end

function WeatherOverlay:draw()
    super.draw(self)
    if not self.paused and not self.handler.paused then
        self.handler:drawOverlay(self)
    end
    Draw.setColor(1, 1, 1, 1)
end

function WeatherOverlay:drawRainTint(alpha)
    Draw.setColor(79/255, 106/255, 115/255, alpha or 55/255)
    love.graphics.rectangle("fill", 0, 0, SCREEN_WIDTH, SCREEN_HEIGHT)
end

function WeatherOverlay:drawDarkRainTint(alpha)
    Draw.setColor(29/255, 29/255, 40/255, alpha or 150/255)
    love.graphics.rectangle("fill", 0, 0, SCREEN_WIDTH, SCREEN_HEIGHT)
end

function WeatherOverlay:drawColdTint(alpha)
    Draw.setColor(108/255, 106/255, 229/255, alpha or 55/255)
    love.graphics.setBlendMode("add")
    love.graphics.rectangle("fill", 0, 0, SCREEN_WIDTH, SCREEN_HEIGHT)
    love.graphics.setBlendMode("alpha")
end

function WeatherOverlay:drawHeatTint(alpha)
    Draw.setColor(191/255, 120/255, 120/255, alpha or 51/255)
    love.graphics.rectangle("fill", 0, 0, SCREEN_WIDTH, SCREEN_HEIGHT)

    Draw.setColor(121/255, 50/255, 50/255, 15/255)
    love.graphics.setLineWidth(2)
    for y = 24, SCREEN_HEIGHT, 30 do
        local sway = math.sin(y / 18 + self.heat_offset * 4) * 3
        love.graphics.line(0, y + sway, SCREEN_WIDTH, y - sway)
    end
end

function WeatherOverlay:drawFog(alpha)
    local texture = Assets.getTexture("world/fog")
    if not texture then return end

    local scale = 2
    local width, height = texture:getWidth() * scale, texture:getHeight() * scale
    Draw.setColor(0.85, 0.9, 1, alpha or 0.3)
    for x = -width, SCREEN_WIDTH + width, width do
        for y = -height, SCREEN_HEIGHT + height, height do
            love.graphics.draw(texture, x + self.fog_offset, y, 0, scale, scale)
        end
    end
end

return WeatherOverlay
