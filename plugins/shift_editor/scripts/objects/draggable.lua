local EditorShiftObject = ...

---@class EditorShiftDraggable : EditorShiftObject
---@overload fun(data?: table, options?: table): EditorShiftDraggable
local EditorShiftDraggable, super = Class(EditorShiftObject)

EditorShiftDraggable.editor_name = "Shift Draggable"
EditorShiftDraggable.editor_description = "An office control dragged along an authored path."
EditorShiftDraggable.sprite_property = "texture"

function EditorShiftDraggable:getSpriteScale()
    return 1, 1
end

function EditorShiftDraggable:init(data, options)
    super.init(self, data, options)
    self:registerProperty("texture", "asset_path", {
        name = "Sprite", asset_registry = { "texture", "frames" },
        path_root = "assets/sprites", strip_extension = true,
        extensions = { "png", "jpg", "jpeg" }
    })
    self:registerProperty("path_axis", "choice", {
        name = "Path Axis", default = "vertical", choices = {
            { value = "vertical", label = "Vertical" },
            { value = "horizontal", label = "Horizontal" },
            { value = "free", label = "Free" }
        }
    })
    self:registerProperty("path_x", "number", { name = "Path X", default = 0 })
    self:registerProperty("path_y", "number", { name = "Path Y", default = 90 })
    self:registerProperty("initial_progress", "number", {
        name = "Initial Position", default = 0, min = 0, max = 1
    })
    self:registerProperty("endpoint_threshold", "number", {
        name = "Endpoint Threshold", default = 0.001, min = 0, max = 0.5
    })
    self:registerProperty("drag_resistance", "number", {
        name = "Drag Resistance", default = 1, min = 0.01
    })
    self:registerProperty("drag_inertia", "number", {
        name = "Drag Inertia", default = 0, min = 0, max = 0.99
    })
end

function EditorShiftDraggable:getPathOffset()
    local x = tonumber(self.property_set:getValue("path_x")) or 0
    local y = tonumber(self.property_set:getValue("path_y")) or 0
    local axis = self.property_set:getValue("path_axis") or "vertical"
    if axis == "vertical" then x = 0 end
    if axis == "horizontal" then y = 0 end
    return x, y
end

function EditorShiftDraggable:drawEditorSelection(context)
    local path_x, path_y = self:getPathOffset()
    local radius = 6 / math.max(context.view_zoom or 1, 0.001)
    local previous_width = love.graphics.getLineWidth()
    love.graphics.setLineWidth(2 / math.max(context.view_zoom or 1, 0.001))
    Draw.setColor(0.25, 0.9, 1, 0.95)
    love.graphics.line(0, 0, path_x, path_y)
    love.graphics.circle("fill", path_x, path_y, radius)
    Draw.setColor(0.02, 0.08, 0.1, 1)
    love.graphics.circle("line", path_x, path_y, radius)
    love.graphics.setLineWidth(previous_width)
end

function EditorShiftDraggable:getEditorInteraction(x, y, context)
    local path_x, path_y = self:getPathOffset()
    local radius = 10 / math.max(context.view_zoom or 1, 0.001)
    local dx, dy = x - path_x, y - path_y
    if dx * dx + dy * dy <= radius * radius then
        return { id = "shift_path_end", cursor = "crosshair", name = "Move Drag Path End" }
    end
end

function EditorShiftDraggable:updateEditorInteraction(interaction, x, y, context)
    if interaction.id ~= "shift_path_end" then return false end
    local axis = self.property_set:getValue("path_axis") or "vertical"
    if context.snap then
        local grid_x = math.max(1, tonumber(context.tile_width) or 1)
        local grid_y = math.max(1, tonumber(context.tile_height) or 1)
        x = MathUtils.round(x / grid_x) * grid_x
        y = MathUtils.round(y / grid_y) * grid_y
    end
    if axis == "vertical" then
        x = 0
    elseif axis == "horizontal" then
        y = 0
    elseif Input.shift() then
        if math.abs(x) >= math.abs(y) then y = 0 else x = 0 end
    end
    if self.properties.path_x == x and self.properties.path_y == y then return false end
    self.properties.path_x, self.properties.path_y = x, y
    return true
end

return EditorShiftDraggable
