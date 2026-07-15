local AgonyBrood, super = Class(Wave)

function AgonyBrood:init()
    super.init(self)
    self.time = 9.5
end

function AgonyBrood:spawnWorm(x, y, segments)
    local soul = Game.battle.soul
    local direction = MathUtils.angle(x, y, soul.x, soul.y)
    local head = self:spawnBullet(
        "agonyinfestation",
        x,
        y,
        direction,
        5,
        "head",
        soul,
        nil
    )
    local previous = head

    for _ = 1, segments do
        previous = self:spawnBullet(
            "agonyinfestation",
            x,
            y,
            direction,
            5,
            "body",
            soul,
            previous
        )
    end

    self:spawnBullet(
        "agonyinfestation",
        x,
        y,
        direction,
        5,
        "tail",
        soul,
        previous
    )
end

function AgonyBrood:buildSpawnSequence()
    local arena = Game.battle.arena
    local center_x = select(1, arena:getCenter())
    local mirror = TableUtils.pick({-1, 1})
    return TableUtils.shuffle({
        {arena:getLeft() - 34, mirror < 0 and arena:getTop() + 26 or arena:getBottom() - 26},
        {arena:getRight() + 34, mirror < 0 and arena:getBottom() - 24 or arena:getTop() + 24},
        {center_x + 18 * mirror, arena:getTop() - 34},
        {center_x - 20 * mirror, arena:getBottom() + 34},
        {arena:getLeft() - 34, mirror < 0 and arena:getTop() + 26 or arena:getBottom() - 26},
        {arena:getRight() + 34, mirror < 0 and arena:getBottom() - 24 or arena:getTop() + 24},
        {center_x + 18 * mirror, arena:getTop() - 34},
        {center_x - 20 * mirror, arena:getBottom() + 34},
    })
end

function AgonyBrood:onStart()
    self.timer:script(function(wait)
        wait(0.45)

        self.spawns = self:buildSpawnSequence()

        for index, spawn in ipairs(self.spawns) do
            Assets.playSound("noise", 0.34, 0.72 + index * 0.11)
            self:spawnObject(AgonyZoneWarning(spawn[1], spawn[2], 34, 34, 0.35))
            self:spawnWorm(spawn[1], spawn[2], 1)
            if index == 1 then
                wait(0.75)
            elseif index < #self.spawns then
                wait(math.max(1 - (0.15*index), 0.1))
            end
        end
    end)
end

return AgonyBrood
