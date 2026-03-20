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

    self.state = "MAIN"
    self.state_reason = nil
    self.heart_sprite = Assets.getTexture("player/heart_menu_small")

    self.ui_select = Assets.newSound("ui_select_camera")
    self.ui_move = Assets.newSound("ui_move_panel")
    self.ui_cancel_small = Assets.newSound("ui_cancel_small_camera")
    self.ui_cant_select = Assets.newSound("ui_error_camera")

    self.font = Assets.getFont("main")
    self.small_font = Assets.getFont("smallnumbers")
    self.ui_interrupt = Assets.newSound("ui_interrupt_hand")
    self.ui_interrupt:setVolume(0.25)

    self.panel_bg = PanelMenuBackground("ui/menu/panels/dark/main/menu", 0, 0, "hand_open", "hand_open", "ui_move_panel", "ui_select_hand", "ui_error_hand", "ui_cancel_small", "ui_static", 0, 0)
    self:addChild(self.panel_bg)

    self.description_panel = PanelMenuBackground("ui/menu/panels/dark/hand/menu", 0, 0, "hand_open", "hand_open", "ui_move_panel", "ui_select_panel", "ui_error_panel", "ui_cancel_small_camera", nil, 0, 0, false)
    self.description_panel.layer = 10
    self:addChild(self.description_panel)
    self.description = Text("", 20, 10, 540, 80 - 16)
    self.description.visible = false
    self.description_panel:addChild(self.description)

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
            self.box.layer = 1
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
            self.box.layer = 1
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
            self.box.layer = 1
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

function DarkMenu:closeBox(immediate)
    self.state = "MAIN"
    if (self.box) then
        if (self.description_panel and not self.description_panel.closed) then self.description_panel:close(immediate) end
        if (self.box.panel_bg ~= nil) then 
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

function DarkMenu:draw()
    super.draw(self)
    if (not self.panel_bg.operable) then
        return
    end
    if (self.state == "MAIN" and not self.box) then
        local max_time = self.animate_out and 3 or 8            
        Draw.setColor(1, 1, 1, self.animation_timer / max_time)
        Draw.draw(self.sprite, 0, 0)
        if self.buttons[self.selected_submenu].desc_sprite then
            Draw.draw(self.buttons[self.selected_submenu].desc_sprite, SCREEN_WIDTH/2, SCREEN_HEIGHT/2 + 38, 0, 2, 2, self.buttons[self.selected_submenu].desc_sprite:getPixelWidth()/2)
        end

        for i = 1, #self.buttons do
            self:drawButton(i, 0, 0)
        end

        for i, party in ipairs(Game.party) do
            self:drawMenuHealthbar(i, party, #Game.party)
        end

        Draw.setColor(1, 1, 1)
    end

    love.graphics.setFont(self.small_font)
    local base_x = 514
    local base_y = 215
    local space = 26
    local offset = (Game.money > 999) and 4 or 0
    love.graphics.print(Game.money, base_x - offset, base_y)
    love.graphics.print(Game:getFlag("bandaids", 0), base_x, base_y + space)
    love.graphics.print(Game:getFlag("tonics", 0), base_x, base_y + space*2)
    love.graphics.print(Game:getFlag("purifiers", 0), base_x, base_y + space*3)
    
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
function DarkMenu:drawMenuHealthbar(index, member, party_size)
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

    Draw.setColor(1,1,1,1)

    local head_sprite = Assets.getTexture(member:getHeadIcons() .. "/head")
    local width = head_sprite:getPixelWidth()
    Draw.draw(head_sprite, x - (width/2), y, 0)


    Draw.setColor(PALETTE["action_health_bg"])
    love.graphics.rectangle("fill", x - (97/8), y + 30, 97/4, 9)

    local health = (member:getHealth() / member:getStat("health")) * (97/4)

    if health > 0 then
        Draw.setColor(member:getColor())
        love.graphics.rectangle("fill", x - (97/8), y + 30, math.ceil(health), 9)
    end
    local color = PALETTE["action_health_text"]
    if health <= 0 then
        color = PALETTE["action_health_text_down"]
    elseif (member:getHealth() <= (member:getStat("health") / 4)) then
        color = PALETTE["action_health_text_low"]
    else
        color = PALETTE["action_health_text"]
    end
    love.graphics.setFont(self.small_font)
    --self:drawCurrentHealth(member, color, x, y + 28)
end

function DarkMenu:drawButton(index, x, y)
    local button = self.buttons[index]
    local sprite = button.sprite
    if index == self.selected_submenu then
        sprite = button.hovered_sprite
    end
    if not sprite then return end
    Draw.setColor(1, 1, 1)
    Draw.draw(sprite, x, y, 0, 1, 1)
    -- if index == self.selected_submenu and self.state == "MAIN" then
    --     Draw.setColor(Game:getSoulColor())
    --     Draw.draw(self.heart_sprite, x + 15, y + 25, 0, 2, 2, self.heart_sprite:getWidth() / 2, self.heart_sprite:getHeight() / 2)
    -- end
end

return DarkMenu
