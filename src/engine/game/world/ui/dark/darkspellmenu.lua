---@class DarkSpellMenu : Object
---@overload fun(...) : DarkSpellMenu
local DarkSpellMenu, super = Class(Object)

function DarkSpellMenu:init()
    super.init(self, 82, 112, 477, 277)

    self.draw_children_below = 0

    self.font = Assets.getFont("main")
    self.header_font = Assets.getFont("small")
    self.small_font = Assets.getFont("smallnumbers")
    self.earthbound_font = Assets.getFont("eb")

    self.ui_move = Assets.newSound("ui_move_panel")
    self.ui_select = Assets.newSound("ui_select_panel")
    self.ui_cant_select = Assets.newSound("ui_error_panel")
    self.ui_cancel_small = Assets.newSound("ui_cancel_small_camera")

    self.heart_sprite = Assets.getTexture("player/heart")
    self.arrow_sprite = Assets.getTexture("ui/page_arrow_down")

    self.tp_sprite = Game:getConfig("oldUIPositions") and Assets.getTexture("ui/menu/caption_tp_old") or Assets.getTexture("ui/menu/caption_tp")
    self.popup_sprite = Assets.getTexture("ui/menu/popup")
    self.popup_text = nil

    self.caption_sprites = {
          ["char"] = Assets.getTexture("ui/menu/caption_char"),
         ["stats"] = Assets.getTexture("ui/menu/caption_spells"),
        ["spells"] = Assets.getTexture("ui/menu/caption_known"),
    }

    self.stat_icons = {
         ["attack"] = Assets.getTexture("ui/menu/icon/sword"),
        ["defense"] = Assets.getTexture("ui/menu/icon/armor"),
          ["magic"] = Assets.getTexture("ui/menu/icon/magic"),
   }

    -- self.bg = UIBox(0, 0, self.width, self.height)
    -- self.bg.layer = -1
    -- self.bg.debug_select = false
    -- self:addChild(self.bg)

    self.party = DarkMenuPartySelect(8, 48)
    self.party.focused = true
    self:addChild(self.party)

    -- PARTY, SPELLS, SELECT
    self.state = "PARTY"
    self.replacing = nil

    self.selected_spell = 1
    self.selected_known = 1
    self.known_scroll = 1

    self.scroll_y = 1

    Assets.stopAndPlaySound("item_trash_warning", 0.6)
end

function DarkSpellMenu:getSpellLimit()
    return 6
end

function DarkSpellMenu:getSpells()
    local spells = {}
    local party = self.party:getSelected()
    for _,spell in ipairs(party:getSpells()) do
        table.insert(spells, spell)
    end
    return spells
end

function DarkSpellMenu:getKnownSpells()
    local spells = {}
    local party = self.party:getSelected()
    for _,spell in ipairs(party:getKnownSpells()) do
        table.insert(spells, spell)
    end
    return spells
end

function DarkSpellMenu:updateDescription()
    if self.state == "PARTY" then
        Game.world.menu:setDescription("", false)
    elseif self.state == "SPELLS" then
        local spell = self:getSpells()[self.selected_spell]
        local visible = spell ~= nil
        Game.world.menu:setDescription(spell and spell:getDescription() or "", visible)
    elseif self.state == "SELECT" then
        local known = self:getKnownSpells()[self.selected_known]
        Game.world.menu:setDescription(known and known:getDescription() or "", true)
    end
end

function DarkSpellMenu:onRemove(parent)
    super.onRemove(self, parent)
    if Game.world.menu then
        Game.world.menu:updateSelectedBoxes()
    end
end

