--- The character controlled by the player when in the Overworld.
---@class Player : Character, StateManagedClass
---@overload fun(chara: string|Actor, x?: number, y?: number) : Player
local Player, super = Class(Character)

function Player:init(chara, x, y)
    super.init(self, chara, x, y)

    self.is_player = true

    self.slide_sound = Assets.newSound("paper_surf")
    self.slide_sound:setLooping(true)

    self.climb_state = PlayerClimbState(self)

    self.state_manager = StateManager("WALK", self, true)
    self.state_manager:addState("WALK", { update = self.updateWalk, drawDebug = self.drawDebug })
    self.state_manager:addState("RUN", { update = self.updateRun, enter = self.beginRun, leave = self.endRun } )
    self.state_manager:addState("DASH", { update = self.updateDash, enter = self.beginDash, leave = self.endDash })
    self.state_manager:addState("SLIDE", { update = self.updateSlide, enter = self.beginSlide, leave = self.endSlide, remove = self.removeSlide })
    self.state_manager:addState("CLIMB_MOUNT", { postJump = self.postJumpClimbMount, enter = self.beginClimbMount })
    self.state_manager:addState("CLIMB", self.climb_state)
    self.state_manager:addState("CLIMB_DISMOUNT", { update = self.updateClimbDismount, enter = self.beginClimbDismount, leave = self.endClimbDismount })

    self.force_run = false
    self.force_walk = false
    self.run_timer = 0
    self.run_timer_grace = 0
    self.run_transition_grace = 0

    self.auto_moving = false

    self.current_slide_area = nil
    self.slide_in_place = false
    self.slide_lock_movement = false
    self.slide_dust_timer = 0
    self.slide_land_timer = 0

    self.hurt_timer = 0

    self.moving_x = 0
    self.moving_y = 0
    --self.walk_speed = (Game:isLight() and 6 or 6) + Game.party[1].walk_speed_bonus
    self.run_momentum = { 0, 0 }
    self.temp_boost_x = 0
    self.temp_boost_y = 0

    self.dash_cd = 0
    self.dash_timer = 0
    self.dash_momentum = { 0, 0 }
    self.dash_magnitude = { 0, 0 }
    self.dash_afterimages = 0

    self.last_move_x = self.x
    self.last_move_y = self.y

    self.idle_timer = 0

    self.history_time = 0
    self.history = {}

    self.interact_buffer = 0
    self.attack_buffer = 0

    self.time_since_attack = 0
    self.attacking = false
    self.attack_stage = 0

    self.battle_alpha = 0

    self.persistent = true
    self.noclip = false

    local was_running = false

    self.splatted = false

    local outlinefx = BattleOutlineFX()
    outlinefx:setAlpha(self.battle_alpha)

    self.outlinefx = self:addFX(outlinefx)

    self.force_climb = false
    self.climb_facing_direction = nil

    self.climb_mount_target_x = 0
    self.climb_mount_target_y = 0

    self.climb_mount_callback = nil

    self.climb_exit_landing = false
    self.climb_exit_target_x = 0
    self.climb_exit_target_y = 0

    self.climb_exit_timer = 0

    self.follower_tweens = {}

    self.should_sit = true
end

function Player:getCurrentSpeed(running)
    local speed = self:getBaseWalkSpeed()
    if running then
        if self.run_timer > 30 then
            if (self.state ~= "RUN") then self:setState("RUN") end
            speed = speed + (Game:isLight() and 6 or 5)
        elseif self.run_timer > 10 then
            speed = speed + 4
        else
            speed = speed + 2
        end
    end
    return speed
end

function Player:getBaseWalkSpeed()
    return 6 + Game.party[1].walk_speed_bonus
end

function Player:getDebugInfo()
    local info = super.getDebugInfo(self)
    table.insert(info, "State: " .. self.state_manager.state)

    self.state_manager:call("getDebugInfo", info)

    if self.state_manager.state == "SLIDE" then
        table.insert(info, "Slide in place: " .. (self.slide_in_place and "True" or "False"))
    elseif self.state_manager.state == "WALK" then
        table.insert(info, "Walk speed: " .. self:getBaseWalkSpeed())
        table.insert(info, "Current walk speed: " .. self:getCurrentSpeed(false))
        table.insert(info, "Current run speed: " .. self:getCurrentSpeed(true))
        table.insert(info, "Run timer: " .. self.run_timer)
        table.insert(info, "Hurt timer: " .. self.hurt_timer)
        table.insert(info, "Force run: " .. (self.force_run and "True" or "False"))
        table.insert(info, "Force walk: " .. (self.force_walk and "True" or "False"))
    end

    return info
end

function Player:getDebugOptions(context)
    context = super.getDebugOptions(self, context)

    if self.state_manager.state == "WALK" then
        context:addMenuItem(
            "Toggle force run", "Toggle if the player is forced to run or not",
            function() self.force_run = not self.force_run end
        )
        context:addMenuItem(
            "Toggle force walk", "Toggle if the player is forced to walk or not",
            function() self.force_walk = not self.force_walk end
        )
    elseif self.state_manager.state == "CLIMB" then
        context:addMenuItem(
            "Toggle force climb", "Toggle if the player is forced to climb or not",
            function() self.force_climb = not self.force_climb end
        )
    end

    if self.state_manager.state ~= "CLIMB" then
        context:addMenuItem(
            "Start climbing", "Start climbing where the player currently is.",
            function() self:setState("CLIMB") end
        )
    end

    if self.state_manager.state ~= "WALK" then
        context:addMenuItem(
            "Start walking", "Start walking where the player currently is.",
            function() self:setState("WALK") end
        )
    end

    if self.state_manager.state ~= "SLIDE" then
        context:addMenuItem(
            "Start sliding", "Start sliding where the player currently is.",
            function() self:setState("SLIDE") end
        )
    end

    return context
