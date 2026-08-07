--- A surveillance camera available during a shift.
---@class ShiftCamera : ShiftMoveTarget
---@field id string
---@field shift Shift?
---@field office Office?
---@field layout_id string?
---@field layout table?
---@field layout_objects table<string, Object>
---@field content Object
---@field name string
---@field background Sprite?
---@field pan number
---@field pan_y number
---@field target_pan number
---@field target_pan_y number
---@field pan_range [number, number]
---@field pan_range_y [number, number]
---@field pan_speed number
---@field pan_speed_y number
---@field pan_edge_margin number Size of the cursor-sensitive edge zone in panel pixels.
---@field flashlight boolean Whether this camera supports a flashlight.
---@field flashlight_on boolean
---@field vent boolean
---@field static_interactables PanelButton[] Extra panel buttons displayed while this camera is selected.
---@field interactables CameraInteractable[]
---@field office_proximity number
---@overload fun() : ShiftCamera
local ShiftCamera, super = Class(ShiftMoveTarget)

function ShiftCamera:init()
    super.init(self, 0, 0, SCREEN_WIDTH, SCREEN_HEIGHT)

    self.shift = nil
    self.office = nil
    self.layout_id = nil
    self.layout = nil
    self.layout_objects = {}
    self.name = "Camera"
    self.background = nil
    self.content = self:addChild(Object(0, 0, SCREEN_WIDTH, SCREEN_HEIGHT))
    self.content.layer = -100
    self.draw_children_below = 0

    self.pan = 0
    self.pan_y = 0
    self.target_pan = 0
    self.target_pan_y = 0
    self.pan_range = { 0, 0 }
    self.pan_range_y = { 0, 0 }
    self.pan_speed = 240
    self.pan_speed_y = 240
    self.pan_edge_margin = 48

    self.flashlight = false
    self.flashlight_on = false
    self.vent = false

    self.static_interactables = {}
    self.interactables = {}
    self.office_proximity = 0

end

---@param object Object
---@param id? string
---@return Object object
function ShiftCamera:registerLayoutObject(object, id)
    id = id or object.layout_id or object.id
    if type(id) == "string" and id ~= "" then
        object.layout_id = id
        self.layout_objects[id] = object
    end
    return object
end

---@param interactable CameraInteractable
---@param id? string
---@return CameraInteractable interactable
function ShiftCamera:addInteractable(interactable, id)
    table.insert(self.interactables, interactable)
    interactable.shift_camera = self
    self:registerLayoutObject(interactable, id)
    self.content:addChild(interactable)
    return interactable
end

---@param button PanelButton
---@return PanelButton button
function ShiftCamera:addStaticInteractable(button)
    table.insert(self.static_interactables, button)
    return button
end

---@param layout table
function ShiftCamera:applyLayout(layout)
    self.layout = layout
    self.layout_id = layout.id or self.layout_id
    self.width = tonumber(layout.width) or self.width
    self.height = tonumber(layout.height) or self.height
    self.content.width, self.content.height = self.width, self.height

    if type(layout.background) == "string" and layout.background ~= "" then
        self.background = Sprite(layout.background)
        self.background.layer = -100
        self.content:addChild(self.background)
    end

    for _, object in ipairs(self.interactables) do self:registerLayoutObject(object) end
    for definition, layer in ShiftLayout.iterObjects(layout) do
        local resolved = ShiftLayout.resolveObjectDefinition(definition)
        local object_id = resolved.layout_id
        local object = object_id and self.layout_objects[object_id] or nil
        local created = false
        if not object then
            object = Registry.createShiftLayoutObject(definition, self)
            created = object ~= nil
        end
        if object then
            ShiftLayout.applyObject(object, definition)
            if resolved.layer == nil and layer.depth ~= nil then object.layer = layer.depth end
            self:registerLayoutObject(object, object_id)
            if created and object:includes(CameraInteractable) then
                self:addInteractable(object, object_id)
            else
                object:setParent(self.content)
            end
        end
    end

    local content_width = tonumber(layout.width)
        or (self.background and self.background.width)
        or SCREEN_WIDTH
    local content_height = tonumber(layout.height)
        or (self.background and self.background.height)
        or SCREEN_HEIGHT
    self.pan_range = { 0, math.max(0, content_width - SCREEN_WIDTH) }
    self.pan_range_y = { 0, math.max(0, content_height - SCREEN_HEIGHT) }
    self.pan_speed = tonumber(layout.pan_speed_x) or tonumber(layout.pan_speed)
        or self.pan_speed
    self.pan_speed_y = tonumber(layout.pan_speed_y) or tonumber(layout.pan_speed)
        or self.pan_speed_y
    self.pan_edge_margin = math.max(1,
        tonumber(layout.pan_edge_margin) or self.pan_edge_margin)
    self:setPan(tonumber(layout.pan_x) or tonumber(layout.pan) or self.pan,
        tonumber(layout.pan_y) or self.pan_y, true)
    self.content.x = -self.pan
    self.content.y = -self.pan_y
