--- A powered barrier such as an office door or vent seal. It drains power only while closed.
---@class OfficeDoor : ShiftMoveTarget, PowerDrainer
---@field id string
---@field office Office?
---@field state DoorState
---@field source Object
---@field power_usage number
---@field severity number
---@field locked boolean
---@field jammed boolean
---@field jammer ShiftAnimatronic?
---@field transition_time number
---@field transition_timer number
---@overload fun(x?: number, y?: number, width?: number, height?: number) : OfficeDoor
local OfficeDoor, super = Class(ShiftMoveTarget)

---@alias DoorState
---| "OPENING"
---| "OPEN"
---| "CLOSING"
---| "CLOSED"

---@param x? number
---@param y? number
---@param width? number
---@param height? number
function OfficeDoor:init(x, y, width, height)
    super.init(self, x, y, width, height)

    self.office = nil
    self.state = "OPEN"
    self.source = self
    self.power_usage = 1
    self.severity = 1

    self.locked = false
    self.jammed = false
    self.jammer = nil
    self.transition_time = 0.25
    self.transition_timer = 0
end

---@param animatronic? ShiftAnimatronic
function OfficeDoor:jam(animatronic)
    if self.jammed then return end
    self.jammed = true
    self.jammer = animatronic
    self.locked = true
    self:onJammed(animatronic)
end

---@param animatronic? ShiftAnimatronic
function OfficeDoor:onJammed(animatronic) end

function OfficeDoor:unjam()
    if not self.jammed then return end
    local jammer = self.jammer
    self.jammed = false
    self.jammer = nil
    self.locked = false
    self:onUnjammed(jammer)
end

---@param animatronic? ShiftAnimatronic
function OfficeDoor:onUnjammed(animatronic) end

---@param state DoorState
function OfficeDoor:setState(state)
    if state == self.state then return end
    local old = self.state
    self.state = state
    self.transition_timer = 0
    self:onStateChange(old, state)
end

---@param old DoorState
---@param new DoorState
function OfficeDoor:onStateChange(old, new) end

---@param instant? boolean
---@return boolean changed
function OfficeDoor:open(instant)
    if self.locked or self.state == "OPEN" or self.state == "OPENING" then return false end
    self:setState(instant and "OPEN" or "OPENING")
    return true
end

---@param instant? boolean
---@return boolean changed
function OfficeDoor:close(instant)
    if self.locked or self.state == "CLOSED" or self.state == "CLOSING" then return false end
    self:setState(instant and "CLOSED" or "CLOSING")
    return true
end

---@param instant? boolean
---@return boolean changed
function OfficeDoor:toggle(instant)
    if self.state == "OPEN" or self.state == "OPENING" then
        return self:close(instant)
    end
    return self:open(instant)
end

---@return boolean
function OfficeDoor:isOpen()
    return self.state == "OPEN"
end

---@return boolean
function OfficeDoor:isClosed()
    return self.state == "CLOSED"
end

---@return boolean
function OfficeDoor:isMoving()
    return self.state == "OPENING" or self.state == "CLOSING"
end

---@return boolean
function OfficeDoor:isPowerDraining()
    return self.state == "CLOSED"
end

function OfficeDoor:update()
    if self:isMoving() then
        self.transition_timer = self.transition_timer + DT
        if self.transition_timer >= self.transition_time then
            self:setState(self.state == "OPENING" and "OPEN" or "CLOSED")
        end
    end
    super.update(self)
end

return OfficeDoor
