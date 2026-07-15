local AgonyUndertow, super = Class(Wave)

function AgonyUndertow:init()
    super.init(self)
    self.time = 11
    self.gap_phase = MathUtils.random(0, math.pi * 2)
    self.gap_direction = TableUtils.pick({-1, 1})
end

function AgonyUndertow:buildSideSequence()
    local group_patterns = {
        {5, 5, 5},
        {4, 4, 4, 3},
        {3, 5, 4, 3},
        {4, 3, 5, 3},
    }
    local groups = TableUtils.pick(group_patterns)
    local side = TableUtils.pick({-1, 1})
    local sides = {}

    for _, length in ipairs(groups) do
        for _ = 1, length do
            table.insert(sides, side)
        end
        side = -side
    end
    return sides
end

function AgonyUndertow:getCurrentRows(gap_y)
    local arena = Game.battle.arena
    local rows = {}
    local top = arena:getTop() + 5
    local bottom = arena:getBottom() - 5
    local row_count = math.max(2, math.ceil((bottom - top) / 12) + 1)

    for index = 1, row_count do
        local y = MathUtils.lerp(top, bottom, (index - 1) / (row_count - 1))
        if math.abs(y - gap_y) > 22 then
            table.insert(rows, y)
        end
    end

    return rows
end

function AgonyUndertow:telegraphCurrent(rows)
    local arena = Game.battle.arena
    local center_x = select(1, arena:getCenter())

    for _, y in ipairs(rows) do
        self:spawnObject(AgonyZoneWarning(
            center_x,
            y,
            arena.width,
            7,
            0.24
        ))
    end
end

function AgonyUndertow:fireCurrent(side, rows)
    local arena = Game.battle.arena
    local x = side < 0 and (arena:getLeft() - 12) or (arena:getRight() + 12)
    local exit_x = side < 0 and (arena:getRight() + 2) or (arena:getLeft() - 2)
    local direction = side < 0 and 0 or math.pi

    Assets.playSound("bigcut", 0.48, side < 0 and 0.92 or 1.04)
    Game.battle:shakeCamera(3, 1)
    for _, y in ipairs(rows) do
        self:spawnBullet("agonyundertowblob", x, y, direction, 21, exit_x)
    end
end

function AgonyUndertow:onStart()
    self.timer:script(function(wait)
        wait(0.35)

        local volleys = 15
        self.sides = self:buildSideSequence()
        for volley = 1, volleys do
            local arena = Game.battle.arena
            local _, center_y = arena:getCenter()
            local travel = arena.height / 2 - 28
            local phase = self.gap_phase
                + ((volley - 1) / (volleys - 1)) * math.pi * 2.4 * self.gap_direction
            local gap_y = center_y + math.sin(phase) * travel
            local side = self.sides[volley]
            local rows = self:getCurrentRows(gap_y)

            self:telegraphCurrent(rows)
            wait(0.24)
            self:fireCurrent(side, rows)
            if volley < volleys then
                wait(0.4)
            end
        end
    end)
end

return AgonyUndertow
