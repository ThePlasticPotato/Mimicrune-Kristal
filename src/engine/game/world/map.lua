--- Stores and manages the currently loaded map. \
--- If a map in `scrips/world/maps` is defined as a folder, map data can be placed in `data.lua`, and a file named `map.lua` can be used to define a custom `Map` object for that map.
---@class Map : Class
---@overload fun(...) : Map
local Map = Class()

local function getWeatherLeafSway()
    if Game.stage and Game.stage.weather_leaf_sway then
        return Game.stage.weather_leaf_sway.amount or 0
    end

    return 0
end

local function getWeatherLeafWindSpeed()
    return 0.8 + (getWeatherLeafSway() * 0.45)
end

local function getWeatherLeafWindPhaseOffset()
    if not Game.stage then
        return 0
    end

    local now = Kristal.getTime()
    local speed = getWeatherLeafWindSpeed()
    local phase = Game.stage.weather_leaf_wind_phase

    if not phase then
        phase = {offset = 0, speed = speed}
        Game.stage.weather_leaf_wind_phase = phase
    elseif phase.speed ~= speed then
        phase.offset = phase.offset + (now * (phase.speed - speed))
        phase.speed = speed
    end

    return phase.offset
end

---@param world? World
---@param data? table
function Map:init(world, data)
    self.world = world or Game.world

    self.data = data

    self.full_map_path = Mod and Mod.info.path or ""
    self.tile_width = 40
    self.tile_height = 40
    self.width = 16
    self.height = 12
    self.name = nil
    self.music = nil
    self.keep_music = nil
    self.can_hum = nil
    self.light = false
    self.border = nil
    self.bg_color = { 0, 0, 0, 0 }
    self.platforming = false
    self.empty_tile_pit = false
    self.base_surface_plane = "z:0"
    self.underwater_underlay = false
    self.underwater_underlay_layer = nil
    self.underwater_underlay_opacity = 0.45
    self.underwater_underlay_void_strength = 0.18
    self.underwater_underlay_speed = 0.35
    self.underwater_underlay_pixel_size = 2
    self.underwater_underlay_scale = 1
    self.underwater_underlay_distortion = 2
    self.underwater_underlay_particle_strength = 0.45
    self.underwater_underlay_shallow_color = "#0B162D"
    self.underwater_underlay_deep_color = "#030711"
    self.underwater_underlay_object = nil
    self.terrain_edge_fog = false
    self.terrain_edge_fog_texture = "fog"
    self.terrain_edge_fog_layer = ""
    self.terrain_edge_fog_surface_id = ""
    self.terrain_edge_fog_extent = 96
    self.terrain_edge_fog_opacity = 0.42
    self.terrain_edge_fog_scroll_x = 10
    self.terrain_edge_fog_scroll_y = 4
    self.terrain_edge_fog_wave_amplitude = 5
    self.terrain_edge_fog_wave_length = 64
    self.terrain_edge_fog_wave_speed = 2.2
    self.terrain_edge_fog_resolution = 4
    self.terrain_edge_fog_scale = 2
    self.terrain_edge_fog_overlap = 8
    self.terrain_edge_fog_raised_void_ratio = 0.5
    self.terrain_edge_fog_object = nil
    self.terrain_edge_fog_objects = {}

    self.tilesets = {}
    self.tileset_gids = {}
    self.max_gid = 0

    self.collision = {}
    self.enemy_collision = {}
    self.block_collision = {}
    self.pits = {}
    self.tile_layers = {}
    self.image_layers = {}
    self.height_occluders = {}
    self.surfaces = {}
    self.surface_by_collider = setmetatable({}, { __mode = "k" })
    self.implicit_surface = {
        id = "__implicit_ground",
        plane = self.base_surface_plane,
        bottom = 0,
        top = 0,
        implicit = true,
        colliders = {},
        support_colliders = {}
    }
    self.shape_layers = {}
    self.markers = {}
    self.markers_by_id = {}
    self.player_spawn = nil
    self.battle_areas = {}
    self.battle_borders = {}
    self.paths = {}

    self.events = {}
    self.events_by_name = {}
    self.events_by_id = {}
    self.events_by_layer = {}

    self.shapes_by_id = {}
    self.shapes_by_name = {}

    self.hitboxes_by_id = {}
    self.hitboxes_by_name = {}

    local reader_class = self.reader_class or (data and data.__map_reader) or TiledMapReader
    assert(isClass(reader_class) and reader_class:includes(MapReader),
        "Map reader must be a MapReader class")
    self.reader = reader_class(self)

    if data then
        self.reader:initialize(data)
    end

    self.depth_per_layer = 0.1 -- its not perfect, but i doubt anyone will have 1000 layers
    self.next_layer = self.depth_per_layer

    self.next_object_id = 0

    self.object_layer = 1
    self.battle_fader_layer = 0.5
    self.tile_layer = 0
    self.layers = {}

    self.timer = Timer()
