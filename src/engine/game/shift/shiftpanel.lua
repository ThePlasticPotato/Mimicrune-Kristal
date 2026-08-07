--- A raiseable menu panel used during shifts.
---@class ShiftPanel : Object
---@field shift Shift?
---@field state PanelState
---@field progress number A value from `0` (closed) to `1` (open).
---@field open_time number
---@field close_time number
---@field buttons PanelButton[]
---@overload fun(x?: number, y?: number, width?: number, height?: number) : ShiftPanel
local ShiftPanel, super = Class(Object)

---@alias PanelState
---| "CLOSED"
---| "OPENING"
---| "OPEN"
---| "CLOSING"

---@param x? number
---@param y? number
---@param width? number
---@param height? number
function ShiftPanel:init(x, y, width, height)
    super.init(self, x, y, width or SCREEN_WIDTH, height or SCREEN_HEIGHT)

    self.shift = nil
    self.state = "CLOSED"
    self.progress = 0
    self.open_time = 0.25
    self.close_time = 0.25
    self.buttons = {}

    self.active = false
    self.visible = false
end

---@param button PanelButton
---@return PanelButton button
function ShiftPanel:addButton(button)
    table.insert(self.buttons, button)
    button.panel = self
    self:addChild(button)
    return button
end

---@return boolean changed
function ShiftPanel:open()
    if self.state == "OPEN" or self.state == "OPENING" then return false end
    local old = self.state
    self.state = "OPENING"
    self.active = true
    self.visible = true
    local shift = self.shift or Game.shift
    if shift then shift:setPanel(self) end
    self:onStateChange(old, self.state)
    return true
end

---@return boolean changed
function ShiftPanel:close()
    if self.state == "CLOSED" or self.state == "CLOSING" then return false end
    local old = self.state
    self.state = "CLOSING"
    self:onStateChange(old, self.state)
    return true
end

---@return boolean changed
function ShiftPanel:toggle()
    if self.state == "CLOSED" or self.state == "CLOSING" then
        return self:open()
    end
    return self:close()
end

---@param old PanelState
---@param new PanelState
function ShiftPanel:onStateChange(old, new) end

function ShiftPanel:onOpened() end
function ShiftPanel:onClosed() end

function ShiftPanel:update()
    if self.state == "OPENING" then
        local amount = self.open_time > 0 and (DT / self.open_time) or 1
        self.progress = MathUtils.approach(self.progress, 1, amount)
        if self.progress >= 1 then
            local old = self.state
            self.state = "OPEN"
            self:onStateChange(old, self.state)
            self:onOpened()
        end
    elseif self.state == "CLOSING" then
        local amount = self.close_time > 0 and (DT / self.close_time) or 1
        self.progress = MathUtils.approach(self.progress, 0, amount)
        if self.progress <= 0 then
            local old = self.state
            self.state = "CLOSED"
            self.active = false
            self.visible = false
            local shift = self.shift or Game.shift
            if shift and shift.panel == self then shift:setPanel(nil) end
            self:onStateChange(old, self.state)
            self:onClosed()
        end
    end
    super.update(self)
end

return ShiftPanel