---@class WorldSoul : Soul
---@field is_active boolean
---@field platforming_enabled boolean
---@field height_state "GROUNDED"|"FALL"|"LAND"|"PIT_RECOVER"
local WorldSoul, super = Class(Soul)

local HEIGHT_EPSILON = 0.001

local function configNumber(name, default)
    local value = Kristal.getLibConfig("worldsoul", name)
    return tonumber(value) or default
end

local function addHeightCollisionIgnore(ignored, collider)
    if not collider then return ignored end
    if not ignored then return collider end
    if isClass(ignored) then ignored = { [ignored] = true } end
    ignored[collider] = true
    return ignored
end

---@param x number
---@param y number
---@param color? Color
---@param z? number
function WorldSoul:init(x, y, color, z)
    super.init(self, x, y, color)

    Game.world.world_soul = self
    self.interact_buffer = 0
    self:setColor(color or { Game:getSoulColor() })

    self.sprite:set("player/heart")

    self.bullet_collider = self.collider
    self.collider = CircleCollider(self, 0, 0, 8)
    self.collider.depth = configNumber("collision_depth", 12)
    self.support_collider = CircleCollider(self, 0, 0, 2)
    self.interact_collider = Hitbox(self, -12, -12, 24, 24)
    self.interact_collider.depth = self.collider.depth

    self.persistent = true
    self.noclip = false
    self.speed = 2
    self.is_active = true
    self.inv_timer = self.inv_timer or 0
    self:setCameraOriginExact(0, 0)

    self.platforming_enabled = false
    self.use_3d_collision = false
    self.height_sort_subject = true
    self.height_depth_transparent = true

    self.spawn_z_explicit = z ~= nil
    self.z = tonumber(z) or 0
    self.spawn_x, self.spawn_y, self.spawn_z = self.x, self.y, self.z

    self.height_state = "GROUNDED"
    self.z_velocity = 0
    self.z_gravity = configNumber("fall_gravity", 0.4)
    self.max_fall_speed = configNumber("max_fall_speed", 8)
    self.pit_fall_limit = configNumber("pit_fall_limit", -80)
    self.ground_z = self.z
    self.ground_collider = nil
    self.ground_surface = nil
    self.airborne_surface = nil
    self.departed_ground_collider = nil
    self.departed_ground_surface = nil
    self.fall_through_colliders = {}
    self.landing_overlap_colliders = {}
    self.platform_momentum_x = 0
    self.platform_momentum_y = 0

    self.last_safe_x, self.last_safe_y, self.last_safe_z = self.x, self.y, self.z
    self.last_safe_surface_id = nil

    self.hover_height = configNumber("hover_height", 7)
    self.hover_bob = configNumber("hover_bob", 2)
    self.hover_speed = configNumber("hover_speed", 1.5)
    self.hover_offset = 0
    self.hover_time = 0
    self.land_time = math.max(configNumber("land_time", 0.25), 0.001)
    self.land_timer = 0
    self.land_start_hover = self.hover_height

    self.pit_recovery_out_time = math.max(
        configNumber("pit_recovery_out_time", 0.25), 0.001)
    self.pit_recovery_hold_time = configNumber("pit_recovery_hold_time", 0.1)
    self.pit_recovery_in_time = math.max(
        configNumber("pit_recovery_in_time", 0.25), 0.001)
    self.pit_recovery_timer = 0
    self.pit_recovery_progress = 0
    self.pit_recovery_teleported = false

    self:syncVisualHover()
end

---@param parent Object
function WorldSoul:onAdd(parent)
    super.onAdd(self, parent)
    if parent:includes(World) then
        self.world = parent
        self.layer = parent.map and parent.map.object_layer or self.layer
        self:setPlatformingEnabled(parent.map and parent.map.platforming)
        if not self.height_shadow then
            self.height_shadow = WorldSoulShadow(self)
            parent:addChild(self.height_shadow)
        end
    end
end

---@param parent Object
function WorldSoul:onRemove(parent)
    self:removeFX("world_soul_pit_recovery")
    if self.height_shadow then
        self.height_shadow:remove()
        self.height_shadow = nil
    end
    super.onRemove(self, parent)

    if parent == Game.world and Game.world.world_soul == self then
        Game.world.world_soul = nil
    end
end

