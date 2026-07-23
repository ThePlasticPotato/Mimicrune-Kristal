--- The character controlled by the player when in the Overworld.
---@class Player : Character, StateManagedClass
---@overload fun(chara: string|Actor, x?: number, y?: number) : Player
local Player, super = Class(Character)

function Player:init(chara, x, y)
    super.init(self, chara, x, y)

    self.is_player = true

    self.climb_state = PlayerClimbState(self)
    self.slide_state = PlayerSlideState(self)
    self.slide_lock_state = PlayerSlideLockState(self)
    self.slide_free_state = PlayerSlideFreeState(self)


    ---todo: convert mimicrune run/dash/attack to states
    self.state_manager = StateManager("WALK", self, true)
    self.state_manager:addState("WALK", { update = self.updateWalk, drawDebug = self.drawDebug })
    self.state_manager:addState("RUN", { update = self.updateRun, enter = self.beginRun, leave = self.endRun } )
    self.state_manager:addState("DASH", { update = self.updateDash, enter = self.beginDash, leave = self.endDash })
    self.state_manager:addState("SLIDE", self.slide_state)
    self.state_manager:addState("SLIDE_LOCK", self.slide_lock_state)
    self.state_manager:addState("SLIDE_FREE", self.slide_free_state)
    self.state_manager:addState("CLIMB_MOUNT", { postJump = self.postJumpClimbMount, enter = self.beginClimbMount })
    self.state_manager:addState("CLIMB", self.climb_state)
    self.state_manager:addState("CLIMB_DISMOUNT", { update = self.updateClimbDismount, enter = self.beginClimbDismount, leave = self.endClimbDismount })

    self.height_state_manager = StateManager("GROUNDED", self, false)
    self.height_state_manager:addState("GROUNDED", { update = self.updateHeightGrounded })
    self.height_state_manager:addState("JUMP", { enter = self.beginHeightJump, update = self.updateHeightJump })
    self.height_state_manager:addState("FALL", { enter = self.beginHeightFall, update = self.updateHeightFall })
    self.height_state_manager:addState("LAND", { enter = self.beginHeightLand, update = self.updateHeightLand, leave = self.endHeightLand })
    self.height_state_manager:addState("PIT_RECOVER", {
        enter = self.beginHeightPitRecovery,
        update = self.updateHeightPitRecovery,
        leave = self.endHeightPitRecovery
    })
    self.height_state_manager:addState("SUSPENDED")

    self.platforming_enabled = false
    self.z_velocity = 0
    self.ground_z = 0
    self.ground_collider = nil
    self.ground_surface = nil
    self.airborne_surface = nil
    self.departed_ground_collider = nil
    self.departed_ground_surface = nil
    self.fall_through_colliders = {}
    self.landing_overlap_colliders = {}
    self.jump_strength = self.actor.jump_strength or 7
    self.jump_windup = self.actor.jump_windup or 0
    self.jump_windup_timer = 0
    self.pending_jump_strength = nil
    self.z_gravity = 0.6
    self.max_fall_speed = 12
    self.land_time = 5 / 30
    self.land_timer = 0
    self.pit_fall_limit = -80
    self.pit_recovery_out_time = 26 / 30
    self.pit_recovery_hold_time = 4 / 30
    self.pit_recovery_in_time = 26 / 30
    self.pit_recovery_timer = 0
    self.pit_recovery_progress = 0
    self.pit_recovery_teleported = false
    self.last_safe_x = self.x
    self.last_safe_y = self.y
    self.last_safe_z = self.z
    self.last_safe_surface_id = nil
    self.height_animation = nil
    self.shadow_z = 0
    self.shadow_surface = nil

    self.force_run = false
    self.force_walk = false
    self.run_timer = 0
    self.run_timer_grace = 0
    self.run_transition_grace = 0

    self.auto_moving = false

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
    self.last_move_z = self.z

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
    table.insert(info, "Height state: " .. self.height_state_manager.state)
    table.insert(info, "Z: " .. tostring(self.z))
    table.insert(info, "Z velocity: " .. tostring(self.z_velocity))
    table.insert(info, "Platforming: " .. (self.platforming_enabled and "True" or "False"))
    local height_surface = self:getHeightSurface()
    table.insert(info, "Surface: " .. tostring(height_surface and height_surface.id or "none"))
    table.insert(info, "Surface plane: " .. tostring(height_surface and height_surface.plane or "none"))

    self.state_manager:call("getDebugInfo", info)

    if self.state_manager.state == "WALK" then
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

    if parent:includes(World) then
        if not parent.player then parent.player = self end
        if not self.height_shadow or self.height_shadow.parent ~= parent then
            self.height_shadow = HeightShadow(self)
            parent:addChild(self.height_shadow)
        end
    end
