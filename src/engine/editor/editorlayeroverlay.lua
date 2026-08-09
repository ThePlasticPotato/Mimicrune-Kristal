--- Draws hitboxes and shapes for a layer in the editor/game preview.
---@class EditorLayerOverlay : Class
---@field color number[]
---@field layer number
---@field layer_type table?
---@field layer_uid string?
---@field source_layer table
---@field visible boolean
---@overload fun(layer: table, layer_type?: table, depth?: number, map?: Map): EditorLayerOverlay
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
    if role == "slope" then return { 0.85, 0.45, 1 } end
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

    local points, closed, connector_step = getShapePoints(object)
    local rotation = math.rad(object.rotation or 0)
    local cosine, sine = math.cos(rotation), math.sin(rotation)
    local footprint = {}
    local min_x, min_y, max_x, max_y = math.huge, math.huge, -math.huge, -math.huge
    for index, point in ipairs(points) do
        local x = point[1] * cosine - point[2] * sine
        local y = point[1] * sine + point[2] * cosine
        footprint[index] = { x, y }
        min_x, min_y = math.min(min_x, x), math.min(min_y, y)
        max_x, max_y = math.max(max_x, x), math.max(max_y, y)
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
    local dash_length = 5 * (line_width or 1)

    local function drawFootprintAt(elevation)
        if #footprint == 1 then
            local x, y = HeightTransform.projectPoint(
                footprint[1][1], footprint[1][2], elevation)
            love.graphics.points(x, y)
            return
        end
        local shifted = {}
        for index, point in ipairs(footprint) do
            shifted[index] = {
                HeightTransform.projectPoint(point[1], point[2], elevation)
            }
        end
        drawDashedPath(shifted, closed, dash_length)
    end

    local function getSlopeElevation(point)
        local direction = tostring(properties.slope_direction or properties.slope_axis or "right"):lower()
        local y_axis = direction == "up" or direction == "down" or direction == "y"
        local coordinate = y_axis and point[2] or point[1]
        local minimum = y_axis and min_y or min_x
        local maximum = y_axis and max_y or max_x
        local progress = maximum ~= minimum
            and MathUtils.clamp((coordinate - minimum) / (maximum - minimum), 0, 1) or 1
        if direction == "left" or direction == "up" or direction == "negative" then
            progress = 1 - progress
        end
        return z + depth * progress
    end

    local function drawSlopeSurface()
        local shifted = {}
        for index, point in ipairs(footprint) do
            shifted[index] = { HeightTransform.projectPoint(
                point[1], point[2], getSlopeElevation(point)) }
        end
        drawDashedPath(shifted, closed, dash_length)
        for index = 1, #footprint, connector_step do
            local point = footprint[index]
            local bottom_x, bottom_y = HeightTransform.projectPoint(point[1], point[2], z)
            local top_x, top_y = HeightTransform.projectPoint(
                point[1], point[2], getSlopeElevation(point))
            love.graphics.line(bottom_x, bottom_y, top_x, top_y)
        end
    end

    local top_z = z + depth
    local authoring_z = MapUtils.getCollisionAuthoringZ(properties, depth)
    if authoring_z ~= 0 then
        Draw.setColor(role_color[1], role_color[2], role_color[3], guide_alpha * 0.28)
        drawFootprintAt(0)
    end
    if depth > 0 and role == "slope" then
        Draw.setColor(role_color[1], role_color[2], role_color[3], guide_alpha * 0.28)
        drawFootprintAt(z)
        Draw.setColor(role_color[1], role_color[2], role_color[3], guide_alpha * 0.75)
        drawSlopeSurface()
    elseif depth > 0 then
        Draw.setColor(role_color[1], role_color[2], role_color[3], guide_alpha * 0.62)
        drawFootprintAt(authoring_z == top_z and z or top_z)
        Draw.setColor(role_color[1], role_color[2], role_color[3], guide_alpha * 0.42)
        for index = 1, #footprint, connector_step do
            local point = footprint[index]
            local bottom_x, bottom_y =
                HeightTransform.projectPoint(point[1], point[2], z)
            local top_x, top_y =
                HeightTransform.projectPoint(point[1], point[2], top_z)
            love.graphics.line(bottom_x, bottom_y, top_x, top_y)
        end
    end

    local ruler_x = max_x + 7 * (line_width or 1)
    local base_y = min_y
    local _, bottom_y = HeightTransform.projectPoint(ruler_x, base_y, z)
    local _, top_y = HeightTransform.projectPoint(ruler_x, base_y, top_z)
    if top_z ~= 0 or z ~= 0 then
        Draw.setColor(role_color[1], role_color[2], role_color[3], guide_alpha * 0.72)
        love.graphics.line(ruler_x, base_y, ruler_x, top_y)
        love.graphics.line(ruler_x - 3, base_y, ruler_x + 3, base_y)
        love.graphics.line(ruler_x - 3, bottom_y, ruler_x + 3, bottom_y)
        love.graphics.line(ruler_x - 3, top_y, ruler_x + 3, top_y)
    end

    local role_names = {
        wall = "WALL", solid = "SOLID", surface = "SURFACE", slope = "SLOPE", pit = "PIT"
    }
    local label
    if role == "pit" then
        label = "PIT"
    elseif role == "slope" then
        local direction = tostring(properties.slope_direction or properties.slope_axis or "right"):upper()
        label = "SLOPE uphill=" .. direction .. " "
            .. formatHeight(z) .. ".." .. formatHeight(top_z)
    elseif depth == 0 then
        label = role_names[role] .. " z=" .. formatHeight(z)
    else
        label = role_names[role] .. " " .. formatHeight(z) .. ".." .. formatHeight(top_z)
    end
    local surface_id = properties.surface_id or properties.structure_id
    local surface_plane = properties.surface_plane or properties.render_plane
    if surface_id and surface_id ~= "" then
        label = label .. "  surface=" .. tostring(surface_id)
    end
    if surface_plane and surface_plane ~= "" then
        label = label .. "  plane=" .. tostring(surface_plane)
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

