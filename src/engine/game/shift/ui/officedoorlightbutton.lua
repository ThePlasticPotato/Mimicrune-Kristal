---@class OfficeDoorLightButton : OfficeInteractable, PowerDrainer
---@field door OfficeDoor?
---@field door_id string?
---@field door_reference string|number|table?
---@field side "left"|"right"
---@field light_on boolean
---@field power_usage number
---@field severity number
---@field source Object
---@field off_texture string
---@field on_texture string
---@field toggle_sound string
---@field jammed_sound string
---@field drone_sound string
---@field drone_volume number
---@field presence_sound string
---@field presence_volume number
---@field announced_animatronics table<ShiftAnimatronic, boolean>
---@field drone Sound?
---@field sprite Sprite
---@overload fun(office?: Office, door?: OfficeDoor|string|table, side?: "left"|"right", x?: number, y?: number, width?: number, height?: number): OfficeDoorLightButton
local OfficeDoorLightButton, super = Class(OfficeInteractable)

function OfficeDoorLightButton:init(office, door, side, x, y, width, height)
    super.init(self, x, y, width or 22, height or 33)
    self.office = office
    local door_object = type(door) == "table" and door.includes
        and door:includes(OfficeDoor) and door or nil
    self.door = door_object
    self.door_reference = door_object and nil or door
    self.door_id = type(door) == "string" and door or nil
    self.side = side == "right" and "right" or "left"
    self.light_on = false
    self.power_usage = 1
    self.severity = 1
    self.source = self
    self.toggle_sound = "doorlight_toggle"
    self.jammed_sound = "doorlight_jammed"
    self.drone_sound = "doorlight_drone_loop"
    self.drone_volume = 0.25
    self.presence_sound = "door_animatronicpresent_quick"
    self.presence_volume = 0.8
    self.announced_animatronics = {}
    self.drone = nil
    self.off_texture = "ui/shift/objects/door_button_off_" .. self.side
    self.on_texture = "ui/shift/objects/door_button_on_" .. self.side
    self.sprite = self:addChild(Sprite(self.off_texture, 0, 0))
    self.sprite.debug_select = false
    self:resolveDoor()
end

function OfficeDoorLightButton:updateSprite()
    self.sprite:setSprite(self.light_on and self.on_texture or self.off_texture)
end

function OfficeDoorLightButton:setSide(side)
    self.side = side == "right" and "right" or "left"
    self.off_texture = "ui/shift/objects/door_button_off_" .. self.side
    self.on_texture = "ui/shift/objects/door_button_on_" .. self.side
    self:updateSprite()
end

function OfficeDoorLightButton:resolveDoor()
    if not (self.door and self.door.includes and self.door:includes(OfficeDoor))
        and self.office then
        self.door = self.office:getDoor(self.door_reference or self.door_id)
    end
    if self.door then
        if self.door.light_button and self.door.light_button ~= self then
            self.door.light_button:setLight(false, true)
        end
        self.door.light_button = self
    end
    return self.door
end

---@param office Office
function OfficeDoorLightButton:onAddedToOffice(office)
    self.office = office
    self:resolveDoor()
end

---@return boolean
function OfficeDoorLightButton:canTurnOn()
    local door = self:resolveDoor()
    local shift = self.office and self.office.shift
    return door ~= nil
        and not door.jammed
        and (not self.office or not self.office.power_out)
        and (not shift or shift.power > 0)
end

function OfficeDoorLightButton:startDrone()
    if not self.drone and self.drone_sound and self.drone_sound ~= "" then
        self.drone = Assets.newSound(self.drone_sound)
        self.drone:setLooping(true)
        self.drone:setVolume(self.drone_volume)
    end
    if self.drone then
        self.drone:stop()
        self.drone:play()
    end
end

function OfficeDoorLightButton:stopDrone()
    if self.drone then self.drone:stop() end
end

