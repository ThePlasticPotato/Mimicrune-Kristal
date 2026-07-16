---@class GonerBattle : Battle
---@overload fun() : GonerBattle
local GonerBattle, super = Class(Battle)

function GonerBattle:init()
    if #Game.party == 0 then
        error("GonerBattle requires one party member")
    end

    super.init(self)

    self.goner_transition_time = 0
    self.goner_transition_length = 26
    self.goner_fade_length = 42
    self.goner_snapshot = nil
    self.goner_exit_snapshot = nil
    self.goner_exit_time = nil
    self.goner_music = "meatfactory"

    -- The normal battle description panel is replaced by the DEVICE
    self.description_panel.visible = false
end

function GonerBattle:createPartyBattlers()
    local party_member = Game.party[1]
    local start_x, start_y = SCREEN_WIDTH / 2, SCREEN_HEIGHT / 2
    local world_character

    if Game.world and Game.world.player and Game.world.player.visible
        and Game.world.player.actor.id == party_member:getActor().id then
        world_character = Game.world.player
    elseif Game.world then
        for _, follower in ipairs(Game.world.followers) do
            if follower.visible and follower.actor.id == party_member:getActor().id then
                world_character = follower
                break
            end
        end
    end

    if world_character then
        start_x, start_y = world_character:getScreenPos()
        self.party_world_characters[party_member.id] = world_character
        world_character.visible = false
    end

    local battler = GonerPartyBattler(party_member, start_x, start_y)
    battler:setAnimation("battle/transition")
    self:addChild(battler)
    table.insert(self.party, battler)
    table.insert(self.party_beginning_positions, {start_x, start_y})

    self.spotlights = {{width = 0, visible = false, offset = 0}}
end

function GonerBattle:createDescriptionPanel()
    return GonerDescriptionPanel()
end

function GonerBattle:createBattleUI()
    return self:addChild(GonerBattleUI())
end

function GonerBattle:createTensionBar()
    return nil
end

function GonerBattle:createBackground()
    return self.encounter:createGonerBackground()
end

function GonerBattle:configureArena(arena)
    local custom_shape = false
    for _, wave in ipairs(self.waves) do
        if wave.arena_shape then
            custom_shape = true
            break
        end
    end

    arena.line_width = 2
    arena:setColor(200 / 255, 201 / 255, 190 / 255)

    if custom_shape then
        arena:setShape(arena.shape)
        return
    end

    local width, height = arena.width, arena.height
    local corner = MathUtils.clamp(math.floor(math.min(width, height) * 0.12), 12, 24)
    arena:setShape({
        {corner, 0},
        {width - corner, 0},
        {width, corner},
        {width, height - corner},
        {width - corner, height},
        {corner, height},
        {0, height - corner},
        {0, corner},
    })
end

function GonerBattle:captureTransitionSnapshot()
    if not SCREEN_CANVAS then return end
    local success, image = pcall(function()
        return love.graphics.newImage(SCREEN_CANVAS:newImageData())
    end)
    if success then
        return image
    end
end

function GonerBattle:startGonerMusic()
    if self.goner_music == "none" or not self.goner_music or self.music:isPlaying() then
        return
    end
    self.music:play(self.goner_music, 0)
    self.music:fade(1, 2.5)
end

function GonerBattle:postInit(state, encounter)
    self.goner_snapshot = self:captureTransitionSnapshot()

    if type(encounter) == "string" then
        encounter = Registry.createEncounter(encounter)
    end
    if encounter.music == "battle" then
        encounter.music = "meatfactory"
    end
    self.goner_music = encounter.music

    super.postInit(self, state, encounter)

    -- Goner encounters use a fixed over-the-shoulder view
    if self.battler_targets[1] then
        self.battler_targets[1] = {150, SCREEN_HEIGHT}
    end

    for index, battler in ipairs(self.party) do
        battler:setPosition(unpack(self.battler_targets[index]))
    end
    for _, enemy in ipairs(self.enemies) do
        enemy:setPosition(enemy.target_x, enemy.target_y)
    end

    if state == "TRANSITION" then
        self.transition_timer = 0
        self:startGonerMusic()
    end
