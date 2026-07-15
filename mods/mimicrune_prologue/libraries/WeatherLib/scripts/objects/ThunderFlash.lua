local ThunderFlash, super = Class(Object)

local mask_effect = love.graphics.newShader[[
   vec4 effect (vec4 color, Image texture, vec2 texture_coords, vec2 screen_coords) {
      if (Texel(texture, texture_coords).rgb == vec3(0.0)) {
         // a discarded pixel wont be applied as the stencil.
         discard;
      }
      return vec4(1.0);
   }
]]

function ThunderFlash:init(handler)
    super.init(self)
    self.parallax_x, self.parallax_y = 0, 0
    self.flashtimer, self.flashtime = 20, 30
    if not Game.stage.weather_layer then
        if handler and handler.addto == Game.world then
            self:setLayer(WORLD_LAYERS["below_ui"] + 1)
        elseif handler and handler.addto == Game.battle then
            self:setLayer(BATTLE_LAYERS["below_ui"] + 1)
        end
    else
        self:setLayer(Game.stage.weather_layer + 1)
    end
    self.mask = Game.stage:getWeatherInverseMask()
    self.darken_mask = Game.stage:getWeatherMask()
end

function ThunderFlash:stencil()
    love.graphics.setShader(mask_effect)
    love.graphics.draw(self.mask, 0, 0)
    love.graphics.setShader()
end

function ThunderFlash:inverseStencil()
    love.graphics.setShader(mask_effect)
    love.graphics.draw(self.darken_mask, 0, 0)
    love.graphics.setShader()
end

function ThunderFlash:update()
    self.flashtimer = self.flashtimer - DTMULT

    if self.flashtimer <= 0 then self:remove() end
    super.update(self)
end

function ThunderFlash:draw()
    super.draw(self)

    local inside = Game.world.map.inside

    if (inside and self.mask) then
        love.graphics.setStencil(self.stencil)
    end

    love.graphics.setBlendMode("add")
    Draw.setColor(1, 1, 1, self.flashtimer/self.flashtime)
    love.graphics.rectangle("fill", 0, 0, SCREEN_WIDTH, SCREEN_HEIGHT)
    love.graphics.setBlendMode("alpha")

    if (inside and self.mask) then
        love.graphics.setStencil()
    end
end

return ThunderFlash