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

    (function()
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
        expect(logical_y == 0 and visual_y == -7,
            "Z projection should affect drawing but not logical transforms")
        local _, full_visual_y =
            child:getFullVisualTransform():transformPoint(0, 0)
        expect(full_visual_y == -12,
            "visual snapshots should include the projected Z of the complete object hierarchy")

        local height_transform = HeightTransform()
        height_transform:translate(10, 20, 5)
        local ground_x, ground_y, ground_z =
            height_transform:transformPoint3D(2, 3, 4)
        local projected_x, projected_y =
            height_transform:transformVisualPoint(2, 3, 4)
        local inverse_x, inverse_y =
            height_transform:inverseTransformVisualPoint(projected_x, projected_y, 4)
        expect(ground_x == 12 and ground_y == 23 and ground_z == 9
            and projected_x == 12 and projected_y == 14
            and inverse_x == 2 and inverse_y == 3,
            "height transforms should keep logical XYZ, projection, and inverse projection coherent")

        local parent_height = HeightTransform()
        parent_height:translate(100, 200, 10)
        parent_height:rotate(math.pi / 2)
        local local_height = HeightTransform()
        local_height:translate(5, 6, 2)
        local composed_height = parent_height:clone():apply(local_height)
        local sequential_height = HeightTransform()
        sequential_height:translate(100, 200, 10)
        sequential_height:rotate(math.pi / 2)
        sequential_height:translate(5, 6, 2)
        local composed_x, composed_y = composed_height:transformVisualPoint()
        local sequential_x, sequential_y = sequential_height:transformVisualPoint()
        expect(math.abs(composed_x - sequential_x) < 0.001
            and math.abs(composed_y - sequential_y) < 0.001
            and composed_height:getZ() == 12,
            "height-transform composition should preserve projected hierarchy and accumulated Z")

        local full_height = child:getFullHeightTransform()
        local full_ground_x, full_ground_y, full_ground_z =
            full_height:transformPoint3D()
        local full_projected_x, full_projected_y =
            full_height:transformVisualPoint()
        expect(full_ground_x == 0 and full_ground_y == 0 and full_ground_z == 12
            and full_projected_x == 0 and full_projected_y == -12,
            "objects should expose one complete logical, visual, and elevation transform")

        local billboard_depth = HeightTransform():getDepthParameters({
            anchor_x = 0, anchor_y = 100, z = 40
        })
        local face_depth = HeightTransform():getDepthParameters({
            anchor_x = 0, anchor_y = 100,
            face_x = 0, face_y = 100, face_top_z = 60
        })
        expect(billboard_depth.anchor_y == 100 and billboard_depth.sort_depth == 140
            and face_depth.face_ground_y == 100 and face_depth.face_top_y == 40
            and face_depth.height_pixels == 60 and face_depth.sort_depth == 160,
            "height transforms should be the single source of billboard and terrain-face depth")
    end)()

    do
        local function solidCanvas(r, g, b, a, x, width)
            local canvas = love.graphics.newCanvas(16, 16)
            love.graphics.setCanvas(canvas)
            love.graphics.origin()
            love.graphics.clear(0, 0, 0, 0)
            love.graphics.setColor(r, g, b, a)
            love.graphics.rectangle("fill", x or 0, 0, width or 16, 16)
            love.graphics.setColor(1, 1, 1, 1)
            love.graphics.setCanvas()
            return canvas
        end
        local output = love.graphics.newCanvas(16, 16)
        local depth = love.graphics.newCanvas(16, 16, {
            format = "depth24stencil8", readable = false
        })
        local blue = solidCanvas(0, 0, 1, 1)
        local red = solidCanvas(1, 0, 0, 1)
        local green = solidCanvas(0, 1, 0, 0.5)
        local half_blue = solidCanvas(0, 0, 1, 1, 8, 8)
        local renderer = setmetatable({}, { __index = World })
        local function billboard(anchor_y, depth_offset)
            return HeightTransform():getDepthParameters({
                anchor_x = 0,
                anchor_y = anchor_y,
                depth_offset = depth_offset or 0
            })
        end

        love.graphics.setCanvas({ output, depthstencil = depth })
        love.graphics.clear(0, 0, 0, 0, false, 0)
        renderer:compositeHeightDepthCanvas(blue, billboard(20), true)
        renderer:compositeHeightDepthCanvas(red, billboard(10), true)
        renderer:compositeHeightDepthCanvas(green, billboard(30), false)
        love.graphics.setCanvas()
        local data = output:newImageData()
        local out_r, out_g, out_b, out_a = data:getPixel(8, 8)
        expect(out_r < 0.05 and out_g > 0.45 and out_g < 0.55
            and out_b > 0.45 and out_b < 0.55 and out_a > 0.95,
            "GPU height depth should reject a later far sprite and correctly blend a translucent near sprite")

        love.graphics.setCanvas({ output, depthstencil = depth })
        love.graphics.clear(0, 0, 0, 0, false, 0)
        renderer:compositeHeightDepthCanvas(red, billboard(10), true)
        renderer:compositeHeightDepthCanvas(half_blue, billboard(20), true)
        renderer:compositeHeightDepthCanvas(
            green, billboard(20, -0.25), false
        )
        love.graphics.setCanvas()
        data = output:newImageData()
        local floor_r, floor_g, floor_b = data:getPixel(4, 8)
        local player_r, player_g, player_b = data:getPixel(12, 8)
        expect(floor_r > 0.45 and floor_r < 0.55
            and floor_g > 0.45 and floor_g < 0.55 and floor_b < 0.05
            and player_r < 0.05 and player_g < 0.05 and player_b > 0.95,
            string.format(
                "attached translucent effects should remain visible on the floor but stay behind equal-depth owner pixels (floor %.3f,%.3f,%.3f; player %.3f,%.3f,%.3f)",
                floor_r, floor_g, floor_b, player_r, player_g, player_b
            ))
        output:release()
        depth:release()
        blue:release()
        red:release()
        green:release()
        half_blue:release()
    end

    do
        local camera_parent = Object(0, 0, 1000, 1000)
        local camera_target = Object(100, 200, 20, 20)
        camera_parent:addChild(camera_target)
        camera_target.stage = camera_parent
        camera_target.getCameraTargetOffset = function() return 0, -80 end
        local camera = Camera(camera_parent, 0, 0, 640, 480, false)
        camera.target = camera_target
        local camera_x, camera_y = camera:getTargetPosition()
        expect(camera_x == 110 and camera_y == 130,
            "attached cameras should include their target's stable elevation offset")

        local camera_player = setmetatable({
            platforming_enabled = true,
            camera_z = 80,
            camera_z_target = 80,
            camera_z_follow_speed = 6,
            camera_z_fall_threshold = 24,
            camera_z_landing_lookahead = 48,
            ground_z = 80,
            z = 120,
            shadow_z = 0,
            height_state_manager = { state = "JUMP" }
        }, { __index = Player })
        camera_player:updateCameraZ()
        expect(camera_player.camera_z == 80
            and camera_player.camera_z_target == 80,
            "ordinary jump arcs should retain the takeoff camera elevation")

        camera_player.height_state_manager.state = "FALL"
        camera_player.z = 50
        camera_player:updateCameraZ()
        local expected_duration = 80 / (6 * 30)
        local expected_camera_z = Utils.ease(
            80, 0, DT / expected_duration, "out-cubic"
        )
        expect(math.abs(camera_player.camera_z - expected_camera_z) < 0.001
            and camera_player.camera_z_target == 0
            and math.abs(camera_player.camera_z_tween_duration - expected_duration) < 0.001,
            "a committed fall should use a distance-scaled cubic-out camera tween")

        local retarget_start = camera_player.camera_z
        camera_player:setCameraZTarget(40)
        expect(camera_player.camera_z == retarget_start
            and camera_player.camera_z_tween_start == retarget_start
            and camera_player.camera_z_target == 40
            and camera_player.camera_z_tween_timer == 0,
            "camera elevation retargeting should restart from its current eased position")

        camera_player.height_state_manager.state = "PIT_RECOVER"
        camera_player:updateCameraZ()
        expect(camera_player.camera_z == retarget_start,
            "pit recovery should freeze camera elevation instead of following the fall")

        camera_player:setCameraZTarget(32, true)
        local offset_x, offset_y = camera_player:getCameraTargetOffset(camera)
        expect(camera_player.camera_z == 32 and offset_x == 0 and offset_y == -32,
            "safe-floor recovery should be able to snap the attached camera elevation")
        camera_player.platforming_enabled = false
        offset_x, offset_y = camera_player:getCameraTargetOffset(camera)
        expect(offset_x == 0 and offset_y == 0,
            "ordinary maps should retain the original camera target coordinates")
    end

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
    do
        (function()
            local departure_piece = Hitbox(platform_parent, 0, 0, 20, 20)
            departure_piece.z, departure_piece.depth = 0, 32
            departure_piece.supports, departure_piece.one_way = true, true
            departure_piece.surface_id = "complex_ledge"
            local sibling_piece = Hitbox(platform_parent, 0, 0, 20, 20)
            sibling_piece.z, sibling_piece.depth = 0, 32
            sibling_piece.supports, sibling_piece.one_way = true, true
            sibling_piece.surface_id = "complex_ledge"
            fake_world.surfaces = { sibling_piece }
            local sibling_landing =
                fake_world:getLandingSurface(
                    probe, 32, 31, nil, nil, departure_piece)
            expect(sibling_landing == nil,
                "walking off a complex platform must not be recaptured by another collider piece on the same surface")
            sibling_landing =
                fake_world:getLandingSurface(
                    probe, 40, 20, nil, nil, departure_piece)
            expect(sibling_landing == 32,
                "the same complex platform should become landable again after falling from above it")
        end)()
    end
    fake_world.surfaces = { platform }

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
        properties = {
            platforming = true,
            empty_tile_pit = true,
            underwater_underlay = true,
            underwater_underlay_layer = -0.75,
            underwater_underlay_opacity = 0.6,
            underwater_underlay_void_strength = 0.2,
            underwater_underlay_speed = 0.18,
            underwater_underlay_pixel_size = 3,
            underwater_underlay_scale = 1.25,
            underwater_underlay_distortion = 3,
            underwater_underlay_particle_strength = 0.75,
            underwater_underlay_shallow_color = "#123456",
            underwater_underlay_deep_color = "#020510",
            terrain_edge_fog = true,
            terrain_edge_fog_texture = "fog",
            terrain_edge_fog_layer = "ground",
            terrain_edge_fog_surface_id = "base",
            terrain_edge_fog_extent = 72,
            terrain_edge_fog_opacity = 0.5,
            terrain_edge_fog_scale = 2,
            terrain_edge_fog_overlap = 6,
            terrain_edge_fog_raised_void_ratio = 0.6
        },
        layers = {}
    })
    expect(runtime_map.platforming and runtime_map.empty_tile_pit
        and runtime_map.underwater_underlay
        and runtime_map.underwater_underlay_layer == -0.75
        and runtime_map.underwater_underlay_opacity == 0.6
        and runtime_map.underwater_underlay_void_strength == 0.2
        and runtime_map.underwater_underlay_speed == 0.18
        and runtime_map.underwater_underlay_pixel_size == 3
        and runtime_map.underwater_underlay_scale == 1.25
        and runtime_map.underwater_underlay_distortion == 3
        and runtime_map.underwater_underlay_particle_strength == 0.75
        and runtime_map.underwater_underlay_shallow_color == "#123456"
        and runtime_map.underwater_underlay_deep_color == "#020510"
        and runtime_map.terrain_edge_fog
        and runtime_map.terrain_edge_fog_texture == "fog"
        and runtime_map.terrain_edge_fog_layer == "ground"
        and runtime_map.terrain_edge_fog_surface_id == "base"
        and runtime_map.terrain_edge_fog_extent == 72
        and runtime_map.terrain_edge_fog_opacity == 0.5
        and runtime_map.terrain_edge_fog_scale == 2
        and runtime_map.terrain_edge_fog_overlap == 6
        and runtime_map.terrain_edge_fog_raised_void_ratio == 0.6,
        "runtime map initialization should preserve platforming ground and edge-fog rules")

    do
        (function()
            expect(Kristal.Shaders["UnderwaterDepth"] ~= nil,
                "deep-water maps should have a procedural underlay shader")
            local water = UnderwaterUnderlay({
                width = 2,
                height = 2,
                tile_width = 40,
                tile_height = 40,
                underwater_underlay_opacity = 0.6,
                underwater_underlay_void_strength = 0.16,
                underwater_underlay_pixel_size = 2
            })
            local water_canvas = love.graphics.newCanvas(80, 80)
            local water_depth = love.graphics.newCanvas(80, 80, {
                format = "depth24stencil8", readable = false
            })
            love.graphics.setCanvas({
                water_canvas,
                depthstencil = water_depth
            })
            love.graphics.origin()
            love.graphics.clear(0, 0, 0, 0)
            Draw.setColor(0.2, 0.2, 0.2, 1)
            love.graphics.rectangle("fill", 40, 0, 40, 80)
            water:fullDraw(true)
            love.graphics.setCanvas()
            local water_pixels = water_canvas:newImageData()
            local top_r, top_g, top_b, top_a =
                water_pixels:getPixel(20, 8)
            local deep_r, deep_g, deep_b, deep_a =
                water_pixels:getPixel(20, 72)
            local artwork_r, _, _, artwork_a =
                water_pixels:getPixel(60, 8)
            expect(top_a > 0.035 and top_a < 0.11
                and deep_a > 0.035 and deep_a < 0.11
                and deep_r + deep_g + deep_b
                    < top_r + top_g + top_b
                and artwork_a > 0.99 and artwork_r < 0.18,
                string.format(
                    "underwater atmosphere should stay faint over empty black while fully tinting distant artwork (top %.3f,%.3f,%.3f,%.3f; deep %.3f,%.3f,%.3f,%.3f; artwork %.3f,%.3f)",
                    top_r, top_g, top_b, top_a,
                    deep_r, deep_g, deep_b, deep_a,
                    artwork_r, artwork_a
                ))
            water_pixels:release()
            water_canvas:release()
            water_depth:release()
            water.mesh:release()
            water.mesh = nil
        end)()
    end

    do
        (function()
            local inside = {
                false, false, false,
                false, true, false,
                false, false, false
            }
            local distances =
                TerrainEdgeFog.computeOutsideDistances(inside, 3, 3)
            expect(distances[5] == 0
                and math.abs(distances[2] - 1) < 0.001
                and math.abs(distances[1] - math.sqrt(2)) < 0.001,
                "terrain edge fog should measure outward distance from the unioned floor footprint")
            expect(Kristal.Shaders["TerrainEdgeFog"] ~= nil,
                "terrain edge fog should have a runtime mask-and-scroll shader")

            local fog_world = Object()
            local floor = Hitbox(fog_world, 4, 4, 32, 32)
            floor.supports = true
            local inferred_tiles = Object()
            inferred_tiles.name = "ground"
            inferred_tiles.provides_ground = true
            inferred_tiles.z = 0
            inferred_tiles.map_width = 1
            inferred_tiles.tile_data = { 1 }
            local fog = TerrainEdgeFog({
                width = 1,
                height = 1,
                tile_width = 40,
                tile_height = 40,
                tile_layers = { inferred_tiles },
                pits = {},
                world = fog_world,
                decodeTileData = function(_, packed) return packed end,
                surfaces = {
                    floor = {
                        support_top = 0,
                        support_colliders = { floor }
                    }
                }
            })
            expect(fog.lowest_z == 0 and fog.distance_field
                and fog.surface_pixel_count > 0
                and #fog.lowest_tile_layers == 0
                and fog.lowest_support_colliders[1] == floor,
                "authored lowest support should replace tile inference as the edge-fog footprint")
            local minimum_filter, maximum_filter =
                fog.distance_field:getFilter()
            expect(minimum_filter == "nearest"
                and maximum_filter == "nearest"
                and fog.texture_scale == 2
                and fog.opacity == 0.42
                and fog.wave_amplitude == 5
                and fog.overlap == 8
                and fog.raised_void_ratio == 0.5,
                "edge fog should use sharp mask sampling, doubled fog pixels, and restrained translucency")
            local fog_canvas = love.graphics.newCanvas(40, 40)
            love.graphics.setCanvas(fog_canvas)
            love.graphics.origin()
            love.graphics.clear(0, 0, 0, 0)
            fog:fullDraw(true)
            love.graphics.setCanvas()
            local fog_pixels = fog_canvas:newImageData()
            local _, _, _, floor_fog_alpha = fog_pixels:getPixel(20, 20)
            local outside_fog_alpha, underlap_fog_alpha = 0, 0
            for y = 0, 39 do
                for x = 0, 39 do
                    if x < 4 or x >= 36 or y < 4 or y >= 36 then
                        local _, _, _, alpha = fog_pixels:getPixel(x, y)
                        outside_fog_alpha = math.max(outside_fog_alpha, alpha)
                    elseif x < 12 or x >= 28 or y < 12 or y >= 28 then
                        local _, _, _, alpha = fog_pixels:getPixel(x, y)
                        underlap_fog_alpha = math.max(underlap_fog_alpha, alpha)
                    end
                end
            end
            expect(floor_fog_alpha < 0.01
                and outside_fog_alpha > 0.01
                and underlap_fog_alpha > 0.01,
                "fog should extend behind rounded floor corners without covering the deep surface")
            fog_pixels:release()
            fog_canvas:release()
            fog.distance_field:release()
            fog.distance_field = nil

            local plane_world = Object()
            local base_floor = Hitbox(plane_world, 0, 0, 160, 200)
            local isolated_floor = Hitbox(plane_world, 170, 20, 16, 16)
            local covered_floor = Hitbox(plane_world, 70, 70, 16, 16)
            local mostly_covered_floor =
                Hitbox(plane_world, 140, 110, 16, 16)
            base_floor.supports = true
            isolated_floor.supports = true
            covered_floor.supports = true
            mostly_covered_floor.supports = true
            local fog_planes = TerrainEdgeFog.createForMap({
                width = 5,
                height = 5,
                tile_width = 40,
                tile_height = 40,
                tile_layers = {},
                pits = {},
                world = plane_world,
                terrain_edge_fog_extent = 24,
                surfaces = {
                    base = {
                        support_top = 0,
                        support_colliders = { base_floor }
                    },
                    isolated = {
                        support_top = 20,
                        support_colliders = { isolated_floor }
                    },
                    covered = {
                        support_top = 40,
                        support_colliders = {
                            covered_floor,
                            mostly_covered_floor
                        }
                    }
                }
            })
            expect(#fog_planes == 2
                and fog_planes[1].z == 0
                and fog_planes[2].z == 20,
                "only raised platforms exposed to base void should receive their own projected fog plane")
            for _, plane in ipairs(fog_planes) do
                plane.distance_field:release()
                plane.distance_field = nil
            end
        end)()
    end

    local vessel = Registry.createActor("vessel")
    expect(vessel.jump_strength == 8 and vessel.jump_windup == 1 / 15,
        "the Vessel should use its tuned jump height and one-frame squat wind-up")
    expect(vessel.run_speed == 6
        and vessel.run_momentum_max == 0.5
        and vessel.run_acceleration == 4
        and vessel.run_deceleration == 4
        and vessel.run_transition_frames == 4
        and vessel.run_dash_boost == 0.25,
        "the Vessel should use its faster-ramping, platforming-friendly run tuning")
    do
        (function()
            local tuned_run_player = setmetatable({
                actor = vessel,
                getBaseWalkSpeed = function() return 6 end
            }, { __index = Player })
            local legacy_run_player = setmetatable({
                actor = {},
                getBaseWalkSpeed = function() return 6 end
            }, { __index = Player })
            expect(tuned_run_player:getRunSpeed() == 6
                and tuned_run_player:getRunMomentumMax() == 0.5
                and tuned_run_player:getRunAcceleration() == 4
                and tuned_run_player:getRunDeceleration() == 4
                and tuned_run_player:getRunSpeed()
                    * (1 + tuned_run_player:getRunMomentumMax()) == 9,
                "Vessel's momentum run should cap at 9 pixels per frame")
            expect(legacy_run_player:getRunSpeed() == 10
                and legacy_run_player:getRunMomentumMax() == 1
                and legacy_run_player:getRunAcceleration() == 1
                and legacy_run_player:getRunDeceleration() == 2,
                "actors without run tuning should retain the legacy momentum defaults")

            tuned_run_player.run_momentum = {0.5, 0}
            local vessel_dash_x, vessel_dash_y =
                tuned_run_player:getDashLaunchMomentum(1, 0, true)
            expect(vessel_dash_x == 1.25 and vessel_dash_y == 0,
                "Vessel's full running dash should only be 25% faster than a standing dash")
            tuned_run_player.run_momentum = {3, 0}
            vessel_dash_x = tuned_run_player:getDashLaunchMomentum(1, 0, true)
            expect(vessel_dash_x == 1.25,
                "excess run momentum must not bypass the Vessel's dash-launch cap")

            legacy_run_player.run_momentum = {1, 0}
            local legacy_dash_x, legacy_dash_y =
                legacy_run_player:getDashLaunchMomentum(1, 0, true)
            expect(legacy_dash_x == 3 and legacy_dash_y == 0,
                "untuned actors should retain the legacy running-dash launch")
        end)()
    end
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
        and fake_world:getLandingSurface(edge_probe, 40, 20) == 32,
        "any remaining grounded-footprint overlap should still support a landing")

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

    do
        (function()
            local coplanar_parent = Object()
            local coplanar_object = Hitbox(coplanar_parent, 0, 0, 20, 20)
            coplanar_parent.z = 32
            coplanar_object.depth = 0
            coplanar_object.supports = false
            coplanar_object.one_way = false
            fake_world.surfaces = { platform, coplanar_object }
            expect(fake_world:getLandingSurface(probe, 40, 20, body) == 32,
                "a zero-depth object on a platform must not invalidate the ground beneath it")

            local landing_parent = Object()
            landing_parent.z = 32
            local landing_body = Hitbox(landing_parent, 2, 2, 4, 4)
            landing_body.depth = 20
            local landing_player = {
                collider = landing_body,
                world = fake_world,
                enemy_collision = false,
                fall_through_colliders = {},
                landing_overlap_colliders = {},
                departed_ground_collider = nil,
                platforming_enabled = true,
                height_state_manager = { state = "LAND" },
                getHeightState = Player.getHeightState,
                updateFallThroughColliders = Player.updateFallThroughColliders,
                getDepartedGroundCollisionIgnore =
                    Player.getDepartedGroundCollisionIgnore
            }
            Player.recordLandingCollisionOverlaps(landing_player)
            expect(landing_player.fall_through_colliders[coplanar_object]
                and landing_player.landing_overlap_colliders[coplanar_object]
                and Player.getMovementHeightCollisionIgnore(landing_player)
                    == coplanar_object,
                "landing inside a coplanar object should allow movement until the body escapes")
            landing_parent.x = 24
            Player.updateDepartedGroundCollision(landing_player)
            expect(not landing_player.fall_through_colliders[coplanar_object]
                and not landing_player.landing_overlap_colliders[coplanar_object],
                "the landing escape exception should expire once the body clears the object")
        end)()
    end

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
        and fake_world:isSupportOver(ledge_body, platform)
        and Player.getHeightCollisionIgnore(ledge_player) == nil
        and fake_world:checkCollision3D(ledge_body, false)
        and not fake_world:checkCollision3D(ledge_body, false, platform),
        "a partially overlapping body must remain supported instead of falling into the ledge wall")
    do
        (function()
            ledge_parent.x, ledge_parent.z = 22, 32
            local entered_fall = false
            local grounded_ledge_player = {
                world = fake_world,
                collider = ledge_body,
                support_collider = ledge_support,
                z = 32,
                height_state_manager = {
                    setState = function(_, state)
                        entered_fall = state == "FALL"
                    end
                }
            }
            Player.updateHeightGrounded(grounded_ledge_player)
            expect(ledge_body:collidesWith(platform)
                and not ledge_support:collidesWith(platform)
                and entered_fall,
                "clearing the compact support footprint should start a fall even while the full body trails over the ledge")
        end)()
    end
    ledge_parent.x, ledge_parent.z = 21, 31
    ledge_parent.x = 25
    expect(Player.getHeightCollisionIgnore(ledge_player) == platform
        and ledge_player.departed_ground_collider == platform,
        "an airborne departure must keep ignoring its old platform after clearing the body")
    ledge_parent.x = 21
    expect(Player.getHeightCollisionIgnore(ledge_player) == nil,
        "moving the complete footprint back over the platform must restore its collision")
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
        and Player.getDepartedGroundCollisionIgnore(ledge_player) == platform,
        "walking upward off a ledge must keep ignoring its old platform while airborne")
    Player.updateDepartedGroundCollision(ledge_player)
    expect(ledge_player.departed_ground_collider == platform,
        "the upward ledge exception must not expire at the physical footprint edge")
    ledge_parent.y = -40
    Player.updateDepartedGroundCollision(ledge_player)
    expect(ledge_player.departed_ground_collider == platform,
        "an upward departure must retain its old-platform exemption for the full fall")
    ledge_player.height_state_manager.state = "LAND"
    Player.updateDepartedGroundCollision(ledge_player)
    expect(ledge_player.departed_ground_collider == nil,
        "the upward ledge exception should expire on a clear landing")
    ledge_player.height_state_manager.state = "FALL"
    ledge_parent.y = 0
    ledge_player.departed_ground_collider = platform
    expect(fake_world:isSupportOver(ledge_body, platform)
        and Player.getDepartedGroundCollisionIgnore(ledge_player) == nil,
        "moving the airborne footprint back over the old platform must restore collision")

    platform.depth = 120
    ledge_parent.x, ledge_parent.z = 21, 5
    ledge_player.departed_ground_collider = platform
    fake_world.map = tile_map
    expect(fake_world:getLandingSurface(ledge_body, 5, -5, ledge_body) == nil,
        "a tall departed platform should still reject an unqualified landing inside its wall")
    ledge_parent.x = 25
    local base_z = fake_world:getLandingSurface(ledge_body, 5, -5,
        ledge_body, Player.getHeightCollisionIgnore(ledge_player))
    expect(base_z == 0,
        "falling beside a tall platform should find walkable base ground below it")
    ledge_player.height_state_manager.state = "LAND"
    expect(Player.getHeightCollisionIgnore(ledge_player) == nil,
        "the old platform exception should expire after landing with the body fully clear")
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
        "a wall overlapping the grounded footprint must remain non-landable")
    ledge_parent.x, ledge_parent.z = 21, 5
    expect(Player.getHeightCollisionIgnore(ledge_player) == nil
        and fake_world:getLandingSurface(ledge_body, 5, -5,
            ledge_body) == nil,
        "base ground must not catch the player while any of their body remains in the wall")
    ledge_parent.x = 25
    local trailing_wall = Player.getHeightCollisionIgnore(ledge_player)
    expect(trailing_wall == descent_wall
        and fake_world:getLandingSurface(ledge_body, 5, -5,
            ledge_body, trailing_wall) == 0,
        "valid floor should catch the player once their complete footprint clears the wall")
    local explicit_base_floor = Hitbox(platform_parent, 20, 0, 20, 20)
    explicit_base_floor.z, explicit_base_floor.depth = -40, 40
    explicit_base_floor.supports, explicit_base_floor.one_way = true, true
    explicit_base_floor.collision_role = "surface"
    fake_world.surfaces = { descent_wall, explicit_base_floor }
    fake_world.map = { pits = {}, empty_tile_pit = true, tile_layers = {} }
    expect(fake_world:getLandingSurface(ledge_body, -5, -10,
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
        projected_player, -19, -25
    )
    expect(projected_z == 0 and projected_surface == projected_floor
        and projected_player.y == 38,
        "a fall rendered down a tall wall should project until the complete body reaches its adjacent base floor")
    projected_player.height_state_manager = { state = "LAND" }
    projected_player.getHeightState = Player.getHeightState
    projected_player.y = 38
    expect(Player.getMovementHeightCollisionIgnore(projected_player) == projected_wall,
        "the cleared wall may remain exempt at the exact projected landing boundary")
    projected_player.y = 37
    expect(Player.getMovementHeightCollisionIgnore(projected_player) == nil,
        "a landed player must not reverse through the wall they just fell past")
    projected_player.y = 38

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
        and editor_shape.property_set:getProperty("depth").name == "Solid Height"
        and editor_shape.property_set:getProperty("surface_id").type == "string"
        and editor_shape.property_set:getProperty("surface_plane").type == "string",
        "collision shapes should expose clear wall, solid, surface, and pit authoring controls")

    local raised_editor_shape = EditorObject({
        x = 40, y = 200, width = 30, height = 20,
        properties = { z = 20, depth = 60, collision_role = "wall" },
        __editor_property_types = {}
    }, { layer_type = Registry.getLayerType("collision") })
    expect(raised_editor_shape.visual_z == 20 and raised_editor_shape.y == 180,
        "explicit walls should be authored at the projected bottom where their blocking footprint begins")

    local projection_document = setmetatable({}, { __index = EditorMapDocument })
    local projection_layer = {
        _editor_type_id = "collision", offsetx = 0, offsety = 0, properties = {}
    }
    local projection_selection = {
        document = projection_document,
        layer = projection_layer,
        entry = { x = 0, y = 0 },
        data = {
            x = 40, y = 200, width = 30, height = 20,
            properties = { z = 20, depth = 60, collision_role = "wall" }
        }
    }
    local projected_x, projected_y =
        projection_document:getObjectLocalRect(projection_selection)
    expect(projection_document:getObjectVisualZ(projection_selection) == 20
        and projected_x == 40 and projected_y == 180,
        "wall selection and manipulation bounds should use the projected blocking bottom")
    projection_selection.data.properties.collision_role = "solid"
    local solid_x, solid_y = projection_document:getObjectLocalRect(projection_selection)
    expect(projection_document:getObjectVisualZ(projection_selection) == 80
        and solid_x == 40 and solid_y == 120,
        "supporting collision shapes should be authored at their projected walkable top")

    local editor_event = EditorObject({
        x = 120, y = 200, width = 40, height = 40,
        properties = { surface_id = "left_tower" },
        __editor_property_types = {}
    }, {
        layer_type = Registry.getLayerType("objects"),
        map = {
            getSurface = function(_, id)
                return id == "left_tower" and { top = 120 } or nil
            end
        }
    })
    expect(editor_event.y == 80 and editor_event.visual_z == 120
        and editor_event.property_set:getProperty("height_sensitive").type == "boolean",
        "raised events should preview at projected Y while retaining a height-sensitive interaction control")

    local used_3d_interaction, used_2d_interaction = false, false
    local interaction_target = {
        height_sensitive = true,
        collidesWith3D = function() used_3d_interaction = true return false end,
        collidesWith = function() used_2d_interaction = true return true end
    }
    expect(not Player.collidesWithHeightSensitiveObject({
            platforming_enabled = true
        }, interaction_target, {})
        and used_3d_interaction and not used_2d_interaction,
        "platforming interactions must reject 2D overlap when the event is on another Z range")

    local occlusion_layer_type = Registry.getLayerType("occlusion")
    expect(occlusion_layer_type and occlusion_layer_type.kind == "object",
        "height occlusion should be a first-class editor layer type")
    local editor_occluder = EditorObject({
        properties = {}, __editor_property_types = {}
    }, { layer_type = occlusion_layer_type })
    expect(editor_occluder.property_set:getProperty("source_layer").type == "string"
        and editor_occluder.property_set:getProperty("z").name == "Bottom Z Override"
        and editor_occluder.property_set:getProperty("depth").name == "Height Override"
        and editor_occluder.property_set:getProperty("surface_id").type == "string"
        and editor_occluder.property_set:getProperty("face_direction").type == "choice"
        and editor_occluder.property_set:getProperty("face_y").type == "number"
        and editor_occluder.property_set:getProperty("face_x").type == "number"
        and editor_occluder.property_set:getProperty("sort_y_offset").type == "number"
        and editor_occluder.property_set:getProperty("cutout_enabled").type == "boolean"
        and editor_occluder.property_set:getProperty("cutout_radius").type == "number"
        and editor_occluder.property_set:getProperty("cutout_alpha").type == "number"
        and editor_occluder.property_set:getProperty("cutout_feather").type == "number"
        and editor_occluder.property_set:getProperty("cutout_grow_time").type == "number"
        and editor_occluder.property_set:getProperty("cutout_shrink_time").type == "number"
        and editor_occluder.property_set:getProperty("cutout_wobble").type == "number"
        and editor_occluder.property_set:getProperty("cutout_wobble_speed").type == "number",
        "occlusion regions should expose their source, linked surface, directed face, and cutout")

    local occlusion_source = Object(0, 0, 40, 40)
    occlusion_source.map_layer = true
    function occlusion_source:draw()
        love.graphics.rectangle("fill", 0, 0, 40, 40)
    end
    local occlusion_map = {
        id = "occlusion_test",
        getDrawableLayer = function(_, name)
            return name == "Terrain" and occlusion_source or nil
        end
    }
    local runtime_occluder = HeightOccluder(occlusion_map, {
        id = 1, name = "pillar", shape = "rectangle",
        x = 0, y = 0, width = 20, height = 40
    }, { offsetx = 0, offsety = 0 }, {
        source_layer = "Terrain", z = 0, depth = 40
    })
    local occlusion_root = Object()
    occlusion_root:addChild(occlusion_source)
    occlusion_root:addChild(runtime_occluder)
    expect(runtime_occluder:resolveSourceLayer() == occlusion_source
        and occlusion_source.height_occlusion_masks[1] == runtime_occluder,
        "runtime occlusion regions should attach to the named tile/image source")

    local clipped_source = Object(0, 0, 40, 40)
    function clipped_source:draw()
        love.graphics.rectangle("fill", 0, 0, 40, 40)
    end
    local clipped_map = {
        id = "clipped_occlusion_test",
        getDrawableLayer = function(_, name)
            return name == "Terrain" and clipped_source or nil
        end,
        getSurface = function(_, id)
            if id == "ledge" then
                return {
                    id = id, bottom = 0, top = 40,
                    bounds = { min_x = 0, max_x = 20, min_y = 0, max_y = 20 }
                }
            end
        end
    }
    local clipped_occluder = HeightOccluder(clipped_map, {
        id = 3, name = "clipped pillar", shape = "rectangle",
        x = 0, y = 0, width = 20, height = 40
    }, { offsetx = 0, offsety = 0 }, {
        source_layer = "Terrain", surface_id = "ledge", face_direction = "front"
    })
    local clipped_root = Object()
    clipped_root:addChild(clipped_source)
    clipped_root:addChild(clipped_occluder)
    clipped_occluder:resolveSourceLayer()
    local clipped_points = clipped_occluder:getOcclusionMaskPoints()
    expect(#clipped_points >= 3 and clipped_occluder.sort_y == 20,
        "a linked front face should resolve its proxy anchor from the collision boundary")
    local clipped_canvas = love.graphics.newCanvas(40, 40)
    love.graphics.setCanvas({ clipped_canvas, stencil = true })
    love.graphics.origin()
    love.graphics.clear(0, 0, 0, 0)
    clipped_source:fullDraw(true)
    love.graphics.setCanvas()
    local clipped_source_data = clipped_canvas:newImageData()
    local _, _, _, clipped_far_alpha = clipped_source_data:getPixel(10, 10)
    local _, _, _, retained_near_alpha = clipped_source_data:getPixel(10, 30)
    expect(clipped_far_alpha == 0 and retained_near_alpha > 0.95,
        string.format(
            "only far-side pixels should leave the source layer for dynamic occlusion (far %.3f, near %.3f)",
            clipped_far_alpha, retained_near_alpha
        ))
    love.graphics.setCanvas({ clipped_canvas, stencil = true })
    love.graphics.origin()
    love.graphics.clear(0, 0, 0, 0)
    clipped_occluder:fullDraw(true)
    love.graphics.setCanvas()
    local clipped_proxy_data = clipped_canvas:newImageData()
    local _, _, _, restored_far_alpha = clipped_proxy_data:getPixel(10, 10)
    local _, _, _, lifted_near_alpha = clipped_proxy_data:getPixel(10, 30)
    expect(restored_far_alpha > 0.95 and lifted_near_alpha == 0,
        "the dynamic proxy must not lift near-side wall pixels over later terrain layers")

    do
        local aligned_root = Object()
        aligned_root.height_occlusion_draw_frame = 77
        local aligned_character = Object(10.4, 20.4, 1, 1)
        function aligned_character:drawHeightOcclusionMask()
            love.graphics.rectangle("fill", 0, 0, 1, 1)
        end
        aligned_root:addChild(aligned_character)
        love.graphics.origin()
        aligned_character:preDraw(false)
        aligned_character:postDraw()
        local aligned_mask = aligned_character:getHeightOcclusionMaskCanvas()
        local min_filter, mag_filter = aligned_mask:getFilter()
        local aligned_data = aligned_mask:newImageData()
        local _, _, _, aligned_alpha = aligned_data:getPixel(10, 20)
        local _, _, _, halo_alpha = aligned_data:getPixel(11, 21)
        expect(min_filter == "nearest" and mag_filter == "nearest"
            and aligned_alpha > 0.95 and halo_alpha == 0,
            "height cutout silhouettes should reuse the exact pixel-snapped draw transform without a filtered halo")
    end

    local low_character = Object(0, 10)
    low_character.height_sort_subject = true
    low_character.use_3d_collision = true
    low_character.z = 0
    local high_character = Object(0, 10)
    high_character.height_sort_subject = true
    high_character.use_3d_collision = true
    high_character.z = 40
    runtime_occluder.layer = 0
    low_character.layer = 0
    high_character.layer = 0
    runtime_occluder.sort_y = 30
    local sort_world = setmetatable({
        children = { runtime_occluder, low_character },
        player = low_character
    }, { __index = World })
    World.sortChildren(sort_world)
    expect(sort_world.children[1] == low_character
        and sort_world.children[2] == runtime_occluder,
        "a low character behind terrain should render beneath its occlusion region")
    sort_world.children = { runtime_occluder, high_character }
    sort_world.player = high_character
    World.sortChildren(sort_world)
    expect(sort_world.children[1] == high_character
        and sort_world.children[2] == runtime_occluder,
        "reaching a region's top should not reorder the character or terrain")

    local foreground_source = Object(0, 0, 40, 40)
    foreground_source.layer = 1
    local foreground_map = {
        id = "occlusion_foreground_test",
        getDrawableLayer = function(_, name)
            return name == "Foreground" and foreground_source or nil
        end
    }
    local foreground_occluder = HeightOccluder(foreground_map, {
        id = 2, name = "foreground", shape = "rectangle",
        x = 0, y = 0, width = 20, height = 40
    }, { offsetx = 0, offsety = 0 }, {
        source_layer = "Foreground", z = 0, depth = 40
    })
    occlusion_root:addChild(foreground_source)
    occlusion_root:addChild(foreground_occluder)
    foreground_occluder:resolveSourceLayer()
    foreground_occluder.layer = 0
    foreground_occluder.sort_y = runtime_occluder.sort_y
    sort_world.children = { foreground_occluder, runtime_occluder }
    World.sortChildren(sort_world)
    expect(sort_world.children[1] == runtime_occluder
        and sort_world.children[2] == foreground_occluder,
        "equal-anchor occlusion regions should preserve their visual source-layer order")

    -- Height changes must never reorder terrain. Visibility for a cleared
    -- region is resolved locally by its stencil instead of by moving the
    -- region around the player in the global draw list.
    foreground_occluder.occlusion_depth = 80
    foreground_occluder.source_draw_layer = 0
    runtime_occluder.source_draw_layer = 1
    high_character.z = 40
    sort_world.children = {
        foreground_occluder, runtime_occluder, high_character
    }
    sort_world.player = high_character
    World.sortChildren(sort_world)
    expect(sort_world.children[1] == high_character
        and sort_world.children[2] == foreground_occluder
        and sort_world.children[3] == runtime_occluder,
        "mixed-height terrain should retain normal player and source ordering")

    high_character.z = 80
    World.sortChildren(sort_world)
    expect(sort_world.children[1] == high_character
        and sort_world.children[2] == foreground_occluder
        and sort_world.children[3] == runtime_occluder,
        "clearing every terrain top should not change terrain ordering")

    high_character.z = 0
    World.sortChildren(sort_world)
    expect(sort_world.children[1] == high_character
        and sort_world.children[2] == foreground_occluder
        and sort_world.children[3] == runtime_occluder,
        "dropping below every terrain top should restore source order above the player")

    local occlusion_canvas = love.graphics.newCanvas(40, 40)
    love.graphics.setCanvas({ occlusion_canvas, stencil = true })
    love.graphics.origin()
    love.graphics.clear(0, 0, 0, 0)
    occlusion_source:fullDraw(true)
    love.graphics.setCanvas()
    local occlusion_base_data = occlusion_canvas:newImageData()
    local _, _, _, masked_alpha = occlusion_base_data:getPixel(10, 20)
    local _, _, _, base_alpha = occlusion_base_data:getPixel(30, 20)
    expect(masked_alpha == 0 and base_alpha > 0,
        "the background source pass should omit pixels owned by an occlusion region")

    love.graphics.setCanvas({ occlusion_canvas, stencil = true })
    love.graphics.origin()
    love.graphics.clear(0, 0, 0, 0)
    runtime_occluder:fullDraw(true)
    love.graphics.setCanvas()
    local occlusion_proxy_data = occlusion_canvas:newImageData()
    local _, _, _, restored_alpha = occlusion_proxy_data:getPixel(10, 20)
    local _, _, _, clipped_alpha = occlusion_proxy_data:getPixel(30, 20)
    expect(restored_alpha > 0 and clipped_alpha == 0,
        "the sorted proxy should redraw only its clipped terrain pixels")

    local cutout_player = Object(0, 0, 20, 20)
    cutout_player.height_sort_subject = true
    cutout_player.use_3d_collision = true
    function cutout_player:draw()
        love.graphics.setColor(0, 0, 1, 1)
        love.graphics.rectangle("fill", 0, 0, 20, 20)
        love.graphics.setColor(1, 1, 1, 1)
    end
    function cutout_player:drawHeightOcclusionMask()
        local r, g, b, a = love.graphics.getColor()
        love.graphics.setColor(0, 0, 1, a)
        love.graphics.rectangle("fill", 0, 0, 20, 20)
        love.graphics.setColor(r, g, b, a)
    end
    occlusion_root:addChild(cutout_player)
    TableUtils.removeValue(occlusion_root.children, cutout_player)
    local runtime_occluder_index
    for index, child in ipairs(occlusion_root.children) do
        if child == runtime_occluder then
            runtime_occluder_index = index
            break
        end
    end
    table.insert(occlusion_root.children, runtime_occluder_index, cutout_player)
    occlusion_map.world = { player = cutout_player }
    runtime_occluder.cutout_radius = 8
    runtime_occluder.cutout_alpha = 0.25
    runtime_occluder.cutout_feather = 0
    runtime_occluder.cutout_wobble = 0
    runtime_occluder.sort_y = 30
    runtime_occluder:updateCutoutAnimation(runtime_occluder.cutout_grow_time)
    love.graphics.setCanvas({ occlusion_canvas, stencil = true })
    love.graphics.origin()
    love.graphics.clear(0, 0, 0, 0)
    runtime_occluder:fullDraw(true)
    love.graphics.setCanvas()
    local cutout_data = occlusion_canvas:newImageData()
    local _, _, _, cutout_alpha = cutout_data:getPixel(10, 10)
    local _, _, _, opaque_alpha = cutout_data:getPixel(10, 30)
    expect(cutout_alpha > 0.2 and cutout_alpha < 0.35 and opaque_alpha > 0.95,
        "terrain covering a low character should become translucent only inside the cutout")

    TableUtils.removeValue(occlusion_root.children, cutout_player)
    table.insert(occlusion_root.children, runtime_occluder_index + 1, cutout_player)
    runtime_occluder:updateCutoutAnimation(runtime_occluder.cutout_shrink_time)
    love.graphics.setCanvas({ occlusion_canvas, stencil = true })
    love.graphics.origin()
    love.graphics.clear(0, 0, 0, 0)
    runtime_occluder:fullDraw(true)
    love.graphics.setCanvas()
    local foreground_cutout_data = occlusion_canvas:newImageData()
    local _, _, _, foreground_cutout_alpha = foreground_cutout_data:getPixel(10, 10)
    expect(foreground_cutout_alpha > 0.95,
        "terrain behind the character should remain opaque instead of showing a cutout")

    do
        (function()
            local animated = setmetatable({
                cutout_enabled = true,
                cutout_radius = 32,
                cutout_grow_time = 0.2,
                cutout_shrink_time = 0.2,
                cutout_wobble = 2,
                cutout_wobble_speed = 2.5,
                cutout_wobble_seed = 0,
                cutout_visibility = 0,
                cutout_tween_start = 0,
                cutout_tween_target = 0,
                cutout_tween_timer = 0,
                cutout_tween_duration = 0,
                cutout_target_active = true,
                getCharacterCutoutTarget = function(self)
                    return self.cutout_target_active and {} or nil
                end,
                captureCharacterCutoutCenter = function() end
            }, { __index = HeightOccluder })
            animated:updateCutoutAnimation(0.1)
            expect(animated.cutout_visibility > 0
                and animated.cutout_visibility < 1,
                "cutouts should grow over time instead of appearing immediately")
            animated:updateCutoutAnimation(0.1)
            expect(animated.cutout_visibility == 1,
                "cutout growth should reach the full authored radius")
            animated.cutout_target_active = false
            animated:updateCutoutAnimation(0.1)
            expect(animated.cutout_visibility > 0
                and animated.cutout_visibility < 1,
                "cutouts should remain visible while shrinking")
            animated:updateCutoutAnimation(0.1)
            expect(animated.cutout_visibility == 0,
                "cutout shrinkage should finish completely")

            local boundary = animated:getCutoutBoundaryCoordinates(
                love.math.newTransform(), 0, 0, 20, 0, 2)
            local minimum_radius, maximum_radius = math.huge, 0
            for index = 1, #boundary, 2 do
                local radius = math.sqrt(
                    boundary[index] * boundary[index]
                    + boundary[index + 1] * boundary[index + 1]
                )
                minimum_radius = math.min(minimum_radius, radius)
                maximum_radius = math.max(maximum_radius, radius)
            end
            expect(maximum_radius - minimum_radius > 1,
                "cutout boundaries should have a visible animated wobble")
        end)()
    end

    TableUtils.removeValue(occlusion_root.children, cutout_player)
    table.insert(occlusion_root.children, runtime_occluder_index, cutout_player)
    cutout_player.z = 40
    cutout_player.y = 40
    local silhouette_canvas = love.graphics.newCanvas(40, 40)
    love.graphics.setCanvas(silhouette_canvas)
    love.graphics.origin()
    love.graphics.clear(0, 0, 0, 0)
    love.graphics.replaceTransform(cutout_player:getFullVisualTransform())
    cutout_player:drawHeightOcclusionMask()
    love.graphics.setCanvas()
    local silhouette_data = silhouette_canvas:newImageData()
    local _, _, _, silhouette_alpha = silhouette_data:getPixel(10, 10)
    expect(silhouette_alpha > 0.95,
        "the cleared-terrain character silhouette should render at its projected position")
    love.graphics.setCanvas({ occlusion_canvas, stencil = true })
    love.graphics.origin()
    love.graphics.clear(0, 0, 0, 0)
    runtime_occluder:fullDraw(true)
    love.graphics.setCanvas()
    local cleared_cutout_data = occlusion_canvas:newImageData()
    local cleared_cutout_r, _, cleared_cutout_b, cleared_cutout_alpha =
        cleared_cutout_data:getPixel(10, 10)
    local _, _, _, cleared_terrain_alpha = cleared_cutout_data:getPixel(10, 30)
    expect(cleared_cutout_r < 0.05 and cleared_cutout_b > 0.95
        and cleared_cutout_alpha > 0.95 and cleared_terrain_alpha > 0.95,
        "opaque character reveals should replay over terrain without requiring an earlier framebuffer pass")

    do
        (function()
            local premultiplied_source = love.graphics.newCanvas(1, 1)
            local premultiplied_result = love.graphics.newCanvas(1, 1)
            love.graphics.setCanvas(premultiplied_source)
            love.graphics.origin()
            love.graphics.clear(1, 0, 0, 1)
            love.graphics.setCanvas(premultiplied_result)
            love.graphics.clear(0, 0, 1, 1)
            Draw.setColor(1, 1, 1, 0.5)
            Draw.drawCanvas(premultiplied_source)
            Draw.setColor(1, 1, 1, 1)
            love.graphics.setCanvas()
            local premultiplied_data = premultiplied_result:newImageData()
            local premultiplied_r, premultiplied_g, premultiplied_b,
                premultiplied_a = premultiplied_data:getPixel(0, 0)
            expect(premultiplied_r > 0.45 and premultiplied_r < 0.55
                and premultiplied_g < 0.05
                and premultiplied_b > 0.45 and premultiplied_b < 0.55
                and premultiplied_a > 0.95,
                "canvas opacity must scale premultiplied RGB and alpha together")

            cutout_player.alpha = 0.5
            cutout_player._height_occlusion_mask_frame = nil
            love.graphics.setCanvas({ occlusion_canvas, stencil = true })
            love.graphics.origin()
            love.graphics.clear(0, 0, 0, 0)
            runtime_occluder:fullDraw(true)
            love.graphics.setCanvas()
            local translucent_data = occlusion_canvas:newImageData()
            local translucent_r, _, translucent_b, translucent_a =
                translucent_data:getPixel(10, 10)
            expect(translucent_r > 0.45 and translucent_r < 0.55
                and translucent_b > 0.95 and translucent_a > 0.95,
                "any translucent height subject should blend over terrain without a type-specific opt-in")
            cutout_player.alpha = 1
            cutout_player._height_occlusion_mask_frame = nil
        end)()
    end

    cutout_player.x = 0
    cutout_player.y = 0
    cutout_player.z = 0
    runtime_occluder.face_position = 30
    expect(runtime_occluder:isCharacterBehindFace(cutout_player)
        and runtime_occluder:getCharacterDepthResult(cutout_player) == "terrain",
        "a low character on the far side of a front face should be depth-occluded")
    cutout_player.y = 20
    expect(not runtime_occluder:isCharacterBehindFace(cutout_player)
        and runtime_occluder:getCharacterDepthResult(cutout_player) == "character",
        "crossing to the near side should put the character in front without changing terrain order")
    cutout_player.y = 0
    cutout_player.z = 40
    expect(runtime_occluder:getCharacterDepthResult(cutout_player) == "character",
        "clearing a face's top should put the character in front even on its far side")

    do
        local dash_source = Object(0, 40, 20, 20)
        dash_source.height_sort_subject = true
        dash_source.use_3d_collision = true
        dash_source.z = 40
        dash_source.ground_surface = runtime_occluder:resolveSurface()
        function dash_source:draw()
            love.graphics.rectangle("fill", 0, 0, 20, 20)
        end
        local dash_trail = AfterImage(dash_source, 0.5)
        occlusion_root:addChild(dash_trail)
        TableUtils.removeValue(occlusion_root.children, dash_trail)
        table.insert(occlusion_root.children, runtime_occluder_index, dash_trail)
        local dash_revealed = false
        for _, subject in ipairs(runtime_occluder:getHeightReveals()) do
            if subject == dash_trail then dash_revealed = true end
        end
        local dash_x, dash_y = dash_trail:getSortPosition()
        local dash_mask_r, dash_mask_g, dash_mask_b, dash_mask_alpha =
            dash_trail:getHeightOcclusionMaskCanvas():newImageData():getPixel(10, 10)
        expect(dash_trail.height_sort_subject and dash_trail.use_3d_collision
            and dash_trail:getFullZ() == 40
            and dash_trail:getFullHeightTransform():getZ() == 40
            and dash_x == 10 and dash_y == 60
            and dash_revealed
            and dash_mask_r > 0.45 and dash_mask_r < 0.55
            and dash_mask_g > 0.45 and dash_mask_g < 0.55
            and dash_mask_b > 0.45 and dash_mask_b < 0.55
            and dash_mask_alpha > 0.45 and dash_mask_alpha < 0.55,
            "dash afterimages should retain height and correctly premultiplied RGBA through terrain")

        cutout_player.y = 40
        cutout_player._height_occlusion_mask_frame = nil
        love.graphics.setCanvas({ occlusion_canvas, stencil = true })
        love.graphics.origin()
        love.graphics.clear(0, 0, 0, 0)
        dash_trail:fullDraw(true)
        cutout_player:fullDraw(true)
        runtime_occluder:fullDraw(true)
        love.graphics.setCanvas()
        local dash_overlap_data = occlusion_canvas:newImageData()
        local dash_overlap_r, _, dash_overlap_b, dash_overlap_a =
            dash_overlap_data:getPixel(10, 10)
        expect(dash_overlap_r < 0.05 and dash_overlap_b > 0.95
            and dash_overlap_a > 0.95,
            string.format(
                "an earlier translucent trail must not tint or replace the later opaque player (%.3f, %.3f, %.3f)",
                dash_overlap_r, dash_overlap_b, dash_overlap_a
            ))
        dash_trail:remove()
        TableUtils.removeValue(occlusion_root.children, dash_trail)
        cutout_player.y = 0
        cutout_player._height_occlusion_mask_frame = nil
    end

    do
        (function()
            local shadow_owner = Object(20, 20, 20, 20)
            shadow_owner.platforming_enabled = true
            shadow_owner.shadow_z = 0
            shadow_owner.shadow_surface = {
                id = "shadow_floor",
                top = 0,
                support_bounds = {
                    min_x = 0, min_y = 0,
                    max_x = 80, max_y = 80
                }
            }
            shadow_owner.shouldDrawHeightShadow = Player.shouldDrawHeightShadow
            shadow_owner.getHeightShadowOffset = Player.getHeightShadowOffset
            shadow_owner.getHeightShadowAlpha = Player.getHeightShadowAlpha

            local sorted_shadow = HeightShadow(shadow_owner)
            shadow_owner.height_shadow = sorted_shadow
            local foreground_object = Object(28, 30, 20, 20)
            function foreground_object:draw()
                love.graphics.setColor(1, 0, 0, 1)
                love.graphics.rectangle("fill", 0, 0, self.width, self.height)
                love.graphics.setColor(1, 1, 1, 1)
            end

            local shadow_root = Object()
            shadow_root:addChild(sorted_shadow)
            shadow_root:addChild(foreground_object)
            shadow_root:addChild(shadow_owner)
            local shadow_world = setmetatable({
                children = shadow_root.children,
                player = shadow_owner,
                map = {}
            }, { __index = World })
            World.sortChildren(shadow_world)
            expect(shadow_root.children[1] == sorted_shadow
                and shadow_root.children[2] == shadow_owner
                and shadow_root.children[3] == foreground_object,
                "the ground shadow should sort independently below foreground objects and the player")

            shadow_owner.shadow_surface.support_bounds.max_x = 28
            local clipped_shadow_canvas = love.graphics.newCanvas(80, 80)
            love.graphics.setCanvas({ clipped_shadow_canvas, stencil = true })
            love.graphics.origin()
            love.graphics.clear(1, 1, 1, 1)
            sorted_shadow:fullDraw()
            love.graphics.setCanvas()
            local clipped_shadow_data = clipped_shadow_canvas:newImageData()
            local clipped_inside_r = clipped_shadow_data:getPixel(25, 38)
            local clipped_outside_r = clipped_shadow_data:getPixel(30, 38)
            expect(clipped_inside_r > 0.63 and clipped_inside_r < 0.67
                and clipped_outside_r > 0.95,
                "the shadow subject should clip itself at its receiving surface's side edge")
            shadow_owner.shadow_surface.support_bounds.max_x = 80

            local sorted_shadow_canvas = love.graphics.newCanvas(80, 80)
            love.graphics.setCanvas({ sorted_shadow_canvas, stencil = true })
            love.graphics.origin()
            love.graphics.clear(1, 1, 1, 1)
            shadow_root:fullDraw()
            love.graphics.setCanvas()
            local sorted_shadow_data = sorted_shadow_canvas:newImageData()
            local shadow_only_r, shadow_only_g, shadow_only_b =
                sorted_shadow_data:getPixel(25, 38)
            local object_r, object_g, object_b, object_a =
                sorted_shadow_data:getPixel(30, 38)
            expect(shadow_only_r > 0.63 and shadow_only_r < 0.67
                and shadow_only_g > 0.63 and shadow_only_g < 0.67
                and shadow_only_b > 0.63 and shadow_only_b < 0.67,
                "the independently sorted shadow should retain its intended opacity")
            expect(object_r > 0.95 and object_g < 0.05 and object_b < 0.05
                and object_a > 0.95,
                "a foreground object must draw over the independently sorted shadow")
        end)()
    end

    if Mod and Mod.info.id == "mimicrune_prologue" then
        do
            (function()
                local fog_map_data = Registry.getMapData("wastes_entrance")
                local fog_root = Object()
                local fog_map = Map(fog_root, fog_map_data)
                fog_map.id = "wastes_entrance"
                fog_map:load()
                local fog_ground_layer = fog_map:getTileLayer("ground")
                local fog_wall_layer = fog_map:getTileLayer("groundcliff")
                expect(fog_map.terrain_edge_fog_object
                    and fog_map.underwater_underlay
                    and fog_map.underwater_underlay_object
                    and fog_map.underwater_underlay_opacity == 0.68
                    and fog_map.underwater_underlay_void_strength == 1
                    and fog_map.underwater_underlay_speed == 1
                    and fog_map.underwater_underlay_distortion == 6
                    and fog_map.underwater_underlay_particle_strength == 0.35
                    and fog_map.underwater_underlay_object.layer
                        > fog_map.layers["Crags1"]
                    and fog_map.underwater_underlay_object.layer
                        < fog_map.terrain_edge_fog_object.layer
                    and fog_map.underwater_underlay_object.layer
                        < fog_ground_layer.layer
                    and fog_map.terrain_edge_fog_object.lowest_z == 0
                    and fog_map.terrain_edge_fog_object.distance_field
                    and #fog_map.terrain_edge_fog_object.lowest_tile_layers == 0
                    and #fog_map.terrain_edge_fog_object.lowest_support_colliders
                        == 9
                    and fog_map.terrain_edge_fog_surface_id == "4"
                    and #fog_map.terrain_edge_fog_objects == 2
                    and fog_map.terrain_edge_fog_objects[2].z == 40
                    and fog_map.terrain_edge_fog_object.layer
                        < fog_ground_layer.layer
                    and fog_map.terrain_edge_fog_object.layer
                        < fog_wall_layer.layer,
                    "the wastes entrance should fog authored void edges beneath its ground artwork")
            end)()
        end

        local platforming_map_data = Registry.getMapData("test")
        local platforming_root = Object()
        local platforming_map = Map(platforming_root, platforming_map_data)
        platforming_map.id = "test"
        platforming_map:load()
        expect(#platforming_map.height_occluders == 3,
            "the test map should use proxies only for genuinely raised structures")
        for _, occluder in ipairs(platforming_map.height_occluders) do
            local mask_points = occluder:getOcclusionMaskPoints()
            local mask_max_y = -math.huge
            for _, point in ipairs(mask_points) do
                mask_max_y = math.max(mask_max_y, point[2])
            end
            expect(occluder:resolveSourceLayer() ~= nil
                and occluder:resolveSurface() ~= nil
                and type(occluder.occlusion_depth) == "number"
                and type(occluder.face_position) == "number"
                and occluder.sort_y == occluder.face_position
                    + occluder.sort_y_offset
                and (occluder.face_direction ~= "front"
                    or mask_max_y <= occluder.face_position + 0.001)
                and occluder.layer == platforming_map.object_layer,
                "test-map faces should clip their dynamic pixels at the resolved depth boundary")
        end

        local front_floor = platforming_map:getSurface("front_floor")
        local back_floor = platforming_map:getSurface("back_floor")
        local center_tower = platforming_map:getSurface("center_tower")
        local left_tower = platforming_map:getSurface("left_tower")
        expect(front_floor and back_floor and center_tower and left_tower
            and front_floor.plane == "base" and back_floor.plane == "base"
            and platforming_map:getImplicitSurface().plane == "base"
            and center_tower.top == 80 and center_tower.plane == "upper_80"
            and left_tower.support_bounds.max_y == 280
            and left_tower.bounds.max_y == 320,
            "same-height floors should share an explicit plane independent of art layers")

        do
            local test_savepoint = platforming_map.events_by_name.savepoint
                and platforming_map.events_by_name.savepoint[1]
            local save_visual_x, save_visual_y =
                test_savepoint:getFullVisualTransform():transformPoint(
                    test_savepoint.width / 2, test_savepoint.height / 2)
            local anchor_local_x = test_savepoint.width / 4 + 2
            local anchor_local_y = test_savepoint.height / 4 + 2
            local expected_anchor_x, expected_anchor_y =
                test_savepoint:localToVisualScreenPos(anchor_local_x, anchor_local_y)
            local menu_anchor_x, menu_anchor_y = SaveMenu.getAnchorPosition({
                point = {
                    stage = true,
                    width = test_savepoint.width,
                    height = test_savepoint.height,
                    localToVisualScreenPos = function(_, x, y)
                        return test_savepoint:localToVisualScreenPos(x, y)
                    end
                }
            })
            expect(test_savepoint and test_savepoint.surface_id == "left_tower"
                and test_savepoint.z == 120 and test_savepoint.y == 220
                and math.abs(save_visual_x - 140) < 0.001
                and math.abs(save_visual_y - 100) < 0.001
                and test_savepoint.ground_surface == left_tower
                and test_savepoint.height_sensitive
                and test_savepoint.height_sort_subject
                and test_savepoint.use_3d_collision,
                "the test savepoint should occupy and render on the left tower's top surface")
            expect(math.abs(menu_anchor_x - expected_anchor_x) < 0.001
                and math.abs(menu_anchor_y - expected_anchor_y) < 0.001,
                "the dark save menu should anchor to an elevated savepoint's projected position")
        end
        World.sortChildren(platforming_root)
        local front_tiles = platforming_map:getDrawableLayer("Tiles")
        local terrain_canvas = love.graphics.newCanvas(640, 480)
        local front_floor_canvas = love.graphics.newCanvas(640, 480)
        love.graphics.setCanvas({ terrain_canvas, stencil = true })
        love.graphics.origin()
        love.graphics.clear(0, 0, 0, 0)
        platforming_root:fullDraw()
        love.graphics.setCanvas({ front_floor_canvas, stencil = true })
        love.graphics.origin()
        love.graphics.clear(0, 0, 0, 0)
        front_tiles:fullDraw(true)
        love.graphics.setCanvas()
        local terrain_data = terrain_canvas:newImageData()
        local floor_data = front_floor_canvas:newImageData()
        local actual_r, actual_g, actual_b, actual_a = terrain_data:getPixel(100, 400)
        local floor_r, floor_g, floor_b, floor_a = floor_data:getPixel(100, 400)
        expect(floor_a > 0.95 and actual_a > 0.95
            and math.abs(actual_r - floor_r) < 0.001
            and math.abs(actual_g - floor_g) < 0.001
            and math.abs(actual_b - floor_b) < 0.001,
            "back-pillar proxies must not overwrite the test map's front floor")

        local map_player = Object(444, 381)
        map_player.height_sort_subject = true
        map_player.use_3d_collision = true
        map_player.z = 40
        map_player.layer = platforming_map.object_layer
        local map_sort_world = setmetatable({
            children = TableUtils.copy(platforming_map.height_occluders),
            player = map_player
        }, { __index = World })
        table.insert(map_sort_world.children, map_player)
        World.sortChildren(map_sort_world)
        local function terrainOrder()
            local names = {}
            for _, child in ipairs(map_sort_world.children) do
                if child ~= map_player then table.insert(names, child.data.name) end
            end
            return table.concat(names, "|")
        end
        local authored_terrain_order = table.concat({
            "Left Tower Visual", "Center Tower Visual",
            "Right Platform Visual"
        }, "|")
        expect(terrainOrder() == authored_terrain_order,
            "the updated test map should preserve authored terrain order at z=40")
        map_player.y = 600
        map_player.z = 120
        World.sortChildren(map_sort_world)
        expect(terrainOrder() == authored_terrain_order,
            "moving above and in front of the pillars should never resort the terrain")

        local front_player = Object(321, 340)
        front_player.height_sort_subject = true
        front_player.use_3d_collision = true
        front_player.z = 0
        front_player.layer = platforming_map.object_layer
        platforming_root:addChild(front_player)
        platforming_root.player = front_player
        World.sortChildren(platforming_root)
        local named_occluders = {}
        for _, occluder in ipairs(platforming_map.height_occluders) do
            named_occluders[occluder.data.name] = occluder
        end
        local center_face = named_occluders["Center Tower Visual"]
        local left_face = named_occluders["Left Tower Visual"]
        expect(center_face.face_position == 320 and center_face.sort_y == 320
            and center_face.mask_sort_y == 480
            and not center_face:isCharacterBehindFace(front_player)
            and center_face:getCharacterDepthResult(front_player) == "character"
            and center_face:getCharacterCutout(center_face.source_layer) == nil,
            "the same-height back floor must remain in front of the center wall on its near side")

        front_player.y = 300
        front_player.z = 0
        World.sortChildren(platforming_root)
        expect(center_face:isCharacterBehindFace(front_player)
            and center_face:getCharacterDepthResult(front_player) == "terrain"
            and center_face:isDrawnAfterCharacter(front_player),
            "the same center wall must cover a low character on its far side")

        front_player.x = 270
        expect(not center_face:isCharacterBehindFace(front_player),
            "brushing a platform side outside its support span must not start occlusion")
        front_player.x = 300
        expect(center_face:isCharacterBehindFace(front_player),
            "the same face should occlude once the player's foot point enters its lateral span")

        front_player.x = 120
        front_player.y = 281
        front_player.z = 119
        front_player.ground_surface = nil
        front_player.airborne_surface = left_tower
        expect(left_face.face_position == 280
            and left_face:getCharacterDepthResult(front_player) == "character",
            "dropping from the left platform's bottom edge must immediately remain on its near side")
        front_player.y = 279
        expect(left_face:getCharacterDepthResult(front_player) == "terrain",
            "falling from the far side of that support edge should still pass behind the tower")

        front_player.x = 321
        front_player.z = 80
        front_player.ground_surface = center_tower
        expect(center_face:getCharacterDepthResult(front_player) == "character"
            and center_face:getCharacterReveal() == front_player,
            "jumping to the center surface elevation should clear its depth face")

        front_player.ground_surface = nil
        front_player.airborne_surface = center_tower
        front_player.z = 40
        expect(center_face:getCharacterDepthResult(front_player) == "terrain",
            "remembering a departed surface must not keep an actor visible after falling below its top")

        front_player.y = 340
        front_player.z = 0
        front_player.airborne_surface = nil
        local before_order = terrainOrder()
        World.sortChildren(platforming_root)
        expect(terrainOrder() == before_order
            and center_face:getCharacterDepthResult(front_player) == "character",
            "crossing between same-plane art layers must not reorder terrain or infer a new plane")
    end

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
