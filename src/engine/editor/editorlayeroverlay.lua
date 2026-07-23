--- Draws hitboxes and shapes for a layer in the editor/game preview.
---@class EditorLayerOverlay : Class
---@field color number[]
---@field layer number
---@field layer_type table?
---@field layer_uid string?
---@field source_layer table
---@field visible boolean
---@overload fun(layer: table, layer_type?: table, depth?: number): EditorLayerOverlay
local EditorLayerOverlay = Class()

local function drawDashedLine(x1, y1, x2, y2, dash_length)
    local dx, dy = x2 - x1, y2 - y1
    local length = math.sqrt(dx * dx + dy * dy)
    if length == 0 then return end
    local nx, ny = dx / length, dy / length
    for distance = 0, length, dash_length * 2 do
        local finish = math.min(length, distance + dash_length)
        love.graphics.line(
            x1 + nx * distance, y1 + ny * distance,
            x1 + nx * finish, y1 + ny * finish
        )
    end
end

local function drawDashedPath(points, closed, dash_length)
    if #points < 2 then return end
    local edge_count = closed and #points or #points - 1
    for index = 1, edge_count do
        local next_index = index == #points and 1 or index + 1
        drawDashedLine(
            points[index][1], points[index][2],
            points[next_index][1], points[next_index][2],
            dash_length
        )
    end
end

local function getShapePoints(object)
    local points, closed, connector_step = {}, false, 1
    if object.polygon or object.polyline then
        for _, point in ipairs(object.polygon or object.polyline) do
            local x, y = MapUtils.getPointCoordinates(point)
            table.insert(points, { x, y })
        end
        closed = object.polygon ~= nil
    elseif object.shape == "ellipse" and (object.width or 0) > 0 and (object.height or 0) > 0 then
        local radius_x, radius_y = object.width / 2, object.height / 2
        for index = 0, 23 do
            local angle = index / 24 * math.pi * 2
            table.insert(points, {
                radius_x + math.cos(angle) * radius_x,
                radius_y + math.sin(angle) * radius_y
            })
        end
        closed = true
        connector_step = 6
    elseif (object.width or 0) ~= 0 or (object.height or 0) ~= 0 then
        points = {
            { 0, 0 }, { object.width or 0, 0 },
            { object.width or 0, object.height or 0 }, { 0, object.height or 0 }
        }
        closed = true
    else
        points = { { 0, 0 } }
    end
    return points, closed, connector_step
end

local function formatHeight(value)
    if value == math.floor(value) then return tostring(math.floor(value)) end
    return string.format("%.2f", value):gsub("0+$", ""):gsub("%.$", "")
end

local function getRoleColor(role)
    if role == "wall" then return { 1, 0.55, 0.2 } end
    if role == "solid" then return { 0.2, 0.9, 1 } end
    if role == "surface" then return { 0.25, 1, 0.45 } end
    return { 1, 0.25, 0.25 }
end

local function drawHeightGuide(object, layer, color, alpha, line_width)
    local properties = TableUtils.mergeMany(layer.properties or {}, object.properties or {})
    local z = tonumber(properties.z) or 0
    local depth = math.max(tonumber(properties.depth) or 0, 0)
    local role = MapUtils.getCollisionRole(properties, depth)
    local explicitly_typed = properties.collision_role ~= nil
        and properties.collision_role ~= "auto"
        or properties.pit == true or properties.platform == true
    if z == 0 and depth == 0 and not explicitly_typed then return end

    local points, closed = getShapePoints(object)
    local rotation = math.rad(object.rotation or 0)
    local cosine, sine = math.cos(rotation), math.sin(rotation)
    local footprint = {}
    local min_y, max_x = math.huge, -math.huge
    for index, point in ipairs(points) do
        local x = point[1] * cosine - point[2] * sine
        local y = point[1] * sine + point[2] * cosine
        footprint[index] = { x, y }
        min_y, max_x = math.min(min_y, y), math.max(max_x, x)
    end

    love.graphics.push()
    love.graphics.translate(
        (object.x or 0) + (layer.offsetx or 0),
        (object.y or 0) + (layer.offsety or 0)
    )
    local previous_width = love.graphics.getLineWidth()
    love.graphics.setLineWidth(line_width or 1)
    local role_color = getRoleColor(role)
    local guide_alpha = math.min(color[4] or 1, 0.9) * alpha
    Draw.setColor(role_color[1], role_color[2], role_color[3], guide_alpha * 0.9)
    local dash_length = 5 * (line_width or 1)

    if #footprint == 1 then
        love.graphics.points(footprint[1][1], footprint[1][2])
    else
        drawDashedPath(footprint, closed, dash_length)
    end

    local top_z = z + depth
    local ruler_x = max_x + 7 * (line_width or 1)
    local base_y = min_y
    local bottom_y, top_y = base_y - z, base_y - top_z
    if top_z ~= 0 or z ~= 0 then
        love.graphics.line(ruler_x, base_y, ruler_x, top_y)
        love.graphics.line(ruler_x - 3, base_y, ruler_x + 3, base_y)
        love.graphics.line(ruler_x - 3, bottom_y, ruler_x + 3, bottom_y)
        love.graphics.line(ruler_x - 3, top_y, ruler_x + 3, top_y)
    end

    local role_names = { wall = "WALL", solid = "SOLID", surface = "SURFACE", pit = "PIT" }
    local label
    if role == "pit" then
        label = "PIT"
    elseif depth == 0 then
        label = role_names[role] .. " z=" .. formatHeight(z)
    else
        label = role_names[role] .. " " .. formatHeight(z) .. ".." .. formatHeight(top_z)
    end
    local label_x, label_y = ruler_x + 5, math.min(base_y, top_y) - 6
    local font = love.graphics.getFont()
    Draw.setColor(0.04, 0.04, 0.05, guide_alpha * 0.85)
    love.graphics.rectangle("fill", label_x - 2, label_y - 1,
        font:getWidth(label) + 4, font:getHeight() + 2)
    Draw.setColor(role_color[1], role_color[2], role_color[3], guide_alpha)
    love.graphics.print(label, label_x, label_y)
    love.graphics.setLineWidth(previous_width)
    love.graphics.pop()