end

function GonerBattle:onIntroState()
    self.seen_encounter_text = false
    self.intro_timer = 0
    self:startGonerMusic()

    for _, battler in ipairs(self.party) do
        battler:setAnimation("battle/intro")
    end
    self.encounter:onBattleStart()
end

function GonerBattle:startBattleMusic()
    self:startGonerMusic()
end

function GonerBattle:updateTransition()
    self.goner_transition_time = self.goner_transition_time + DTMULT
    self.transition_timer = MathUtils.clamp(
        (self.goner_transition_time / self.goner_transition_length) * 10,
        0,
        10
    )

    if self.goner_transition_time >= self.goner_transition_length then
        self.transition_timer = 10
        self:setState("INTRO")
    end
end

function GonerBattle:updateIntro()
    self.intro_timer = self.intro_timer + DTMULT
    if self.intro_timer >= self.goner_fade_length then
        self.goner_snapshot = nil
        for _, battler in ipairs(self.party) do
            battler:resetSprite()
        end
        self:setState("ACTIONSELECT", "INTRO")
    end
end

function GonerBattle:onTransitionOutState()
    super.onTransitionOutState(self)

    -- Let the DEVICE panels close, then freeze the unobstructed battle frame
    -- and bleed that image away instead of morphing the bust into its actor (cause that would look fugly)
    self.goner_exit_snapshot = nil
    self.goner_exit_time = nil
end

function GonerBattle:updateTransitionOut()
    if not self.battle_ui.animation_done then
        return
    end

    if not self.goner_exit_time then
        self.goner_exit_snapshot = self:captureTransitionSnapshot()
        self.goner_exit_time = 0
    end

    self.goner_exit_time = self.goner_exit_time + DTMULT
    if self.goner_exit_time < self.goner_transition_length then
        return
    end

    local enemies = {}
    for _, world_enemy in pairs(self.enemy_world_characters) do
        table.insert(enemies, world_enemy)
    end

    Game.fader:fadeIn(nil, {
        alpha = 1,
        speed = self.goner_fade_length / 30,
        color = COLORS.black,
        music = false,
    })
    self.encounter:onReturnToWorld(enemies)
    self:returnToWorld()
end

function GonerBattle:drawBleedSnapshot(snapshot, progress)
    if not snapshot then return end

    local shader = Assets.getShader("goner_bleed")
    shader:send("progress", MathUtils.clamp(progress, 0, 1))
    shader:send("time", Kristal.getTime())
    love.graphics.setShader(shader)
    Draw.setColor(1, 1, 1, 1)
    Draw.draw(snapshot)
    love.graphics.setShader()
end

function GonerBattle:drawGonerTransition()
    if self.state == "TRANSITION" then
        Draw.setColor(0, 0, 0, 1)
        love.graphics.rectangle("fill", 0, 0, SCREEN_WIDTH, SCREEN_HEIGHT)
        self:drawBleedSnapshot(
            self.goner_snapshot,
            self.goner_transition_time / self.goner_transition_length
        )
    elseif self.state == "INTRO" then
        local alpha = 1 - MathUtils.clamp(self.intro_timer / self.goner_fade_length, 0, 1)
        Draw.setColor(0, 0, 0, alpha)
        love.graphics.rectangle("fill", 0, 0, SCREEN_WIDTH, SCREEN_HEIGHT)
    elseif self.state == "TRANSITIONOUT" and self.goner_exit_time then
        Draw.setColor(0, 0, 0, 1)
        love.graphics.rectangle("fill", 0, 0, SCREEN_WIDTH, SCREEN_HEIGHT)
        self:drawBleedSnapshot(
            self.goner_exit_snapshot,
            self.goner_exit_time / self.goner_transition_length
        )
    end
    Draw.setColor(1, 1, 1, 1)
end

function GonerBattle:draw()
    super.draw(self)
    self:drawGonerTransition()
end

function GonerBattle:isWorldHidden()
    if self.state == "TRANSITIONOUT" then
        return true
    end
    return super.isWorldHidden(self)
end

return GonerBattle
