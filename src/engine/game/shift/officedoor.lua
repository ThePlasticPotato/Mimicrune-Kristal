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
---@field close_shake_x number Horizontal screenshake when a closing transition finishes.
---@field close_shake_friction number Screenshake decay per 30 FPS frame.
---@field light_button OfficeDoorLightButton?
---@field light_hallway_sprite string? Sprite shown inside the lit doorway.
---@field light_animatronic_sprite string? Fallback sprite for animatronics waiting at this door.
---@field visual_path string? Base path containing open, opening, closing, and closed sprites.
---@field visual_sprite Sprite?
---@field visual_open_sprite string?
---@field visual_opening_sprite string?
---@field visual_closing_sprite string?
---@field visual_closed_sprite string?
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
    self.close_shake_x = 4
    self.close_shake_friction = 1
    self.light_button = nil
    self.light_hallway_sprite = nil
    self.light_animatronic_sprite = nil
    self.visual_path = nil
    self.visual_sprite = nil
    self.visual_open_sprite = nil
    self.visual_opening_sprite = nil
    self.visual_closing_sprite = nil
    self.visual_closed_sprite = nil
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
    self:updateVisualState()
    self:onStateChange(old, state)
    if old == "CLOSING" and self.state == "CLOSED" then
        self:onClosed()
    end
end

---@param old DoorState
---@param new DoorState
function OfficeDoor:onStateChange(old, new) end

--- Called when the normal closing transition reaches the closed state.
function OfficeDoor:onClosed()
    local shift = self.office and self.office.shift
    if shift and self.close_shake_x > 0 then
        shift:shake(self.close_shake_x, 0, self.close_shake_friction)
    end
end

---@param definition table
function OfficeDoor:applyLayoutDefinition(definition)
    self.transition_time = math.max(0,
        tonumber(definition.transition_time) or self.transition_time)
    self.close_shake_x = math.max(0,
        tonumber(definition.close_shake_x) or self.close_shake_x)
    self.close_shake_friction = math.max(0.01,
        tonumber(definition.close_shake_friction) or self.close_shake_friction)
    self.light_hallway_sprite = definition.light_hallway_sprite
        or self.light_hallway_sprite
    self.light_animatronic_sprite = definition.light_animatronic_sprite
        or self.light_animatronic_sprite
    self.visual_path = definition.visual_path or self.visual_path
    self.visual_open_sprite = definition.visual_open_sprite
        or (self.visual_path and self.visual_path .. "/open")
        or self.visual_open_sprite
    self.visual_opening_sprite = definition.visual_opening_sprite
        or (self.visual_path and self.visual_path .. "/opening")
        or self.visual_opening_sprite
    self.visual_closing_sprite = definition.visual_closing_sprite
        or (self.visual_path and self.visual_path .. "/closing")
        or self.visual_closing_sprite
    self.visual_closed_sprite = definition.visual_closed_sprite
        or (self.visual_path and self.visual_path .. "/closed")
        or self.visual_closed_sprite
    self:updateVisualState()
end

---@return string?
function OfficeDoor:getVisualSpriteForState()
    if self.state == "OPEN" then return self.visual_open_sprite end
    if self.state == "OPENING" then return self.visual_opening_sprite end
    if self.state == "CLOSING" then return self.visual_closing_sprite end
    if self.state == "CLOSED" then return self.visual_closed_sprite end
end

function OfficeDoor:updateVisualState()
    local asset = self:getVisualSpriteForState()
    if not asset or asset == "" then
        if self.visual_sprite then self.visual_sprite.visible = false end
        return
    end
    if not self.visual_sprite then
        self.visual_sprite = self:addChild(Sprite(nil, 0, 0))
        self.visual_sprite.debug_select = false
    end
    self.visual_sprite.visible = true

    local frames = Assets.getFrames(asset)
    if self:isMoving() and frames and #frames > 0 then
        local delay = math.max(self.transition_time / #frames, 1 / 240)
        self.visual_sprite:setAnimation({ asset, delay, false })
    else
        self.visual_sprite:setSprite(asset)
    end
end

---@param instant? boolean
---@return boolean changed
function OfficeDoor:open(instant)
    if self.locked or self.state == "OPEN" or self.state == "OPENING" then return false end
    self:setState(instant and "OPEN" or "OPENING")
    Assets.stopAndPlaySound("officedoor_open")
    return true
end

---@param instant? boolean
---@return boolean changed
function OfficeDoor:close(instant)
    if self.locked or self.state == "CLOSED" or self.state == "CLOSING" then return false end
    self:setState(instant and "CLOSED" or "CLOSING")
    Assets.stopAndPlaySound("officedoor_close", 0.8)
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

---@return boolean
function OfficeDoor:isLightOn()
    return self.state == "OPEN"
        and self.light_button ~= nil
        and self.light_button.light_on
end

---@param texture string
function OfficeDoor:drawHallwayTexture(texture)
    if not texture or texture == "" or not Assets.hasSprite(texture) then return end
    local image = Assets.getTexture(texture)
    local image_width = math.max(image:getWidth(), 1)
    local image_height = math.max(image:getHeight(), 1)
    local scale = math.min(self.width / image_width, self.height / image_height)
    local x = (self.width - image_width * scale) / 2
    local y = (self.height - image_height * scale) / 2
    Draw.setColor(1, 1, 0.82, 0.75)
    Draw.draw(image, x, y, 0, scale, scale)
end

---@param texture string
---@param index integer
---@param count integer
function OfficeDoor:drawLitAnimatronic(texture, index, count)
    if not texture or texture == "" or not Assets.hasSprite(texture) then return end
    local image = Assets.getTexture(texture)
    local image_width = math.max(image:getWidth(), 1)
    local image_height = math.max(image:getHeight(), 1)
    local scale = math.min(self.width / image_width, self.height / image_height)
    local spread = math.min(self.width * 0.18, 20)
    local x = (self.width - image_width * scale) / 2
        + (index - (count + 1) / 2) * spread
    local y = self.height - image_height * scale
    Draw.setColor(1, 1, 0.86, 1)
    Draw.draw(image, x, y, 0, scale, scale)
end

function OfficeDoor:drawLightView()
    if not self:isLightOn() then return end

    love.graphics.push("all")
    Draw.setColor(0.9, 0.78, 0.42, 0.9)
    love.graphics.rectangle("fill", 0, 0, self.width, self.height)
    self:drawHallwayTexture(self.light_hallway_sprite)

    local count = #self.animatronics
    for index, animatronic in ipairs(self.animatronics) do
        local texture = animatronic.getDoorLightSprite
            and animatronic:getDoorLightSprite(self)
            or self.light_animatronic_sprite
        self:drawLitAnimatronic(texture or self.light_animatronic_sprite, index, count)
    end
    love.graphics.pop()
end

function OfficeDoor:draw()
    super.draw(self)
end

return OfficeDoor