end

function EditorLayerOverlay:init(layer, layer_type, depth)
    self.source_layer = layer
    self.layer_uid = layer._editor_uid
    MapUtils.addLayerOffset(self, depth)
    self.layer_type = layer_type
    self.color = Registry.layer_types:getLayerColor(layer, layer_type)
    self.visible = true
end

function EditorLayerOverlay:drawObject(object, alpha, line_width)
    local width, height = object.width or 0, object.height or 0
    local points = object.polygon or object.polyline
    love.graphics.push()
    love.graphics.translate((object.x or 0) + (self.source_layer.offsetx or 0),
        (object.y or 0) + (self.source_layer.offsety or 0))
    love.graphics.rotate(math.rad(object.rotation or 0))
    local previous_width = love.graphics.getLineWidth()
    if object.polyline and object.shape_data and tonumber(object.shape_data.thickness) then
        love.graphics.setLineWidth(math.max(line_width or 1,
            tonumber(object.shape_data.thickness) * (line_width or 1)))
    else
        love.graphics.setLineWidth(line_width or 1)
    end

    local color = self.color
    Draw.setColor(color[1] or 1, color[2] or 1, color[3] or 1, 0.14 * alpha)
    if points then
        if #points >= 3 and object.polygon then
            love.graphics.polygon("fill", MapUtils.collectPointCoordinates(points))
        end
    elseif object.shape == "ellipse" and width > 0 and height > 0 then
        love.graphics.ellipse("fill", width / 2, height / 2, width / 2, height / 2)
    elseif width > 0 or height > 0 then
        love.graphics.rectangle("fill", 0, 0, width, height)
    end

    Draw.setColor(color[1] or 1, color[2] or 1, color[3] or 1,
        math.min(color[4] or 1, 0.9) * alpha)
    if points then
        local coordinates = MapUtils.collectPointCoordinates(points)
        if object.polygon and #coordinates >= 6 then
            love.graphics.polygon("line", coordinates)
        elseif #coordinates >= 4 then
            for _, edge in ipairs(MapUtils.getPolylineEdges(object, #points)) do
                local first, second = points[edge[1]], points[edge[2]]
                local x1, y1 = MapUtils.getPointCoordinates(first)
                local x2, y2 = MapUtils.getPointCoordinates(second)
                love.graphics.line(x1, y1, x2, y2)
            end
        end
    elseif object.shape == "ellipse" and width > 0 and height > 0 then
        love.graphics.ellipse("line", width / 2, height / 2, width / 2, height / 2)
    elseif width > 0 or height > 0 then
        love.graphics.rectangle("line", 0, 0, width, height)
    else
        love.graphics.line(-4, 0, 4, 0)
        love.graphics.line(0, -4, 0, 4)
    end
    love.graphics.setLineWidth(previous_width)
    love.graphics.pop()
    drawHeightGuide(object, self.source_layer, color, alpha, line_width)
end

function EditorLayerOverlay:draw(alpha, line_width, selected)
    if not self.visible then return end
    alpha = alpha or 1
    local previous_width = love.graphics.getLineWidth()
    love.graphics.setLineWidth(line_width or 1)
    for _, object in ipairs(self.source_layer.objects or {}) do
        if object.visible ~= false then self:drawObject(object, alpha, line_width) end
    end
    love.graphics.setLineWidth(previous_width)
    Draw.setColor(1, 1, 1, 1)
end

return EditorLayerOverlay
