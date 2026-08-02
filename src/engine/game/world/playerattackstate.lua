---@class PlayerAttackState : StateClass
---@field player Player
---@overload fun(player: Player): PlayerAttackState
local PlayerAttackState, super = Class(StateClass)

function PlayerAttackState:init(player)
    self.player = player
    self.serial = 0
    self.stage = 0
    self.direction = "down"
    self.return_state = "WALK"
    self.phase = "idle"
    self.aerial = false
    self.collider = nil
    self.hit_anything = false
    self.hit_objects = {}
    self.lunge_distance = 0
    self.lunge_duration = 0
    self.lunge_elapsed = 0
    self.lunge_progress = 0
    self.afterimage_count = 0
    self.afterimage_max = 2
    self.afterimage_alpha = 0.25
    self.carry_x = 0
    self.carry_y = 0
    self.carry_duration = 0
    self.carry_elapsed = 0
end

function PlayerAttackState:registerEvents()
    self:registerEvent("enter", self.onEnter)
    self:registerEvent("update", self.onUpdate)
    self:registerEvent("leave", self.onExit)
    self:registerEvent("drawDebug", self.drawDebug)
    self:registerEvent("getDebugInfo", self.getDebugInfo)
end

function PlayerAttackState:getReturnState(old_state)
    if old_state == "RUN" or old_state == "DASH" and self.player.was_running then
        return "RUN"
    end
    return "WALK"
end

function PlayerAttackState:getMovementInput()
    local move_x, move_y = 0, 0
    if Input.down("left") then
        move_x = move_x - 1
    elseif Input.down("right") then
        move_x = move_x + 1
    end
    if Input.down("up") then
        move_y = move_y - 1
    elseif Input.down("down") then
        move_y = move_y + 1
    end

    local joy_x, joy_y = Input.getThumbstick("left")
    if joy_x ~= 0 or joy_y ~= 0 then
        move_x, move_y = joy_x, joy_y
    end
    return move_x, move_y
end

function PlayerAttackState:updateMovement()
    local player = self.player
    local move_x, move_y = self:getMovementInput()
    player.moving_x, player.moving_y = move_x, move_y

    if self.return_state == "RUN" and not Game:getFlag("simple_run", false) then
        player:move(
            move_x + player.run_momentum[1],
            move_y + player.run_momentum[2],
            player:getRunSpeed() * DTMULT
        )
    else
        local speed = self.return_state == "RUN"
            and player:getRunSpeed() or player:getBaseWalkSpeed()
        player:move(move_x, move_y, speed * DTMULT)
    end

    if self.carry_elapsed < self.carry_duration then
        local old_progress = self.carry_elapsed / self.carry_duration
        self.carry_elapsed = math.min(self.carry_elapsed + DT, self.carry_duration)
        local new_progress = self.carry_elapsed / self.carry_duration
        local strength = 1 - ((old_progress + new_progress) / 2)
        player:move(self.carry_x, self.carry_y, strength * DTMULT)
    end
end

function PlayerAttackState:spawnAfterImage()
    local afterimage = AbsoluteAfterImage(self.player, self.afterimage_alpha, 0.06)
    self.player.world:addChild(afterimage)
end

function PlayerAttackState:updateLunge()
    if self.lunge_progress >= 1 or self.lunge_distance <= 0 then return false end

    local old_progress = self.lunge_progress
    self.lunge_elapsed = math.min(self.lunge_elapsed + DT, self.lunge_duration)
    self.lunge_progress = self.lunge_duration > 0
        and self.lunge_elapsed / self.lunge_duration or 1
    local old_eased = Utils.ease(0, 1, old_progress, "out-cubic")
    local new_eased = Utils.ease(0, 1, self.lunge_progress, "out-cubic")
    local distance = self.lunge_distance * (new_eased - old_eased)
    if distance <= 0 then return false end

    local afterimage_index = math.floor(old_progress * self.afterimage_max)
    if self.afterimage_count <= afterimage_index
        and self.afterimage_count < self.afterimage_max then
        self:spawnAfterImage()
        self.afterimage_count = self.afterimage_count + 1
    end
    local direction_x, direction_y = Utils.getFacingVector(self.direction)
    self.player:move(direction_x, direction_y, distance, true)
    return true
end

function PlayerAttackState:hitTargets()
    local player = self.player
    local targets = {}

    Object.startCache()
    for _, object in ipairs(player.world.children) do
        if object.onHit and not self.hit_objects[object]
            and player:collidesWithAttackTarget(object, self.collider) then
            table.insert(targets, {
                object = object,
                distance = player:getAttackTargetDistance(object)
            })
        end
    end
    Object.endCache()

    table.sort(targets, function(a, b) return a.distance < b.distance end)
    for _, target in ipairs(targets) do
        self.hit_objects[target.object] = true
        self.hit_anything = target.object:onHit(player, self.direction)
            or self.hit_anything
    end
    player.attack_hit_anything = self.hit_anything
    return self.hit_anything
