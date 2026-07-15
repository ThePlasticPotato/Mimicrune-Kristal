---@class World
local World, super = HookSystem.hookScript(World)

---Returns the path of the correct step sound for the given conditions.
---@param x number x pos on map
---@param y number y pos on map
---@param num number step interval (1 or 2)
---@param actor Actor actor for custom logic
---@return string
---@return number?
function World:getStepSound(x, y, num, actor)
    if (actor:getStepSoundOverride()) then return actor:getStepSoundOverride()..tostring(num) end
    local prefix = "step/"
    if (self.map) then
        if (self.map.has_tile_sounds or Game.world.map.data.properties["has_tile_sounds"]) then
            local tile_x = math.floor(x/40)
            local tile_y = math.floor(y/40)
            local tileset, tile_index = self.map:getTile(tile_x, tile_y, self.map.data.properties.step_layer or "stepsounds")
            if (tileset and tile_index) then
                if (tileset.tile_info[tile_index] and (tileset.tile_info[tile_index].step_sound)) then
                    local sound = tileset.tile_info[tile_index].step_sound
                    if (sound == "") then sound = "default" end
                    return prefix..sound..tostring(num), tileset.tile_info[tile_index]["step_pitch"]
                end
            end
            
        end
        if (self.map.step_sound or Game.world.map.data.properties["step_sound"]) then
            local sound = self.map.step_sound or Game.world.map.data.properties["step_sound"]
            if (sound == "") then sound = "default" end
            return prefix..sound..tostring(num), nil
        end
    end
    return prefix.."default"..tostring(num), nil
end

function World:getSteppableTile(x, y)
    if self.map then
        if true then
            local tile_x = math.floor(x/40)
            local tile_y = math.floor(y/40)
            local tileset, tile_index = self.map:getTile(tile_x, tile_y, self.map.data.properties.step_layer or "stepsounds")
            if (tileset and tile_index) then
                return tileset.tile_info[tile_index]
            end
            return false
        end
        return false
    end
    return false
end
return World