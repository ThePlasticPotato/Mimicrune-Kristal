---@class ZappyOverlay : Object
---@overload fun(opacity?: number) : ZappyOverlay
local ZappyOverlay, super = Class(Object)

function ZappyOverlay:init(opacity)
    super.init(self, 0, 0, SCREEN_WIDTH, SCREEN_HEIGHT)

    self.parallax_x = 0
    self.parallax_y = 0
    self.debug_select = false
    self.alpha = opacity or 0.75
    self.shader = Assets.newShader("zippy_zaps")
end

function ZappyOverlay:draw()
    if self.alpha <= 0 then return end

    self.shader:send("iTime", Kristal.getTime())
    self.shader:send("screenSize", {SCREEN_WIDTH, SCREEN_HEIGHT})

    love.graphics.push("all")
    love.graphics.origin()
    love.graphics.setBlendMode("alpha", "premultiplied")
    love.graphics.setShader(self.shader)
    Draw.setColor(1, 1, 1, self.alpha)
    love.graphics.rectangle("fill", 0, 0, SCREEN_WIDTH, SCREEN_HEIGHT)
    love.graphics.pop()
end

return ZappyOverlay