function OfficeDoorLightButton:playPresenceCue()
    local door = self:resolveDoor()
    if not door then return end
    local newly_revealed = false
    for _, animatronic in ipairs(door.animatronics) do
        if not self.announced_animatronics[animatronic] then newly_revealed = true end
        self.announced_animatronics[animatronic] = true
    end
    if newly_revealed and self.presence_sound and self.presence_sound ~= "" then
        Assets.playSound(self.presence_sound, self.presence_volume)
    end
end

function OfficeDoorLightButton:refreshPresenceLatches()
    local present = {}
    local door = self:resolveDoor()
    if door then
        for _, animatronic in ipairs(door.animatronics) do present[animatronic] = true end
    end
    for animatronic in pairs(self.announced_animatronics) do
        if not present[animatronic] then self.announced_animatronics[animatronic] = nil end
    end
end

---@param light_on boolean
---@param silent? boolean
---@return boolean changed
function OfficeDoorLightButton:setLight(light_on, silent)
    light_on = light_on == true
    if light_on == self.light_on then return false end
    if light_on and not self:canTurnOn() then
        local door = self:resolveDoor()
        if door and door.jammed and not silent
            and self.jammed_sound and self.jammed_sound ~= "" then
            Assets.playSound(self.jammed_sound, 0.7)
        end
        return false
    end

    self.light_on = light_on
    self:updateSprite()
    if light_on then self:startDrone() else self:stopDrone() end
    if not silent and self.toggle_sound and self.toggle_sound ~= "" then
        Assets.playSound(self.toggle_sound, 0.7)
    end
    if light_on and not silent then self:playPresenceCue() end
    self:onLightChanged(light_on)
    return true
end

---@return boolean changed
function OfficeDoorLightButton:toggleLight()
    return self:setLight(not self.light_on)
end

---@param light_on boolean
function OfficeDoorLightButton:onLightChanged(light_on) end

---@return boolean
function OfficeDoorLightButton:isPowerDraining()
    return self.light_on
end

function OfficeDoorLightButton:onClick(button, x, y, presses)
    if button == self.mouse_button then self:toggleLight() end
    super.onClick(self, button, x, y, presses)
end

function OfficeDoorLightButton:onMouseEnter(x, y)
    Kristal.setCursorType("select")
end

function OfficeDoorLightButton:onMouseLeave(x, y)
    Kristal.setCursorType("default")
end

---@param definition table
function OfficeDoorLightButton:applyLayoutDefinition(definition)
    local side = definition.side or self.side
    self:setSide(side)
    self.off_texture = type(definition.off_texture) == "string" and definition.off_texture ~= ""
        and definition.off_texture or self.off_texture
    self.on_texture = type(definition.on_texture) == "string" and definition.on_texture ~= ""
        and definition.on_texture or self.on_texture
    self.power_usage = math.max(0, tonumber(definition.power_usage) or self.power_usage)
    self.severity = math.max(0, tonumber(definition.severity) or self.severity)
    self.drone_volume = math.max(0, tonumber(definition.drone_volume) or self.drone_volume)
    self.presence_volume = math.max(0,
        tonumber(definition.presence_volume) or self.presence_volume)
    self.toggle_sound = definition.toggle_sound or self.toggle_sound
    self.jammed_sound = definition.jammed_sound or self.jammed_sound
    self.drone_sound = definition.drone_sound or self.drone_sound
    self.presence_sound = definition.presence_sound or self.presence_sound
    local reference = definition.door or definition.target
    if reference ~= nil then
        if self.door and self.door.light_button == self then self.door.light_button = nil end
        self.door = nil
        self.announced_animatronics = {}
        self.door_reference = reference
        self.door_id = type(reference) == "string" and reference or nil
    end
    self:updateSprite()
    self:resolveDoor()
end

function OfficeDoorLightButton:update()
    self:refreshPresenceLatches()
    if self.light_on and not self:canTurnOn() then self:setLight(false, true) end
    super.update(self)
end

function OfficeDoorLightButton:onRemove(parent)
    self:stopDrone()
    if self.door and self.door.light_button == self then self.door.light_button = nil end
    if self.hovered then Kristal.setCursorType("default") end
    super.onRemove(self, parent)
end

return OfficeDoorLightButton
