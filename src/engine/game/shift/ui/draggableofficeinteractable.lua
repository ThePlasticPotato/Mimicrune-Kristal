--- An office interactable whose hitbox can be dragged along a line segment.
---@class DraggableOfficeInteractable : OfficeInteractable
---@field path_start_x number
---@field path_start_y number
---@field path_end_x number
---@field path_end_y number
---@field progress number Position from the start (0) to end (1) of the path.
---@field endpoint_threshold number
---@field drag_resistance number Mouse travel multiplier required to move the handle.
---@field drag_inertia number Velocity retained per 30 FPS frame after release.
---@field drag_velocity number Current velocity in path-progress units per second.
---@field auto_return boolean Whether a released handle returns to the start of its path.
---@field return_delay number Seconds between inertia settling and the return movement.
---@field return_speed number Return speed in path-progress units per second.
---@field sprite Sprite?
---@field sprite_id string?
---@overload fun(x?: number, y?: number, width?: number, height?: number): DraggableOfficeInteractable
local DraggableOfficeInteractable, super = Class(OfficeInteractable)

function DraggableOfficeInteractable:init(x, y, width, height)
    super.init(self, x, y, width or 32, height or 32)
    self.path_start_x = x or 0
    self.path_start_y = y or 0
    self.path_end_x = x or 0
    self.path_end_y = (y or 0) + 90
    self.progress = 0
    self.endpoint_threshold = 0.001
    self.drag_resistance = 1
    self.drag_inertia = 0
    self.drag_velocity = 0
    self.max_drag_velocity = 3
    self.drag_pointer_progress = 0
    self.auto_return = false
    self.return_delay = 0.2
    self.return_speed = 0.45
    self.return_armed = false
    self.return_started = false
    self.return_timer = 0
    self.returning = false
    self.last_endpoint = "start"
    self.sprite = nil
    self.sprite_id = nil
end

function DraggableOfficeInteractable:cancelReturn()
    self.return_armed = false
    self.return_started = false
    self.return_timer = 0
    self.returning = false
end

--- Sets the draggable handle's sprite without changing its authored hitbox.
---@param texture string|love.Image?
function DraggableOfficeInteractable:setSprite(texture)
    if not self.sprite then
        self.sprite = self:addChild(Sprite(texture, 0, 0))
        self.sprite.debug_select = false
    else
        self.sprite:setSprite(texture)
    end
    self.sprite_id = type(texture) == "string" and texture or nil
end

---@param start_x number
---@param start_y number
---@param end_x number
---@param end_y number
function DraggableOfficeInteractable:setPath(start_x, start_y, end_x, end_y)
    self.path_start_x, self.path_start_y = start_x, start_y
    self.path_end_x, self.path_end_y = end_x, end_y
    self:setProgress(self.progress, true)
end

---@param progress number
---@param silent? boolean
function DraggableOfficeInteractable:setProgress(progress, silent)
    progress = MathUtils.clamp(progress or 0, 0, 1)
    self.progress = progress
    self.x = MathUtils.lerp(self.path_start_x, self.path_end_x, progress)
    self.y = MathUtils.lerp(self.path_start_y, self.path_end_y, progress)

    local endpoint
    if progress <= self.endpoint_threshold then
        endpoint = "start"
    elseif progress >= 1 - self.endpoint_threshold then
        endpoint = "end"
    end
    if endpoint ~= self.last_endpoint then
        self.last_endpoint = endpoint
        if endpoint and not silent then self:onPathEndpoint(endpoint) end
    end
end

---@param screen_x number
---@param screen_y number
---@return number progress
function DraggableOfficeInteractable:getPathProgressAt(screen_x, screen_y)
    local x, y = self:perspectiveCursorPosition(screen_x, screen_y)
    if self.parent then x, y = self.parent:screenToLocalPos(x, y) end
    local path_x = self.path_end_x - self.path_start_x
    local path_y = self.path_end_y - self.path_start_y
    local length_squared = path_x * path_x + path_y * path_y
    if length_squared <= 0 then return 0 end
    x, y = x - self.width / 2, y - self.height / 2
    return ((x - self.path_start_x) * path_x + (y - self.path_start_y) * path_y)
        / length_squared
end

function DraggableOfficeInteractable:onPressed(button, x, y, presses)
    self:cancelReturn()
    self.drag_pointer_progress = self:getPathProgressAt(x, y)
    self.drag_velocity = 0
    Kristal.setCursorType("grab")
    return true
end

function DraggableOfficeInteractable:onMouseEnter(x, y)
    Kristal.setCursorType(self.pressed and "grab" or "select")
end

function DraggableOfficeInteractable:onMouseLeave(x, y)
    if not self.pressed then Kristal.setCursorType("default") end
end

function DraggableOfficeInteractable:onReleased(button, x, y, presses)
    self.return_armed = self.auto_return
        and self.progress > self.endpoint_threshold
        and self.progress < 1 - self.endpoint_threshold
    self.return_started = false
    self.return_timer = 0
    self.returning = false
    Kristal.setCursorType(self.hovered and "select" or "default")
end

