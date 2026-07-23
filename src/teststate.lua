local Testing = {}

function Testing:enter()
    if Kristal.Args["test"] and Kristal.Args["test"][1] == "platforming" then
        local success, message = xpcall(function()
            self:runPlatformingTests()
        end, debug.traceback)
        if not success then
            print(message)
            love.event.quit(1)
        end
        return
    end

    self.stage = Stage()
    self.font = Assets.getFont("main")

    self.state = "MAIN"

    self.text = Text("The quick brown fox jumps over the lazy dog.", 0, 240 + 32, {
        ["align"] = "center"
    })
    self.stage:addChild(self.text)
end

function Testing:runPlatformingTests()
    local function expect(value, message)
        if not value then error("Platforming test failed: " .. message, 2) end
    end

    local root = Object()
    root.z = 5
    local child = Object()
    child.z = 7
    root:addChild(child)
    expect(child:getFullZ() == 12, "parent and child Z should accumulate")

    local logical_transform = love.math.newTransform()
    child:applyTransformTo(logical_transform)
    local _, logical_y = logical_transform:transformPoint(0, 0)
    local visual_transform = love.math.newTransform()
    child:applyVisualTransformTo(visual_transform)
    local _, visual_y = visual_transform:transformPoint(0, 0)
    expect(logical_y == 0 and visual_y == -7, "Z projection should affect drawing but not logical transforms")
    local _, full_visual_y = child:getFullVisualTransform():transformPoint(0, 0)
    expect(full_visual_y == -12,
        "visual snapshots should include the projected Z of the complete object hierarchy")

    local a_parent, b_parent = Object(), Object()
    local a = Hitbox(a_parent, 0, 0, 10, 10)
    local b = Hitbox(b_parent, 0, 0, 10, 10)
    a_parent.collider, b_parent.collider = a, b

    a_parent.z, b_parent.z = 0, 10
    expect(a:collidesWith(b), "default collision should remain two-dimensional")
    expect(not a:collidesWith3D(b), "separated zero-depth colliders should not collide in 3D")

    b_parent.z = 0
    expect(a:collidesWith3D(b), "zero-depth colliders at the same Z should collide")

    a.depth = 20
    expect(a:collidesWith3D(b), "a zero-depth slice should collide inside a positive-depth body")

    local platform_parent = Object()
    local platform = Hitbox(platform_parent, 0, 0, 20, 20)
    platform.depth = 32
    platform.supports = true
    platform_parent.collider = platform

    a_parent.z = 32
    expect(not a:collidesWith3D(platform), "a body touching a platform top should not side-collide")
    a_parent.z = 20
    expect(a:collidesWith3D(platform), "a body inside a platform volume should collide")

    local group_child = Hitbox(platform_parent, 0, 0, 20, 20)
    group_child.depth = 32
    local group = ColliderGroup(platform_parent, { group_child })
    a_parent.z = 32
    expect(not group:collidesWith3D(a), "collider groups should respect child Z bounds")
    a_parent.z = 20
    expect(group:collidesWith3D(a), "collider groups should test child volumes in 3D")

    local probe_parent = Object()
    local probe = Hitbox(probe_parent, 2, 2, 4, 4)
    local fake_world = setmetatable({
        map = { pits = {} },
        surfaces = { platform }
    }, { __index = World })
    function fake_world:getCollision() return self.surfaces end

    a_parent.x, a_parent.y, a_parent.z = 5, -32, 0
    expect(not a:collidesWith(platform)
        and fake_world:checkMovementCollision3D(a),
        "a tall solid's projected north face must block entry below its top")
    a_parent.z = 32
    expect(not fake_world:checkMovementCollision3D(a),
        "the projected north face must stop blocking once the mover reaches the top")
    a_parent.y, a_parent.z = 15, 32
    expect(not fake_world:checkMovementCollision3D(a),
        "standing on a solid must still allow movement off its downward edge")
    a_parent.z = 31
    expect(not fake_world:checkMovementCollision3D(a, false, platform),
        "a departed solid must remain ignored while falling clear of its downward edge")

    a_parent.z = 40
    expect(fake_world:checkCollision(a), "world collision should stay two-dimensional by default")
    expect(not fake_world:checkCollision3D(a), "world 3D collision should be explicitly requested")

    local support_z, support = fake_world:getSupportAt(probe, 32)
    expect(support_z == 32 and support == platform, "support lookup should find a platform top")

    local landing_z, landing = fake_world:getLandingSurface(probe, 40, 20)
    expect(landing_z == 32 and landing == platform, "landing sweep should find the highest crossed surface")
    landing_z = fake_world:getLandingSurface(probe, 32, 31, nil, nil, platform)
    expect(landing_z == nil,
        "walking off a platform must not immediately snap back to the same-height top")
    landing_z = fake_world:getLandingSurface(probe, 40, 20, nil, nil, platform)
    expect(landing_z == 32,
        "a later fall from above should still be able to land back on the departed platform")

    fake_world.surfaces = {}
    landing_z = fake_world:getLandingSurface(probe, 5, -5)
    expect(landing_z == 0, "ordinary empty space should land on implicit z=0 ground")
    landing_z = fake_world:getLandingSurface(probe, -5, -10)
    expect(landing_z == 0,
        "valid base ground should catch a fall after a blocking wall has been cleared")
    expect(not fake_world:isPitFallAt(probe),
        "ordinary non-pit space must not trigger out-of-bounds recovery")

    local tile_map = {
        width = 2, height = 1, tile_width = 40, tile_height = 40,
        pits = {}, collision = {}, enemy_collision = {}, empty_tile_pit = true,
        decodeTileData = function(_, packed) return packed end
    }
    local ground_tiles = TileLayer(tile_map, {
        width = 2, height = 1, data = { 1, 0 }
    })
    ground_tiles.provides_ground = true
    tile_map.tile_layers = { ground_tiles }
    local tile_world = setmetatable({ map = tile_map, children = {} }, { __index = World })
    probe_parent.x = 0
    expect(tile_world:hasImplicitGroundAt(probe),
        "a non-empty tile should provide implicit ground when empty tiles are pits")
    probe_parent.x = 40
    expect(not tile_world:hasImplicitGroundAt(probe),
        "an empty tile should remove implicit ground when the map opts in")
    expect(tile_world:isPitFallAt(probe),
        "an opted-in empty tile should trigger pit recovery")
    probe_parent.x = 0
    expect(not tile_world:isPitFallAt(probe),
        "a non-empty ground tile must not be treated as a pit")

    local pit = Hitbox(probe_parent, 0, 0, 20, 20)
    fake_world.map.pits = { pit }
    landing_z = fake_world:getLandingSurface(probe, 5, -5)
    expect(landing_z == nil, "an explicit pit should suppress implicit ground")
    expect(fake_world:isPitFallAt(probe),
        "an explicit pit should trigger pit recovery")

    local authored = MapUtils.colliderFromShape(probe_parent, {
        shape = "rectangle", width = 8, height = 8
    }, 0, 0, { z = 4, depth = 12 })
    expect(authored.z == 4 and authored.depth == 12 and authored.supports,
        "authored positive-depth colliders should expose a supported top surface")

    local runtime_map = Map(nil, {
        __map_reader = EditorMapReader,
        properties = { platforming = true, empty_tile_pit = true },
        layers = {}
    })
    expect(runtime_map.platforming and runtime_map.empty_tile_pit,
        "runtime map initialization should preserve authored platforming ground rules")

    local vessel = Registry.createActor("vessel")
    expect(vessel.jump_strength == 8 and vessel.jump_windup == 1 / 15,
        "the Vessel should use its tuned jump height and one-frame squat wind-up")
    local jump_pose
    local windup_player = {
        jump_strength = vessel.jump_strength,
        jump_windup = vessel.jump_windup,
        setHeightAnimation = function(_, animation) jump_pose = animation end
    }
    Player.beginHeightJump(windup_player, "GROUNDED", vessel.jump_strength)
    expect(windup_player.z_velocity == 0
        and windup_player.pending_jump_strength == vessel.jump_strength
        and windup_player.jump_windup_timer == vessel.jump_windup
        and jump_pose == "jump",
        "the jump animation should begin before vertical launch movement")

    local held_frame
    Player.holdJumpAnimationFrame({
        height_state_manager = { state = "JUMP" },
        height_animation = "jump",
        isDashAnimationActive = function() return false end,
        sprite = {
            playing = false,
            frames = { 1, 2, 3 },
            setFrame = function(_, frame) held_frame = frame end
        }
    })
    expect(held_frame == 3,
        "a completed jump animation should hold its final frame through the upward arc")
    held_frame = nil
    Player.holdJumpAnimationFrame({
        height_state_manager = { state = "JUMP" },
        height_animation = "jump",
        isDashAnimationActive = function() return true end,
        sprite = {
            playing = false,
            frames = { 1, 2, 3 },
            setFrame = function(_, frame) held_frame = frame end
        }
    })
    expect(held_frame == nil,
        "the jump frame hold must not overwrite a dash sprite in midair")

    local vessel_sprite = vessel:createSprite()
    vessel_sprite:setFacing("down")
    vessel_sprite:setAnimation("jump")
    for _ = 1, 12 do vessel_sprite:update() end
    expect(#vessel_sprite.frames == 3 and vessel_sprite.frame == 3
        and vessel_sprite.playing,
        "the resolved directional Vessel jump should remain active on its third frame")

    local one_way_surface = MapUtils.colliderFromShape(probe_parent, {
        shape = "rectangle", width = 20, height = 20
    }, 0, 0, { z = 40, collision_role = "surface" })
    local surface_bottom, surface_top = one_way_surface:getZBounds()
    expect(one_way_surface.supports and one_way_surface.one_way
        and surface_bottom == 40 and surface_top == 40,
        "one-way platform shapes should create a landing surface at their authored Z")
    fake_world.surfaces = { one_way_surface }
    a_parent.x, a_parent.y, a_parent.z = 0, 0, 0
    expect(not fake_world:checkCollision3D(a)
        and fake_world:checkMovementCollision3D(a),
        "horizontal movement must not enter a support footprint above the player's feet")
    expect(not fake_world:checkMovementCollision3D(a, false, one_way_surface),
        "an explicitly ignored elevated support must remain passable")
    a_parent.z = 40
    expect(not fake_world:checkMovementCollision3D(a),
        "a support footprint should become traversable once the player reaches its top")
    a_parent.z = 41
    expect(not fake_world:checkMovementCollision3D(a)
        and fake_world:checkMovementCollision3D(a, false, nil, 39),
        "a dash must not enter a platform when this frame's fall ends below its top")
    expect(not fake_world:hasImplicitGroundAt(a, 0),
        "implicit z=0 ground must not exist beneath an elevated support footprint")

    local guarded_player = Object(0, 0)
    guarded_player.z = 0
    guarded_player.collider = Hitbox(guarded_player, 0, 0, 10, 10)
    guarded_player.collider.depth = 20
    guarded_player.support_collider = Hitbox(guarded_player, 2, 2, 6, 6)
    guarded_player.world = fake_world
    guarded_player.platforming_enabled = true
    guarded_player.enemy_collision = false
    guarded_player.noclip = false
    guarded_player.fall_through_colliders = {}
    guarded_player.departed_ground_collider = nil
    guarded_player.height_state_manager = { state = "GROUNDED" }
    guarded_player.getHeightState = Player.getHeightState
    guarded_player.getDepartedGroundCollisionIgnore = Player.getDepartedGroundCollisionIgnore
    guarded_player.getMovementHeightCollisionIgnore = Player.getMovementHeightCollisionIgnore
    guarded_player.getMovementCollisionZ = Player.getMovementCollisionZ
    expect(not Player.validateHeightMovement(guarded_player, -20, 0)
        and guarded_player.x == -20,
        "a final movement guard must roll back any position beneath an elevated support")

    fake_world.map.pits = {}
    fake_world.surfaces = { platform }
    local edge_probe = Hitbox(probe_parent, 18.5, 2, 4, 4)
    expect(edge_probe:collidesWith(platform)
        and fake_world:getLandingSurface(edge_probe, 40, 20) == nil,
        "overlapping only a platform edge should not snap the player back onto its top")

    local blocking_wall = Hitbox(platform_parent, 0, 0, 20, 20)
    blocking_wall.z, blocking_wall.depth = 32, 40
    blocking_wall.supports, blocking_wall.one_way = false, false
    local body = Hitbox(probe_parent, 2, 2, 4, 4)
    body.depth = 20
    fake_world.surfaces = { platform, blocking_wall }
    expect(fake_world:getLandingSurface(probe, 40, 20, body) == nil,
        "landing should be rejected when the player's body would be inside a wall")
    expect(fake_world:getGroundZAt(probe, 40, body) == nil,
        "the shadow must not advertise a surface that landing rejects as inside a wall")

    local ledge_parent = Object()
    ledge_parent.x, ledge_parent.z = 21, 31
    local ledge_body = Hitbox(ledge_parent, -4, 2, 8, 8)
    ledge_body.depth = 20
    local ledge_support = Hitbox(ledge_parent, -2, 4, 4, 4)
    fake_world.surfaces = { platform }
    local ledge_player = {
        world = fake_world,
        collider = ledge_body,
        support_collider = ledge_support,
        platforming_enabled = true,
        departed_ground_collider = platform,
        height_state_manager = { state = "FALL" },
        getHeightState = Player.getHeightState,
        isGrounded = Player.isGrounded,
        getDepartedGroundCollisionIgnore = Player.getDepartedGroundCollisionIgnore
    }
    expect(ledge_support:collidesWith(platform)
        and not fake_world:isSupportOver(ledge_support, platform)
        and Player.getHeightCollisionIgnore(ledge_player) == platform
        and fake_world:checkCollision3D(ledge_body, false)
        and not fake_world:checkCollision3D(ledge_body, false, platform),
        "walking off a solid ledge should use its support point, not its wider footprint")
    ledge_parent.x = 25
    expect(Player.getHeightCollisionIgnore(ledge_player) == platform
        and ledge_player.departed_ground_collider == platform,
        "an airborne departure must keep ignoring its old platform after clearing the body")
    ledge_parent.x = 21
    expect(Player.getHeightCollisionIgnore(ledge_player) == platform,
        "a rejected speculative move should leave the ledge exception armed")
    ledge_parent.x = 25
    Player.updateDepartedGroundCollision(ledge_player)
    expect(ledge_player.departed_ground_collider == platform,
        "the departed platform exemption must last for the complete airborne fall")
    ledge_player.height_state_manager.state = "LAND"
    Player.updateDepartedGroundCollision(ledge_player)
    expect(ledge_player.departed_ground_collider == nil,
        "the departed platform exemption should expire after landing clear of it")
    ledge_player.height_state_manager.state = "FALL"

    ledge_parent.x, ledge_parent.y, ledge_parent.z = 10, -20, 0
    ledge_player.departed_ground_collider = platform
    expect(not ledge_body:collidesWith(platform)
        and fake_world:isProjectedHeightCollision(ledge_body, platform, 0)
        and Player.getDepartedGroundCollisionIgnore(ledge_player) == platform,
        "walking upward off a ledge must ignore its projected face while falling clear")
    Player.updateDepartedGroundCollision(ledge_player)
    expect(ledge_player.departed_ground_collider == platform,
        "the upward ledge exception must not expire at the physical footprint edge")
    ledge_parent.y = -40
    Player.updateDepartedGroundCollision(ledge_player)
    expect(ledge_player.departed_ground_collider == platform,
        "clearing a projected face must not re-arm it later in the same fall")
    ledge_player.height_state_manager.state = "LAND"
    Player.updateDepartedGroundCollision(ledge_player)
    expect(ledge_player.departed_ground_collider == nil,
        "the upward ledge exception should expire on a clear landing")
    ledge_player.height_state_manager.state = "FALL"
    ledge_parent.y = 0
    ledge_player.departed_ground_collider = platform
    expect(fake_world:isSupportOver(ledge_support, platform)
        and Player.getDepartedGroundCollisionIgnore(ledge_player) == nil,
        "moving the airborne support point back over the old platform must restore collision")

    platform.depth = 120
    ledge_parent.x, ledge_parent.z = 21, 5
    ledge_player.departed_ground_collider = platform
    fake_world.map = tile_map
    expect(fake_world:getLandingSurface(ledge_support, 5, -5, ledge_body) == nil,
        "a tall departed platform should still reject an unqualified landing inside its wall")
    local base_z = fake_world:getLandingSurface(ledge_support, 5, -5,
        ledge_body, Player.getHeightCollisionIgnore(ledge_player))
    expect(base_z == 0,
        "falling beside a tall platform should find walkable base ground below it")
    ledge_player.height_state_manager.state = "LAND"
    expect(Player.getHeightCollisionIgnore(ledge_player) == platform,
        "the old platform side should remain passable until the landed body clears it")
    platform.depth = 32
    fake_world.map = { pits = {} }

    local airborne_runner = {
        last_collided_x = true,
        last_collided_y = false,
        platforming_enabled = true,
        isGrounded = function() return false end
    }
    expect(not Player.hasGroundedMovementCollision(airborne_runner),
        "contacting a new platform in midair should preserve horizontal run momentum")
    airborne_runner.isGrounded = function() return true end
    expect(Player.hasGroundedMovementCollision(airborne_runner),
        "running into a wall while grounded should still cancel momentum")

    local descent_wall = Hitbox(platform_parent, 0, 0, 20, 20)
    descent_wall.z, descent_wall.depth = 0, 120
    descent_wall.supports, descent_wall.one_way = false, false
    descent_wall.collision_role = "wall"
    fake_world.surfaces = { descent_wall }
    ledge_parent.x, ledge_parent.z = 10, 119
    ledge_player.departed_ground_collider = nil
    ledge_player.fall_through_colliders = {}
    ledge_player.height_state_manager.state = "FALL"
    Player.updateFallThroughColliders(ledge_player)
    local movement_ignores = Player.getMovementHeightCollisionIgnore(ledge_player)
    expect(ledge_player.fall_through_colliders[descent_wall]
        and fake_world:checkCollision3D(ledge_body, false)
        and not fake_world:checkCollision3D(ledge_body, false, movement_ignores),
        "a wall entered through vertical descent must not trap horizontal escape")
    expect(Player.getHeightCollisionIgnore(ledge_player) == nil,
        "a wall under the support point must remain non-landable")
    ledge_parent.x, ledge_parent.z = 21, 5
    local trailing_wall = Player.getHeightCollisionIgnore(ledge_player)
    expect(trailing_wall == descent_wall
        and fake_world:getLandingSurface(ledge_support, 5, -5,
            ledge_body, trailing_wall) == 0,
        "valid floor should catch the player once their support point clears the wall")
    local explicit_base_floor = Hitbox(platform_parent, 20, 0, 20, 20)
    explicit_base_floor.z, explicit_base_floor.depth = -40, 40
    explicit_base_floor.supports, explicit_base_floor.one_way = true, true
    explicit_base_floor.collision_role = "surface"
    fake_world.surfaces = { descent_wall, explicit_base_floor }
    fake_world.map = { pits = {}, empty_tile_pit = true, tile_layers = {} }
    expect(fake_world:getLandingSurface(ledge_support, -5, -10,
        ledge_body, trailing_wall) == 0,
        "an authored z=0 base floor should catch a player who already fell below it")
    fake_world.map = { pits = {} }

    local projected_wall = Hitbox(platform_parent, 0, 0, 20, 40)
    projected_wall.z, projected_wall.depth = 0, 120
    projected_wall.supports, projected_wall.one_way = false, false
    projected_wall.collision_role = "wall"
    local projected_floor = Hitbox(platform_parent, 0, 40, 20, 20)
    projected_floor.z, projected_floor.depth = -40, 40
    projected_floor.supports, projected_floor.one_way = true, true
    projected_floor.collision_role = "surface"
    fake_world.surfaces = { projected_wall, projected_floor }
    local projected_player = Object(10, 14)
    projected_player.z = -19
    projected_player.collider = Hitbox(projected_player, -4, 2, 8, 8)
    projected_player.collider.depth = 20
    projected_player.support_collider = Hitbox(projected_player, -2, 4, 4, 4)
    projected_player.world = fake_world
    projected_player.platforming_enabled = true
    projected_player.departed_ground_collider = nil
    projected_player.fall_through_colliders = { [projected_wall] = true }
    projected_player.getDepartedGroundCollisionIgnore = Player.getDepartedGroundCollisionIgnore
    projected_player.getHeightCollisionIgnore = Player.getHeightCollisionIgnore
    local projected_z, projected_surface = Player.tryProjectedBaseLanding(
        projected_player, -19, -21
    )
    expect(projected_z == 0 and projected_surface == projected_floor
        and projected_player.y == 34,
        "a fall rendered down a tall wall should project onto its adjacent base floor")
    projected_player.height_state_manager = { state = "LAND" }
    projected_player.getHeightState = Player.getHeightState
    projected_player.y = 35
    expect(Player.getMovementHeightCollisionIgnore(projected_player) == projected_wall,
        "a landed player may finish clearing a wall that still trails their body")
    projected_player.y = 33
    expect(Player.getMovementHeightCollisionIgnore(projected_player) == nil,
        "a landed player must not reverse through the wall they just fell past")
    projected_player.y = 34

    local recovered_from_unbounded_fall = false
    local stranded_ledge_player = {
        z = -79,
        z_velocity = -12,
        z_gravity = 0.6,
        max_fall_speed = 12,
        pit_fall_limit = -80,
        collider = ledge_body,
        support_collider = ledge_support,
        departed_ground_collider = nil,
        world = {
            getLandingSurface = function() return nil end
        },
        getHeightCollisionIgnore = function() return nil end,
        tryProjectedBaseLanding = function() return nil end,
        updateFallThroughColliders = function() end,
        recoverFromPit = function()
            recovered_from_unbounded_fall = true
        end
    }
    Player.updateHeightFall(stranded_ledge_player)
    expect(recovered_from_unbounded_fall,
        "falling past every legal floor beside a wall must recover instead of continuing forever")

    expect(Player.isPitRecovering({
        getHeightState = function() return "PIT_RECOVER" end
    }), "pit recovery should use a dedicated timed height state")
    expect(Player.shouldDrawHeightShadow({
        platforming_enabled = true, shadow_z = 40, z = 40
    }), "the platforming shadow should remain visible while grounded")

    local applied_height_animation
    local dash_animation_player = {
        state_manager = { state = "DASH" },
        actor = { getAnimation = function() return true end },
        setAnimation = function(_, animation) applied_height_animation = animation end,
        isDashAnimationActive = Player.isDashAnimationActive
    }
    Player.setHeightAnimation(dash_animation_player, "fall")
    expect(dash_animation_player.height_animation == "fall"
        and applied_height_animation == nil,
        "aerial state should be remembered without overriding an active dash sprite")
    local reset_during_dash = false
    dash_animation_player.resetSprite = function() reset_during_dash = true end
    Player.restoreGroundAnimation(dash_animation_player)
    expect(not reset_during_dash,
        "finishing a landing during a dash must not reset the dash sprite")
    dash_animation_player.height_animation = "fall"
    dash_animation_player.state_manager.state = "WALK"
    Player.setHeightAnimation(dash_animation_player, dash_animation_player.height_animation)
    expect(applied_height_animation == "fall",
        "the remembered aerial sprite should resume when the dash ends")

    local recovery_world = Object()
    local recovered_state
    local recovery_player = {
        world = recovery_world,
        z_velocity = -12,
        jump_windup_timer = 1,
        pending_jump_strength = 8,
        ground_collider = platform,
        departed_ground_collider = platform,
        pit_recovery_out_time = 26 / 30,
        pit_recovery_hold_time = 4 / 30,
        pit_recovery_in_time = 26 / 30,
        height_state_manager = {
            setState = function(_, state) recovered_state = state end
        },
        teleportFromPit = function(self) self.pit_recovery_teleported = true end,
        restoreGroundAnimation = function() end
    }
    Player.beginHeightPitRecovery(recovery_player)
    local recovery_fx = recovery_world:getFX("pit_recovery")
    expect(recovery_fx and recovery_fx.shader == Assets.getShader("goner_bleed"),
        "pit recovery should use the Goner Battle bleed shader")
    recovery_player.pit_recovery_timer = recovery_player.pit_recovery_out_time
        + recovery_player.pit_recovery_hold_time
    Player.updateHeightPitRecovery(recovery_player)
    expect(recovery_player.pit_recovery_teleported
        and recovery_player.pit_recovery_progress < 1,
        "pit recovery should teleport while obscured, then reveal the safe position")
    recovery_player.pit_recovery_timer = recovery_player.pit_recovery_out_time
        + recovery_player.pit_recovery_hold_time + recovery_player.pit_recovery_in_time
    Player.updateHeightPitRecovery(recovery_player)
    expect(recovered_state == "GROUNDED",
        "pit recovery should finish only after the timed reveal")
    Player.endHeightPitRecovery(recovery_player)
    expect(not recovery_world:getFX("pit_recovery"),
        "pit recovery should remove its transition effect when finished")

    local explicit_wall = MapUtils.colliderFromShape(probe_parent, {
        shape = "rectangle", width = 80, height = 12
    }, 0, 0, { z = 0, depth = 80, collision_role = "wall" })
    expect(explicit_wall.collision_role == "wall"
        and not explicit_wall.supports and not explicit_wall.one_way,
        "explicit walls should block across their Z range without creating a landing top")

    local editor_shape = EditorObject({
        properties = {}, __editor_property_types = {}
    }, { layer_type = Registry.getLayerType("collision") })
    expect(editor_shape.property_set:getProperty("z").type == "number"
        and editor_shape.property_set:getProperty("depth").type == "number",
        "map objects should expose typed Z and depth editor properties")
    expect(editor_shape.property_set:getProperty("pit").type == "boolean",
        "collision shapes should expose a typed pit editor property")
    expect(editor_shape.property_set:getProperty("collision_role").type == "choice"
        and editor_shape.property_set:getProperty("z").name == "Bottom Z"
        and editor_shape.property_set:getProperty("depth").name == "Solid Height",
        "collision shapes should expose clear wall, solid, surface, and pit authoring controls")

    local jump_forwarded = false
    local fake_editor = {
        live_document = {},
        game_preview_paused = false,
        consumed_editor_keys = {},
        tile_editing_mode = false,
        menu_bar = { onKeyPressed = function() return false end },
        dockspace = {
            focused_control = nil,
            context_menu = nil,
            onKeyPressed = function() return false end
        },
        preview_controller = {
            canForwardGameKeyboardInput = function() return true end
        },
        handleGameDebugKeyPressed = function() return false end,
        forwardGameKeyPressed = function()
            jump_forwarded = true
            return true
        end
    }
    Editor.onKeyPressed(fake_editor, "space", false)
    expect(jump_forwarded, "the editor should forward Space to an active game preview for jumping")

    local overlay_layer = {
        properties = {},
        objects = { {
            x = 16, y = 32, width = 16, height = 8, shape = "rectangle",
            properties = { depth = 12 }
        } }
    }
    local overlay = EditorLayerOverlay(overlay_layer, Registry.getLayerType("collision"), 0)
    local canvas = love.graphics.newCanvas(64, 64)
    love.graphics.setCanvas(canvas)
    love.graphics.origin()
    love.graphics.clear(0, 0, 0, 0)
    overlay:draw(1, 1)
    love.graphics.setCanvas()
    local image_data = canvas:newImageData()
    local found_projected_line = false
    for y = 0, 30 do
        for x = 0, 63 do
            local _, _, _, alpha = image_data:getPixel(x, y)
            if alpha > 0 then
                found_projected_line = true
                break
            end
        end
        if found_projected_line then break end
    end
    expect(found_projected_line, "editable collision shapes should render a compact elevation guide")

    print("Platforming tests passed")
    love.event.quit(0)
