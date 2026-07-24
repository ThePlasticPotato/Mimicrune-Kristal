--- Draws animated fog immediately outside a walkable surface footprint.
---@class TerrainEdgeFog : Object
---@field map Map
---@field lowest_z number?
---@field distance_field love.Image?
---@overload fun(map: Map, options?: table): TerrainEdgeFog
local TerrainEdgeFog, super = Class(Object)

local INF = 1000000
local DIAGONAL = math.sqrt(2)

local function decodedTileExists(map, packed)
    if not packed then return false end
    local gid = map:decodeTileData(packed)
    return gid ~= nil and gid ~= 0
end

---@param inside boolean[]
---@param width number
---@param height number
---@return number[] distances
function TerrainEdgeFog.computeOutsideDistances(inside, width, height)
    local distances = {}
    for index = 1, width * height do
        distances[index] = inside[index] and 0 or INF
    end

    local function relax(index, other, cost)
        if other and distances[other] + cost < distances[index] then
            distances[index] = distances[other] + cost
        end
    end

    for y = 1, height do
        for x = 1, width do
            local index = x + (y - 1) * width
            if not inside[index] then
                relax(index, x > 1 and index - 1 or nil, 1)
                relax(index, y > 1 and index - width or nil, 1)
                relax(index, x > 1 and y > 1
                    and index - width - 1 or nil, DIAGONAL)
                relax(index, x < width and y > 1
                    and index - width + 1 or nil, DIAGONAL)
            end
        end
    end
    for y = height, 1, -1 do
        for x = width, 1, -1 do
            local index = x + (y - 1) * width
            if not inside[index] then
                relax(index, x < width and index + 1 or nil, 1)
                relax(index, y < height and index + width or nil, 1)
                relax(index, x < width and y < height
                    and index + width + 1 or nil, DIAGONAL)
                relax(index, x > 1 and y < height
                    and index + width - 1 or nil, DIAGONAL)
            end
        end
    end
    return distances
end

---@param map Map
---@param options? table
function TerrainEdgeFog:init(map, options)
    options = options or {}
    self.map = map
    self.extent = math.max(tonumber(map.terrain_edge_fog_extent) or 96, 1)
    self.opacity = MathUtils.clamp(
        tonumber(map.terrain_edge_fog_opacity) or 0.42, 0, 1)
    self.scroll_x = tonumber(map.terrain_edge_fog_scroll_x) or 10
    self.scroll_y = tonumber(map.terrain_edge_fog_scroll_y) or 4
    self.wave_amplitude = math.max(
        tonumber(map.terrain_edge_fog_wave_amplitude) or 5, 0)
    self.wave_length = math.max(
        tonumber(map.terrain_edge_fog_wave_length) or 64, 1)
    self.wave_speed = tonumber(map.terrain_edge_fog_wave_speed) or 2.2
    self.resolution = math.max(
        math.floor(tonumber(map.terrain_edge_fog_resolution) or 4), 1)
    self.overlap = math.max(
        tonumber(map.terrain_edge_fog_overlap) or 8, 0)
    self.raised_void_ratio = MathUtils.clamp(
        tonumber(map.terrain_edge_fog_raised_void_ratio) or 0.5, 0, 1)
    self.exposure_distance = math.max(self.resolution * 2, 8)
    self.texture_scale = math.max(
        tonumber(map.terrain_edge_fog_scale) or 2, 0.01)
    self.texture = Assets.getTexture(map.terrain_edge_fog_texture or "fog")
    if self.texture then self.texture:setFilter("nearest", "nearest") end

    local padding = math.ceil(
        (self.extent + self.wave_amplitude + self.resolution * 2)
            / self.resolution
    ) * self.resolution
    self.padding = padding
    local map_width = map.width * map.tile_width
    local map_height = map.height * map.tile_height
    self.field_width = map_width + padding * 2
    self.field_height = map_height + padding * 2
    super.init(self, -padding, -padding, self.field_width, self.field_height)

    self.debug_select = false
    self.lowest_tile_layers = options.tile_layers or {}
    self.lowest_support_colliders = options.support_colliders or {}
    self.erase_pits = options.erase_pits ~= false
    self.block_mask = options.block_mask
    self.lowest_z = options.surface_z
    if self.lowest_z == nil then
        self.lowest_z = self:findLowestSurface()
    end
    self.z = self.lowest_z or 0
    self.distance_limit = self.extent + self.wave_amplitude
        + self.resolution * 2
    if self.lowest_z ~= nil and self.texture then
        self:buildDistanceField()
    end
end

