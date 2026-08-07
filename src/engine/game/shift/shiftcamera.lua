--- A surveillance camera available during a shift.
---@class ShiftCamera : Object
---@field id string
---@field shift Shift?
---@field office Office?
---@field name string
---@field background Sprite?
---@field pan number
---@field target_pan number
---@field pan_range [number, number]
---@field pan_speed number
---@field flashlight boolean Whether this camera supports a flashlight.
---@field flashlight_on boolean
---@field vent boolean
---@field static_interactables PanelButton[] Extra panel buttons displayed while this camera is selected.
---@field interactables CameraInteractable[]
---@field office_proximity number
---@field move_targets MoveTarget[]
---@field animatronics ShiftAnimatronic[]
---@field enabled boolean
---@overload fun() : ShiftCamera
local ShiftCamera, super = Class(Object)

---@class MoveTarget
---@field target_id string
---@field allowed_animatronics string[] An empty list allows every animatronic.
---@field blocked boolean

function ShiftCamera:init()
    super.init(self, 0, 0, SCREEN_WIDTH, SCREEN_HEIGHT)

    self.shift = nil
    self.office = nil
    self.name = "Camera"
    self.background = nil

    self.pan = 0
    self.target_pan = 0
    self.pan_range = { 0, 0 }
    self.pan_speed = 240

    self.flashlight = false
    self.flashlight_on = false
    self.vent = false

    self.static_interactables = {}
    self.interactables = {}
    self.office_proximity = 0

    self.move_targets = {}
    self.animatronics = {}
    self.enabled = true
end

---@param target string|MoveTarget
---@param allowed_animatronics? string[]
---@return MoveTarget target
function ShiftCamera:addMoveTarget(target, allowed_animatronics)
    if type(target) == "string" then
        target = {
            target_id = target,
            allowed_animatronics = allowed_animatronics or {},
            blocked = false,
        }
    else
        target.allowed_animatronics = target.allowed_animatronics or {}
        target.blocked = target.blocked or false
    end
    table.insert(self.move_targets, target)
    return target
end

---@param id string
---@return MoveTarget?
function ShiftCamera:getMoveTarget(id)
    for _, target in ipairs(self.move_targets) do
        if target.target_id == id then return target end
    end
end

---@param target MoveTarget
---@param animatronic ShiftAnimatronic
---@return boolean
function ShiftCamera:canMoveTo(target, animatronic)
    if target.blocked then return false end
    return #target.allowed_animatronics == 0
        or TableUtils.contains(target.allowed_animatronics, animatronic.id)
end

---@param animatronic ShiftAnimatronic
function ShiftCamera:addAnimatronic(animatronic)
    if not TableUtils.contains(self.animatronics, animatronic) then
        table.insert(self.animatronics, animatronic)
    end
end

---@param interactable CameraInteractable
---@return CameraInteractable interactable
function ShiftCamera:addInteractable(interactable)
    table.insert(self.interactables, interactable)
    interactable.camera = self
    self:addChild(interactable)
    return interactable
end

---@param button PanelButton
---@return PanelButton button
function ShiftCamera:addStaticInteractable(button)
    table.insert(self.static_interactables, button)
    return button
end

---@param animatronic ShiftAnimatronic
function ShiftCamera:removeAnimatronic(animatronic)
    TableUtils.removeValue(self.animatronics, animatronic)
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

---@param pan number
---@param instant? boolean
function ShiftCamera:setPan(pan, instant)
    self.target_pan = MathUtils.clamp(pan, self.pan_range[1], self.pan_range[2])
    if instant then self.pan = self.target_pan end
end

function ShiftCamera:update()
    self.pan = MathUtils.approach(self.pan, self.target_pan, self.pan_speed * DT)
    super.update(self)
end

return ShiftCamera