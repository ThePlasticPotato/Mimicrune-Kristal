---@class Assets
---
---@field loaded boolean
---
---@field data Assets.data
---
---@field frames_for table<string, {[1]: string, [2]: number}>
---@field texture_ids table<love.Image, string>
---@field sounds table<string, Sound>
---@field sound_instances table<string, Sound[]>
---@field quads table<string, love.Quad>
---
---@field saved_data table?
---
local Assets = {}
local self = Assets

local DEFAULT_CHARACTER_BUCKETS = {
    "character:cassidy",
    "character:elizabeth",
    "character:evan",
    "character:fredbear",
    "character:kris",
    "character:noelle",
    "character:ralsei",
    "character:susie",
    "character:vessel",
}

local function normalizeBucketList(value)
    local result, seen = {}, {}
    local function add(id)
        id = type(id) == "string" and StringUtils.trim(id) or nil
        if id and id ~= "" and not seen[id] then
            seen[id] = true
            table.insert(result, id)
        end
    end
    if type(value) == "string" then
        for id in value:gmatch("[^,%s]+") do add(id) end
    elseif type(value) == "table" then
        for _, id in ipairs(value) do add(id) end
    end
    return result
end

local function sameBucketList(a, b)
    a, b = normalizeBucketList(a), normalizeBucketList(b)
    if #a ~= #b then return false end
    local found = {}
    for _, id in ipairs(a) do found[id] = true end
    for _, id in ipairs(b) do if not found[id] then return false end end
    return true
end

function Assets.parseAssetBucketList(value)
    return normalizeBucketList(value)
end

function Assets.getDeclaredAssetBuckets(data)
    if type(data) ~= "table" then return {} end
    return normalizeBucketList(data.asset_buckets or data.asset_bucket)
end

---@class Assets.data
---@field texture table<string, love.Image>
---@field texture_data table<string, love.ImageData>
---@field frames table<string, love.Image[]>
---@field frame_ids table<string, string[]>
---@field fonts table<string, love.Font|{default: number, [number]: love.Font}>
---@field font_data table<string, love.Data>
---@field font_bmfont_data table<string, string>
---@field font_image_data table<string, love.ImageData>
---@field font_settings table<string, Assets.font_settings>
---@field sound_data table<string, love.SoundData>
---@field sound_settings table<string, Assets.sound_settings>
---@field music table<string, string>
---@field shaders table<string, love.Shader>
---@field shader_paths table<string, string>
---@field videos table<string, string>
---@field bubble_settings table<string, table>
---@field midi table<string, string>

--- Settings for a font asset, paired with the actual font data as a .json file.
---@class Assets.font_settings
---@field defaultSize integer? # The default size of the font.
---@field autoScale boolean? # Whether to scale the default-sized font to fit requested sizes. This is true by default for image and BMFont fonts.
---@field glyphs string? # (Image fonts only) Characters in the font, in order from left to right.
---@field hinting love.HintingMode? # (TrueType fonts only) The hinting mode to load the font with.
---@field fallbacks Assets.font_settings.fallbacks[]? # Fallback fonts to use in case there are missing glyphs.

---@class Assets.font_settings.fallbacks
---@field font string # ID of the fallback font. It must be of the same font type as the base font.
---@field size number? # (TrueType fonts only) The default size of the fallback font.

--- Settings for a sound asset, paired with the actual sound data as a .json file.
---@class Assets.sound_settings
---@field volume number? # Default volume to play the sound at.

Assets.saved_data = nil

---@internal
---@return any task
function Assets.getQueue(bucket_id, asset_type)
    if not self.queued_tasks[bucket_id] then
        self.queued_tasks[bucket_id] = {}
    end
    if not self.queued_tasks[bucket_id][asset_type] then
        self.queued_tasks[bucket_id][asset_type] = {}
    end
    return self.queued_tasks[bucket_id][asset_type]
end

function Assets.init()
    Assets.clear()
    AssetLoaders.init()
    self.bucket_generation = 0
    self.bucket_activation = 0
    self.queued_tasks = {}
    self.asset_load_in_channel = love.thread.getChannel("asset_load_in")
    self.asset_load_out_channel = love.thread.getChannel("asset_load_out")
    self.asset_load_in_channel:clear()
    self.asset_load_out_channel:clear()
    local thread_arg = Kristal.Args["asset-loader-threads"]
    local configured_threads = tonumber(thread_arg and thread_arg[1])
        or tonumber(Kristal.Config["assetLoaderThreads"])
        or 0
    local processor_count = love.system.getProcessorCount()
    if configured_threads <= 0 then
        configured_threads = math.min(4, math.max(1, processor_count - 1))
    end
    self.asset_load_worker_count = math.max(1, math.min(8, math.floor(configured_threads)))
    self.asset_load_in_flight_limit = math.max(64, self.asset_load_worker_count * 32)
    self.asset_load_threads = {}
    for worker_id = 1, self.asset_load_worker_count do
        local thread = love.thread.newThread("src/engine/loading/assetloadthread.lua")
        thread:start(worker_id)
        table.insert(self.asset_load_threads, thread)
    end
    print(string.format("[AssetLoader] Started %d decode worker(s) on %d logical processor(s), queue limit %d",
        self.asset_load_worker_count, processor_count, self.asset_load_in_flight_limit))
    ---@type AssetBucket[]
    self.buckets = {
        AssetBucket("engine", { "assets" }, {
            active = true, persistent = true, priority = 0, scope = "engine"
        }),
        AssetBucket("engine-editor", { "assets/buckets/editor" }, {
            active = false, priority = 20, scope = "engine"
        }),
        AssetBucket("project", { "assets" }, {
            active = false, priority = 100, scope = "project"
        }),
    }
    self.bucket_by_id = {}
    for _, bucket in ipairs(self.buckets) do
        self.bucket_by_id[bucket.bucket_id] = bucket
    end
    for index, bucket_id in ipairs(DEFAULT_CHARACTER_BUCKETS) do
        local character_id = bucket_id:match("^character:(.+)$")
        self.defineBucket(bucket_id, { "assets/buckets/characters/" .. character_id }, {
            active = false, priority = 10 + index, scope = "engine"
        })
    end
    self.project_bucket_config = nil
    self.project_bucket_ids = {}
    self.project_engine_bucket_ids = {}
    self.party_character_bucket_ids = {}
    self.active_map_bucket = nil
    self.active_map_buckets = {}
    self.getBucket("engine"):startLoading({ "assets" })