end

function Map:load()
    Game:setLight(self.light)

    self.world:addChild(self.timer)
    if self.data then
        self.reader:read(self.data)
    end
    for _, occluder in ipairs(self.height_occluders) do
        occluder.layer = self.object_layer
        occluder:resolveSourceLayer()
        occluder:resolveSurface()
    end
    if self.underwater_underlay then
        local underlay = UnderwaterUnderlay(self)
        local underlay_layer = tonumber(self.underwater_underlay_layer)
        if underlay_layer == nil then
            local lowest_terrain_layer
            for _, tile_layer in ipairs(self.tile_layers) do
                local layer = tonumber(tile_layer.layer)
                if layer and (lowest_terrain_layer == nil
                    or layer < lowest_terrain_layer) then
                    lowest_terrain_layer = layer
                end
            end
            underlay_layer = (lowest_terrain_layer or self.tile_layer)
                - self.depth_per_layer
        end
        underlay.layer = underlay_layer
        self.underwater_underlay_object = underlay
        self.world:addChild(underlay)
    end
    if self.platforming and self.terrain_edge_fog then
        local edge_fogs = TerrainEdgeFog.createForMap(self)
        for index, edge_fog in ipairs(edge_fogs) do
            if index == 1 then
                local visual_ground = self:getTileLayer(
                    self.terrain_edge_fog_layer)
                local lowest_layer = visual_ground and visual_ground.layer
                    or self.tile_layer
                if not visual_ground then
                    for _, layer in ipairs(self.tile_layers) do
                        if layer.provides_ground ~= false
                            and math.abs(tonumber(layer.z) or 0) < 0.001 then
                            lowest_layer = math.min(
                                lowest_layer,
                                layer.layer or lowest_layer
                            )
                        end
                    end
                end
                edge_fog.layer = lowest_layer - self.depth_per_layer
                self.terrain_edge_fog_object = edge_fog
            else
                edge_fog.layer = self.object_layer - self.depth_per_layer
            end
            self.world:addChild(edge_fog)
            table.insert(self.terrain_edge_fog_objects, edge_fog)
        end
    end
    for _, event in ipairs(self.events) do
        if event.onLoad then
            event:onLoad()
        end
    end
end

function Map:save(path, options)
    return self.reader:save(path, options)
end

function Map:onEnter() end
function Map:onExit() end

function Map:onFootstep(char, num) end

function Map:onGameOver() end

function Map:update() end
function Map:draw() end

function Map:getBorder(dark_transition)
    if self.border then
        return self.border
    elseif dark_transition then
        return self.light and "leaves" or "castle"
    end
end

function Map:getUniqueID()
    return "#" .. self.id
end

function Map:setFlag(flag, value)
    local uid = self:getUniqueID()
    Game:setFlag(uid .. ":" .. flag, value)
end

function Map:getFlag(flag, default)
    local uid = self:getUniqueID()
    return Game:getFlag(uid .. ":" .. flag, default)
end

function Map:addFlag(flag, amount)
    local uid = self:getUniqueID()
    return Game:addFlag(uid .. ":" .. flag, amount)
end

--- Gets a specific marker from the current map.
---@param id KristalObjectRef The name of the marker to search for, the unique numerical ID, or a Tiled object reference.
---@return number x The x-coordinate of the marker's center (or the center of the map if it doesn't exist).
---@return number y The y-coordinate of the marker's center (or the center of the map if it doesn't exist).
---@return Marker? marker The full marker data.
function Map:getMarker(id)
    local marker

    if type(id) == "table" then
        local map_id = id.map_id or id.map
        if map_id and map_id ~= self.id then
            return (self.width * self.tile_width / 2), (self.height * self.tile_height / 2), nil
        end
        local object_id = id.object_id or id.object or id.id
        if object_id ~= nil then
            marker = self.markers_by_id[object_id]
        end
    elseif type(id) == "number" then
        marker = self.markers_by_id[id]
    else
        marker = id == "spawn" and self.player_spawn or self.markers[id]
    end

    if marker == nil then
        return (self.width * self.tile_width / 2), (self.height * self.tile_height / 2), nil
    end

    return marker.center_x, marker.center_y, marker
