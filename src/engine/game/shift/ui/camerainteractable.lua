--- An interactable positioned within a [`ShiftCamera`](lua://ShiftCamera)'s panoramic
--- coordinates rather than screen coordinates.
---@class CameraInteractable : ShiftInteractable
---@field camera ShiftCamera?
---@overload fun(x?: number, y?: number, width?: number, height?: number) : CameraInteractable
local CameraInteractable, super = Class(ShiftInteractable)

---@param x? number
---@param y? number
---@param width? number
---@param height? number
function CameraInteractable:init(x, y, width, height)
    super.init(self, x, y, width, height)
    self.camera = nil
end

return CameraInteractable