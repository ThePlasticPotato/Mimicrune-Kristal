--- A shift's office view and the objects positioned within its panoramic space.
---@class Office : ShiftMoveTarget
---@field id string
---@field shift Shift?
---@field layout_id string?
---@field layout table?
---@field layout_objects table<string, Object>
---@field layout_objects_by_source_id table<string, Object>
---@field panorama Object Container translated with the office's panoramic view.
---@field background_texture love.Image?
---@field background Sprite?
---@field power_out boolean
---@field power_out_sprite string?
---@field intro_animation string|table|function?
---@field intro_speed number
---@field cameras (string|ShiftCamera)[] ShiftCamera ids or instances.
---@field doors OfficeDoor[]
---@field door_by_id table<string, OfficeDoor>
---@field static_interactables ShiftInteractable[]
---@field interactables OfficeInteractable[]
---@field pan number
---@field target_pan number
---@field pan_range [number, number]
---@field pan_speed number
---@field panorama_warp number Clickteam-style vertical panorama compression at the horizontal edges.
---@overload fun() : Office
local Office, super = Class(ShiftMoveTarget)

function Office:init()
    super.init(self, 0, 0, SCREEN_WIDTH, SCREEN_HEIGHT)

    self.background_texture = nil
    self.background = nil
    self.power_out = false
    self.power_out_sprite = nil
    self.intro_animation = nil
    self.intro_speed = 1 / 30
    self.shift = nil
    self.layout_id = nil
    self.layout = nil
    self.layout_objects = {}
    self.layout_objects_by_source_id = {}
    self.panorama = self:addChild(Object(0, 0, self.width, self.height))

    self.cameras = {}
    self.doors = {}
    self.door_by_id = {}
    self.static_interactables = {}
    self.interactables = {}

    self.pan = 0
    self.target_pan = 0
    self.pan_range = { 0, 0 }
    self.pan_speed = 900
    -- Equivalent to the Clickteam Panorama effect's commonly used zoom value of 75:
    -- 75 * 0.0015 = 0.1125 edge compression.
    self.panorama_warp = 0.1125
end

---@param camera string|ShiftCamera
function Office:addCamera(camera)
    table.insert(self.cameras, camera)
end

---@return ShiftCamera[]
function Office:createCameras()
    local result = {}
    for _, entry in ipairs(self.cameras) do
        local camera = entry
        if type(entry) == "string" then
            camera = Registry.createShiftCamera(entry)
        end
        table.insert(result, camera)
    end
    return result
end

---@param door OfficeDoor
---@return OfficeDoor door
function Office:addDoor(door)
    if type(door.id) ~= "string" or door.id == "" then
        error("Office doors used as movement targets require a non-empty id")
    end
    if self.door_by_id[door.id] then
        error("Duplicate office door id \"" .. door.id .. "\"")
    end
    table.insert(self.doors, door)
    self.door_by_id[door.id] = door
    door.office = self
    door:addMoveTarget(self)
    self:registerLayoutObject(door, door.id)
    self:addChild(door)
    if self.shift then
        self.shift:addMoveTarget(door)
    end
    return door
end

---@param object Object
---@param id? string
---@param source_id? string|number
---@return Object object
function Office:registerLayoutObject(object, id, source_id)
    id = id or object.layout_id or object.id
    if type(id) == "string" and id ~= "" then
        object.layout_id = id
        self.layout_objects[id] = object
    end
    if source_id ~= nil then
        self.layout_objects_by_source_id[tostring(source_id)] = object
    end
    return object
end

---@param reference string|number|table
---@return Object?
function Office:getLayoutObject(reference)
    if type(reference) == "table" then
        if reference.includes and reference:includes(Object) then return reference end
        reference = reference.object_id or reference.object or reference.id
    end
    if reference == nil then return nil end
    return self.layout_objects[tostring(reference)]
        or self.layout_objects_by_source_id[tostring(reference)]
end

---@param door OfficeDoor|string|table
---@return OfficeDoor?
function Office:getDoor(door)
    if type(door) == "table" and door.includes and door:includes(OfficeDoor) then return door end
    local result = type(door) == "string" and self.door_by_id[door] or nil
    result = result or self:getLayoutObject(door)
    return result and result:includes(OfficeDoor) and result or nil
end

---@return boolean
function Office:hasIntro()
    return self.intro_animation ~= nil
end

