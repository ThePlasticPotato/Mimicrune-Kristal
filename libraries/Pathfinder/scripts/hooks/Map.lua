---@class Map : Class
---@field pathfinder_node_size number
local Map, super = HookSystem.hookScript(Map)

function Map:init(world, data)
    super.init(self, world, data)
    self.pathfinder_node_size =  data and data.properties and data.properties["node_size"] or Pathfinder:getConfig("default_node_size") or 40
end

return Map