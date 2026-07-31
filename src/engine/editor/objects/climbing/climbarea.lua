---@class EditorClimbArea : EditorObject
---@overload fun(data?: table, options?: table): EditorClimbArea
local EditorClimbArea, super = Class(EditorObject)
EditorClimbArea.editor_sprite = "editor/climbarea"
EditorClimbArea.placement_shape = "region"
function EditorClimbArea:init(data, options)
    super.init(self, data, options)
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
function EditorClimbArea:createObject(map, context)
    return ClimbArea(self.data.x, self.data.y, self:getRectData())
end

return EditorClimbArea
