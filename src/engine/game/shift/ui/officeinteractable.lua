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

---@param x number
---@param y number
---@return number x
---@return number y
function OfficeInteractable:perspectiveCursorPosition(x, y)
    if self.office and self.parent == self.office.panorama then
        return self.office:screenToPanoramaSource(x, y)
    end
    return x, y
end

---@param x number
---@param y number
---@return boolean
function OfficeInteractable:containsPerspectivePoint(x, y)
    x, y = self:perspectiveCursorPosition(x, y)
    if self.collider then
        return self.collider:collidesWith(PointCollider(nil, x, y))
    end
    local local_x, local_y = self:getFullTransform():inverseTransformPoint(x, y)
    local rect = self:getDebugRectangle() or { 0, 0, self.width, self.height }
    return local_x >= rect[1] and local_x < rect[1] + rect[3]
        and local_y >= rect[2] and local_y < rect[2] + rect[4]
end

function OfficeInteractable:mouseHovered()
    local x, y = Input.getCurrentCursorPosition()
    return x ~= nil and y ~= nil and self:containsPerspectivePoint(x, y)
end

function OfficeInteractable:clicked(button)
    if not button then return super.clicked(self, button) end
    local pressed, x, y = Input.mousePressed(button)
    return pressed and self:containsPerspectivePoint(x, y), button
end

return OfficeInteractable