end

---@param parent World
function Player:onAdd(parent)
    super.onAdd(self, parent)

    if parent:includes(World) and not parent.player then
        parent.player = self
    end
end

---@param parent World
function Player:onRemove(parent)
    super.onRemove(self, parent)

    self.state_manager:call("remove")

    self.slide_sound:stop()

    if parent:includes(World) and parent.player == self then
        parent.player = nil
    end
end

function Player:setActor(actor)
    super.setActor(self, actor)

    local hx, hy, hw, hh = self.collider.x, self.collider.y, self.collider.width, self.collider.height

    self.interact_collider = {
        ["left"] = Hitbox(self, hx - 13, hy, hw / 2 + 13, hh),
        ["right"] = Hitbox(self, hx + hw / 2, hy, hw / 2 + 13, hh),
        ["up"] = Hitbox(self, hx, hy - 19, hw, hh / 2 + 19),
        ["down"] = Hitbox(self, hx, hy + hh / 2, hw, hh / 2 + 14)
    }

    self.attack_collider = {
        ["left"] = Hitbox(self, hx - 26, hy, hw / 2 + 26, hh),
        ["right"] = Hitbox(self, hx + hw / 2, hy, hw / 2 + 26, hh),
        ["up"] = Hitbox(self, hx, hy - 38, hw, hh / 2 + 38),
        ["down"] = Hitbox(self, hx, hy + hh / 2, hw, hh / 2 + 28)
    }
end

function Player:interact()
    if self.interact_buffer > 0 then
        return true
    end

    local col = self.interact_collider[self:getFacing()]

    Object.startCache()
    local interactables = {}
    for _, obj in ipairs(self.world.children) do
        if obj.onInteract and obj:collidesWith(col) then
            local rx, ry = obj:getRelativePos(obj.width / 2, obj.height / 2, self.parent)
            table.insert(interactables, { obj = obj, dist = MathUtils.dist(self.x, self.y, rx, ry) })
        end
    end
    Object.endCache()

    table.sort(interactables, function(a, b) return a.dist < b.dist end)
    for _, v in ipairs(interactables) do
        if v.obj:onInteract(self, self:getFacing()) then
            self.interact_buffer = v.obj.interact_buffer or 0
            return true
        end
    end

    return false
end

function Player:canDash()
    return self:isMovementEnabled() and self.dash_cd == 0 and not Game:isLight() and self.state_manager.state ~= "SLIDE" and self.state_manager.state ~= "DASH"
end

function Player:beginDash(prev_state, settings)
    self:setAnimation("dash")
    if not (settings and settings.transition_restore) then
        Assets.playSound("bigcut", 0.8)
    end

    if settings and settings.transition_restore then
        self.idle_timer = 0
        return
    end

    local walk_x = 0
    local walk_y = 0

    if     Input.down("left")  then walk_x = walk_x - 1
    elseif Input.down("right") then walk_x = walk_x + 1 end
    if     Input.down("up")    then walk_y = walk_y - 1
    elseif Input.down("down")  then walk_y = walk_y + 1 end

    local joy_x, joy_y = Input.getThumbstick("left")
    if (joy_x ~= 0 or joy_y ~= 0) then
        walk_x = joy_x
        walk_y = joy_y
    end

    if (walk_x == 0 and walk_y == 0) then
        walk_x, walk_y = Utils.getFacingVector(self.facing)
    end
    if (prev_state == "RUN") then
        self.was_running = true
        self.dash_momentum = {walk_x + self.run_momentum[1] * 2, walk_y + self.run_momentum[2] * 2}
    else
        self.dash_momentum = {walk_x, walk_y}
    end

    self.idle_timer = 0

    self.dash_magnitude = {self.dash_momentum[1], self.dash_momentum[2]}
    -- for index, value in ipairs(Game.world.followers) do
    --     if (value.following) then
    --         value.state_manager:setState("DASH")
    --     end
    -- end
end

function Player:endDash(new_state)
    self:resetSprite()
    -- for index, value in ipairs(Game.world.followers) do
    --     if (value.following) then
    --         value.state_manager:setState(new_state)
    --     end
    -- end
    if (new_state == "WALK") then
    else
        self.run_momentum = self.dash_momentum
    end
    self.was_running = false
    self.dash_momentum = {0, 0}
    self.dash_magnitude = {0, 0}
    self.dash_cd = 10
    self.dash_timer = 0
    self.dash_afterimages = 0
end