---@param map Map
---@return TerrainEdgeFog[] fogs
function TerrainEdgeFog.createForMap(map)
    local fogs = {}
    local base = TerrainEdgeFog(map)
    if not base.distance_field then return fogs end
    table.insert(fogs, base)

    local grouped = {}
    for _, surface in pairs(map.surfaces or {}) do
        local top = surface.support_top
        if top ~= nil and top > base.lowest_z + 0.001 then
            local key = string.format("%.4f", top)
            grouped[key] = grouped[key] or {
                z = top,
                colliders = {}
            }
            for _, collider in ipairs(surface.support_colliders or {}) do
                if not collider.invert then
                    table.insert(grouped[key].colliders, collider)
                end
            end
        end
    end

    local planes = {}
    for _, plane in pairs(grouped) do
        if #plane.colliders > 0 then table.insert(planes, plane) end
    end
    table.stable_sort(planes, function(a, b) return a.z < b.z end)
    for _, plane in ipairs(planes) do
        local fog = TerrainEdgeFog(map, {
            surface_z = plane.z,
            support_colliders = plane.colliders,
            erase_pits = false,
            block_mask = base.surface_mask
        })
        if fog.distance_field then table.insert(fogs, fog) end
        fog.block_mask = nil
    end
    base.surface_mask = nil
    return fogs
end

---@return number? lowest_z
function TerrainEdgeFog:findLowestSurface()
    local tile_candidates = {}
    local requested_layer = tostring(
        self.map.terrain_edge_fog_layer or ""):lower()
    for _, layer in ipairs(self.map.tile_layers or {}) do
        local ground_tile_count = 0
        if layer.provides_ground ~= false
            and math.abs(tonumber(layer.z) or 0) < 0.001 then
            for _, packed in ipairs(layer.tile_data or {}) do
                if decodedTileExists(self.map, packed) then
                    ground_tile_count = ground_tile_count + 1
                end
            end
        end
        if ground_tile_count > 0
            and (requested_layer == ""
                or tostring(layer.name or ""):lower() == requested_layer) then
            table.insert(tile_candidates, {
                layer = layer,
                count = ground_tile_count
            })
        end
    end
    if #tile_candidates > 0 then
        table.stable_sort(tile_candidates, function(a, b)
            return a.count > b.count
        end)
    end

    local support_candidates = {}
    local requested_surface_id = tostring(
        self.map.terrain_edge_fog_surface_id or "")
    local requested_surface = requested_surface_id ~= ""
        and self.map:getSurface(requested_surface_id) or nil
    if requested_surface and requested_surface.support_top ~= nil
        and #(requested_surface.support_colliders or {}) > 0 then
        support_candidates = { requested_surface }
    else
        if requested_surface_id ~= "" then
            Kristal.Console:warn(string.format(
                "Terrain edge fog surface '%s' on map '%s' has no walkable support; using automatic base detection",
                requested_surface_id,
                tostring(self.map.id or self.map.name or "?")
            ))
        end
        local lowest_support_z
        for _, surface in pairs(self.map.surfaces or {}) do
            if surface.support_top ~= nil
                and #(surface.support_colliders or {}) > 0 then
                lowest_support_z = lowest_support_z
                    and math.min(lowest_support_z, surface.support_top)
                    or surface.support_top
            end
        end
        if lowest_support_z ~= nil then
            for _, surface in pairs(self.map.surfaces or {}) do
                if surface.support_top ~= nil
                    and math.abs(surface.support_top - lowest_support_z) < 0.001
                    and #(surface.support_colliders or {}) > 0 then
                    table.insert(support_candidates, surface)
                end
            end
        end
    end

    local support_z = support_candidates[1]
        and support_candidates[1].support_top or nil
    local tile_z = #tile_candidates > 0 and 0 or nil
    local lowest
    if requested_surface then
        lowest = support_z
    elseif support_z ~= nil and (tile_z == nil or support_z <= tile_z + 0.001) then
        lowest = support_z
    else
        lowest = tile_z
        support_candidates = {}
    end
    if lowest == nil then return nil end

    if #support_candidates == 0 and math.abs(lowest) < 0.001
        and #tile_candidates > 0 then
        self.lowest_tile_layers = { tile_candidates[1].layer }
    else
        self.lowest_tile_layers = {}
    end
    for _, surface in ipairs(support_candidates) do
        for _, collider in ipairs(surface.support_colliders) do
            if not collider.invert then
                table.insert(self.lowest_support_colliders, collider)
            end
        end
    end
    return lowest
end

---@param erase boolean?
function TerrainEdgeFog:drawFootprint(erase)
    local map = self.map
    for _, layer in ipairs(self.lowest_tile_layers) do
        love.graphics.push()
        local transform = love.graphics.getTransformRef()
        layer:applyTransformTo(transform)
        love.graphics.replaceTransform(transform)
        for index, packed in ipairs(layer.tile_data or {}) do
            if decodedTileExists(map, packed) then
                local tile_x = (index - 1) % layer.map_width
                local tile_y = math.floor((index - 1) / layer.map_width)
                love.graphics.rectangle(
                    "fill",
                    tile_x * map.tile_width,
                    tile_y * map.tile_height,
                    map.tile_width,
                    map.tile_height
                )
            end
        end
        love.graphics.pop()
    end
    if erase and self.erase_pits then
        local old_blend, old_alpha_mode = love.graphics.getBlendMode()
        love.graphics.setBlendMode("replace", "premultiplied")
        for _, pit in ipairs(map.pits or {}) do
            if not pit.invert then
                pit:drawFillFor(map.world, 0, 0, 0, 0)
            end
        end
        love.graphics.setBlendMode(old_blend, old_alpha_mode)
    end
    for _, collider in ipairs(self.lowest_support_colliders) do
        collider:drawFillFor(map.world, 1, 1, 1, 1)
    end