function DarkSpellMenu:update()
    self.alpha = 1 - Game.world.menu.flicker_dur
    if self.state == "PARTY" then
        self.popup_text = "PLEASE SELECT\nA VALID USER"
        if Input.pressed("cancel") then
            self.ui_cancel_small:stop()
            self.ui_cancel_small:play()
            self.popup_text = nil
            Game.world.menu:closeBox()
            return
        elseif Input.pressed("confirm") then
            if #self:getSpells() > 0 then
                self.state = "SPELLS"

                self.party.focused = false
                self.popup_text = nil

                self.ui_select:stop()
                self.ui_select:play()

                self.selected_spell = 1
                self.scroll_y = 1

                self:updateDescription()
            else
                self.state = "SELECT"
                self.party.focused = false
                self.popup_text = nil
                self.ui_select:stop()
                self.ui_select:play()
                self.selected_known = 1
                self.known_scroll = 1
                self:updateDescription()
            end
        end
    elseif self.state == "SPELLS" then
        if Input.pressed("cancel") then
            self.state = "PARTY"
            self.popup_text = "PLEASE SELECT\nA VALID USER"

            self.ui_cancel_small:stop()
            self.ui_cancel_small:play()

            self.party.focused = true

            self.scroll_y = 1

            self:updateDescription()
            return
        end
        if Input.pressed("confirm") then
            self.replacing = self:getSpells()[self.selected_spell]
            if (self.replacing ~= nil and self.replacing.required == true) then
                self.ui_cant_select:stop()
                self.ui_cant_select:play()
                self.replacing = nil
                return
            end
            self.state = "SELECT"

            self.ui_select:stop()
            self.ui_select:play()
            
            self.selected_known = 1
            self.known_scroll = 1
            self:updateDescription()
        end
        local spells = self:getSpells()
        local old_selected = self.selected_spell
        if Input.pressed("up", true) then
            self.selected_spell = self.selected_spell - 1
        end
        if Input.pressed("down", true) then
            self.selected_spell = self.selected_spell + 1
        end
        local max_spells = self.party:getSelected():getStat("max_spells", 6)
        self.selected_spell = MathUtils.clamp(self.selected_spell, 1, max_spells)
        if self.selected_spell ~= old_selected then
            local spell_limit = self:getSpellLimit()
            local min_scroll = math.max(1, self.selected_spell - (spell_limit - 1))
            local max_scroll = math.min(math.max(1, max_spells - (spell_limit - 1)), self.selected_spell)
            self.scroll_y = MathUtils.clamp(self.scroll_y, min_scroll, max_scroll)

            self.ui_move:stop()
            self.ui_move:play()
            self:updateDescription()
        end
    elseif self.state == "SELECT" then
        if Input.pressed("cancel") then
            self.state = "SPELLS"

            self.ui_cancel_small:stop()
            self.ui_cancel_small:play()

            self.known_scroll = 1

            self:updateDescription()
            return
        end
        if Input.pressed("confirm") then
            local spell = self:getKnownSpells()[self.selected_known]
            if (self:hasEquipped(spell) and self.replacing ~= spell) then
                self.ui_cant_select:stop()
                self.ui_cant_select:play()
                return
            elseif (self:hasEquipped(spell) and self.replacing == spell) then
                self.party:getSelected():removeSpell(spell)
            end
            if (not spell and self.replacing) then
                self.party:getSelected():removeSpell(self.replacing)
            else
                if (spell == nil) then return end
                if (self.replacing) then self.party:getSelected():replaceSpell(self.replacing, spell) else self.party:getSelected():addSpell(spell) end
            end
            
            
            self.replacing = nil
            self.state = "SPELLS"
            self.ui_select:stop()
            self.ui_select:play()
            self.selected_known = 1
            self.known_scroll = 1
            self:updateDescription()
        end
        local spells = self:getKnownSpells()
        local old_selected = self.selected_known
        if Input.pressed("up", true) then
            self.selected_known = self.selected_known - 1
        end
        if Input.pressed("down", true) then
            self.selected_known = self.selected_known + 1
        end
        self.selected_known = MathUtils.clamp(self.selected_known, 1, 30)
        if self.selected_known ~= old_selected then
            local spell_limit = self:getSpellLimit()
            local min_scroll = math.max(1, self.selected_known - (spell_limit - 1))
            local max_scroll = math.min(math.max(1, 30 - (spell_limit - 1)), self.selected_known)
            self.known_scroll = MathUtils.clamp(self.known_scroll, min_scroll, max_scroll)

            self.ui_move:stop()
            self.ui_move:play()
            self:updateDescription()
        end
    end
    super.update(self)
end

function DarkSpellMenu:isRequired(spell)
    return spell.required or false
end

function DarkSpellMenu:hasEquipped(spell)
    return TableUtils.contains(self:getSpells(), spell)
end

function DarkSpellMenu:draw()
    love.graphics.setFont(self.font)

    Draw.setColor(1, 1, 1, self.alpha)
    love.graphics.stencil(function()
        love.graphics.circle("fill", SCREEN_WIDTH / 2 - self.x, SCREEN_HEIGHT / 2 - self.y, 162)
    end, "replace", 1)
    love.graphics.setStencilTest("greater", 0)

    if self.state ~= "PARTY" then
        self:drawChar()
        self:drawKnown()
        self:drawSpells()
    end

    self:drawPopup()

    love.graphics.setStencilTest()

    super.draw(self)
end

