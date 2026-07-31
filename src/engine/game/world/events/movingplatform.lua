--- A solid that moves before overworld stuff and carries anything standing on it.\
--- Moving platforms may travel on all three world axes. Their position is the bottom of the solid\
--- the walkable surface is always `z + depth`.
---@class MovingPlatform : Event
---@overload fun(x: number, y: number, shape: table, properties?: table): MovingPlatform
local MovingPlatform, super = Class(Event)

local EPSILON = 0.001

local function pointValue(point, key, index, fallback)
    local value = point[key]
    if value == nil then value = point[index] end
    if value == nil then return fallback end
    return tonumber(value) or fallback
end

function MovingPlatform:init(x, y, shape, properties)
    properties = properties or {}
    super.init(self, x, y, shape)

    self.is_moving_platform = true
    self.solid = true
    self.use_3d_collision = true
    self.height_sort_subject = false
    self.height_occluder = properties.height_occluder ~= false
    self.height_face_direction = properties.face_direction or "front"
    self.height_occlusion_sort_y_offset = tonumber(properties.sort_y_offset) or 0

    self.z = tonumber(properties.z) or self.z
    self.depth = math.max(tonumber(properties.depth) or 16, 0)
    self.collider.z = tonumber(properties.collision_z) or 0
    self.collider.depth = math.max(tonumber(properties.collision_depth) or self.depth, 0)
    self.collider.supports = true
    self.collider.one_way = properties.one_way == true or properties.oneway == true
    self.collider.collision_role = self.collider.one_way and "surface" or "solid"
    self.surface_id = properties.surface_id or properties.structure_id
    self.collider.surface_id = self.surface_id and tostring(self.surface_id) or nil
    self.collider.surface_plane = properties.surface_plane

    self.carry_momentum = properties.carry_momentum ~= false
    self.push_actors = properties.push_actors ~= false
    self.stop_on_block = properties.stop_on_block ~= false
    local autostart = properties.autostart ~= false
    self.motion_enabled = autostart

    self.motion_velocity_x = 0
    self.motion_velocity_y = 0
    self.motion_velocity_z = 0
    self.frame_delta_x = 0
    self.frame_delta_y = 0
    self.frame_delta_z = 0
    self.previous_x, self.previous_y, self.previous_z = self.x, self.y, self.z
    self.attached_objects = setmetatable({}, { __mode = "k" })
    self.motion = nil

    self.platform_color = type(properties.color) == "table"
        and properties.color or { 0.36, 0.38, 0.55, 1 }
    local sprite = properties.sprite
    if sprite and sprite ~= "" then
        self:setSprite(sprite, tonumber(properties.sprite_speed), false)
        self.sprite:setScale(tonumber(properties.scalex) or 2, tonumber(properties.scaley) or 2)
    end

    local offset_x = tonumber(properties.offset_x or properties.movex) or 0
    local offset_y = tonumber(properties.offset_y or properties.movey) or 0
    local offset_z = tonumber(properties.offset_z or properties.movez) or 0
    if offset_x ~= 0 or offset_y ~= 0 or offset_z ~= 0 then
        self:setPath({
            { x = self.x, y = self.y, z = self.z },
            { x = self.x + offset_x, y = self.y + offset_y, z = self.z + offset_z,
                wait = tonumber(properties.wait) or 0 }
        }, {
            mode = properties.mode or "pingpong",
            duration = math.max(tonumber(properties.duration) or 2, EPSILON),
            easing = properties.easing or "linear",
            wait = tonumber(properties.wait) or 0
        })
        self.motion_enabled = autostart
    end
end

function MovingPlatform:onAdd(parent)
    super.onAdd(self, parent)
    if self.world and self.world.map then
        self.surface = self.world.map:getSurfaceForCollider(self.collider)
        if not self.surface then
            self.surface = self.world.map:registerSurfaceCollider(
                self.collider, self.object_id or self.unique_id or tostring(self))
        end
        self.surface_id = self.collider.surface_id
        self:refreshSurface()
    end
end

function MovingPlatform:onRemove(parent)
    self:stop()
    if self.world and self.world.map then
        self.world.map:unregisterSurfaceCollider(self.collider)
    end
    super.onRemove(self, parent)
end