end

--- Checks if a marker exists.
---@param id string|integer|TiledObjectRef The name of the marker to search for, or the unique numerical ID.
function Map:hasMarker(id)
    if type(id) == "table" then
        local map_id = id.map_id or id.map
        if map_id and map_id ~= self.id then return false end
        local object_id = id.object_id or id.object or id.id
        if object_id ~= nil then
            return self.markers_by_id[object_id] ~= nil
        end
    elseif type(id) == "number" then
        return self.markers_by_id[id] ~= nil
    end

    return id == "spawn" and self.player_spawn ~= nil or self.markers[id] ~= nil
end

function Map:getPath(name)
    return self.paths[name]
end

function Map:addTileset(id)
    local tileset = Registry.getTileset(id)
    if tileset then
        table.insert(self.tilesets, tileset)
        self.tileset_gids[tileset] = self.max_gid + 1
        self.max_gid = self.max_gid + tileset.tile_count
        return tileset
    else
        error("No tileset with id '" .. id .. "'")
    end
end

function Map:getTile(x, y, layer)
    local tile_layer = self:getTileLayer(layer)

    if tile_layer then
        return tile_layer:getTile(x, y)
    else
        return nil, 0
    end
end

function Map:setTile(x, y, tileset, ...)
    local args = { ... }

    local tile_layer
    if type(args[#args]) == "string" then
        tile_layer = self:getTileLayer(args[#args])
        table.remove(args, #args)
    else
        tile_layer = self:getTileLayer()
    end

    tile_layer:setTile(x, y, tileset, unpack(args))
end

--- Gets a specific event present in the current map.
---
--- If multiple objects are found (if you pass in a name), only the first will be returned. Use `Map:getEvents` to get all of them.
---@see Map.getEvents
---@param id string|integer|TiledObjectRef The name of the event, the unique numerical ID, or a Tiled object reference.
---@return Event? event The event instance, if found.
function Map:getEvent(id)
    if type(id) == "table" then
        local object_id = id.object_id or id.object or id.id
        if object_id ~= nil then
            return self.events_by_id[object_id]
        end
    elseif type(id) == "number" then
        return self.events_by_id[id]
    else
        if self.events_by_name[id] then
            return self.events_by_name[id][1]
        end
    end
end

--- Gets a list of all instances of one type of event in the current maps
---@param name? string The text id of the event to search for, fetches every event if `nil`
---@return Event[] events A table containing every instance of the event in the current map
function Map:getEvents(name)
    if name then
        return self.events_by_name[name] or {}
    else
        return self.events
    end
end

function Map:getShape(id)
    if type(id) == "number" then
        return self.shapes_by_id[id]
    else
        if self.shapes_by_name[id] then
            return self.shapes_by_name[id][1]
        end
    end
end

function Map:getHitbox(id)
    if type(id) == "number" then
        return self.hitboxes_by_id[id]
    else
        if self.hitboxes_by_name[id] then
            return self.hitboxes_by_name[id][1]
        end
    end
end

function Map:getImageLayer(id)
    return self.image_layers[id]
end

local function defaultSurfacePlane(top)
    if math.abs(top) < 0.001 then top = 0 end
    return "z:" .. tostring(top)
end

--- Registers a map collider as part of a height surface.
---@param collider Collider
---@param fallback_id? string|number
---@return table? surface
function Map:registerSurfaceCollider(collider, fallback_id)
    if not collider or collider.pit then return nil end
    local surface_id = collider.surface_id
    if not surface_id and collider.supports then
        surface_id = "collision:" .. tostring(fallback_id or collider.map_object_id
            or collider.map_object_name or #self.surfaces + 1)
        collider.surface_id = surface_id
    end
    if not surface_id then return nil end

    surface_id = tostring(surface_id)
    local surface = self.surfaces[surface_id]
    if not surface then
        surface = {
            id = surface_id,
            plane = collider.surface_plane,
            explicit_plane = collider.surface_plane ~= nil,
            bottom = math.huge,
            top = -math.huge,
            bounds = nil,
            support_bounds = nil,
            support_top = nil,
            colliders = {},
            support_colliders = {}
        }
        self.surfaces[surface_id] = surface
    elseif collider.surface_plane then
        if surface.explicit_plane and collider.surface_plane ~= surface.plane then
            Kristal.Console:warn(string.format(
                "Surface '%s' mixes planes '%s' and '%s'; keeping '%s'",
                surface_id, surface.plane, collider.surface_plane, surface.plane
            ))
        else
            surface.plane = collider.surface_plane
            surface.explicit_plane = true
        end
    end

    local bottom, top = collider:getZBounds()
    surface.bottom = math.min(surface.bottom, bottom)
    surface.top = math.max(surface.top, top)
    if collider.map_bounds then
        local bounds = collider.map_bounds
        if not surface.bounds then
            surface.bounds = {
                min_x = bounds.min_x, min_y = bounds.min_y,
                max_x = bounds.max_x, max_y = bounds.max_y
            }
        else
            surface.bounds.min_x = math.min(surface.bounds.min_x, bounds.min_x)
            surface.bounds.min_y = math.min(surface.bounds.min_y, bounds.min_y)
            surface.bounds.max_x = math.max(surface.bounds.max_x, bounds.max_x)
            surface.bounds.max_y = math.max(surface.bounds.max_y, bounds.max_y)
        end
    end
    table.insert(surface.colliders, collider)
    if collider.supports then
        table.insert(surface.support_colliders, collider)
        local bounds = collider.map_bounds
        if surface.support_top == nil or top > surface.support_top + 0.001 then
            surface.support_top = top
            surface.support_bounds = bounds and {
                min_x = bounds.min_x, min_y = bounds.min_y,
                max_x = bounds.max_x, max_y = bounds.max_y
            } or nil
        elseif math.abs(top - surface.support_top) <= 0.001 and bounds then
            if not surface.support_bounds then
                surface.support_bounds = {
                    min_x = bounds.min_x, min_y = bounds.min_y,
                    max_x = bounds.max_x, max_y = bounds.max_y
                }
            else
                surface.support_bounds.min_x =
                    math.min(surface.support_bounds.min_x, bounds.min_x)
                surface.support_bounds.min_y =
                    math.min(surface.support_bounds.min_y, bounds.min_y)
                surface.support_bounds.max_x =
                    math.max(surface.support_bounds.max_x, bounds.max_x)
                surface.support_bounds.max_y =
                    math.max(surface.support_bounds.max_y, bounds.max_y)
            end
        end
    end
    surface.plane = surface.plane or defaultSurfacePlane(surface.top)
    if not surface.explicit_plane then
        surface.plane = defaultSurfacePlane(surface.top)
    end
    self.surface_by_collider[collider] = surface
    if collider:includes(ColliderGroup) then
        for _, child in ipairs(collider.colliders) do
            self.surface_by_collider[child] = surface
        end
    end
    return surface
end

---@param id string?
---@return table? surface
function Map:getSurface(id)
    if id == nil or id == "" then return nil end
    return self.surfaces[tostring(id)]
end

---@param collider Collider?
---@return table? surface
function Map:getSurfaceForCollider(collider)
    if not collider then return nil end
    return self.surface_by_collider[collider]
        or collider.surface_id and self:getSurface(collider.surface_id) or nil
end

---@return table surface
function Map:getImplicitSurface()
    self.implicit_surface.plane = self.base_surface_plane or "z:0"
    return self.implicit_surface
end

--- Gets a tile/image layer that can provide pixels to an occlusion region.
---@param name string
---@return Object?
function Map:getDrawableLayer(name)
    if type(name) ~= "string" or name == "" then return nil end
    return self:getTileLayer(name) or self:getImageLayer(name)
end

function Map:getShapeLayer(name)
    return self.shape_layers[name]
end

function Map:getShapes(layer_prefix)
    local result = {}
    for k,v in pairs(self.shape_layers) do
        if not layer_prefix or StringUtils.startsWith(k:lower(), layer_prefix) then
            TableUtils.merge(result, v.objects)
        end
    end
    return result
end

function Map:getTileLayer(name)
    if name then
        for _, layer in ipairs(self.tile_layers) do
            if layer.name == name then
                return layer
            end
        end
    else
        return self.tile_layers[1]
    end
end

function Map:addTileLayer(depth, battle_border)
    local tilelayer = TileLayer(self)
    tilelayer.layer = depth or self.next_layer
    self.world:addChild(tilelayer)
    table.insert(self.tile_layers, tilelayer)
    if battle_border then
        table.insert(self.battle_borders, tilelayer)
    end
    if not depth then
        self.next_layer = self.next_layer + self.depth_per_layer
    end
    return tilelayer
end

function Map:loadMapData(data)
    return self.reader:call("loadMapData", data)
end

function Map:getLayerClassOrName(layer)
    return self.reader:call("getLayerClassOrName", layer)
end

function Map:isLayerType(layer, type)
    return self.reader:call("isLayerType", layer, type)
end

function Map:loadLayer(layer, depth)
    return self.reader:call("loadLayer", layer, depth)
end

---todo: leaf tile layer registry
function Map:loadTiles(layer, depth)
    -- if (tilelayer.name and tilelayer.name == "Leaves") then
    --     tilelayer:addFX(ShaderFX("windy", {
    --         ["iTime"] = function () return Kristal.getTime() end,
    --         ["weatherSway"] = getWeatherLeafSway,
    --         ["wind_speed"] = getWeatherLeafWindSpeed,
    --         ["windPhaseOffset"] = getWeatherLeafWindPhaseOffset
    --     }))
    -- end
    return self.reader:call("loadTiles", layer, depth)
end

function Map:createTileLayer(data)
    return self.reader:call("createTileLayer", data)
end

function Map:decodeTileData(tile)
    return self.reader:call("decodeTileData", tile)
end

function Map:encodeTileData(tileset, tile_id, ...)
    return self.reader:call("encodeTileData", tileset, tile_id, ...)
end

function Map:loadImage(layer, depth)
    return self.reader:call("loadImage", layer, depth)
end

function Map:loadTextureFromImagePath(filename)
    return self.reader:call("loadTextureFromImagePath", filename)
end

function Map:loadCollision(layer)
    return self.reader:call("loadCollision", layer)
end

function Map:loadEnemyCollision(layer)
    return self.reader:call("loadEnemyCollision", layer)
end

function Map:loadBlockCollision(layer)
    return self.reader:call("loadBlockCollision", layer)
end

function Map:loadBattleAreas(layer)
    return self.reader:call("loadBattleAreas", layer)
end

function Map:loadHitboxes(layer)
    return self.reader:call("loadHitboxes", layer)
end

function Map:loadShapes(layer)
    return self.reader:call("loadShapes", layer)
end

function Map:loadHeightOcclusion(layer, depth)
    return self.reader:call("loadHeightOcclusion", layer, depth)
end

function Map:loadMarkers(layer)
    return self.reader:call("loadMarkers", layer)
end

function Map:loadPaths(layer)
    return self.reader:call("loadPaths", layer)
end

function Map:shouldLoadObject(data, layer)
    return self.reader:call("shouldLoadObject", data, layer)
end

function Map:getObjectType(data)
    return self.reader:call("getObjectType", data)
end

function Map:loadObjects(layer, depth, layer_type)
    return self.reader:call("loadObjects", layer, depth, layer_type)
end

--- Loads an object using the old system, based on the Registry.
---
--- Solely for legacy support of projects and libraries that use the old event system.
---@internal
---@param name string # The name of the object to load.
---@param data table # The Tiled object data for the object.
---@return Event? # The loaded object, or `nil` if none was found.
function Map:legacyLoadObject(name, data)
    return self.reader:call("legacyLoadObject", name, data)
end

--- Load an object by its name.
---@param name string The name of the object to load.
---@param data table The serialized object data for the object.
---@param context? table Format-specific loading context.
---@return Event? The loaded object, or `nil` if none was found.
function Map:loadObject(name, data, context)
    return self.reader:call("loadObject", name, data, context)
end

function Map:loadController(name, data, context)
    return self.reader:call("loadController", name, data, context)
end

function Map:populateTilesets(data)
    return self.reader:call("populateTilesets", data)
end

function Map:loadTilesetFromTilesetPath(filename)
    return self.reader:call("loadTilesetFromTilesetPath", filename)
end

---@return Tileset?
---@return integer
function Map:getTileset(id)
    return self.reader:call("getTileset", id)
end

function Map:getTileObjectRect(data)
    return self.reader:call("getTileObjectRect", data)
end

function Map:createTileObject(data, x, y, width, height)
    return self.reader:call("createTileObject", data, x, y, width, height)
end

return Map
