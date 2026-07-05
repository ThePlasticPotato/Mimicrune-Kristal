---@class DarkMenu : Object
---@overload fun(...) : DarkMenu
local DarkMenu, super = Class(Object)

function DarkMenu:init()
    super.init(self, 0, 0)

    self.layer = WORLD_LAYERS["ui"]

    self.parallax_x = 0
    self.parallax_y = 0

    self.animation_done = false
    self.animation_timer = 0
    self.animate_out = false

    self.selected_submenu = 1

    self.item_header_selected = 1
    self.equip_selected = 1
    self.power_selected = 1

    self.item_selected_x = 1
    self.item_selected_y = 1

    self.selected_party = 1
    self.party_select_mode = "SINGLE" -- SINGLE, ALL
    self.after_party_select = nil

    self.selected_item = 1

    self.booting = not Game:getFlag("opened_darkmenu", false)
    self.boot_timer = 0
    self.boot_sound_played = false
    self.boot_disk_played = false
    self.boot_finboot_played = false
    self.boot_done = false
    self.state = self.booting and "BOOT" or "MAIN"
    self.state_reason = nil
    self.heart_sprite = Assets.getTexture("player/heart_menu_small")

    self.ui_select = Assets.newSound("ui_select_camera")
    self.ui_move = Assets.newSound("ui_move_panel")
    self.ui_cancel_small = Assets.newSound("ui_cancel_small_camera")
    self.ui_cant_select = Assets.newSound("ui_error_camera")

    self.hp_sprite = Assets.getTexture("ui/menu/panels/dark/main/max_health")
    self.attack_sprite = Assets.getTexture("ui/menu/panels/dark/main/attack")
    self.magic_sprite = Assets.getTexture("ui/menu/panels/dark/main/magic")
    self.defense_sprite = Assets.getTexture("ui/menu/panels/dark/main/defense")
    self.boot_logo_sprite = Assets.getTexture("misc/garamond_bios")

    self.positive_arrow = Assets.getTexture("ui/status/type/up")
    self.negative_arrow = Assets.getTexture("ui/status/type/down")

    self.font = Assets.getFont("main")
    self.small_font = Assets.getFont("smallnumbers")
    self.mono_font = Assets.getFont("main_mono", 16)
    self.ui_interrupt = Assets.newSound("ui_interrupt_hand")
    self.ui_interrupt:setVolume(0.25)

    ---@type PanelMenuBackground
    self.panel_bg = PanelMenuBackground("ui/menu/panels/dark/main/menu", 0, 0, "hand_open", "hand_open", "ui_move_panel", "ui_select_hand", "ui_error_hand", "ui_cancel_small", "ui_static", 0, 0)
    if self.booting then
        self.panel_bg.sprite = Assets.getTexture("ui/menu/panels/dark/main/menu_booting")
        self.panel_bg.open_sprite:setSprite("ui/menu/panels/dark/main/menu_boot")
    end
    self:addChild(self.panel_bg)
    if self.state == "BOOT" then
        self.panel_bg.panel_ambience:pause()
    end

    self.description_panel = PanelMenuBackground("ui/menu/panels/dark/hand/menu", 0, 0, "hand_open", "hand_open", "ui_move_panel", "ui_select_panel", "ui_error_panel", "ui_cancel_small_camera", nil, 0, 0, false)
    self.description_panel.layer = 10
    self:addChild(self.description_panel)
    self.description = Text("", 20, 10, 540, 80 - 16)
    self.description.visible = false
    self.description_panel:addChild(self.description)

    self.bag_sprite = Assets.getTexture("ui/menu/panels/dark/main/bag")
    self.stat_sprite = Assets.getTexture("ui/menu/panels/dark/main/stat")

    self.flicker_timer = 0
    self.flicker_dur = 0

    self.buttons = {}
    self:addButtons()
    self.buttons = Kristal.callEvent(KRISTAL_EVENT.getDarkMenuButtons, self.buttons, self) or self.buttons

    self.sprite = Assets.getTexture("ui/menu/radialselect")

    self.box = nil
    self.box_offset_x = 0
    self.box_offset_y = 0

    self.objective = ObjectivePopup(0, -240, nil, nil, Game:getFlag("current_objective"), nil, "none", false, false, true)
    self.objective.layer = self.layer - 0.1
    Game.stage:addChild(self.objective)

    self.health_override = nil
    self.attack_override = nil
    self.magic_override = nil
    self.defense_override = nil