function Player:updateDash()
    local sign = function (number)
        return number > 0 and 1 or (number == 0 and 0 or -1)
    end
    self.dash_timer = self.dash_timer + (1 * DTMULT)
    if (self.dash_timer >= 20 or Input.pressed("attack")) then
        if (Input.down("cancel")) then
            self.was_running = true
        end
        self:setState(self.was_running and "RUN" or "WALK")
    end

    local walk_x = 0
    local walk_y = 0

    if     Input.down("left")  then walk_x = walk_x - 1
    elseif Input.down("right") then walk_x = walk_x + 1 end
    if     Input.down("up")    then walk_y = walk_y - 1
    elseif Input.down("down")  then walk_y = walk_y + 1 end

    local joy_x, joy_y = Input.getThumbstick("left")
    if (joy_x ~= 0 or joy_y ~= 0) then
        walk_x = joy_x
        walk_y = joy_y
    end

    local target_x = (math.abs(walk_x) > 0) and (sign(walk_x) * math.abs(self.dash_magnitude[1])) or self.dash_momentum[1]
    local target_y = (math.abs(walk_y) > 0) and (sign(walk_y) * math.abs(self.dash_magnitude[2])) or self.dash_momentum[2]
    self.dash_momentum[1] = MathUtils.approach(self.dash_momentum[1], target_x, DTMULT / 2)
    self.dash_momentum[2] = MathUtils.approach(self.dash_momentum[2], target_y, DTMULT / 2)

    while self.dash_afterimages < math.floor(self.dash_timer) + 4 do
        local afterimage = AbsoluteAfterImage(self, 0.5)
        Game.world:addChild(afterimage)

        self.dash_afterimages = self.dash_afterimages + 1
    end

    self:move(self.dash_momentum[1], self.dash_momentum[2], 14 * DTMULT)
end

function Player:beginRun(old_state)
    self:setWalkSprite(self.actor:getRunSprite())
    self.temp_boost_x = 0
    self.temp_boost_y = 0
    if (old_state ~= "DASH") then
        self.run_momentum[1] = 0
        self.run_momentum[2] = 0
    end
    self.idle_timer = 0

    -- for index, value in ipairs(Game.world.followers) do
    --     if (value.following) then
    --         value.state_manager:setState("RUN")
    --     end
    -- end
end

function Player:endRun(new_state)
    if (new_state) == "WALK" then
        self:resetSprite()
        self.temp_boost_x = 0
        self.temp_boost_y = 0
        self.run_momentum[1] = 0
        self.run_momentum[2] = 0

        local settle_min_speed = self:getBaseWalkSpeed()
        local settle_speed = settle_min_speed + (Game:isLight() and 4 or 4)
        for _, follower in ipairs(Game.world.followers) do
            if follower.following and follower.state_manager.state == "RUN" then
                local offset_x, offset_y = 0, 0
                if self.facing == "left" then
                    offset_x = 1
                elseif self.facing == "right" then
                    offset_x = -1
                elseif self.facing == "up" then
                    offset_y = 1
                elseif self.facing == "down" then
                    offset_y = -1
                end

                local idist = (follower:getFollowDelay() / (1 / 30)) * 4
                follower.run_settling = true
                follower.run_settle_target = {
                    x = self.x + (offset_x * idist),
                    y = self.y + (offset_y * idist),
                    facing = self.facing
                }
                follower.run_settle_speed = settle_speed
                follower.run_settle_min_speed = settle_min_speed
                follower.following = false
                follower.returning = false
            end
        end
    end
end

function Player:restoreRunState(run_state)
    self:setState("RUN")
    self.run_timer = run_state.run_timer
    self.run_timer_grace = run_state.run_timer_grace
    self.run_momentum[1] = run_state.run_momentum[1]
    self.run_momentum[2] = run_state.run_momentum[2]
    self.temp_boost_x = run_state.temp_boost_x
    self.temp_boost_y = run_state.temp_boost_y
    self.run_transition_grace = run_state.run_transition_grace or 0.5
    self:setWalkSprite(self.actor:getRunSprite())
end

function Player:restoreDashState(dash_state)
    self:setState("DASH", { transition_restore = true })
    self.dash_timer = dash_state.dash_timer
    self.dash_momentum = { dash_state.dash_momentum[1], dash_state.dash_momentum[2] }
    self.dash_magnitude = { dash_state.dash_magnitude[1], dash_state.dash_magnitude[2] }
    self.dash_afterimages = dash_state.dash_afterimages
    self.was_running = dash_state.was_running
end

function Player:restoreTransitionMovementState(movement_state)
    if movement_state.state == "DASH" then
        self:restoreDashState(movement_state)
    elseif movement_state.state == "RUN" then
        self:restoreRunState(movement_state)
    end
end

function Player:updateRun()
    if (Game:getFlag("simple_run", false)) then
        self:updateWalk()
    else
        if self:isMovementEnabled() then
            self:handleMomentumMovement()
        end
    end
end