function MovingPlatform:refreshSurface()
    local surface = self.surface
    if not surface and self.world and self.world.map then
        surface = self.world.map:getSurfaceForCollider(self.collider)
        self.surface = surface
    end
    if not surface then return end

    local bottom, top = self.collider:getZBounds()
    local bounds = {
        min_x = self.x + (self.collider.x or 0),
        min_y = self.y + (self.collider.y or 0),
        max_x = self.x + (self.collider.x or 0) + (self.collider.width or self.width),
        max_y = self.y + (self.collider.y or 0) + (self.collider.height or self.height)
    }
    self.collider.map_bounds = bounds
    surface.dynamic = true
    surface.owner = self
    if self.world and self.world.map and self.world.map.refreshSurface then
        self.world.map:refreshSurface(surface)
    else
        surface.bottom, surface.top = bottom, top
        surface.bounds = bounds
        surface.support_top = top
        surface.support_bounds = bounds
    end
    if not surface.explicit_plane then surface.plane = "surface:" .. tostring(surface.id) end
end

---@param object Object
function MovingPlatform:attach(object)
    if object and object ~= self then self.attached_objects[object] = true end
end

---@param object Object
function MovingPlatform:detach(object)
    self.attached_objects[object] = nil
end

function MovingPlatform:isRider(object)
    return object and object.ground_collider == self.collider
        and (not object.isGrounded or object:isGrounded())
end

function MovingPlatform:getCarriedObjects()
    local result, found = {}, {}
    local function add(object)
        if object and object ~= self and object.parent and not found[object] then
            found[object] = true
            table.insert(result, object)
        end
    end
    if self.world then
        for _, object in ipairs(self.world.children) do
            if self:isRider(object) or self.attached_objects[object]
                or (self.surface_id and object.surface_id == self.surface_id
                    and object.is_moving_platform ~= true) then
                add(object)
            end
        end
    end
    for object in pairs(self.attached_objects) do add(object) end
    return result
end

---@param x number
---@param y number
---@param z number
---@param duration? number
---@param easing? string
---@param after? function
function MovingPlatform:moveTo(x, y, z, duration, easing, after)
    self:setPath({
        { x = self.x, y = self.y, z = self.z },
        { x = x, y = y, z = z }
    }, { mode = "once", duration = duration or 1, easing = easing or "linear", after = after })
end

function MovingPlatform:setVelocity(x, y, z)
    self.motion = { kind = "velocity", x = x or 0, y = y or 0, z = z or 0 }
    self.motion_enabled = true
end

