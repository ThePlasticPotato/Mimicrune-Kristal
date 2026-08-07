local CameraMapLayer, map_super = Class(Object)

---@param panel CameraPanel
function CameraMapLayer:init(panel)
    map_super.init(self, 0, 0, panel.screen_width, panel.screen_height)
    self.panel = panel
    self.layer = 10
end

function CameraMapLayer:draw()
    local shift = self.panel.shift or Game.shift
    if shift then shift.night:drawCameraMap(self.panel) end
    map_super.draw(self)
end

--- A camera controlling variant of [`ShiftPanel`](lua://ShiftPanel). It owns the camera map
--- controls and exposes the currently selected [`ShiftCamera`](lua://ShiftCamera).
---@class CameraPanel : ShiftPanel
---@field cameras ShiftCamera[]
---@field selected_camera ShiftCamera?
---@field camera_container Object
---@field map_layer Object
---@overload fun(x?: number, y?: number, width?: number, height?: number) : CameraPanel
local CameraPanel, super = Class(ShiftPanel)

---@param x? number
---@param y? number
---@param width? number
---@param height? number
function CameraPanel:init(x, y, width, height)
    super.init(self, x, y, width or SCREEN_WIDTH, height or SCREEN_HEIGHT)

    self.cameras = {}
    self.selected_camera = nil
    self:setBackground("ui/shift/panels/camera/menu")
    self:setScreenBounds(21, 21, 618, 475)
    self:setSounds("camera_open", "camera_close", "ui_static")
    self.screen_crt = false

    self.camera_container = self:addScreenChild(Object(0, 0, SCREEN_WIDTH, SCREEN_HEIGHT))
    self.camera_container:setScale(
        self.screen_width / SCREEN_WIDTH,
        self.screen_height / SCREEN_HEIGHT
    )
    self.camera_container.layer = 0
    self.camera_container:vhs({ SCREEN_WIDTH, SCREEN_HEIGHT }, "static_gray", true)
    self.map_layer = self:addScreenChild(CameraMapLayer(self))
end

---@param camera ShiftCamera
function CameraPanel:addCamera(camera)
    if not TableUtils.contains(self.cameras, camera) then
        table.insert(self.cameras, camera)

        if camera.parent then
            local old_parent = camera.parent
            old_parent:removeChild(camera)
            old_parent:updateChildList()
            old_parent.update_child_list = false
        end
        self.camera_container:addChild(camera)
    end
end

---@param button PanelButton
---@return PanelButton button
function CameraPanel:addButton(button)
    button = super.addButton(self, button)
    button.layer = 20
    return button
end

---@param camera ShiftCamera|string|nil
function CameraPanel:setCamera(camera)
    local shift = self.shift or Game.shift
    if type(camera) == "string" and shift then
        camera = shift:getCamera(camera)
    end
    if camera == self.selected_camera then return end

    local old = self.selected_camera
    self.selected_camera = camera
    if shift then shift:setCamera(camera) end
    self:onCameraChanged(camera, old)
end

---@param camera ShiftCamera?
---@param old ShiftCamera?
function CameraPanel:onCameraChanged(camera, old) end

function CameraPanel:onStateChange(old, new)
    if new == "OPENING" and not self.selected_camera and self.cameras[1] then
        self:setCamera(self.cameras[1])
    end
end

function CameraPanel:onOpened()
    if not self.selected_camera and self.cameras[1] then
        self:setCamera(self.cameras[1])
    end
    local shift = self.shift or Game.shift
    if shift then shift:checkOfficeAttack(self) end
end

function CameraPanel:onClosed()
    self:setCamera(nil)
end

return CameraPanel