function WorldSoul:getDebugInfo()
    local info = super.getDebugInfo(self)
    table.insert(info, "Platforming: " .. tostring(self.platforming_enabled))
    table.insert(info, "Height state: " .. tostring(self.height_state))
    table.insert(info, "Z: " .. tostring(self.z))
    table.insert(info, "Z velocity: " .. tostring(self.z_velocity))
    table.insert(info, "Hover: " .. tostring(self.hover_offset))
    return info
end

---@param enabled boolean?
function WorldSoul:setPlatformingEnabled(enabled)
    self.platforming_enabled = enabled == true
    self.use_3d_collision = self.platforming_enabled

    if not self.platforming_enabled then
        self.z = 0
        self.z_velocity = 0
        self.ground_z = 0
        self.ground_collider = nil
        self.ground_surface = nil
        self.airborne_surface = nil
        self.departed_ground_collider = nil
        self.departed_ground_surface = nil
        self.fall_through_colliders = {}
        self.landing_overlap_colliders = {}
        self.platform_momentum_x, self.platform_momentum_y = 0, 0
        self.height_state = "GROUNDED"
        self.hover_offset = 0
        self:syncVisualHover()
        return
    end

    local maximum_z = self.spawn_z_explicit and self.z or math.huge
    local ground_z, ground, surface = self.world:getGroundZAt(
        self.support_collider, maximum_z, self.collider
    )
    if ground_z then
        self.z = ground_z
        self.ground_z = ground_z
        self.ground_collider = ground
        self.ground_surface = surface
        self.height_state = "GROUNDED"
        self.last_safe_x, self.last_safe_y, self.last_safe_z = self.x, self.y, self.z
        self.last_safe_surface_id = surface and surface.id or nil
    else
        self.height_state = "FALL"
    end
    self.hover_offset = self.hover_height
    self:syncVisualHover()
end

---@param x number
---@param y number
---@param z? number
function WorldSoul:enterMap(x, y, z)
    self:removeFX("world_soul_pit_recovery")
    self:setExactPosition(x, y)
    self.z = tonumber(z) or 0
    self.spawn_z_explicit = z ~= nil
    self.spawn_x, self.spawn_y, self.spawn_z = self.x, self.y, self.z

    self.height_state = "GROUNDED"
    self.z_velocity = 0
    self.ground_z = self.z
    self.ground_collider = nil
    self.ground_surface = nil
    self.airborne_surface = nil
    self.departed_ground_collider = nil
    self.departed_ground_surface = nil
    self.fall_through_colliders = {}
    self.landing_overlap_colliders = {}
    self.platform_momentum_x, self.platform_momentum_y = 0, 0
    self.pit_recovery_timer = 0
    self.pit_recovery_progress = 0
    self.pit_recovery_teleported = false
    self.hover_offset = 0
    self.layer = self.world.map and self.world.map.object_layer or self.layer

    Object.uncache(self)
    self:setPlatformingEnabled(self.world.map and self.world.map.platforming)
    self.spawn_z = self.z
    self.last_safe_x, self.last_safe_y, self.last_safe_z = self.x, self.y, self.z
    self.last_safe_surface_id = self.ground_surface and self.ground_surface.id or nil
    self:syncVisualHover()
    self:onMapLoad(self.world.map)
end

---@param map Map
function WorldSoul:onMapLoad(map)
end

---@return FacingDirection
function WorldSoul:getTransitionFacing()
    local x, y = self.moving_x or 0, self.moving_y or 0
    if math.abs(x) > math.abs(y) then
        return x < 0 and "left" or "right"
    elseif y ~= 0 then
        return y < 0 and "up" or "down"
    end
    return "down"
end

---@return boolean
function WorldSoul:isGrounded()
    return self.height_state == "GROUNDED" or self.height_state == "LAND"
end

---@return boolean
function WorldSoul:isFalling()
    return self.height_state == "FALL"
end

---@return boolean
function WorldSoul:isPitRecovering()
    return self.height_state == "PIT_RECOVER"
end

---@return table?
function WorldSoul:getHeightSurface()
    return self.ground_surface or self.airborne_surface
        or self.world and self.world:getImplicitHeightSurface() or nil
end

---@return string?
function WorldSoul:getHeightSurfacePlane()
    local surface = self:getHeightSurface()
    return surface and surface.plane or nil
end

function WorldSoul:getSortPosition()
    return self:getRelativePos(0, 0, self.parent)
end