end

---@param parent World
function Player:onRemove(parent)
    if parent and parent.removeFX then
        parent:removeFX("pit_recovery")
    end
    if self.height_shadow then
        self.height_shadow:remove()
        self.height_shadow = nil
    end
    super.onRemove(self, parent)

    self.state_manager:call("remove")

    if parent:includes(World) and parent.player == self then
        parent.player = nil
    end
end

function Player:setActor(actor)
    super.setActor(self, actor)

    self.collider.depth = actor.collision_depth or 20

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

    local support_width = math.min(hw, math.max(2, hw * 0.25))
    local support_height = math.min(hh, math.max(2, hh * 0.25))
    self.support_collider = Hitbox(self,
        hx + (hw - support_width) / 2,
        hy + (hh - support_height) / 2,
        support_width, support_height)
end

function Player:collidesWithHeightSensitiveObject(obj, collider)
    if obj.height_sensitive and self.platforming_enabled then
        return obj:collidesWith3D(collider)
    end
    return obj:collidesWith(collider)
end

function Player:interact()
    if self.interact_buffer > 0 then
        return true
    end

    local col = self.interact_collider[self:getFacing()]

    Object.startCache()
    local interactables = {}
    for _, obj in ipairs(self.world.children) do
        local collided = self:collidesWithHeightSensitiveObject(obj, col)
        if obj.onInteract and collided then
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

--- Airborne contact with the side of a platform can be temporary: continued
--- horizontal movement should carry the player over it once their Z clears
--- the top. Only grounded wall collisions cancel run momentum and splat.
---@return boolean
function Player:hasGroundedMovementCollision()
    local collided = self.last_collided_x or self.last_collided_y
    if not collided then return false end
    return not (self.platforming_enabled and not self:isGrounded())
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

    local grounded_collision = self:hasGroundedMovementCollision()
    if not running or grounded_collision then
        self.run_timer = 0
        if grounded_collision
            and ((self.last_collided_x and math.abs(self.run_momentum[1]) > 0.85)
                or (self.last_collided_y and math.abs(self.run_momentum[2]) > 0.85))
            and Game:isLight() then
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
        local collided = self:collidesWithHeightSensitiveObject(obj, col)
        if obj.onHit and collided then
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

function Player:isPlatformingEnabled()
    return self.platforming_enabled
end

function Player:setPlatformingEnabled(enabled)
    self.platforming_enabled = enabled or false
    self.use_3d_collision = self.platforming_enabled

    if not self.platforming_enabled then
        self.z = 0
        self.z_velocity = 0
        self.jump_windup_timer = 0
        self.pending_jump_strength = nil
        self.ground_z = 0
        self.ground_collider = nil
        self.ground_surface = nil
        self.airborne_surface = nil
        self.departed_ground_collider = nil
        self.departed_ground_surface = nil
        self.fall_through_colliders = {}
        self.landing_overlap_colliders = {}
        self.height_state_manager:setState("GROUNDED")
        self:restoreGroundAnimation()
        return
    end

    local ground_z, ground, surface = self.world:getGroundZAt(
        self.support_collider, self.z, self.collider
    )
    if ground_z then
        self.z = ground_z
        self.ground_z = ground_z
        self.ground_collider = ground
        self.ground_surface = surface
        self.airborne_surface = nil
        self.height_state_manager:setState("GROUNDED")
    elseif self.world:isOverPit(self.support_collider) then
        self.height_state_manager:setState("FALL")
    end
end

function Player:getHeightState()
    return self.height_state_manager.state
end

function Player:isGrounded()
    local state = self:getHeightState()
    return state == "GROUNDED" or state == "LAND"
end

function Player:isJumping()
    return self:getHeightState() == "JUMP"
end

function Player:isFalling()
    return self:getHeightState() == "FALL"
end

---@return table? surface
function Player:getHeightSurface()
    if self.ground_surface then return self.ground_surface end
    if self.airborne_surface then return self.airborne_surface end
    return self.world and self.world:getImplicitHeightSurface() or nil
end

---@return string? plane
function Player:getHeightSurfacePlane()
    local surface = self:getHeightSurface()
    return surface and surface.plane or nil
end

function Player:isPitRecovering()
    return self:getHeightState() == "PIT_RECOVER"
