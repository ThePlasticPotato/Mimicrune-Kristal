---@class AgonyInfestation : Bullet
---@field child_part AgonyInfestation
local AgonyInfestation, super = Class(Bullet)

---@alias BodyPart
---| "head"
---| "body"
---| "tail"

---@param x number
---@param y number
---@param dir number
---@param speed number
---@param bodypart BodyPart
---@param target Soul|Object
---@param parent AgonyInfestation
function AgonyInfestation:init(x, y, dir, speed, bodypart, target, parent)
    -- Last argument = sprite path
    super.init(self, x, y, "bullets/agonyinfestation_"..bodypart)

    if parent then 
        speed = parent.physics.speed
        dir = MathUtils.angle(self.x, self.y, parent.x, parent.y)
        parent.child_part = self
    else
        speed = speed or 0
        dir = dir or 0
    end

    -- Move the bullet in dir radians (0 = right, pi = left, clockwise rotation)
    self.physics.match_rotation = true
    self.rotation = dir
    -- Speed the bullet moves (pixels per frame at 30FPS)
    self.physics.speed = speed
    self.target_speed = speed

    self.owner_part = parent
    self.child_part = nil
    
    self.target = target

    self.should_turn = false

    self.remove_offscreen = false
    self.destroy_on_hit = false
    --self.damage = self.damage * 2

    self.run_state = "ACQUIRE"  -- ACQUIRE -> COMMIT -> PASS -> RECOVER
    self.run_target_x = nil
    self.run_target_y = nil

    self.run_side = (MathUtils.random() < 0.5) and -1 or 1 -- pick left/right initial bias
    self.commit_timer = 0
    self.pass_timer = 0

    self.commit_dist = 60     -- start committing when within this range
    self.pass_dist   = 10      -- consider it a "pass" if you get this close
    self.reacquire_dist = 80  -- only pick a new run after you're out again

    self.still_ticker = 0
    self.run_locked_x, self.run_locked_y = nil, nil
    self.run_phase = "TO_LOCK"     -- "TO_LOCK" or "THROUGH"
    self.lock_corridor = 22        -- how close we force it to go to the locked point (tune)
    self.still_threshold = 2       -- seconds (you already use 2)

    self.parry = bodypart == "head"
    self.deflect_timer = 0     -- seconds remaining
    self.deflect_time = 0.35   -- how long it stays knocked away
    self.deflect_speed = 22    -- speed during deflect
end

function AgonyInfestation:updateOld()
    super.update(self)
    if self.owner_part then
        local p = self.owner_part
        local desired = 15

        local dx, dy = self.x - p.x, self.y - p.y
        local d = math.sqrt(dx*dx + dy*dy)
        if d > 0.0001 then
            local tx = p.x + (dx / d) * desired
            local ty = p.y + (dy / d) * desired

            local stiffness = 0.65
            self.x = self.x + (tx - self.x) * stiffness
            self.y = self.y + (ty - self.y) * stiffness

            self.rotation = MathUtils.angle(self.x, self.y, p.x, p.y)
        end

        self.physics.speed = 0
        return
    end

    local angle_diff = MathUtils.angleDiff(self.rotation, MathUtils.angle(self.x, self.y, self.target.x, self.target.y))
    local gradient = math.abs(angle_diff) / math.pi
    self.target_speed = 16 * math.max(1-gradient, 0.1)
    local divisor = (self.physics.speed < self.target_speed) and 1 or 6
    self.physics.speed = MathUtils.approach(self.physics.speed, self.target_speed, DTMULT / divisor)
    if (self.should_turn) then self.rotation = MathUtils.approachAngle(self.rotation, MathUtils.angle(self.x, self.y, self.target.x, self.target.y), DTMULT / 8) end
end