end

function Testing:update()
    if not self.stage then return end
    self.stage:update()
end

function Testing:draw()
    if not self.stage then return end
    Draw.setColor(1, 1, 1, 1)

    love.graphics.setFont(self.font)

    if self.state == "MAIN" then
        love.graphics.printf("~ テスティング ~", 0, 16, 640, "center")

        love.graphics.printf("The quick brown fox jumps over the lazy dog.", 0, 240, 640, "center")
    elseif self.state == "GAMEPAD" then
        love.graphics.printf("~ コントローラーテスト ~", 0, 16, 640, "center")
        self:drawGamepad()
    end

    Draw.setColor(COLORS.white)
    local tex = Assets.getTexture("kristal/lancer/wave_9")
    Draw.draw(tex, 320, 480, 0, 2, 2, tex:getWidth() / 2, tex:getHeight())

    self.stage:draw()
end

function Testing:drawGamepad()
    local radius = 40
    local circle_size = 10

    Draw.setColor(COLORS.ltgray)
    love.graphics.circle("line", 120, 418, radius)

    Draw.setColor(COLORS.white)
    love.graphics.circle("line", 120 + Input.gamepad_left_x * radius, 418 + Input.gamepad_left_y * radius, circle_size)

    local thing_x, thing_y = Input.getLeftThumbstick()

    Draw.setColor(COLORS.red)
    love.graphics.circle("line", 120 + thing_x * radius, 418 + thing_y * radius, circle_size)

    Draw.setColor(COLORS.white)

    Draw.setColor(Input.down("gamepad:left") and COLORS.white or COLORS.gray)
    love.graphics.print("[<]", 64, 400)
    Draw.setColor(Input.down("gamepad:down") and COLORS.white or COLORS.gray)
    love.graphics.print("[V]", 104, 426)
    Draw.setColor(Input.down("gamepad:right") and COLORS.white or COLORS.gray)
    love.graphics.print("[>]", 144, 400)
    Draw.setColor(Input.down("gamepad:up") and COLORS.white or COLORS.gray)
    love.graphics.print("[^]", 104, 374)


    Draw.setColor(Input.down("left") and COLORS.white or COLORS.gray)
    love.graphics.print("[<]", 466, 400)
    Draw.setColor(Input.down("down") and COLORS.white or COLORS.gray)
    love.graphics.print("[V]", 506, 400)
    Draw.setColor(Input.down("right") and COLORS.white or COLORS.gray)
    love.graphics.print("[>]", 546, 400)
    Draw.setColor(Input.down("up") and COLORS.white or COLORS.gray)
    love.graphics.print("[^]", 506, 374)
end

return Testing
