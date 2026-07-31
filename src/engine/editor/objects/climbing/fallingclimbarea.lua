---@class EditorFallingClimbArea : EditorObject
---@overload fun(data?: table, options?: table): EditorFallingClimbArea
local EditorFallingClimbArea, super = Class(EditorObject)
EditorFallingClimbArea.editor_sprite = "editor/fallingclimbarea"
EditorFallingClimbArea.placement_shape = "region"
function EditorFallingClimbArea:init(data, options)
    super.init(self, data, options)
    self:registerProperty("dont_break", "boolean", { name = "Don't Break" })
    self:registerProperty("breaks_on_leave", "boolean", { name = "Breaks On Leave" })
    self:registerProperty("fall_time", "number", { name = "Fall Time" })
    self:registerProperty("timed", "boolean")
    self:registerProperty("no_unsafe_area", "boolean", { name = "No Unsafe Area" })
    self:registerProperty("climb_height_mode", "choice", {
        name = "Height Mapping", default = "auto", choices = {
            { value = "auto", label = "Auto (Depth = Vertical)" },
            { value = "vertical", label = "Vertical Z Plane" },
            { value = "flat", label = "Flat at Z" }
        }
    })
    self:registerProperty("climb_height_axis", "choice", {
        name = "Height Axis", default = "y", choices = {
            { value = "y", label = "Bottom to Top" },
            { value = "x", label = "Left to Right" }
        }
    })
    self:registerProperty("climb_height_reverse", "boolean", {
        name = "Reverse Height", default = false
    })
end
function EditorFallingClimbArea:createObject(map, context)
    local properties = self.data.properties
    return FallingClimbArea(self.data.x, self.data.y, self:getRectData(), {
        dont_break = properties.dont_break,
        breaks_on_leave = properties.breaks_on_leave,
        fall_time = properties.fall_time,
        timed = properties.timed,
        no_unsafe_area = properties.no_unsafe_area
    })
end

return EditorFallingClimbArea