function DraggableOfficeInteractable:onDrag(button, x, y, dx, dy)
    local pointer_progress = self:getPathProgressAt(x, y)
    local pointer_delta = pointer_progress - self.drag_pointer_progress
    self.drag_pointer_progress = pointer_progress
    if pointer_delta == 0 then return end

    local resistance = math.max(0.01, self:getDragResistance(pointer_delta))
    local old_progress = self.progress
    self:setProgress(self.progress + pointer_delta / resistance)
    local applied_delta = self.progress - old_progress
    if applied_delta == 0 then
        self.drag_velocity = 0
    else
        local sample_velocity = applied_delta / math.max(DT, 1 / 240)
        self.drag_velocity = MathUtils.clamp(sample_velocity,
            -self.max_drag_velocity, self.max_drag_velocity)
    end
end

--- Returns the mouse-travel multiplier for movement in the supplied direction.
--- Values above `1` require more travel; values below `1` make movement lighter.
---@param progress_delta number
---@return number resistance
function DraggableOfficeInteractable:getDragResistance(progress_delta)
    return self.drag_resistance
end

--- *(Override)* Called once when the handle first reaches either path endpoint.
---@param endpoint "start"|"end"
function DraggableOfficeInteractable:onPathEndpoint(endpoint) end

--- *(Override)* Called once after released inertia settles, before auto-return begins.
function DraggableOfficeInteractable:onReturnStarted() end

---@param definition table
function DraggableOfficeInteractable:applyLayoutDefinition(definition)
    if definition.texture and definition.texture ~= "" then
        self:setSprite(definition.texture)
    end
    self.endpoint_threshold = tonumber(definition.endpoint_threshold) or self.endpoint_threshold
    self.drag_resistance = math.max(0.01,
        tonumber(definition.drag_resistance) or self.drag_resistance)
    self.drag_inertia = MathUtils.clamp(
        tonumber(definition.drag_inertia) or self.drag_inertia, 0, 0.99)
    if definition.auto_return ~= nil then
        self.auto_return = definition.auto_return == true
    end
    self.return_delay = math.max(0,
        tonumber(definition.return_delay) or self.return_delay)
    self.return_speed = math.max(0.01,
        tonumber(definition.return_speed) or self.return_speed)
    local old_start_x, old_start_y = self.path_start_x, self.path_start_y
    self.path_start_x = tonumber(definition.path_start_x) or tonumber(definition.x) or old_start_x
    self.path_start_y = tonumber(definition.path_start_y) or tonumber(definition.y) or old_start_y
    self.path_end_x = tonumber(definition.path_x) and self.path_start_x + tonumber(definition.path_x)
        or tonumber(definition.path_end_x)
        or self.path_end_x + self.path_start_x - old_start_x
    self.path_end_y = tonumber(definition.path_y) and self.path_start_y + tonumber(definition.path_y)
        or tonumber(definition.path_end_y)
        or self.path_end_y + self.path_start_y - old_start_y
    self:setProgress(tonumber(definition.initial_progress) or self.progress, true)
end

function DraggableOfficeInteractable:update()
    super.update(self)

    if not self.pressed and self.drag_inertia > 0 and math.abs(self.drag_velocity) > 0.0001 then
        local old_progress = self.progress
        self:setProgress(self.progress + self.drag_velocity * DT)
        if self.progress == old_progress then self.drag_velocity = 0 end
    end

    if self.drag_velocity ~= 0 then
        self.drag_velocity = self.drag_velocity * (self.drag_inertia ^ DTMULT)
        if math.abs(self.drag_velocity) <= 0.0001 then self.drag_velocity = 0 end
    end

    if not self.pressed and self.return_armed then
        if self.progress <= self.endpoint_threshold
            or self.progress >= 1 - self.endpoint_threshold then
            self:cancelReturn()
        elseif self.drag_velocity == 0 then
            if not self.return_started then
                self.return_started = true
                self.return_timer = self.return_delay
                self:onReturnStarted()
            elseif self.return_timer > 0 then
                self.return_timer = math.max(0, self.return_timer - DT)
            else
                self.returning = true
                self:setProgress(MathUtils.approach(
                    self.progress, 0, self.return_speed * DT))
                if self.progress <= self.endpoint_threshold then
                    self:setProgress(0)
                    self:cancelReturn()
                end
            end
        end
    end
end

function DraggableOfficeInteractable:drawDebug()
    local center_x, center_y = self.width / 2, self.height / 2
    local start_x = self.path_start_x - self.x + center_x
    local start_y = self.path_start_y - self.y + center_y
    local end_x = self.path_end_x - self.x + center_x
    local end_y = self.path_end_y - self.y + center_y
    local previous_width = love.graphics.getLineWidth()
    love.graphics.setLineWidth(3)
    Draw.setColor(0.25, 0.9, 1, 0.9)
    love.graphics.line(start_x, start_y, end_x, end_y)
    love.graphics.circle("line", start_x, start_y, 4)
    love.graphics.circle("line", end_x, end_y, 4)
    love.graphics.setLineWidth(previous_width)
    Draw.setColor(1, 1, 1, 1)
end

function DraggableOfficeInteractable:draw()
    super.draw(self)
    if DEBUG_RENDER then self:drawDebug() end
end

function DraggableOfficeInteractable:onRemove(parent)
    if self.hovered or self.pressed then Kristal.setCursorType("default") end
    super.onRemove(self, parent)
end

return DraggableOfficeInteractable