end

function Player:canJump()
    if not self.platforming_enabled or not self:isGrounded() then return false end
    if not self:isMovementEnabled() or self.jumping then return false end
    if self:isClimbing() or self:isSliding() then return false end
    return true
end

function Player:jump(strength)
    if not self:canJump() then return false end
    self.height_state_manager:setState("JUMP", strength or self.jump_strength)
    return true
end

function Player:isDashAnimationActive()
    return self.state_manager.state == "DASH"
end

function Player:setHeightAnimation(animation)
    self.height_animation = animation
    if self:isDashAnimationActive() then return end
    if self.actor:getAnimation(animation) then
        self:setAnimation(animation)
    end
end

function Player:restoreGroundAnimation()
    self.height_animation = nil
    if self:isDashAnimationActive() then return end
    if self.state_manager.state == "RUN" then
        self:setWalkSprite(self.actor:getRunSprite())
    else
        self:resetSprite()
    end
end

function Player:beginHeightJump(last_state, strength)
    self.z_velocity = 0
    self.pending_jump_strength = strength or self.jump_strength
    self.jump_windup_timer = self.jump_windup
    self:setHeightAnimation("jump")
    if self.jump_windup_timer <= 0 then self:launchHeightJump() end
end

function Player:launchHeightJump()
    self.z_velocity = self.pending_jump_strength or self.jump_strength
    self.pending_jump_strength = nil
    self.jump_windup_timer = 0
    self.airborne_surface = self.ground_surface
        or self.world:getHeightSurfaceForCollider(self.ground_collider)
        or self.world:getImplicitHeightSurface()
    self.ground_collider = nil
    self.ground_surface = nil
    Assets.playSound("jump", 0.7)
end

function Player:updateHeightGrounded()
    local support_z, support, surface =
        self.world:getSupportAt(self.support_collider, self.z)
    if support_z then
        self.z = support_z
        self.ground_z = support_z
        self.ground_collider = support
        self.ground_surface = surface
        self.airborne_surface = nil
        self.z_velocity = 0
        if not self.world:isOverPit(self.support_collider) then
            self.last_safe_x = self.x
            self.last_safe_y = self.y
            self.last_safe_z = self.z
            self.last_safe_surface_id = surface and surface.id or nil
        end
    else
        self.height_state_manager:setState("FALL")
    end
end

function Player:updateHeightJump()
    if self.pending_jump_strength then
        self.jump_windup_timer = MathUtils.approach(self.jump_windup_timer, 0, DT)
        if self.jump_windup_timer > 0 then return end
        self:launchHeightJump()
    end

    local old_z = self.z
    self.z_velocity = self.z_velocity - self.z_gravity * DTMULT
    local new_z = self.z + self.z_velocity * DTMULT

    if self.z_velocity > 0 then
        local ceiling_z = self.world:getCeilingSurface(
            self.collider,
            old_z + self.collider.depth,
            new_z + self.collider.depth
        )
        if ceiling_z then
            self.z = ceiling_z - self.collider.depth
            self.z_velocity = 0
            self.height_state_manager:setState("FALL")
            return
        end
    end

    self.z = new_z
    if self.z_velocity <= 0 then
        self.height_state_manager:setState("FALL")
    end
end

function Player:beginHeightFall(last_state)
    local previous_ground = self.ground_collider
    local previous_surface = self.ground_surface
    self.jump_windup_timer = 0
    self.pending_jump_strength = nil
    if last_state == "GROUNDED" or last_state == "LAND" then
        self.z_velocity = math.min(self.z_velocity, 0)
        if previous_ground then
            self.departed_ground_collider = previous_ground
        end
        self.departed_ground_surface = previous_surface
        self.airborne_surface = previous_surface
            or self.world:getImplicitHeightSurface()
    end
    self.ground_collider = nil
    self.ground_surface = nil
    self:setHeightAnimation("fall")
end

local function addHeightCollisionIgnore(ignored, collider)
    if not collider then return ignored end
    if not ignored then return collider end
    if isClass(ignored) then ignored = { [ignored] = true } end
    ignored[collider] = true
    return ignored
end

---@return Collider?
function Player:getDepartedGroundCollisionIgnore()
    local surface = self.departed_ground_collider
    if not surface or not self.platforming_enabled then return nil end

    if self.world:isSupportOver(self.support_collider, surface) then return nil end

    local state = self:getHeightState()
    if state == "JUMP" or state == "FALL" then return surface end

    if not self.collider:collidesWith(surface) then return nil end

    return surface