end

function TerrainEdgeFog:buildDistanceField()
    local grid_width = math.max(
        math.ceil(self.field_width / self.resolution), 1)
    local grid_height = math.max(
        math.ceil(self.field_height / self.resolution), 1)
    local mask = love.graphics.newCanvas(grid_width, grid_height)
    mask:setFilter("nearest", "nearest")
    local old_canvas = love.graphics.getCanvas()
    local old_r, old_g, old_b, old_a = love.graphics.getColor()
    love.graphics.setCanvas(mask)
    love.graphics.origin()
    love.graphics.clear(0, 0, 0, 0)
    love.graphics.translate(
        self.padding / self.resolution,
        self.padding / self.resolution
    )
    love.graphics.scale(1 / self.resolution)
    Draw.setColor(1, 1, 1, 1)
    self:drawFootprint(true)
    love.graphics.setCanvas(old_canvas)
    love.graphics.setColor(old_r, old_g, old_b, old_a)

    local mask_data = mask:newImageData()
    mask:release()
    local inside, inside_count = {}, 0
    for y = 0, grid_height - 1 do
        for x = 0, grid_width - 1 do
            local _, _, _, alpha = mask_data:getPixel(x, y)
            local index = x + y * grid_width + 1
            inside[index] = alpha >= 0.5
            if inside[index] then inside_count = inside_count + 1 end
        end
    end
    mask_data:release()
    if inside_count == 0 then return end
    self.surface_pixel_count = inside_count
    self.surface_mask = inside

    local distances = TerrainEdgeFog.computeOutsideDistances(
        inside, grid_width, grid_height)
    if self.block_mask then
        local exterior_count, void_count = 0, 0
        for index = 1, grid_width * grid_height do
            if not inside[index]
                and distances[index] * self.resolution
                    <= self.exposure_distance then
                exterior_count = exterior_count + 1
                if not self.block_mask[index] then
                    void_count = void_count + 1
                end
            end
        end
        self.exposure_ratio = exterior_count > 0
            and void_count / exterior_count or 0
        if self.exposure_ratio < self.raised_void_ratio then return end
    end

    local outside = {}
    for index = 1, grid_width * grid_height do
        outside[index] = not inside[index]
    end
    local inside_distances = TerrainEdgeFog.computeOutsideDistances(
        outside, grid_width, grid_height)
    local field_data = love.image.newImageData(grid_width, grid_height)
    local visible_pixel_count = 0
    for y = 0, grid_height - 1 do
        for x = 0, grid_width - 1 do
            local index = x + y * grid_width + 1
            local under_surface_edge = inside[index]
                and inside_distances[index] * self.resolution <= self.overlap
            local blocked = self.block_mask and self.block_mask[index]
                and not inside[index] or false
            local surface_blocked = inside[index] and not under_surface_edge
            local distance_pixels = inside[index] and 0
                or distances[index] * self.resolution
            if not surface_blocked and not blocked
                and distance_pixels <= self.distance_limit then
                visible_pixel_count = visible_pixel_count + 1
            end
            local distance = math.min(
                distance_pixels,
                self.distance_limit
            ) / self.distance_limit
            field_data:setPixel(
                x, y,
                surface_blocked and 1 or 0,
                blocked and 1 or 0,
                0,
                distance
            )
        end
    end
    self.visible_pixel_count = visible_pixel_count
    if visible_pixel_count == 0 then
        field_data:release()
        return
    end
    self.distance_field = love.graphics.newImage(field_data)
    field_data:release()
    self.distance_field:setFilter("nearest", "nearest")
end

function TerrainEdgeFog:draw()
    if not self.distance_field or not self.texture
        or not Kristal.Shaders["TerrainEdgeFog"] then return end
    Draw.pushShader("TerrainEdgeFog", {
        fog_texture = self.texture,
        field_size = { self.field_width, self.field_height },
        field_origin = { self.x, self.y },
        fog_size = { self.texture:getWidth(), self.texture:getHeight() },
        fog_scale = self.texture_scale,
        pixel_size = self.resolution,
        scroll = { self.scroll_x, self.scroll_y },
        time = Kristal.getTime(),
        distance_limit = self.distance_limit,
        extent = self.extent,
        wave_amplitude = self.wave_amplitude,
        wave_length = self.wave_length,
        wave_speed = self.wave_speed,
        opacity = self.opacity
    })
    Draw.draw(
        self.distance_field,
        0, 0, 0,
        self.field_width / self.distance_field:getWidth(),
        self.field_height / self.distance_field:getHeight()
    )
    Draw.popShader()
end

function TerrainEdgeFog:onRemove(parent)
    if self.distance_field then
        self.distance_field:release()
        self.distance_field = nil
    end
    super.onRemove(self, parent)
end

return TerrainEdgeFog
