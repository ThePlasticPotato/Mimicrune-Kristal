---@class EditorPushBlock : EditorObject
---@overload fun(data?: table, options?: table): EditorPushBlock
local EditorPushBlock, super = Class(EditorObject)

EditorPushBlock.sprite_property = "sprite"
function EditorPushBlock:getEditorSprite(data)
    return data.properties.sprite or "world/events/push_block"
end
function EditorPushBlock:init(data, options)
    super.init(self, data, options)
    self:registerProperty("supports", "boolean", {
        name = "Walkable Collider Top", default = true
    })
    self:registerProperty("sprite", "asset_path", {
        asset_registry = { "texture", "frames" },
        path_root = "assets/sprites", strip_extension = true,
        extensions = { "png", "jpg", "jpeg" }
    })
    self:registerProperty("solvedsprite", "asset_path", {
        name = "Solved Sprite", asset_registry = { "texture", "frames" },
        path_root = "assets/sprites", strip_extension = true,
        extensions = { "png", "jpg", "jpeg" }
    })
    self:registerProperty("pushdist", "number", { name = "Push Distance", default = 40 })
    self:registerProperty("pushtime", "number", { name = "Push Time", default = 0.2 })
    self:registerProperty("pushsound", "asset_path", {
        name = "Push Sound", default = "noise", asset_registry = "sound_data",
        path_root = "assets/sounds", strip_extension = true, extensions = { "wav", "ogg" }
    })
    self:registerProperty("pressbuttons", "boolean", { name = "Press Buttons", default = true })
    self:registerProperty("lock", "boolean")
    self:registerProperty("inputlock", "boolean", { name = "Input Lock" })
    self:registerProperty("height_physics", "boolean", {
        name = "Height Physics", default = true
    })
    self:registerProperty("fallgravity", "number", {
        name = "Fall Gravity", default = 0.6
    })
    self:registerProperty("maxfallspeed", "number", {
        name = "Maximum Fall Speed", default = 12
    })
    self:registerProperty("pitfalllimit", "number", {
        name = "Pit Fall Limit", default = -80
    })
    self:registerProperty("resetonpit", "boolean", {
        name = "Reset On Pit", default = true
    })
end
function EditorPushBlock:createObject(map, context)
    return PushBlock(self.data.x, self.data.y, self:getRectData(), self.data.properties)
end

return EditorPushBlock
