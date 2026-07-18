---@class ScreenColorOverlay : Object
---@overload fun(color?: table, opacity?: number) : ScreenColorOverlay
local ScreenColorOverlay, super = Class(Object)

function ScreenColorOverlay:init(color, opacity)
    super.init(self, 0, 0, SCREEN_WIDTH, SCREEN_HEIGHT)

    self.parallax_x = 0
    self.parallax_y = 0
    self.debug_select = false
    self.overlay_color = color or COLORS.black
    self.alpha = opacity or 0
end

function ScreenColorOverlay:draw()
    if self.alpha <= 0 then return end

    Draw.setColor(
        self.overlay_color[1],
        self.overlay_color[2],
        self.overlay_color[3],
        self.alpha * (self.overlay_color[4] or 1)
    )
    love.graphics.rectangle("fill", 0, 0, SCREEN_WIDTH, SCREEN_HEIGHT)
end

return ScreenColorOverlay
