local HOLD_TIME = 2.25
local ABSORBED_WAIT = 2.5
local AMBITION_LUNGE_OVERSHOOT = 32
local GRAB_CAMERA_PAN_TIME = 0.65
local CONVERSION_CAMERA_PAN_TIME = 0.2
local HEART_BURST_Y_OFFSET = -18
local SPLAT_HEART_BURST_Y_OFFSET = -4

local function setSoulControl(soul, enabled)
    soul.can_move = enabled
    soul.is_active = enabled
end

local function hideSoul(soul)
    setSoulControl(soul, false)
    soul.visible = false
    if soul.height_shadow then soul.height_shadow.visible = false end
end

local function recenterCameraOnVessel(
    cutscene, vessel, focus_x, focus_y, focus_z
)
    if vessel.camera_recentering then return end
    vessel.camera_recentering = true

    local world = cutscene.world
    focus_x = focus_x or vessel.x
    focus_y = focus_y or vessel.y
    focus_z = focus_z or vessel.z or 0

    -- NPCs normally have no platforming camera offset. Give this Vessel the
    -- same elevation-aware target used by the Player it will become.
    vessel.getCameraTargetOffset = function(subject)
        return 0, -(subject.z or 0)
    end

    local origin_x, origin_y = vessel:getCameraOriginExact()
    local target_x, target_y = vessel:getRelativePos(
        origin_x, origin_y, world
    )
    target_x = target_x + focus_x - vessel.x
    target_y = target_y + focus_y - vessel.y - focus_z

    cutscene:detachCamera()
    world:setCameraTarget(vessel)
    world.camera:panTo(
        target_x, target_y, GRAB_CAMERA_PAN_TIME, "in-out-sine",
        function()
            if vessel.parent then world:setCameraAttached(true) end
        end
    )
end

local function spawnHeartBurst(vessel, y_offset)
    Assets.playSound("hurt")
    Assets.playSound("grab")
    local burst = HeartBurst(
        vessel.x,
        vessel.y - (vessel.z or 0) + (y_offset or HEART_BURST_Y_OFFSET),
        { Game:getSoulColor() }
    )
    burst.layer = (vessel.layer or Game.world.map.object_layer) + 0.02
    Game.world:addChild(burst)
end

local function playAbsorb(cutscene, vessel, animation, burst_frame, burst_y_offset)
    local finished = false
    local burst_spawned = false
    vessel:setAnimation(animation, function() finished = true end)
    cutscene:wait(function()
        if not burst_spawned and vessel.sprite.frame >= burst_frame then
            burst_spawned = true
            spawnHeartBurst(vessel, burst_y_offset)
            vessel:shake(2, 0)
        end
        return finished
    end)
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

    if soul.parent then soul:remove() end
    Game:setFlag("plot", math.max(
        Game:getFlag("plot", PLOT.intro_wastes),
        PLOT.intro_vessel
    ))
    scene_map.vessel_intro_state = "complete"
    Game.world:setCameraTarget(nil)
    cutscene:detachCamera()
    cutscene:wait(cutscene:attachCamera(CONVERSION_CAMERA_PAN_TIME))
end

local function captureKindness(cutscene, vessel, soul)
    hideSoul(soul)
    recenterCameraOnVessel(cutscene, vessel)
    vessel.solid = false
    cutscene:playSound("bump")
    cutscene:wait(cutscene:setAnimation(vessel, "intro/kindness/gentle_grab"))
    vessel:setSprite("intro/kindness/gentle_hold")
    cutscene:wait(HOLD_TIME)
    playAbsorb(cutscene, vessel, "intro/kindness/gentle_absorb", 5)
end

local function captureMindOrVoice(cutscene, scene_map, vessel, soul, gift)
    hideSoul(soul)
    recenterCameraOnVessel(cutscene, vessel)
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
    recenterCameraOnVessel(cutscene, vessel)
    vessel.solid = false
    cutscene:playSound("hurt")
    cutscene:playSound("grab")
    playAbsorb(cutscene, vessel, "intro/bravery/snatch_and_absorb", 6)
end

local function captureAmbition(cutscene, vessel, soul)
    setSoulControl(soul, false)
    vessel.solid = false
    local rando = MathUtils.randomInt(1, 101)
    if (rando == 1) then
        cutscene:playSound("foxyjumpscare", 0.75, 1.2)
    else
        cutscene:playSound("jump")
    end
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
        recenterCameraOnVessel(
            cutscene, vessel, target_x, target_y, target_z
        )
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
    playAbsorb(
        cutscene, vessel, "intro/ambition/absorb_splat", 3,
        SPLAT_HEART_BURST_Y_OFFSET
    )
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
