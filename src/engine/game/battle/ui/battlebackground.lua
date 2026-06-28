--- The battle background object. By default, this is a purple grid.
---
--- This gets automatically spawned during battles; if you'd like to disable or customize it, override [`Encounter:createBackground`](lua://Encounter.createBackground).
---
---@class BattleBackground : Object
---
---@field position number An offset used to scroll the background.
---@field position2 number Another offset used to scroll the background.
---@field move_speed number The speed at which the background scrolls.
---@field private fading_out boolean Whether the background is currently fading out or not.
---
---@overload fun(tense: boolean) : BattleBackground
---@overload fun() : BattleBackground
local BattleBackground, super = Class(Object)

function BattleBackground:init(tense)
    super.init(self, 0, 0, SCREEN_WIDTH, SCREEN_HEIGHT)

    self.debug_select = false

    self.layer = BATTLE_LAYERS["background"]

    self.position = 0
    self.position2 = 0
    self.move_speed = 1
    self.alpha = 0

    self.fading_out = false
    self.tense = tense

    self.glow_siner = 0
    self.surface_siner = 0
    self.offset = 0

    self.spotlights = {}
    self.bars = {}

    self.bg_primary = {0.85, 0.85, 0.85}
    self.bg_secondary = {1, 1, 1}
    self.bg_primaries = {
        none = {0.85, 0.85, 0.85},
        violence = {66/255, 0, 11/255},
        enemy = {66 / 255, 0, 33 / 255},
        evan = {0, 66 / 255, 33 / 255},
        cassidy = {211/255/2, 130/255/2, 75/255/2},
        fredbear = {66 / 255, 0, 66 / 255},
    }
    self.bg_secondaries = {
        none = {1,1,1},
        violence = {0.5, 0, 11/255},
        enemy = {0.5, 0, 33 / 255},
        evan = {0, 0.5, 11/255},
        cassidy = {0.8, 200/255, 43/255},
        fredbear = {0.5, 0, 0.5},
    }

    self:setParallax(0, 0)

    if self.tense then
        self.fountain = TaintedFountainBase({x = SCREEN_WIDTH/2, y = (-373), properties = {}}, true)
        self.fountain.layer = BATTLE_LAYERS["bottom"] - 1
        self.fountain.wing_left:setParent(self)
        self.fountain.wing_left.visible = false
        self.fountain.wing_right:setParent(self)
        self.fountain.wing_right.visible = false
        self:addChild(self.fountain)
    end
end

function BattleBackground:update()
    super.update(self)

    self.position = self.position + (self.move_speed / 2) * DTMULT
    self.position2 = self.position2 + self.move_speed * DTMULT

    if self.position >= 100 then
        self.position = self.position - 100
    end

    if self.position2 >= 100 then
        self.position2 = self.position2 - 100
    end

    local offsetSpeed = self.tense and 4 or 1

    self.offset = self.offset + offsetSpeed * DTMULT
    self.surface_siner = self.surface_siner + 2 * DTMULT
    self.glow_siner = self.glow_siner + DT

    if self.offset > 100 then
        self.offset = self.offset - 100
    end

    if not self.fading_out then
        self.alpha = MathUtils.approach(self.alpha, 1, 0.1 * DTMULT)
    else
        self.alpha = MathUtils.approach(self.alpha, 0, 0.1 * DTMULT)

        if self.alpha <= 0 then
            self:remove()
        end
    end
end

--- Returns whether the battle background is currently fading out or not.
---@return boolean
function BattleBackground:isFading()
    return self.fading_out
end

--- Request the battle background to fade out. The background will automatically be removed once it has fully faded out.
function BattleBackground:fadeOut()
    self.fading_out = true
end


