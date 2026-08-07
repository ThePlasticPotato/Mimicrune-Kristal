---@class Office : Object
---@field background_texture love.Image
---@field cameras string[] ShiftCamera IDs
---@field doors OfficeDoor[]
---@field static_interactables ShiftInteractable[]
---@field interactables OfficeInteractable[]
local Office, super = Class(Object)

return Office