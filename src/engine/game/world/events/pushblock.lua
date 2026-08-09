--- A Pushable Block! Collision for Pushblocks can be created by adding a `blockcollision` layer to a map. \
--- `PushBlock` is an [`Event`](lua://Event.init) - naming an object `pushblock` on an `objects` layer in a map creates this object. \
--- See this object's Fields for the configurable properties on this object.
---
---@class PushBlock : Event
---
---@field default_sprite    string      *[Property `sprite`]* An optional custom sprite the block should use
---@field solved_sprite     string      *[Property `solvedsprite`]* An optional custom solve sprite the block uses
---
---@field solid             boolean
---
---@field push_dist         number      *[Property `pushdist`]* The number of pixels the block moves per push (Defaults to `40`, one tile)
---@field push_timer        number      *[Property `pushtime`]* The time the block takes to complete a push, in seconds (Defaults to `0.2`)
---
---@field push_sound        string      *[Property `pushsound`]* The name of the sound file to play when the block is pushed (Defaults to `pushsound`)
---
---@field press_buttons     boolean     *[Property `pressbuttons`]* Unused (Defaults to `true`)
---
---@field lock_in_place     boolean     *[Property `lock`]* Whether the block gets locked in place when in a solved state (Defaults to `false`)
---
---@field input_lock        boolean     *[Property `inputlock`]* Whether the player's input's are locked while the block is being pushed
---
---@field start_x           number      Initial position of the block
---@field start_y           number      Initial position of the block
---
---@field state             string      The current state of the Pushblock - value can be IDLE, PUSH, or RESET
---
---@field solved            boolean     Whether the pushblock is in a solved state
---
---@overload fun(...) : PushBlock
local PushBlock, super = Class(Event)

function PushBlock:init(x, y, shape, properties, sprite, solved_sprite)
    super.init(self, x, y, shape)

    properties = properties or {}

    self.default_sprite = properties["sprite"] or sprite or "world/events/push_block"
    self.solved_sprite = properties["solvedsprite"] or properties["sprite"] or solved_sprite or sprite or "world/events/push_block_solved"

    self:setSprite(self.default_sprite)
    self.solid = true
    self.collider.supports = true

    -- Options
    self.push_dist = properties["pushdist"] or 40
    self.push_time = properties["pushtime"] or 0.2

    self.push_sound = properties["pushsound"] or "noise"

    self.press_buttons = properties["pressbuttons"] ~= false

    self.lock_in_place = properties["lock"] or false
    self.input_lock = properties["inputlock"]

    -- Height physics (enabled automatically on platforming maps).
    self.height_physics = properties["height_physics"] ~= false
    self.z_velocity = 0
    self.z_gravity = tonumber(properties["fallgravity"]) or 0.6
    self.max_fall_speed = tonumber(properties["maxfallspeed"]) or 12
    self.pit_fall_limit = tonumber(properties["pitfalllimit"]) or -80
    self.reset_on_pit = properties["resetonpit"] ~= false
    self.height_state = "GROUNDED"
    self.ground_z = self.z
    self.ground_collider = nil
    self.ground_surface = nil
    self.departed_ground_collider = nil

    local hx, hy = self.collider.x or 0, self.collider.y or 0
    local hw, hh = self.collider.width or self.width, self.collider.height or self.height
    local support_width = math.min(hw, math.max(2, hw * 0.25))
    local support_height = math.min(hh, math.max(2, hh * 0.25))
    self.support_collider = Hitbox(self,
        hx + (hw - support_width) / 2,
        hy + (hh - support_height) / 2,
        support_width, support_height)

    -- State variables
    self.start_x = self.x
    self.start_y = self.y
    self.start_z = self.z

    -- IDLE, PUSH, RESET
    self.state = "IDLE"

    self.solved = false
    self.push_input_locked = false
end

function PushBlock:isHeightPhysicsEnabled()
    return self.height_physics and self.world and self.world.map
        and self.world.map.platforming == true
end

function PushBlock:isGrounded()
    return not self:isHeightPhysicsEnabled() or self.height_state == "GROUNDED"
end

function PushBlock:onLoad()
    -- Map readers apply layer offsets and linked-surface Z after init.
    self.start_x, self.start_y, self.start_z = self.x, self.y, self.z
    self:initializeHeightState()
end

function PushBlock:initializeHeightState()
    self.z_velocity = 0
    self.departed_ground_collider = nil
    if not self:isHeightPhysicsEnabled() then
        self.height_state = "GROUNDED"
        self.ground_z = self.z
        return
    end
    local support_z, support, surface = self.world:getSupportAt(
        self.support_collider, self.z, 0.75, self.collider)
    if support_z then
        self:setGroundSupport(support_z, support, surface)
    else
        self.height_state = "FALL"
        self.ground_collider, self.ground_surface = nil, nil
    end
end

function PushBlock:setGroundSupport(z, collider, surface)
    self.z = z
    self.ground_z = z
    self.ground_collider = collider
    self.ground_surface = surface
    self.departed_ground_collider = nil
    self.z_velocity = 0
    self.height_state = "GROUNDED"
end

function PushBlock:beginHeightFall(silent)
    if self.height_state == "FALL" then return end
    self.departed_ground_collider = self.ground_collider
    self.ground_collider, self.ground_surface = nil, nil
    self.z_velocity = math.min(self.z_velocity, 0)
    self.height_state = "FALL"
    if not silent then self:onFall() end
end

function PushBlock:getHeightCollisionIgnore()
    local ignored = { [self.collider] = true }
    if self.departed_ground_collider then
        ignored[self.departed_ground_collider] = true
    end
    return ignored
end

--- Keeps a grounded block on flat ground or a continuous slope after an XY step.
function PushBlock:updateGroundAfterMovementStep(silent)
    if not self:isHeightPhysicsEnabled() or not self:isGrounded() then return end
    local slope_z, slope, slope_surface = self.world:getTraversableSlopeAt(
        self.support_collider, self.z, self.collider)
    if slope_z then
        self:setGroundSupport(slope_z, slope, slope_surface)
        return
    end
    local support_z, support, surface = self.world:getSupportAt(
        self.support_collider, self.z, 0.75, self.collider)
    if support_z then
        self:setGroundSupport(support_z, support, surface)
    else
        self:beginHeightFall(silent)
    end
end

--- Applies an XY delta in one-pixel steps so ramps remain continuous.
function PushBlock:moveHeightAware(dx, dy)
    local steps = math.max(1, math.ceil(math.max(math.abs(dx), math.abs(dy))))
    local step_x, step_y = dx / steps, dy / steps
    for _ = 1, steps do
        self.x, self.y = self.x + step_x, self.y + step_y
        Object.uncache(self)
        self:updateGroundAfterMovementStep(false)
    end
end

function PushBlock:updateHeightGrounded()
    local slope_z, slope, slope_surface = self.world:getTraversableSlopeAt(
        self.support_collider, self.z, self.collider)
    if slope_z then
        self:setGroundSupport(slope_z, slope, slope_surface)
        return
    end

    local support_z, support, surface = self.world:getSupportAt(
        self.support_collider, self.z, 0.75, self.collider)
    if support_z then
        self:setGroundSupport(support_z, support, surface)
    else
        self:beginHeightFall(false)
    end
end

function PushBlock:tryProjectedBaseLanding(old_z, new_z)
    if new_z >= 0 then return nil end

    local original_y = self.y
    local sweep_start = math.min(old_z, 0)
    local distance = sweep_start - new_z
    local steps = math.max(1, math.ceil(distance))
    for step = 1, steps do
        local sample_z = sweep_start - math.min(distance, step)
        self.y = original_y - sample_z
        Object.uncache(self)
        local ground_z, ground, surface = self.world:getGroundZAt(
            self.support_collider, 0, self.collider,
            self:getHeightCollisionIgnore())
        if ground_z and math.abs(ground_z) < 0.001 then
            return 0, ground, surface
        end
    end

    self.y = original_y
    Object.uncache(self)
    return nil
end

function PushBlock:updateHeightFall()
    local old_z = self.z
    self.z_velocity = math.max(
        self.z_velocity - self.z_gravity * DTMULT, -self.max_fall_speed)
    local new_z = self.z + self.z_velocity * DTMULT
    local ignored = self:getHeightCollisionIgnore()
    local landing_z, landing, surface = self.world:getLandingSurface(
        self.support_collider, old_z, new_z, self.collider,
        ignored, self.departed_ground_collider)

    if not landing_z then
        landing_z, landing, surface = self:tryProjectedBaseLanding(old_z, new_z)
    end

    if landing_z then
        self:setGroundSupport(landing_z, landing, surface)
        self:onLand()
    else
        self.z = new_z
        Object.uncache(self)
        if self.z <= self.pit_fall_limit then
            self:fallOut()
        end
    end
end

function PushBlock:updateHeight()
    if not self:isHeightPhysicsEnabled() or self.state == "RESET" then return end
    if self.height_state == "FALL" then
        self:updateHeightFall()
    else
        self:updateHeightGrounded()
    end
end

function PushBlock:update()
    super.update(self)
    self:updateHeight()
end

--- *(Override)* Called when the block leaves its supporting surface.
function PushBlock:onFall() end

--- *(Override)* Called when the block lands on a supporting surface.
function PushBlock:onLand() end

function PushBlock:fallOut()
    if self.state == "RESET" then return end
    if self.reset_on_pit then
        self:reset()
    else
        self:releasePushInputLock()
        self:remove()
    end
end

function PushBlock:onInteract(chara, facing)
    self:playPushSound()

    if self.state ~= "IDLE" then return true end

    if self:isHeightPhysicsEnabled() and not self:isGrounded() then
        self:onPushFail(facing)
        return true
    end

    if not self:checkCollision(facing) then
        self:onPush(facing)
    else
        self:onPushFail(facing)
    end

    return true
end

function PushBlock:playPushSound()
    if self.push_sound and self.push_sound ~= "" then
        Assets.stopAndPlaySound(self.push_sound)
    end
end

function PushBlock:checkCollision(facing)
    if self:isHeightPhysicsEnabled() then
        return self:checkHeightCollision(facing)
    end

    local collided = false

    local dx, dy = Utils.getFacingVector(facing)
    local target_x, target_y = self.x + dx * self.push_dist, self.y + dy * self.push_dist

    local x1, y1 = math.min(self.x, target_x), math.min(self.y, target_y)
    local x2, y2 = math.max(self.x + self.width, target_x + self.width), math.max(self.y + self.height, target_y + self.height)

    local bound_check = Hitbox(self.world, x1 + 1, y1 + 1, x2 - x1 - 2, y2 - y1 - 2)

    Object.startCache()
    for _, collider in ipairs(Game.world.map.block_collision) do
        if collider:collidesWith(bound_check) then
            collided = true
            break
        end
    end
    if not collided then
        self.collidable = false
        collided = self.world:checkCollision(bound_check)
        self.collidable = true
    end
    Object.endCache()

    return collided
end

function PushBlock:checkHeightCollision(facing)
    local dx, dy = Utils.getFacingVector(facing)
    dx, dy = dx * self.push_dist, dy * self.push_dist
    local steps = math.max(1, math.ceil(math.max(math.abs(dx), math.abs(dy))))
    local step_x, step_y = dx / steps, dy / steps
    local saved = {
        x = self.x, y = self.y, z = self.z,
        height_state = self.height_state, z_velocity = self.z_velocity,
        ground_z = self.ground_z, ground_collider = self.ground_collider,
        ground_surface = self.ground_surface,
        departed_ground_collider = self.departed_ground_collider
    }
    local collided = false

    Object.startCache()
    for _ = 1, steps do
        self.x, self.y = self.x + step_x, self.y + step_y
        Object.uncache(self)
        for _, blocker in ipairs(self.world.map.block_collision) do
            if self.collider:collidesWith3D(blocker) then
                collided = true
                break
            end
        end
        if not collided then
            collided = self.world:checkMovementCollision3D(
                self.collider, false, self.collider, self.z)
        end
        if collided then break end
        self:updateGroundAfterMovementStep(true)
    end
    Object.endCache()

    self.x, self.y, self.z = saved.x, saved.y, saved.z
    self.height_state, self.z_velocity = saved.height_state, saved.z_velocity
    self.ground_z, self.ground_collider = saved.ground_z, saved.ground_collider
    self.ground_surface = saved.ground_surface
    self.departed_ground_collider = saved.departed_ground_collider
    Object.uncache(self)
    return collided
end

function PushBlock:setPushInputLocked(locked)
    if not locked or self.push_input_locked then return end
    self.push_input_locked = true
    Game.lock_movement = true
end

function PushBlock:releasePushInputLock()
    if not self.push_input_locked then return end
    self.push_input_locked = false
    if not self.world or not self.world.cutscene then
        Game.lock_movement = false
    end
end

function PushBlock:onPush(facing)
    if self.solved then
        if self.lock_in_place then
            return
        end

        self.solved = false
        self:onUnsolved()
    end

    local input_lock = Game:getConfig("pushBlockInputLock")
    if self.input_lock ~= nil then
        input_lock = self.input_lock
    end

    self:setPushInputLocked(input_lock)

    self.state = "PUSH"
    local dx, dy = Utils.getFacingVector(facing)
    self:slideTo(self.x + dx * self.push_dist, self.y + dy * self.push_dist, self.push_time, "linear", function()
        self.state = "IDLE"
        self:onPushEnd(facing)
        self:releasePushInputLock()
    end)
    if self.physics.move_target and self:isHeightPhysicsEnabled() then
        self.physics.move_target.move_func = function(_, move_x, move_y)
            self:moveHeightAware(move_x, move_y)
        end
    end
end

--- *(Override)* Called when the block enters a solved state
function PushBlock:onSolved()
    self:setSprite(self.solved_sprite)
end

--- *(Override)* Called when the block stops being in a solved state
function PushBlock:onUnsolved()
    self:setSprite(self.default_sprite)
end

--- *(Override)* Called when a block finishes being pushed
function PushBlock:onPushEnd(facing) end
--- *(Override)* Called when a block cannot be pushed because of collision
function PushBlock:onPushFail(facing) end

--- Fades the block out and returns it to its original position
function PushBlock:reset()
    if self.solved then
        self.solved = false
        self:onUnsolved()
    end

    self.physics.move_target = nil
    self.physics.move_path = nil
    self:releasePushInputLock()
    self.state = "RESET"
    self.collidable = false
    self.sprite:fadeToSpeed(0, 0.2, function()
        self.x = self.start_x
        self.y = self.start_y
        self.z = self.start_z
        self.z_velocity = 0
        self.ground_z = self.start_z
        self.ground_collider, self.ground_surface = nil, nil
        self.departed_ground_collider = nil
        Object.uncache(self)
        self:onReset()
        self.sprite:fadeToSpeed(1, 0.2, function()
            self.collidable = true
            self.state = "IDLE"
            self:initializeHeightState()
        end)
    end)
end

--- *(Override)* Called when the block is reset
function PushBlock:onReset() end

return PushBlock
