--- camera map b ut ton
---@class CameraMapButton : PanelButton
---@field target_camera ShiftCamera
---@field label string
---@overload fun(camera: ShiftCamera, label?: string, x?: number, y?: number, width?: number, height?: number): CameraMapButton
local CameraMapButton, super = Class(PanelButton)

function CameraMapButton:init(camera, label, x, y, width, height)
    super.init(self, x or 0, y or 0, width or 58, height or 24)
    self.target_camera = camera
    self.label = label or camera.name or camera.id or "CAM"
end

function CameraMapButton:onClick(button, x, y, presses)
    self.panel:setCamera(self.target_camera)
end

function CameraMapButton:draw()
    local selected = self.panel.selected_camera == self.target_camera
    Draw.setColor(selected and { 1, 1, 1, 0.95 }
        or { 0, 0, 0, self.hovered and 0.8 or 0.55 })
    love.graphics.rectangle("fill", 0, 0, self.width, self.height)
    Draw.setColor(selected and { 0, 0, 0, 1 } or { 1, 1, 1, 1 })
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", 0, 0, self.width, self.height)
    love.graphics.setLineWidth(1)
    love.graphics.setFont(Assets.getFont("main", 10))
    love.graphics.printf(self.label, 2, math.floor((self.height - 10) / 2), self.width - 4, "center")
    super.draw(self)
end

return CameraMapButton
