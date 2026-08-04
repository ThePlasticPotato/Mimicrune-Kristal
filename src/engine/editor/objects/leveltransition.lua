---@class EditorLevelTransition : EditorObject
---@overload fun(data?:table, options?:table): EditorLevelTransition
local EditorLevelTransition, super = Class(EditorObject)

EditorLevelTransition.placement_shape = "region"
EditorLevelTransition.editor_sprite = "editor/slidearea"

function EditorLevelTransition:init(data, options)
    super.init(self, data, options)
    self:registerProperty("target_level", "string", {
        name = "Target Level",
        placeholder = "Level ID"
    })
    self:registerProperty("require_grounded", "boolean", {
        name = "Require Grounded", default = true
    })
    self:registerProperty("snap_camera", "boolean", {
        name = "Snap Camera", default = false
    })
end

function EditorLevelTransition:createObject(map, context)
    return LevelTransition(self.data.x, self.data.y,
        self:getRectData(), self.data.properties)
end

return EditorLevelTransition