function Player:handleMomentumMovement()

    local sign = function (number)
        return number > 0 and 1 or (number == 0 and 0 or -1)
    end

    local walk_x = 0
    local walk_y = 0

    if     Input.down("left")  then walk_x = walk_x - 1
    elseif Input.down("right") then walk_x = walk_x + 1 end
    if     Input.down("up")    then walk_y = walk_y - 1
    elseif Input.down("down")  then walk_y = walk_y + 1 end

    local joy_x, joy_y = Input.getThumbstick("left")
    if (joy_x ~= 0 or joy_y ~= 0) then
        walk_x = joy_x
        walk_y = joy_y
    end

    self.moving_x = walk_x
    self.moving_y = walk_y

    self.temp_boost_x = MathUtils.approach(self.temp_boost_x, 0, DT)
    self.temp_boost_y = MathUtils.approach(self.temp_boost_y, 0, DT)

    local running = (Input.down("cancel") or self.force_run) and not self.force_walk
    if Kristal.Config["autoRun"] and not self.force_run and not self.force_walk then
        running = not running
    end
    if self.run_transition_grace > 0 then
        running = true
    end

    if self.force_run and not self.force_walk then
        self.run_timer = 200
    end
    if self.run_timer == 0 then
        self.run_momentum[1] = MathUtils.approach(self.run_momentum[1], 0, DT * 2)
        self.run_momentum[2] = MathUtils.approach(self.run_momentum[2], 0, DT * 2)

        if (math.abs(self.run_momentum[1]) < 0.05 and math.abs(self.run_momentum[2]) < 0.05) then
            self:setState("WALK")
        end
    else
        local mult_x, mult_y = 1, 1
        if math.abs(walk_x) > 0 and (sign(walk_x) ~= sign(self.run_momentum[1])) and math.abs(self.run_momentum[1]) > 0.5 then mult_x = 3 end
        if math.abs(walk_y) > 0 and (sign(walk_y) ~= sign(self.run_momentum[2])) and math.abs(self.run_momentum[2]) > 0.5 then mult_y = 3 end
        if ((mult_x > 1) or (mult_y > 1)) and (math.abs(walk_x) > 0 or math.abs(walk_y) > 0) and not self.sprite:isSprite("skid") then
            local facingangle = math.atan2(walk_y, walk_x)
            local facingfromangle = Utils.facingFromAngle(facingangle)
            self:setFacing(facingfromangle)
            self:setAnimation("skid", function () self:setWalkSprite(self.actor:getRunSprite()) end)
            
            Assets.playSound("run_skid", 0.75, 1)
            self:runSkidDust(walk_y > 0 and mult_y > 1)
            for index, value in ipairs(Game.world.followers) do
                value:setFacing(facingfromangle)
                value:runSkidDust(walk_y > 0 and mult_y > 1)
                value:setAnimation({"skid/"..facingfromangle, 0.15, false}, function () value:setWalkSprite(value.actor:getRunSprite()) end)
            end
            if ((mult_x > 1) and (walk_y ~= 0) and (mult_y == 1)) and self.temp_boost_x == 0 then
                self.temp_boost_y = math.min(self.temp_boost_y + 0.5, 2)
                Assets.playSound("bell_bounce_short")
                self:flash()
            end
            if ((mult_y > 1) and (walk_x ~= 0) and (mult_x == 1)) and self.temp_boost_y == 0 then
                self.temp_boost_x = math.min(self.temp_boost_x + 0.5, 2)
                Assets.playSound("bell_bounce_short")
                self:flash()
            end
        end
        self.run_momentum[1] = MathUtils.approach(self.run_momentum[1], walk_x + (walk_x * self.temp_boost_x), DT * mult_x)
        self.run_momentum[2] = MathUtils.approach(self.run_momentum[2], walk_y + (walk_y * self.temp_boost_y), DT * mult_y)
    end

    local speed = self:getBaseWalkSpeed() + (Game:isLight() and 4 or 4)
    
    self:move(walk_x + self.run_momentum[1], walk_y + self.run_momentum[2], speed * DTMULT)

    if not running or self.last_collided_x or self.last_collided_y then
        self.run_timer = 0
        if ((self.last_collided_x and math.abs(self.run_momentum[1]) > 0.85) or (self.last_collided_y and math.abs(self.run_momentum[2]) > 0.85)) and Game:isLight() then
            local slide_position = {self.last_collided_x and -self.run_momentum[1] * 8 or 0, self.last_collided_y and -self.run_momentum[2] * 8 or 0}
            self:setState("WALK")
            self.splatted = true
            Game.world.timer:after(2, function ()
                self.splatted = false
                self:resetSprite()
            end)
            Assets.playSound("splat")
            self:setAnimation("splat")
            self:slideTo(self.x + slide_position[1], self.y + slide_position[2], 0.5, "out-cubic")
        end
    elseif running then
        if walk_x ~= 0 or walk_y ~= 0 then
            self.run_timer = self.run_timer + DTMULT
            self.run_timer_grace = 0
            self.run_transition_grace = 0
        else
            -- Dont reset running until 2 frames after you release the movement keys
            if self.run_transition_grace == 0 and self.run_timer_grace >= 2 then
                self.run_timer = 0
            end
            self.run_timer_grace = self.run_timer_grace + DTMULT
        end
    end
end

function Player:attack()
    if ((not Game:getFlag("can_attack", false)) or self.state_manager.state == "SLIDE") then
        return true
    end
    if (self.attack_buffer > 0) then
        return true
    end
    self.time_since_attack = 0
    self.attack_stage = self.attack_stage + 1
    if (self.attack_stage > 3) then self.attack_stage = 1 end
    self.attack_buffer = Game.party[1].overworld_attack_cd
    self.attacking = true

    local attack_dist = Game.party[1].attack_distance
    local dx, dy = Utils.getFacingVector(self.facing)
    if (attack_dist > 0) then self:updateSlideDust() end
    self.slide_dust_timer = 0
    self:move(self.x + (dx * attack_dist), self.y + (dy * attack_dist), 0.15)

    self:setAnimation("attack"..self.attack_stage, function () self.attacking = false end)
    Assets.playSound(Game.party[1].attack_sound or (Game:isLight() and "swipe") or "laz_c", 1.0, Game.party[1].attack_pitch or 1)

    local hit_anything = false
    local col = self.attack_collider[self.facing]
    local attackables = {}
    for _, obj in ipairs(self.world.children) do
        if obj.onHit and obj:collidesWith(col) then
            local rx, ry = obj:getRelativePos(obj.width / 2, obj.height / 2, self.parent)
            table.insert(attackables, { obj = obj, dist = Utils.dist(self.x, self.y, rx, ry) })
        end
    end
    table.sort(attackables, function (a, b) return a.dist < b.dist end)
    for _, v in ipairs(attackables) do
        hit_anything = v.obj:onHit(self, self.facing) or hit_anything
    end

    return hit_anything
