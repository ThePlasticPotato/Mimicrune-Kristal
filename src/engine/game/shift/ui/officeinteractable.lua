--- An interactable positioned within an [`Office`](lua://Office)'s panoramic coordinates,
--- used for controls such as door buttons and levers.
---@class OfficeInteractable : ShiftInteractable
---@field office Office?
---@overload fun(x?: number, y?: number, width?: number, height?: number) : OfficeInteractable
local OfficeInteractable, super = Class(ShiftInteractable)

---@param x? number
---@param y? number
---@param width? number
---@param height? number
function OfficeInteractable:init(x, y, width, height)
    super.init(self, x, y, width, height)
    self.office = nil
end

return OfficeInteractable