end

---@return integer generation
function Assets.nextBucketGeneration()
    self.bucket_generation = (self.bucket_generation or 0) + 1
    return self.bucket_generation
end

function Assets.shutdown()
    for _, thread in ipairs(self.asset_load_threads or {}) do
        if thread:isRunning() then self.asset_load_in_channel:push("stop") end
    end
end

---@return boolean loading
function Assets.isLoading()
    for _, bucket in ipairs(self.buckets or {}) do
        if bucket.state == AssetBucket.State.LOADING then return true end
    end
    return false
end

function Assets.getAssetCount()
    local asset_total = 0
    local asset_loaded = 0
    for _, bucket in pairs(self.buckets) do
        asset_loaded = asset_loaded + bucket.assets_loaded
        asset_total = asset_total + bucket.assets_total
    end
    return asset_loaded, asset_total
end

---@param bucket_id string
---@return table? stats
function Assets.getLoadStats(bucket_id)
    return self.getBucket(bucket_id).last_load_stats
end

function Assets.clear()
    self.loaded = false
    self.data = {
        texture = {},
        texture_data = {},
        frame_ids = {},
        frames = {},
        fonts = {},
        font_data = {},
        font_bmfont_data = {},
        font_image_data = {},
        font_settings = {},
        sound_data = {},
        sound_settings = {},
        music = {},
        videos = {},
        bubbles = {},
        bubble_settings = {},
        shaders = {},
        shader_paths = {},
        midi = {}
    }
    self.frames_for = {}
    self.texture_ids = {}
    self.sounds = {}
    self.sound_instances = {}
    self.quads = {}
end

---@param data Assets.data
function Assets.loadData(data)
    TableUtils.merge(self.data, data, true)

    self.parseData(data)

    self.loaded = true
end

---@param asset_type string
---@param asset_id string
---@return any asset
function Assets.get(asset_type, asset_id)
    if not AssetLoaders.exists(asset_type) then
        error(string.format("Attempt to get unknown asset type '%s' with id '%s'", asset_type, asset_id), 2)
    end
    return Assets.internalGet(asset_type, asset_id, 2)
end

function Assets.tryGet(asset_type, asset_id)
    if not AssetLoaders.exists(asset_type) then
        error(string.format("Attempt to get unknown asset type '%s' with id '%s'", asset_type, asset_id), 2)
    end
    if Assets.internalHas(asset_type, asset_id) then
        return Assets.internalGet(asset_type, asset_id)
    end
end

--- Iterate over assets of a particular type.
---@param asset_type string
---@param id_prefix string?
---@return fun(): string
function Assets.iterate(asset_type, id_prefix)
    id_prefix = id_prefix or ""
    return coroutine.wrap(function()
        for _, bucket in ipairs(self.buckets) do
            if bucket:isActive() then
                for id in pairs(Assets.getQueue(bucket.bucket_id, asset_type)) do
                    if StringUtils.startsWith(id, id_prefix) then
                        coroutine.yield(id)
                    end
                end
                for id in pairs(bucket.loaded_assets[asset_type] or {}) do
                    if StringUtils.startsWith(id, id_prefix) then
                        coroutine.yield(id)
                    end
                end
            end
        end
    end)
end

local ASSET_REGISTRY_TYPES = {
    sound_data = "sound",
    sound_settings = "sound",
    music = "music",
    shaders = "shader",
    shader_paths = "shader",
    videos = "video",
    fonts = "font",
    font_data = "font",
    font_bmfont_data = "font",
    font_image_data = "font",
    font_settings = "font",
    bubbles = "bubble",
    bubble_settings = "bubble",
    midi = "midi",
}

---@param registry string
---@param id_prefix string?
---@return fun(): string
function Assets.iterateRegistry(registry, id_prefix)
    id_prefix = id_prefix or ""
    if registry == "texture" then
        return coroutine.wrap(function()
            for _, bucket in ipairs(self.buckets) do
                if bucket:isActive() then
                    for id in pairs(bucket.exact_sprite_groups or {}) do
                        if StringUtils.startsWith(id, id_prefix) then coroutine.yield(id) end
                    end
                end
            end
        end)
    elseif registry == "frames" then
        return self.iterate("sprite", id_prefix)
    end

    local asset_type = ASSET_REGISTRY_TYPES[registry]
    if asset_type then return self.iterate(asset_type, id_prefix) end

    return coroutine.wrap(function()
        for id in pairs(self.data and self.data[registry] or {}) do
            id = tostring(id)
            if StringUtils.startsWith(id, id_prefix) then coroutine.yield(id) end
        end
    end)
end

---@private
---@param asset_type string
---@param asset_id string
---@return any asset
function Assets.internalGet(asset_type, asset_id, error_level)
    for i = #self.buckets, 1, -1 do
        if self.buckets[i]:has(asset_type, asset_id) then
            return self.buckets[i]:get(asset_type, asset_id)
        end
    end
    local errstring = string.format("Attempt to get missing asset of type '%s' with ID '%s'", asset_type, asset_id)
    error(errstring, error_level)
