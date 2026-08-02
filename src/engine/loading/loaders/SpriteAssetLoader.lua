local spell = require("src.engine.game.common.data.spell")

---@class SpriteAssetLoader : AssetLoader<{textures: love.Image[], data: love.ImageData[] }, SpriteAssetLoader.Task, SpriteAssetLoader.TaskResult>
---
---@field protected image_extensions string[]
---
---@field protected mario_texture love.Image
---
local SpriteAssetLoader, super = Class(AssetLoader, "SpriteAssetLoader")

---@class SpriteAssetLoader.FramePath
---@field frame integer
---@field path string

---@class SpriteAssetLoader.Task
---@field frames SpriteAssetLoader.FramePath[]

---@class SpriteAssetLoader.TaskResult
---@field texture_data love.ImageData[]
---@field texture_paths string[]

---@param valid_subfolders string[]
---@param valid_extensions string[]
function SpriteAssetLoader:init(valid_subfolders, valid_extensions)
    super.init(self, valid_subfolders, valid_extensions)

    self.image_extensions = valid_extensions

    self.placeholder = love.image.newImageData(1,1)

    -- Mario mode support
    if love.graphics and love.filesystem.getInfo("mario.png") and Kristal.Args["mario-mode"] then
        self.mario_texture = love.graphics.newImage("mario.png")
    end
end

---@return string identifier
---@return integer? split_frame
function SpriteAssetLoader.splitIdentifier(full_identifier)
    local identifier_split = StringUtils.split(full_identifier, "_")
    local split_frame
    local try_frame_number = tonumber(identifier_split[#identifier_split])
    if try_frame_number and try_frame_number ~= math.huge and try_frame_number > 0 then
        split_frame = tonumber(table.remove(identifier_split, #identifier_split))
    end
    local identifier = table.concat(identifier_split, "_")
    return identifier, split_frame
end

function SpriteAssetLoader:beginLoad(file, queue)
    -- Split an asset id like `"idle_01"` into `"idle", "01"`
    local identifier, split_frame = SpriteAssetLoader.splitIdentifier(file.identifier)

    -- Sprite frames and metadata all form the same asset, so the task table is modified
    local task = queue[identifier] or { frames = {}, frame_positions = {} }

    -- If the filename has a frame separator, convert it to a number
    local frame_index = tonumber(split_frame)

    if split_frame then
        assert(frame_index, string.format("Invalid frame separator '%s', expected number", split_frame))
        if (frame_index <= 0) then
            self:logWarn(string.format("Frame index must begin at 1 (%s)", file.relative_path))
        end
    end

    -- All textures are frame 1 of the sprite unless otherwise specified
    frame_index = frame_index or 1
    
    local frame = {
        frame = frame_index,
        path = file.full_path
    }
    local position = task.frame_positions[frame_index]
    if position then
        task.frames[position] = frame
    else
        table.insert(task.frames, frame)
        task.frame_positions[frame_index] = #task.frames
    end

    if queue[identifier] == nil then
        queue[identifier] = task

        self:logDebug(string.format("Queued load for sprite '%s'", identifier))
    end
end

function SpriteAssetLoader:load(asset_id, task)
    ---@type SpriteAssetLoader.TaskResult
    local result = {
        texture_data = {},
        texture_paths = {},
        max_frame = 0,
    }

    -- Load frame image data (images themselves cannot be loaded on a separate thread)
    for _, frame_data in ipairs(task.frames) do
        assert(result.texture_data[frame_data.frame] == nil, string.format("Duplicate frame index %d on %s", frame_data.frame, asset_id))

        local image_data = love.image.newImageData(frame_data.path)

        result.texture_data[frame_data.frame] = image_data
        result.texture_paths[frame_data.frame] = frame_data.path
        result.max_frame = math.max(result.max_frame, frame_data.frame)
    end

    -- HACK: Allow gaps in frame indecies by inserting a placeholder ImageData. Ideally should not be used.
    if #result.texture_data ~= #task.frames then
        for i=1, table.maxn(result.texture_data) do
            result.texture_data[i] = result.texture_data[i] or self.placeholder
        end
        self:logError(string.format("Unexpected gap between frame indexes for '%s'", asset_id))
    end

    self:logDebug(string.format(
        "Loaded %d frame(s) for sprite '%s'",
        #task.frames, asset_id
    ))

    return result
end

function SpriteAssetLoader:apply(asset_id, output)
    local textures = {}
    local texture_datas = {}
    local had_gap = false

    -- Now on the main thread, create textures from the loaded data
    for i = 1, output.max_frame or table.maxn(output.texture_data) do
        local texture_data = output.texture_data[i] or self.placeholder
        if not output.texture_data[i] then had_gap = true end
        if self.mario_texture ~= nil then
            texture_data = self:generateMario(texture_data)
        end
        local texture = love.graphics.newImage(texture_data)

        textures[i] = texture

        texture_datas[i] = texture_data
    end
    if had_gap then
        self:logError(string.format("Unexpected gap between frame indexes for '%s'", asset_id))
    end

    return {
        textures = textures,
        data = texture_datas,
    }
end

function SpriteAssetLoader:release(asset)
    for _, texture in pairs(asset.textures or {}) do
        self:releaseObject(texture)
    end
    for _, data in pairs(asset.data or {}) do
        if data ~= self.placeholder then self:releaseObject(data) end
    end
end

function SpriteAssetLoader:releaseOutput(output)
    for _, data in pairs(output.texture_data or {}) do
        if data ~= self.placeholder then self:releaseObject(data) end
    end
end

--- Mario mode image creation
---@internal
---@param texture love.ImageData
---@return love.ImageData
function SpriteAssetLoader:generateMario(texture)
    local target_width, target_height = texture:getWidth(), texture:getHeight()
    local mario_width, mario_height = self.mario_texture:getWidth(), self.mario_texture:getHeight()

    local new_mario = love.graphics.newCanvas(target_width, target_height)

    local scale_x, scale_y = target_width / mario_width, target_height / mario_height

    Draw.pushCanvas(new_mario)
        love.graphics.draw(self.mario_texture, 0, 0, 0, scale_x, scale_y)
    Draw.popCanvas()
    local new_mario_data = new_mario:newImageData()
    new_mario:release()
    return new_mario_data
end

return SpriteAssetLoader