function DarkSpellMenu:drawPopup()
    if self.popup_text then
        Draw.setColor(1, 1, 1, self.alpha)
        Draw.draw(self.popup_sprite, SCREEN_WIDTH / 3.95, 86)
        Draw.setColor(0, 0, 0, self.alpha)
        love.graphics.setFont(self.earthbound_font)
        local _, wrapped = self.earthbound_font:getWrap(self.popup_text, 150)
        local base_y = 96
        if #wrapped < 4 then
            base_y = base_y + (16 * (3.5 - #wrapped))
        end
        for i, textline in ipairs(wrapped) do
            love.graphics.print(textline, (SCREEN_WIDTH / 4) + 10, base_y + (16 * (i - 1)))
            if i > 4 then break end
        end
        love.graphics.setFont(self.font)
        Draw.setColor(1, 1, 1, 1)
    end
end

function DarkSpellMenu:drawSectionHeader(text, y, left, right)
    local old_font = love.graphics.getFont()
    love.graphics.setFont(self.header_font)
    love.graphics.setLineWidth(2)

    Draw.setColor(PALETTE["world_header"] or PALETTE["world_text"], self.alpha)

    local center = (left + right) / 2
    local width = self.header_font:getWidth(text)
    local gap = 8

    love.graphics.line(left, y, center - (width / 2) - gap, y)
    love.graphics.line(center + (width / 2) + gap, y, right, y)
    love.graphics.print(text, center - (width / 2), y - 6)

    love.graphics.setFont(old_font)
end

function DarkSpellMenu:drawChar()
    local party = self.party:getSelected()
    local center_x = SCREEN_WIDTH / 2 - self.x

    Draw.setColor(PALETTE["world_text"], self.alpha)
    local name_width = self.font:getWidth(party:getName())
    love.graphics.print(party:getName(), center_x - (name_width / 2), -28)

    love.graphics.setFont(self.header_font)
    Draw.setColor(PALETTE["world_gray"], self.alpha)
    local title = party:getTitle()
    local title_width = self.header_font:getWidth(title)
    love.graphics.print(title, center_x - (title_width / 2), -1)
    love.graphics.setFont(self.font)
end

function DarkSpellMenu:drawKnown()
    local spells = self:getKnownSpells()

    local max_display = 30

    local tp_x, tp_y
    local name_x, name_y

    tp_x, tp_y = 236, 121
    name_x, name_y = 294, 121

    self:drawSectionHeader("KNOWN", 96, 236, 390)

    Draw.setColor(1, 1, 1, self.alpha)
    Draw.draw(self.tp_sprite, tp_x, tp_y - 5)

    local spell_limit = self:getSpellLimit()

    for i = self.known_scroll, math.min(max_display, self.known_scroll + (spell_limit - 1)) do
        local offset = i - self.known_scroll
        local spell = spells[i]
        if (not spell) then
            Draw.setColor(PALETTE["world_dark_gray"], self.alpha)
            love.graphics.print("---------", name_x, name_y + (offset * 27) - 6)
        else
            local equipped = self:hasEquipped(spell)
            if (self:hasEquipped(spell)) then
                Draw.setColor(PALETTE["world_gray"], self.alpha)
            else
                Draw.setColor(PALETTE["world_text"], self.alpha)
            end
            if (spell.psychic) then
                local npCost = tostring(spell:getNPCost(self.party:getSelected()))
                local heat = tostring(spell:getNHeat(self.party:getSelected()))
                love.graphics.setFont(self.small_font)
                local pColor = COLORS.aqua
                local hColor = COLORS.red
                if (equipped) then
                    pColor = {0, 0.5, 0.5, 1}
                    hColor = {0.5, 0, 0, 1}
                end
                Draw.setColor(PALETTE["world_gray"], self.alpha)
                love.graphics.print("-", tp_x+ (12 * npCost:len()), tp_y+12 + (offset * 25))
                Draw.setColor(pColor, self.alpha)
                love.graphics.print(npCost.."%P", tp_x, tp_y+12 + (offset * 25))
                Draw.setColor(hColor, self.alpha)
                love.graphics.print(heat.."H", tp_x+(12 * (npCost:len())+8), tp_y+12 + (offset * 25))
                if (not equipped) then Draw.setColor(PALETTE["world_text"], self.alpha) else Draw.setColor(PALETTE["world_gray"], self.alpha) end
                love.graphics.setFont(self.font)
            else
                love.graphics.print(tostring(spell:getTPCost(self.party:getSelected())).."%", tp_x, tp_y + (offset * 25))
            end
            love.graphics.print(spell:getName(), name_x, name_y + (offset * 25))
        end
    end

    -- Draw scroll arrows if needed
    if max_display > spell_limit then
        Draw.setColor(1, 1, 1, self.alpha)

        -- Move the arrows up and down only if we're in the spell selection state
        local sine_off = 0
        if self.state == "SELECT" then
            sine_off = math.sin((Kristal.getTime()*30)/12) * 3
        end

        if self.known_scroll > 1 then
            -- up arrow
            Draw.draw(self.arrow_sprite, 386, (name_y + 25 - 3) - sine_off, 0, 1, -1)
        end
        if self.known_scroll + spell_limit <= 30 then
            -- down arrow
            Draw.draw(self.arrow_sprite, 386, (name_y + (25 * spell_limit) - 12) + sine_off)
        end
    end

    if self.state == "SELECT" then
        Draw.setColor(Game:getSoulColor())
        Draw.draw(self.heart_sprite, tp_x - 20, tp_y + 10 + ((self.selected_known - self.known_scroll) * 25))

        -- Draw scrollbar if needed (unless the spell limit is 2, in which case the scrollbar is too small)
        if spell_limit > 2 and max_display > spell_limit then
            local scrollbar_height = (spell_limit - 2) * 25
            Draw.setColor(PALETTE["world_dark_gray"], self.alpha)
            love.graphics.rectangle("fill", 390, name_y + 30, 6, scrollbar_height)
            local percent = (self.known_scroll - 1) / (max_display - spell_limit)
            Draw.setColor(1, 1, 1, self.alpha)
            love.graphics.rectangle("fill", 390, name_y + 30 + math.floor(percent * (scrollbar_height-6)), 6, 6)
        end
    end
end

function DarkSpellMenu:drawSpells()
    local spells = self:getSpells()
    local max_spells = self.party:getSelected():getStat("max_spells", 6)
    local spell_weight = self.party:getSelected():getSpellWeight()

    local tp_x, tp_y
    local name_x, name_y

    tp_x, tp_y = 92, 121
    name_x, name_y = 116, 121

    self:drawSectionHeader("EQUIPPED", 96, 88, 212)

    Draw.setColor(1, 1, 1, self.alpha)
    --Draw.draw(self.tp_sprite, tp_x, tp_y - 5)

    local spell_limit = self:getSpellLimit()

    for i = self.scroll_y, math.min(max_spells, self.scroll_y + (spell_limit - 1)) do
        local offset = i - self.scroll_y
        local spell = spells[i]
        if (not spell) then
            Draw.setColor(PALETTE["world_dark_gray"], self.alpha)
            love.graphics.print("---------", name_x + 4, name_y + (offset * 27) - 6)
        else
            if self:isRequired(spell) then
                Draw.setColor(PALETTE["world_gray"], self.alpha)
            else
                Draw.setColor(PALETTE["world_text"], self.alpha)
            end
            --love.graphics.print(tostring(spell:getTPCost(self.party:getSelected())).."%", tp_x, tp_y + (offset * 25))
            love.graphics.print(spell:getName(), name_x, name_y + (offset * 25))
        end
    end

    -- Draw scroll arrows if needed
    if max_spells > spell_limit then
        Draw.setColor(1, 1, 1, self.alpha)

        -- Move the arrows up and down only if we're in the spell selection state
        local sine_off = 0
        if self.state == "SPELLS" then
            sine_off = math.sin((Kristal.getTime()*30)/12) * 3
        end

        if self.scroll_y > 1 then
            -- up arrow
            Draw.draw(self.arrow_sprite, 208, (name_y + 25 - 3) - sine_off, 0, 1, -1)
        end
        if self.scroll_y + spell_limit <= #spells then
            -- down arrow
            Draw.draw(self.arrow_sprite, 208, (name_y + (25 * spell_limit) - 12) + sine_off)
        end
    end

    if (spell_weight < max_spells) then
        Draw.setColor(1, 1, 1, self.alpha)
    else
        Draw.setColor(0.8, 0, 0, self.alpha)
    end
    love.graphics.setFont(self.small_font)
    love.graphics.print("("..tostring(spell_weight).."/"..tostring(max_spells)..")", tp_x, tp_y - 8)
    love.graphics.setFont(self.font)
    Draw.setColor(1, 1, 1, self.alpha)
    if self.state == "SPELLS" then
        Draw.setColor(Game:getSoulColor())
        Draw.draw(self.heart_sprite, tp_x, tp_y + 10 + ((self.selected_spell - self.scroll_y) * 25))

        -- Draw scrollbar if needed (unless the spell limit is 2, in which case the scrollbar is too small)
        if spell_limit > 2 and #spells > spell_limit then
            local scrollbar_height = (spell_limit - 2) * 25
            Draw.setColor(PALETTE["world_dark_gray"], self.alpha)
            love.graphics.rectangle("fill", 212, name_y + 30, 6, scrollbar_height)
            local percent = (self.scroll_y - 1) / (#spells - spell_limit)
            Draw.setColor(1, 1, 1, self.alpha)
            love.graphics.rectangle("fill", 212, name_y + 30 + math.floor(percent * (scrollbar_height-6)), 6, 6)
        end
    end
end

return DarkSpellMenu
