--- A camera controlling variant of [`ShiftPanel`](lua://ShiftPanel). It owns the camera map
--- controls and exposes the currently selected [`ShiftCamera`](lua://ShiftCamera).
---@class CameraPanel : ShiftPanel
---@field cameras ShiftCamera[]
---@field camera ShiftCamera?
---@overload fun(x?: number, y?: number, width?: number, height?: number) : CameraPanel
local CameraPanel, super = Class(ShiftPanel)

---@param x? number
---@param y? number
---@param width? number
---@param height? number
function CameraPanel:init(x, y, width, height)
    super.init(self, x, y, width, height)

    self.cameras = {}
    self.camera = nil
end

---@param camera ShiftCamera
function CameraPanel:addCamera(camera)
    if not TableUtils.contains(self.cameras, camera) then
        table.insert(self.cameras, camera)
    end
end

---@param camera ShiftCamera|string|nil
function CameraPanel:setCamera(camera)
    local shift = self.shift or Game.shift
    if type(camera) == "string" and shift then
        camera = shift:getCamera(camera)
    end
    if camera == self.camera then return end

    local old = self.camera
    self.camera = camera
    if shift then shift:setCamera(camera) end
    self:onCameraChanged(camera, old)
end

---@param camera ShiftCamera?
---@param old ShiftCamera?
function CameraPanel:onCameraChanged(camera, old) end

function CameraPanel:onClosed()
    self:setCamera(nil)
end

return CameraPanel