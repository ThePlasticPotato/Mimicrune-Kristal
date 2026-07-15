--- A standalone background for Goner battles. It deliberately does not inherit
--- from BattleBackground or use any of the normal battle background rendering.
---@class GonerBattleBackground : Object
---@overload fun() : GonerBattleBackground
local GonerBattleBackground, super = Class(Object)

function GonerBattleBackground:init()
    super.init(self, 0, 0, SCREEN_WIDTH, SCREEN_HEIGHT)

    self.debug_select = false
    self.layer = BATTLE_LAYERS["background"]
    self.alpha = 0
    self.fading_out = false
    self.time = 0
    self.fault_timer = 0
    self.faults = {}
    self.grid_scroll = 0
    self.vanishing_x = SCREEN_WIDTH * 0.78
    self.horizon_y = SCREEN_HEIGHT * 0.29

    self.device_color = ColorUtils.hexToRGB("#c8c9be")
    self.screen_color = ColorUtils.hexToRGB("#111312")
    self:regenerateFaults()
end

function GonerBattleBackground:regenerateFaults()
    self.faults = {}
    for _ = 1, 12 do
        table.insert(self.faults, {
            x = love.math.random(-24, SCREEN_WIDTH - 20),
            y = love.math.random(18, SCREEN_HEIGHT - 20),
            width = love.math.random(18, 150),
            height = love.math.random(1, 5),
            phase = love.math.random() * math.pi * 2,
        })
    end
end

function GonerBattleBackground:isFading()
    return self.fading_out
end

function GonerBattleBackground:fadeOut()
    self.fading_out = true
end

function GonerBattleBackground:update()
    self.time = self.time + DT
    self.grid_scroll = (self.grid_scroll + DT * 0.32) % 1
    self.fault_timer = self.fault_timer + DTMULT

    if self.fault_timer >= 18 then
        self.fault_timer = self.fault_timer - 18
        self:regenerateFaults()
    end

    if self.fading_out then
        self.alpha = MathUtils.approach(self.alpha, 0, 0.08 * DTMULT)
        if self.alpha <= 0 then
            self:remove()
        end
    else
        self.alpha = MathUtils.approach(self.alpha, 1, 0.04 * DTMULT)
    end

    super.update(self)
end

function GonerBattleBackground:drawPerspectiveGrid(alpha)
    local r, g, b = unpack(self.device_color)
    local vanishing_x = self.vanishing_x
    local horizon_y = self.horizon_y
    local floor_y = SCREEN_HEIGHT + 24
    local ground_left = -360
    local ground_right = SCREEN_WIDTH + 420

    love.graphics.setLineWidth(1)
    for endpoint_x = ground_left, ground_right, 72 do
        local distance = math.abs(endpoint_x - vanishing_x) / SCREEN_WIDTH
        Draw.setColor(r, g, b, alpha * (0.12 + math.min(distance, 1) * 0.12))
        love.graphics.line(vanishing_x, horizon_y, endpoint_x, floor_y)
    end

    for index = 0, 15 do
        local depth = (index + self.grid_scroll) / 15
        if depth <= 1 then
            local projected = depth * depth
            local y = horizon_y + ((floor_y - horizon_y) * projected)
            local left = vanishing_x + ((ground_left - vanishing_x) * projected)
            local right = vanishing_x + ((ground_right - vanishing_x) * projected)
            Draw.setColor(r, g, b, alpha * (0.08 + depth * 0.34))
            love.graphics.line(left, y, right, y)
        end
    end

    Draw.setColor(r, g, b, alpha * 0.4)
    love.graphics.setLineWidth(2)
    love.graphics.line(0, horizon_y, SCREEN_WIDTH, horizon_y)

    Draw.setColor(r, g, b, alpha * 0.18)
    love.graphics.setLineWidth(1)
    love.graphics.rectangle("line", 10, 10, SCREEN_WIDTH - 20, SCREEN_HEIGHT - 20)
end

function GonerBattleBackground:drawFaults(alpha)
    local r, g, b = unpack(self.device_color)
    for index, fault in ipairs(self.faults) do
        local pulse = 0.35 + math.sin(self.time * (5 + index * 0.13) + fault.phase) * 0.25
        Draw.setColor(r, g, b, alpha * math.max(0.04, pulse))
        love.graphics.rectangle("fill", fault.x, fault.y, fault.width, fault.height)

        if index % 3 == 0 then
            Draw.setColor(0, 0, 0, alpha * 0.8)
            love.graphics.rectangle("fill", fault.x + 8, fault.y, math.max(2, fault.width / 3), fault.height)
        end
    end
end

function GonerBattleBackground:draw()
    local transition_alpha = 1
    if Game.battle then
        transition_alpha = MathUtils.clamp(Game.battle.transition_timer / 10, 0, 1)
    end
    local alpha = self.alpha * transition_alpha
    local sr, sg, sb = unpack(self.screen_color)

    Draw.setColor(sr, sg, sb, alpha)
    love.graphics.rectangle("fill", -8, -8, SCREEN_WIDTH + 16, SCREEN_HEIGHT + 16)

    self:drawPerspectiveGrid(alpha)
    self:drawFaults(alpha)

    Draw.setColor(1, 1, 1, 1)
    love.graphics.setLineWidth(1)
    super.draw(self)
end

return GonerBattleBackground
