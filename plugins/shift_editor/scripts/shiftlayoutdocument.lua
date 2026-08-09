---@class EditorShiftLayoutDocument : EditorMapDocument
---@overload fun(workspace: EditorProjectWorkspace, path: string, contents: string, layer_types: table): EditorShiftLayoutDocument
local EditorShiftLayoutDocument, super = Class(EditorMapDocument)

local SHAPE_TYPES = {
    rectangle = "rectangle", ellipse = "ellipse", polygon = "polygon",
    polyline = "polyline", line = "line", point = "point"
}

local PROPERTY_FIELDS = {
    "layout_id", "texture", "door", "target", "target_id", "camera", "label",
    "path_axis", "path_x", "path_y", "path_start_x", "path_start_y",
    "path_end_x", "path_end_y", "initial_progress", "endpoint_threshold",
    "mode", "scalex", "scaley"
}

local function propertyTable(properties)
    if type(properties) ~= "table" then return {} end
    if properties[1] == nil then return TableUtils.copy(properties, true) end
    local result = {}
    for _, property in ipairs(properties) do
        if type(property) == "table" and type(property.name) == "string" then
            result[property.name] = property.value
        end
    end
    return result
end

local function normalizePolyline(points)
    if type(points) ~= "table" then return nil end
    if type(points[1]) == "table" then return TableUtils.copy(points, true) end
    local result = {}
    for index = 1, #points, 2 do
        table.insert(result, { x = points[index] or 0, y = points[index + 1] or 0 })
    end
    return result
end

local function normalizeObject(source, next_id)
    local object = TableUtils.copy(source, true)
    local properties = propertyTable(object.properties)
    if type(object.id) == "string" and properties.layout_id == nil then
        properties.layout_id = object.id
    elseif object.layout_id ~= nil and properties.layout_id == nil then
        properties.layout_id = object.layout_id
    end
    for _, key in ipairs(PROPERTY_FIELDS) do
        if object[key] ~= nil and properties[key] == nil then properties[key] = object[key] end
    end
    if object.scale_x ~= nil and properties.scalex == nil then properties.scalex = object.scale_x end
    if object.scale_y ~= nil and properties.scaley == nil then properties.scaley = object.scale_y end
    if object.path_end_x ~= nil and properties.path_x == nil then
        properties.path_x = object.path_end_x - (object.x or 0)
    end
    if object.path_end_y ~= nil and properties.path_y == nil then
        properties.path_y = object.path_end_y - (object.y or 0)
    end
    properties.path_end_x, properties.path_end_y = nil, nil
    properties.path_start_x, properties.path_start_y = nil, nil
    if object.type and SHAPE_TYPES[object.type] then
        object.shape = SHAPE_TYPES[object.type]
        object.type = nil
        if object.shape == "line" or object.shape == "polyline" then
            object.polyline = normalizePolyline(object.polyline or object.points)
            object.points = nil
        end
    end
    object.id = tonumber(object.id) or next_id
    object.properties = properties
    object.layout_id = nil
    for _, key in ipairs(PROPERTY_FIELDS) do
        if key ~= "layout_id" then object[key] = nil end
    end
    object.scale_x, object.scale_y = nil, nil
    object.path_end_x, object.path_end_y = nil, nil
    return object
end