---@param after fun() Called when the animation finishes.
---@return boolean started
function Office:startIntro(after)
    if not self.background or not self.intro_animation then return false end

    if type(self.intro_animation) == "string" then
        self.background:setSprite(self.intro_animation)
        if self.background.frames then
            self.background:play(self.intro_speed, false, after)
        else
            after()
        end
    elseif type(self.intro_animation) == "table" then
        local animation = self.intro_animation
        animation = TableUtils.copy(animation)
        local old_callback = animation.callback
        animation.callback = function(sprite)
            if old_callback then old_callback(sprite) end
            after()
        end
        self.background:setAnimation(animation)
    else
        self.background:setAnimation({ self.intro_animation, callback = after })
    end
    return true
end

function Office:setPowerOut()
    if self.power_out then return end
    self.power_out = true
    if self.background and self.power_out_sprite then
        self.background:setSprite(self.power_out_sprite)
    end
    self:onPowerOut()
end

--- *(Override)*
function Office:onPowerOut() end

---@param interactable ShiftInteractable
---@param id? string
---@return ShiftInteractable interactable
function Office:addStaticInteractable(interactable, id)
    table.insert(self.static_interactables, interactable)
    if interactable:includes(OfficeInteractable) then
        interactable.office = self
    end
    self:registerLayoutObject(interactable, id)
    self:addChild(interactable)
    if interactable.onAddedToOffice then interactable:onAddedToOffice(self) end
    return interactable
end

---@param interactable OfficeInteractable
---@param id? string
---@return OfficeInteractable interactable
function Office:addInteractable(interactable, id)
    table.insert(self.interactables, interactable)
    interactable.office = self
    self:registerLayoutObject(interactable, id)
    self.panorama:addChild(interactable)
    if interactable.onAddedToOffice then interactable:onAddedToOffice(self) end
    return interactable
end

---@param layout table
function Office:applyLayout(layout)
    self.layout = layout
    self.layout_id = layout.id or self.layout_id
    self.width = tonumber(layout.width) or self.width
    self.height = tonumber(layout.height) or self.height
    self.panorama.width, self.panorama.height = self.width, self.height

    if type(layout.background) == "string" and layout.background ~= "" then
        self.background = Sprite(layout.background)
    end

    for _, door in ipairs(self.doors) do self:registerLayoutObject(door) end
    for _, object in ipairs(self.static_interactables) do self:registerLayoutObject(object) end
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
            self:registerLayoutObject(object, object_id, definition.id)

            local mode = resolved.mode or layer.mode or "panorama"
            if created and object:includes(OfficeDoor) then
                self:addDoor(object)
                object:setParent(mode == "static" and self or self.panorama)
            elseif created and object:includes(OfficeInteractable) then
                if mode == "static" then
                    self:addStaticInteractable(object, object_id)
                else
                    self:addInteractable(object, object_id)
                end
            else
                object:setParent(mode == "static" and self or self.panorama)
            end
        end
    end

    for _, object in ipairs(self.interactables) do
        if object.resolveDoor then object:resolveDoor() end
    end

    local content_width = tonumber(layout.width)
        or (self.background and self.background.width)
        or SCREEN_WIDTH
    self.pan_range = { 0, math.max(0, content_width - SCREEN_WIDTH) }
    self:setPan(tonumber(layout.pan) or self.pan, true)
end

---@param pan number
---@param instant? boolean
function Office:setPan(pan, instant)
    self.target_pan = MathUtils.clamp(pan, self.pan_range[1], self.pan_range[2])
    if instant then
        local old = self.pan
        self.pan = self.target_pan
        if old ~= self.pan then
            self:syncPan()
            self:onPan(self.pan, old)
        end
    end
end

---@param pan number
---@param old number
function Office:onPan(pan, old) end

function Office:syncPan()
    if self.background and not self.background.parent then self.background.x = -self.pan end
    self.panorama.x = -self.pan
end

function Office:drawBackground()
    if not self.background or self.background.parent then return end
    if self.panorama_warp <= 0 then
        self.background:fullDraw()
        return
    end

    local canvas = Draw.pushCanvas(SCREEN_WIDTH, SCREEN_HEIGHT)
    self.background:fullDraw()
    Draw.popCanvas()

    local last_shader = love.graphics.getShader()
    local shader = Assets.getShader("office_panorama")
    shader:send("warp", self.panorama_warp)
    love.graphics.setShader(shader)
    Draw.setColor(1, 1, 1, 1)
    Draw.draw(canvas)
    love.graphics.setShader(last_shader)
end

function Office:update()
    if self.background and not self.background.parent then
        self.background:fullUpdate()
    end
    local old = self.pan
    self.pan = MathUtils.approach(self.pan, self.target_pan, self.pan_speed * DT)
    if old ~= self.pan then
        self:syncPan()
        self:onPan(self.pan, old)
    end
    super.update(self)
end

function Office:draw()
    self:drawBackground()
    super.draw(self)
end

---@return boolean
function Office:canDeepCopy()
    return false
end

return Office
