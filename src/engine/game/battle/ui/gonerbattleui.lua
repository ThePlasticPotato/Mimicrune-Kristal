---@class GonerBattleUI : BattleUI
---@overload fun() : GonerBattleUI
local GonerBattleUI, super = Class(BattleUI)

local ACTION_NAMES = {
    fight = "EXECUTE",
    act = "QUERY",
    magic = "PROGRAM",
    item = "STORAGE",
    spare = "RELEASE",
    defend = "WAIT",
}

function GonerBattleUI:init()
    super.init(self)
    self:setPosition(0, 0)
    self.layer = BATTLE_LAYERS["ui"]

    self.control_panel.visible = false
    self.party_panel.visible = false
    self.action_panel.visible = false
    self.action_panel_cover.visible = false
    self.selector_sprite.visible = false

    self.encounter_text:remove()
    self.choice_box:remove()
    self.short_act_text_1:remove()
    self.short_act_text_2:remove()
    self.short_act_text_3:remove()

    self.eb_font = Assets.getFont("eb")
    self.eb_line_spacing = Assets.getFontData("eb").lineSpacing or self.eb_font:getHeight()
    self.action_row_height = self.eb_line_spacing + 3
    self.submenu_row_height = self.eb_line_spacing + 10

    self.status_panel = GonerBattlePanel(112, 59, 170, 64)

    self.action_device_panel = GonerBattlePanel(115, 406, 170, 112)
    self.work_panel = GonerBattlePanel(420, 412, 360, 100)
    self:addChild(self.status_panel)
    self:addChild(self.action_device_panel)
    self:addChild(self.work_panel)

    self.status_name_text = Text("", 8, -21, 154, 18, {font = "eb", color = COLORS.black, line_offset = 0})
    self.status_text = Text("", 10, 4, 112, 18, {font = "eb", color = COLORS.black, line_offset = 0})
    self.action_text = Text("", 40, 10, 116, 96, {
        font = "eb",
        color = COLORS.black,
        line_offset = self.action_row_height - self.eb_line_spacing,
    })
    self.status_panel:addChild(self.status_name_text)
    self.status_panel:addChild(self.status_text)
    self.action_device_panel:addChild(self.action_text)

    self.health_meter = GonerBattleMeter(10, 12, 106, "HP")
    self.tp_meter = GonerBattleMeter(126, 4, 36, Game:getConfig("tpName"), "vertical", 56)
    self.status_panel:addChild(self.health_meter)
    self.status_panel:addChild(self.tp_meter)

    self.action_cursor = Sprite("player/heart", 20, 10)
    self.action_cursor:setScale(0.5)
    self.action_cursor:setColor(COLORS.black)
    self.action_device_panel:addChild(self.action_cursor)

    self.submenu_content = Object(0, 0)
    self.work_panel:addChild(self.submenu_content)
    self.submenu_left_text = Text("", 40, 12, 140, 76, {
        font = "eb",
        color = COLORS.black,
        line_offset = self.submenu_row_height - self.eb_line_spacing,
    })
    self.submenu_right_text = Text("", 200, 12, 140, 76, {
        font = "eb",
        color = COLORS.black,
        line_offset = self.submenu_row_height - self.eb_line_spacing,
    })
    self.submenu_content:addChild(self.submenu_left_text)
    self.submenu_content:addChild(self.submenu_right_text)

    self.submenu_cursor = Sprite("player/heart", 20, 12)
    self.submenu_cursor:setScale(0.5)
    self.submenu_cursor:setColor(COLORS.black)
    self.submenu_content:addChild(self.submenu_cursor)

    self.message_content = Object(0, 0)
    self.work_panel:addChild(self.message_content)

    self.encounter_text = Textbox(14, 8, 332, 84, "eb", nil, true)
    self.encounter_text.text:setTextColor(0, 0, 0, 1)
    self.encounter_text.text.line_offset = 0
    self.message_content:addChild(self.encounter_text)

    self.choice_box = GonerBattleChoicebox(6, 8, 346, 84)
    self.choice_box.active = false
    self.choice_box.visible = false
    self.message_content:addChild(self.choice_box)

    self.short_act_text_1 = DialogueText("", 14, 8, 332, 24, {font = "eb", color = COLORS.black, line_offset = 0})
    self.short_act_text_2 = DialogueText("", 14, 36, 332, 24, {font = "eb", color = COLORS.black, line_offset = 0})
    self.short_act_text_3 = DialogueText("", 14, 64, 332, 24, {font = "eb", color = COLORS.black, line_offset = 0})
    self.message_content:addChild(self.short_act_text_1)
    self.message_content:addChild(self.short_act_text_2)
    self.message_content:addChild(self.short_act_text_3)

    self.current_encounter_text = {text = Game.battle.encounter.text}
    self.shown = false
    self.main_panel_shown = false
    self.animation_done = true
    self.glitch_timer = MathUtils.random(75, 150)
    self.panel_fault = {
        panel = nil,
        state = "waiting",
        timer = MathUtils.random(240, 480),
    }

    self:crt({SCREEN_WIDTH, SCREEN_HEIGHT}, false, {
        vertJerkOpt = 0,
        vertMovementOpt = 0,
        bottomStaticOpt = 0.03,
        scanlinesOpt = 0.16,
        rgbOffsetOpt = 0.08,
        horzFuzzOpt = 0.06,
    })
