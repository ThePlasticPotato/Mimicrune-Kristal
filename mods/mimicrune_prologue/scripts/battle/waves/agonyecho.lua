local AgonyEcho, super = Class(Wave)

function AgonyEcho:init()
    super.init(self)
    self.time = 11
    self.orbit_direction = TableUtils.pick({-1, 1})
    self.angle_offset = MathUtils.random(0, math.pi * 2)
end

function AgonyEcho:lockPosition(direction, burst_index, warning_time)
    local arena = Game.battle.arena
    local soul = Game.battle.soul
    local x = MathUtils.clamp(soul.x, arena:getLeft() + 22, arena:getRight() - 22)
    local y = MathUtils.clamp(soul.y, arena:getTop() + 22, arena:getBottom() - 22)

    self:spawnObject(AgonyMarker(x, y, direction))
    self:spawnObject(AgonyZoneWarning(x, y, 42, 42, warning_time))
    local pitch = 0.78 + burst_index * 0.065
    Assets.playSound("noise", 0.32, pitch)
    Assets.playSound(burst_index % 2 == 0 and "intercept_short_2" or "intercept_short_1", 0.2, pitch)
    Assets.playSound("agonyroar", 0.14, pitch * 0.86)
    return x, y
end

function AgonyEcho:detonate(x, y, burst_index)
    local soul = Game.battle.soul
    local escape_angle = MathUtils.angle(x, y, soul.x, soul.y)
    local count = 18 + burst_index

    Assets.playSound("impact", 0.62, 0.9 + burst_index * 0.04)
    Assets.playSound("agonyscreech", 0.3, 0.82 + burst_index * 0.055)
    Assets.playSound("breakdownnoise_twisted", 0.14, 0.9 + burst_index * 0.035)
    Assets.playSound("icky", 0.22, 0.92 + burst_index * 0.04)
    Game.battle:shakeCamera(2.5 + burst_index * 0.3, 2)
    for slot = 0, count - 1 do
        local angle = self.angle_offset + (slot / count) * math.pi * 2 + burst_index * 0.17
        if math.abs(MathUtils.angleDiff(angle, escape_angle)) > 0.38 then
            local bullet = self:spawnBullet(
                "agonyblob",
                x,
                y,
                angle,
                7.5 + burst_index * 0.65
            )
            bullet.remove_offscreen = false
        end
    end
end

function AgonyEcho:onStart()
    self.timer:script(function(wait)
        wait(0.35)

        local bursts = 6
        for burst = 1, bursts do
            local ramp = (burst - 1) / (bursts - 1)
            local warning_time = MathUtils.lerp(0.78, 0.38, ramp)
            local recovery_time = MathUtils.lerp(1.25, 0.55, ramp)
            local x, y = self:lockPosition(
                burst % 2 == 0 and -self.orbit_direction or self.orbit_direction,
                burst,
                warning_time
            )
            wait(warning_time)
            self:detonate(x, y, burst)
            if burst < bursts then
                wait(recovery_time)
            end
        end
    end)
end

return AgonyEcho
