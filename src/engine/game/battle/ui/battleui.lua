---@class BattleUI : Object
---@overload fun(...) : BattleUI
---@field action_boxes table<ActionBox>
local BattleUI, super = Class(Object)

function BattleUI:init()
    super.init(self, 0, 565)

    self.layer = BATTLE_LAYERS["ui"]

    self.control_panel_target = -33
    self.control_panel_done = false
    self.control_panel = Sprite("ui/battle/panels/controlpanel", 76, 200)
    self.control_panel_screen = Sprite("ui/battle/panels/controlpanel_screen", 8, 8)
    self:addChild(self.control_panel)
    self.control_panel:addChild(self.control_panel_screen)
    self.control_panel:setLayer(-2)
    self.control_panel_screen:setLayer(20)
    --self.control_panel_screen:addFX(ShaderFX("vhs", {["iTime"] = function () return Kristal.getTime() end, ["texsize"] = {self.control_panel_screen.texture:getWidth(), self.control_panel_screen.texture:getHeight()}, ["noiseTex"] = Assets.getTexture("static_gray")}))

    self.control_panel_infoborders = Sprite("ui/battle/panels/controlpanel_infomode")
    self.control_panel_screen:addChild(self.control_panel_infoborders)
    self.control_panel_infoborders:setLayer(30)

    self:showMainPanel()

    self.party_panel = Sprite("ui/battle/panels/partypanel", 0, -67)
    self.party_panel_screen = Sprite("ui/battle/panels/partypanel_screen", 6, 48)
    self:addChild(self.party_panel)
    self.party_panel:addChild(self.party_panel_screen)
    self.party_panel:setLayer(-3)
    self.party_panel_screen:setLayer(1)

    self.action_panel_cover_target = SCREEN_WIDTH
    self.action_panel = Sprite("ui/battle/panels/actionpanel", SCREEN_WIDTH - 79, -67)
    self.action_panel_cover = Sprite("ui/battle/panels/actionpanel_cover", SCREEN_WIDTH - 79 + 5, -13)
    --self.action_panel_screen = Sprite("ui/battl/panels/actionpanel_screen", 6, 55)
    self:addChild(self.action_panel)
    --self.action_panel:addChild(self.action_panel_screen)
    self:addChild(self.action_panel_cover)
    self.action_panel:setLayer(-4)
    --self.action_panel_screen:setLayer(50)
    self.action_panel_cover:setLayer(BATTLE_LAYERS["above_ui"])

    self.current_encounter_text = {
        text = Game.battle.encounter.text
    }

    self.encounter_text = Textbox(10, 98, 454, 90, "eb", nil, true)
    self.encounter_text.text.line_offset = 0
    self.encounter_text:setText("")
    self.encounter_text.debug_rect = {-30, -12, SCREEN_WIDTH+1, 124}
    self.control_panel_screen:addChild(self.encounter_text)

    self.choice_box = Choicebox(10, 98, 454, 90, true)
    self.choice_box.active = false
    self.choice_box.visible = false
    self.control_panel_screen:addChild(self.choice_box)

    self.short_act_text_1 = DialogueText("", 10, 15, 454, SCREEN_HEIGHT - 53, {wrap = false, line_offset = 0})
    self.short_act_text_2 = DialogueText("", 10,  15 + 30, 454, SCREEN_HEIGHT - 53, {wrap = false, line_offset = 0})
    self.short_act_text_3 = DialogueText("", 10, 15 + 30 + 30, 454, SCREEN_HEIGHT - 53, {wrap = false, line_offset = 0})
    self.control_panel_screen:addChild(self.short_act_text_1)
    self.control_panel_screen:addChild(self.short_act_text_2)
    self.control_panel_screen:addChild(self.short_act_text_3)

    self.action_boxes = {}
    self.attack_boxes = {}

    self.attacking = false

    local size_offset = 0
    local box_gap = 0

    if #Game.battle.party == 3 then
        size_offset = 0
        box_gap = 3
    elseif #Game.battle.party == 2 then
        size_offset = 24
        box_gap = 10
    elseif #Game.battle.party == 1 then
        size_offset = 213 / 4
        box_gap = 0
    end

    for index,battler in ipairs(Game.battle.party) do
        local action_box = ActionBox(0, 0, index, battler, size_offset+ (index - 1) * (48 + box_gap))
        self.party_panel_screen:addChild(action_box)
        table.insert(self.action_boxes, action_box)
        battler.chara:onActionBox(action_box, false)
    end

    self.parallax_x = 0
    self.parallax_y = 0

    self.animation_done = true
    self.animation_timer = 0
    self.animate_out = false

    self.animation_y = 0
    self.animation_y_lag = 0

    self.shown = false

    self.heart_sprite = Assets.getTexture("player/heart")
    self.arrow_sprite = Assets.getTexture("ui/page_arrow_down")

    self.sparestar = Assets.getTexture("ui/battle/sparestar")
    self.tiredmark = Assets.getTexture("ui/battle/tiredmark")

    self.selector_sprite = Sprite("ui/battle/selector", 3, self.action_boxes[1].partypanel_offset + 5)
    self.selector_sprite:setLayer(BATTLE_LAYERS["above_ui"])
    self.selector_sprite.visible = false
    self.selector_sprite:play(1/2, true)
    self.party_panel_screen:addChild(self.selector_sprite)

    self.small_text = Assets.getFont("small")
    self:resetXACTPosition()
