local TestCamera, super = Class(ShiftCamera)

---@param id? string
---@param name? string
---@param color? table
function TestCamera:init(id, name, color)
    super.init(self)

    self.id = id or "test_camera"
    self.name = name or "TEST CAMERA"
    self.placeholder = Assets.getTexture("placeholder")
    self.feed_color = color or { 0.55, 0.55, 0.55 }
end

function TestCamera:draw()
    if not self.layout then
        Draw.setColor(self.feed_color[1], self.feed_color[2], self.feed_color[3], 1)
        Draw.draw(
            self.placeholder,
            0,
            0,
            0,
            SCREEN_WIDTH / self.placeholder:getWidth(),
            SCREEN_HEIGHT / self.placeholder:getHeight()
        )
    end

    Draw.setColor(0, 0, 0, 0.7)
    love.graphics.rectangle("fill", 14, 14, 300, 48)
    Draw.setColor(1, 1, 1, 1)
    love.graphics.setFont(Assets.getFont("main", 24))
    love.graphics.print(self.name, 26, 24)

    love.graphics.push()
    love.graphics.translate(-self.pan, -self.pan_y)
    for index, animatronic in ipairs(self.animatronics) do
        local x = 250 + ((index - 1) * 76)
        local y = 190
        Draw.setColor(1, 0.35, 0.35, 1)
        Draw.draw(self.placeholder, x, y, 0, 2, 2)
        Draw.setColor(1, 1, 1, 1)
        love.graphics.print(animatronic.name, x - 30, y + 72)
    end
    love.graphics.pop()

    super.draw(self)
end

return TestCamera