end

function DarkMenu:getButtonSpacing()
    if #self.buttons <= 4 then
        return 100
    else
        return 100 - (#self.buttons * #self.buttons)
    end
end

function DarkMenu:addButton(button, index)
    index = index or #self.buttons + 1
    table.insert(self.buttons, index, button)
    return index
end

function DarkMenu:addButtons()
    -- CONFIG
    self:addButton({
        ["state"]          = "CONFIGMENU",
        ["sprite"]         = Assets.getTexture("ui/menu/radialbtn/settings"),
        ["hovered_sprite"] = Assets.getTexture("ui/menu/radialbtn/settings_h"),
        ["desc_sprite"]    = Assets.getTexture("ui/menu/desc/config"),
        ["callback"]       = function()
            self.box = DarkConfigMenu()
            self.box.layer = -1
            self:addChild(self.box)

            self.ui_select:stop()
            self.ui_select:play()
        end
    })
    -- TALK
    self:addButton({
        ["state"]          = "TALK",
        ["sprite"]         = Assets.getTexture("ui/menu/radialbtn/talk"),
        ["hovered_sprite"] = Assets.getTexture("ui/menu/radialbtn/talk_h"),
        ["desc_sprite"]    = Assets.getTexture("ui/menu/desc/talk"),
        ["callback"]       = function()
            Input.clear("confirm")
            Game.world:closeMenu()

            self.ui_select:stop()
            self.ui_select:play()

            Game.world:startCutscene("_talk")
        end
    })
    -- ITEM
    self:addButton({
        ["state"]          = "ITEMMENU",
        ["sprite"]         = Assets.getTexture("ui/menu/radialbtn/item"),
        ["hovered_sprite"] = Assets.getTexture("ui/menu/radialbtn/item_h"),
        ["desc_sprite"]    = Assets.getTexture("ui/menu/desc/item"),
        ["callback"]       = function()
            self.box = DarkItemMenu()
            self.box.layer = self.layer + 1
            self:addChild(self.box)

            self.ui_select:stop()
            self.ui_select:play()
        end
    })

    -- EQUIP
    self:addButton({
        ["state"]          = "EQUIPMENU",
        ["sprite"]         = Assets.getTexture("ui/menu/radialbtn/equip"),
        ["hovered_sprite"] = Assets.getTexture("ui/menu/radialbtn/equip_h"),
        ["desc_sprite"]    = Assets.getTexture("ui/menu/desc/equip"),
        ["callback"]       = function()
            self.box = DarkEquipMenu()
            self.box.layer = self.layer + 1
            self:addChild(self.box)

            self.ui_select:stop()
            self.ui_select:play()
        end
    })

    -- POWER
    self:addButton({
        ["state"]          = "POWERMENU",
        ["sprite"]         = Assets.getTexture("ui/menu/radialbtn/power"),
        ["hovered_sprite"] = Assets.getTexture("ui/menu/radialbtn/power_h"),
        ["desc_sprite"]    = Assets.getTexture("ui/menu/desc/power"),
        ["callback"]       = function()
            self.box = DarkPowerMenu()
            self.box.layer = self.layer + 1
            self:addChild(self.box)

            self.ui_select:stop()
            self.ui_select:play()
        end
    })

    -- SPELLS
    self:addButton({
        ["state"]          = "SPELLMENU",
        ["sprite"]         = Assets.getTexture("ui/menu/radialbtn/spells"),
        ["hovered_sprite"] = Assets.getTexture("ui/menu/radialbtn/spells_h"),
        ["desc_sprite"]    = Assets.getTexture("ui/menu/desc/spells"),
        ["callback"]       = function()
            self.box = DarkSpellMenu()
            self.box.layer = 1
            self:addChild(self.box)

            self.ui_select:stop()
            self.ui_select:play()
        end
    })
end

function DarkMenu:getButton(id)
    for _,button in ipairs(self.buttons) do
        if button.id == id then
            return button
        end
    end
end

function DarkMenu:onAdd(parent)
    super.onAdd(self, parent)
    Game.world:showHealthBars()
    Kristal.callEvent(KRISTAL_EVENT.onDarkMenuOpen, self)
end

function DarkMenu:transitionOut()
    if Game.world.menu == self then
        Game.world.menu = nil
    end
    if (self.objective) then self.objective:close() end
    if (self.description_panel and not self.description_panel.closed) then self.description_panel:close() end
    self.animate_out = true
    local could_open = Game.world.can_open_menu
    if self.box then self.box:remove() end
    Game.world.can_open_menu = false
    self.panel_bg:close(false, function ()
        Game.world.can_open_menu = could_open
        self:remove()
        end)
end

function DarkMenu:setOverrides(health, attack, magic, defense)
    self.health_override = health
    self.attack_override = attack
    self.magic_override = magic
    self.defense_override = defense
end

function DarkMenu:resetOverrides()
    self.health_override = nil
    self.attack_override = nil
    self.magic_override = nil
    self.defense_override = nil
end

function DarkMenu:closeBox(immediate)
    self.state = "MAIN"
    self:resetOverrides()
    if (self.box) then
        if (self.description_panel and not self.description_panel.closed) then self.description_panel:close(immediate) end
        if (self.box.panel_bg) then 
            self.box.panel_bg:close(immediate, function () self.box:remove() ; self.box = nil end)
        else
            self.box:remove()
            self.box = nil
        end
    end
end

function DarkMenu:setDescription(text, visible)
    local wasVisible = self.description_panel.operable
    local oldText = self.description.text
    self.description:setText(text)
    if (wasVisible and visible ~= false and oldText ~= text) then self.ui_interrupt:stop() ; self.ui_interrupt:play() end
    if visible ~= nil then
        if (visible ~= wasVisible) then
            if (visible) then
                self.description_panel:open(false, function () end)
            else
                self.description.visible = false
                self.description_panel:close(false, nil, false)
            end
        end
    end
end

function DarkMenu:partySelect(mode, after)
    self.state_reason = self.state
    self.state = "PARTYSELECT"

    self.party_select_mode = mode or "SINGLE"
    self.after_party_select = after

    self:updateSelectedBoxes()
end

function DarkMenu:onKeyPressed(key)
    if self.box then
        if self.box.onKeyPressed then
            if (self.box.panel_bg and not self.box.panel_bg.operable) then
            else
                self.box:onKeyPressed(key)
            end
        end
    end

    if not self.panel_bg.operable then return end
    if self.state == "BOOT" then return end

    if (Input.isMenu(key) or Input.isCancel(key)) and self.state == "MAIN" then
        Game.world:closeMenu()
        return
    end

    --if not self.animation_done then return end

    if self.state == "MAIN" then
        local old_selected = self.selected_submenu
        if Input.is("left", key)  then self.selected_submenu = self.selected_submenu - 1 end
        if Input.is("right", key) then self.selected_submenu = self.selected_submenu + 1 end
        if self.selected_submenu < 1             then self.selected_submenu = #self.buttons end
        if self.selected_submenu > #self.buttons then self.selected_submenu = 1             end
        if old_selected ~= self.selected_submenu then
            self.ui_move:stop()
            self.ui_move:play()
        end
        if Input.isConfirm(key) then
            self:onButtonSelect(self.selected_submenu)
        end
    elseif self.state == "PARTYSELECT" then
        if Input.isCancel(key) then
            Input.clear("cancel")
            self.ui_cancel_small:stop()
            self.ui_cancel_small:play()

            self.state = self.state_reason
            if self.after_party_select then
                self.after_party_select(false)
            end

            self:updateSelectedBoxes()
            return
        end
        local old_selected = self.selected_party
        if self.party_select_mode == "SINGLE" then
            if Input.is("up", key) then
                self.selected_party = self.selected_party - 1
                self.ui_move:stop()
                self.ui_move:play()
            end
            if Input.is("down", key) then
                self.selected_party = self.selected_party + 1
                self.ui_move:stop()
                self.ui_move:play()
            end
        end
        if self.selected_party < 1 then self.selected_party = #Game.party end
        if self.selected_party > #Game.party then self.selected_party = 1 end
        if old_selected ~= self.selected_party then
            self:updateSelectedBoxes()
        end
        if Input.isConfirm(key) then
            Input.clear("confirm")
            self.state = self.state_reason
            self.state_reason = nil
            if self.after_party_select then
                if self.party_select_mode == "SINGLE" then
                    self.after_party_select(true, Game.party[self.selected_party])
                else
                    self.after_party_select(true, Game.party)
                end
            end
            self:updateSelectedBoxes()
        end
    end
end

function DarkMenu:onButtonSelect(button_index)
    if self.buttons[button_index].callback then
        self.state = self.buttons[button_index].state
        Input.clear("confirm")
        self.buttons[button_index].callback()

        if self.box then
            self.box.x = self.box.x + self.box_offset_x
            self.box.y = self.box.y + self.box_offset_y
        end
    end
end

function DarkMenu:updateSelectedBoxes()
    for _, actionbox in ipairs(Game.world.healthbar.action_boxes) do
        if self.state == "PARTYSELECT" and self.party_select_mode == "ALL" then
            actionbox.selected = true
            actionbox:setHeadIcon("heart")
        else
            actionbox.selected = false
            actionbox:setHeadIcon("head")
        end
    end
    if self.state == "PARTYSELECT" then
        Game.world.healthbar.action_boxes[self.selected_party].selected = true
        Game.world.healthbar.action_boxes[self.selected_party]:setHeadIcon("heart")
    end
end

function DarkMenu:update()
    if (self.panel_bg.operable) then self.animation_timer = self.animation_timer + DTMULT end
    if self.state == "BOOT" and self.panel_bg.operable then
        self:updateBootSequence()
    end

    local max_time = self.animate_out and 3 or 8

    self.description.visible = self.description_panel.operable

    if self.animation_timer > max_time + 1 then
        self.animation_done = true
        self.animation_timer = max_time + 1
        -- if self.animate_out then
        --     self:remove()
        --     return
        -- end
    end

    self.flicker_timer = self.flicker_timer + MathUtils.random(0, 11)
    if (self.flicker_timer >= 200) then
        self.flicker_timer = MathUtils.random(-200, 150)
        self.flicker_dur = Kristal.Config["simplifyVFX"] and 0 or 0.25
    end
    if (self.flicker_dur > 0) then
        self.flicker_dur = self.flicker_dur - (DTMULT / 8)
    end

    -- if not self.animate_out then
    --     if self.y < 0 then
    --         if self.y > -40 then
    --             self.y = self.y + math.ceil(-self.y / 2.5) * DTMULT
    --         else
    --             self.y = self.y + 30 * DTMULT
    --         end
    --     else
    --         self.y = 0
    --     end
    -- else
    --     if self.y > -80 then
    --         if self.y > 0 then
    --             self.y = self.y - math.floor(self.y / 2.5) * DTMULT
    --         else
    --             self.y = self.y - 30 * DTMULT
    --         end
    --     else
    --         self.y = -80
    --     end
    -- end

    super.update(self)
end

function DarkMenu:updateBootSequence()
    self.boot_timer = self.boot_timer + DTMULT

    if self.boot_timer >= 24 and not self.boot_sound_played then
        self.boot_sound_played = true
        Assets.playSound("wakeup_call")
    end

    if self.boot_timer >= 30 and not self.boot_disk_played then
        self.boot_disk_played = true
        Assets.playSound("disk_noises")
    end

    if self.boot_timer >= 108 and not self.boot_finboot_played then
        self.boot_finboot_played = true
        self:playPanelFinboot()
    end

    if self.boot_timer >= 156 and not self.boot_done then
        self.boot_done = true
        self.panel_bg.panel_ambience:play()
        self.state = "MAIN"
        self.animation_done = true
        self.animation_timer = 9
        self.flicker_dur = Kristal.Config["simplifyVFX"] and 0 or 0.2
        Game:setFlag("opened_darkmenu", true)
    end
end

function DarkMenu:playPanelFinboot()
    local sprite = self.panel_bg.open_sprite
    sprite.visible = true
    sprite:setSprite("ui/menu/panels/dark/main/menu_finboot")
    self.panel_bg.opening = true
    sprite:play(1/20, false, function()
        sprite.visible = false
        self.panel_bg.opening = false
        self.panel_bg.sprite = Assets.getTexture("ui/menu/panels/dark/main/menu")
    end)
end

function DarkMenu:draw()
    super.draw(self)
    if (not self.panel_bg.operable) then
        return
    end
    local max_time = self.animate_out and 3 or 8
    local alpha = self.animation_timer / max_time
    if (self.animation_timer > max_time) and self.flicker_dur > 0 then
        alpha = 1 - self.flicker_dur
    end
    if self.state == "BOOT" then
        self:drawBootSequence()
        return
    end

    if (self.state == "MAIN" and not self.box) then
        self:drawMainMenu(alpha)
    end

    if self.box and (self.box:includes(DarkEquipMenu) or self.box:includes(DarkSpellMenu)) then
        self:drawStat(alpha)
    else
        self:drawBag(alpha)
    end
end

function DarkMenu:getBootElementAlpha(start, duration)
    local progress = MathUtils.clamp((self.boot_timer - start) / duration, 0, 1)
    if progress <= 0 then
        return 0
    elseif progress < 1 then
        local flicker = (math.floor((self.boot_timer - start) / 3) % 2 == 0) and 1 or 0.25
        return progress * flicker
    end
    return 1
end

function DarkMenu:drawBootSequence()
    if self.boot_timer < 24 then
        self:drawBootFlicker()
    elseif self.boot_timer < 108 then
        self:drawBootLoadingScreen()
    else
        local radial_alpha = self:getBootElementAlpha(108, 10)
        local desc_alpha = self:getBootElementAlpha(116, 10)
        local health_alpha = self:getBootElementAlpha(130, 12)
        local bag_alpha = self:getBootElementAlpha(140, 10)
        local button_alphas = {}
        for i = 1, #self.buttons do
            button_alphas[i] = self:getBootElementAlpha(118 + (i * 3), 8)
        end

        self:drawMainMenu(1, {
            radial = radial_alpha,
            desc = desc_alpha,
            buttons = button_alphas,
            healthbars = health_alpha,
        })
        self:drawBag(bag_alpha)
    end
end

function DarkMenu:drawBootFlicker()
    love.graphics.stencil(function()
        love.graphics.circle("fill", SCREEN_WIDTH / 2, SCREEN_HEIGHT / 2, 162)
    end, "replace", 1)
    love.graphics.setStencilTest("greater", 0)

    local pulse = 0.08 + (math.sin(self.boot_timer / 5) * 0.03)
    Draw.setColor(pulse, pulse, pulse + 0.02, 0.55)
    love.graphics.rectangle("fill", 0, 0, SCREEN_WIDTH, SCREEN_HEIGHT)

    love.graphics.setStencilTest()
end

function DarkMenu:drawBootLoadingScreen()
    love.graphics.stencil(function()
        love.graphics.circle("fill", SCREEN_WIDTH / 2, SCREEN_HEIGHT / 2, 162)
    end, "replace", 1)
    love.graphics.setStencilTest("greater", 0)

    Draw.setColor(0.02, 0.025, 0.03, 0.92)
    love.graphics.rectangle("fill", 0, 0, SCREEN_WIDTH, SCREEN_HEIGHT)

    local progress = MathUtils.clamp((self.boot_timer - 24) / 60, 0, 1)
    local stepped_progress = math.floor(progress * 18) / 18
    if progress >= 1 then
        stepped_progress = 1
    end
    local center_x = SCREEN_WIDTH / 2
    local center_y = SCREEN_HEIGHT / 2
    local radius = 25
    local jank = (math.floor(self.boot_timer / 5) % 5) == 0
    local jitter_x = jank and ((math.floor(self.boot_timer) % 3) - 1) or 0
    local jitter_y = jank and ((math.floor(self.boot_timer / 2) % 3) - 1) or 0

    Draw.setColor(1, 1, 1, 0.05)
    for y = 90, 300, 7 do
        love.graphics.rectangle("fill", 170, y + ((math.floor(self.boot_timer / 8) % 2)), 300, 1)
    end

    Draw.setColor(1, 1, 1, 0.92)
    Draw.draw(self.boot_logo_sprite, center_x - 96 + jitter_x, center_y + 18 + jitter_y, 0, 1, 1, self.boot_logo_sprite:getPixelWidth() / 2, self.boot_logo_sprite:getPixelHeight() / 2)

    local old_line_width = love.graphics.getLineWidth()
    love.graphics.setLineWidth(4)
    Draw.setColor(PALETTE["world_dark_gray"], 0.9)
    love.graphics.circle("line", center_x + jitter_x, center_y + 38 + jitter_y, radius, 48)
    Draw.setColor(PALETTE["world_text"], 0.95)
    love.graphics.arc("line", "open", center_x + jitter_x, center_y + 38 + jitter_y, radius, -math.pi / 2, (-math.pi / 2) + (stepped_progress * math.pi * 2), 48)
    if jank and stepped_progress > 0.15 then
        Draw.setColor(PALETTE["world_gray"], 0.65)
        love.graphics.arc("line", "open", center_x + jitter_x, center_y + 38 + jitter_y, radius + 6, (stepped_progress * math.pi * 2) - 1.4, stepped_progress * math.pi * 2, 12)
    end
    love.graphics.setLineWidth(old_line_width)

    love.graphics.setFont(self.small_font)
    Draw.setColor(PALETTE["world_gray"], 0.75)
    local percent = math.floor(stepped_progress * 100) .. "%"
    local percent_alpha = (stepped_progress == 1 and (math.floor(self.boot_timer / 8) % 2 == 0)) and 0.45 or 0.8
    Draw.setColor(PALETTE["world_gray"], percent_alpha)
    love.graphics.print(percent, center_x - (self.small_font:getWidth(percent) / 2) + jitter_x, center_y + 32 + jitter_y)
    love.graphics.setFont(self.mono_font)

    love.graphics.print("REPAIRING DRIVE", center_x - (self.mono_font:getWidth("REPAIRING DRIVE") / 2) + jitter_x, center_y + 68 + jitter_y)

    love.graphics.setFont(self.font)

    love.graphics.setStencilTest()
end

function DarkMenu:drawMainMenu(alpha, parts)
    parts = parts or {}
    local radial_alpha = parts.radial or alpha
    local desc_alpha = parts.desc or alpha
    local button_alphas = parts.buttons
    local health_alpha = parts.healthbars or alpha

    Draw.setColor(1, 1, 1, radial_alpha)
    Draw.draw(self.sprite, 0, 0)
    if self.buttons[self.selected_submenu].desc_sprite then
        Draw.setColor(1, 1, 1, desc_alpha)
        Draw.draw(self.buttons[self.selected_submenu].desc_sprite, SCREEN_WIDTH/2, SCREEN_HEIGHT/2 + 38, 0, 2, 2, self.buttons[self.selected_submenu].desc_sprite:getPixelWidth()/2)
    end

    for i = 1, #self.buttons do
        self:drawButton(i, 0, 0, button_alphas and button_alphas[i] or alpha)
    end

    for i, party in ipairs(Game.party) do
        self:drawMenuHealthbar(i, party, #Game.party, health_alpha)
    end

    Draw.setColor(1, 1, 1)
end

function DarkMenu:drawBag(alpha)
    love.graphics.setFont(self.small_font)
    Draw.setColor(1,1,1, alpha)
    Draw.draw(self.bag_sprite, 0, 0)
    local base_x = 514
    local base_y = 215
    local space = 26
    local offset = (Game.money > 999) and 4 or 0

    local bandaids = Game:getFlag("bandaids", 0)
    local tonics = Game:getFlag("tonics", 0)
    local purifiers = Game:getFlag("purifiers", 0)

    if (Game.money == 0) then Draw.setColor(PALETTE["world_text_unusable"], alpha) end
    love.graphics.print(Game.money, base_x - offset, base_y)
    Draw.setColor(1,1,1, alpha)
    if (bandaids == 0) then Draw.setColor(PALETTE["world_text_unusable"], alpha) end
    love.graphics.print(bandaids, base_x, base_y + space)
    Draw.setColor(1,1,1, alpha)
    if (tonics == 0) then Draw.setColor(PALETTE["world_text_unusable"], alpha) end
    love.graphics.print(tonics, base_x, base_y + space*2)
    Draw.setColor(1,1,1, alpha)
    if (purifiers == 0) then Draw.setColor(PALETTE["world_text_unusable"], alpha) end
    love.graphics.print(purifiers, base_x, base_y + space*3)
end

function DarkMenu:drawStat(alpha)
    local chara = Game.party[self.box.party.selected_party]

    if not (chara) then return end

    Draw.setColor(1,1,1, alpha)
    love.graphics.setFont(self.small_font)
    Draw.draw(self.stat_sprite, 0, 0)
    local base_x = 514
    local base_y = 215
    local space = 26

    local max_health = self.health_override or chara:getStat("health")
    local offset = (max_health > 999) and 4 or 0
    local attack = self.attack_override or chara:getStat("attack")
    local magic = self.magic_override or chara:getStat("magic")
    local defense = self.defense_override or chara:getStat("defense")

    Draw.setColor(1,1,1, alpha)
    if (self.health_override) then
        if (chara:getStat("health") > max_health) then
            Draw.setColor(COLORS.red, alpha)
            Draw.draw(self.negative_arrow, base_x - 20, base_y)
        elseif (chara:getStat("health") < max_health) then
            Draw.setColor(COLORS.lime, alpha)
            Draw.draw(self.positive_arrow, base_x - 20, base_y)
        else
            Draw.draw(self.hp_sprite, 0, 0)
        end
    else
        Draw.draw(self.hp_sprite, 0, 0)
    end
    love.graphics.print(max_health, base_x - offset, base_y)

    Draw.setColor(1,1,1, alpha)
    if (self.attack_override) then
        if (chara:getStat("attack") > attack) then
            Draw.setColor(COLORS.red, alpha)
            Draw.draw(self.negative_arrow, base_x - 20, base_y + space)
        elseif (chara:getStat("attack") < attack) then
            Draw.setColor(COLORS.lime, alpha)
            Draw.draw(self.positive_arrow, base_x - 20, base_y + space)
        else
            Draw.draw(self.attack_sprite, 0, 0)
        end
    else
        Draw.draw(self.attack_sprite, 0, 0)
    end
    love.graphics.print(attack, base_x, base_y + space)

    Draw.setColor(1,1,1, alpha)
    if (self.magic_override) then
        if (chara:getStat("magic") > magic) then
            Draw.setColor(COLORS.red, alpha)
            Draw.draw(self.negative_arrow, base_x - 20, base_y + space*2)
        elseif (chara:getStat("magic") < magic) then
            Draw.setColor(COLORS.lime, alpha)
            Draw.draw(self.positive_arrow, base_x - 20, base_y + space*2)
        else
            Draw.draw(self.magic_sprite, 0, 0)
        end
    else
        Draw.draw(self.magic_sprite, 0, 0)
    end
    love.graphics.print(magic, base_x, base_y + space*2)

    Draw.setColor(1,1,1, alpha)
    if (self.defense_override) then
        if (chara:getStat("defense") > defense) then
            Draw.setColor(COLORS.red, alpha)
            Draw.draw(self.negative_arrow, base_x-20, base_y + space*3)
        elseif (chara:getStat("defense") < defense) then
            Draw.setColor(COLORS.lime, alpha)
            Draw.draw(self.positive_arrow, base_x-20, base_y + space*3)
        else
            Draw.draw(self.defense_sprite, 0, 0)
        end
    else
        Draw.draw(self.defense_sprite, 0, 0)
    end
    if (self.defense_override == 0) then Draw.setColor(PALETTE["world_text_hover"], alpha) end
    love.graphics.print(defense, base_x, base_y + space*3)
end

---comment
---@param battler PartyMember
---@param color table
---@param x number
---@param y number
function DarkMenu:drawCurrentHealth(battler, color, x, y)
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
    local string_from = tostring(battler:getHealth())
    local string_to = tostring(battler:getHealth())
    local max_string_length = math.max(#string_from, #string_to)
    for i = 1, max_string_length - #string_from do
        string_from = ' ' .. string_from
    end
    for i = 1, max_string_length - #string_to do
        string_to = ' ' .. string_to
    end
    local health_offset = (max_string_length - 1) * 8
    x = x - health_offset
    local roll_progress = 1
    local rolling_down = false
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

---@param index number Party member index
---@param member PartyMember member
---@param party_size number party size
function DarkMenu:drawMenuHealthbar(index, member, party_size, alpha)
    local start_x = SCREEN_WIDTH / 2
    local y = 332
    local x = start_x
    if (party_size % 2 == 0) then
        local offset = (index <= party_size / 2) and ((party_size/2) +1 - index) or (index - party_size/2)
        if (index <= (party_size / 2)) then
            x = x - 16 --* offset
        else
            x = x + 16 --* offset
        end
        if (math.abs(offset) > 1) then
            x = x + (21 * (index - (party_size+1)/2))
        end
    elseif (party_size >= 3) then
        x = x + (42 * (index - (party_size+1)/2))
    end

    Draw.setColor(1,1,1, alpha)

    local head_sprite = Assets.getTexture(member:getHeadIcons() .. "/head")
    local width = head_sprite:getPixelWidth()
    Draw.draw(head_sprite, x - (width/2), y, 0)


    Draw.setColor(PALETTE["action_health_bg"], alpha)
    love.graphics.rectangle("fill", x - (97/8), y + 30, 97/4, 9)

    local health = (member:getHealth() / member:getStat("health")) * (97/4)

    if health > 0 then
        Draw.setColor({member:getColor()}, alpha)
        love.graphics.rectangle("fill", x - (97/8), y + 30, math.ceil(health), 9)
    end
end

function DarkMenu:drawButton(index, x, y, alpha)
    local button = self.buttons[index]
    local sprite = button.sprite
    if index == self.selected_submenu then
        sprite = button.hovered_sprite
    end
    if not sprite then return end
    Draw.setColor(1, 1, 1, alpha)
    Draw.draw(sprite, x, y, 0, 1, 1)
    -- if index == self.selected_submenu and self.state == "MAIN" then
    --     Draw.setColor(Game:getSoulColor())
    --     Draw.draw(self.heart_sprite, x + 15, y + 25, 0, 2, 2, self.heart_sprite:getWidth() / 2, self.heart_sprite:getHeight() / 2)
    -- end
end

return DarkMenu
