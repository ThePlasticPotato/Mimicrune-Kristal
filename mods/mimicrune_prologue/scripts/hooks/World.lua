---@class World
local World, super = HookSystem.hookScript(World)

function World:setupMap(map, ...)
    super.setupMap(self, map, ...)
    if self.map and self.map.data and self.map.data.properties and self.map.data.properties.area_name then
        love.window.setTitle(self.map.data.properties.area_name)
    else
        love.window.setTitle("DEPTHS")
    end
end

return World