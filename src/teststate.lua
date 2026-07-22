local Testing = {}

function Testing:enter()
    if Kristal.Args["test"] and Kristal.Args["test"][1] == "platforming" then
        self:runPlatformingTests()
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

    fake_world.surfaces = {}
    landing_z = fake_world:getLandingSurface(probe, 5, -5)
    expect(landing_z == 0, "ordinary empty space should land on implicit z=0 ground")

    local pit = Hitbox(probe_parent, 0, 0, 20, 20)
    fake_world.map.pits = { pit }
    landing_z = fake_world:getLandingSurface(probe, 5, -5)
    expect(landing_z == nil, "an explicit pit should suppress implicit ground")

    local authored = MapUtils.colliderFromShape(probe_parent, {
        shape = "rectangle", width = 8, height = 8
    }, 0, 0, { z = 4, depth = 12 })
    expect(authored.z == 4 and authored.depth == 12 and authored.supports,
        "authored positive-depth colliders should expose a supported top surface")

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
