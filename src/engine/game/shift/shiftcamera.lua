--- A surveillance camera available during a shift.
---@class ShiftCamera : ShiftMoveTarget
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
---@overload fun() : ShiftCamera
local ShiftCamera, super = Class(ShiftMoveTarget)

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

end

---@param interactable CameraInteractable
---@return CameraInteractable interactable
function ShiftCamera:addInteractable(interactable)
    table.insert(self.interactables, interactable)
    interactable.shift_camera = self
    self:addChild(interactable)
    return interactable
end

---@param button PanelButton
---@return PanelButton button
function ShiftCamera:addStaticInteractable(button)
    table.insert(self.static_interactables, button)
    return button
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