end

function Player:setState(state, ...)
    self.state_manager:setState(state, ...)
end

function Player:resetFollowerHistory()
    for _, follower in ipairs(Game.world.followers) do
        if follower:getTarget() == self then
            follower:copyHistoryFrom(self)
        end
    end
end

--- Aligns the player's followers' directions and positions.
---@param facing?   string  The direction every character should face (Defaults to player's direction)
---@param x?        number  The x-coordinate of the 'front' of the line. (Defaults to player's x-position)
---@param y?        number  The y-coordinate of the 'front' of the line. (Defaults to player's y-position)
---@param dist?     number  The distance between each follower.
function Player:alignFollowers(facing, x, y, dist)
    facing = facing or self:getFacing()
    x, y = x or self.x, y or self.y

    local offset_x, offset_y = 0, 0
    if facing == "left" then
        offset_x = 1
    elseif facing == "right" then
        offset_x = -1
    elseif facing == "up" then
        offset_y = 1
    elseif facing == "down" then
        offset_y = -1
    end

    self.history = { { x = x, y = y, time = self.history_time } }
    for i = 1, Game.max_followers do
        local idist = dist and (i * dist) or (((i * FOLLOW_DELAY) / (1 / 30)) * 4)
        table.insert(
            self.history,
            {
                x = x + (offset_x * idist),
                y = y + (offset_y * idist),
                facing = facing,
                time = self.history_time - (i * FOLLOW_DELAY)
            }
        )
    end
    self:resetFollowerHistory()
end

--- Adds all followers' current positions to their movement history.
function Player:interpolateFollowers()
    for i, follower in ipairs(Game.world.followers) do
        if follower:getTarget() == self then
            follower:interpolateHistory()
        end
    end
end

function Player:isCameraAttachable()
    if self.state_manager.state == "CLIMB" then
        return false
    end

    if self.state_manager.state == "CLIMB_MOUNT" then
        return false
    end

    if self.state_manager.state == "CLIMB_DISMOUNT" then
        return false
    end

    if self.state_manager.state == "SLIDE" and self.slide_in_place then
        return false
    end

    return true
end

function Player:isMovementEnabled()
    return not OVERLAY_OPEN
        and not Game.lock_movement
        and not self.slide_lock_movement
        and Game.state == "OVERWORLD"
        and self.world.state == "GAMEPLAY"
        and self.hurt_timer == 0
        and Game.world.door_delay == 0
        and not self.attacking
        and not self.splatted
end

function Player:handleMovement()
    local walk_x = 0
    local walk_y = 0

    if Input.down("left") then
        walk_x = walk_x - 1
    elseif Input.down("right") then
        walk_x = walk_x + 1
    end

    if Input.down("up") then
        walk_y = walk_y - 1
    elseif Input.down("down") then
        walk_y = walk_y + 1
    end

    local joy_x, joy_y = Input.getThumbstick("left")
    if (joy_x ~= 0 or joy_y ~= 0) then
        walk_x = joy_x
        walk_y = joy_y
    end

    self.moving_x = walk_x
    self.moving_y = walk_y

    local running = (Input.down("cancel") or self.force_run) and not self.force_walk
    if Kristal.Config["autoRun"] and not self.force_run and not self.force_walk then
        running = not running
    end

    if self.force_run and not self.force_walk then
        self.run_timer = 200
    end

    local speed = self:getCurrentSpeed(running)

    self:move(walk_x, walk_y, speed * DTMULT)

    if not running or self.last_collided_x or self.last_collided_y then
        self.run_timer = 0
    elseif running then
        if walk_x ~= 0 or walk_y ~= 0 then
            self.run_timer = self.run_timer + DTMULT
            self.run_timer_grace = 0
        else
            -- Dont reset running until 2 frames after you release the movement keys
            if self.run_timer_grace >= 2 then
                self.run_timer = 0
            end
            self.run_timer_grace = self.run_timer_grace + DTMULT
        end
    end
end

function Player:updateWalk()
    if self:isMovementEnabled() then
        self:handleMovement()
    end
    if (self.moving_x == 0 and self.moving_y == 0) then
        self.idle_timer = self.idle_timer + DT
    else
        self.idle_timer = 0
    end
end

function Player:onMapLoad()
    if self:isClimbing() then
        Game.world:detachFollowers()
        self:cancelFollowerTweens()
        for _, follower in ipairs(Game.world.followers) do
            follower.alpha = 0
            follower.visible = false
        end

        self.climb_state:setDirection(self:getFacing())
    end
end

function Player:isMoving()
    return self.moving_x ~= 0 or self.moving_y ~= 0
end

function Player:isClimbing()
    return self.state_manager.state == "CLIMB"
end

function Player:isClimbJumping()
    return self:isClimbing() and self.climb_state.jumping and self.climb_state.state == 2
end

function Player:beginSlide(last_state, in_place, lock_movement)
    self.slide_sound:play()
    self.auto_moving = true
    self.slide_in_place = in_place or false
    self.slide_lock_movement = lock_movement or false
    self.slide_land_timer = 0
    self.sprite:setAnimation("slide")
end

function Player:updateSlideDust()
    self.slide_dust_timer = self.slide_dust_timer - DTMULT

    if self.slide_dust_timer <= 0 then
        self.slide_dust_timer = self.slide_dust_timer + 3

        local dust = Sprite("effects/slide_dust")
        dust:play(1 / 15, false, function() dust:remove() end)
        dust:setOrigin(0.5, 0.5)
        dust:setScale(2, 2)
        dust:setPosition(self.x, self.y)
        dust.layer = self.layer - 0.01
        dust.physics.speed_y = -6
        dust.physics.speed_x = MathUtils.random(-1, 1)
        dust.debug_select = false
        self.world:addChild(dust)
    end
end

function Player:runSkidDust(above)
    for i = 1, 3, 1 do
        local dust = Sprite("effects/slide_dust")
        dust:play(1 / 15, false, function () dust:remove() end)
        dust:setOrigin(0.5, 0.5)
        local scale_offset = MathUtils.random(-0.35, 0.35)
        dust:setScale(1 + scale_offset, 1 + scale_offset)
        dust:setPosition(self.x + MathUtils.random(-0.5, 0.5), self.y + 8)
        dust.layer = self.layer - (above and 0.01 or -0.01)
        dust.physics.speed_y = -4 + MathUtils.random(-1, 1)
        dust.physics.speed_x = MathUtils.random(-1, 1) + self.run_momentum[1]
        self.world:addChild(dust)
    end
end

function Player:updateSlide()
    local slide_x = 0
    local slide_y = 0

    if self:isMovementEnabled() then
        if Input.down("right") then slide_x = slide_x + 1 end
        if Input.down("left") then slide_x = slide_x - 1 end
        if Input.down("down") then slide_y = slide_y + 1 end
        if Input.down("up") then slide_y = slide_y - 1 end
    end

    if not self.slide_in_place then
        slide_y = 2
    end

    self.run_timer = 50
    local speed = self:getBaseWalkSpeed() + 4

    self:move(slide_x, slide_y, speed * DTMULT)

    self:updateSlideDust()
end

function Player:endSlide(next_state)
    if self.slide_lock_movement then
        self.slide_land_timer = 4
    else
        self.slide_sound:stop()
        self.sprite:resetSprite()
    end
    self.auto_moving = false
end

function Player:removeSlide()
    self.slide_sound:stop()
end

function Player:cancelFollowerTweens()
    for _, tween in ipairs(self.follower_tweens) do
        Game.world.timer:cancel(tween)
    end
    self.follower_tweens = {}
end

---@class ClimbMountSettings
---@field target_x number? The x position that the player will jump to.
---@field target_y number? The y position that the player will jump to.
---@field facing_direction FacingDirection? The climb direction the player will face after mounting.
---@field post_jump fun():nil? A function that will be called after the player finishes the jump, before they enter the CLIMB state.

function Player:beginClimbMount(last_state, settings)
    settings = settings or {}

    Game.lock_movement = true

    Game.world:detachFollowers()

    self.climb_mount_target_x = settings.target_x or self.x
    self.climb_mount_target_y = settings.target_y or self.y

    self.climb_facing_direction = settings.facing_direction

    if self.climb_facing_direction == nil then
        -- If a facing direction isn't supplied, let's try to guess one...
        self.climb_facing_direction = Utils.facingFromAngle(MathUtils.angle(self.x, self.y, self.climb_mount_target_x, self.climb_mount_target_y))
    end

    self:jumpTo(self.climb_mount_target_x, self.climb_mount_target_y + self:getScaledHeight() / 2, 8, 8 / 30, "jump_ball_slow")

    self:cancelFollowerTweens()

    for _, follower in ipairs(Game.world.followers) do
        follower.alpha = 1
        follower.visible = true
        table.insert(self.follower_tweens, Game.world.timer:tween(7 / 30, follower.color, { [1] = 0.5, [2] = 0.5, [3] = 0.5 }))
        table.insert(self.follower_tweens, Game.world.timer:tween(7 / 30, follower, { alpha = 0 }))
    end

    Assets.playSound("wing")

    self.climb_mount_callback = settings.post_jump
end

function Player:postJumpClimbMount()
    Assets.playSound("noise")

    self.x = self.climb_mount_target_x
    self.y = self.climb_mount_target_y

    Game.lock_movement = false
    self:setState("CLIMB", { starting_direction = self.climb_facing_direction })

    if self.climb_mount_callback then
        self.climb_mount_callback()
        self.climb_mount_callback = nil
    end
end

---@class ClimbFallSettings
---@field direction "up"|"down"|"left"|"right"? The direction the player falls. Defaults to "down".
---@field recover_from_fall boolean? Whether the player should be teleported back to the last safe position after falling. Defaults to true.
---@field max_speed number? The maximum speed the player can reach while falling. Defaults to 10.

--- Make the player fall while in the climb state. Does nothing if the player is not climbing.
---@param time integer The amount of time (in frames) that it takes the player to attempt to re-grab the wall. Defaults to 20. Common values are 10, 15, 20, 24, 30, 34, and 80.
---@param settings ClimbFallSettings? The settings for the climb fall. Optional.
function Player:climbFall(time, settings)
    if not self:isClimbing() then
        return
    end

    self.climb_state:fall(time, settings)
end

--- Requests that the player exits the climb state, jumping to a defined location.
---@param settings ClimbDismountSettings The settings for the climb dismount.
function Player:queueClimbDismount(settings)
    if not self:isClimbing() then
        return
    end

    self.climb_state:queueExit(settings)
end

---@class ClimbDismountSettings
---@field obj ClimbExit|ClimbLanding?
---@field landing boolean?
---@field x number?
---@field y number?
---@field facing FacingDirection?

function Player:beginClimbDismount(last_state, settings)
    Game.lock_movement = true

    local landing = settings.landing

    local target_x = settings.x
    local target_y = settings.y

    if settings.facing ~= nil then
        self:setFacing(settings.facing)
    end

    if settings.obj ~= nil then
        if landing then
            local landing_strip = settings.obj --[[@as ClimbLanding]]

            target_x, target_y = self.x, landing_strip.y
        else
            local exit = settings.obj --[[@as ClimbExit]]

            target_x, target_y = exit:getExitPosition()
        end
    end

    if target_x == nil or target_y == nil then
        target_x, target_y = self.x, self.y
    end

    self.climb_exit_landing = landing
    self.climb_exit_target_x = target_x
    self.climb_exit_target_y = target_y

    self.climb_exit_timer = 0


    if landing then
        Assets.playSound("noise")
        self:shake(5, 0, 1)
        self.sprite:setSprite("landed")
        self.sprite:setFrame(1)
        self:setFacing("down")

        self.x = target_x
        self.y = target_y

        -- TODO: Look into multiple party members, one party member, etc
        -- Susie prefers left, Ralsei prefers right

        local positions = {
            { self.x - 40, self.y - 10 },
            { self.x + 40, self.y - 10 }
        }

        for i, follower in ipairs(Game.world.followers) do
            local pos = positions[i]
            if pos then
                follower.x = pos[1]
                follower.y = pos[2]
            else
                follower.x = self.x
                follower.y = self.y - 20
            end
            follower:interpolateHistory()
        end
    else
        Assets.playSound("wing")
        self.auto_moving = true
    end

    if Game.world.camera ~= nil then

        local old_x, old_y = self.x, self.y
        self.x, self.y = target_x, target_y

        local ox, oy = self:getCameraOriginExact()
        local camera_x, camera_y = self:getRelativePos(ox, oy, Game.world)

        Game.world.camera:panTo(camera_x, camera_y, 15 / 30, "linear")

        self.x, self.y = old_x, old_y
    end

    if not landing then
        local jump_strength = 8
        if self:getFacing() == "up" then
            jump_strength = 12
        end

        self:jumpTo(target_x, target_y, jump_strength, 16 / 30, "jump_ball_slow")


        -- TODO: Look into multiple party members, one party member, etc
        -- Susie prefers left, Ralsei prefers right

        local facing = self:getFacing()

        for i, follower in ipairs(Game.world.followers) do
            if facing == "down" then
                if i == 1 then
                    follower.x = target_x - 20
                    follower.y = target_y - 10
                elseif i == 2 then
                    follower.x = target_x + 20
                    follower.y = target_y - 10
                else
                    follower.x = target_x
                    follower.y = target_y - 20
                end
            elseif facing == "up" then
                if i == 1 then
                    follower.x = target_x - 20
                    follower.y = target_y + 10
                elseif i == 2 then
                    follower.x = target_x + 20
                    follower.y = target_y + 10
                else
                    follower.x = target_x
                    follower.y = target_y + 20
                end
            elseif facing == "left" then
                follower.x = target_x + 20 * i
                follower.y = target_y
            elseif facing == "right" then
                follower.x = target_x - 20 * i
                follower.y = target_y
            end

            follower:interpolateHistory()
        end
    end
end

function Player:updateClimbDismount()
    self.climb_exit_timer = self.climb_exit_timer + DTMULT

    if self.climb_exit_timer >= 16 then
        local blend_time = 12
        if not self.climb_exit_landing then
            blend_time = 8

            Assets.playSound("noise")
        end

        self:cancelFollowerTweens()

        for _, follower in ipairs(Game.world.followers) do
            follower.alpha = 0
            follower.visible = true
            table.insert(self.follower_tweens, Game.world.timer:tween(blend_time / 30, follower.color, { [1] = 1, [2] = 1, [3] = 1 }))
            table.insert(self.follower_tweens, Game.world.timer:tween(blend_time / 30, follower, { alpha = 1 }))
        end

        self:interpolateFollowers()
        Game.world:attachFollowersImmediate()

        for _, follower in ipairs(Game.world.followers) do
            for _, history in ipairs(follower.history) do
                history.facing = self:getFacing()
            end
            follower:setFacing(self:getFacing())
        end

        self:setState("WALK")
    end
end

function Player:endClimbDismount()
    self.auto_moving = false
    Game.lock_movement = false
    Game.world.camera:setAttached(true, true)
    self:resetSprite()

    if self.climb_exit_timer < 16 then
        -- IF the end state was interrupted, forcibly show followers

        local blend_time = self.climb_exit_landing and 12 or 8

        self:cancelFollowerTweens()

        for _, follower in ipairs(Game.world.followers) do
            follower.alpha = 0
            follower.visible = true
            table.insert(self.follower_tweens, Game.world.timer:tween(blend_time / 30, follower.color, { [1] = 1, [2] = 1, [3] = 1 }))
            table.insert(self.follower_tweens, Game.world.timer:tween(blend_time / 30, follower, { alpha = 1 }))
        end

        self:interpolateFollowers()
        Game.world:attachFollowersImmediate()

        for _, follower in ipairs(Game.world.followers) do
            for _, history in ipairs(follower.history) do
                history.facing = self:getFacing()
            end
            follower:setFacing(self:getFacing())
        end
    end
end

function Player:getSoulOffset()
    if self.state == "CLIMB" then
        return self.width / 2, self.height / 2
    else
        return self.actor:getSoulOffset()
    end
end

function Player:updateHistory()
    if #self.history == 0 then
        table.insert(self.history, { x = self.x, y = self.y, time = 0 })
    end

    local moved = self.x ~= self.last_move_x or self.y ~= self.last_move_y

    local auto = self.auto_moving

    if moved then
        self.history_time = self.history_time + DT

        table.insert(
            self.history,
            1,
            {
                x = self.x,
                y = self.y,
                facing = self:getFacing(),
                time = self.history_time,
                state = self.state_manager.state,
                state_args = self.state_manager.args,
                auto = auto
            }
        )

        while (self.history_time - self.history[#self.history].time) > (Game.max_followers * FOLLOW_DELAY) do
            table.remove(self.history, #self.history)
        end
    end

    for _, follower in ipairs(self.world.followers) do
        follower:updateHistory(moved, auto)
    end

    self.last_move_x = self.x
    self.last_move_y = self.y
end

function Player:processJump()
    super.processJump(self)

    if (self.jump_progress == 3) and (not self.jumping) then
        -- A jump was just finished. Slightly hardcoded behavior for now...
        self.state_manager:call("postJump")
    end
end

function Player:update()
    if (self.sprite:isSprite("run") and self.state_manager.state ~= "RUN" and not self.force_run) then
        self:resetSprite()
    end

    if (self.idle_timer) >= 20 and Game.world.humming and not Game.world.hum_boosted then
        Game.world.hum_boosted = true
        Game.world.additional_music:fade(1.75)
    end
    if (self.idle_timer < 20) and Game.world.humming and Game.world.hum_boosted then
        Game.world.hum_boosted = false
        Game.world.additional_music:fade(1.2)
    end
    if self.hurt_timer > 0 then
        self.hurt_timer = MathUtils.approach(self.hurt_timer, 0, DTMULT)
    end

    if (self.dash_cd > 0) then
        self.dash_cd = MathUtils.approach(self.dash_cd, 0, DT * 4)
        if self.dash_cd <= 0 then
            self:flash()
        end
    end

    if self.run_transition_grace > 0 and self:isMovementEnabled() then
        self.run_transition_grace = MathUtils.approach(self.run_transition_grace, 0, DT)
    end

    if self.slide_land_timer > 0 and self.state_manager.state ~= "SLIDE" then
        self.slide_land_timer = MathUtils.approach(self.slide_land_timer, 0, DTMULT)
        if self.slide_land_timer == 0 then
            self.slide_sound:stop()
            self.sprite:resetSprite()
            self.slide_lock_movement = false
        end
    end

    self.state_manager:update()

    self:updateHistory()

    if not Game.world.cutscene and not Game.world.menu then
        self.interact_buffer = MathUtils.approach(self.interact_buffer, 0, DT)
        self.attack_buffer = MathUtils.approach(self.attack_buffer, 0, DT)
        self.time_since_attack = MathUtils.approach(self.time_since_attack, 3, DT)
        if (self.time_since_attack >= 2.99 and self.attack_stage > 0) then
            self.attack_stage = 0
        end
    end

    self.world.in_battle_area = false
    for _, area in ipairs(self.world.map.battle_areas) do
        if area:collidesWith(self.collider) then
            if not self.world.in_battle_area then
                self.world.in_battle_area = true
            end
            break
        end
    end

    if self.world:inBattle() then
        self.battle_alpha = math.min(self.battle_alpha + (0.04 * DTMULT), 0.8)
    else
        self.battle_alpha = math.max(self.battle_alpha - (0.08 * DTMULT), 0)
    end

    local outlinefx = self.outlinefx --[[@as BattleOutlineFX]]
    outlinefx:setAlpha(self.battle_alpha)

    super.update(self)
end

function Player:preDraw(dont_transform)
    super.preDraw(self, dont_transform)

    self.state_manager:call("preDraw", dont_transform)
end

function Player:drawDebug()
    local col = self.interact_collider[self:getFacing()]
    col:draw(1, 1, 0, 0.5)
end

function Player:draw()
    self.state_manager:call("drawUnderPlayer")

    local r, g, b, a = self:getColor()
    local use_alpha = a

    if self.state == "CLIMB" and Game.world.soul and Game.world.soul.inv_timer > 0 then
        use_alpha = a * 0.5
    end

    self:setColor(r, g, b, use_alpha)

    -- Draw the player
    super.draw(self)

    self:setColor(r, g, b, a)

    self.state_manager:call("drawOverPlayer")

    if DEBUG_RENDER then
        self.state_manager:call("drawDebug")
    end
end

function Player:postDraw()
    super.postDraw(self)

    self.state_manager:call("postDraw")
end

return Player
