---@class EditorLaunchVent : EditorObject
---@overload fun(data?: table, options?: table): EditorLaunchVent
local EditorLaunchVent, super = Class(EditorObject)

EditorLaunchVent.editor_sprite = "world/events/ventlauncher/right"
EditorLaunchVent.scaling_mode = "scale"

function EditorLaunchVent:init(data, options)
    super.init(self, data, options)
    self:registerProperty("mode", "choice", { name = "Launch Mode", default = "target", choices = {
        { value = "target", label = "Target Arc" },
        { value = "force", label = "Static Force" }
    } })
    self:registerProperty("direction", "choice", { default = "right", choices = {
        "up", "down", "left", "right"
    } })
    self:registerProperty("target", "object_reference", {
        name = "Landing Target", allowed_types = { "marker", "player" }
    })
    self:registerProperty("target_x", "number", { name = "Target X" })
    self:registerProperty("target_y", "number", { name = "Target Y" })
    self:registerProperty("target_z", "number", { name = "Target Z" })
    self:registerProperty("distance", "number", {
        name = "Fallback Target Distance", default = 240
    })
    self:registerProperty("duration", "number", {
        name = "Arc Duration", default = 0.75
    })
    self:registerProperty("apex_height", "number", {
        name = "Arc Height Override"
    })
    self:registerProperty("force_x", "number", { name = "Force X" })
    self:registerProperty("force_y", "number", { name = "Force Y" })
    self:registerProperty("force_z", "number", { name = "Force Z", default = 12 })
    self:registerProperty("force_speed", "number", {
        name = "Directional Force", default = 8
    })
    self:registerProperty("hold_time", "number", {
        name = "Hold Before Launch"
    })
    self:registerProperty("center_time", "number", {
        name = "Centering Time", default = 0.1
    })
    self:registerProperty("capture_offset_x", "number", {
        name = "Capture Offset X", default = 0
    })
    self:registerProperty("capture_offset_y", "number", {
        name = "Capture Offset Y", default = 5
    })
    self:registerProperty("lock_flight", "boolean", {
        name = "Lock Input During Flight"
    })
    self:registerProperty("cooldown", "number", { default = 0.4 })
    self:registerProperty("enabled", "boolean", { default = true })
    self:registerProperty("idle_steam", "boolean", {
        name = "Idle Steam", default = true
    })
    self:registerProperty("steam_interval", "number", {
        name = "Steam Interval", default = 10 / 30
    })
    self:registerProperty("launch_sound", "asset_path", {
        name = "Launch Sound", asset_registry = "sound_data",
        path_root = "assets/sounds", strip_extension = true,
        extensions = { "wav", "ogg" }
    })
end

function EditorLaunchVent:getEditorSprite(data)
    local properties = data.properties or {}
    return "world/events/ventlauncher/" .. (properties.direction or "right")
end

function EditorLaunchVent:createObject(map, context)
    return LaunchVent(self.data)
end

function EditorLaunchVent:draw(alpha)
    super.draw(self, alpha)
    local properties = self.data.properties or {}
    local direction = properties.direction or "right"
    local directions = {
        up = { 0, -1 }, down = { 0, 1 }, left = { -1, 0 }, right = { 1, 0 }
    }
    local dx, dy
    if properties.mode == "force" then
        local fallback = directions[direction] or directions.right
        dx = tonumber(properties.force_x) or fallback[1] * (tonumber(properties.force_speed) or 8)
        dy = (tonumber(properties.force_y) or fallback[2] * (tonumber(properties.force_speed) or 8))
            - (tonumber(properties.force_z) or 12)
        dx, dy = dx * 8, dy * 8
    elseif tonumber(properties.target_x) and tonumber(properties.target_y) then
        local center_x = self.x + self.width / 2
        local center_y = self.y + self.height / 2
        dx = tonumber(properties.target_x) - center_x
        dy = tonumber(properties.target_y) - (tonumber(properties.target_z) or 0) - center_y
    else
        local fallback = directions[direction] or directions.right
        dx, dy = fallback[1] * 48, fallback[2] * 48
    end
    local start_x, start_y = self.x + self.width / 2, self.y + self.height / 2
    Draw.setColor(1, 0.55, 0.15, alpha or 1)
    love.graphics.line(start_x, start_y, start_x + dx, start_y + dy)
    love.graphics.circle("fill", start_x + dx, start_y + dy, 3)
    Draw.setColor(1, 1, 1, 1)
end

return EditorLaunchVent
