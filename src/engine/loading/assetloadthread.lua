---@diagnostic disable: lowercase-global
require("love.image")
require("love.sound")

local json = require("src.lib.json")

local in_channel = love.thread.getChannel("asset_load_in")
local out_channel = love.thread.getChannel("asset_load_out")

local function loadAsset(asset_type, task)
    if asset_type == "sprite" then
        local output = {
            texture_data = {},
            texture_paths = {},
        }
        for _, frame_data in ipairs(task.frames) do
            output.texture_data[frame_data.frame] = love.image.newImageData(frame_data.path)
            output.texture_paths[frame_data.frame] = frame_data.path
            output.max_frame = math.max(output.max_frame or 0, frame_data.frame)
        end
        return output
    elseif asset_type == "sound" then
        return love.sound.newSoundData(task)
    elseif asset_type == "shader" then
        return love.filesystem.read(task)
    elseif asset_type == "font" then
        local output = {}
        if task.bmfont_path then output.bmfont_path = task.bmfont_path end
        if task.font_path then output.font_data = love.filesystem.newFileData(task.font_path) end
        if task.image_path then output.image_data = love.image.newImageData(task.image_path) end
        if task.settings_path then
            output.settings = json.decode(love.filesystem.read(task.settings_path))
        end
        return output
    elseif asset_type == "bubble" then
        return json.decode(love.filesystem.read(task))
    elseif asset_type == "music" or asset_type == "video" or asset_type == "midi" then
        return task
    end
    error("Unknown asset type '" .. tostring(asset_type) .. "'")
end

while true do
    local message = in_channel:demand()
    if message == "stop" then break end

    local success, result = xpcall(function()
        return loadAsset(message.asset_type, message.task)
    end, debug.traceback)

    out_channel:push({
        bucket_id = message.bucket_id,
        generation = message.generation,
        asset_type = message.asset_type,
        asset_id = message.asset_id,
        success = success,
        result = result,
    })
end
