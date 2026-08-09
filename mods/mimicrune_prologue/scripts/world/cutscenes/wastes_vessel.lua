local HOLD_TIME = 2.25
local ABSORBED_WAIT = 2.5
local VESSEL_PILE_COLLIDER_ID = 118
local MAX_CONTROL_SPAWN_NUDGE = 48
local AMBITION_LUNGE_OVERSHOOT = 32

local function setSoulControl(soul, enabled)
    soul.can_move = enabled
    soul.is_active = enabled
end

local function hideSoul(soul)
    setSoulControl(soul, false)
    soul.visible = false
    if soul.height_shadow then soul.height_shadow.visible = false end
end

local function spawnHeartBurst(vessel)
    Assets.playSound("hurt")
    Assets.playSound("grab")
    local burst = HeartBurst(
        vessel.x,
        vessel.y - (vessel.z or 0) - vessel.height + 2,
        { Game:getSoulColor() }
    )
    burst.layer = (vessel.layer or Game.world.map.object_layer) + 0.02
    Game.world:addChild(burst)
end

local function playAbsorb(cutscene, vessel, animation, burst_frame)
    local finished = false
    local burst_spawned = false
    vessel:setAnimation(animation, function() finished = true end)
    cutscene:wait(function()
        if not burst_spawned and vessel.sprite.frame >= burst_frame then
            burst_spawned = true
            spawnHeartBurst(vessel)
            vessel:shake(2, 0)
        end
        return finished
    end)
end

local function movePlayerClearOfPile(scene_map, player)
    local pile_collider
    for _, collider in ipairs(scene_map.collision or {}) do
        if collider.map_object_id == VESSEL_PILE_COLLIDER_ID then
            pile_collider = collider
            break
        end
    end
    if not pile_collider or not player.collider then return end

    local moved = 0
    Object.uncache(player)
    while moved < MAX_CONTROL_SPAWN_NUDGE
        and player.collider:collidesWith3D(pile_collider) do
        player.y = player.y + 1
        moved = moved + 1
        Object.uncache(player)
    end

    if moved > 0 then
        player.spawn_x, player.spawn_y, player.spawn_z =
            player.x, player.y, player.z
        player.last_safe_x, player.last_safe_y, player.last_safe_z =
            player.x, player.y, player.z
    end
end

local function finishAwakening(cutscene, scene_map, vessel, soul, final_sprite)
    vessel:setSprite(final_sprite or "intro/absorbed")
    cutscene:wait(ABSORBED_WAIT)
    vessel:shake(1, 0)
    cutscene:wait(1)

    if not Game:hasPartyMember("vessel") then
        Game:addPartyMember("vessel")
    end
    vessel.party = "vessel"
    vessel:setFlag("dont_load", true)
    local player = vessel:convertToPlayer()
    player:setFacing("down")
    player:resetSprite()
    movePlayerClearOfPile(scene_map, player)

    if soul.parent then soul:remove() end
    Game:setFlag("plot", math.max(
        Game:getFlag("plot", PLOT.intro_wastes),
        PLOT.intro_vessel
    ))
    scene_map.vessel_intro_state = "complete"
    Game.world:setCameraAttached(true)
end

local function captureKindness(cutscene, vessel, soul)
    hideSoul(soul)
    vessel.solid = false
    cutscene:playSound("bump")
    cutscene:wait(cutscene:setAnimation(vessel, "intro/kindness/gentle_grab"))
    vessel:setSprite("intro/kindness/gentle_hold")
    cutscene:wait(HOLD_TIME)
    playAbsorb(cutscene, vessel, "intro/kindness/gentle_absorb", 5)
end

local function captureMindOrVoice(cutscene, scene_map, vessel, soul, gift)
    hideSoul(soul)
    vessel.solid = false
    if gift == "voice" then scene_map:stopVesselVoice() end
    cutscene:playSound("hurt")
    cutscene:playSound("grab")
    cutscene:wait(cutscene:setAnimation(vessel, "intro/snatch"))
    vessel:setSprite("intro/hold_soul")
    cutscene:wait(HOLD_TIME)
    playAbsorb(cutscene, vessel, "intro/absorb", 5)
end

local function captureBravery(cutscene, vessel, soul)
    hideSoul(soul)
    vessel.solid = false
    cutscene:playSound("hurt")
    cutscene:playSound("grab")
    playAbsorb(cutscene, vessel, "intro/bravery/snatch_and_absorb", 6)
