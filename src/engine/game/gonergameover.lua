---@class GonerGameOver : Object
---@overload fun(x?:number, y?:number) : GonerGameOver
local GonerGameOver, super = Class(Object, "gonergameover")

function GonerGameOver:init(x, y)
    super.init(self, 0, 0, SCREEN_WIDTH, SCREEN_HEIGHT)

    self.font = Assets.getFont("eb")
    self.cursor = Assets.getTexture("player/heart")
    self.music = Music()
    self.timer = 0
    self.phase = "DEATH"
    self.selected = 1
    self.interface_alpha = 0

    local captured, screenshot = pcall(function()
        return SCREEN_CANVAS and love.graphics.newImage(SCREEN_CANVAS:newImageData())
    end)
    self.screenshot = captured and screenshot or nil

    self.soul = Sprite("player/heart", x or SCREEN_WIDTH / 2, y or SCREEN_HEIGHT / 2)
    self.soul:setOrigin(0.5, 0.5)
    self.soul:setColor(Game:getSoulColor())
    self:addChild(self.soul)

    self.ui_move = Assets.newSound("ui_move_panel")
    self.ui_select = Assets.newSound("ui_select_panel")

    self:crt({SCREEN_WIDTH, SCREEN_HEIGHT}, false, {
        vertJerkOpt = 0,
        vertMovementOpt = 0,
        bottomStaticOpt = 0.04,
        scanlinesOpt = 0.14,
        rgbOffsetOpt = 0.06,
        horzFuzzOpt = 0.04,
    })
end

function GonerGameOver:onRemove(parent)
    super.onRemove(self, parent)
    self.music:remove()
end

function GonerGameOver:breakSoul()
    Assets.playSound("break1")
    self.soul:setSprite("player/heart_break")
end

function GonerGameOver:shatterSoul()
    Assets.playSound("break2")
    local color = {self.soul:getColor()}
    local x, y = self.soul:getPosition()
    self.soul:remove()
    self.soul = nil

    self.shards = {}
    for index = 1, 6 do
        local shard = Sprite("player/heart_shard", x, y)
        shard:setColor(color)
        shard.physics.direction = math.rad(((index - 1) * 60) + MathUtils.random(-18, 18))
        shard.physics.speed = MathUtils.random(5, 8)
        shard.physics.gravity = 0.2
        shard:play(5 / 30)
        self:addChild(shard)
        table.insert(self.shards, shard)
    end
end

function GonerGameOver:showInterface()
    self.phase = "MENU"
    self.screenshot = nil
    if self.shards then
        for _, shard in ipairs(self.shards) do shard:remove() end
        self.shards = nil
    end
    self.music:play("AUDIO_DEFEAT")
end

function GonerGameOver:attemptReconnection()
    self.music:stop()
    if Game.quick_save then
        Game:loadQuick(true)
    else
        Game:load(nil, nil, true)
    end
end

function GonerGameOver:update()
    self.timer = self.timer + DTMULT

    if self.phase == "DEATH" then
        if self.timer >= 24 and self.screenshot then
            self.screenshot = nil
        end
        if self.timer >= 45 then
            self:breakSoul()
            self.phase = "BREAK"
        end
    elseif self.phase == "BREAK" and self.timer >= 78 then
        self:shatterSoul()
        self.phase = "SHATTER"
    elseif self.phase == "SHATTER" and self.timer >= 125 then
        self:showInterface()
    elseif self.phase == "MENU" then
        self.interface_alpha = MathUtils.approach(self.interface_alpha, 1, 0.04 * DTMULT)
    end

    super.update(self)
end

function GonerGameOver:onKeyPressed(key)
    if self.phase ~= "MENU" or self.interface_alpha < 1 then return end

    if Input.is("left", key) or Input.is("right", key)
        or Input.is("up", key) or Input.is("down", key) then
        self.selected = self.selected == 1 and 2 or 1
        self.ui_move:stop()
        self.ui_move:play()
    elseif Input.isConfirm(key) then
        self.ui_select:stop()
        self.ui_select:play()
        if self.selected == 1 then
            self:attemptReconnection()
        else
            love.event.quit()
        end
    end
end

function GonerGameOver:drawCursor(x, y)
    local r, g, b = Game:getSoulColor()
    Draw.setColor(r, g, b, self.interface_alpha)
    Draw.draw(self.cursor, x, y + (self.font:getHeight() - self.cursor:getHeight() * 0.5) / 2, 0, 0.5, 0.5)
end

function GonerGameOver:draw()
    Draw.setColor(COLORS.black)
    love.graphics.rectangle("fill", 0, 0, SCREEN_WIDTH, SCREEN_HEIGHT)
    super.draw(self)

    if self.screenshot then
        Draw.setColor(1, 1, 1, 1)
        Draw.draw(self.screenshot)
    end

    if self.phase == "MENU" then
        love.graphics.setFont(self.font)
        local alpha = self.interface_alpha

        love.graphics.push()
        love.graphics.translate(SCREEN_WIDTH / 2, 132)
        love.graphics.scale(2, 2)
        Draw.setColor(1, 1, 1, alpha * 0.12)
        love.graphics.printf("CONNECTION LOST", -159, 1, 320, "center")
        Draw.setColor(1, 1, 1, alpha)
        love.graphics.printf("CONNECTION LOST", -160, 0, 320, "center")
        love.graphics.pop()

        Draw.setColor(1, 1, 1, alpha)
        love.graphics.print("ATTEMPT RECONNECTION", 116, 350)
        love.graphics.print("DO NOT", 490, 350)
        Draw.setColor(1, 1, 1, alpha * 0.35)
        if self.selected == 1 then
            self:drawCursor(90, 350)
        else
            self:drawCursor(464, 350)
        end
    end
    Draw.setColor(1, 1, 1, 1)
end

return GonerGameOver
