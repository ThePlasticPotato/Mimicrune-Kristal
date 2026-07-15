---@class World
local World, super = HookSystem.hookScript(World)

local function getMapProperties(map)
    return map and map.data and map.data.properties or {}
end

local function getTileProperties(world, x, y)
    local map = world.map
    if not map then return nil end

    local map_properties = getMapProperties(map)
    local tile_x = math.floor(x / (map.tile_width or 40))
    local tile_y = math.floor(y / (map.tile_height or 40))
    local tileset, tile_index = map:getTile(tile_x, tile_y, map_properties.step_layer or "stepsounds")
    if not tileset or tile_index == nil then return nil end

    local tile_info = tileset.tile_info[tile_index]
    return tile_info and tile_info.properties or nil
end

---Returns the path of the correct step sound for the given conditions.
---@param x number x pos on map
---@param y number y pos on map
---@param num number step interval (1 or 2)
---@param actor Actor actor for custom logic
---@return string
---@return number?
function World:getStepSound(x, y, num, actor)
    local override = actor and actor.getStepSoundOverride and actor:getStepSoundOverride()
    if override then return override .. tostring(num) end

    local prefix = "step/"
    if (self.map) then
        local map_properties = getMapProperties(self.map)
        if self.map.has_tile_sounds or map_properties.has_tile_sounds then
            local tile_properties = getTileProperties(self, x, y)
            if tile_properties and tile_properties.step_sound ~= nil then
                local sound = tile_properties.step_sound
                if sound == "" then sound = "default" end
                return prefix .. sound .. tostring(num), tile_properties.step_pitch
            end
        end

        local sound = self.map.step_sound or map_properties.step_sound
        if sound ~= nil then
            if sound == "" then sound = "default" end
            return prefix .. sound .. tostring(num), nil
        end
    end
    return prefix .. "default" .. tostring(num), nil
end

function World:getSteppableTile(x, y)
    return getTileProperties(self, x, y)
end

return World
