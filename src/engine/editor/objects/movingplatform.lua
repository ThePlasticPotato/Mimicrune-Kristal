---@class EditorMovingPlatform : EditorObject
---@overload fun(data?: table, options?: table): EditorMovingPlatform
local EditorMovingPlatform, super = Class(EditorObject)

EditorMovingPlatform.placement_shape = "rectangle"
EditorMovingPlatform.sprite_property = "sprite"
EditorMovingPlatform.sprite_alignment = "top_left"

function EditorMovingPlatform:init(data, options)
    super.init(self, data, options)
    self:registerProperty("supports", "boolean", {
        name = "Walkable Collider Top", default = true
    })
    self:registerProperty("sprite", "asset_path", {
        asset_registry = { "texture", "frames" }, path_root = "assets/sprites",
        strip_extension = true, extensions = { "png", "jpg", "jpeg" }
    })
    self:registerProperty("sprite_speed", "number", { name = "Sprite Speed" })
    self:registerProperty("scalex", "number", { name = "Scale X", default = 2 })
    self:registerProperty("scaley", "number", { name = "Scale Y", default = 2 })
    self:registerProperty("depth", "number", { name = "Platform Height", default = 16 })
    self:registerProperty("offset_x", "number", { name = "Travel X", default = 0 })
    self:registerProperty("offset_y", "number", { name = "Travel Y", default = 0 })
    self:registerProperty("offset_z", "number", { name = "Travel Z", default = 0 })
    self:registerProperty("duration", "number", { name = "Travel Time", default = 2 })
    self:registerProperty("wait", "number", { name = "Endpoint Wait", default = 0 })
    self:registerProperty("mode", "choice", { name = "Path Mode", default = "pingpong", choices = {
        { value = "pingpong", label = "Ping-Pong" },
        { value = "loop", label = "Loop" },
        { value = "once", label = "Once" }
    } })
    self:registerProperty("easing", "string", { name = "Easing", default = "linear" })
    self:registerProperty("autostart", "boolean", { name = "Auto Start", default = true })
    self:registerProperty("carry_momentum", "boolean", { name = "Preserve Exit Momentum", default = true })
    self:registerProperty("push_actors", "boolean", { name = "Push Actors", default = true })
    self:registerProperty("stop_on_block", "boolean", { name = "Stop When Blocked", default = true })
    self:registerProperty("one_way", "boolean", { name = "One-Way Surface", default = false })
end

function EditorMovingPlatform:createObject(map, context)
    return MovingPlatform(self.data.x, self.data.y, self:getRectData(), self.data.properties)
end

function EditorMovingPlatform:draw(alpha)
    super.draw(self, alpha)
    local properties = self.data.properties or {}
    if not self.sprite then
        local width, height = self:getBoundsSize()
        local depth = math.max(tonumber(properties.depth) or 16, 0)
        Draw.setColor(0.2, 0.55, 0.68, (alpha or 1) * 0.55)
        love.graphics.rectangle("fill", self.x, self.y + height - depth, width, depth)
        Draw.setColor(0.3, 0.8, 0.95, (alpha or 1) * 0.7)
        love.graphics.rectangle("fill", self.x, self.y - depth, width, height)
    end
    local dx = tonumber(properties.offset_x or properties.movex) or 0
    local dy = tonumber(properties.offset_y or properties.movey) or 0
    local dz = tonumber(properties.offset_z or properties.movez) or 0
    if dx == 0 and dy == 0 and dz == 0 then
        Draw.setColor(1, 1, 1, 1)
        return
    end
    local width, height = self:getBoundsSize()
    local x1, y1 = self.x + width / 2, self.y + height / 2
    local x2, y2 = x1 + dx, y1 + dy - dz
    Draw.setColor(0.3, 0.9, 1, alpha or 1)
    love.graphics.line(x1, y1, x2, y2)
    love.graphics.circle("fill", x2, y2, 3)
    Draw.setColor(1, 1, 1, 1)
end

return EditorMovingPlatform
