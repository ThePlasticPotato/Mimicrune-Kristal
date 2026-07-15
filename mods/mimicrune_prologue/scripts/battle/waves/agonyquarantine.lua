local AgonyQuarantine, super = Class(Wave)

function AgonyQuarantine:init()
    super.init(self)
    self.time = 8.5
end

function AgonyQuarantine:buildFloodSequence()
    local directions = TableUtils.shuffle({"down", "left", "up", "right"})
    local floods = {}

    for _, direction in ipairs(directions) do
        table.insert(floods, {direction, TableUtils.pick({-1, 1})})
    end

    table.insert(floods, {floods[1][1], -floods[1][2]})
    return floods
end

function AgonyQuarantine:getFloodArea(direction, section_side)
    local arena = Game.battle.arena
    local center_x, center_y = arena:getCenter()
    local vertical_travel = direction == "down" or direction == "up"
    local width = vertical_travel and arena.width * 0.6 or arena.width
    local height = vertical_travel and arena.height or arena.height * 0.6

    if vertical_travel then
        if section_side < 0 then
            center_x = arena:getLeft() + width / 2
        else
            center_x = arena:getRight() - width / 2
        end
    else
        if section_side < 0 then
            center_y = arena:getTop() + height / 2
        else
            center_y = arena:getBottom() - height / 2
        end
    end

    return center_x, center_y, width, height, vertical_travel
end

function AgonyQuarantine:warnFlood(direction, section_side, pitch, duration)
    local x, y, width, height = self:getFloodArea(direction, section_side)
    self:spawnObject(AgonyZoneWarning(x, y, width, height, duration))
    Assets.playSound("noise", 0.42, pitch)
end

function AgonyQuarantine:spawnFlood(direction, section_side, pitch, speed)
    local arena = Game.battle.arena
    local center_x, center_y, width, height, vertical_travel =
        self:getFloodArea(direction, section_side)
    local angle, x, y, exit_coordinate, axis_length
    local depth = 92

    if direction == "down" then
        angle = math.pi / 2
        x, y = center_x, -depth / 2 - 18
        exit_coordinate = SCREEN_HEIGHT + depth / 2 + 18
        axis_length = width - 18
    elseif direction == "up" then
        angle = -math.pi / 2
        x, y = center_x, SCREEN_HEIGHT + depth / 2 + 18
        exit_coordinate = -depth / 2 - 18
        axis_length = width - 18
    elseif direction == "right" then
        angle = 0
        x, y = -depth / 2 - 18, center_y
        exit_coordinate = SCREEN_WIDTH + depth / 2 + 18
        axis_length = height - 18
    else
        angle = math.pi
        x, y = SCREEN_WIDTH + depth / 2 + 18, center_y
        exit_coordinate = -depth / 2 - 18
        axis_length = height - 18
    end

    self:spawnBullet(
        "agonyquarantinemass",
        x,
        y,
        angle,
        speed,
        axis_length,
        depth,
        exit_coordinate
    )

    Assets.playSound("swooshby", 0.68, pitch)
    Assets.playSound("agonyroar", 0.22, pitch * 0.82)
    Assets.playSound("impact", 0.28, pitch * 1.08)
    Game.battle:shakeCamera(3, vertical_travel and 2 or 1)
end

function AgonyQuarantine:onStart()
    self.timer:script(function(wait)
        wait(0.3)

        self.floods = self:buildFloodSequence()

        for index, flood in ipairs(self.floods) do
            local direction, section_side = flood[1], flood[2]
            local ramp = (index - 1) / (#self.floods - 1)
            local pitch = 0.78 + index * 0.055
            local warning_time = MathUtils.lerp(0.48, 0.28, ramp)
            local recovery_time = MathUtils.lerp(1.15, 0.68, ramp)
            local speed = MathUtils.lerp(20, 32, ramp)

            self:warnFlood(direction, section_side, pitch, warning_time)
            wait(warning_time * 0.56)
            Assets.playSound("noise", 0.25, pitch + 0.16)
            wait(warning_time * 0.44)
            self:spawnFlood(direction, section_side, pitch, speed)

            if index < #self.floods then
                wait(recovery_time)
            end
        end
    end)
end

return AgonyQuarantine