end

local function captureAmbition(cutscene, vessel, soul)
    setSoulControl(soul, false)
    vessel.solid = false
    cutscene:playSound("jump")
    vessel:setAnimation("intro/ambition/tackle")

    local start_x, start_y, start_z = vessel.x, vessel.y, vessel.z or 0
    local soul_x, soul_y, target_z = soul.x, soul.y, soul.z or 0
    local approach_x, approach_y = soul_x - start_x, soul_y - start_y
    local approach_distance = MathUtils.dist(0, 0, approach_x, approach_y)
    local direction_x, direction_y = 0, 1
    if approach_distance > 0 then
        direction_x = approach_x / approach_distance
        direction_y = approach_y / approach_distance
    end
    local target_x = soul_x + direction_x * AMBITION_LUNGE_OVERSHOOT
    local target_y = soul_y + direction_y * AMBITION_LUNGE_OVERSHOOT
    local grab_progress = approach_distance
        / (approach_distance + AMBITION_LUNGE_OVERSHOOT)
    local duration = 0.55
    local landed = false
    local soul_hidden = false
    local function grabSoul()
        if soul_hidden then return end
        soul_hidden = true
        hideSoul(soul)
        Assets.playSound("grab")
    end
    Game.world.timer:during(duration, function(remaining)
        local progress = MathUtils.clamp((duration - remaining) / duration, 0, 1)
        vessel.x = MathUtils.lerp(start_x, target_x, progress)
        vessel.y = MathUtils.lerp(start_y, target_y, progress)
        vessel.z = MathUtils.lerp(start_z, target_z, progress)
            + math.sin(progress * math.pi) * 34
        if not soul_hidden and progress >= grab_progress then
            grabSoul()
        end
    end, function()
        vessel:setPosition(target_x, target_y)
        vessel.z = target_z
        grabSoul()
        landed = true
    end)
    cutscene:wait(function() return landed end)

    cutscene:playSound("impact")
    vessel:setSprite("intro/ambition/land")
    vessel:shake(2, 1)
    cutscene:wait(0.75)
    playAbsorb(cutscene, vessel, "intro/ambition/absorb_splat", 3)
end

return {
    ---@param cutscene WorldCutscene
    ---@param scene_map maps.wastes_vessel
    ---@param vessel NPC
    ---@param soul WorldSoul
    ---@param gift string
    spot = function(cutscene, scene_map, vessel, soul, gift)
        if not vessel or not soul then return end
        setSoulControl(soul, true)
        cutscene:enableMovement()
        cutscene:wait(cutscene:setAnimation(vessel, "intro/spotted_soul"))

        if gift == "kindness" or gift == "bravery" then
            vessel:setSprite("intro/watching")
            cutscene:wait(0.75)
            cutscene:wait(cutscene:setAnimation(vessel, "intro/reach_out"))
            if gift == "kindness" then
                vessel:setSprite("intro/reaching")
            else
                vessel:setAnimation("intro/bravery/wave")
            end
        elseif gift == "mind" then
            vessel:setSprite("intro/mind/waiting")
        elseif gift == "ambition" then
            vessel:setAnimation("intro/ambition/tense")
        elseif gift == "voice" then
            vessel:setAnimation("intro/voice/sing")
            scene_map:beginVesselVoice(vessel)
        else
            error("Unknown Vessel gift branch: " .. tostring(gift))
        end

        scene_map.vessel_intro_state = "waiting_capture"
        setSoulControl(soul, true)
    end,

    ---@param cutscene WorldCutscene
    ---@param scene_map maps.wastes_vessel
    ---@param vessel NPC
    ---@param soul WorldSoul
    ---@param gift string
    capture = function(cutscene, scene_map, vessel, soul, gift)
        if not vessel or not soul then return end

        if gift == "kindness" then
            captureKindness(cutscene, vessel, soul)
        elseif gift == "mind" or gift == "voice" then
            captureMindOrVoice(cutscene, scene_map, vessel, soul, gift)
        elseif gift == "ambition" then
            captureAmbition(cutscene, vessel, soul)
        elseif gift == "bravery" then
            captureBravery(cutscene, vessel, soul)
        else
            error("Unknown Vessel gift branch: " .. tostring(gift))
        end

        local final_sprite = gift == "ambition"
            and "intro/ambition/absorbed_splat" or "intro/absorbed"
        finishAwakening(cutscene, scene_map, vessel, soul, final_sprite)
    end
}