end

function PlayerAttackState:finishAnimation(serial)
    if serial ~= self.serial or self.player.state_manager.state ~= "ATTACK" then return end
    if self.aerial then
        self.player:setState(self.return_state)
        return
    end
    self.phase = "recovery"
    self.player.sprite:stop(true)
end

function PlayerAttackState:advanceCombo(aerial)
    if not aerial then
        self.player.attack_stage = self.player.attack_stage % 3 + 1
    end
    self.stage = self.player.attack_stage
    return self.stage
end

function PlayerAttackState:getCooldown(party, aerial, stage)
    local cooldown
    if aerial then
        cooldown = party.overworld_air_attack_cd
    elseif stage == 3 then
        cooldown = party.overworld_attack_finisher_cd
    else
        cooldown = party.overworld_attack_cd
    end
    return math.max(tonumber(cooldown) or 0, 0)
end

function PlayerAttackState:beginSwing()
    local player = self.player
    local party = Game.party[1]
    self.serial = self.serial + 1
    local serial = self.serial

    self.direction = player:getFacing()
    self.aerial = player.platforming_enabled and not player:isGrounded()
    self:advanceCombo(self.aerial)
    self.phase = "active"
    self.hit_anything = false
    self.hit_objects = {}
    player.attack_hit_anything = false
    player.time_since_attack = 0
    player.attack_buffer = self:getCooldown(party, self.aerial, self.stage)

    self.lunge_distance = math.max(tonumber(party.attack_distance) or 0, 0)
    self.lunge_duration = math.max(
        tonumber(party.overworld_attack_lunge_time) or 0.15, 0)
    self.lunge_elapsed = 0
    self.lunge_progress = self.lunge_distance > 0 and 0 or 1
    self.afterimage_count = 0

    self.collider = self.aerial
        and player.air_attack_collider or player.attack_collider[self.direction]
    if self.aerial then
        self.collider.radius = math.max(
            tonumber(party.overworld_air_attack_radius) or 20, 0)
    end

    self:hitTargets()
    Assets.playSound(
        party.attack_sound or (Game:isLight() and "swipe" or "laz_c"),
        1, party.attack_pitch or 1)

    local animation
    if self.aerial then
        animation = player.actor:getAnimation("attack_air")
            and "attack_air" or "attack" .. math.max(self.stage, 1)
    else
        animation = "attack" .. self.stage
    end
    player.sprite:setAnimation(animation, function()
        self:finishAnimation(serial)
    end)
end

function PlayerAttackState:onEnter(old_state, settings)
    local player = self.player
    settings = settings or {}
    self.return_state = settings.return_state or self:getReturnState(old_state)
    self.carry_x = tonumber(settings.carry_x) or 0
    self.carry_y = tonumber(settings.carry_y) or 0
    self.carry_duration = math.max(tonumber(settings.carry_duration) or 0, 0)
    self.carry_elapsed = 0
    player.attacking = true
    self:beginSwing()
end

function PlayerAttackState:onUpdate()
    self:updateMovement()
    self:updateLunge()
    if self.phase == "active" then self:hitTargets() end

    local grace = math.max(
        tonumber(Game.party[1].overworld_attack_grace) or 3, 0)
    if self.phase == "recovery" and self.player.time_since_attack >= grace then
        self.player:setState(self.return_state)
    end
end

function PlayerAttackState:onExit()
    self.serial = self.serial + 1
    self.phase = "idle"
    self.collider = nil
    self.player.attacking = false
    self.player.attack_stage = 0
    self.player:resetSprite()
end

function PlayerAttackState:holdAnimationFrame()
    local sprite = self.player.sprite
    if not self.aerial and self.phase == "recovery" and sprite.frames then
        sprite:setFrame(#sprite.frames)
    end
end

function PlayerAttackState:drawDebug()
    if self.collider then self.collider:draw(1, 0.2, 0.2, 0.65) end
end

function PlayerAttackState:getDebugInfo(info)
    table.insert(info, "Attack phase: " .. tostring(self.phase))
    table.insert(info, "Attack stage: " .. tostring(self.stage))
    table.insert(info, "Attack aerial: " .. tostring(self.aerial))
    table.insert(info, "Attack direction: " .. tostring(self.direction))
    table.insert(info, "Attack hit: " .. tostring(self.hit_anything))
end

return PlayerAttackState
