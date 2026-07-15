local TwistedSpiral, super = Class(Wave)

function TwistedSpiral:init()
    super.init(self)

    self.time = 12
    -- self.arena_x = 350
    -- self.arena_y = 178
    -- self.arena_width = 220
    -- self.arena_height = 180
    -- self.soul_start_x = self.arena_x
    -- self.soul_start_y = self.arena_y
    self.ring_index = 0
    self.impacted_rings = {}
    self.gap_start = MathUtils.randomInt(0, 8)
    self.gap_step = TableUtils.pick({3, 5})
    self.angle_seed = MathUtils.random(0, math.pi * 2)
    self.orbit_start = TableUtils.pick({-1, 1})
end

function TwistedSpiral:onAgonyRingImpact(ring_id)
    if self.impacted_rings[ring_id] then return end

    self.impacted_rings[ring_id] = true
    Assets.playSound("impact", 0.34, MathUtils.random(1.15, 1.4))
end

function TwistedSpiral:getSpawnRadius(target_x, target_y)
    local arena = Game.battle.arena
    local horizontal = math.max(
        math.abs(target_x - arena:getLeft()),
        math.abs(target_x - arena:getRight())
    )
    local vertical = math.max(
        math.abs(target_y - arena:getTop()),
        math.abs(target_y - arena:getBottom())
    )
    return math.sqrt(horizontal * horizontal + vertical * vertical) + 30
end

function TwistedSpiral:spawnRing()
    self.ring_index = self.ring_index + 1

    local arena = Game.battle.arena
    local target_x, target_y = arena:getCenter()
    if Game.battle.soul then
        target_x = MathUtils.clamp(Game.battle.soul.x, arena:getLeft() + 34, arena:getRight() - 34)
        target_y = MathUtils.clamp(Game.battle.soul.y, arena:getTop() + 34, arena:getBottom() - 34)
    end

    local slots = 8
    local gap = (self.gap_start + (self.ring_index - 1) * self.gap_step) % slots
    local angle_offset = self.angle_seed + self.ring_index * 0.31 + MathUtils.random(-0.07, 0.07)
    local orbit_direction = self.orbit_start * (self.ring_index % 2 == 0 and -1 or 1)
    local radius = self:getSpawnRadius(target_x, target_y)
    local radial_speed = radius / MathUtils.random(38, 42)

    Assets.playSound("noise", 0.38, MathUtils.random(0.72, 1.12))
    self:spawnObject(AgonyMarker(target_x, target_y, orbit_direction))

    for slot = 0, slots - 1 do
        if slot ~= gap and slot ~= ((gap + 1) % slots) then
            local angle = angle_offset + (slot / slots) * math.pi * 2
            local size = MathUtils.random(18, 27)
            local bullet = self:spawnBullet(
                "agonysquare",
                target_x,
                target_y,
                angle,
                radius,
                size,
                radial_speed,
                0.009 * orbit_direction
            )
            bullet.ring_id = self.ring_index
            bullet.slot_index = slot
        end
    end
end

function TwistedSpiral:onStart()
    self.timer:script(function(wait)
        wait(0.2)
        local ring_count = 11
        for ring = 1, ring_count do
            self:spawnRing()
            if ring < ring_count then
                -- Leave the opening rings readable, then collapse the delay
                -- aggressively enough for several rings to overlap near the
                -- end. Give the player one recovery beat before the finale:
                -- its opening can rotate nearly opposite the preceding one,
                -- making the minimum cadence impossible to cross reliably.
                if ring == ring_count - 1 then
                    wait(0.78)
                else
                    local ramp = (ring - 1) / (ring_count - 2)
                    wait(MathUtils.lerp(1.45, 0.42, ramp ^ 1.55))
                end
            end
        end
    end)
end

return TwistedSpiral