function BattleBackground:getBattleBGColor()
    local primary = self.bg_primaries.none
    local secondary = self.bg_secondaries.none
    
    local party = Game.battle.party
    local currentSelecting = Game.battle.current_selecting
    local state = Game.battle.state
    local currentAction = Game.battle:getCurrentAction()
    local activeEnemies = Game.battle:getActiveEnemies()

    if state == "DEFENDING" or state == "DEFENDINGBEGIN" or state == "DEFENDINGEND" or state == "ENEMYSELECT" or state == "ACTIONSDONE" or (state == "ENEMYDIALOGUE" and #activeEnemies > 0) then
        primary = self.bg_primaries.enemy
        secondary = self.bg_secondaries.enemy
    elseif state == "ACTIONSELECT" then
        local member = Game.party[currentSelecting]
        local selecting = member and member.id or "evan"
        primary = self.bg_primaries[selecting] or self.bg_primaries.evan
        secondary = self.bg_secondaries[selecting] or self.bg_secondaries.evan
    elseif state == "ACTIONS" or state == "BATTLETEXT" then
        local actioning = currentAction and currentAction.character_id or "evan"
        primary = self.bg_primaries[actioning] or self.bg_primaries.evan
        secondary = self.bg_secondaries[actioning] or self.bg_secondaries.evan
    elseif state == "MENUSELECT" or state == "PARTYSELECT" then
        local highlighted = "evan"
        for _,member in ipairs(party) do
            if (Game.battle:isHighlighted(member)) then
                local id = member.chara.id
                highlighted = id
                break
            end
        end
        primary = self.bg_primaries[highlighted] or self.bg_primaries.evan
        secondary = self.bg_secondaries[highlighted] or self.bg_secondaries.evan
    elseif state == "ATTACKING" then
        primary = self.bg_primaries.violence
        secondary = self.bg_secondaries.violence
    elseif state == "VICTORY" or state == "TRANSITIONOUT" or (state == "ENEMYDIALOGUE" and #activeEnemies == 0) then
        primary = self.bg_primaries.evan
        secondary = self.bg_primaries.evan
    end
    self.bg_primary = ColorUtils.mergeColor(self.bg_primary, primary, 0.12 * DTMULT)
    self.bg_secondary = ColorUtils.mergeColor(self.bg_secondary, secondary, 0.12 * DTMULT)
    return ColorUtils.mergeColor(self.bg_primary, {1,1,1}, math.sin(self.glow_siner) / 8), ColorUtils.mergeColor(self.bg_secondary, {1,1,1}, math.sin(self.glow_siner) / 8)
end

function BattleBackground.floorStencil()
    love.graphics.rectangle("fill", -8, 80, SCREEN_WIDTH+16, 380-130)
end

function BattleBackground:drawBackground(fade)
    Draw.setColor(0, 0, 0, fade)
    love.graphics.rectangle("fill", -8, -8, SCREEN_WIDTH+16, SCREEN_HEIGHT+16)
    local primary, secondary = self:getBattleBGColor()

    -- love.graphics.setLineStyle("rough")
    -- love.graphics.setLineWidth(1)

    -- for i = 2, 16 do
    --     Draw.setColor(0, 66 / 255, 33 / 255, (self.transition_timer / 10) / 2)
    --     love.graphics.line(0, -210 + (i * 50) + math.floor(self.offset / 2), 640, -210 + (i * 50) + math.floor(self.offset / 2))
    --     love.graphics.line(-200 + (i * 50) + math.floor(self.offset / 2), 0, -200 + (i * 50) + math.floor(self.offset / 2), 480)
    -- end

    -- for i = 3, 16 do
    --     Draw.setColor(0, 66 / 255, 33 / 255, self.transition_timer / 10)
    --     love.graphics.line(0, -100 + (i * 50) - math.floor(self.offset), 640, -100 + (i * 50) - math.floor(self.offset))
    --     love.graphics.line(-100 + (i * 50) - math.floor(self.offset), 0, -100 + (i * 50) - math.floor(self.offset), 480)
    -- end
    for i = 0, 11 do
        local siner = self.surface_siner + (i * (10 * math.pi))

        love.graphics.setLineWidth(2)
        Draw.setColor(primary, fade * math.sin(siner / 60))
        if math.cos(siner / 60) < 0 then
            love.graphics.line(0, 360 - (math.sin(siner / 60) * 60) + 30, SCREEN_WIDTH, 360 - (math.sin(siner / 60) * 60) + 30)
            --love.graphics.line(0, 211 + (math.sin(siner / 60) * 30) - 30, SCREEN_WIDTH, 211 + (math.sin(siner / 60) * 30) - 30)
        end
    end

    if (Game.battle.using_fft and Game.battle.music:isPlaying() and Game.fft and Game.fft:getSoundData()) then
        self:drawVisualizer(fade, secondary, primary)
    end

    love.graphics.stencil(self.floorStencil, "replace", 1)
    love.graphics.setStencilTest("greater", 0)
    Draw.setColor(0, 0, 0, fade)
    love.graphics.rectangle("fill", -8, 80, SCREEN_WIDTH+16, 380-128)

    love.graphics.setLineStyle("rough")
    love.graphics.setLineWidth(1)

    for i = -2, 20 do
        Draw.setColor(primary, (fade) / 2)
        love.graphics.line(0, -210 + (i * 50) + math.floor(self.offset / 2), 640, 210 + (i * 50) + math.floor(self.offset / 2))
        love.graphics.line(-200 + (i * 50) + math.floor(self.offset / 2), 0, 200 + (i * 50) + math.floor(self.offset / 2), 480)
    end

    for i = 0, 20 do
        Draw.setColor(primary, fade)
        love.graphics.line(0, -100 + (i * 50) - math.floor(self.offset), 640, 100 + (i * 50) - math.floor(self.offset))
        love.graphics.line(-100 + (i * 50) - math.floor(self.offset), 0, 100 + (i * 50) - math.floor(self.offset), 480)
    end
    love.graphics.setStencilTest()
    Draw.setColor(secondary)
    love.graphics.setLineWidth(2)
    love.graphics.line(0, 330, SCREEN_WIDTH, 330)
    love.graphics.line(0, 80, SCREEN_WIDTH, 80)

    -- if (self.using_fft and self.music:isPlaying() and Game.fft and Game.fft:getSoundData()) then
    --     self:drawVisualizer(fade, secondary)
    -- end
end

function BattleBackground:drawTenseBackground(fade)
    Draw.setColor(0, 0, 0, fade)
    love.graphics.rectangle("fill", -8, -8, SCREEN_WIDTH+16, SCREEN_HEIGHT+16)
    for i = 0, 11 do
        local siner = self.surface_siner + (i * (10 * math.pi))

        love.graphics.setLineWidth(2)
        Draw.setColor(66 / 255, 0, 11 / 255, fade * math.sin(siner / 60))
        if math.cos(siner / 60) < 0 then
            love.graphics.line(0, 360 - (math.sin(siner / 60) * 60) + 30, SCREEN_WIDTH, 360 - (math.sin(siner / 60) * 60) + 30)
            --love.graphics.line(0, 211 + (math.sin(siner / 60) * 30) - 30, SCREEN_WIDTH, 211 + (math.sin(siner / 60) * 30) - 30)
        end
    end

    love.graphics.stencil(self.floorStencil, "replace", 1)
    love.graphics.setStencilTest("greater", 0)
    Draw.setColor(0, 0, 0, fade)
    love.graphics.rectangle("fill", -8, 80, SCREEN_WIDTH+16, 380-128)

    love.graphics.setLineStyle("rough")
    love.graphics.setLineWidth(1)

    for i = -2, 20 do
        Draw.setColor(66 / 255, 0, 11 / 255, (fade) / 2)
        love.graphics.line(0, -210 + (i * 50) + math.floor(self.offset / 2), 640, 210 + (i * 50) + math.floor(self.offset / 2))
        love.graphics.line(-200 + (i * 50) + math.floor(self.offset / 2), 0, 200 + (i * 50) + math.floor(self.offset / 2), 480)
    end

    for i = 0, 20 do
        Draw.setColor(66 / 255, 0, 11 / 255, fade)
        love.graphics.line(0, -100 + (i * 50) - math.floor(self.offset), 640, 100 + (i * 50) - math.floor(self.offset))
        love.graphics.line(-100 + (i * 50) - math.floor(self.offset), 0, 100 + (i * 50) - math.floor(self.offset), 480)
    end
    love.graphics.setStencilTest()
    Draw.setColor(0.5, 0, 11/255)
    love.graphics.setLineWidth(2)
    love.graphics.line(0, 330, SCREEN_WIDTH, 330)
    love.graphics.line(0, 80, SCREEN_WIDTH, 80)
end

function BattleBackground:drawVisualizer(fade, color, secondary)
    Game.battle.fft_array = Game.fft:get() -- This operation takes almost no time
    local barWidth = SCREEN_WIDTH / 512 * 8 -- We only take care of the lowest 1/8 of the frequencies because it is where most energy resides
    Draw.setColor(color, (fade) / 2)
    local dark = true
    local displayed = math.max(2, math.floor(32 * (Game:getTension() / Game:getMaxTension())))
    for i = 1, 32 do
        local disabled = i > displayed
        if (dark) then
            dark = false
            Draw.setColor(color, (fade) / (disabled and 4 or MathUtils.lerp(3, 1, Game:getTension() / Game:getMaxTension())))
        else
            dark = true
            Draw.setColor(secondary, (fade) / (disabled and 4 or MathUtils.lerp(3, 1, Game:getTension() / Game:getMaxTension())))
        end
        if (not self.bars[i]) then
            self.bars[i] = {height = 0, max_height = 0, max_height_timer = 0}
        end
        local barHeight = Game.battle.fft_array[i] * 450 -- H is window height
        if (disabled) then barHeight = -10 end
        self.bars[i].height = MathUtils.approach(self.bars[i].height, barHeight, DTMULT * 4)
        if (self.bars[i].max_height < self.bars[i].height) then
            self.bars[i].max_height = self.bars[i].height
            self.bars[i].max_height_timer = 15
        end
        self.bars[i].max_height_timer = MathUtils.approach(self.bars[i].max_height_timer, 0, DTMULT * (2 / math.max(1, self.bars[i].max_height_timer)))
        if (self.bars[i].max_height_timer == 0) then
            self.bars[i].max_height = barHeight
        end
        love.graphics.rectangle("fill", (i - 1) * barWidth * 2 + 4, -self.bars[i].height + 69, barWidth, math.max(11 + self.bars[i].height, 0))
        love.graphics.rectangle("fill", (i - 1) * barWidth * 2 + 4, -self.bars[i].height + 59 + (disabled and 11 or 0), barWidth, 4)
        --love.graphics.rectangle("line", (i - 1) * barWidth * 2 + 4, 59 + (disabled and 11 or 0) - math.max(self.bars[i].max_height * (math.min(10, self.bars[i].max_height_timer) / 10), self.bars[i].height), barWidth, 4)
        love.graphics.rectangle("line", (i - 1) * barWidth * 2 + 4, 59 + (disabled and 11 or 0) - math.max(Ease.inCubic(math.max(0, 10 - self.bars[i].max_height_timer), self.bars[i].max_height, -self.bars[i].max_height, 10), self.bars[i].height), barWidth, 4)

    end
end

function BattleBackground:drawSpotlights()
    for index, battler in ipairs(Game.battle.party) do
        if not self.spotlights[index] then
            self.spotlights[index] = {width = 0, visible = false, offset = 0}
        end
        if Game.battle:shouldHaveSpotlight(battler) then
           self.spotlights[index].width = MathUtils.approach(self.spotlights[index].width, 32, DTMULT * 4)
        else
            self.spotlights[index].width = MathUtils.approach(self.spotlights[index].width, 0, DTMULT * 8)
        end
        self.spotlights[index].visible = self.spotlights[index].width > 0

        if self.spotlights[index].visible then
            self.spotlights[index].offset = self.spotlights[index].offset + (DT * 2)
            Draw.setColor(ColorUtils.mergeColor(self.bg_secondaries[battler.chara.id], {1,1,1, 0.75}, 0.5) or self.bg_secondaries.none, 0.75)
            love.graphics.polygon("fill",
                battler.x - 125, battler.y - 175,
                battler.x + battler.width/2 - self.spotlights[index].width + math.sin(self.spotlights[index].offset) * 4, battler.y,
                battler.x + battler.width / 2 + self.spotlights[index].width-4 + math.sin(self.spotlights[index].offset) * 8, battler.y,
                battler.x + battler.width / 2 + self.spotlights[index].width + math.sin(self.spotlights[index].offset) * 8, battler.y - 4
            )
            Draw.setColor(ColorUtils.mergeColor(self.bg_secondaries[battler.chara.id], {1,1,1, 0.75}, 0.75) or self.bg_secondaries.none, 0.75)
            love.graphics.polygon("fill",
                battler.x - 125, battler.y - 175,
                battler.x + battler.width/2 - self.spotlights[index].width/1.5 + math.sin(self.spotlights[index].offset) * 4, battler.y,
                battler.x + battler.width / 2 + self.spotlights[index].width/1.5 + math.sin(self.spotlights[index].offset) * 8, battler.y
            )
        end
    end
    Draw.setColor(1,1,1,1)
end

function BattleBackground:draw()
    local fade = Game.battle.transition_timer / 10
    if not self.tense then self:drawBackground(fade) else self:drawTenseBackground(fade) end
    -- Draw.setColor(0, 0, 0, self.background_fade_alpha)
    -- love.graphics.rectangle("fill", -20, -20, SCREEN_WIDTH + 40, SCREEN_HEIGHT + 40)

    if not (self.tense) then
        self:drawSpotlights()
    end
    Draw.setColor(1, 1, 1)
    super.draw(self)
end

return BattleBackground