---@return number x
---@return number y
function WorldSoul:getHeightCutoutCenter()
    return 0, -(self.platforming_enabled and self.hover_offset or 0)
end

---@param camera Camera
---@return number x
---@return number y
function WorldSoul:getCameraTargetOffset(camera)
    if not self.platforming_enabled then return 0, 0 end
    return 0, -self.z
end

function WorldSoul:drawHeightOcclusionMask()
    if self.sprite and self.sprite.visible then
        self.sprite:fullDraw(false)
    end
end

function WorldSoul:shouldDrawHeightShadow()
    return self.platforming_enabled and self.shadow_z ~= nil
        and not self:isPitRecovering()
end

function WorldSoul:getHeightShadowOffset()
    if self.shadow_z == nil then return 0 end
    return math.max(self.z + self.hover_offset - self.shadow_z, 0)
end

function WorldSoul:getHeightShadowAlpha()
    return MathUtils.clamp(0.32 - self:getHeightShadowOffset() / 320, 0.08, 0.32)
end

function WorldSoul:syncVisualHover()
    local hover = self.platforming_enabled and self.hover_offset or 0
    local visual_y = -hover
    self.sprite.y = visual_y
    self.graze_sprite.y = visual_y
    self.parry_sprite.y = visual_y
    self.parry_glow.y = visual_y

    local collider_y = self.platforming_enabled and -(self.z + hover) or 0
    self.bullet_collider.y = collider_y
    self.graze_collider.y = collider_y
end

function WorldSoul:updateHover()
    if not self.platforming_enabled then
        self.hover_offset = 0
        self:syncVisualHover()
        return
    end

    self.hover_time = self.hover_time + DT
    local bob = math.sin(self.hover_time * math.pi * 2 * self.hover_speed)
        * self.hover_bob

    if self.height_state == "GROUNDED" then
        self.hover_offset = self.hover_height + bob
    elseif self.height_state == "LAND" then
        local progress = MathUtils.clamp(self.land_timer / self.land_time, 0, 1)
        local eased = 1 - ((1 - progress) ^ 3)
        self.hover_offset = MathUtils.lerp(
            self.land_start_hover, self.hover_height + bob, eased)
    elseif self.height_state == "FALL" then
        self.hover_offset = MathUtils.approach(
            self.hover_offset, self.hover_height, DT * 20)
    end

    self:syncVisualHover()
end

---@param new_state "GROUNDED"|"FALL"|"LAND"|"PIT_RECOVER"
---@param impact_speed? number
function WorldSoul:setHeightState(new_state, impact_speed)
    if self.height_state == new_state then return end
    local old_state = self.height_state
    self.height_state = new_state

    if new_state == "FALL" then
        self:beginHeightFall(old_state)
    elseif new_state == "LAND" then
        self:beginHeightLand(impact_speed or 0)
    elseif new_state == "PIT_RECOVER" then
        self:beginHeightPitRecovery()
    elseif old_state == "PIT_RECOVER" then
        self:endHeightPitRecovery()
    end
end

function WorldSoul:beginHeightFall(last_state)
    local previous_ground = self.ground_collider
    local previous_surface = self.ground_surface
    if last_state == "GROUNDED" or last_state == "LAND" then
        self.z_velocity = math.min(self.z_velocity, 0)
        local platform = previous_ground and previous_ground.parent
        if platform and platform.is_moving_platform and platform.applyExitMomentum then
            platform:applyExitMomentum(self)
        end
        self.departed_ground_collider = previous_ground
        self.departed_ground_surface = previous_surface
        self.airborne_surface = previous_surface
            or self.world:getImplicitHeightSurface()
    end
    self.ground_collider = nil
    self.ground_surface = nil
end

---@param impact_speed number
function WorldSoul:beginHeightLand(impact_speed)
    self.land_timer = 0
    local compression = MathUtils.clamp(2 + impact_speed * 0.3, 2, 5)
    self.land_start_hover = math.max(
        self.hover_height - compression, math.min(2, self.hover_height))
    self.hover_offset = self.land_start_hover
end

---@return Collider|table<Collider, boolean>?
function WorldSoul:getDepartedGroundCollisionIgnore()
    local surface = self.departed_ground_collider
    if not surface or not self.platforming_enabled then return nil end
    if self.world:isSupportOver(self.support_collider, surface) then return nil end
    if self.height_state == "FALL" then return surface end
    if not self.collider:collidesWith(surface) then return nil end
    return surface