end

function BattleUI:resetXACTPosition()
    self.xact_x_pos = 142
end

function BattleUI:clearEncounterText()
    self.encounter_text:setActor(nil)
    self.encounter_text:setFace(nil)
    self.encounter_text:setFont()
    self.encounter_text:setAlign("left")
    self.encounter_text:setSkippable(true)
    self.encounter_text:setAdvance(false)
    self.encounter_text:setAuto(false)
    self.encounter_text:setText("")
    Game.battle:setDescription("", "", false, "")
end

function BattleUI:drawCurrentHealth(battler, color, x, y)
    local map = function (tbl, func)
        local result = {}
        for index, value in ipairs(tbl) do
            result[index] = func(value, index)
        end
        return result
    end

    local getConfig = function (name)
        return Kristal.getLibConfig("rolling-health", name)
    end
    local string_from = tostring(battler.health_rolling_last)
    local string_to = tostring(battler.chara:getHealth())
    local max_string_length = math.max(#string_from, #string_to)
    for i = 1, max_string_length - #string_from do
        string_from = ' ' .. string_from
    end
    for i = 1, max_string_length - #string_to do
        string_to = ' ' .. string_to
    end
    local health_offset = (max_string_length - 1) * 8
    x = x - health_offset
    local roll_progress = MathUtils.clamp((battler.health_rolling_timer / battler:getRollSpeed()) * getConfig("display_roll_speed"), 0, 1)
    local rolling_down = battler.chara:getHealth() < battler.health_rolling_last
    if rolling_down then roll_progress = 1 - roll_progress end
    for i = 1, max_string_length do
        local number_from, number_to = string.sub(string_from, i, i+1) or '', string.sub(string_to, i, i+1) or ''
        if number_from == number_to then
            Draw.setColor(color)
            love.graphics.print(number_from, x + (i - 1) * 8, y)
            --Kristal.Console:log(string_from)
        else
            -- Looks horrible (but it works)
            local function drawNumber(number, first, dark)
                Draw.setColor(map(color, function(value, index)
                    if index == 4 then return getConfig("change_alpha") and (first and roll_progress or (1 - roll_progress)) or value
                    else return (dark and getConfig("darken_previous")) and value * 0.25 or value
                    end
                end))
                love.graphics.print(number, x + (i - 1) * 8, y + (roll_progress - (first and 1 or 0)) * 12)
            end
            if rolling_down then
                drawNumber(number_to, false, false)
                drawNumber(number_from, true, true)
            else
                drawNumber(number_from, false, true)
                drawNumber(number_to, true, false)
            end
        end
    end
end

function BattleUI:beginAttack()
    local attack_order = Utils.pickMultiple(Game.battle.normal_attackers, #Game.battle.normal_attackers)

    for _, box in ipairs(self.attack_boxes) do
        box:remove()
    end
    self.attack_boxes = {}

    local last_offset = -1
    local offset = 0
    for i = 1, #attack_order do
        offset = offset + last_offset

        local battler = attack_order[i]
        local index = Game.battle:getPartyIndex(battler.chara.id)
        local attack_box = AttackBox(battler, 30 + offset, index, 168+ (153 * (index - 1)), 66)
        attack_box.layer = BATTLE_LAYERS["above_ui"] + (index * 0.01)
        self:addChild(attack_box)
        table.insert(self.attack_boxes, attack_box)

        if i < #attack_order and last_offset ~= 0 then
            last_offset = TableUtils.pick({ 0, 10, 15 })
        else
            last_offset = TableUtils.pick({ 10, 15 })
        end
    end

    self.attacking = true
end

function BattleUI:endAttack()
    Game.battle.cancel_attack = false
    for _, box in ipairs(self.attack_boxes) do
        box:endAttack()
    end
end

function BattleUI:transitionIn()
    if not self.shown then
        self.animate_out = false
        self.animation_timer = 0
        self.animation_done = false
        self.shown = true
    end
end

function BattleUI:transitionOut()
    -- TODO: Accurate transition-out animation
    if self.shown then
        self.animate_out = true
        self.animation_timer = 0
        self.animation_done = false
        self.animation_y_lag = self.y
        self.shown = false
    end
end

function BattleUI:showMainPanel()
    self.control_panel_done = false
    self.main_panel_target = -33
    self.control_panel:slideTo(self.control_panel.x, self.main_panel_target, 0.75, "in-out-cubic", function() self.control_panel_done = true end)
end

function BattleUI:hideMainPanel()
    self.control_panel_done = false
    self.main_panel_target = 200
    self.control_panel:slideTo(self.control_panel.x, self.main_panel_target, 0.75, "in-out-cubic", function() self.control_panel_done = true end)
end

function BattleUI:update()
    self.selector_sprite.visible = StringUtils.contains(Game.battle.state, "SELECT") and (Game.battle.current_selecting ~= 0)
    self.party_panel_screen.visible = self.animation_done and self.shown
    --self.action_panel_screen.visible = self.animation_done and (self.action_panel_cover_target == 80)
    self.control_panel_screen.visible = self.animation_done and self.control_panel_done and (self.main_panel_target == -33) and self.shown
    self.control_panel_infoborders.visible = (Game.battle.state ~= "SHORTACTTEXT") and (Game.battle.state ~= "BATTLETEXT") and (Game.battle.state ~= "ATTACKING") and self.shown and self.action_boxes[Game.battle.current_selecting]
    self.action_panel_cover.x = MathUtils.approach(self.action_panel_cover.x, self.action_panel_cover_target, DTMULT * 24)
    self.encounter_text.y = ((Game.battle.state ~= "SHORTACTTEXT") and (Game.battle.state ~= "BATTLETEXT")) and 98 or 15
    self.encounter_text.face_y = ((Game.battle.state ~= "SHORTACTTEXT") and (Game.battle.state ~= "BATTLETEXT")) and -16 or 2
    self.encounter_text.face:setCutout(0, 0, 0, ((Game.battle.state ~= "SHORTACTTEXT") and (Game.battle.state ~= "BATTLETEXT")) and 4 or 0)
    
    if (self.action_boxes and self.action_boxes[1]) and Game.battle.current_selecting and Game.battle.current_selecting ~= 0 then
        self.selector_sprite.y = MathUtils.approach(self.selector_sprite.y, self.action_boxes[Game.battle.current_selecting].partypanel_offset + 5, DTMULT * 12)
    end

    if (Game.battle.state == "ACTIONSELECT") then
        self.action_panel_cover_target = SCREEN_WIDTH
    else
        self.action_panel_cover_target = SCREEN_WIDTH - 79 + 5
    end
    if not self.animation_done then
        self.animation_timer = self.animation_timer + DTMULT

        local max_time = self.animate_out and 6 or 12

        if self.animation_timer > max_time + 1 then
            self.animation_done = true
            self.animation_timer = max_time + 1
        end

        local lower, upper = self:getTransitionBounds()
        local target = lower - upper

        if not self.animate_out then
            if self.animation_y < target then
                if target - self.animation_y < 40 then
                    self.animation_y = self.animation_y + math.ceil((target - self.animation_y) / 2.5) * DTMULT
                else
                    self.animation_y = self.animation_y + 30 * DTMULT
                end
            else
                self.animation_y = target
            end
        else
            self.animation_y_lag = MathUtils.approach(self.animation_y_lag, self.y, 30 * DTMULT)

            if self.animation_y > 0 then
                if math.floor((target - self.animation_y) / 5) > 15 then
                    self.animation_y = self.animation_y - math.floor((target - self.animation_y) / 2.5) * DTMULT
                else
                    self.animation_y = self.animation_y - 30 * DTMULT
                end
            else
                self.animation_y = 0
            end
        end

        self.y = lower - self.animation_y

        for _, box in ipairs(self.action_boxes) do
            if not self.animate_out then
                box.data_offset = self.animation_y - target
            else
                box.data_offset = self.y - self.animation_y_lag
            end
        end
    end

    if self.attacking then
        local all_done = true

        for _, box in ipairs(self.attack_boxes) do
            if not box.removing or box.fade_rect.alpha < 1 then
                all_done = false
                break
            end
        end

        if all_done then
            for _, box in ipairs(self.attack_boxes) do
                box:remove()
            end
            self.attack_boxes = {}
            self.attacking = false
        end
    end

    super.update(self)
end

function BattleUI:getTransitionBounds()
    return 565, 325
end

function BattleUI:draw()
    --self:drawActionArena()
    --self:drawActionStrip()
    super.draw(self)
    self:drawState()
end

function BattleUI:drawActionStrip()
    -- Draw the top line of the action strip
    Draw.setColor(PALETTE["action_strip"])
    love.graphics.rectangle("fill", 0, Game:getConfig("oldUIPositions") and 1 or 0, 640, Game:getConfig("oldUIPositions") and 3 or 2)
    -- Draw the background of the action strip
    Draw.setColor(PALETTE["action_fill"])
    love.graphics.rectangle("fill", 0, Game:getConfig("oldUIPositions") and 4 or 2, 640, Game:getConfig("oldUIPositions") and 33 or 35)
end

function BattleUI:drawActionArena()
    -- Draw the top line of the action area
    Draw.setColor(PALETTE["action_strip"])
    love.graphics.rectangle("fill", 0, 37, 640, 3)
    -- Draw the background of the action area
    Draw.setColor(PALETTE["action_fill"])
    love.graphics.rectangle("fill", 0, 40, 640, 115)
    self:drawState()
end

function BattleUI:drawState()
    local map = function (tbl, func)
        local result = {}
        for index, value in ipairs(tbl) do
            result[index] = func(value, index)
        end
        return result
    end
    if (Game.battle.state == "ACTIONSELECT") then
        Game.battle:setDescription("", "", false, "")
    end

    if (self.control_panel_infoborders.visible and self.animation_done and self.shown and self.control_panel_done and (self.main_panel_target == -33)) then
        

        Draw.setColor(1,1,1,1)
        if (self.action_boxes and self.action_boxes[Game.battle.current_selecting]) then
            ---@type ActionBox
            local box = self.action_boxes[Game.battle.current_selecting]
            local character = box.battler.chara
            local battler = box.battler

            local name_sprite = Assets.getTexture(character:getNameSprite())
            local head_sprite = Assets.getTexture(character:getMenuIcon())

            Draw.draw(head_sprite, SCREEN_WIDTH/2, -24, nil, nil, nil, head_sprite:getWidth()/2, 0)
            Draw.draw(name_sprite, SCREEN_WIDTH/2 + 16, 0, nil, nil, nil, name_sprite:getWidth(), 0)

            Draw.setColor(PALETTE["action_health_bg"])
            love.graphics.rectangle("fill", 273, 37, 97, 9)

            local health = (character:getHealth() / character:getStat("health")) * 97

            if health > 0 then
                Draw.setColor(character:getColor())
                love.graphics.rectangle("fill", 273, 37, math.ceil(health), 9)
            end

            local health_rolling_diff = ((battler.health_rolling_to - battler.chara:getHealth()) / battler.chara:getStat("health")) * 97
            if health_rolling_diff ~= 0 and health > 0 then
                Draw.setColor(map({battler.chara:getColor()}, function(value, index)
                    if index == 4 then return value
                    else
                        return value * 0.75
                    end
                end))
                local x_start = health
                local width = health_rolling_diff
                if health_rolling_diff < 0 then
                    x_start = math.ceil(health + width)
                    width = math.ceil(width) - 1
                end
                -- Kristal.Console:log(x_start + math.abs(math.floor(width)))
                love.graphics.rectangle("fill", x_start + 273, 37, math.abs(width), 9)
            end

            local color = PALETTE["action_health_text"]
            if health <= 0 then
                color = PALETTE["action_health_text_down"]
            elseif (character:getHealth() <= (character:getStat("health") / 4)) then
                color = PALETTE["action_health_text_low"]
            else
                color = PALETTE["action_health_text"]
            end


            local health_offset = 0
            health_offset = (#tostring(character:getHealth()) - 1) * 8

            Draw.setColor(color)
            love.graphics.setFont(Assets.getFont("smallnumbers"))
            --love.graphics.print(character:getHealth(), 290 - health_offset, 22)
            self:drawCurrentHealth(battler, color, 290, 22)
            love.graphics.setFont(Assets.getFont("smallnumbers"))
            Draw.setColor(PALETTE["action_health_text"])
            love.graphics.print("/", SCREEN_WIDTH/2-4, 22)
            local string_width = Assets.getFont("smallnumbers"):getWidth(tostring(character:getStat("health")))
            Draw.setColor(color)
            love.graphics.print(character:getStat("health"), 345, 22)

            Draw.setColor(203/255, 219/255, 252/255, 1)

            love.graphics.print(character:getLevel(), 364, 4)

            Draw.setColor(1,1,1,1)

            love.graphics.setFont(Assets.getFont("main"))
            if (character.is_psychic) then
                Draw.draw(Assets.getTexture("ui/battle/panels/controlpanel_npnh"), 98, 0)
                local power = (character.neural_power / 100)
                local heat = (character.heat / character:getStat("heat"))
                
                if (power > 0) then
                    Draw.setColor(128/255, 233/255, 1, 1)
                    love.graphics.rectangle("fill", 116, 0, math.ceil(power * 97), 9)
                end

                if (heat > 0) then
                    Draw.setColor(COLORS.red)
                    love.graphics.rectangle("fill", 116, 15, math.ceil(heat * 97), 9)
                end

                love.graphics.setFont(Assets.getFont("smallnumbers"))

                Draw.setColor(1,1,1,1)

                love.graphics.print((power * 100).."%", 114 + 102, 0)

                if (heat >= 0.95) then
                    Draw.setColor(COLORS.red)
                elseif (heat >= 0.85) then
                    Draw.setColor(COLORS.orange)
                elseif (heat >= 0.75) then
                    Draw.setColor(COLORS.yellow)
                end

                love.graphics.print((math.ceil(heat * 100)).."%", 114 + 102, 14)

                Draw.setColor(1,1,1,1)
                love.graphics.setFont(Assets.getFont("main"))

            elseif (character.is_musical) then
                Draw.setColor(112/255, 94/255, 129/255, 1)
                if (character.notes >= 3) then
                    Draw.setColor(195/255, 134/255, 1, 1)
                end
                Draw.draw(Assets.getTexture("ui/menu/icon/note"), 118 + (37 * 2), 0, nil, 2, 2)
                if (character.notes >= 2) then
                    Draw.setColor(195/255, 134/255, 1, 1)
                end
                Draw.draw(Assets.getTexture("ui/menu/icon/note"), 118 + 37, 0, nil, 2, 2)
                if (character.notes >= 1) then
                    Draw.setColor(195/255, 134/255, 1, 1)
                end
                Draw.draw(Assets.getTexture("ui/menu/icon/note"), 118, 0, nil, 2, 2)
                Draw.setColor(1,1,1,1)
            else
                Draw.draw(Assets.getTexture("ui/battle/panels/controlpanel_nothing"), 114, 0)
            end

            Draw.setColor(1,1,1,1)
            --statuses
            if (Utils.tableLength(battler.statuses) == 0) then
                Draw.draw(Assets.getTexture("ui/battle/panels/controlpanel_nothing"), 427, 10)
            else
                love.graphics.setFont(self.small_text)
                local displayed = 0
                for _,status in pairs(battler.statuses) do
                    local data = status.data.effect
                    Draw.setColor(data:getColor(1))
                    Draw.draw(Assets.getTexture(data:getIcon()), 403, 12 * displayed + 4)
                    love.graphics.print(data:getDisplayName(), 417, 12 * displayed + 4)

                    Draw.draw(Assets.getTexture(data:getTypeIcon()), 462, 12 * displayed + 4)
                    if (data:getMaxStacking() ~= 1) then love.graphics.print("x"..status.stacks, 474, 12 * displayed + 4) end

                    local extra = ""
                    if (data.consume_on_trigger) then
                        extra = "'"
                    end
                    love.graphics.print("x"..status.time_left..extra, 517, 12 * displayed + 4)
                    displayed = displayed + 1
                end
            end
            --instants
            local font = Assets.getFont("main")
            love.graphics.setFont(self.small_text)

            local bandaids = Game:getFlag("bandaids", 0)
            local tonics = Game:getFlag("tonics", 0)
            local purifiers = Game:getFlag("purifiers", 0)
            local insta_color = battler.used_instant and COLORS.gray or COLORS.white

            if (bandaids == 0) then
                Draw.setColor(COLORS.maroon)
            else
                Draw.setColor(insta_color)
            end
            love.graphics.print(bandaids, 134, 36)

            if (tonics == 0) then
                Draw.setColor(COLORS.maroon)
            else
                Draw.setColor(insta_color)
            end
            love.graphics.print(tonics, 134 + 37, 36)

            if (purifiers == 0) then
                Draw.setColor(COLORS.maroon)
            else
                Draw.setColor(insta_color)
            end
            love.graphics.print(purifiers, 134 + (37 * 2), 36)


            Draw.setColor(1,1,1,1)

            love.graphics.setFont(font)
        end
    end

    if Game.battle.state == "MENUSELECT" then
        local page = math.ceil(Game.battle.current_menu_y / 3) - 1
        local max_page = math.ceil(#Game.battle.menu_items / 6) - 1

        local x = 0
        local y = 0
        Draw.setColor(Game.battle.encounter:getSoulColor())
        Draw.draw(self.heart_sprite, 105 + ((Game.battle.current_menu_x - 1) * 230), 44 + ((Game.battle.current_menu_y - (page*3)) * 30))

        local font = Assets.getFont("main")
        love.graphics.setFont(font)

        local page_offset = page * 6
        for i = page_offset + 1, math.min(page_offset + 6, #Game.battle.menu_items) do
            local item = Game.battle.menu_items[i]

            Draw.setColor(1, 1, 1, 1)
            local text_offset = 0
            -- Are we able to select this?
            local able = Game.battle:canSelectMenuItem(item)
            if item.party then
                if not able then
                    -- We're not able to select this, so make the heads gray.
                    Draw.setColor(COLORS.gray)
                end

                for index, party_id in ipairs(item.party) do
                    local chara = Game:getPartyMember(party_id)

                    -- Draw head only if it isn't the currently selected character
                    if Game.battle:getPartyIndex(party_id) ~= Game.battle.current_selecting then
                        local ox, oy = chara:getHeadIconOffset()
                        Draw.draw(Assets.getTexture(chara:getHeadIcons() .. "/head"), text_offset + 105 + 30 + (x * 230) + ox, 50 + 14 + (y * 30) + oy)
                        text_offset = text_offset + 30
                    end
                end
            end

            if item.icons then
                if not able then
                    -- We're not able to select this, so make the heads gray.
                    Draw.setColor(COLORS.gray)
                end

                for _, icon in ipairs(item.icons) do
                    if type(icon) == "string" then
                        icon = { icon, false, 0, 0, nil }
                    end
                    if not icon[2] then
                        local texture = Assets.getTexture(icon[1])
                        Draw.draw(texture, text_offset + 30 + 105 + (x * 230) + (icon[3] or 0), 50 + (y * 30) + 14 + (icon[4] or 0))
                        text_offset = text_offset + (icon[5] or texture:getWidth())
                    end
                end
            end

            if able then
                -- Using color like a function feels wrong... should this be called getColor?
                Draw.setColor(item:color() or { 1, 1, 1, 1 })
            else
                Draw.setColor(COLORS.gray)
            end
            love.graphics.print(item.name, text_offset + 30 + 105 + (x * 230), 50 + 14 + (y * 30))
            text_offset = text_offset + font:getWidth(item.name)

            if item.icons then
                if able then
                    Draw.setColor(1, 1, 1)
                end

                for _, icon in ipairs(item.icons) do
                    if type(icon) == "string" then
                        icon = { icon, false, 0, 0, nil }
                    end
                    if icon[2] then
                        local texture = Assets.getTexture(icon[1])
                        Draw.draw(texture, text_offset + 30 + (x * 230) + (icon[3] or 0), 50 + (y * 30) + (icon[4] or 0))
                        text_offset = text_offset + (icon[5] or texture:getWidth())
                    end
                end
            end

            if x == 0 then
                x = 1
            else
                x = 0
                y = y + 1
            end
        end

        -- Print information about currently selected item
        local current_item = Game.battle.menu_items[Game.battle:getItemIndex()]
        if current_item.description and current_item.description ~= "" then
            -- Draw.setColor(COLORS.gray)
            -- love.graphics.print(current_item.description, 260 + 240, 50)
            -- Draw.setColor(1, 1, 1, 1)
            -- _, tp_offset = current_item.description:gsub('\n', '\n')
            -- tp_offset = tp_offset + 1
            Game.battle:setDescription(current_item.description, nil, true)
        else
            Game.battle:setDescription("", nil, nil)
        end

        if current_item.tp and current_item.tp ~= 0 then
            Game.battle:setDescription(nil,"[color:lime]" .. math.floor((current_item.tp / Game:getMaxTension()) * 100) .. "% "..Game:getConfig("tpName"), true)
            Game:setTensionPreview(current_item.tp)
        else
            Game.battle:setDescription(nil, nil, nil)
            Game:setTensionPreview(0)
        end

        if current_item.data and current_item.data.pcost and current_item.data:getNPCost() ~= 0 then
            local npCost = current_item.data.pcost
            local max_heat = 50
            local neural_power = 0
            local heat = current_item.data.pheat
            local current_heat = 0
            if (Game.battle.current_selecting and Game.battle.party[Game.battle.current_selecting]) then
                local chara = Game.battle.party[Game.battle.current_selecting]
                max_heat = chara.chara:getStat("heat", 50)
                npCost = current_item.data:getNPCost(chara.chara)
                heat = current_item.data:getNHeat(chara.chara)
                neural_power = chara.chara.neural_power
                current_heat = chara.chara.heat
            end
            -- if (self.neurometer) then
            --     self.neurometer.potential_power = MathUtils.clamp(neural_power - npCost, 0, 100) / 100
            --     self.neurometer.potential_heat = MathUtils.clamp(current_heat + heat, 0, max_heat) / max_heat
            -- end
            local heatpercent = tostring((heat / max_heat) * 100)
            local warning = ""
            if (Game.battle.current_selecting and Game.battle.party[Game.battle.current_selecting]) then
                local chara = Game.battle.party[Game.battle.current_selecting].chara
                
                if current_heat + heat >= max_heat then
                    warning = "///"
                end
            end
            Game.battle:setDescription(nil, "[font:smallnumbers][color:aqua]" .. npCost.."%P[color:gray]-[color:red]" .. heatpercent.."%H"..warning, true)
        else
            Game.battle:setDescription(nil, nil, nil)
        end

        if current_item.data and current_item.data.note_min and current_item.data.note_min ~= 0 then
            local has_notes = 3
            if (Game.battle.current_selecting and Game.battle.party[Game.battle.current_selecting]) then
                local chara = Game.battle.party[Game.battle.current_selecting].chara
                has_notes = chara.notes
            end
            local drawcolor = "gray"
            if ((has_notes == 0) or current_item.data.note_min > has_notes) then
                drawcolor = "maroon"
            elseif (has_notes == 3) then
                drawcolor = "white"
            end
            Game.battle:setDescription(nil, nil, true, "[color:"..drawcolor.."][image:ui/menu/icon/note]")
        else
            Game.battle:setDescription(nil, nil, nil, "")
        end

        if ((not current_item.tp) or (current_item.tp == 0)) and ((not current_item.data) or (not current_item.data.pcost) or (current_item.data.pcost == 0)) then
            Game.battle:setDescription(nil, "", nil, nil)
        end

        if (Game.battle.description.text == "" and Game.battle.cost_description.text == "" and Game.battle.note_display.text == "") then
            Game.battle:setDescription(nil, nil, false, nil)
        end

        Draw.setColor(1, 1, 1, 1)
        if page < max_page then
            Draw.draw(self.arrow_sprite, 470, 120 + (math.sin(Kristal.getTime() * 6) * 2))
        end
        if page > 0 then
            Draw.draw(self.arrow_sprite, 470, 70 - (math.sin(Kristal.getTime() * 6) * 2), 0, 1, -1)
        end

    elseif Game.battle.state == "ENEMYSELECT" then
        Game.battle:setDescription("", "", false, "")
        local enemies = Game.battle.enemies_index

        local page = math.ceil(Game.battle.current_menu_y / 3) - 1
        local max_page = math.ceil(#enemies / 3) - 1
        local page_offset = page * 3

        Draw.setColor(Game.battle.encounter:getSoulColor())
        Draw.draw(self.heart_sprite, 105, 44 + ((Game.battle.current_menu_y - page_offset) * 30))

        local font = Assets.getFont("main")
        love.graphics.setFont(font)

        local draw_mercy = Game:getConfig("mercyBar")
        local draw_percents = Game:getConfig("enemyBarPercentages")

        Draw.setColor(1, 1, 1, 1)

        if draw_mercy then
            if Game.battle.state_reason ~= "XACT" then
                love.graphics.print("HP", 324, 39 + 20, 0, 1, 0.5)
            end
            love.graphics.print("MERCY", 424, 39 + 20, 0, 1, 0.5)
        end

        for _, enemy in ipairs(Game.battle:getActiveEnemies()) do
            if self.xact_x_pos < font:getWidth(enemy.name) + 142 + 50 then
                self.xact_x_pos = font:getWidth(enemy.name) + 142 + 50
            end
        end

        for index = page_offset + 1, math.min(page_offset + 3, #enemies) do
            local enemy = enemies[index]
            local y_off = (index - page_offset - 1) * 30

            if enemy then
                ---@cast enemy EnemyBattler
                local name_colors = enemy:getNameColors()
                if type(name_colors) ~= "table" then
                    name_colors = { name_colors }
                end

                if #name_colors <= 1 then
                    Draw.setColor(name_colors[1] or enemy.selectable and {1, 1, 1} or {0.5, 0.5, 0.5})
                    love.graphics.print(enemy.name, 80 + 50, 50 + 14 + y_off)
                else
                    -- Draw the enemy name to a canvas first
                    local canvas = Draw.pushCanvas(font:getWidth(enemy.name), font:getHeight())
                    Draw.setColor(1, 1, 1)
                    love.graphics.print(enemy.name)
                    Draw.popCanvas()

                    -- Define our gradient
                    local color_canvas = Draw.pushCanvas(#name_colors, 1)
                    for i = 1, #name_colors do
                        -- Draw a pixel for the color
                        Draw.setColor(name_colors[i])
                        love.graphics.rectangle("fill", i - 1, 0, 1, 1)
                    end
                    Draw.popCanvas()

                    -- Reset the color
                    Draw.setColor(1, 1, 1)

                    -- Use the dynamic gradient shader for the spare/tired colors
                    local shader = Kristal.Shaders["DynGradient"]
                    love.graphics.setShader(shader)
                    -- Send the gradient colors
                    shader:send("colors", color_canvas)
                    shader:send("colorSize", { #name_colors, 1 })
                    -- Draw the canvas from before to apply the gradient over it
                    Draw.draw(canvas, 80 + 50, 50 + 14 + y_off)
                    -- Disable the shader
                    love.graphics.setShader()
                end

                Draw.setColor(1, 1, 1)

                local spare_icon = false
                local tired_icon = false
                if enemy.tired and enemy:canSpare() then
                    Draw.draw(self.sparestar, 80 + 50 + font:getWidth(enemy.name) + 20, 60 + 14 + y_off)
                    Draw.draw(self.tiredmark, 80 + 50 + font:getWidth(enemy.name) + 40, 60 + 14 + y_off)
                    spare_icon = true
                    tired_icon = true
                elseif enemy.tired then
                    Draw.draw(self.tiredmark, 80 + 50 + font:getWidth(enemy.name) + 40, 60 + 14 + y_off)
                    tired_icon = true
                elseif enemy.mercy >= 100 then
                    Draw.draw(self.sparestar, 80 + 50 + font:getWidth(enemy.name) + 20, 60 + 14 + y_off)
                    spare_icon = true
                end

                for i = 1, #enemy.icons do
                    if enemy.icons[i] then
                        if (spare_icon and (i == 1)) or (tired_icon and (i == 2)) then
                            -- Skip the custom icons if we're already drawing spare/tired ones
                        else
                            Draw.setColor(1, 1, 1, 1)
                            Draw.draw(enemy.icons[i], 80 + font:getWidth(enemy.name) + (i * 20), 60 + 14 + y_off)
                        end
                    end
                end

                if Game.battle.state_reason == "XACT" then
                    Draw.setColor(Game.battle.party[Game.battle.current_selecting].chara:getXActColor())
                    if Game.battle.selected_xaction.id == 0 then
                        love.graphics.print(enemy:getXAction(Game.battle.party[Game.battle.current_selecting]), self.xact_x_pos, 50 + 14 + y_off)
                    else
                        love.graphics.print(Game.battle.selected_xaction.name, self.xact_x_pos, 50 + 14 + y_off)
                    end
                else
                    local namewidth = font:getWidth(enemy.name)

                    Draw.setColor(128 / 255, 128 / 255, 128 / 255, 1)


                    if ((80 + namewidth + 60 + (font:getWidth(enemy.comment) / 2)) < 415) then
                        love.graphics.print(enemy.comment, 50 + 80 + namewidth + 60, 50 + 20 + y_off)
                    else
                        love.graphics.print(enemy.comment, 50 + 80 + namewidth + 60, 50 + 20 + y_off, 0, 0.5, 1)
                    end


                    local hp_percent = enemy.health / enemy.max_health

                    local hp_x = draw_mercy and 320 or 410

                    if enemy.selectable then
                        -- Draw the enemy's HP
                        Draw.setColor(PALETTE["action_health_bg"])
                        love.graphics.rectangle("fill", hp_x, 55 + 20 + y_off, 81, 16)

                        Draw.setColor(PALETTE["action_health"])
                        love.graphics.rectangle("fill", hp_x, 55 + 20 + y_off, math.ceil(hp_percent * 81), 16)

                        if draw_percents then
                            Draw.setColor(PALETTE["action_health_text"])
                            love.graphics.print(enemy:getHealthDisplay(), hp_x + 4, 55 + 20 + y_off, 0, 1, 0.5)
                        end
                    end
                end

                if draw_mercy then
                    -- Draw the enemy's MERCY
                    if enemy.selectable then
                        Draw.setColor(PALETTE["battle_mercy_bg"])
                    else
                        Draw.setColor(127 / 255, 127 / 255, 127 / 255, 1)
                    end
                    love.graphics.rectangle("fill", 420, 55 + 20 + y_off, 81, 16)

                    if enemy.disable_mercy then
                        Draw.setColor(PALETTE["battle_mercy_text"])
                        love.graphics.setLineWidth(2)
                        love.graphics.line(420, 56 + 20 + y_off, 420 + 81, 56 + 20 + y_off + 16 - 2)
                        love.graphics.line(420, 56 + 20 + y_off + 16 - 2, 420 + 81, 20 + 56 + y_off)
                    else
                        Draw.setColor(1, 1, 0, 1)
                        love.graphics.rectangle("fill", 420, 55 + 20 + y_off, ((enemy.mercy / 100) * 81), 16)

                        if draw_percents and enemy.selectable then
                            Draw.setColor(enemy:getMercyColor())
                            love.graphics.print(enemy:getMercyDisplay(), 424, 55 + 20 + y_off, 0, 1, 0.5)
                        end
                    end
                end
            end
        end

        Draw.setColor(1, 1, 1, 1)

        local arrow_down = false
        local i = page_offset + 3
        while true do
            i = i + 1
            if i > #enemies then
                break
            elseif enemies[i] then
                arrow_down = true
                break
            end
        end

        local arrow_up = false
        i = page_offset + 1
        while true do
            i = i - 1
            if i < 1 then
                break
            elseif enemies[i] then
                arrow_up = true
                break
            end
        end

        if arrow_down then
            Draw.draw(self.arrow_sprite, 20, 120 + (math.sin(Kristal.getTime() * 6) * 2))
        end
        if arrow_up then
            Draw.draw(self.arrow_sprite, 20, 70 - (math.sin(Kristal.getTime() * 6) * 2), 0, 1, -1)
        end
    elseif Game.battle.state == "PARTYSELECT" then
        Game.battle:setDescription("", "", false, "")
        local page = math.ceil(Game.battle.current_menu_y / 3) - 1
        local max_page = math.ceil(#Game.battle.party / 3) - 1
        local page_offset = page * 3

        Draw.setColor(Game.battle.encounter:getSoulColor())
        Draw.draw(self.heart_sprite, 105, 37 + ((Game.battle.current_menu_y - page_offset) * 30))

        local font = Assets.getFont("main")
        love.graphics.setFont(font)

        for index = page_offset + 1, math.min(page_offset + 3, #Game.battle.party) do
            Draw.setColor(1, 1, 1, 1)
            love.graphics.print(Game.battle.party[index].chara:getName(), 135, 57 + ((index - page_offset - 1) * 30))

            Draw.setColor(PALETTE["action_health_bg"])
            love.graphics.rectangle("fill", 380, 67 + ((index - page_offset - 1) * 30), 101, 16)

            local percentage = Game.battle.party[index].chara:getHealth() / Game.battle.party[index].chara:getStat("health")
            -- Chapter 3 introduces this lower limit, but all chapters in Kristal might as well have it
            -- Swooning is the only time you can ever see it this low
            percentage = math.max(-1, percentage)
            Draw.setColor(PALETTE["action_health"])
            love.graphics.rectangle("fill", 380, 67 + ((index - page_offset - 1) * 30), math.ceil(percentage * 101), 16)
        end

        Draw.setColor(1, 1, 1, 1)
        if page < max_page then
            Draw.draw(self.arrow_sprite, 20, 120 + (math.sin(Kristal.getTime() * 6) * 2))
        end
        if page > 0 then
            Draw.draw(self.arrow_sprite, 20, 70 - (math.sin(Kristal.getTime() * 6) * 2), 0, 1, -1)
        end
    end
    if Game.battle.state == "ATTACKING" or self.attacking then
        Game.battle:setDescription("", "", false, "")
        -- Draw.setColor(PALETTE["battle_attack_lines"])
        -- if not Game:getConfig("oldUIPositions") then
        --     -- Chapter 2 attack lines
        --     love.graphics.rectangle("fill", 79, 78, 224, 2)
        --     love.graphics.rectangle("fill", 79, 116, 224, 2)
        -- else
        --     -- Chapter 1 attack lines
        --     local has_index = {}
        --     for _,box in ipairs(self.attack_boxes) do
        --         has_index[box.index] = true
        --     end
        --     love.graphics.rectangle("fill", has_index[2] and 77 or 2, 78, has_index[2] and 226 or 301, 3)
        --     love.graphics.rectangle("fill", has_index[3] and 77 or 2, 116, has_index[3] and 226 or 301, 3)
        -- end
    end
end

return BattleUI
