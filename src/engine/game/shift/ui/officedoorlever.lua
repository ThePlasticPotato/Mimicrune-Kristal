--- A draggable office lever that requests a door state only at its path endpoints.
---@class OfficeDoorLever : DraggableOfficeInteractable
---@field door OfficeDoor?
---@field door_id string?
---@field door_reference string|number|table?
---@field close_resistance number Additional resistance toward the closed endpoint.
---@field open_resistance number Additional resistance toward the open endpoint.
---@field jam_limit number Furthest path progress allowed while the linked door is jammed open.
---@field jam_shake number Vertical sprite shake while pressing against a jammed limit.
---@field jam_creak_interval number Seconds between creaks while pressing against a jam.
---@field jam_pressure boolean Whether the player is actively pulling against the jammed stop.
---@overload fun(office?: Office, door?: OfficeDoor|string, x?: number, y?: number, width?: number, height?: number): OfficeDoorLever
local OfficeDoorLever, super = Class(DraggableOfficeInteractable)

function OfficeDoorLever:init(office, door, x, y, width, height)
    super.init(self, x, y, width, height)
    self:setSprite("ui/shift/objects/door_lever_left")
    self.close_resistance = 1.35
    self.open_resistance = 1
    self.drag_inertia = 0.65
    self.auto_return = true
    self.return_delay = 0.2
    self.return_speed = 0.45
    self.jam_limit = 0.5
    self.jam_shake = 1
    self.jam_creak_interval = 0.65
    self.jam_creak_timer = 0
    self.jam_feedback_active = false
    self.jam_pressure = false
    self.office = office
    local door_object = type(door) == "table" and door.includes
        and door:includes(OfficeDoor) and door or nil
    self.door = door_object
    self.door_reference = door_object and nil or door
    self.door_id = type(door) == "string" and door or (door_object and door_object.id or nil)
end

function OfficeDoorLever:onReturnStarted()
    self:playCreak(0.5)
end

---@param volume? number
function OfficeDoorLever:playCreak(volume)
    Assets.playSound("doorlever_creak", volume or 0.5)
end

function OfficeDoorLever:resolveDoor()
    if self.door and self.door.includes and self.door:includes(OfficeDoor) then return self.door end
    if self.office then
        self.door = self.office:getDoor(self.door_reference or self.door_id)
    end
    return self.door
end

---@param office Office
function OfficeDoorLever:onAddedToOffice(office)
    self.office = office
    self:resolveDoor()
end

---@param definition table
function OfficeDoorLever:applyLayoutDefinition(definition)
    super.applyLayoutDefinition(self, definition)
    self.close_resistance = math.max(0.01,
        tonumber(definition.close_resistance) or self.close_resistance)
    self.open_resistance = math.max(0.01,
        tonumber(definition.open_resistance) or self.open_resistance)
    self.jam_limit = MathUtils.clamp(
        tonumber(definition.jam_limit) or self.jam_limit, 0, 1)
    self.jam_shake = math.max(0,
        tonumber(definition.jam_shake) or self.jam_shake)
    self.jam_creak_interval = math.max(0.05,
        tonumber(definition.jam_creak_interval) or self.jam_creak_interval)
    local reference = definition.door or definition.target
    if reference ~= nil then
        self.door = nil
        self.door_reference = reference
        self.door_id = type(reference) == "string" and reference or nil
    end
    self:resolveDoor()
end

---@return boolean
function OfficeDoorLever:isDoorJammedOpen()
    local door = self:resolveDoor()
    return door ~= nil and door.jammed and door:isOpen()
end

---@param progress number
---@param silent? boolean
function OfficeDoorLever:setProgress(progress, silent)
    progress = progress or 0
    if self:isDoorJammedOpen() then
        self.jam_pressure = progress > self.jam_limit + self.endpoint_threshold
        progress = math.min(progress, self.jam_limit)
    else
        self.jam_pressure = false
    end
    super.setProgress(self, progress, silent)
end

function OfficeDoorLever:onPressed(button, x, y, presses)
    self.jam_pressure = false
    return super.onPressed(self, button, x, y, presses)
end

function OfficeDoorLever:onReleased(button, x, y, presses)
    self.jam_pressure = false
    super.onReleased(self, button, x, y, presses)
end

---@param progress_delta number
---@return number resistance
function OfficeDoorLever:getDragResistance(progress_delta)
    local directional = progress_delta > 0 and self.close_resistance or self.open_resistance
    return super.getDragResistance(self, progress_delta) * directional
end

function OfficeDoorLever:onPathEndpoint(endpoint)
    local door = self:resolveDoor()
    if not door then return end
    local changed
    if endpoint == "start" then
        changed = door:open()
    else
        changed = door:close()
    end
    self:onLeverActivated(endpoint, door, changed)
end

function OfficeDoorLever:updateJamFeedback()
    local at_limit = self:isDoorJammedOpen()
        and self.progress >= self.jam_limit - self.endpoint_threshold
    local active = self.pressed and at_limit and self.jam_pressure

    if active then
        if not self.jam_feedback_active then
            self.jam_feedback_active = true
            self.jam_creak_timer = 0
            if self.sprite and self.jam_shake > 0 then
                self.sprite:shake(0, self.jam_shake, 0, 2 / 30)
            end
        end
        self.jam_creak_timer = self.jam_creak_timer - DT
        if self.jam_creak_timer <= 0 then
            self:playCreak(0.35)
            self.jam_creak_timer = self.jam_creak_interval
        end
    elseif self.jam_feedback_active then
        self.jam_feedback_active = false
        self.jam_creak_timer = 0
        if self.sprite then self.sprite:stopShake() end
    end
end

function OfficeDoorLever:update()
    super.update(self)
    self:updateJamFeedback()
end

function OfficeDoorLever:onRemove(parent)
    if self.sprite then self.sprite:stopShake() end
    super.onRemove(self, parent)
end

--- *(Override)* Called after an endpoint requests its corresponding door state.
---@param endpoint "start"|"end"
---@param door OfficeDoor
---@param changed boolean
function OfficeDoorLever:onLeverActivated(endpoint, door, changed) end

return OfficeDoorLever