end

---@private
---@param asset_type string
---@param asset_id string
---@return boolean found
function Assets.internalHas(asset_type, asset_id)
    for i = #self.buckets, 1, -1 do
        if self.buckets[i]:has(asset_type, asset_id) then
            return true
        end
    end
    return false
    
end

---@private
---@param exact_id string
---@return love.Image? texture
---@return love.ImageData? data
function Assets.internalGetExactSprite(exact_id)
    for i = #self.buckets, 1, -1 do
        local bucket = self.buckets[i]
        if bucket:hasExactSprite(exact_id) then
            return bucket:getExactSprite(exact_id)
        end
    end
    return nil, nil
end

---@param bucket_id string
---@return AssetBucket? bucket
function Assets.tryGetBucket(bucket_id)
    return self.bucket_by_id and self.bucket_by_id[bucket_id]
end

---@param bucket_id string
---@return AssetBucket bucket
function Assets.getBucket(bucket_id)
    return self.tryGetBucket(bucket_id)
        or error(string.format("Attempt to get non-existent bucket '%s'", bucket_id), 2)
end

---@param bucket AssetBucket
function Assets.promoteBucket(bucket)
    self.bucket_activation = (self.bucket_activation or 0) + 1
    bucket.activation_order = self.bucket_activation
    table.sort(self.buckets, function(a, b)
        if a.priority ~= b.priority then return a.priority < b.priority end
        return a.activation_order < b.activation_order
    end)
end

---@param bucket_id string
function Assets.activateBucket(bucket_id)
    local bucket = self.getBucket(bucket_id)
    bucket:setActive(true)
    self.promoteBucket(bucket)
end

---@param bucket_id string
function Assets.deactivateBucket(bucket_id)
    self.getBucket(bucket_id):setActive(false)
end

---@param bucket_id string
---@param paths string[]
---@param options? table
---@return AssetBucket bucket
function Assets.defineBucket(bucket_id, paths, options)
    if self.tryGetBucket(bucket_id) then
        error(string.format("Attempt to redefine asset bucket '%s'", bucket_id), 2)
    end
    local bucket = AssetBucket(bucket_id, paths or {}, options)
    table.insert(self.buckets, bucket)
    self.bucket_by_id[bucket_id] = bucket
    return bucket
end

---@param bucket_id string
---@param force? boolean
function Assets.removeBucket(bucket_id, force)
    local bucket = self.getBucket(bucket_id)
    if next(bucket.owners) and not force then
        error(string.format("Attempt to remove owned asset bucket '%s'", bucket_id), 2)
    end
    if bucket.state ~= AssetBucket.State.UNLOADED then bucket:unload() end
    TableUtils.removeValue(self.buckets, bucket)
    self.bucket_by_id[bucket_id] = nil
end

---@param bucket_id string
---@param owner any
---@param options? {active?: boolean, eager?: boolean}
---@param after? function
function Assets.acquireBucket(bucket_id, owner, options, after)
    options = options or {}
    local bucket = self.getBucket(bucket_id)
    if owner ~= nil then bucket.owners[owner] = true end
    local activate = options.active ~= false
    local eager = options.eager == true

    if eager and activate then self.activateBucket(bucket_id) end

    local function complete()
        if activate then self.activateBucket(bucket_id) end
        if after then after(bucket) end
    end

    if bucket.state == AssetBucket.State.LOADED then
        complete()
    elseif bucket.state == AssetBucket.State.LOADING then
        bucket:onComplete(complete)
    else
        bucket:setActive(eager and activate)
        bucket:startLoading(nil, complete)
    end
end

---@param party PartyMember[]
function Assets.syncPartyCharacterBuckets(party)
    local desired = {}
    for _, member in ipairs(party or {}) do
        local bucket_id = member and member.id and ("character:" .. member.id)
        if bucket_id and self.tryGetBucket(bucket_id) then desired[bucket_id] = true end
    end
    for bucket_id in pairs(self.party_character_bucket_ids or {}) do
        if not desired[bucket_id] and self.tryGetBucket(bucket_id) then
            self.releaseBucket(bucket_id, "game-party")
        end
    end
    for bucket_id in pairs(desired) do
        if not self.party_character_bucket_ids or not self.party_character_bucket_ids[bucket_id] then
            self.acquireBucket(bucket_id, "game-party", { active = true, eager = true })
        end
    end
    self.party_character_bucket_ids = desired
end

function Assets.releasePartyCharacterBuckets()
    for bucket_id in pairs(self.party_character_bucket_ids or {}) do
        if self.tryGetBucket(bucket_id) then self.releaseBucket(bucket_id, "game-party") end
    end
    self.party_character_bucket_ids = {}
end

---@param bucket_id string
---@param owner any
---@param force? boolean
function Assets.releaseBucket(bucket_id, owner, force)
    local bucket = self.getBucket(bucket_id)
    if owner ~= nil then bucket.owners[owner] = nil end
    if force or (not bucket.persistent and next(bucket.owners) == nil) then
        bucket:setActive(false)
        if bucket.state ~= AssetBucket.State.UNLOADED then bucket:unload() end
    end
end

---@param requests {id: string, owner: any, active?: boolean}[]
---@param after function
function Assets.acquireBuckets(requests, after)
    local remaining = #requests
    if remaining == 0 then
        after()
        return
    end
    local function complete()
        remaining = remaining - 1
        if remaining == 0 then after() end
    end
    for _, request in ipairs(requests) do
        self.acquireBucket(request.id, request.owner,
            { active = request.active ~= false }, complete)
    end
end