end

---@param enabled boolean
function ShiftCamera:setFlashlight(enabled)
    enabled = self.flashlight and enabled or false
    if self.flashlight_on == enabled then return end
    self.flashlight_on = enabled
    self:onFlashlightChanged(enabled)
end

---@param enabled boolean
function ShiftCamera:onFlashlightChanged(enabled) end

---@param previous ShiftCamera?
function ShiftCamera:onViewed(previous)
    self.active = true
    self.visible = true
end

---@param next_camera ShiftCamera?
function ShiftCamera:onUnviewed(next_camera)
    self:setFlashlight(false)
    self.active = false
    self.visible = false
end

---@param pan_x number
---@param pan_y? number|boolean
---@param instant? boolean
function ShiftCamera:setPan(pan_x, pan_y, instant)
    if type(pan_y) == "boolean" then
        instant, pan_y = pan_y, nil
    end
    self.target_pan = MathUtils.clamp(pan_x, self.pan_range[1], self.pan_range[2])
    if pan_y ~= nil then
        self.target_pan_y = MathUtils.clamp(pan_y,
            self.pan_range_y[1], self.pan_range_y[2])
    end
    if instant then
        self.pan = self.target_pan
        self.pan_y = self.target_pan_y
    end
end

--- Advances the camera pan according to a pointer position inside its panel screen.
---@param x number Local panel-screen X.
---@param y number Local panel-screen Y.
---@param width number Panel-screen width.
---@param height number Panel-screen height.
function ShiftCamera:panFromPointer(x, y, width, height)
    if x < 0 or y < 0 or x > width or y > height then return end
    local margin_x = math.min(self.pan_edge_margin, width / 2)
    local margin_y = math.min(self.pan_edge_margin, height / 2)
    local direction_x, direction_y = 0, 0
    if self.pan_range[2] > self.pan_range[1] then
        if x < margin_x then
            direction_x = -(1 - x / margin_x)
        elseif x > width - margin_x then
            direction_x = (x - (width - margin_x)) / margin_x
        end
    end
    if self.pan_range_y[2] > self.pan_range_y[1] then
        if y < margin_y then
            direction_y = -(1 - y / margin_y)
        elseif y > height - margin_y then
            direction_y = (y - (height - margin_y)) / margin_y
        end
    end
    self.target_pan = MathUtils.clamp(
        self.target_pan + direction_x * self.pan_speed * DT,
        self.pan_range[1], self.pan_range[2])
    self.target_pan_y = MathUtils.clamp(
        self.target_pan_y + direction_y * self.pan_speed_y * DT,
        self.pan_range_y[1], self.pan_range_y[2])
end

function ShiftCamera:updatePointerPan()
    local shift = self.shift or Game.shift
    local panel = shift and shift.night and shift.night.camera_panel
    if not panel or panel.state ~= "OPEN" or panel.selected_camera ~= self then return end
    local mouse_x, mouse_y = Input.getCurrentCursorPosition()
    if not mouse_x or not mouse_y then return end
    local x, y = panel.screen:screenToLocalPos(mouse_x, mouse_y)
    self:panFromPointer(x, y, panel.screen_width, panel.screen_height)
end

function ShiftCamera:update()
    self:updatePointerPan()
    self.pan = MathUtils.approach(self.pan, self.target_pan, self.pan_speed * DT)
    self.pan_y = MathUtils.approach(self.pan_y, self.target_pan_y, self.pan_speed_y * DT)
    self.content.x = -self.pan
    self.content.y = -self.pan_y
    super.update(self)
end

return ShiftCamera