local function drawOcclusionGuide(object, layer, color, alpha, line_width, map)
    local properties = TableUtils.mergeMany(layer.properties or {}, object.properties or {})
    local source = tostring(properties.source_object or properties.visual_object
        or properties.source_layer or properties.visual_layer
        or "<set visual source>")
    local surface_id = properties.surface_id or properties.structure_id
    local face_direction = tostring(properties.face_direction or properties.face or "front")
    local surface = map and map.getSurface and map:getSurface(surface_id) or nil
    local z = tonumber(properties.z or properties.occlusion_z)
        or surface and surface.bottom or 0
    local depth = math.max(tonumber(properties.depth or properties.occlusion_depth)
        or surface and (surface.top - surface.bottom) or 0, 0)
    local sort_offset = tonumber(properties.sort_y_offset or properties.sort_offset_y) or 0
    local linked = surface_id ~= nil and tostring(surface_id) ~= ""
    local label
    if linked then
        label = string.format("DEPTH FACE %s  source=%s  surface=%s",
            face_direction:upper(), source, tostring(surface_id))
    else
        label = string.format("DEPTH FACE %s  source=%s  %s..%s",
            face_direction:upper(), source, formatHeight(z), formatHeight(z + depth))
    end

    local width, height = object.width or 0, object.height or 0
    local object_world_x = (object.x or 0) + (layer.offsetx or 0)
    local object_world_y = (object.y or 0) + (layer.offsety or 0)
    local face_y = tonumber(properties.face_y or properties.depth_y)
    local face_x = tonumber(properties.face_x or properties.depth_x)
    local face_bounds = surface and (surface.support_bounds or surface.bounds)
    if face_bounds then
        if not face_y and face_direction == "front" then
            face_y = face_bounds.max_y
        elseif not face_y and face_direction == "back" then
            face_y = face_bounds.min_y
        elseif not face_x and face_direction == "left" then
            face_x = face_bounds.min_x
        elseif not face_x and face_direction == "right" then
            face_x = face_bounds.max_x
        end
    end
    local anchor_y = face_y and (face_y - object_world_y) + sort_offset or nil
    local anchor_x = face_x and (face_x - object_world_x) or nil
    love.graphics.push()
    love.graphics.translate(object_world_x, object_world_y)
    love.graphics.rotate(math.rad(object.rotation or 0))
    local previous_width = love.graphics.getLineWidth()
    love.graphics.setLineWidth(line_width or 1)
    local guide_alpha = math.min(color[4] or 1, 0.95) * alpha
    Draw.setColor(0.75, 0.3, 1, guide_alpha)
    if (face_direction == "front" or face_direction == "back") and anchor_y then
        drawDashedLine(0, anchor_y, width, anchor_y, 5 * (line_width or 1))
        local direction = face_direction == "front" and 1 or -1
        love.graphics.line(width / 2, anchor_y,
            width / 2, anchor_y + direction * 10)
        love.graphics.line(width / 2, anchor_y + direction * 10,
            width / 2 - 3, anchor_y + direction * 6)
        love.graphics.line(width / 2, anchor_y + direction * 10,
            width / 2 + 3, anchor_y + direction * 6)
    elseif (face_direction == "left" or face_direction == "right") and anchor_x then
        drawDashedLine(anchor_x, 0, anchor_x, height, 5 * (line_width or 1))
        local direction = face_direction == "right" and 1 or -1
        love.graphics.line(anchor_x, height / 2,
            anchor_x + direction * 10, height / 2)
        love.graphics.line(anchor_x + direction * 10, height / 2,
            anchor_x + direction * 6, height / 2 - 3)
        love.graphics.line(anchor_x + direction * 10, height / 2,
            anchor_x + direction * 6, height / 2 + 3)
    elseif linked then
        label = label .. "  boundary=derived"
    else
        anchor_y = height + sort_offset
        drawDashedLine(0, anchor_y, width, anchor_y, 5 * (line_width or 1))
        label = label .. "  boundary=legacy-mask-bottom"
    end
    local font = love.graphics.getFont()
    local label_x, label_y = 4, (anchor_y or height) + 5
    Draw.setColor(0.04, 0.04, 0.05, guide_alpha * 0.88)
    love.graphics.rectangle("fill", label_x - 2, label_y - 1,
        font:getWidth(label) + 4, font:getHeight() + 2)
    Draw.setColor(0.82, 0.5, 1, guide_alpha)
    love.graphics.print(label, label_x, label_y)
    love.graphics.setLineWidth(previous_width)
    love.graphics.pop()
