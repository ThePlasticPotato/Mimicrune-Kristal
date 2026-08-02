local FilePath = require("src.engine.loading.FilePath")
---@class AssetBucket : Class
---@field private loaded_assets table<string, table<string, any>>
---@field private paths string[]
---@field public state AssetBucket.State
---@overload fun(id: string, paths: string[]) : AssetBucket
local AssetBucket = Class(nil, "AssetBucket")

---@enum AssetBucket.State
AssetBucket.State = {
    UNLOADED = 0,
    LOADING = 1,
    LOADED = 2,
}

---@param paths string[]
function AssetBucket:init(id, paths)
    self.bucket_id = id
    self.paths = paths
    self.loaded_assets = {}
    self.texture_ids = {}
    self.dispatched_tasks = {}
    self.pending_tasks = 0
    self.completion_callbacks = {}
    self.generation = 0
    self.state = AssetBucket.State.UNLOADED
    self.assets_total = 0
    self.assets_loaded = 0
end

function AssetBucket:unload()
    self.generation = self.generation + 1
    for asset_type, assets in pairs(self.loaded_assets) do
        local loader = AssetLoaders.get(asset_type)
        for _, asset in pairs(assets) do
            loader:release(asset)
        end
    end
    Assets.queued_tasks[self.bucket_id] = {}
    self.loaded_assets = {}
    self.texture_ids = {}
    self.dispatched_tasks = {}
    self.pending_tasks = 0
    self.completion_callbacks = {}
    self.state = AssetBucket.State.UNLOADED
    self.assets_total = 0
    self.assets_loaded = 0
end

---@param paths string[]?
---@param after function?
function AssetBucket:startLoading(paths, after)
    assert(self.state == AssetBucket.State.UNLOADED, "Can't load a bucket that's already loaded")
    self.generation = self.generation + 1
    self.state = AssetBucket.State.LOADING
    self.paths = paths or self.paths
    self.loaded_assets = {}
    self.texture_ids = {}
    self.dispatched_tasks = {}
    self.pending_tasks = 0
    self.completion_callbacks = {}
    self.assets_total = 0
    self.assets_loaded = 0
    Assets.queued_tasks[self.bucket_id] = {}
    if after then table.insert(self.completion_callbacks, after) end
    for _, asset_search_path in ipairs(self.paths) do
        for asset_type, loader in AssetLoaders.iterLoaders() do
            for _, subfolder in ipairs(loader.valid_subfolders or error(TableUtils.dump(loader))) do
                local files = FileSystemUtils.getFilesRecursive(asset_search_path .. "/" .. subfolder)
                table.sort(files)
                for i, subpath in ipairs(files) do
                    local filepath = FilePath(asset_search_path .. "/" .. subfolder, subpath)
                    if TableUtils.contains(loader.valid_extensions, filepath.extension) then
                        loader:beginLoad(filepath, Assets.getQueue(self.bucket_id, asset_type))
                    end
                end
            end
        end
    end
    for asset_type, _ in pairs(Assets.queued_tasks[self.bucket_id]) do
        self.assets_total = self.assets_total + TableUtils.getKeyCount(Assets.getQueue(self.bucket_id, asset_type))
    end
end

---@param callback function
function AssetBucket:onComplete(callback)
    if self.state == AssetBucket.State.LOADED then
        callback()
    else
        assert(self.state == AssetBucket.State.LOADING, "Can't await an unloaded bucket")
        table.insert(self.completion_callbacks, callback)
    end
end

