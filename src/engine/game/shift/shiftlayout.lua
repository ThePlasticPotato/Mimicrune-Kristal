---@class ShiftLayout
local ShiftLayout = {}

ShiftLayout.VERSION = 1
ShiftLayout.DIRECTORY = "shift/layouts"
ShiftLayout.KINDS = { office = true, camera = true, night = true }

local function propertiesToTable(properties)
    if type(properties) ~= "table" then return {} end
    if properties[1] == nil then return properties end
    local result = {}
    for _, property in ipairs(properties) do
        if type(property) == "table" and type(property.name) == "string" then
            result[property.name] = property.value
        end
    end
    return result
end

---@param definition table
---@return table
function ShiftLayout.resolveObjectDefinition(definition)
    local resolved = TableUtils.copy(definition or {}, true)
    for key, value in pairs(propertiesToTable(definition and definition.properties)) do
        if resolved[key] == nil then resolved[key] = value end
    end
    resolved.layout_id = resolved.layout_id
        or (type(resolved.id) == "string" and resolved.id or nil)
        or resolved.name
    resolved.scale_x = resolved.scale_x or resolved.scalex
    resolved.scale_y = resolved.scale_y or resolved.scaley
    return resolved
end

---@param definition table
---@return string?
function ShiftLayout.getObjectID(definition)
    return ShiftLayout.resolveObjectDefinition(definition).layout_id
end

---@param source string
---@param path? string
---@return table? data
---@return string? reason
function ShiftLayout.decode(source, path)
    local data, reason = EditorFormat.decodeJSON(source, path or "shift layout")
    if not data then return nil, reason end
    if data.version ~= ShiftLayout.VERSION then
        return nil, string.format("%s uses unsupported shift layout version %s",
            path or "Shift layout", tostring(data.version))
    end
    if not ShiftLayout.KINDS[data.kind] then
        return nil, string.format("%s requires kind 'office', 'camera', or 'night'",
            path or "Shift layout")
    end
    if type(data.layers) ~= "table" then data.layers = {} end
    return data
end

---@param data table
---@return string? encoded
---@return string? reason
function ShiftLayout.encode(data)
    return EditorFormat.encodeJSON(data, "map", { pretty = true })
end

---@param layout table
---@return fun(): table?, table?
function ShiftLayout.iterObjects(layout)
    local entries = {}
    local function append(layers)
        for _, layer in ipairs(layers or {}) do
            for _, object in ipairs(layer.objects or {}) do
                table.insert(entries, { object = object, layer = layer })
            end
            append(layer.layers)
        end
    end
    append(layout.layers)
    local index = 0
    return function()
        index = index + 1
        local entry = entries[index]
        if entry then return entry.object, entry.layer end
    end
end

---@param object Object
---@param definition table
function ShiftLayout.applyObject(object, definition)
    local resolved = ShiftLayout.resolveObjectDefinition(definition)
    object.layout_id = resolved.layout_id or object.layout_id
    if resolved.x ~= nil then object.x = resolved.x end
    if resolved.y ~= nil then object.y = resolved.y end
    if resolved.width ~= nil then object.width = resolved.width end
    if resolved.height ~= nil then object.height = resolved.height end
    if resolved.layer ~= nil then object.layer = resolved.layer end
    if resolved.scale_x ~= nil then object.scale_x = resolved.scale_x end
    if resolved.scale_y ~= nil then object.scale_y = resolved.scale_y end
    if resolved.rotation ~= nil then object.rotation = resolved.rotation end
    if resolved.visible ~= nil then object.visible = resolved.visible end
    if type(resolved.color) == "table" and object.setColor then
        object:setColor(resolved.color)
    end
    for key, value in pairs(propertiesToTable(resolved.properties)) do
        if key ~= "texture" or not object:includes(Sprite) then
            object[key] = value
        end
    end
    if object.applyLayoutDefinition then object:applyLayoutDefinition(resolved) end
end

---@param registry Registry
function ShiftLayout.discover(registry)
    local directories = {}
    local function add(path)
        if love.filesystem.getInfo(path, "directory") then table.insert(directories, path) end
    end
    add(ShiftLayout.DIRECTORY)
    add("scripts/" .. ShiftLayout.DIRECTORY)
    if Mod then
        for _, library in Kristal.iterLibraries() do
            if library.info and library.info.path then
                add(library.info.path .. "/scripts/" .. ShiftLayout.DIRECTORY)
            end
        end
        add(Mod.info.path .. "/scripts/" .. ShiftLayout.DIRECTORY)
    end

    for _, directory in ipairs(directories) do
        for _, relative in ipairs(FileSystemUtils.getFilesRecursive(directory, ".json")) do
            local path = directory .. "/" .. relative .. ".json"
            local source, read_error = love.filesystem.read(path)
            if not source then error("Could not read shift layout '" .. path .. "': " .. tostring(read_error)) end
            local data, reason = ShiftLayout.decode(source, path)
            if not data then error(reason) end
            local folder, relative_id = relative:match("^([^/]+)/(.+)$")
            local inferred = ({ offices = "office", cameras = "camera", nights = "night" })[folder]
            if inferred and inferred ~= data.kind then
                error(string.format("Shift layout '%s' has kind '%s' but is stored under '%s'",
                    path, tostring(data.kind), folder))
            end
            data.id = data.id or relative_id or relative
            data.full_path = path
            registry.registerShiftLayout(data.kind, data.id, data)
        end
    end
end

return ShiftLayout
