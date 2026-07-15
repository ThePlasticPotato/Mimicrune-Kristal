local AgonyImpact, super = Class(Wave)

function AgonyImpact:init()
    super.init(self)
    self.time = 12
    self.arena_start_x = nil
    self.arena_start_y = nil
    self.arena_offset_x = 0
    self.arena_offset_y = 0
end

function AgonyImpact:buildSlamSequence()
    local directions = {
        {-1, 0},
        {1, 0},
        {0, -1},
        {0, 1},
    }
    local slams = TableUtils.shuffle(directions)
    local extras = TableUtils.shuffle(directions)
    
    if extras[1][1] == slams[#slams][1] and extras[1][2] == slams[#slams][2] then
        extras[1], extras[2] = extras[2], extras[1]
    end
    table.insert(slams, extras[1])
    table.insert(slams, extras[2])
    return slams
end

function AgonyImpact:getSafeCoordinate(side_x, side_y, slam_index)
    local arena = Game.battle.arena
    local soul = Game.battle.soul
    local biases = {-18, 18, -20, 20, -12, 12}
    local bias = biases[slam_index] or 0
    if side_x ~= 0 then
        return MathUtils.clamp(soul.y + bias, arena:getTop() + 24, arena:getBottom() - 24)
    end
    return MathUtils.clamp(soul.x + bias, arena:getLeft() + 24, arena:getRight() - 24)
end

function AgonyImpact:spawnWarningRegion(x, y, width, height, duration)
    if width <= 1 or height <= 1 then return end
    self:spawnObject(AgonyZoneWarning(x, y, width, height, duration))
end

function AgonyImpact:telegraphSlam(side_x, side_y, safe_coordinate, duration, pitch)
    local arena = Game.battle.arena
    local center_x, center_y = arena:getCenter()
    local gap_radius = 18

    if side_x ~= 0 then
        local upper_height = safe_coordinate - gap_radius - arena:getTop()
        local lower_top = safe_coordinate + gap_radius
        local lower_height = arena:getBottom() - lower_top
        self:spawnWarningRegion(
            center_x,
            arena:getTop() + upper_height / 2,
            arena.width,
            upper_height,
            duration
        )
        self:spawnWarningRegion(
            center_x,
            lower_top + lower_height / 2,
            arena.width,
            lower_height,
            duration
        )
    else
        local left_width = safe_coordinate - gap_radius - arena:getLeft()
        local right_left = safe_coordinate + gap_radius
        local right_width = arena:getRight() - right_left
        self:spawnWarningRegion(
            arena:getLeft() + left_width / 2,
            center_y,
            left_width,
            arena.height,
            duration
        )
        self:spawnWarningRegion(
            right_left + right_width / 2,
            center_y,
            right_width,
            arena.height,
            duration
        )
    end

    Assets.playSound("noise", 0.42, pitch)
end

function AgonyImpact:spawnWall(side_x, side_y, safe_coordinate, speed, slam_index)
    local arena = Game.battle.arena
    local center_x, center_y = arena:getCenter()
    local depth = 48
    local direction, x, y, contact_coordinate, exit_coordinate, axis_length, gap_offset

    if side_x < 0 then
        direction = 0
        contact_coordinate = arena:getLeft() - depth / 2
        exit_coordinate = arena:getRight() + depth / 2 + 6
        x, y = contact_coordinate - 18, center_y
        axis_length = arena.height
        gap_offset = safe_coordinate - center_y
    elseif side_x > 0 then
        direction = math.pi
        contact_coordinate = arena:getRight() + depth / 2
        exit_coordinate = arena:getLeft() - depth / 2 - 6
        x, y = contact_coordinate + 18, center_y
        axis_length = arena.height
        gap_offset = safe_coordinate - center_y
    elseif side_y < 0 then
        direction = math.pi / 2
        contact_coordinate = arena:getTop() - depth / 2
        exit_coordinate = arena:getBottom() + depth / 2 + 6
        x, y = center_x, contact_coordinate - 18
        axis_length = arena.width
        gap_offset = safe_coordinate - center_x
    else
        direction = -math.pi / 2
        contact_coordinate = arena:getBottom() + depth / 2
        exit_coordinate = arena:getTop() - depth / 2 - 6
        x, y = center_x, contact_coordinate + 18
        axis_length = arena.width
        gap_offset = safe_coordinate - center_x
    end

    local wall = self:spawnBullet(
        "agonyimpactwall",
        x,
        y,
        direction,
        speed,
        axis_length,
        gap_offset,
        36,
        contact_coordinate,
        exit_coordinate,
        side_x,
        side_y,
        slam_index
    )
    wall.push_distance = 32 + slam_index * 4
    wall.push_duration = MathUtils.lerp(0.22, 0.11, (slam_index - 1) / 5)
    wall.safe_coordinate = safe_coordinate
end

function AgonyImpact:onImpactWallLaunch(wall)
    Assets.playSound("swooshby", 0.58, 0.78 + wall.slam_index * 0.055)
    Assets.playSound("greatslash", 0.22, 0.82 + wall.slam_index * 0.045)
end

function AgonyImpact:spawnImpactDebris(wall)
    local arena = Game.battle.arena
    local direction = wall.physics.direction
    local debris_speed = 8.5 + wall.slam_index * 0.7

    if wall.side_x ~= 0 then
        local x = wall.side_x < 0 and arena:getLeft() or arena:getRight()
        local debris_index = 0
        for y = arena:getTop() + 12, arena:getBottom() - 12, 22 do
            if math.abs(y - wall.safe_coordinate) > 20 then
                debris_index = debris_index + 1
                local angle = direction + (debris_index % 2 == 0 and 0.13 or -0.13)
                local bullet = self:spawnBullet("agonyblob", x, y, angle, debris_speed)
                bullet.remove_offscreen = false
            end
        end
    else
        local y = wall.side_y < 0 and arena:getTop() or arena:getBottom()
        local debris_index = 0
        for x = arena:getLeft() + 12, arena:getRight() - 12, 22 do
            if math.abs(x - wall.safe_coordinate) > 20 then
                debris_index = debris_index + 1
                local angle = direction + (debris_index % 2 == 0 and 0.13 or -0.13)
                local bullet = self:spawnBullet("agonyblob", x, y, angle, debris_speed)
                bullet.remove_offscreen = false
            end
        end
    end
end

function AgonyImpact:onImpactWallContact(wall)
    local target = {}
    if wall.side_x ~= 0 then
        target.arena_offset_x = -wall.side_x * wall.push_distance
    else
        target.arena_offset_y = -wall.side_y * wall.push_distance
    end
    self.timer:tween(wall.push_duration, self, target, "out-quad")
    self:spawnImpactDebris(wall)

    local power = 4 + wall.slam_index * 0.65
    Game.battle.arena:shake(-wall.side_x * power, -wall.side_y * power, 1)
    Game.battle:shakeCamera(
        wall.side_x ~= 0 and power or 2,
        wall.side_y ~= 0 and power or 2,
        1
    )
    Assets.playSound("impact", 0.68, 0.76 + wall.slam_index * 0.05)
    Assets.playSound("bigcut", 0.34, 0.86 + wall.slam_index * 0.045)
    Assets.playSound("agonyroar", 0.16, 0.7 + wall.slam_index * 0.035)
end

function AgonyImpact:onStart()
    self.arena_start_x = Game.battle.arena.x
    self.arena_start_y = Game.battle.arena.y

    self.timer:script(function(wait)
        wait(0.3)

        self.slams = self:buildSlamSequence()

        for index, side in ipairs(self.slams) do
            local ramp = (index - 1) / (#self.slams - 1)
            local warning_time = MathUtils.lerp(0.72, 0.36, ramp)
            local recovery_time = MathUtils.lerp(1.25, 0.62, ramp)
            local speed = MathUtils.lerp(9.5, 19, ramp)
            local safe_coordinate = self:getSafeCoordinate(side[1], side[2], index)
            local pitch = 0.7 + index * 0.055

            self:telegraphSlam(side[1], side[2], safe_coordinate, warning_time, pitch)
            wait(warning_time * 0.58)
            Assets.playSound("noise", 0.24, pitch + 0.18)
            wait(warning_time * 0.42)
            self:spawnWall(side[1], side[2], safe_coordinate, speed, index)

            if index < #self.slams then
                wait(recovery_time)
            end
        end

        wait(0.55)
        self.timer:tween(0.4, self, {
            arena_offset_x = 0,
            arena_offset_y = 0,
        }, "out-sine")
    end)
end

function AgonyImpact:update()
    super.update(self)

    local arena = Game.battle.arena
    if not arena or not self.arena_start_x then return end

    local target_x = self.arena_start_x + self.arena_offset_x
    local target_y = self.arena_start_y + self.arena_offset_y
    local movement_x = target_x - arena.x
    local movement_y = target_y - arena.y
    if movement_x ~= 0 or movement_y ~= 0 then
        arena:setPosition(target_x, target_y)
    end
end

function AgonyImpact:beforeEnd()
    local arena = Game.battle.arena
    if arena and self.arena_start_x then
        arena:setPosition(self.arena_start_x, self.arena_start_y)
    end
end

return AgonyImpact