---@param limit integer
---@return integer dispatched
function AssetBucket:dispatchTasks(limit)
    if self.state ~= AssetBucket.State.LOADING or limit <= 0 then return 0 end
    local dispatched = 0
    for asset_type, queue in pairs(Assets.queued_tasks[self.bucket_id] or {}) do
        self.dispatched_tasks[asset_type] = self.dispatched_tasks[asset_type] or {}
        for asset_id, task in pairs(queue) do
            if not self.dispatched_tasks[asset_type][asset_id] then
                Assets.asset_load_in_channel:push({
                    bucket_id = self.bucket_id,
                    generation = self.generation,
                    asset_type = asset_type,
                    asset_id = asset_id,
                    task = task,
                })
                self.dispatched_tasks[asset_type][asset_id] = true
                self.pending_tasks = self.pending_tasks + 1
                dispatched = dispatched + 1
                if dispatched >= limit then return dispatched end
            end
        end
    end
    return dispatched
end

---@param asset_type string
---@param asset_id string
---@param success boolean
---@param result any
function AssetBucket:receiveTask(asset_type, asset_id, success, result)
    self.pending_tasks = math.max(0, self.pending_tasks - 1)
    if self.dispatched_tasks[asset_type] then
        self.dispatched_tasks[asset_type][asset_id] = nil
    end

    local loader = AssetLoaders.get(asset_type)
    local queue = Assets.getQueue(self.bucket_id, asset_type)
    if not success then
        error(string.format("Failed to load %s/%s/%s:\n%s",
            self.bucket_id, asset_type, asset_id, tostring(result)))
    elseif not queue[asset_id] then
        -- asset gotten synchronously
        loader:releaseOutput(result)
    else
        self:applyResult(asset_type, asset_id, result)
    end
end

---@param asset_type string
---@param asset_id string
---@param result any
function AssetBucket:applyResult(asset_type, asset_id, result)
    local loader = AssetLoaders.get(asset_type)
    local final = loader:apply(asset_id, result)
    self:ensureLoader(asset_type)
    self.loaded_assets[asset_type][asset_id] = final
    Assets.getQueue(self.bucket_id, asset_type)[asset_id] = nil
    self.assets_loaded = self.assets_loaded + 1

    if asset_type == "sprite" then
        for frame, texture in pairs(final.textures) do
            self.texture_ids[texture] = asset_id .. "_" .. frame
        end
    end
    return final
end

function AssetBucket:finishIfReady()
    if self.state ~= AssetBucket.State.LOADING
        or self.pending_tasks > 0
        or self.assets_loaded < self.assets_total then return false end

    self.state = AssetBucket.State.LOADED
    local callbacks = self.completion_callbacks
    self.completion_callbacks = {}
    for _, callback in ipairs(callbacks) do callback() end
    return true
end


function AssetBucket:has(asset_type, asset_id)
    if self.state == AssetBucket.State.UNLOADED then
        return false
    end
    self:ensureLoader(asset_type)
    if self.loaded_assets[asset_type][asset_id] then
        return true
    end
    if Assets.getQueue(self.bucket_id, asset_type)[asset_id] then
        return true
    end
end

--[[

for k, v in pairs(Assets.getQueue("engine", "sprite")) do
    Assets.getFrames(k)
end

--]]

---@internal
---@param asset_type string
---@param asset_id string
function AssetBucket:get(asset_type, asset_id)
    if self.state == AssetBucket.State.UNLOADED then
        error(string.format("Attempt to get asset from bucket '%s' while it's unloaded", self.bucket_id), 2)
    end
    self:ensureLoader(asset_type)
    if self.loaded_assets[asset_type][asset_id] then
        return self.loaded_assets[asset_type][asset_id]
    elseif Assets.getQueue(self.bucket_id, asset_type)[asset_id] then
        local loader = AssetLoaders.get(asset_type)
        local result = loader:load(asset_id, Assets.getQueue(self.bucket_id, asset_type)[asset_id])
        return self:applyResult(asset_type, asset_id, result)
    else
        error(string.format("Attempt to get missing asset of type '%s' with ID '%s'", asset_type, asset_id), 2)
    end
end

---@private
function AssetBucket:ensureLoader(asset_type)
    if not self.loaded_assets[asset_type] then
        self.loaded_assets[asset_type] = {}
    end
end

return AssetBucket