function AgonyInfestation:update()
    super.update(self)
    if self.owner_part then
        local p = self.owner_part
        local desired = 15

        local dx, dy = self.x - p.x, self.y - p.y
        local d = math.sqrt(dx*dx + dy*dy)
        if d > 0.0001 then
            local tx = p.x + (dx / d) * desired
            local ty = p.y + (dy / d) * desired

            local stiffness = 0.65
            self.x = self.x + (tx - self.x) * stiffness
            self.y = self.y + (ty - self.y) * stiffness

            self.rotation = MathUtils.angle(self.x, self.y, p.x, p.y)
        end

        self.physics.speed = 0
        return
    end

    -- Knockback/deflect behavior (head only)
    if self.deflect_timer and self.deflect_timer > 0 then
        self.deflect_timer = self.deflect_timer - DT

        -- fly on current rotation; don't steer or pick runs
        self.target_speed = self.deflect_speed
        self.physics.speed = MathUtils.approach(self.physics.speed, self.target_speed, DTMULT)

        -- optional: after deflect ends, force a clean re-acquire
        if self.deflect_timer <= 0 then
            self.run_state = "ACQUIRE"
        end
        return
    end

    if (self.target.moving_x == 0 and self.target.moving_y == 0) then
        self.still_ticker = self.still_ticker + DT
    else
        self.still_ticker = 0
    end

    -- ===== HEAD =====
    local tx, ty = self.target.x, self.target.y
    local dist = MathUtils.dist(self.x, self.y, tx, ty)

    -- vector to target
    local dx, dy = tx - self.x, ty - self.y
    local d = math.sqrt(dx*dx + dy*dy)
    if d < 0.0001 then d = 0.0001 end
    local nx, ny = dx / d, dy / d

    -- perpendicular (for "swoop side" offset)
    local px, py = -ny, nx

    -- Helper to set a run target with a lateral offset
    -- local function pickRunPoint()
    --     -- Aim a bit PAST the player, not at them
    --     local overshoot = 40 + math.random() * 80    -- how far past (tune)
    --     local lateral   = self.run_side * (40 + math.random() * 50) -- curve amount (tune)
    --     if (self.still_ticker or 0) >= 2 then

    --         self.run_target_x = tx + nx * overshoot
    --         self.run_target_y = ty + ny * overshoot
    --     return
    -- end

    --     self.run_target_x = tx + nx * overshoot + px * lateral
    --     self.run_target_y = ty + ny * overshoot + py * lateral
    -- end

    local function pickRunPoint()
        local overshoot = 80 + math.random() * 80
        local lateral   = self.run_side * (40 + math.random() * 50)

        -- lock where the player is at the moment we choose the run
        self.run_locked_x, self.run_locked_y = tx, ty

        if (self.still_ticker or 0) >= self.still_threshold then
            -- STILL MODE: guaranteed thread-the-needle run
            -- Step 1 aim AT the locked point, step 2 aim PAST it
            local ldx, ldy = self.run_locked_x - self.x, self.run_locked_y - self.y
            local ld = math.sqrt(ldx*ldx + ldy*ldy)
            if ld < 0.0001 then ld = 0.0001 end
            local lnx, lny = ldx / ld, ldy / ld

            self.run_target_x = self.run_locked_x + lnx * overshoot
            self.run_target_y = self.run_locked_y + lny * overshoot

            self.run_phase = "TO_LOCK"
            
            return
        end

        -- MOVING MODE: curved swoop
        self.run_target_x = tx + nx * overshoot + px * lateral
        self.run_target_y = ty + ny * overshoot + py * lateral

        self.run_phase = "THROUGH"
    end

    -- State transitions
    if self.run_state == "ACQUIRE" then
        pickRunPoint()
        self.commit_timer = 0
        self.run_state = "COMMIT"
        Assets.playSound("agonyroar", 0.75, MathUtils.random(0.7, 1.0))
    end

    if self.run_state == "COMMIT" then
        self.commit_timer = self.commit_timer + DTMULT

        -- once we get "close enough" we stop re-aiming and just GO through
        if dist < self.commit_dist or self.commit_timer > 35 then
            self.pass_timer = 0
            Assets.playSound("swooshby")
            self.run_state = "PASS"
        end
    end

    if self.run_state == "PASS" then
        self.pass_timer = self.pass_timer + DTMULT

        -- after a brief moment (or after we've gotten very close), we stop turning much
        -- and let it fly past; then, once we're far enough away again, reacquire.
        if (dist < self.pass_dist) then
            -- flip the side for next run so it doesn't repeat the same curve
            self.run_side = -self.run_side
            self.run_state = "RECOVER"
            Assets.playSound("agonyscreech")
        elseif self.pass_timer > 60 then
            self.run_side = -self.run_side
            self.run_state = "RECOVER"
            Assets.playSound("agonyscreech")
        end
    end

    if self.run_state == "RECOVER" then
        -- wait until we've actually separated, so we don't re-lock into an orbit
        if dist > self.reacquire_dist then
            self.run_state = "ACQUIRE"
        end
    end

    -- Steering target depends on state:
    local aim_x, aim_y = tx, ty
    if self.run_state == "COMMIT" or self.run_state == "PASS" then
        -- If we are in STILL MODE and haven't reached the locked point corridor yet,
        -- aim at the locked point first.
        if self.run_phase == "TO_LOCK" and self.run_locked_x then
            aim_x, aim_y = self.run_locked_x, self.run_locked_y

            local lock_dist = MathUtils.dist(self.x, self.y, aim_x, aim_y)
            if lock_dist <= self.lock_corridor then
                self.run_phase = "THROUGH"
            end
        else
            aim_x, aim_y = self.run_target_x, self.run_target_y
        end
    elseif self.run_state == "RECOVER" then
        aim_x, aim_y = self.run_target_x or tx, self.run_target_y or ty
    end

    local aim = MathUtils.angle(self.x, self.y, aim_x, aim_y)

    -- Turning: strong early, weak during PASS so it doesn't "lock on" near the player
    local turn_rate =
        (self.run_state == "PASS") and (DTMULT / 12) or
        (self.run_state == "COMMIT") and (DTMULT / 10) or
        (DTMULT / 8)
    -- Extra authority while threading the locked point (only in STILL MODE phase A)
    if self.run_phase == "TO_LOCK" then
        turn_rate = DTMULT / 6
    end
    self.rotation = MathUtils.approachAngle(self.rotation, aim, turn_rate)

    -- Speed: fast on run-in, stays fast through pass; slight variance helps it feel alive
    local desired_speed =
        (self.run_state == "RECOVER") and 12 or
        16

    self.target_speed = desired_speed
    local divisor = (self.physics.speed < self.target_speed) and 1 or 6
    self.physics.speed = MathUtils.approach(self.physics.speed, self.target_speed, DTMULT / divisor)
end

function AgonyInfestation:sequenceFlash()
    self.sprite:flash()
    if (self.child_part) then
        self.wave.timer:after(0.05, function () self.child_part:sequenceFlash() end)
    end
end

function AgonyInfestation:onParry(soul)
    -- Only the head can be parried/deflected
    if self.owner_part then return end

    local away = MathUtils.angle(soul.x, soul.y, self.x, self.y)

    away = away + MathUtils.random(-0.35, 0.35)

    self.rotation = away
    self.physics.speed = math.max(self.physics.speed, self.deflect_speed)

    self.deflect_timer = self.deflect_time

    self.run_state = "RECOVER"
    self.commit_timer = 0
    self.pass_timer = 0
    self.run_phase = "THROUGH"
    self.run_locked_x, self.run_locked_y = nil, nil
    self.run_target_x, self.run_target_y = nil, nil

    self:sequenceFlash()

    Assets.playSound("wormparry", 1.0, MathUtils.random(0.9, 1.1))
end

function AgonyInfestation:draw()
    super.draw(self)
end

return AgonyInfestation