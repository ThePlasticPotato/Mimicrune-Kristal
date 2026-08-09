--- A positioned, clickable or draggable object anchored to shift screen coordinates.
---@class ShiftInteractable : Object
---@field enabled boolean
---@field hovered boolean
---@field pressed boolean
---@field dragging boolean
---@field mouse_button integer
---@field callback fun(self: ShiftInteractable, button: integer, x: number, y: number)?
---@overload fun(x?: number, y?: number, width?: number, height?: number) : ShiftInteractable
local ShiftInteractable, super = Class(Object)

---@param x? number
---@param y? number
---@param width? number
---@param height? number
function ShiftInteractable:init(x, y, width, height)
    super.init(self, x, y, width, height)

    self.enabled = true
    self.hovered = false
    self.pressed = false
    self.dragging = false
    self.mouse_button = 1
    self.callback = nil
end

---@return boolean
function ShiftInteractable:canInteract()
    return self.enabled and self.active and self.visible
end

---@param x number
---@param y number
function ShiftInteractable:onMouseEnter(x, y) end

---@param x number
---@param y number
function ShiftInteractable:onMouseLeave(x, y) end

---@param button integer
---@param x number
---@param y number
---@param presses integer
---@return boolean?
function ShiftInteractable:onPressed(button, x, y, presses) end

---@param button integer
---@param x number
---@param y number
---@param presses integer
function ShiftInteractable:onReleased(button, x, y, presses) end

---@param button integer
---@param x number
---@param y number
---@param presses integer
function ShiftInteractable:onClick(button, x, y, presses)
    if self.callback then self.callback(self, button, x, y) end
end

---@param button integer
---@param x number
---@param y number
---@param dx number
---@param dy number
function ShiftInteractable:onDrag(button, x, y, dx, dy) end

function ShiftInteractable:update()
    local can_interact = self:canInteract()
    local hovered = can_interact and self:mouseHovered()
    local mouse_x, mouse_y = Input.getCurrentCursorPosition()
    mouse_x, mouse_y = mouse_x or 0, mouse_y or 0

    if hovered ~= self.hovered then
        self.hovered = hovered
        if hovered then
            self:onMouseEnter(mouse_x, mouse_y)
        else
            self:onMouseLeave(mouse_x, mouse_y)
        end
    end

    if can_interact and not self.pressed then
        local clicked, button = self:clicked(self.mouse_button)
        if clicked then
            local _, x, y, presses = Input.mousePressed(button)
            self.pressed = self:onPressed(button, x, y, presses) ~= false
        end
    end

    if self.pressed then
        local down, x, y, _, dx, dy = Input.mouseDown(self.mouse_button)
        if down and ((dx or 0) ~= 0 or (dy or 0) ~= 0) then
            self.dragging = true
            self:onDrag(self.mouse_button, x, y, dx or 0, dy or 0)
        end

        local released, release_x, release_y, presses = Input.mouseReleased(self.mouse_button)
        if released then
            self:onReleased(self.mouse_button, release_x, release_y, presses)
            if self.hovered and not self.dragging then
                self:onClick(self.mouse_button, release_x, release_y, presses)
            end
            self.pressed = false
            self.dragging = false
        end
    end

    super.update(self)
end

return ShiftInteractable