end

function GonerBattleUI:resetXACTPosition()
    self.xact_x_pos = 0
end

function GonerBattleUI:transitionIn()
    self.shown = true
    self.animation_done = true
end

function GonerBattleUI:transitionOut()
    self.shown = false
    self.main_panel_shown = false
    self.animation_done = false
end

function GonerBattleUI:showMainPanel()
    self.main_panel_shown = true
end

function GonerBattleUI:hideMainPanel()
    self.main_panel_shown = false
end

function GonerBattleUI:isPanelFrozen(panel)
    return self.panel_fault.panel == panel and self.panel_fault.state ~= "waiting"
end

function GonerBattleUI:isPanelOnline(panel)
    return not (self.panel_fault.panel == panel and self.panel_fault.state == "crashed")
end

function GonerBattleUI:finishPanelFault()
    local fault = self.panel_fault
    if fault.panel then
        fault.panel:setHung(false)
        fault.panel:stopGlitch()
    end
    fault.panel = nil
    fault.state = "waiting"
    fault.timer = MathUtils.random(240, 520)
end

function GonerBattleUI:updatePanelFault(active)
    local fault = self.panel_fault
    if not active then return end

    fault.timer = fault.timer - DTMULT
    if fault.timer > 0 then return end

    if fault.state == "waiting" then
        local candidates = {self.status_panel}
        if Game.battle.state == "ACTIONSELECT" and self.action_device_panel.visible then
            table.insert(candidates, self.action_device_panel)
        end
        fault.panel = TableUtils.pick(candidates)
        fault.state = "hung"
        fault.timer = MathUtils.random(24, 54)
        fault.panel:setHung(true)
        fault.panel:glitch({
            scan_line_jitter = 0.004,
            horizontal_shake = 0.002,
            color_drift = 0.004,
        }, 0.1)
    elseif fault.state == "hung" then
        if fault.panel == self.action_device_panel then
            self:finishPanelFault()
        else
            fault.panel:setHung(false)
            fault.state = "crashed"
            fault.timer = MathUtils.random(50, 110)
            fault.panel:setOpen(false, true)
        end
    else
        self:finishPanelFault()
    end
end

function GonerBattleUI:updateStatus()
    local battler = Game.battle.party[1]
    if not battler then return end
    local chara = battler.chara
    local lines = {}
    if chara.is_psychic then
        table.insert(lines, string.format("NP:%d H:%d", chara.neural_power, math.ceil((chara.heat / chara:getStat("heat")) * 100)))
    elseif chara.is_musical then
        table.insert(lines, string.format("NOTES %d/3", chara.notes))
    end
    local health, max_health = chara:getHealth(), chara:getStat("health")
    if not self:isPanelFrozen(self.status_panel) then
        self.status_name_text:setText(chara:getName():upper())
        self.health_meter.y = #lines > 0 and 24 or 12
        self.status_text:setText(table.concat(lines, "\n"))
        self.health_meter:setMeter("HP", health, max_health, string.format("%s / %s", health, max_health))
        local tension, max_tension = Game:getTension(), Game:getMaxTension()
        local tension_percent = math.floor((tension / math.max(max_tension, 1)) * 100)
        self.tp_meter:setMeter(Game:getConfig("tpName"), tension, max_tension, tension_percent .. "%")
    end
end

