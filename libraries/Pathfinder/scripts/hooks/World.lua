---@class World : Object
local World, super = HookSystem.hookScript(World)

function World:init(map)
    super.init(self, map)
end
--- Returns the nearest valid pathfinding node, based on the map's `node_size`.
--- 
--- `x` and `y` must be relative to this World.
--- @param x number X position, relative to world
--- @param y number Y position, relative to world
--- @return table<number> node_pos 2D Vector of node pos. Nil if no valid nodes are within a 1 node radius of this position.
function World:getNearestNode(x, y)
    local node_size = self:getPathfinderNodeSize()

    return { MathUtils.round(x/node_size), MathUtils.round(y/node_size) }
end

--- Returns the nearest valid pathfinding node, based on the map's `node_size`.
--- 
--- `x` and `y` must be relative to this World.
--- @param x number X position, relative to world
--- @param y number Y position, relative to world
--- @param collider Collider|nil Hitbox to check collision with.
--- @param range number A range of nodes to search within. Defaults to 1.
--- @return table<number>|nil node_pos 2D Vector of node pos. Nil if no valid nodes are within a 1 node radius of this position.
function World:getNearestValidNode(x, y, collider, range)
    local node = self:getNearestNode(x, y)

    if (self:nodeIsValid(node[1], node[2], collider)) then
        return node
    elseif (collider and collider) then
        local current = nil
        local score = 999
        local get_score = function (score_x, score_y) return math.abs(score_x) + math.abs(score_y) end
        for off_x = -range, range, 1 do
            for off_y = -range, range, 1 do
                if (not (off_x == 0 and  off_y == 0)) then
                    local new_node = { node[1] + off_x, node[2] + off_y }
                    local valid = self:nodeIsValid(new_node[1], new_node[2], collider)
                    local new_score = get_score(off_x, off_y)
                    if (valid and (new_score < score)) then
                        current = new_node
                        score = new_score
                        if (score == 1) then return current end
                    end
                end
            end
        end
        return current
    end

    -- for off_x = -1, 1, 1 do
    --         for off_y = -1, 1, 1 do
    --             if (not (off_x == 0 and  off_y == 0) and math.abs(off_x) ~= math.abs(off_y)) then
    --                 local new_node = { node[1] + off_x, node[2] + off_y }
    --                 local valid = self:nodeIsValid(new_node[1], new_node[2], ref_collider)
    --                 if (valid) then
    --                     return new_node
    --                 end
    --             end
    --         end
    --     end
    
    return nil
end

---@param x number
---@param y number
---@param collider Collider
---@return number original_x
---@return number original_y
function World:centerOnNode(x, y, collider)
    local world_pos = self:nodePosToWorld(x, y)

    local original_offset_x = collider.x
    local original_offset_y = collider.y
    local relative_pos_x, relative_pos_y = self:getRelativePos(world_pos[1], world_pos[2], collider.parent)
    collider.x = relative_pos_x - (original_offset_x / 2)
    collider.y = relative_pos_y - (original_offset_y / 2)
    return original_offset_x, original_offset_y
end

---@param x number
---@param y number
---@param collider Collider
function World:nodeIsValid(x, y, collider)
    if (collider) then
        local og_x, og_y = self:centerOnNode(x, y, collider)
        local collided = self:checkCollision(collider, false) or not self:inBounds(self:nodePosToWorld(x, y))
        collider.x = og_x
        collider.y = og_y
        return not collided
    end
    return true
end

---@param x number
---@param y number
---@return table<number> world_pos
---@overload fun(x: table<number>): table<number>
function World:nodePosToWorld(x, y)
    if (type(x) == "table") then
        y = x[2]
        x = x[1]
    end
    local node_size = self:getPathfinderNodeSize()
    return { x * node_size, y * node_size }
end

---@return number size
function World:getPathfinderNodeSize()
    return self.map and self.map.pathfinder_node_size or Pathfinder:getConfig("default_node_size") or 40
end

---@overload fun(x: table<number>): boolean
function World:inBounds(x, y)
    if (type(x) == "table") then
        y = x[2]
        x = x[1]
    end
    return x <= (self.map.width * self.map.tile_width) and x >= 0 and y <= (self.map.height * self.map.tile_height) and y >= 0
end