end

---@return Collider|table<Collider, boolean>?
function WorldSoul:getHeightCollisionIgnore()
    local ignored = self:getDepartedGroundCollisionIgnore()
    for wall in pairs(self.fall_through_colliders) do
        if not self.world:isSupportOver(self.collider, wall) then
            ignored = addHeightCollisionIgnore(ignored, wall)
        end
    end
    return ignored
end

---@return Collider|table<Collider, boolean>?
function WorldSoul:getMovementHeightCollisionIgnore()
    local ignored = self:getDepartedGroundCollisionIgnore()
    for wall in pairs(self.fall_through_colliders) do
        if not self:isGrounded() or self.landing_overlap_colliders[wall]
            or not self.world:isSupportOver(self.collider, wall) then
            ignored = addHeightCollisionIgnore(ignored, wall)
        end
    end
    return ignored
end

---@return number
function WorldSoul:getMovementCollisionZ()
    if not self.platforming_enabled or self.height_state ~= "FALL" then
        return self.z
    end
    local next_velocity = math.max(
        self.z_velocity - self.z_gravity * DTMULT, -self.max_fall_speed)
    return math.min(self.z, self.z + next_velocity * DTMULT)
end

function WorldSoul:onHeightMovementStep()
    if not self.platforming_enabled or not self:isGrounded() then return end
    local slope_z, slope, surface = self.world:getTraversableSlopeAt(
        self.support_collider, self.z)
    if not slope_z then return end
    self.z = slope_z
    self.ground_z = slope_z
    self.ground_collider = slope
    self.ground_surface = surface
    self.airborne_surface = nil
end

function WorldSoul:updateFallThroughColliders()
    Object.startCache()
    for _, wall in ipairs(self.world:getCollision(false)) do
        if not wall.one_way and not wall.supports
            and self.collider:collidesWith3D(wall) then
            self.fall_through_colliders[wall] = true
        end
    end
    Object.endCache()
end

function WorldSoul:recordLandingCollisionOverlaps()
    self:updateFallThroughColliders()
    for wall in pairs(self.fall_through_colliders) do
        if self.collider:collidesWith3D(wall) then
            self.landing_overlap_colliders[wall] = true
        end
    end
end

function WorldSoul:updateDepartedGroundCollision()
    local surface = self.departed_ground_collider
    if surface then
        local returned = self:isGrounded()
            and self.world:isSupportOver(self.support_collider, surface)
        if returned or (self.height_state ~= "FALL"
            and not self.collider:collidesWith(surface)) then
            self.departed_ground_collider = nil
            self.departed_ground_surface = nil
        end
    end
    for wall in pairs(self.fall_through_colliders) do
        if not self.collider:collidesWith(wall) then
            self.fall_through_colliders[wall] = nil
            self.landing_overlap_colliders[wall] = nil
        end
    end
end

---@param old_z number
---@param new_z number
---@return number? landing_z
---@return Collider? surface
---@return table? height_surface
function WorldSoul:tryProjectedBaseLanding(old_z, new_z)
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
        if ground_z and math.abs(ground_z) < HEIGHT_EPSILON then
            return 0, ground, surface
        end
    end
    self.y = original_y
    Object.uncache(self)
    return nil
end

function WorldSoul:updateHeightGrounded()
    local support_z, support, surface = self.world:getSupportAt(
        self.support_collider, self.z)
    if not support_z then
        self:setHeightState("FALL")
        return
    end

    self.z = support_z
    self.ground_z = support_z
    self.ground_collider = support
    self.ground_surface = surface
    self.airborne_surface = nil
    self.z_velocity = 0
    self.platform_momentum_x, self.platform_momentum_y = 0, 0
    if not self.world:isOverPit(self.support_collider) then
        self.last_safe_x, self.last_safe_y, self.last_safe_z = self.x, self.y, self.z
        self.last_safe_surface_id = surface and surface.id or nil
    end
end