--- Starts an XYZ path.
--- Points accept `{x, y, z, duration, wait}` or `{x, y, z}`.
--- Options: `relative`, `snap`, `mode` (`once`, `loop`, `pingpong`), `duration`,
--- `speed`, `easing`, `wait`, and `after`.
function MovingPlatform:setPath(points, options)
    options = options or {}
    assert(type(points) == "table" and #points > 0, "MovingPlatform path requires at least one point")
    local origin_x, origin_y, origin_z = self.x, self.y, self.z
    local normalized = {}
    for _, point in ipairs(points) do
        local px = pointValue(point, "x", 1, origin_x)
        local py = pointValue(point, "y", 2, origin_y)
        local pz = pointValue(point, "z", 3, origin_z)
        if options.relative then px, py, pz = origin_x + px, origin_y + py, origin_z + pz end
        table.insert(normalized, {
            x = px, y = py, z = pz,
            duration = tonumber(point.duration),
            wait = tonumber(point.wait)
        })
    end
    if options.snap then
        self:setPosition3D(normalized[1].x, normalized[1].y, normalized[1].z)
    elseif math.abs(self.x - normalized[1].x) > EPSILON
        or math.abs(self.y - normalized[1].y) > EPSILON
        or math.abs(self.z - normalized[1].z) > EPSILON then
        table.insert(normalized, 1, { x = self.x, y = self.y, z = self.z })
    end
    if #normalized == 1 then
        table.insert(normalized, { x = normalized[1].x, y = normalized[1].y, z = normalized[1].z })
    end
    self.motion = {
        kind = "path", points = normalized,
        mode = options.mode or (options.loop and "loop" or "once"),
        duration = math.max(tonumber(options.duration) or 1, EPSILON),
        speed = tonumber(options.speed), easing = options.easing or options.ease or "linear",
        wait = math.max(tonumber(options.wait) or 0, 0), after = options.after,
        index = 1, next_index = 2, direction = 1, elapsed = 0, waiting = 0
    }
    self.motion_enabled = true
    self:refreshSurface()
end

function MovingPlatform:stop()
    self.motion = nil
    self.motion_velocity_x, self.motion_velocity_y, self.motion_velocity_z = 0, 0, 0
end

function MovingPlatform:setMotionEnabled(enabled)
    self.motion_enabled = enabled ~= false
end

function MovingPlatform:getSegmentDuration(motion, from, to)
    if to.duration then return math.max(to.duration, EPSILON) end
    if motion.speed and motion.speed > 0 then
        local dx, dy, dz = to.x - from.x, to.y - from.y, to.z - from.z
        return math.max(math.sqrt(dx * dx + dy * dy + dz * dz) / (motion.speed * 30), EPSILON)
    end
    return motion.duration
end

function MovingPlatform:advancePath(motion)
    local count = #motion.points
    motion.index = motion.next_index
    local point = motion.points[motion.index]
    motion.waiting = math.max(point.wait or motion.wait or 0, 0)
    motion.elapsed = 0
    local next_index = motion.index + motion.direction
    if next_index >= 1 and next_index <= count then
        motion.next_index = next_index
        return
    end
    if motion.mode == "loop" then
        motion.next_index = motion.direction > 0 and 1 or count
    elseif motion.mode == "pingpong" then
        motion.direction = -motion.direction
        motion.next_index = motion.index + motion.direction
    else
        local after = motion.after
        self:stop()
        if after then after(self) end
    end
end

function MovingPlatform:getIntendedPosition(dt)
    local motion = self.motion
    if not self.motion_enabled or not motion then return self.x, self.y, self.z end
    if motion.kind == "velocity" then
        return self.x + motion.x * DTMULT, self.y + motion.y * DTMULT,
            self.z + motion.z * DTMULT
    end
    if motion.waiting > 0 then
        motion.waiting = math.max(motion.waiting - dt, 0)
        return self.x, self.y, self.z
    end
    local from, to = motion.points[motion.index], motion.points[motion.next_index]
    local duration = self:getSegmentDuration(motion, from, to)
    motion.elapsed = math.min(motion.elapsed + dt, duration)
    local progress = motion.elapsed / duration
    local x = Utils.ease(from.x, to.x, progress, motion.easing)
    local y = Utils.ease(from.y, to.y, progress, motion.easing)
    local z = Utils.ease(from.z, to.z, progress, motion.easing)
    if motion.elapsed >= duration then self:advancePath(motion) end
    return x, y, z
end

function MovingPlatform:canCarryTo(object, x, y, z)
    if not object.collider or object.noclip or NOCLIP then return true end
    local old_x, old_y, old_z = object.x, object.y, object.z
    object:setPosition3D(x, y, z)
    Object.uncache(object)
    local collided = self.world:checkMovementCollision3D(
        object.collider, object.enemy_collision, self.collider, z)
    object:setPosition3D(old_x, old_y, old_z)
    Object.uncache(object)
    return not collided
end

function MovingPlatform:isPlatformPositionClear(ignored)
    local bottom = self.collider:getZBounds()
    for _, other in ipairs(self.world:getCollision(false)) do
        if other ~= self.collider and not ignored[other.parent]
            and self.collider:collidesWith3D(other) then
            local _, other_top = other:getZBounds()
            local resting_on_support = other.supports
                and math.abs(other_top - bottom) <= EPSILON
            if not resting_on_support then return false end
        end
    end
    return true
end

function MovingPlatform:getActorsToPush(carried_lookup)
    local result = {}
    if not self.world or not self.world.stage then return result end
    for _, actor in ipairs(self.world.stage:getObjects(Character)) do
        if actor ~= self and actor.collider and not carried_lookup[actor]
            and self.collider:collidesWith3D(actor.collider) then
            table.insert(result, actor)
        end
    end
    return result
end

function MovingPlatform:applyStep(dx, dy, dz, carried)
    if dx == 0 and dy == 0 and dz == 0 then return true end
    for _, object in ipairs(carried) do
        if not self:canCarryTo(object, object.x + dx, object.y + dy, object.z + dz) then
            return false
        end
    end
    local carried_lookup, ignored = {}, { [self] = true }
    for _, object in ipairs(carried) do
        carried_lookup[object] = true
        ignored[object] = true
    end
    local old_x, old_y, old_z = self.x, self.y, self.z
    self:setPosition3D(old_x + dx, old_y + dy, old_z + dz)
    Object.uncache(self)
    self:refreshSurface()
    if not self:isPlatformPositionClear(ignored) then
        self:setPosition3D(old_x, old_y, old_z)
        Object.uncache(self)
        self:refreshSurface()
        return false
    end

    local pushed = self:getActorsToPush(carried_lookup)
    if #pushed > 0 and not self.push_actors then
        self:setPosition3D(old_x, old_y, old_z)
        Object.uncache(self)
        self:refreshSurface()
        return false
    end
    for _, actor in ipairs(pushed) do
        if not self:canCarryTo(actor, actor.x + dx, actor.y + dy, actor.z + dz) then
            self:setPosition3D(old_x, old_y, old_z)
            Object.uncache(self)
            self:refreshSurface()
            return false
        end
    end
    for _, object in ipairs(carried) do
        object:setPosition3D(object.x + dx, object.y + dy, object.z + dz)
        if object.ground_z then object.ground_z = object.ground_z + dz end
        Object.uncache(object)
    end
    for _, actor in ipairs(pushed) do
        actor:setPosition3D(actor.x + dx, actor.y + dy, actor.z + dz)
        Object.uncache(actor)
    end
    return true
end

--- Called by World before character movement. Do not call this from ordinary object update.
function MovingPlatform:preUpdateMotion(dt)
    local old_x, old_y, old_z = self.x, self.y, self.z
    local old_bottom, old_top = self.collider:getZBounds()
    self.collider.previous_bottom, self.collider.previous_top = old_bottom, old_top
    self.previous_x, self.previous_y, self.previous_z = old_x, old_y, old_z
    local target_x, target_y, target_z = self:getIntendedPosition(dt)
    local dx, dy, dz = target_x - old_x, target_y - old_y, target_z - old_z
    local steps = math.max(1, math.ceil(math.max(math.abs(dx), math.abs(dy), math.abs(dz))))
    local step_x, step_y, step_z = dx / steps, dy / steps, dz / steps
    local carried = self:getCarriedObjects()
    for _ = 1, steps do
        if not self:applyStep(step_x, step_y, step_z, carried) then
            if self.stop_on_block then self:stop() end
            break
        end
    end
    self.frame_delta_x, self.frame_delta_y, self.frame_delta_z =
        self.x - old_x, self.y - old_y, self.z - old_z
    local divisor = math.max(DTMULT, EPSILON)
    self.motion_velocity_x = self.frame_delta_x / divisor
    self.motion_velocity_y = self.frame_delta_y / divisor
    self.motion_velocity_z = self.frame_delta_z / divisor
    self:refreshSurface()
end

function MovingPlatform:applyExitMomentum(object)
    if not self.carry_momentum or not object then return end
    object.platform_momentum_x = self.motion_velocity_x
    object.platform_momentum_y = self.motion_velocity_y
    object.z_velocity = (object.z_velocity or 0) + self.motion_velocity_z
end

local function drawFallback(self)
    local color = self.platform_color
    Draw.setColor((color[1] or 0.36) * 0.65, (color[2] or 0.38) * 0.65,
        (color[3] or 0.55) * 0.65, color[4] or 1)
    love.graphics.rectangle("fill", 0, self.height - self.depth, self.width, self.depth)
    Draw.setColor(color[1] or 0.36, color[2] or 0.38, color[3] or 0.55, color[4] or 1)
    love.graphics.rectangle("fill", 0, -self.depth, self.width, self.height)
    Draw.setColor(1, 1, 1, 1)
end

function MovingPlatform:draw()
    super.draw(self)
    if not self.sprite then drawFallback(self) end
end

function MovingPlatform:drawHeightOcclusionMask()
    if self.sprite then
        super.drawHeightOcclusionMask(self)
    else
        drawFallback(self)
    end
end

return MovingPlatform
