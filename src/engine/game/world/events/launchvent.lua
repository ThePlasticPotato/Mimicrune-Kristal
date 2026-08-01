--- A height-aware vent that either follows an arc
--- or applies a launch velocity.
---@class LaunchVent : Event
---@overload fun(data: table): LaunchVent
local LaunchVent, super = Class(Event)

local DIRECTIONS = {
    up = { 0, -1, -math.pi / 2 },
    down = { 0, 1, math.pi / 2 },
    left = { -1, 0, math.pi },
    right = { 1, 0, 0 }
}

function LaunchVent:init(data)
    data = data or {}
    local properties = data.properties or {}
    super.init(self, data)

    self.mode = properties.mode == "force" and "force" or "target"
    self.direction = DIRECTIONS[properties.direction] and properties.direction or "right"
    self.pad_variant = properties.pad_variant or properties.variant or "auto"
    self.enabled = properties.enabled ~= false
    self.distance = tonumber(properties.distance) or 240
    self.target = properties.target or properties.marker
    self.target_x = tonumber(properties.target_x)
    self.target_y = tonumber(properties.target_y)
    self.target_z = tonumber(properties.target_z)
    self.duration = math.max(tonumber(properties.duration) or 0.75, 1 / 30)
    self.apex_height = tonumber(properties.apex_height)

    self.force_x = tonumber(properties.force_x)
    self.force_y = tonumber(properties.force_y)
    self.force_z = tonumber(properties.force_z) or 12
    self.force_speed = tonumber(properties.force_speed) or 8
    self.hold_time = tonumber(properties.hold_time)
    self.center_time = math.max(tonumber(properties.center_time) or 0.1, 0)
    self.capture_offset_x = tonumber(properties.capture_offset_x) or 0
    self.capture_offset_y = tonumber(properties.capture_offset_y) or 5
    self.lock_flight = properties.lock_flight
    self.cooldown_time = math.max(tonumber(properties.cooldown) or 0.4, 0)
    self.launch_sound = properties.launch_sound == false and nil
        or properties.launch_sound or "ventlaunch"
    self.idle_steam = properties.idle_steam ~= false
    self.steam_interval = math.max(tonumber(properties.steam_interval) or 10 / 30, 1 / 30)

    self.capture = nil
    self.busy = false
    self.cooldown_timer = 0
    self.steam_timer = 0
    self.burst_steam = 0

    self.sprite_variant = self:getSpriteVariant()
    self:setSprite("world/events/ventlauncher/" .. self.sprite_variant, 4 / 30)
end

function LaunchVent:getDebugInfo()
    local info = super.getDebugInfo(self)
    table.insert(info, "Mode: " .. self.mode)
    table.insert(info, "Direction: " .. self.direction)
    table.insert(info, "Pad variant: " .. self.sprite_variant)
    table.insert(info, "Busy: " .. tostring(self.busy))
    return info
end

function LaunchVent:getDirectionVector()
    local direction = DIRECTIONS[self.direction] or DIRECTIONS.right
    return direction[1], direction[2], direction[3]
end

function LaunchVent:getForceVector()
    local direction_x, direction_y = self:getDirectionVector()
    return self.force_x ~= nil and self.force_x or direction_x * self.force_speed,
        self.force_y ~= nil and self.force_y or direction_y * self.force_speed,
        self.force_z
end

--- Whether this vent is intentionally directionless. Auto mode uses the
--- neutral pad only for a static-force launch with no horizontal component.
function LaunchVent:wantsUniversalPad()
    if self.pad_variant == "universal" then return true end
    if self.pad_variant == "directional" then return false end
    if self.mode ~= "force" then return false end
    local force_x, force_y = self:getForceVector()
    return math.abs(force_x) < 0.001 and math.abs(force_y) < 0.001
end

function LaunchVent:getSpriteVariant()
    if self:wantsUniversalPad() then
        local universal = "world/events/ventlauncher/universal"
        -- The neutral art may be supplied by a mod. Fall back safely for
        -- projects which only have the original directional reference art.
        if Assets.getFramesOrTexture(universal) then return "universal" end
    end
    return self.direction
end

function LaunchVent:spawnSteam(speed)
    if not self.world then return end
    local _, _, angle = self:getDirectionVector()
    if self.sprite_variant == "universal" then angle = -math.pi / 2 end
    local spread = math.rad(love.math.random(-18, 18))
    local steam = VentSteam(
        self.x + self.width / 2,
        self.y + self.height / 2,
        self.z,
        angle + spread,
        speed)
    steam.ground_surface = self.ground_surface
    self.world:spawnObject(steam, self.layer + 0.1)
end

function LaunchVent:resolveTarget(player)
    local target_x, target_y, marker
    if self.target ~= nil then
        target_x, target_y, marker = self.world.map:getMarker(self.target)
    end
    target_x = self.target_x or target_x
    target_y = self.target_y or target_y
    if target_x == nil or target_y == nil then
        local direction_x, direction_y = self:getDirectionVector()
        target_x = self.x + self.width / 2 + direction_x * self.distance
        target_y = self.y + self.height / 2 + self.capture_offset_y
            + direction_y * self.distance
    end

    local target_z = self.target_z
    if target_z == nil and marker and marker.properties then
        target_z = tonumber(marker.properties.z)
    end
    if target_z == nil then
        local probe = PointCollider(nil, target_x, target_y)
        target_z = self.world:getGroundZAt(probe, math.huge)
    end
    return target_x, target_y, target_z or player.z