function WorldSoul:updateHeightFall()
    local old_z = self.z
    self.z_velocity = math.max(
        self.z_velocity - self.z_gravity * DTMULT, -self.max_fall_speed)
    local new_z = self.z + self.z_velocity * DTMULT

    if new_z > old_z then
        local ceiling_z = self.world:getCeilingSurface(
            self.collider,
            old_z + self.collider.depth,
            new_z + self.collider.depth)
        if ceiling_z then
            self.z = ceiling_z - self.collider.depth
            self.z_velocity = 0
        else
            self.z = new_z
        end
        self:updateFallThroughColliders()
        return
    end

    local ignored = self:getHeightCollisionIgnore()
    local landing_z, landing, surface = self.world:getLandingSurface(
        self.support_collider, old_z, new_z, self.collider,
        ignored, self.departed_ground_collider)

    if not landing_z then
        landing_z, landing, surface = self:tryProjectedBaseLanding(old_z, new_z)
    end

    if landing_z then
        local impact_speed = math.abs(self.z_velocity)
        self.z = landing_z
        self.ground_z = landing_z
        self.ground_collider = landing
        self.ground_surface = surface
        self.airborne_surface = nil
        self.z_velocity = 0
        self:recordLandingCollisionOverlaps()
        self:setHeightState("LAND", impact_speed)
    else
        self.z = new_z
        self:updateFallThroughColliders()
        if self.z <= self.pit_fall_limit then
            self:setHeightState("PIT_RECOVER")
        end
    end
end

function WorldSoul:updateHeightLand()
    local support_z, support, surface = self.world:getSupportAt(
        self.support_collider, self.z)
    if not support_z then
        self:setHeightState("FALL")
        return
    end

    self.z = support_z
    self.ground_z = support_z
    self.ground_collider = support
    self.ground_surface = surface
    self.airborne_surface = nil
    self.land_timer = self.land_timer + DT
    if self.land_timer >= self.land_time then
        self:setHeightState("GROUNDED")
    end
end

function WorldSoul:beginHeightPitRecovery()
    self.z_velocity = 0
    self.ground_collider = nil
    self.ground_surface = nil
    self.airborne_surface = nil
    self.departed_ground_collider = nil
    self.departed_ground_surface = nil
    self.fall_through_colliders = {}
    self.landing_overlap_colliders = {}
    self.platform_momentum_x, self.platform_momentum_y = 0, 0
    self.pit_recovery_timer = 0
    self.pit_recovery_progress = 0
    self.pit_recovery_teleported = false

    self:removeFX("world_soul_pit_recovery")
    self:addFX(ShaderFX("goner_bleed", {
        progress = function() return self.pit_recovery_progress end,
        time = function() return Kristal.getTime() end
    }, false), "world_soul_pit_recovery")
end

function WorldSoul:teleportFromPit()
    self:setExactPosition(self.last_safe_x or self.spawn_x,
        self.last_safe_y or self.spawn_y)
    self.z = self.last_safe_z or self.spawn_z or 0
    self.z_velocity = 0
    Object.uncache(self)
    local ground_z, ground, surface = self.world:getSupportAt(
        self.support_collider, self.z)
    if ground_z then self.z = ground_z end
    self.ground_z = self.z
    self.ground_collider = ground
    self.ground_surface = surface
    self.airborne_surface = nil
end

function WorldSoul:updateHeightPitRecovery()
    self.pit_recovery_timer = self.pit_recovery_timer + DT
    local out_end = self.pit_recovery_out_time
    local hold_end = out_end + self.pit_recovery_hold_time
    local recovery_end = hold_end + self.pit_recovery_in_time

    if self.pit_recovery_timer < out_end then
        self.pit_recovery_progress = self.pit_recovery_timer / out_end
    elseif self.pit_recovery_timer < hold_end then
        self.pit_recovery_progress = 1
    else
        if not self.pit_recovery_teleported then
            self.pit_recovery_teleported = true
            self:teleportFromPit()
        end
        self.pit_recovery_progress = 1 - MathUtils.clamp(
            (self.pit_recovery_timer - hold_end) / self.pit_recovery_in_time, 0, 1)
    end

    if self.pit_recovery_timer >= recovery_end then
        self:setHeightState("GROUNDED")
    end
end

function WorldSoul:endHeightPitRecovery()
    self:removeFX("world_soul_pit_recovery")
    self.pit_recovery_progress = 0
end

function WorldSoul:updateHeight()
    if not self.platforming_enabled then return end
    self:updateDepartedGroundCollision()
    if self.height_state == "GROUNDED" then
        self:updateHeightGrounded()
    elseif self.height_state == "FALL" then
        self:updateHeightFall()
    elseif self.height_state == "LAND" then
        self:updateHeightLand()
    elseif self.height_state == "PIT_RECOVER" then
        self:updateHeightPitRecovery()
    end

    self.shadow_z, _, self.shadow_surface = self.world:getGroundZAt(
        self.support_collider, self.z, self.collider,
        self:getHeightCollisionIgnore())