local function normalizeLayers(layout, layer_types)
    local next_object_id = 1
    local function normalizeList(source_layers)
        local layers = {}
        for _, source in ipairs(source_layers or {}) do
        local layer = TableUtils.copy(source, true)
        if layer.type == "group" or layer.kind == "group" or layer.layers then
            layer.type, layer.kind = "group", "group"
            layer._editor_type_id = "folder"
            layer._editor_kind_id = "group"
            layer.layers = normalizeList(layer.layers)
            table.insert(layers, layer)
        else
        local mode = layer.mode or (layout.kind == "office" and "panorama"
            or layout.kind == "camera" and "camera_feed" or "camera_map")
        if mode == "contents" and layout.kind == "camera" then mode = "camera_feed" end
        if mode == "contents" and layout.kind == "night" then mode = "camera_map" end
        layer.mode = mode
        layer.type = "objectgroup"
        layer.kind = "object"
        layer._editor_type_id = layer_types[mode] or layer_types.contents
        layer._editor_kind_id = "object"
        layer._editor_depth_offset = tonumber(layer.depth) or 0
        layer.width, layer.height = layout.width, layout.height
        layer.properties = propertyTable(layer.properties)
        layer.objects = layer.objects or {}
        for index, object in ipairs(layer.objects) do
            layer.objects[index] = normalizeObject(object, next_object_id)
            next_object_id = math.max(next_object_id + 1, layer.objects[index].id + 1)
        end
        if mode == "static" then
            layer._shift_static_offset = true
            layer._shift_source_offset_x = tonumber(layer.offsetx) or 0
            layer.offsetx = layer._shift_source_offset_x + (tonumber(layout.pan) or 0)
        end
        table.insert(layers, layer)
        end
        end
        return layers
    end
    return normalizeList(layout.layers)
end

local function stripEditorState(value)
    if type(value) ~= "table" then return value end
    if value.includes and value:includes(EditorObjectReference) then
        return { map = value.map_id, object = value.object_id }
    end
    local result = {}
    for key, child in pairs(value) do
        if type(key) ~= "string" or key:sub(1, 1) ~= "_" then
            result[key] = stripEditorState(child)
        end
    end
    return result
end

function EditorShiftLayoutDocument:init(workspace, path, contents, layer_types)
    local layout, reason = ShiftLayout.decode(contents, path)
    assert(layout, reason)
    self.workspace = workspace
    self.path = path
    self.real_path = ProjectFileSystem.getRealPath(path)
    self.relative_path = workspace:getRelativePath(path) or path
    self.name = layout.name or layout.id or (path:match("([^/\\]+)%.json$") or "Shift Layout")
    self.file_type = "text"
    self.persistent = true
    self.layer_types = layer_types
    self.layer_modes = {}
    for mode, type_id in pairs(layer_types) do self.layer_modes[type_id] = mode end
    self.layout_metadata = TableUtils.copy(layout, true)
    self.layout_metadata.layers = nil
    self.layout_metadata.full_path = nil
    self.preview_pan = tonumber(layout.pan) or 0
    self.virtual_map_id = "shift-layout:" .. tostring(path):gsub("\\", "/")
    self.previous_map_data = Registry.getMapData(self.virtual_map_id)
    self.previous_map_reader = Registry.getMapReader(self.virtual_map_id)

    local map_data = {
        id = self.virtual_map_id,
        name = self.name,
        width = math.max(1, tonumber(layout.width) or SCREEN_WIDTH),
        height = math.max(1, tonumber(layout.height) or SCREEN_HEIGHT),
        grid_width = 1,
        grid_height = 1,
        tilewidth = 1,
        tileheight = 1,
        bg_color = { 0, 0, 0, 0 },
        layers = normalizeLayers(layout, layer_types)
    }
    self.map_data = map_data
    Registry.registerMapData(self.virtual_map_id, map_data, EditorMapReader)
    super.init(self, workspace.editor, self.virtual_map_id)
    local layers = self:getEditableLayers(self.virtual_map_id)
    if layers[1] then self:setSelectedLayer(layers[1]._editor_uid, self.virtual_map_id) end
end

function EditorShiftLayoutDocument:captureHistoryState()
    local state = super.captureHistoryState(self)
    state.shift_layout_metadata = TableUtils.copy(self.layout_metadata, true)
    state.shift_preview_pan = self.preview_pan
    return state
end

function EditorShiftLayoutDocument:restoreHistoryState(state)
    if not super.restoreHistoryState(self, state) then return false end
    self.layout_metadata = TableUtils.copy(state.shift_layout_metadata or self.layout_metadata, true)
    self.preview_pan = tonumber(state.shift_preview_pan) or 0
    return true
end

function EditorShiftLayoutDocument:getLayoutKind()
    return self.layout_metadata.kind
end

function EditorShiftLayoutDocument:isLayerTypeAvailable(layer_type)
    if layer_type.id == "folder" then return true end
    local mode = self.layer_modes[layer_type.id]
    local kind = self:getLayoutKind()
    if kind == "office" then return mode == "panorama" or mode == "static" end
    if kind == "camera" then return mode == "camera_feed" end
    if kind == "night" then return mode == "camera_map" end
    return false