end

function LaunchVent:releaseCaptureLock()
    local capture = self.capture
    if capture then
        Game.lock_movement = capture.previous_movement_lock
    end
end

function LaunchVent:finishCapture(player)
    local capture = self.capture
    if not capture or capture.player ~= player then return end
    local previous_lock = capture.previous_movement_lock
    self.capture = nil
    Game.lock_movement = previous_lock

    local lock_flight = self.lock_flight
    if lock_flight == nil then lock_flight = self.mode == "target" end
    local options = {
        lock_movement = lock_flight,
        jump_sound = false,
        on_finish = function(_, landed)
            self.busy = false
            if not landed then self.cooldown_timer = math.max(self.cooldown_timer, 0.1) end
        end
    }

    local launched
    if self.mode == "force" then
        local force_x, force_y, force_z = self:getForceVector()
        launched = player:launchXYZ(force_x, force_y, force_z, options)
    else
        local target_x, target_y, target_z = self:resolveTarget(player)
        options.duration = self.duration
        options.apex_height = self.apex_height
        launched = player:launchToXYZ(target_x, target_y, target_z, options)
    end

    if not launched then
        self.busy = false
        Game.lock_movement = previous_lock
        return
    end
    if self.launch_sound then Assets.playSound(self.launch_sound) end
    self.burst_steam = 14
end

function LaunchVent:beginCapture(player)
    self.busy = true
    self.cooldown_timer = self.cooldown_time
    if self.sprite_variant ~= "universal" then
        player:setFacing(self.direction)
    end

    local ground_z, ground, surface = self.world:getGroundZAt(
        player.support_collider, player.z + 0.75, player.collider)
    ground_z = ground_z or player.z
    if ground_z then
        player.z = ground_z
        player.ground_z = ground_z
        player.ground_collider = ground
        player.ground_surface = surface
        player.airborne_surface = nil
        player.z_velocity = 0
        player.platform_momentum_x = 0
        player.platform_momentum_y = 0
        player.height_state_manager:setState("GROUNDED")
        player:restoreGroundAnimation()
    end

    local hold_time = self.hold_time
    if hold_time == nil then hold_time = self.mode == "target" and 0.3 or 0 end
    hold_time = math.max(hold_time, 0)
    if hold_time > 0 then hold_time = math.max(hold_time, self.center_time) end
    self.capture = {
        player = player,
        elapsed = 0,
        duration = hold_time,
        start_x = player.x,
        start_y = player.y,
        z = player.z,
        target_x = self.x + self.width / 2 + self.capture_offset_x,
        target_y = self.y + self.height / 2 + self.capture_offset_y,
        previous_movement_lock = Game.lock_movement
    }
    Game.lock_movement = true
    if hold_time <= 0 then self:finishCapture(player) end
end

function LaunchVent:onEnter(player)
    if not self.enabled or self.busy or self.cooldown_timer > 0 then return end
    if player ~= self.world.player or not player:isPlatformingEnabled()
        or player:isPitRecovering() or player:isClimbing() then return end
    self:beginCapture(player)
end

function LaunchVent:updateCapture()
    local capture = self.capture
    if not capture then return end
    local player = capture.player
    if not player or not player.parent or player:isPitRecovering() then
        self:releaseCaptureLock()
        self.capture = nil
        self.busy = false
        return
    end

    capture.elapsed = math.min(capture.elapsed + DT, capture.duration)
    local center_progress = self.center_time <= 0 and 1
        or MathUtils.clamp(capture.elapsed / self.center_time, 0, 1)
    player:setPosition(
        Utils.ease(capture.start_x, capture.target_x, center_progress, "out-quad"),
        Utils.ease(capture.start_y, capture.target_y, center_progress, "out-quad"))
    player.z = capture.z
    player.z_velocity = 0
    player.platform_momentum_x = 0
    player.platform_momentum_y = 0
    Object.uncache(player)

    if capture.elapsed >= capture.duration then
        self:finishCapture(player)
    end
end

function LaunchVent:update()
    self.cooldown_timer = math.max(self.cooldown_timer - DT, 0)
    self:updateCapture()

    self.steam_timer = self.steam_timer + DT
    if self.idle_steam and not self.busy and self.steam_timer >= self.steam_interval then
        self.steam_timer = self.steam_timer % self.steam_interval
        self:spawnSteam(6)
    end
    if self.burst_steam > 0 then
        self:spawnSteam(12 + love.math.random() * 4)
        self.burst_steam = self.burst_steam - DTMULT
    end
    super.update(self)
end

function LaunchVent:onRemove(parent)
    self:releaseCaptureLock()
    self.capture = nil
    super.onRemove(self, parent)
end

return LaunchVent