end

function WorldSoul:updatePlatformMomentum()
    if not self.platforming_enabled or self:isGrounded()
        or self:isPitRecovering() then
        self.platform_momentum_x, self.platform_momentum_y = 0, 0
        return
    end
    local x, y = self.platform_momentum_x or 0, self.platform_momentum_y or 0
    if x == 0 and y == 0 then return end
    local moved_x = self:moveX(x * DTMULT, y * DTMULT)
    local moved_y = self:moveY(y * DTMULT, x * DTMULT)
    if not moved_x and self.last_collided_x then self.platform_momentum_x = 0 end
    if not moved_y and self.last_collided_y then self.platform_momentum_y = 0 end
end

function WorldSoul:doMovement()
    local speed = self.speed
    if self.allow_focus and Input.down("cancel") then speed = speed / 2 end

    local move_x, move_y = 0, 0
    if Input.down("left") then move_x = move_x - 1 end
    if Input.down("right") then move_x = move_x + 1 end
    if Input.down("up") then move_y = move_y - 1 end
    if Input.down("down") then move_y = move_y + 1 end
    self.moving_x, self.moving_y = move_x, move_y

    if move_x ~= 0 or move_y ~= 0 then
        if not self:move(move_x, move_y, speed * DTMULT) then
            self.moving_x, self.moving_y = 0, 0
        end
    end
end

---@param axis "x"|"y"
---@param amount number
---@param other_amount number
---@return boolean
---@return Object?
function WorldSoul:moveExact(axis, amount, other_amount)
    local other_axis = axis == "x" and "y" or "x"
    local sign = MathUtils.sign(amount)
    for i = sign, amount, sign do
        local last_axis, last_other = self[axis], self[other_axis]
        self[axis] = self[axis] + sign

        if not self.noclip and not NOCLIP then
            Object.uncache(self)
            Object.startCache()
            local collided, target = self.world:checkSoulMovementCollision(
                self.collider, self:getMovementHeightCollisionIgnore(),
                self:getMovementCollisionZ())
            if self.slope_correction and collided and not (other_amount > 0) then
                for j = 1, 2 do
                    Object.uncache(self)
                    self[other_axis] = self[other_axis] - 1
                    collided, target = self.world:checkSoulMovementCollision(
                        self.collider, self:getMovementHeightCollisionIgnore(),
                        self:getMovementCollisionZ())
                    if not collided then break end
                end
            end
            if self.slope_correction and collided and not (other_amount < 0) then
                self[other_axis] = last_other
                for j = 1, 2 do
                    Object.uncache(self)
                    self[other_axis] = self[other_axis] + 1
                    collided, target = self.world:checkSoulMovementCollision(
                        self.collider, self:getMovementHeightCollisionIgnore(),
                        self:getMovementCollisionZ())
                    if not collided then break end
                end
            end
            Object.endCache()

            if collided then
                self[axis], self[other_axis] = last_axis, last_other
                if target and target.onSoulCollide then target:onSoulCollide(self) end
                self["last_collided_" .. axis] = sign
                return false, target
            end
        end

        self:onHeightMovementStep()
        Object.uncache(self)
    end
    self["last_collided_" .. axis] = 0
    return true
end

function WorldSoul:moveXExact(amount, move_y)
    return self:moveExact("x", amount, move_y)
end

function WorldSoul:moveYExact(amount, move_x)
    return self:moveExact("y", amount, move_x)
end

function WorldSoul:updateTransition()
    if self.timer >= 7 then
        Input.clear("cancel")
        self.timer = 0
        if self.transition_destroy then
            local visual_y = self.y - self.z - self.hover_offset
            Game.world:addChild(HeartBurst(self.x, visual_y, { Game:getSoulColor() }))
            self:remove()
        else
            self.transitioning = false
            self:setExactPosition(self.target_x, self.target_y)
        end
    else
        self:setExactPosition(
            MathUtils.lerp(self.original_x, self.target_x,
                MathUtils.clamp(self.timer / 7, 0, 1)),
            MathUtils.lerp(self.original_y, self.target_y,
                MathUtils.clamp(self.timer / 7, 0, 1)))
        self.alpha = MathUtils.lerp(0, self.target_alpha or 1,
            MathUtils.clamp(self.timer / 3, 0, 1))
        self.sprite:setColor(self.color[1], self.color[2], self.color[3], self.alpha)
        self.timer = self.timer + DTMULT
    end