end

function EditorLayerOverlay:init(layer, layer_type, depth, map)
    self.source_layer = layer
    self.layer_uid = layer._editor_uid
    MapUtils.addLayerOffset(self, depth)
    self.layer_type = layer_type
    self.map = map
    self.color = Registry.layer_types:getLayerColor(layer, layer_type)
    self.visible = true
end

function EditorLayerOverlay:drawObject(object, alpha, line_width)
    local width, height = object.width or 0, object.height or 0
    local points = object.polygon or object.polyline
    local color = self.color
    local visual_z = 0
    if self.layer_type and self.layer_type.collision_layer then
        local properties = TableUtils.mergeMany(
            self.source_layer.properties or {}, object.properties or {})
        local depth = math.max(tonumber(properties.depth) or 0, 0)
        local role = MapUtils.getCollisionRole(properties, depth)
        visual_z = MapUtils.getCollisionAuthoringZ(properties, depth)
        color = getRoleColor(role)
    end
    love.graphics.push()
    local object_x, object_y = HeightTransform.projectPoint(
        (object.x or 0) + (self.source_layer.offsetx or 0),
        (object.y or 0) + (self.source_layer.offsety or 0),
        visual_z
    )
    love.graphics.translate(object_x, object_y)
    love.graphics.rotate(math.rad(object.rotation or 0))
    local previous_width = love.graphics.getLineWidth()
    if object.polyline and object.shape_data and tonumber(object.shape_data.thickness) then
        love.graphics.setLineWidth(math.max(line_width or 1,
            tonumber(object.shape_data.thickness) * (line_width or 1)))
    else
        love.graphics.setLineWidth(line_width or 1)
    end

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
    if self.layer_type and self.layer_type.id == "occlusion" then
        drawOcclusionGuide(object, self.source_layer, color, alpha, line_width, self.map)
    else
        drawHeightGuide(object, self.source_layer, color, alpha, line_width)
    end
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
