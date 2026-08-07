---@class ShiftCamera : Object
---@field background Sprite
---@field pan_range number[]
---@field flashlight boolean
---@field vent boolean
---@field static_interactables PanelButton[] extra buttons added to the camera panel while on this camera (for like sealing vents)
---@field interactables CameraInteractable[]
---@field office_proximity number
---
---@field move_targets MoveTarget[]
local ShiftCamera, super = Class(Object)

---@class MoveTarget
---@field target_id string
---@field allowed_animatronics string[]
---@field blocked boolean

return ShiftCamera