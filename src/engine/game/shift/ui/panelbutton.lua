--- An interactable button belonging to a [`ShiftPanel`](lua://ShiftPanel).
---@class PanelButton : ShiftInteractable
---@field panel ShiftPanel?
---@field label string?
---@field selected boolean
---@overload fun(x?: number, y?: number, width?: number, height?: number) : PanelButton
local PanelButton, super = Class(ShiftInteractable)

---@param x? number
---@param y? number
---@param width? number
---@param height? number
function PanelButton:init(x, y, width, height)
    super.init(self, x, y, width, height)

    self.panel = nil
    self.label = nil
    self.selected = false
end

---@return boolean
function PanelButton:canInteract()
    return super.canInteract(self) and (not self.panel or self.panel.state == "OPEN")
end

return PanelButton