function GonerBattleUI:beginAttack()
    local attack_order = Utils.pickMultiple(Game.battle.normal_attackers, #Game.battle.normal_attackers)

    for _, box in ipairs(self.attack_boxes) do
        box:remove()
    end
    self.attack_boxes = {}

    for _, battler in ipairs(attack_order) do
        local index = Game.battle:getPartyIndex(battler.chara.id)
        local attack_box = GonerAttackBox(battler, 0, index, 125, 382)
        attack_box.layer = BATTLE_LAYERS["above_ui"] + (index * 0.01)
        self:addChild(attack_box)
        table.insert(self.attack_boxes, attack_box)
    end

    self.attacking = true
end

function GonerBattleUI:updateActions()
    local action_box = self.action_boxes[1]
    if not action_box or self:isPanelFrozen(self.action_device_panel) then return end
    local labels = {}
    for _, button in ipairs(action_box:getSelectableButtons()) do
        table.insert(labels, ACTION_NAMES[button.type] or tostring(button.type):upper())
    end
    self.action_text:setText(table.concat(labels, "\n"))
    local cursor_center_offset = (self.eb_font:getHeight() - self.action_cursor.height * self.action_cursor.scale_y) / 2
    self.action_cursor.y = 10 + ((action_box.selected_button - 1) * self.action_row_height) + cursor_center_offset
end

function GonerBattleUI:updateSubmenu()
    local battle = Game.battle
    local left, right = {}, {}
    local cursor_x, cursor_y = 20, 12

    if battle.state == "MENUSELECT" then
        local page = math.ceil(battle.current_menu_y / 3) - 1
        local first = (page * 6) + 1
        for index = first, math.min(first + 5, #battle.menu_items) do
            local item = battle.menu_items[index]
            local label = item.name
            if item.tp and item.tp > 0 then
                label = label .. " " .. math.floor((item.tp / Game:getMaxTension()) * 100) .. "%"
            end
            local column = ((index - first) % 2) + 1
            table.insert(column == 1 and left or right, label)
        end
        cursor_x = battle.current_menu_x == 1 and 20 or 180
        cursor_y = 12 + (((battle.current_menu_y - 1) % 3) * self.submenu_row_height)
    elseif battle.state == "PARTYSELECT" then
        for _, battler in ipairs(battle.party) do
            table.insert(left, battler.chara:getName())
        end
        cursor_y = 12 + ((battle.current_menu_y - 1) * self.submenu_row_height)
    end

    self.submenu_left_text:setText(table.concat(left, "\n"))
    self.submenu_right_text:setText(table.concat(right, "\n"))
    local cursor_center_offset = (self.eb_font:getHeight() - self.submenu_cursor.height * self.submenu_cursor.scale_y) / 2
    self.submenu_cursor:setPosition(cursor_x, cursor_y + cursor_center_offset)
end

function GonerBattleUI:update()
    local state = Game.battle.state
    local selecting = state == "MENUSELECT" or state == "PARTYSELECT"
    local in_transition = state == "TRANSITION" or state == "INTRO"
    local message = self.main_panel_shown
        and (state == "BATTLETEXT" or state == "SHORTACTTEXT")

    self:updatePanelFault(self.shown and not in_transition)

    self.status_panel:setOpen(self.shown and not in_transition and self:isPanelOnline(self.status_panel))
    self.action_device_panel:setOpen(self.shown and self.main_panel_shown and state == "ACTIONSELECT")
    self.work_panel:setOpen(self.shown and (selecting or message))
    self.submenu_content.visible = selecting
    self.message_content.visible = message

    self:updateStatus()
    self:updateActions()
    self:updateSubmenu()

    self.glitch_timer = self.glitch_timer - DTMULT
    if self.glitch_timer <= 0 then
        self:glitch({scan_line_jitter = 0.004, horizontal_shake = 0.003, color_drift = 0.004}, 0.08)
        self.glitch_timer = MathUtils.random(75, 150)
    end

    Object.update(self)

    if self.attacking then
        local all_removed = true
        for _, box in ipairs(self.attack_boxes) do
            if not box.removing or box.fade_rect.alpha < 1 then
                all_removed = false
                break
            end
        end
        if all_removed then
            for _, box in ipairs(self.attack_boxes) do
                box:remove()
            end
            self.attack_boxes = {}
            self.attacking = false
        end
    end

    if not self.shown then
        self.animation_done = self.status_panel.progress == 0
            and self.action_device_panel.progress == 0
            and self.work_panel.progress == 0
    end
end

function GonerBattleUI:draw()
    Object.draw(self)

    if Game.battle.state == "ENEMYSELECT" then
        local enemy = Game.battle.enemies_index[Game.battle.current_menu_y]
        if enemy and enemy.visible then
            local x, y = enemy:getScreenPos()
            y = y - ((enemy.height or 40) * enemy.scale_y / 2)
            local radius = MathUtils.clamp(math.max(enemy.width or 40, enemy.height or 40) * 0.7, 25, 54)
            local rotation = Kristal.getTime() * 2.8
            local r, g, b = unpack(ColorUtils.hexToRGB("#c8c9be"))

            love.graphics.push()
            love.graphics.translate(x, y)
            love.graphics.rotate(rotation)
            Draw.setColor(0, 0, 0, 0.65)
            love.graphics.setLineWidth(5)
            love.graphics.circle("line", 0, 0, radius + 2)
            Draw.setColor(r, g, b, 1)
            love.graphics.setLineWidth(2)
            love.graphics.circle("line", 0, 0, radius)

            for corner = 0, 3 do
                love.graphics.push()
                love.graphics.rotate(corner * math.pi / 2)
                love.graphics.line(radius + 7, -10, radius + 7, 10)
                love.graphics.line(radius - 3, 0, radius + 17, 0)
                love.graphics.pop()
            end
            love.graphics.pop()

            Draw.setColor(r, g, b, 0.8)
            love.graphics.setLineWidth(1)
            love.graphics.line(x - radius - 16, y, x + radius + 16, y)
            love.graphics.line(x, y - radius - 16, x, y + radius + 16)
            Draw.setColor(1, 1, 1, 1)
            love.graphics.setLineWidth(1)
        end
    end
end

return GonerBattleUI