end

--- Colliders that landing and shadow validation may safely disregard.
---@return Collider|table<Collider, boolean>?
function Player:getHeightCollisionIgnore()
    local ignored = self:getDepartedGroundCollisionIgnore()
    for wall in pairs(self.fall_through_colliders or {}) do
        if not self.world:isSupportOver(self.collider, wall) then
            ignored = addHeightCollisionIgnore(ignored, wall)
        end
    end
    return ignored
end

--- Colliders entered through vertical motion must not trap horizontal escape.
---@return Collider|table<Collider, boolean>?
function Player:getMovementHeightCollisionIgnore()
    local ignored = self:getDepartedGroundCollisionIgnore()
    local grounded = Player.isGrounded(self)
    for wall in pairs(self.fall_through_colliders or {}) do
        if not grounded or (self.landing_overlap_colliders or {})[wall]
            or not self.world:isSupportOver(self.collider, wall) then
            ignored = addHeightCollisionIgnore(ignored, wall)
        end
    end
    return ignored
end

--- Returns the lowest foot Z occupied during the current movement/height
--- frame. Horizontal movement is processed before height, so using only the
--- current Z would let a well-timed dash enter a platform just before the same
--- frame drops the player below its top.
---@return number
function Player:getMovementCollisionZ()
    if not self.platforming_enabled or self.pending_jump_strength then
        return self.z
    end

    local state = self:getHeightState()
    if state ~= "JUMP" and state ~= "FALL" then return self.z end

    local next_velocity = self.z_velocity - self.z_gravity * DTMULT
    if state == "FALL" then
        next_velocity = math.max(next_velocity, -self.max_fall_speed)
    end
    return math.min(self.z, self.z + next_velocity * DTMULT)
end

--- Validates the committed result of a movement state as a final safeguard
--- against fast, multi-axis movement ending beneath an elevated support.
---@param start_x number
---@param start_y number
---@return boolean valid
function Player:validateHeightMovement(start_x, start_y)
    if not self.platforming_enabled or self.noclip or NOCLIP
        or (self.x == start_x and self.y == start_y) then
        return true
    end

    Object.uncache(self)
    local collided = self.world:checkMovementCollision3D(
        self.collider, self.enemy_collision,
        self:getMovementHeightCollisionIgnore(), self:getMovementCollisionZ()
    )
    if not collided then return true end

    local moved_x, moved_y = self.x ~= start_x, self.y ~= start_y
    self:setPosition(start_x, start_y)
    Object.uncache(self)
    self.last_collided_x = self.last_collided_x or moved_x
    self.last_collided_y = self.last_collided_y or moved_y
    return false
end

--- Records non-supporting walls entered because Z changed, rather than
--- because the player moved horizontally into them.
function Player:updateFallThroughColliders()
    Object.startCache()
    for _, wall in ipairs(self.world:getCollision(false)) do
        if not wall.one_way and not wall.supports
            and self.collider:collidesWith3D(wall) then
            self.fall_through_colliders[wall] = true
        end
    end
    Object.endCache()
end

--- Records a ground-level obstacle entered vertically on the landing frame.
function Player:recordLandingCollisionOverlaps()
    self:updateFallThroughColliders()
    for wall in pairs(self.fall_through_colliders or {}) do
        if self.collider:collidesWith3D(wall) then
            self.landing_overlap_colliders[wall] = true
        end
    end
end

function Player:updateDepartedGroundCollision()
    local surface = self.departed_ground_collider
    if surface then
        local state = self:getHeightState()
        local airborne = state == "JUMP" or state == "FALL"
        local returned_to_surface = self:isGrounded()
            and self.world:isSupportOver(self.support_collider, surface)
        if returned_to_surface
            or (not airborne and not self.collider:collidesWith(surface)) then
            self.departed_ground_collider = nil
            self.departed_ground_surface = nil
        end
    end
    for wall in pairs(self.fall_through_colliders or {}) do
        if not self.collider:collidesWith(wall) then
            self.fall_through_colliders[wall] = nil
            if self.landing_overlap_colliders then
                self.landing_overlap_colliders[wall] = nil
            end
        end
    end
end

