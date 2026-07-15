---@class Character : Object
---@field pathing boolean
---@field chasing boolean
---@field chasing_target Object|nil
---@field chasing_timer number
---@field chasing_options table
local Character, super = HookSystem.hookScript(Character)

function Character:init(actor, x, y)
    super.init(self, actor, x, y)
    self.pathing = false
    self.chasing = false
    self.chasing_options = {}
    self.chasing_timer = 0
    self.chasing_target = nil
end

--- Attempts to path a character to a position from its current position.
--- Returns false if failed.
--- 
--- @param x number The target X position.
---@param y number The target Y position.
---@param options table A table of options. Supported options:
---|"refollow" # If a follower, will immediately refollow after pathfinding completion or failure.
---|"refollow_on_fail" # If a follower, will immediately refollow after pathfinding failure.
---|"speed" # The walking speed at which the character will follow the path. Defaults to 6.
---|"after" # A function executed after pathfinding is complete. Recieves no arguments.
---|"valid_distance" # The valid range to search for ending positions by the target. Defaults to 1.
function Character:pathfindTo(x, y, options)
    self.following = false
    if (self.chasing) then self:stopChasing() end
    options = options or {}
    if (options and options.refollow_on_fail == nil) then options.refollow_on_fail = true end
    local current_node = Game.world:getNearestNode(self.x, self.y)
    local target_node = Game.world:getNearestValidNode(x, y, self.collider, options.valid_distance or 5)
    if (not target_node) then
        if options and (options.refollow or options.refollow_on_fail) and self.returnToFollowing then self:returnToFollowing(6) end
        Kristal.Console:log("[Pathfinder] : Target node invalid! Returning...")
        return false
    end
    local path = Game.world:findPathTo(current_node[1], current_node[2], target_node[1], target_node[2], self.collider)
    if (#path == 0) then
        if options and (options.refollow or options.refollow_on_fail) and self.returnToFollowing then self:returnToFollowing(6) end
        Kristal.Console:log("[Pathfinder] : Pathfinding failed! Returning...")
        return false
    end
    self.pathing = true
    Kristal.Console:log("[Pathfinder] : Found a path that is " ..#path.." nodes long! Pathfinding...")
    self:walkPath(path, { speed = options and options.speed or 6, loop = false, relative = false, after = function ()
        self.pathing = false
        if options and options.after then options.after() end
        if options and options.refollow and self.returnToFollowing then self:returnToFollowing(6) end
        Kristal.Console:log("[Pathfinder] : Pathfinding complete! Arrived at target destination.")
        end }
    )
    return true
end

--- Attempts to path a character to a target from its current position continuously.
--- Returns false if failed.
--- 
--- @param target Object The target object.
---@param options table A table of options. Supported options:
---|"refollow" # If a follower, will immediately refollow after pathfinding completion or failure.
---|"speed" # The walking speed at which the character will follow the path. Defaults to 6.
---|"after" # A function executed after chasing ends. Recieves no arguments.
---|"on_reach" # A function executed upon reaching the target. May be called more than once. Recieves a boolean determining if the target was reached successfully.
---|"once" # Whether or not this chaser will continue chasing after reaching its target. Defaults to true.
---|"valid_distance" # The valid range to search for ending positions by the target. Defaults to 1.
---|"chase_distance" # The acceptable range at which to stop chasing a target. Defaults to 0.
---|"match_speed" # Whether the pathing should try and match the speed of the target, rather than using the set speed.
---|"offset" # Specified offset from target. Takes priority over chase_distance. Either a table, or a function that returns one.
function Character:pathfindChase(target, options)
    self.following = false
    if not target then return false end
    self.chasing = true
    self.chasing_target = target
    options = options or {}
    self.chasing_options = options
    if (options and options.refollow_on_fail == nil) then options.refollow_on_fail = true end
    local current_node = Game.world:getNearestNode(self.x, self.y)
    local target_pos = {target.x, target.y}
    if options.offset then
        local offset = options.offset
        if (type(options.offset) == "table") then
            offset = options.offset
        else
            offset = options.offset()
        end
        target_pos = {target.x + offset[1], target.y + offset[2]}
        
    elseif options.chase_distance and (options.chase_distance > 0) then
        local distance_to = {target.x - self.x, target.y - self.y}
        local normal_x, normal_y = Vector.normalize(distance_to[1], distance_to[2])
        local distance_offset = {normal_x * options.chase_distance, normal_y * options.chase_distance}
        target_pos = { target.x + distance_offset[1], target.y + distance_offset[2] }
    end
    local target_node = Game.world:getNearestValidNode(target_pos[1], target_pos[2], self.collider, options.valid_distance or 2)
    if (not target_node) then
        Kristal.Console:log("[Pathfinder CHASE] : Target node invalid! Returning...")
        if options.on_reach then options.on_reach(false) end
        return false
    end
    local path = Game.world:findPathTo(current_node[1], current_node[2], target_node[1], target_node[2], self.collider)
    if (#path == 0) then
        Kristal.Console:log("[Pathfinder CHASE] : Pathfinding failed! Returning...")
        if options.on_reach then options.on_reach(false) end
        return false
    end
    self.pathing = true
    local default_speed = options.speed or target.walk_speed or 6
    Kristal.Console:log("[Pathfinder CHASE] : Found a path that is " ..#path.." nodes long! Pathfinding...")
    self:walkPath(path, { speed = default_speed, loop = false, relative = false, after = function ()
        self.pathing = false
        if options.on_reach then options.on_reach(true) end
        Kristal.Console:log("[Pathfinder CHASE] : Pathfinding complete! Arrived at target.")
        if options.once ~= false then self:stopChasing() end
        end }
    )
    return true
end

function Character:stopChasing()
    Kristal.Console:log("[Pathfinder CHASE] : Chasing stopped.")
    self.chasing_target = nil
    self.chasing_time = 0
    self.chasing = false
    self.pathing = false
    self.physics.move_path = nil
    if self.chasing_options and self.chasing_options.after then self.chasing_options.after() end
    self.chasing_options = {}
end

---@param target Object
---@param options table|nil
function Character:updateChaseTarget(target, options)
    if target then self:pathfindChase(target, options or self.chasing_options) end
    if not target then self:stopChasing() end
end

function Character:doWalkToStep(x, y, keep_facing)
    local was_noclip = self.noclip
    self.noclip = not self.pathing
    self:move(x, y, 1, keep_facing)
    self.noclip = was_noclip
end

function Character:update()
    super.update(self)
    if (self.chasing) then
        self.chasing_timer = self.chasing_timer + DT
        if (self.chasing_timer > Pathfinder:getConfig("chaser_pathing_poll_rate")) then
            self.chasing_timer = 0
            if not self.pathing then self:updateChaseTarget(self.chasing_target) end
        end
    end
end

function Character:draw()
    if DEBUG_RENDER and Pathfinder:getConfig("debug_render_pathfinding") then
        local node = Game.world:getNearestNode(self.x, self.y)
        local neighbors = Game.world:getValidNeighbors(node[1], node[2], self.collider, 1)
        Draw.setColor(0, 1, 0.5, 0.5)
        local sprite = Assets.getTexture("effects/criticalswing/sparkle_2")
        local sprite_path = Assets.getTexture("effects/criticalswing/sparkle_1")
        for index, value in ipairs(neighbors) do
            local world_pos = Game.world:nodePosToWorld(value[1], value[2])
            local relative_x, relative_y = Game.world:getRelativePos(world_pos[1], world_pos[2], self)
            Draw.draw(sprite, relative_x - 4, relative_y - 4, nil, nil, nil)
        end
        Draw.setColor(1, 1, 1, 0.25)
        if (self.pathing and self.physics.move_path and self.physics.move_path.path and (#self.physics.move_path.path > 0)) then
            love.graphics.setLineWidth(1)
            love.graphics.setLineStyle("rough")
            local last_line_end = nil
            for index, value in ipairs(self.physics.move_path.path) do
                local relative_x, relative_y = Game.world:getRelativePos(value[1], value[2], self)
                if (last_line_end) then love.graphics.line(last_line_end[1], last_line_end[2], relative_x, relative_y) end
                Draw.draw(sprite_path, relative_x - 4, relative_y - 4, nil, nil, nil)
                last_line_end = { relative_x, relative_y }
            end
        end
        Draw.setColor(1,1,1,1)
    end
    super.draw(self)
end

return Character