end

function EditorShiftLayoutDocument:getEditorTitle()
    return self.name or self.layout_metadata.name or self.layout_metadata.id or "Shift Layout"
end

function EditorShiftLayoutDocument:setPreviewPan(value)
    value = MathUtils.clamp(tonumber(value) or 0, 0,
        math.max(0, (tonumber(self.map_data.width) or SCREEN_WIDTH) - SCREEN_WIDTH))
    local delta = value - self.preview_pan
    if delta == 0 then return false end
    self.preview_pan = value
    self.layout_metadata.pan = value
    for _, layer in ipairs(self:getAllEditableLayers(self.virtual_map_id)) do
        if layer._shift_static_offset then layer.offsetx = (layer.offsetx or 0) + delta end
    end
    self:invalidatePreview(self.virtual_map_id)
    return true
end

function EditorShiftLayoutDocument:getPropertiesTarget()
    local fields = {
        {
            id = "layout_id", label = "Layout ID", compact = true,
            get = function() return self.layout_metadata.id or "" end
        },
        {
            id = "layout_name", label = "Name", compact = true,
            get = function() return self.layout_metadata.name or "" end,
            set = function(value)
                if self.layout_metadata.name == value then return false end
                self.layout_metadata.name, self.name = value, value
                return true
            end
        }
    }
    if self:getLayoutKind() == "office" then
        table.insert(fields, {
            id = "background", label = "Background", control = "path",
            path_kind = "asset", asset_registry = { "texture", "frames" },
            path_root = "assets/sprites", strip_extension = true,
            get = function() return self.layout_metadata.background or "" end,
            set = function(value)
                if self.layout_metadata.background == value then return false end
                self.layout_metadata.background = value ~= "" and value or nil
                self:invalidatePreview(self.virtual_map_id)
                return true
            end
        })
        table.insert(fields, {
            id = "preview_pan", label = "Preview Pan", compact = true,
            get = function() return self.preview_pan end,
            set = function(value) return self:setPreviewPan(value) end
        })
    elseif self:getLayoutKind() == "camera" then
        table.insert(fields, {
            id = "background", label = "Background", control = "path",
            path_kind = "asset", asset_registry = { "texture", "frames" },
            path_root = "assets/sprites", strip_extension = true,
            get = function() return self.layout_metadata.background or "" end,
            set = function(value)
                if self.layout_metadata.background == value then return false end
                self.layout_metadata.background = value ~= "" and value or nil
                self:invalidatePreview(self.virtual_map_id)
                return true
            end
        })
        local function addCameraNumber(id, label, default, minimum)
            table.insert(fields, {
                id = id, label = label, compact = true,
                get = function()
                    local value = self.layout_metadata[id]
                    return value == nil and default or value
                end,
                set = function(value)
                    value = tonumber(value) or default
                    if minimum ~= nil then value = math.max(minimum, value) end
                    if self.layout_metadata[id] == value then return false end
                    self.layout_metadata[id] = value
                    self:invalidatePreview(self.virtual_map_id)
                    return true
                end
            })
        end
        addCameraNumber("pan_x", "Initial Pan X", 0, 0)
        addCameraNumber("pan_y", "Initial Pan Y", 0, 0)
        addCameraNumber("pan_speed_x", "Horizontal Pan Speed", 240, 0)
        addCameraNumber("pan_speed_y", "Vertical Pan Speed", 240, 0)
        addCameraNumber("pan_edge_margin", "Pan Edge Margin", 48, 1)
    end
    return {
        title = self.name .. " (Shift Layout)",
        history_owner = self,
        map_id = self.virtual_map_id,
        fields = fields
    }
end

