local CameraButton, button_super = Class(PanelButton)

---@param camera ShiftCamera
---@param label string
---@param x number
---@param y number
function CameraButton:init(camera, label, x, y)
    button_super.init(self, x, y, 58, 24)
    self.target_camera = camera
    self.label = label
end

function CameraButton:onClick(button, x, y, presses)
    self.panel:setCamera(self.target_camera)
end

function CameraButton:draw()
    local selected = self.panel.selected_camera == self.target_camera
    if selected then
        Draw.setColor(1, 1, 1, 0.95)
    else
        Draw.setColor(0, 0, 0, self.hovered and 0.8 or 0.55)
    end
    love.graphics.rectangle("fill", 0, 0, self.width, self.height)
    Draw.setColor(selected and 0 or 1, selected and 0 or 1, selected and 0 or 1, 1)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", 0, 0, self.width, self.height)
    love.graphics.setLineWidth(1)
    love.graphics.setFont(Assets.getFont("main", 10))
    love.graphics.printf(self.label, 2, 8, self.width - 4, "center")
    button_super.draw(self)
end

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
    local panel = CameraPanel()
    panel.shift = shift
    local button_layout = {
        { "CAM 1", 424, 296 },
        { "CAM 2", 486, 344 },
        { "CAM 3", 400, 392 },
    }
    for index, camera in ipairs(shift.cameras) do
        panel:addCamera(camera)
        local layout = button_layout[index]
        panel:addButton(CameraButton(camera, layout[1], layout[2], layout[3]))
    end
    shift:addChild(panel)
    self.camera_panel = panel
end

function TestNight:drawCameraMap(panel)
    Draw.setColor(0, 0, 0, 0.5)
    love.graphics.rectangle("fill", 370, 262, 208, 174)

    Draw.setColor(1, 1, 1, 0.75)
    love.graphics.setLineWidth(2)
    love.graphics.line(453, 328, 515, 356)
    love.graphics.line(487, 374, 438, 404)
    love.graphics.rectangle("line", 398, 278, 116, 66)
    love.graphics.rectangle("line", 458, 326, 112, 70)
    love.graphics.rectangle("line", 380, 374, 112, 58)
    love.graphics.setLineWidth(1)
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
