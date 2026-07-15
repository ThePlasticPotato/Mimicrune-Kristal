local RainPiece, super = Class(Object)

function RainPiece:init(number, x, y, speed, handler)
    super.init(self)
    self:setPosition(x, y)
    self.number = number
    self.speed = speed or 2
    if handler.addto == Game.world then
        self:setLayer(WORLD_LAYERS["below_ui"] - 1)
    elseif handler.addto == Game.battle then
        self:setLayer(BATTLE_LAYERS["below_ui"] - 1)
    end
    self.alpha = 0.5

    self.rainsprite = Sprite("world/rain/"..number)
    self.rainsprite:setScale(2)
    self.rainsprite.inherit_color = true
    self:setPosition(self.x, self.y - (self.rainsprite.height * 2))
    --self:addChild(self.rainsprite)
    self.initx, self.inity = self.x, self.y

    self.addto = handler.addto
    self.handler = handler

    self.splash_point = PointCollider(self, 0, self.rainsprite.height * 2)
    -- Random depth into the screen at which this piece will attempt to splash
    self.splash_travel = math.random(SCREEN_HEIGHT * 0.05, SCREEN_HEIGHT * 1.15)
    self.splash_checked = false
end

function RainPiece:update()
    super.update(self)

    if not Game.stage.weather_layer then
        if self.handler.addto == Game.world then
            if self.parent ~= Game.world then
                local newx, newy = self.parent:getRelativePos(self.x, self.y, Game.world)
                self.parent:removeChild(self)
                Game.world:addChild(self)
                self:setPosition(newx, newy)
            end
            if self.layer ~= WORLD_LAYERS["below_ui"] - 1 then
                self:setLayer(WORLD_LAYERS["below_ui"] - 1)
            end
        elseif self.handler.addto == Game.battle then
            if self.parent ~= Game.battle then
                local newx, newy = self.parent:getRelativePos(self.x, self.y, Game.battle)
                self.parent:removeChild(self)
                Game.battle:addChild(self)
                self:setPosition(newx, newy)
            end

            if self.layer ~= BATTLE_LAYERS["below_ui"] - 1 then
                self:setLayer(BATTLE_LAYERS["below_ui"] - 1)
            end
        end
    else 
        if self.layer ~= Game.stage.weather_layer - 1 then self:setLayer(Game.stage.weather_layer - 1) end
    end
    
    self.x, self.y = self.x - self.speed * 0.5 * DTMULT, self.y + self.speed * DTMULT

    local _, y = self:getRelativePos(self.x, self.y, self.addto)
    local y2 = Game.world.camera.y + (SCREEN_HEIGHT/2)
    local x2 = Game.world.camera.x - (SCREEN_WIDTH/2)

    -- One-time walkability check at a random depth into the screen
    if not self.splash_checked and self.y - self.inity >= self.splash_travel then
        self.splash_checked = true
        if self:spawnSplashIfWalkable() then
            self:remove()
            return
        end
    end

    if self.y > y2 then self:remove() end
    --if self.x < x2 then self:remove() end

    if self.y - self.inity > (Game.world.map.height * Game.world.map.tile_height) + 120 then
        MathUtils.approach(self.rainsprite.alpha, 0, DTMULT)
        if self.alpha < 1 then self:remove() end
    end
end

function RainPiece:spawnSplashIfWalkable()
    if self.addto ~= Game.world then return false end
    if not (Game.world and Game.world.map) then return false end
    if (Game.world.map.inside) then return false end
    if not Game.world:inBounds(self.x, self.y) then return false end
    -- if Game.world:checkCollision(self.splash_point, false) then
    --     return false
    -- end
    local tile = Game.world:getSteppableTile(self.x, self.y)
    if tile then
        local splashsize = 1
        if tile["step_sound"] then
            local sound = tile["step_sound"]
            local randpitch = MathUtils.random(-0.15, 0.15)
            if sound and StringUtils.contains(sound, "glass") then
                Assets.playSound("step/heavyglass" .. MathUtils.randomInt(1,3), 0.1, 1 + randpitch)
                splashsize = 2
            end
        end
        if (Game.world and Game.world.map) then
            local lake = Game.world.map:getEvent("smalllake")
            if lake then
                if (self.x <= (lake.x + lake.width/2)) and (self.x >= (lake.x - lake.width/2)) and (self.y <= (lake.y + lake.height/2)) and (self.y >= (lake.y - lake.height/2)) then
                    local screenPosX, screenPosY = lake:screenToLocalPos(self:localToScreenPos(0,0))
                    lake:spawnSplash(screenPosX, screenPosY, 5 * splashsize, 1.5, 1)
                    return true
                    --Kristal.Console:log("splsih splash")
                end
            end
        end
        local splash = RainSplash(self.x, self.y, self.addto, splashsize)
        self.addto:addChild(splash)
        splash:setLayer(Game.world.player.layer)
        return true
    end
    return false
end

function RainPiece:draw()
    super.draw(self)

    --[[local premult_shader = love.graphics.newShader
[[
  vec4 effect(vec4 colour, Image tex, vec2 texpos, vec2 scrpos)
  {
    return colour.a * vec4(colour.rgb, 1.0) * Texel(tex, texpos);
  }
]]

    --Draw.setColor(208/255, 199/255, 1, 131/255)
    Draw.setColor(1, 1, 1, 0)

    --love.graphics.setShader(premult_shader)
    love.graphics.setBlendMode("add")
    --self.rainsprite.width, self.rainsprite.height = 2, 2
    self.rainsprite:drawAlpha(0.4)
    love.graphics.setBlendMode("alpha")
    --love.graphics.setShader()
end

return RainPiece