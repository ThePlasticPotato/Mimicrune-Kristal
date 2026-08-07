--- A shift's office view and the objects positioned within its panoramic space.
---@class Office : Object
---@field id string
---@field shift Shift?
---@field background_texture love.Image?
---@field background Sprite?
---@field cameras (string|ShiftCamera)[] ShiftCamera ids or instances.
---@field doors OfficeDoor[]
---@field door_by_id table<string, OfficeDoor>
---@field static_interactables ShiftInteractable[]
---@field interactables OfficeInteractable[]
---@field pan number
---@field target_pan number
---@field pan_range [number, number]
---@field pan_speed number
---@overload fun() : Office
local Office, super = Class(Object)

function Office:init()
    super.init(self, 0, 0, SCREEN_WIDTH, SCREEN_HEIGHT)

    self.background_texture = nil
    self.background = nil
    self.shift = nil

    self.cameras = {}
    self.doors = {}
    self.door_by_id = {}
    self.static_interactables = {}
    self.interactables = {}

    self.pan = 0
    self.target_pan = 0
    self.pan_range = { 0, 0 }
    self.pan_speed = 240
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
    table.insert(self.doors, door)
    if door.id then
        self.door_by_id[door.id] = door
    end
    door.office = self
    self:addChild(door)
    return door
end

---@param door OfficeDoor|string
---@return OfficeDoor?
function Office:getDoor(door)
    if type(door) == "string" then
        return self.door_by_id[door]
    end
    return door
end

---@param interactable ShiftInteractable
---@return ShiftInteractable interactable
function Office:addStaticInteractable(interactable)
    table.insert(self.static_interactables, interactable)
    if interactable:includes(OfficeInteractable) then
        interactable.office = self
    end
    self:addChild(interactable)
    return interactable
end

---@param interactable OfficeInteractable
---@return OfficeInteractable interactable
function Office:addInteractable(interactable)
    table.insert(self.interactables, interactable)
    interactable.office = self
    self:addChild(interactable)
    return interactable
end

---@param pan number
---@param instant? boolean
function Office:setPan(pan, instant)
    self.target_pan = MathUtils.clamp(pan, self.pan_range[1], self.pan_range[2])
    if instant then
        local old = self.pan
        self.pan = self.target_pan
        if old ~= self.pan then self:onPan(self.pan, old) end
    end
end

---@param pan number
---@param old number
function Office:onPan(pan, old) end

function Office:update()
    local old = self.pan
    self.pan = MathUtils.approach(self.pan, self.target_pan, self.pan_speed * DT)
    if old ~= self.pan then self:onPan(self.pan, old) end
    super.update(self)
end

---@return boolean
function Office:canDeepCopy()
    return false
end

return Office