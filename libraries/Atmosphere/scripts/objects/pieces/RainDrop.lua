---@class RainDrop : Object
---@field number string
---@field speed number
---@field rainsprite Sprite
---@field handler Rain
---@field splash_travel number
---@field splash_checked boolean
local RainDrop, super = Class(Object)

function RainDrop:init(number, x, y, speed, handler, sprite_path)
    super.init(self, x, y)
    self.number = number
    self.speed = speed or 20
    self.handler = handler
    self.addto = handler.addto
    self.alpha = 0.5

    self:setLayer(((self.addto == Game.battle) and BATTLE_LAYERS["below_ui"] or WORLD_LAYERS["below_ui"]) - 1)
    self.rainsprite = Sprite((sprite_path or "world/rain/") .. number)
    self.rainsprite:setScale(2)
    self.rainsprite.inherit_color = true
    self.initx, self.inity = self.x, self.y
    self.splash_travel = MathUtils.random(SCREEN_HEIGHT * 0.2, SCREEN_HEIGHT * 0.95)
    self.splash_checked = false
    handler:configureHeightPiece(self, self.splash_travel, true)
end

function RainDrop:update()
    super.update(self)
    if self.handler.paused then return end

    local horizontal = self.handler.type == "flipped_rain" and 0.5 or -0.5
    horizontal = horizontal + (self.handler.wind_direction or 0) * (self.handler.wind_strength or 0)
    self.x = self.x + self.speed * horizontal * DTMULT
    if self.weather_height_enabled then
        local landed, landing_z, collider, surface =
            self.handler:advanceHeightPiece(self, self.speed * DTMULT)
        if landed then
            self:spawnSplashIfWalkable(landing_z, collider, surface)
            self:remove()
            return
        end
    else
        self.y = self.y + self.speed * DTMULT

        if not self.splash_checked and self.y - self.inity >= self.splash_travel then
            self.splash_checked = true
            if self:spawnSplashIfWalkable() then
                self:remove()
                return
            end
        end
    end

    local screen_x, screen_y = self:localToScreenPos(0, 0)
    if screen_y > SCREEN_HEIGHT + 80 or screen_x < -120 or screen_x > SCREEN_WIDTH + 120 then
        self:remove()
    end
end

function RainDrop:spawnSplashIfWalkable(landing_z, landing_collider, landing_surface)
    if self.addto ~= Game.world or self.handler:isInside() then return false end
    if not (Game.world and Game.world.map and Game.world.inBounds and Game.world:inBounds(self.x, self.y)) then return false end

    local tile = Game.world:getSteppableTile(self.x, self.y)
    if not self.weather_height_enabled and not tile then return false end
    if self.weather_height_enabled and landing_z == nil then return false end

    local splash_size = 1
    local sound = tile and tile.rain_sound
    if sound and sound ~= "" then
        Assets.playSound(sound .. MathUtils.randomInt(1, 2), 0.1, 1 + MathUtils.random(-0.15, 0.15))
        splash_size = 2
    end

    local splash = Splash(self.x, self.y, self.addto, splash_size)
    if self.weather_height_enabled then
        self.handler:configureHeightPiece(splash, landing_z, false)
        splash.height_depth_offset = 0.05
        splash.ground_collider = landing_collider
        splash.ground_surface = landing_surface
    end
    self.addto:addChild(splash)
    splash:setLayer(self.layer)
    return true
end

function RainDrop:draw()
    super.draw(self)
    love.graphics.setBlendMode("add")
    self.rainsprite:drawAlpha(0.4 * self.alpha)
    love.graphics.setBlendMode("alpha")
    Draw.setColor(1, 1, 1, 1)
end

return RainDrop