local function getRelativeBucketPaths(mod, definition)
    local paths = definition.paths or definition.path or {}
    if type(paths) == "string" then paths = { paths } end
    local result = {}
    for _, path in ipairs(paths) do
        table.insert(result, mod.path .. "/" .. path:gsub("^/+", ""))
    end
    return result
end

local function appendBuckets(result, seen, value)
    for _, bucket_id in ipairs(normalizeBucketList(value)) do
        if not seen[bucket_id] then
            seen[bucket_id] = true
            table.insert(result, bucket_id)
        end
    end
end

local function getConfiguredMapBuckets(config, map_id)
    local zones = config and (config.mapBuckets or config.mapZones)
    if type(zones) ~= "table" or type(map_id) ~= "string" then return nil end
    if zones[map_id] then return zones[map_id] end

    local best_prefix, best_buckets
    for prefix, bucket_ids in pairs(zones) do
        local normalized = prefix:gsub("%*$", "")
        if normalized ~= prefix or StringUtils.endsWith(normalized, "/") then
            if StringUtils.startsWith(map_id, normalized)
                and (not best_prefix or #normalized > #best_prefix) then
                best_prefix, best_buckets = normalized, bucket_ids
            end
        end
    end
    return best_buckets
end

---@param map_id string
---@return string[] bucket_ids
function Assets.getMapBuckets(map_id)
    local config = self.project_bucket_config
    local result, seen = {}, {}
    if type(map_id) ~= "string" then return result end

    local worlds = {}
    for world_id, world in pairs(Registry.editor_worlds or {}) do
        if world:hasMap(map_id) then table.insert(worlds, { id = world_id, world = world }) end
    end
    table.sort(worlds, function(a, b) return a.id < b.id end)
    for _, entry in ipairs(worlds) do
        local data = entry.world.data or {}
        appendBuckets(result, seen, data.asset_buckets or data.asset_bucket)
        appendBuckets(result, seen, data.properties and data.properties.asset_buckets)
        appendBuckets(result, seen, config and config.worldZones
            and config.worldZones[entry.id])
    end

    local map_data = Registry.getMapData and Registry.getMapData(map_id)
    if map_data then
        appendBuckets(result, seen, map_data.asset_buckets or map_data.asset_bucket)
        appendBuckets(result, seen, map_data.properties and map_data.properties.asset_buckets)
    end
    appendBuckets(result, seen, getConfiguredMapBuckets(config, map_id))
    return result
end

---@param map_id string
---@return string? bucket_id
function Assets.getMapBucket(map_id)
    return self.getMapBuckets(map_id)[1]
end

---@param map_id string
---@return boolean changing
function Assets.mapBucketsChanged(map_id)
    return not sameBucketList(self.getMapBuckets(map_id), self.active_map_buckets or {})
end

---@param asset_type string|string[]
---@param asset_id string
---@return AssetBucket? bucket
function Assets.findAssetBucket(asset_type, asset_id)
    local asset_types = type(asset_type) == "table" and asset_type or { asset_type }
    local normalized_types = {}
    for _, kind in ipairs(asset_types) do
        if kind == "texture" or kind == "frames" then kind = "sprite" end
        if kind == "sound_data" then kind = "sound" end
        normalized_types[kind] = true
    end
    for index = #self.buckets, 1, -1 do
        local bucket = self.buckets[index]
        if bucket:isActive() then
            for kind in pairs(normalized_types) do
                if kind == "sprite" then
                    for _, candidate in ipairs(self.getTextureReferenceCandidates(asset_id)) do
                        if bucket:hasExactSprite(candidate) or bucket:has("sprite", candidate) then
                            return bucket
                        end
                    end
                elseif AssetLoaders.exists(kind) and bucket:has(kind, asset_id) then
                    return bucket
                end
            end
        end
    end
end

---@param map_id string
---@param asset_type string|string[]
---@param asset_id string
---@return string? bucket_id
---@return boolean added
function Assets.noteEditorAssetUsage(map_id, asset_type, asset_id)
    if type(map_id) ~= "string" or type(asset_id) ~= "string" or asset_id == "" then return nil, false end
    local bucket = self.findAssetBucket(asset_type, asset_id)
    if not bucket or bucket.persistent or bucket.bucket_id == "engine-editor" then return nil, false end
    local effective = self.getMapBuckets(map_id)
    if TableUtils.contains(effective, bucket.bucket_id) then return bucket.bucket_id, false end
    local map_data = Registry.getMapData(map_id)
    if not map_data then return bucket.bucket_id, false end
    local declared = normalizeBucketList(map_data.asset_buckets or map_data.asset_bucket)
    table.insert(declared, bucket.bucket_id)
    map_data.asset_bucket = nil
    map_data.asset_buckets = declared
    return bucket.bucket_id, true
end

---@param mod ProjectInfo
---@param after function
---@return boolean bucketed
function Assets.loadProjectBuckets(mod, after)
    local manifest_path = mod.path .. "/asset_buckets.json"
    local has_manifest = love.filesystem.getInfo(manifest_path) ~= nil
    local requests = {}

    local engine_bucket_ids = TableUtils.copy(DEFAULT_CHARACTER_BUCKETS)
    if has_manifest then
        local success, config = pcall(JSON.decode, love.filesystem.read(manifest_path))
        if not success then
            error(string.format("Could not parse '%s': %s", manifest_path, tostring(config)))
        end
        self.project_bucket_config = config
        engine_bucket_ids = config.engineBuckets
        if engine_bucket_ids == nil then engine_bucket_ids = TableUtils.copy(DEFAULT_CHARACTER_BUCKETS) end

        local definitions = config.buckets or {}
        local definition_ids = {}
        for bucket_id in pairs(definitions) do table.insert(definition_ids, bucket_id) end
        table.sort(definition_ids, function(a, b)
            local a_priority = definitions[a].priority or 0
            local b_priority = definitions[b].priority or 0
            return a_priority == b_priority and a < b or a_priority < b_priority
        end)

        local library_paths = {}
        for _, lib_id in ipairs(mod.lib_order) do
            table.insert(library_paths, mod.libs[lib_id].path .. "/assets")
        end
        if #library_paths > 0 and not definitions["project-common"] then
            definitions["project-common"] = { persistent = true }
            table.insert(definition_ids, 1, "project-common")
        end

        for _, bucket_id in ipairs(definition_ids) do
            local definition = definitions[bucket_id]
            local paths = getRelativeBucketPaths(mod, definition)
            if bucket_id == "project-common" then
                for index = #library_paths, 1, -1 do
                    table.insert(paths, 1, library_paths[index])
                end
            end
            self.defineBucket(bucket_id, paths, {
                active = false,
                persistent = definition.persistent == true,
                priority = definition.priority
                    or (bucket_id == "project-common" and 100 or 200),
                scope = "project"
            })
            table.insert(self.project_bucket_ids, bucket_id)
            if definition.persistent == true then
                table.insert(requests, { id = bucket_id, owner = "project", active = true })
            end
        end

        local initial_buckets
        if Mod and type(Mod.getInitialAssetBuckets) == "function" then
            initial_buckets = Mod:getInitialAssetBuckets()
        elseif Mod and type(Mod.getInitialAssetBucket) == "function" then
            initial_buckets = Mod:getInitialAssetBucket()
        end
        initial_buckets = normalizeBucketList(initial_buckets)
        if #initial_buckets == 0 then initial_buckets = self.getMapBuckets(mod.map) end
        self.active_map_buckets = initial_buckets
        self.active_map_bucket = initial_buckets[1]
        for _, initial_bucket in ipairs(initial_buckets) do
            if not self.tryGetBucket(initial_bucket) then
                error(string.format("Initial asset bucket '%s' is not defined", initial_bucket))
            end
            table.insert(requests, {
                id = initial_bucket, owner = "world-map", active = true
            })
        end
    else
        local paths = {}
        for _, lib_id in ipairs(mod.lib_order) do
            table.insert(paths, mod.libs[lib_id].path .. "/assets")
        end
        table.insert(paths, mod.path .. "/assets")
        local project = self.getBucket("project")
        project.paths = paths
        table.insert(requests, { id = "project", owner = "project", active = true })
    end

    for _, bucket_id in ipairs(engine_bucket_ids or {}) do
        if not self.tryGetBucket(bucket_id) then
            error(string.format("Project requested unknown engine asset bucket '%s'", bucket_id))
        end
        table.insert(self.project_engine_bucket_ids, bucket_id)
        table.insert(requests, { id = bucket_id, owner = "project", active = true })
    end

    self.acquireBuckets(requests, after)
    return has_manifest
end

function Assets.clearProjectBuckets()
    self.releasePartyCharacterBuckets()
    for _, bucket_id in ipairs(self.project_engine_bucket_ids or {}) do
        if self.tryGetBucket(bucket_id) then self.releaseBucket(bucket_id, "project") end
    end
    for index = #(self.project_bucket_ids or {}), 1, -1 do
        local bucket_id = self.project_bucket_ids[index]
        if self.tryGetBucket(bucket_id) then self.removeBucket(bucket_id, true) end
    end
    local project = self.tryGetBucket("project")
    if project then
        project.owners = {}
        project:setActive(false)
        if project.state ~= AssetBucket.State.UNLOADED then project:unload() end
    end
    self.project_bucket_config = nil
    self.project_bucket_ids = {}
    self.project_engine_bucket_ids = {}
    self.active_map_bucket = nil
    self.active_map_buckets = {}
end

---@param map_id string
---@param ready fun(commit: fun(callback: function))
function Assets.prepareMapBucket(map_id, ready)
    local target_ids = self.getMapBuckets(map_id)
    local old_ids = self.active_map_buckets or normalizeBucketList(self.active_map_bucket)
    if sameBucketList(target_ids, old_ids) then
        ready(function(callback) callback() end)
        return
    end
    local old_set, target_set = {}, {}
    for _, id in ipairs(old_ids) do old_set[id] = true end
    for _, id in ipairs(target_ids) do
        target_set[id] = true
        if not self.tryGetBucket(id) then
            error(string.format("Map '%s' uses undefined asset bucket '%s'", map_id, id), 2)
        end
    end
    local requests = {}
    for _, id in ipairs(target_ids) do
        if not old_set[id] then table.insert(requests, { id = id, owner = "world-map", active = false }) end
    end
    self.acquireBuckets(requests, function()
        local committed = false
        ready(function(callback)
            assert(not committed, "Asset bucket transition was committed twice")
            committed = true
            for _, id in ipairs(target_ids) do self.activateBucket(id) end
            self.active_map_buckets = target_ids
            self.active_map_bucket = target_ids[1]
            local success, message = xpcall(callback, debug.traceback)
            for _, id in ipairs(old_ids) do
                if not target_set[id] and self.tryGetBucket(id) then
                    self.deactivateBucket(id)
                    self.releaseBucket(id, "world-map")
                end
            end
            if not success then error(message, 0) end
        end)
    end)
end

---@param map_id string
---@param callback function
function Assets.transitionToMapBucket(map_id, callback)
    self.prepareMapBucket(map_id, function(commit) commit(callback) end)
end

---@param after function
function Assets.acquireEditorAssets(after)
    local requests = {
        { id = "engine-editor", owner = "editor", active = true },
    }
    for _, bucket_id in ipairs(DEFAULT_CHARACTER_BUCKETS) do
        table.insert(requests, { id = bucket_id, owner = "editor", active = true })
    end
    for _, bucket_id in ipairs(self.project_bucket_ids or {}) do
        table.insert(requests, { id = bucket_id, owner = "editor", active = true })
    end
    self.acquireBuckets(requests, after)
end

function Assets.releaseEditorAssets()
    for _, bucket_id in ipairs(self.project_bucket_ids or {}) do
        local bucket = self.tryGetBucket(bucket_id)
        if bucket then self.releaseBucket(bucket_id, "editor") end
    end
    for _, bucket_id in ipairs(DEFAULT_CHARACTER_BUCKETS) do
        local bucket = self.tryGetBucket(bucket_id)
        if bucket then self.releaseBucket(bucket_id, "editor") end
    end
    local editor_bucket = self.tryGetBucket("engine-editor")
    if editor_bucket then self.releaseBucket("engine-editor", "editor") end
    for _, bucket_id in ipairs(self.active_map_buckets or {}) do
        if self.tryGetBucket(bucket_id) then self.activateBucket(bucket_id) end
    end
end

function Assets.saveData()
    self.saved_data = {
        data = TableUtils.copy(self.data, true),
        frames_for = TableUtils.copy(self.frames_for, true),
        texture_ids = TableUtils.copy(self.texture_ids, true),
        sounds = TableUtils.copy(self.sounds, true),
    }
end

---@return boolean
function Assets.restoreData()
    if self.saved_data then
        Assets.clear()
        for k,v in pairs(self.saved_data) do
            self[k] = TableUtils.copy(v, true)
        end
        self.loaded = true
        return true
    else
        return false
    end
end

---@param data Assets.data
function Assets.parseData(data)
    -- thread can't create images, we do it here
    for key, image_data in pairs(data.texture_data) do
        self.data.texture[key] = love.graphics.newImage(image_data)
        self.texture_ids[self.data.texture[key]] = key
    end

    -- create frame tables with images
    for key, ids in pairs(data.frame_ids) do
        self.data.frames[key] = {}
        for i, id in pairs(ids) do
            self.data.frames[key][i] = self.data.texture[id]
            self.frames_for[id] = { key, i }
        end
    end

    -- create TTF fonts
    for key, file_data in pairs(data.font_data) do
        local default = data.font_settings[key] and data.font_settings[key].defaultSize or 12
        self.data.fonts[key] = { default = default }
    end
    -- create bmfont fonts
    for key, file_path in pairs(data.font_bmfont_data) do
        data.font_settings[key] = data.font_settings[key] or {}
        if data.font_settings[key].autoScale == nil then
            data.font_settings[key].autoScale = true
        end
        self.data.fonts[key] = love.graphics.newFont(file_path)
    end
    -- set up bmfont font fallbacks
    for key, _ in pairs(data.font_bmfont_data) do
        if data.font_settings[key].fallbacks then
            local fallbacks = {}
            for _, fallback in ipairs(data.font_settings[key].fallbacks) do
                local font = self.data.fonts[fallback.font]
                if type(font) == "table" or (self.data.font_settings[fallback.font] and self.data.font_settings[fallback.font].glyphs) then
                    error("Attempt to use TTF or image fallback on BMFont font: " .. key)
                else
                    table.insert(fallbacks, font)
                end
            end
            self.data.fonts[key]:setFallbacks(unpack(fallbacks))
        end
    end
    -- create image fonts
    for key, image_data in pairs(data.font_image_data) do
        local glyphs = data.font_settings[key] and data.font_settings[key].glyphs or ""
        data.font_settings[key] = data.font_settings[key] or {}
        if data.font_settings[key].autoScale == nil then
            data.font_settings[key].autoScale = true
        end
        self.data.fonts[key] = love.graphics.newImageFont(image_data, glyphs)
    end
    -- set up image font fallbacks
    for key, _ in pairs(data.font_image_data) do
        if data.font_settings[key].fallbacks then
            local fallbacks = {}
            for _, fallback in ipairs(data.font_settings[key].fallbacks) do
                local font = self.data.fonts[fallback.font]
                if type(font) == "table" or not (self.data.font_settings[fallback.font] and self.data.font_settings[fallback.font].glyphs) then
                    error("Attempt to use TTF or BMFont fallback on image font: " .. key)
                else
                    table.insert(fallbacks, font)
                end
            end
            self.data.fonts[key]:setFallbacks(unpack(fallbacks))
        end
    end

    -- may be a memory hog, we clone the existing source so we dont need the sound data anymore
    --self.data.sound_data = {}
end

function Assets.update()
    local sounds_to_remove = {}
    for key, sounds in pairs(self.sound_instances) do
        for _, sound in ipairs(sounds) do
            if not sound:isPlaying() then
                table.insert(sounds_to_remove, { key = key, value = sound })
            end
        end
    end
    for _,sound in ipairs(sounds_to_remove) do
        TableUtils.removeValue(self.sound_instances[sound.key], sound.value)
    end
    for _, thread in ipairs(self.asset_load_threads or {}) do
        if not thread:isRunning() then
            local thread_error = thread:getError()
            if thread_error then error("Asset loader thread failed:\n" .. thread_error) end
        end
    end

    local max_in_flight = self.asset_load_in_flight_limit or 64
    local in_flight = 0
    for _, bucket in ipairs(self.buckets) do in_flight = in_flight + bucket.pending_tasks end
    for _, bucket in ipairs(self.buckets) do
        if in_flight >= max_in_flight then break end
        in_flight = in_flight + bucket:dispatchTasks(max_in_flight - in_flight)
    end

    local start_time = love.timer.getTime()
    local state = Kristal.getState()
    local blocking_load = MOD_LOADING
        or state == Kristal.States["Loading"]
        or state == Kristal.States["Empty"]
    local apply_budget = blocking_load and (2 / 30) or (0.5 / 30)
    while self.asset_load_out_channel:getCount() > 0 do
        local message = self.asset_load_out_channel:pop()
        local bucket = self.tryGetBucket(message.bucket_id)
        if bucket and bucket.state == AssetBucket.State.LOADING
            and bucket.generation == message.generation then
            bucket:receiveTask(message.asset_type, message.asset_id,
                message.success, message.result, message.decode_time,
                message.worker_id, message.worker_heap_kb)
            if Kristal.Config["verboseLoader"] then
                Kristal.Loader.message = string.format("%s/%s: %s",
                    message.bucket_id, message.asset_type, message.asset_id)
            end
        elseif message.success then
            AssetLoaders.get(message.asset_type):releaseOutput(message.result)
        end
        if love.timer.getTime() - start_time >= apply_budget then break end
    end

    in_flight = 0
    for _, bucket in ipairs(self.buckets) do in_flight = in_flight + bucket.pending_tasks end
    for _, bucket in ipairs(self.buckets) do
        if in_flight >= max_in_flight then break end
        in_flight = in_flight + bucket:dispatchTasks(max_in_flight - in_flight)
    end

    for _, bucket in ipairs(self.buckets) do bucket:finishIfReady() end

    if self.isLoading() then
        Kristal.Overlay.setLoading(true)
    elseif Kristal.Loader.waiting == 0 then
        Kristal.Loader.message = ""
        Kristal.Overlay.setLoading(false)
    end
end

---@param path string
---@return table
function Assets.getBubbleData(path)
    return self.get("bubble", path)
end

---@return FontAssetLoader.Font
function Assets.getFontInfo(asset_id)
    return self.get("font", asset_id)
end

---@param path string
---@param size? number
---@return love.Font
function Assets.getFont(path, size)
    local font = self.getFontInfo(path)
    local font_cache = self.data.fonts[path] or {}
    self.data.fonts[path] = font_cache
    local settings = font.settings or {}
    if not font.font then
        if settings.autoScale then
            size = font.default
        else
            size = size or font.default
        end
        if not font_cache[size] then
            ---@diagnostic disable-next-line: param-type-mismatch
            font_cache[size] = love.graphics.newFont(font.font_data --[[@as string]], size, settings.hinting or "mono")

            if settings.fallbacks then
                local fallbacks = {}

                for _, fallback in ipairs(settings.fallbacks) do
                    local fb_font = self.get("font", fallback.font).settings

                    if type(fb_font) ~= "table" then
                        error("Attempt to use image or BMFont fallback on TTF font: " .. path)
                    else
                        local ratio = (fallback.size or fb_font.default) / font.default
                        table.insert(fallbacks, self.getFont(fallback.font, size * ratio))
                    end
                end

                font_cache[size]:setFallbacks(unpack(fallbacks))
            end
        end
        return font_cache[size]
    else
        return font.font
    end
end

---@param path string
function Assets.getFontData(path)
    return self.getFontInfo(path).settings or {}
end

---@param path string
---@param size? number
---@return number
function Assets.getFontScale(path, size)
    local data = self.data.font_settings[path]
    if data and data.autoScale then
        return (size or 1) / (data.defaultSize or 1)
    else
        return 1
    end
end

---@param path string
---@return love.Image
function Assets.getTexture(path)
    local exact_texture = self.internalGetExactSprite(path)
    if exact_texture then return exact_texture end

    local identifier, split_frame = SpriteAssetLoader.splitIdentifier(path)
    local frames = self.getFrames(identifier)
    if not frames then return nil end
    local texture = frames[split_frame or 1] or error(string.format("Out-of-bounds frame %s on sprite '%s'", split_frame, identifier))
    return texture
end

---@return boolean
function Assets.hasSprite(asset_id)
    return Assets.internalHas("sprite", asset_id)
end

---@param reference string
---@return string[]
function Assets.getTextureReferenceCandidates(reference)
    if type(reference) ~= "string" or reference == "" then return {} end
    local normalized = reference:gsub("\\", "/"):gsub("^%./", "")
    local candidates, seen = {}, {}
    local function add(candidate)
        candidate = candidate and candidate:gsub("^/+", "")
        if not candidate or candidate == "" or seen[candidate] then return end
        seen[candidate] = true
        table.insert(candidates, candidate)
        local without_extension = candidate:gsub("%.[^%./]+$", "")
        if without_extension ~= candidate and not seen[without_extension] then
            seen[without_extension] = true
            table.insert(candidates, without_extension)
        end
    end

    add(normalized)
    local marker = "assets/sprites/"
    local marker_start = normalized:find(marker, 1, true)
    if marker_start then add(normalized:sub(marker_start + #marker)) end
    if StringUtils.startsWith(normalized, "sprites/") then add(normalized:sub(9)) end

    return candidates
end

---Resolves either an asset id or a path-shaped sprite reference through the
---merged engine/library/project texture registry.
---@param reference string
---@return love.Image? texture
---@return string? id
function Assets.resolveTextureReference(reference)
    for _, id in ipairs(self.getTextureReferenceCandidates(reference)) do
        local texture = self.getTexture(id)
        if texture then return texture, id end
    end
    return nil
end

---@param reference string
---@return love.Image? texture
---@return string? id
---@return string? reason
function Assets.reloadTextureReference(reference)
    for _, id in ipairs(self.getTextureReferenceCandidates(reference)) do
        for bucket_n = #self.buckets, 1, -1 do
            local bucket = self.buckets[bucket_n]
            if bucket:isActive() and bucket:hasExactSprite(id) then
                local group_id = bucket.exact_sprite_groups[id]
                local _, frame = bucket:getFramesForExactSprite(id)
                local group = bucket:get("sprite", group_id)
                local path = group and group.texture_paths and group.texture_paths[id]
                if path then
                    local success, image_data = pcall(love.image.newImageData, path)
                    if not success then return nil, id, tostring(image_data) end
                    local image = love.graphics.newImage(image_data)
                    local previous = group.exact_textures[id]
                    if previous then bucket.texture_ids[previous] = nil end
                    group.exact_data[id] = image_data
                    group.exact_textures[id] = image
                    bucket.texture_ids[image] = id
                    if frame then
                        group.data[frame] = image_data
                        group.textures[frame] = image
                    end
                    return image, id
                end
            end
        end
    end
    local texture, id = self.resolveTextureReference(reference)
    if texture then return texture, id end
    return nil, nil, "Could not find the source file for image asset '" .. tostring(reference) .. "'"
end

---@param path string
---@return love.ImageData
function Assets.getTextureData(path)
    local _, exact_data = self.internalGetExactSprite(path)
    if exact_data then return exact_data end

    local identifier, split_frame = SpriteAssetLoader.splitIdentifier(path)
    if not self.internalHas("sprite", identifier) then return nil end
    local frames = self.get("sprite", identifier).data
    local texture = frames[split_frame or 1] or error(string.format("Out-of-bounds frame %s on sprite '%s'", split_frame, identifier))
    return texture
end

---@param texture love.Image|string
---@return string
function Assets.getTextureID(texture)
    if type(texture) == "string" then return texture end
    for bucket_n = #Assets.buckets, 1, -1 do
        local bucket = Assets.buckets[bucket_n]
        local id = bucket:isActive() and bucket.texture_ids[texture]
        if id then return id end
    end
end

---@param path string
---@return love.Image[]
function Assets.getFrames(path)
    if not self.internalHas("sprite", path) then return nil end
    return self.get("sprite", path).textures
end

---@param path string
---@return string[]
function Assets.getFrameIds(path)
    if not self.internalHas("sprite", path) then return nil end
    return self.get("sprite", path).frame_ids
end

---@param texture string
---@return string texture, number frame
function Assets.getFramesFor(texture)
    for bucket_n = #self.buckets, 1, -1 do
        local bucket = self.buckets[bucket_n]
        if bucket:hasExactSprite(texture) then
            return bucket:getFramesForExactSprite(texture)
        end
    end
    return nil, nil
end

---@param path string
---@return love.Image[]
function Assets.getFramesOrTexture(path)
    local exact_texture = self.internalGetExactSprite(path)
    if exact_texture then return { exact_texture } end
    return self.getFrames(path)
end

---@param x number
---@param y number
---@param w number
---@param h number
---@param sw number
---@param sh number
---@return love.Quad
function Assets.getQuad(x, y, w, h, sw, sh)
    local key = x .. "," .. y .. "," .. w .. "," .. h .. "," .. sw .. "," .. sh
    if not self.quads[key] then
        self.quads[key] = love.graphics.newQuad(x, y, w, h, sw, sh)
    end
    return self.quads[key]
end

---@param sound string
---@return Sound
function Assets.getSound(sound)
    return self.get("sound", sound)
end

---@param sound string
---@return Sound
function Assets.newSound(sound)
    return self.getSound(sound):clone()
end

---@param sound string
---@return Sound
function Assets.startSound(sound)
    local src = self.get("sound", sound)
    src:stop()
    src:play()
    return src
end

---@param sound string
---@param actually_stop? boolean
function Assets.stopSound(sound, actually_stop)
    for _, src in ipairs(self.sound_instances[sound] or {}) do
        if actually_stop then
            src:stop()
        else
            src:setVolume(0)
            if src:isLooping() then
                src:setLooping(false)
            end
        end
    end
    if actually_stop then
        self.sound_instances[sound] = {}
    end
end

function Assets.stopAllSounds()
    for key,_ in pairs(Assets.sound_instances) do
        Assets.stopSound(key, true)
    end
end

---@param sound string
---@param volume? number
---@param pitch? number
---@return Sound
function Assets.playSound(sound, volume, pitch)
    self.sound_instances[sound] = self.sound_instances[sound] or {}
    local src
    local function play(v)
        src = self.newSound(sound)
        if v then
            src:setVolume(v)
        end
        if pitch then
            src:setPitch(pitch)
        end
        src:play()
        table.insert(self.sound_instances[sound], src)
    end
    if volume and volume > 1 then
        for _ = 1, math.floor(volume) do
            play(1)
        end
        if volume % 1 > 0 then
            play(volume % 1)
        end
    else
        play(volume)
    end
    return src
end

---@param sound string
---@param volume? number
---@param pitch? number
---@param actually_stop? boolean
---@return Sound
function Assets.stopAndPlaySound(sound, volume, pitch, actually_stop)
    self.stopSound(sound, actually_stop)
    return self.playSound(sound, volume, pitch)
end

---@param music string
---@return string
function Assets.getMusicPath(music)
    -- TODO: Make this error once Music2 is updated.
    if not self.internalHas("music", music) then
        ---@diagnostic disable-next-line
        return nil, string.format("Attempt to fetch missing music '%s'", music)
    end
    return self.get("music", music)
end

---@param midi string
---@return string
function Assets.getMidiPath(midi)
    --return self.data.midi[midi]
    return self.get("midi", midi)
end

---@param video string
---@return string
function Assets.getVideoPath(video)
    return self.get("video", video)
end

---@param video string
---@param load_audio? boolean
---@return love.Video
function Assets.newVideo(video, load_audio)
    return love.graphics.newVideo(self.getVideoPath(video), { audio = load_audio })
end

---@param id string
---@return love.Shader
function Assets.getShader(id)
    return self.get("shader", id).shader
end

function Assets.newShader(id)
    return love.graphics.newShader(self.get("shader", id).source)
end

return Assets