--- Sweeps the screen-space descent below z=0 against base ground. A tall wall
--- can separate an elevated footprint from the lower floor in map Y even
--- though that floor is directly below the ledge in the rendered projection.
--- On contact, the excess visual drop is converted into map Y so setting Z to
--- zero does not snap the player back up the wall.
---@param old_z number
---@param new_z number
---@return number? landing_z
---@return Collider? surface
---@return table? height_surface
function Player:tryProjectedBaseLanding(old_z, new_z)
    if new_z >= 0 then return nil end

    local original_y = self.y
    local sweep_start = math.min(old_z, 0)
    local distance = sweep_start - new_z
    local steps = math.max(1, math.ceil(distance))

    for step = 1, steps do
        local sample_z = sweep_start - math.min(distance, step)
        self.y = original_y - sample_z
        Object.uncache(self)

        local ground_z, ground, height_surface = self.world:getGroundZAt(
            self.support_collider, 0,
            self.collider, self:getHeightCollisionIgnore()
        )
        if ground_z and math.abs(ground_z) < 0.001 then
            return 0, ground, height_surface
        end
    end

    self.y = original_y
    Object.uncache(self)
    return nil
end

function Player:updateHeightFall()
    local old_z = self.z
    self.z_velocity = math.max(self.z_velocity - self.z_gravity * DTMULT, -self.max_fall_speed)
    local new_z = self.z + self.z_velocity * DTMULT
    local ignored_surface = self:getHeightCollisionIgnore()
    local landing_z, landing, landing_surface =
        self.world:getLandingSurface(self.support_collider,
        old_z, new_z, self.collider, ignored_surface, self.departed_ground_collider)

    if not landing_z then
        landing_z, landing, landing_surface =
            self:tryProjectedBaseLanding(old_z, new_z)
    end

    if landing_z then
        self.z = landing_z
        self.ground_z = landing_z
        self.ground_collider = landing
        self.ground_surface = landing_surface
        self.airborne_surface = nil
        self.z_velocity = 0
        self:recordLandingCollisionOverlaps()
        self.height_state_manager:setState("LAND")
    else
        self.z = new_z
        self:updateFallThroughColliders()
        -- Once the player is this far below the base plane, every ordinary
        -- landing surface has already been missed. This is also an out-of-
        -- bounds fallback for wall-only ledge footprints: those are not pits,
        -- but must not allow Z to decrease forever when the player stops
        -- moving before reaching the adjacent lower floor.
        if self.z <= self.pit_fall_limit then
            self:recoverFromPit()
        end
    end
end

function Player:beginHeightLand()
    self.land_timer = self.land_time
    self:setHeightAnimation("landed")
end

function Player:updateHeightLand()
    local support_z, support, surface =
        self.world:getSupportAt(self.support_collider, self.z)
    if not support_z then
        self.height_state_manager:setState("FALL")
        return
    end

    self.z = support_z
    self.ground_z = support_z
    self.ground_collider = support
    self.ground_surface = surface
    self.airborne_surface = nil
    self.land_timer = MathUtils.approach(self.land_timer, 0, DT)
    if self.land_timer == 0 then
        self.height_state_manager:setState("GROUNDED")
    end
end

function Player:endHeightLand(new_state)
    if new_state == "GROUNDED" then
        self:restoreGroundAnimation()
    end
end

function Player:recoverFromPit()
    if self:isPitRecovering() then return end
    self.height_state_manager:setState("PIT_RECOVER")
end

function Player:beginHeightPitRecovery()
    self.z_velocity = 0
    self.jump_windup_timer = 0
    self.pending_jump_strength = nil
    self.ground_collider = nil
    self.ground_surface = nil
    self.airborne_surface = nil
    self.departed_ground_collider = nil
    self.departed_ground_surface = nil
    self.fall_through_colliders = {}
    self.landing_overlap_colliders = {}
    self.pit_recovery_timer = 0
    self.pit_recovery_progress = 0
    self.pit_recovery_teleported = false

    self.world:removeFX("pit_recovery")
    self.world:addFX(ShaderFX("goner_bleed", {
        progress = function() return self.pit_recovery_progress end,
        time = function() return Kristal.getTime() end
    }, false), "pit_recovery")
end

function Player:teleportFromPit()
    self:setPosition(self.last_safe_x, self.last_safe_y)
    self.z = self.last_safe_z or 0
    self.z_velocity = 0
    local ground_z, ground, surface =
        self.world:getSupportAt(self.support_collider, self.z)
    if ground_z then self.z = ground_z end
    self.ground_z = self.z
    self.ground_collider = ground
    self.ground_surface = surface
    self.airborne_surface = nil
    self:resetFollowerHistory()
end

function Player:updateHeightPitRecovery()
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
        self.height_state_manager:setState("GROUNDED")
    end
end

