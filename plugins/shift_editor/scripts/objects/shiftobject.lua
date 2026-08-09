---@class EditorShiftObject : EditorObject
---@overload fun(data?: table, options?: table): EditorShiftObject
local EditorShiftObject, super = Class(EditorObject)

EditorShiftObject.editor_sprite = "editor/marker"
EditorShiftObject.placement_shape = "rectangle"
EditorShiftObject.sprite_alignment = "top_left"

function EditorShiftObject:getSpriteScale()
    return 1, 1
end

function EditorShiftObject:init(data, options)
    super.init(self, data, options)
    self:registerProperty("layout_id", "string", {
        name = "Layout ID",
        placeholder = "Stable runtime identifier"
    })
end

function EditorShiftObject:createObject()
    return nil
end

return EditorShiftObject