function EditorShiftLayoutDocument:drawPreview(entry, outline_width, map_selected, options)
    if self.layout_metadata.background then
        local texture = Assets.getTexture(self.layout_metadata.background)
        if texture then
            Draw.setColor(1, 1, 1, 1)
            Draw.draw(texture, 0, 0)
        end
    end
    local drawn = super.drawPreview(self, entry, outline_width, map_selected, options)
    local kind = self:getLayoutKind()
    if (kind == "office" or kind == "camera") and not (options and options.export) then
        local previous_width = love.graphics.getLineWidth()
        love.graphics.setLineWidth(2 * (outline_width or 1))
        Draw.setColor(0.2, 0.9, 1, 0.9)
        local pan_x = kind == "office" and self.preview_pan
            or tonumber(self.layout_metadata.pan_x) or 0
        local pan_y = kind == "camera" and tonumber(self.layout_metadata.pan_y) or 0
        love.graphics.rectangle("line", pan_x, pan_y, SCREEN_WIDTH,
            math.min(SCREEN_HEIGHT, entry.height or SCREEN_HEIGHT))
        love.graphics.setLineWidth(previous_width)
        Draw.setColor(1, 1, 1, 1)
    end
    return drawn
end

function EditorShiftLayoutDocument:buildLayout()
    local layout = TableUtils.copy(self.layout_metadata, true)
    layout.version = ShiftLayout.VERSION
    layout.kristal_version = tostring(Kristal.Version)
    layout.width = tonumber(self.map_data.width) or SCREEN_WIDTH
    layout.height = tonumber(self.map_data.height) or SCREEN_HEIGHT
    layout.pan = self:getLayoutKind() == "office" and self.preview_pan or layout.pan
    local function serializeObject(source)
        local object = stripEditorState(source)
        local object_type = self:getEditorObjectType(source, self.virtual_map_id)
        local success, editor_object = pcall(Registry.createEditorObject,
            object_type, source, { map_id = self.virtual_map_id })
        if success and editor_object then
            local properties, reason = editor_object.property_set:encodeEntries({
                map = self.map_data,
                map_id = self.virtual_map_id,
                object = source
            })
            assert(properties, reason)
            object.properties = properties
        end
        return object
    end
    local function serializeLayer(source)
        local layer = stripEditorState(source)
        if source._editor_kind_id == "group" then
            layer.type, layer.kind = "group", "group"
            layer.layers = {}
            for _, child in ipairs(source.layers or {}) do
                table.insert(layer.layers, serializeLayer(child))
            end
            return layer
        end
        local mode = self.layer_modes[source._editor_type_id] or source.mode or "contents"
        layer.type, layer.kind, layer.mode = "object", "object", mode
        layer.depth = tonumber(source._editor_depth_offset) or tonumber(source.depth) or 0
        layer.objects = {}
        for _, object in ipairs(source.objects or {}) do
            table.insert(layer.objects, serializeObject(object))
        end
        if source._shift_static_offset then
            layer.offsetx = (tonumber(source.offsetx) or 0) - self.preview_pan
        end
        if layer.offsetx == 0 then layer.offsetx = nil end
        if layer.offsety == 0 then layer.offsety = nil end
        return layer
    end
    layout.layers = {}
    for _, source in ipairs(self:getEditableLayers(self.virtual_map_id)) do
        table.insert(layout.layers, serializeLayer(source))
    end
    return layout
end

function EditorShiftLayoutDocument:save()
    local layout = self:buildLayout()
    local encoded, reason = ShiftLayout.encode(layout)
    if not encoded then return false, reason end
    local written
    written, reason = ProjectFileSystem.writeFile(self.path, encoded)
    if not written then return false, reason end
    layout.full_path = self.path
    Registry.registerShiftLayout(layout.kind, layout.id, layout)
    self.layout_metadata = TableUtils.copy(layout, true)
    self.layout_metadata.layers = nil
    self.layout_metadata.full_path = nil
    self.workspace:onDocumentSaved(self)
    if self.editor and self.editor.history then self.editor.history:markSaved(self) end
    return true
end

function EditorShiftLayoutDocument:release()
    if self.editor and self.editor.history then self.editor.history:forgetOwner(self) end
    if Registry.getMapData(self.virtual_map_id) == self.map_data then
        Registry.map_data[self.virtual_map_id] = self.previous_map_data
        Registry.map_readers[self.virtual_map_id] = self.previous_map_reader
    end
end

return EditorShiftLayoutDocument
