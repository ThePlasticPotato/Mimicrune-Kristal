---@class Snowflake : Object
local Snowflake, super = Class(Object)

function Snowflake:init(sprite, x, y, speed, rotation_speed, sway_speed, handler)
    super.init(self, x, y)
    self.handler = handler
    self.speed = speed
    self.rotation_speed = rotation_speed
    self.sway_speed = sway_speed
    self.phase = MathUtils.random(0, math.pi * 2)
    self.alpha = MathUtils.random(0.35, 0.95)
    self.flake = Sprite("world/snow/" .. sprite)
    self.flake:setOrigin(0.5, 0.5)
    self:setLayer(((handler.addto == Game.battle) and BATTLE_LAYERS["below_ui"] or WORLD_LAYERS["below_ui"]) - 1)
    handler:configureHeightPiece(
        self, MathUtils.random(SCREEN_HEIGHT * 0.2, SCREEN_HEIGHT * 0.95), true)
end

function Snowflake:update()
    super.update(self)
    if self.handler.paused then return end
    self.x = self.x + math.sin(Kristal.getTime() * self.sway_speed + self.phase) * 0.8 * DTMULT
    self.x = self.x + (self.handler.wind_direction or 0) * (self.handler.wind_strength or 0) * DTMULT
    self.rotation = self.rotation + self.rotation_speed * DT
    if self.weather_height_enabled then
        local landed = self.handler:advanceHeightPiece(self, self.speed * DTMULT)
        if landed then
            self:remove()
            return
        end
    else
        self.y = self.y + self.speed * DTMULT
    end

    local screen_x, screen_y = self:localToScreenPos(0, 0)
    if screen_y > SCREEN_HEIGHT + 30 or screen_x < -50 or screen_x > SCREEN_WIDTH + 50 then self:remove() end
end

function Snowflake:draw()
    super.draw(self)
    love.graphics.setBlendMode("add")
    self.flake:drawAlpha(self.alpha)
    love.graphics.setBlendMode("alpha")
end

return Snowflake