end

function WorldSoul:updateBulletCollision()
    if self.inv_timer > 0 then
        self.inv_timer = MathUtils.approach(self.inv_timer, 0, DT)
    end

    local collided_bullets = {}
    Object.startCache()
    for _, bullet in ipairs(Game.stage:getObjects(Bullet)) do
        if bullet:collidesWith(self.bullet_collider) then
            table.insert(collided_bullets, bullet)
        end
        if self.inv_timer == 0 and bullet:canGraze()
            and bullet:collidesWith(self.graze_collider) then
            local old_graze = bullet.grazed
            if bullet.grazed then
                Game:giveTension(bullet:getGrazeTension() * DT * self.graze_tp_factor)
                if self.graze_sprite.timer < 0.1 then self.graze_sprite.timer = 0.1 end
                bullet:onGraze(false)
            else
                Assets.playSound("graze")
                Game:giveTension(bullet:getGrazeTension() * self.graze_tp_factor)
                self.graze_sprite.timer = 1 / 3
                bullet.grazed = true
                bullet:onGraze(true)
            end
            self:onGraze(bullet, old_graze)
        end
    end
    Object.endCache()
    for _, bullet in ipairs(collided_bullets) do self:onCollide(bullet) end

    if self.inv_timer > 0 then
        self.inv_flash_timer = self.inv_flash_timer + DT
        if (math.floor(self.inv_flash_timer / (4 / 30)) % 2) == 1 then
            self.sprite:setColor(0.5, 0.5, 0.5)
        else
            self.sprite:setColor(1, 1, 1)
        end
    else
        self.inv_flash_timer = 0
        self.sprite:setColor(1, 1, 1)
    end
end

function WorldSoul:update()
    if self.transitioning then
        self:updateTransition()
        self:updateHover()
        Object.update(self)
        return
    end

    if self.can_move and self.is_active and not Game.lock_movement
        and not self:isPitRecovering() then
        self:doMovement()
    end
    self:updatePlatformMomentum()
    self:updateHeight()
    self:updateHover()
    self:updateBulletCollision()

    if self.interact_buffer > 0 then
        self.interact_buffer = MathUtils.approach(self.interact_buffer, 0, DT)
    end
    Object.update(self)
end

function WorldSoul:onCollide(bullet)
end

--- Shatters the soul into several shards.
---@param count? integer
function WorldSoul:shatter(count)
    Assets.playSound("break2")
    local visual_y = self.y - self.z - self.hover_offset
    self.shards = {}
    for i = 1, count or 6 do
        local x_pos = self.shard_x_table[((i - 1) % #self.shard_x_table) + 1]
        local y_pos = self.shard_y_table[((i - 1) % #self.shard_y_table) + 1]
        local shard = Sprite("player/heart_shard", self.x + x_pos, visual_y + y_pos)
        shard:setColor(self:getColor())
        shard.physics.direction = math.rad(MathUtils.random(360))
        shard.physics.speed = 7
        shard.physics.gravity = 0.2
        shard.layer = self.layer
        shard:play(5 / 30)
        table.insert(self.shards, shard)
        self.stage:addChild(shard)
    end
    self:remove()
    Game.world.world_soul = nil
end

function WorldSoul:interact()
    if self.interact_buffer > 0 then return true end

    local interactables = {}
    Object.startCache()
    for _, obj in ipairs(Game.world.children) do
        local collided
        if self.platforming_enabled and obj.height_sensitive then
            collided = obj:collidesWith3D(self.interact_collider)
        else
            collided = obj:collidesWith(self.interact_collider)
        end
        if obj.onSoulInteract and collided then
            local rx, ry = obj:getRelativePos(obj.width / 2, obj.height / 2, self.parent)
            table.insert(interactables, {
                obj = obj,
                dist = MathUtils.dist(self.x, self.y, rx, ry)
            })
        end
    end
    Object.endCache()

    table.sort(interactables, function(a, b) return a.dist < b.dist end)
    for _, candidate in ipairs(interactables) do
        if candidate.obj:onSoulInteract(self) then
            self.interact_buffer = candidate.obj.interact_buffer or 0
            return true
        end
    end
    return false
end

return WorldSoul