---Takes in two Node positions and finds a valid path between them. Uses the A* pathfinding algorithm.
---@param x number
---@param y number
---@param target_x number
---@param target_y number
---@param collider Collider
---@return table path
function World:findPathTo(x, y, target_x, target_y, collider)

    local path = Luafinding(LVector(x, y), LVector(target_x, target_y), function (pos) return self:nodeIsValid(pos.x, pos.y, collider) end):GetPath() or {}
    if #path == 0 then Kristal.Console:log("But it was empty...") end
    local world_path = {}

    for index, value in ipairs(path) do
        local world_pos = self:nodePosToWorld(value.x, value.y)
        table.insert(world_path, world_pos)
    end

    return world_path


    -- local path = {}
    -- if (x == target_x and y == target_y) then return path end

    -- local compose = function (vec_x, vec_y)
    --     return tostring(vec_x)..","..tostring(vec_y)
    -- end

    -- local decompose = function (vecstring)
    --     local split = Utils.splitFast(vecstring, ",")
    --     return { tonumber(split[1]), tonumber(split[2]) }
    -- end

    -- local came_from = {}
    -- came_from[compose(x, y)] = compose(x, y)
    -- local frontier = PriorityQueue()
    -- frontier:put( {x, y}, 0 )
    -- local cost_so_far = {}
    -- cost_so_far[compose(x, y)] = 0

    -- local heuristic = function (current_x, current_y)
    --     return math.abs(target_x - current_x) + math.abs(target_y - current_y)
    -- end
    -- -- todo: maybe implement this if its worthwhile
    -- local movement_cost = function (node_x, node_y, next_x, next_y)
    --     --return math.abs(Utils.dist(node_x, node_y, next_x, next_y))
    -- end
    
    -- local max_nodes_searched = 100
    -- local nodes_counted = 0
    
    -- while (not frontier:empty()) and not (nodes_counted >= max_nodes_searched) do
    --     local current = frontier:popLeast()
    --     if (current[1] == target_x and current[2] == target_y) then
    --         break
    --     end
    --     local neighbors = self:getValidNeighbors(current[1], current[2], collider)
    --     if (#neighbors > 0) then
    --         for index, value in ipairs(neighbors) do
    --             local new_cost = (cost_so_far[compose(current[1], current[2])] or 1) + 1 -- movement_cost(current[1][1], current[1][2])
    --             if (not cost_so_far[compose(value[1], value[2])]) then --or new_cost < cost_so_far[compose(value[1], value[2])]) then
    --                 local priority = new_cost + heuristic(value[1], value[2])
    --                 frontier:put (value, priority)
    --                 came_from[compose(value[1], value[2])] = compose(current[1], current[2])
    --             end
    --         end
    --     end
    --     nodes_counted = nodes_counted + 1
    -- end

    -- if (not came_from[compose(target_x, target_y)]) then 
    --     Kristal.Console:log("Pathfinding failure, target not in final path...")
    --     return path
    -- end
    -- local current = {target_x, target_y}
    
    -- while ((current[1] ~= x and current[2] ~= y)) do
    --     local node = decompose(came_from[compose(current[1], current[2])])
    --     current = node
    --     table.insert(path, #path + 1, self:nodePosToWorld(node))
    -- end
    -- return Utils.reverse(path)

end


--- Returns all allowed pathfinding node neighbors.
--- 
--- `x` and `y` must be relative to this World.
--- @param x number X position, relative to world
--- @param y number Y position, relative to world
--- @return table node_positions
function World:getNeighbors(x, y)
    local node = {x, y}
    local neighbors = {}

    for off_x = -1, 1, 1 do
        for off_y = -1, 1, 1 do
            if (not (off_x == 0 and  off_y == 0)) then
                local new_node = { node[1] + off_x, node[2] + off_y }
                table.insert(neighbors, new_node)
            end
        end
    end
    
    
    return neighbors
end

--- Returns all valid pathfinding node neighbors.
--- 
--- `x` and `y` must be relative to this World.
--- @param x number X position, relative to world
--- @param y number Y position, relative to world
--- @param collider Collider|nil Hitbox to check collision with.
--- @param range number A range of nodes to search within. Defaults to 1.
--- @return table node_positions
function World:getValidNeighbors(x, y, collider, range)
    local node = {x, y}
    local neighbors = {}
    if not range then range = 1 end

    for off_x = -range, range, 1 do
        for off_y = -range, range, 1 do
            if (not (off_x == 0 and  off_y == 0)) then
                local new_node = { node[1] + off_x, node[2] + off_y }
                local valid = self:nodeIsValid(new_node[1], new_node[2], collider)
                if (valid) then
                    table.insert(neighbors, new_node)
                end
            end
        end
    end
    
    
    return neighbors
end

return World