function Player:endHeightPitRecovery()
    self.world:removeFX("pit_recovery")
    self.pit_recovery_progress = 0
    self:restoreGroundAnimation()
end

function Player:updateHeight()
    if not self.platforming_enabled then return end
    if self.jumping or self:isClimbing() then return end
    self:updateDepartedGroundCollision()
    self.height_state_manager:update()
    self.shadow_z, _, self.shadow_surface =
        self.world:getGroundZAt(self.support_collider, self.z,
            self.collider, self:getHeightCollisionIgnore())
end

--- Keeps a completed, non-looping jump animation on its anticipation-free
--- final frame until the height state changes to FALL.
function Player:holdJumpAnimationFrame()
    if not self:isDashAnimationActive()
        and self.height_state_manager.state == "JUMP" and self.height_animation == "jump"
        and not self.sprite.playing and self.sprite.frames then
        self.sprite:setFrame(#self.sprite.frames)
    end
end

function Player:setState(state, ...)
    self.state_manager:setState(state, ...)
    if self.height_state_manager and self.height_animation then
        self:setHeightAnimation(self.height_animation)
    end
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

    self.history = { { x = x, y = y, z = self.z, time = self.history_time } }
    for i = 1, Game.max_followers do
        local idist = dist and (i * dist) or (((i * FOLLOW_DELAY) / (1 / 30)) * 4)
        table.insert(
            self.history,
            {
                x = x + (offset_x * idist),
                y = y + (offset_y * idist),
                z = self.z,
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

    if self.state_manager.state == "SLIDE_FREE" then
        return false
    end

    return true
end

--- Whether the player should decrease the invulnerability timer.
---
--- This returns `true` if the state's `shouldDecreaseInvuln` callback returns `true`, or if [`World:shouldBulletsHurt()`](lua://World.shouldBulletsHurt) returns `true`.
---@return boolean? decrease_invuln # `true` if the invulnerability timer should decrease.
function Player:shouldDecreaseInvuln()
    return Game.world:shouldBulletsHurt() or self.state_manager:call("shouldDecreaseInvuln")
end

function Player:isMovementEnabled()
    return not OVERLAY_OPEN
        and not Game.lock_movement
        and self.state ~= "SLIDE_LOCK"
        and Game.state == "OVERWORLD"
        and self.world.state == "GAMEPLAY"
        and self.hurt_timer == 0
        and Game.world.door_delay == 0
        and not self.attacking
        and not self.splatted
        and not self:isPitRecovering()
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
    self:setPlatformingEnabled(Game.world.map.platforming)

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

function Player:isSliding()
    local state = self.state_manager.state
    return state == "SLIDE" or state == "SLIDE_LOCK" or state == "SLIDE_FREE"
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
        table.insert(self.history, { x = self.x, y = self.y, z = self.z, time = 0 })
    end

    local moved = self.x ~= self.last_move_x or self.y ~= self.last_move_y or self.z ~= self.last_move_z

    local auto = self.auto_moving

    if moved then
        self.history_time = self.history_time + DT

        table.insert(
            self.history,
            1,
            {
                x = self.x,
                y = self.y,
                z = self.z,
                facing = self:getFacing(),
                time = self.history_time,
                state = self.state_manager.state,
                state_args = self.state_manager.args,
                height_state = self.height_state_manager.state,
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
    self.last_move_z = self.z
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

    local movement_start_x, movement_start_y = self.x, self.y
    self.state_manager:update()
    self:validateHeightMovement(movement_start_x, movement_start_y)

    self:updateHeight()

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
    self:holdJumpAnimationFrame()
end

function Player:preDraw(dont_transform)
    super.preDraw(self, dont_transform)

    self.state_manager:call("preDraw", dont_transform)
end

function Player:drawDebug()
    local col = self.interact_collider[self:getFacing()]
    col:draw(1, 1, 0, 0.5)
end

function Player:shouldDrawHeightShadow()
    return self.platforming_enabled and self.shadow_z ~= nil
        and not self._drawing_afterimage
end

function Player:getHeightShadowOffset()
    return math.max(self.z - self.shadow_z, 0)
end

function Player:getHeightShadowAlpha()
    return MathUtils.clamp(0.35 - self:getHeightShadowOffset() / 400, 0.1, 0.35)
end

function Player:draw()
    self.state_manager:call("drawUnderPlayer")

    local r, g, b, a = self:getColor()
    local use_alpha = a

    if self.state == "CLIMB" and Game.inv_frames > 0 then
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
