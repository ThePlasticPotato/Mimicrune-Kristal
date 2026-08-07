local TestNight, super = Class(Night)

function TestNight:init()
    super.init(self)

    self.name = "Shift Framework Test"
    self.office = "test"
    self.duration = 90
    self.max_power = 100
    self.base_power_usage = 1
    self.power_drain_rate = 0.2
    self.power_out_delay = 2
    self.victory_duration = 2
    self:addAnimatronic("test", 8)

    self.camera_panel = nil
end

function TestNight:onShiftInit(shift)
    return super.onShiftInit(self, shift)
end

function TestNight:onKeyPressed(key)
    if key == "space" and self.camera_panel then
        self.camera_panel:toggle()
        return true
    elseif key == "escape" and self.camera_panel and self.camera_panel.state ~= "CLOSED" then
        self.camera_panel:close()
        return true
    end
end

function TestNight:draw()
    if not Game.shift or Game.shift.state ~= "GAMEPLAY" then return end
    if self.camera_panel and self.camera_panel.state ~= "CLOSED" then return end
    Draw.setColor(0, 0, 0, 0.65)
    love.graphics.rectangle("fill", 8, 8, 220, 54)
    Draw.setColor(1, 1, 1, 1)
    love.graphics.setFont(Assets.getFont("main", 16))
    love.graphics.print(string.format("%d AM   POWER %d", Game.shift:getDisplayHour(), math.ceil(Game.shift.power)), 16, 16)
    love.graphics.print("SPACE: CAMERAS", 16, 38)
end

return TestNight
