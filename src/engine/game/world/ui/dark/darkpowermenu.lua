---@class DarkPowerMenu : Object
---@overload fun(...) : DarkPowerMenu
local DarkPowerMenu, super = Class(Object)

function DarkPowerMenu:init()
    super.init(self, 82, 112, 477, 277)

    self.draw_children_below = 0

    self.font = Assets.getFont("main")
    self.header_font = Assets.getFont("small")
    self.small_font = Assets.getFont("smallnumbers")
    self.earthbound_font = Assets.getFont("eb")
    self.mono_font = Assets.getFont("main_mono", 16)
    self.wingdings_font = Assets.getFont("wingdings", 4)
    self.lv_sprite = Assets.getTexture("ui/menu/caption_lv")

    self.ui_move = Assets.newSound("ui_move_panel")
    self.ui_select = Assets.newSound("ui_select_panel")
    self.ui_cant_select = Assets.newSound("ui_error_panel")
    self.ui_cancel_small = Assets.newSound("ui_cancel_small_camera")

    self.heart_sprite = Assets.getTexture("ui/flat_arrow_right")
    self.left_arrow_sprite = Assets.getTexture("ui/page_arrow_left")
    self.right_arrow_sprite = Assets.getTexture("ui/page_arrow_right")

    self.popup_sprite = Assets.getTexture("ui/menu/popup")
    self.popup_text = nil

    self.stat_icons = {
        ["health"] = Assets.getTexture("ui/menu/icon/health"),
        ["sword"] = Assets.getTexture("ui/menu/icon/sword"),
        ["armor"] = Assets.getTexture("ui/menu/icon/armor"),
        ["attack"] = Assets.getTexture("ui/menu/icon/sword"),
        ["defense"] = Assets.getTexture("ui/menu/icon/armor"),
        ["magic"] = Assets.getTexture("ui/menu/icon/magic"),
        ["gift"] = Assets.getTexture("ui/menu/icon/gift"),
        ["up"] = Assets.getTexture("ui/menu/icon/up"),
        ["down"] = Assets.getTexture("ui/menu/icon/down"),
        ["act"] = Assets.getTexture("ui/menu/icon/exclamation"),
        ["mercy"] = Assets.getTexture("ui/menu/icon/note"),
        ["demise"] = Assets.getTexture("ui/menu/icon/smile"),
   }

    -- self.bg = UIBox(0, 0, self.width, self.height)
    -- self.bg.layer = -1
    -- self.bg.debug_select = false
    -- self:addChild(self.bg)

    self.party = DarkMenuPartySelect(8, 48)
    self.party.focused = true
    self:addChild(self.party)

    self.party.on_select = function(new, old)
        Game.party[old]:onPowerDeselect(self)
        Game.party[new]:onPowerSelect(self)
        self.pending_stat_allocations = {}
        self:refreshStatPoints()
        self:syncBust()
    end

    -- PARTY, OVERVIEW, STATS, CONFIRM
    self.state = "PARTY"

    self.stat_rows = {
        {id = "health", label = "Health", description = "WITHSTAND PAIN."},
        {id = "attack", label = "Attack", description = "ENHANCE PAIN."},
        {id = "defense", label = "Defense", description = "REDUCE WOUNDS."},
        {id = "magic", label = "Magic", description = "EMPOWER LIGHT."},
    }
    self.character_statistics = {
        {
            name = "PAIN",
            stats = {
                {label = "INFLICTED", flag = "%s/damage_dealt", icon = "sword"},
                {label = "RECIEVED", flag = "%s/damage_taken", icon = "armor"},
                {label = "RELIEVED", flag = "%s/healing_done", icon = "health"},
            },
        },
        {
            name = "EXPERIENCED",
            stats = {
                {label = "VICTORY", flag = "%s/battles_won", icon = "up"},
                {label = "FALL", flag = "%s/downed_count", icon = "down"},
                {label = "DEMISE", flag = "evan/remembered_deaths", icon = "demise", glitch = true, evan_only = true},
            },
        },
        {
            name = "PERFORMED",
            stats = {
                {label = "ATTACK", flag = "%s/attacks_made", icon = "sword"},
                {label = "ACT", flag = "%s/acts_done", icon = "act"},
                {label = "CAST", flag = "%s/spells_cast", icon = "magic"},
                {label = "MERCY", flag = "%s/times_spared", icon = "mercy"},
            },
        },
    }
    self.selected_stat = 1
    self.overview_page = 1
    self.max_overview_pages = 2
    self.pending_stat_points = 0
    self.pending_stat_allocations = {}
    self:refreshStatPoints()

    self.bust = Bust(nil, nil, nil, 64, 64)
    self.bust:setScale(2)
    self.bust.body.inherit_color = true
    self.bust.face.inherit_color = true
    self.bust.visible = false
    self.bust.active = false
    self:addChild(self.bust)
    self.bust_available = false
    self:syncBust()
    self:updateBustVisibility()

    self.selection_siner = 0

    Assets.stopAndPlaySound("item_trash_warning", 0.6)
end

function DarkPowerMenu:updateDescription()
    if self.state == "PARTY" then
        Game.world.menu:setDescription("", false)
    elseif self.state == "OVERVIEW" or self.state == "STATS" then
        Game.world.menu:setDescription("", false)
    end
end

function DarkPowerMenu:onRemove(parent)
    super.onRemove(self, parent)
    if Game.world.menu then
        Game.world.menu:updateSelectedBoxes()
    end
end

function DarkPowerMenu:update()
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
            self.state = "OVERVIEW"

            self.party.focused = false
            self.popup_text = nil
            self.overview_page = 1

            self.ui_select:stop()
            self.ui_select:play()

            self.selected_stat = 1

            self:updateDescription()
        end
    elseif self.state == "OVERVIEW" then
        if Input.pressed("cancel") then
            self.state = "PARTY"
            self.popup_text = "PLEASE SELECT\nA VALID USER"

            self.ui_cancel_small:stop()
            self.ui_cancel_small:play()

            self.party.focused = true

            self:updateDescription()
            return
        end

        local old_page = self.overview_page
        if Input.pressed("left", true) then
            self.overview_page = self.overview_page - 1
        end
        if Input.pressed("right", true) then
            self.overview_page = self.overview_page + 1
        end
        self.overview_page = MathUtils.clamp(self.overview_page, 1, self.max_overview_pages)

        if self.overview_page ~= old_page then
            self.ui_move:stop()
            self.ui_move:play()
            self:updateDescription()
        elseif Input.pressed("confirm") then
            if self.overview_page == 1 then
                self.state = "STATS"

                self.ui_select:stop()
                self.ui_select:play()

                self:updateDescription()
            else
                self.ui_cant_select:stop()
                self.ui_cant_select:play()
            end
        end
    elseif self.state == "STATS" then
        self.selection_siner = self.selection_siner + (DTMULT / 8)
        if Input.pressed("cancel") then
            self.state = "OVERVIEW"
            self.popup_text = nil

            self.ui_cancel_small:stop()
            self.ui_cancel_small:play()

            self:updateDescription()
            return
        end

        local old_selected = self.selected_stat
        if Input.pressed("up", true) then
            self.selected_stat = self.selected_stat - 1
        end
        if Input.pressed("down", true) then
            self.selected_stat = self.selected_stat + 1
        end
        self.selected_stat = MathUtils.clamp(self.selected_stat, 1, #self.stat_rows)

        if self.selected_stat ~= old_selected then
            self.ui_move:stop()
            self.ui_move:play()
            self:updateDescription()
        end

        local pressed_left = Input.pressed("left", true)
        local pressed_right = Input.pressed("right", true)
        local pressed_confirm = Input.pressed("confirm")

        if pressed_left then
            if not self:allocateSelectedStat(-1) then
                self.ui_cant_select:stop()
                self.ui_cant_select:play()
            end
        elseif pressed_right or pressed_confirm then
            if pressed_confirm and self:hasPendingStatAllocations() then
                self:beginPendingStatConfirm()
                return
            end
            if not self:allocateSelectedStat(1) then
                self.ui_cant_select:stop()
                self.ui_cant_select:play()
            end
        end
    elseif self.state == "CONFIRM" then
        if Input.pressed("cancel") then
            self.state = "STATS"
            self.popup_text = nil

            self.ui_cancel_small:stop()
            self.ui_cancel_small:play()

            self:updateDescription()
            return
        elseif Input.pressed("confirm") then
            if self:applyPendingStatAllocations() then
                Assets.playSound("item_use")
            else
                self.ui_cant_select:stop()
                self.ui_cant_select:play()
            end

            self.state = "STATS"
            self.popup_text = nil
            self:updateDescription()
            return
        end
    end
    self:updateBustVisibility()
    super.update(self)
end

function DarkPowerMenu:syncBust()
    local party = self.party:getSelected()
    local actor = party and party:getActor(false)
    self.bust_available = false

    if not actor or not actor:getBustPath() then
        return
    end

    self.bust:setActor(actor)
    local body = actor:getDefaultBust() or "idle"
    if self.bust:setBody(body) then
        self.bust:setFace("blank")
        self.bust_available = true
    end
end

function DarkPowerMenu:updateBustVisibility()
    local visible = self.bust_available and self.state ~= "PARTY"
    self.bust.visible = visible
    self.bust.active = visible
    self.bust:setColor(1, 1, 1, self.alpha)
end

function DarkPowerMenu:getClassText()
    local lines = StringUtils.split(self.party:getSelected().title or "", "\n", false)
    local class_name = lines[1] or ""
    local description = {}
    for i = 2, #lines do
        table.insert(description, lines[i])
    end
    return class_name, table.concat(description, "\n")
end

function DarkPowerMenu:getPendingStatAllocation(stat)
    return self.pending_stat_allocations[stat] or 0
end

function DarkPowerMenu:refreshStatPoints()
    local party = self.party:getSelected()
    if not party then
        self.pending_stat_points = 0
        return
    end
    self.pending_stat_points = Game:getFlag(party.id .. "/stat_points", 0) - Game:getFlag(party.id .. "/assigned_stat_points", 0)
end

function DarkPowerMenu:getTotalPendingStatAllocation()
    local spent = 0
    for _, amount in pairs(self.pending_stat_allocations) do
        spent = spent + amount
    end
    return spent
end

function DarkPowerMenu:getAvailableStatPoints()
    return self.pending_stat_points - self:getTotalPendingStatAllocation()
end

function DarkPowerMenu:hasPendingStatAllocations()
    return self:getTotalPendingStatAllocation() > 0
end

function DarkPowerMenu:getCurrentStatRow()
    return self.stat_rows[self.selected_stat]
end

function DarkPowerMenu:canAllocateStat(stat, amount)
    if amount > 0 then
        return self:getAvailableStatPoints() >= amount
    elseif amount < 0 then
        return self:getPendingStatAllocation(stat) >= -amount
    end
    return false
end

function DarkPowerMenu:allocateSelectedStat(amount)
    local row = self:getCurrentStatRow()
    if not row or not self:canAllocateStat(row.id, amount) then
        return false
    end
    self.pending_stat_allocations[row.id] = self:getPendingStatAllocation(row.id) + amount
    Assets.playSound("item_click")
    return true
end

function DarkPowerMenu:beginPendingStatConfirm()
    self.state = "CONFIRM"
    self.popup_text = "ASSIGN POINT?\nTHIS IS IRREVERSIBLE."

    self.ui_select:stop()
    self.ui_select:play()

    self:updateDescription()
end

function DarkPowerMenu:applyPendingStatAllocations()
    local party = self.party:getSelected()
    local total = self:getTotalPendingStatAllocation()
    if not party or total <= 0 then
        return false
    end

    for stat, amount in pairs(self.pending_stat_allocations) do
        if amount > 0 then
            party:increaseStat(stat, amount)
        end
    end

    Game:addFlag(party.id .. "/assigned_stat_points", total)
    self.pending_stat_allocations = {}
    self:refreshStatPoints()

    return true
end

function DarkPowerMenu:draw()
    love.graphics.setFont(self.font)

    Draw.setColor(1, 1, 1, self.alpha)
    love.graphics.stencil(function()
        love.graphics.circle("fill", SCREEN_WIDTH / 2 - self.x, SCREEN_HEIGHT / 2 - self.y, 162)
    end, "replace", 1)
    love.graphics.setStencilTest("greater", 0)

    self:updateBustVisibility()
    if self.bust.visible then
        Draw.pushShader("GonerPalette", {
            shadow = {0.13, 0.13, 0.16},
            mid = {0.53, 0.53, 0.60},
            light = {0.84, 0.84, 0.90},
            amount = 1,
            steps = 4,
        })
    end
    super.draw(self)
    if self.bust.visible then
        Draw.popShader()
    end

    if self.state ~= "PARTY" then
        self:drawChar()
        self:drawPowerPanel()
    end

    self:drawPopup()

    love.graphics.setStencilTest()
end

function DarkPowerMenu:drawPopup()
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

function DarkPowerMenu:drawSectionHeader(text, y, left, right)
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

function DarkPowerMenu:drawChar()
    local party = self.party:getSelected()
    local center_x = SCREEN_WIDTH / 2 - self.x

    Draw.setColor(PALETTE["world_text"], self.alpha)
    local name_width = self.font:getWidth(party:getName())
    love.graphics.print(party:getName(), center_x - (name_width / 2), -28)

    Draw.setColor(1, 1, 1, self.alpha)
    Draw.draw(self.lv_sprite, -self.x, 10 - self.y)
    love.graphics.setFont(Game.world.menu.small_font)
    love.graphics.print(party:getLevel(), SCREEN_WIDTH / 2.6, 2)

    local class_name = self:getClassText()
    if class_name ~= "" then
        love.graphics.setFont(self.mono_font)
        Draw.setColor(PALETTE["world_gray"], self.alpha)
        local class_width = self.mono_font:getWidth(class_name)
        love.graphics.print(class_name, center_x - (class_width / 2), 18)
    end

    love.graphics.setFont(self.font)
end

function DarkPowerMenu:drawPowerPanel()
    self:drawBust()
    self:drawClassText()
    if self.state == "OVERVIEW" and self.overview_page == 2 then
        self:drawCharacterStatistics()
    else
        self:drawStatRows()
        self:drawCustomPowerStats()
    end
    if self.state == "OVERVIEW" then
        self:drawOverviewPageIndicator()
    end
end

function DarkPowerMenu:drawBust()
    local party = self.party:getSelected()

    if self.bust_available then
        return
    end

    local icon = party and Assets.getTexture(party:getMenuIcon()) or nil
    if icon then
        Draw.setColor(0.72, 0.72, 0.78, self.alpha)
        Draw.draw(icon, 96, 104, 0, 4, 4)
    end
end

function DarkPowerMenu:drawClassText()
    local _, description = self:getClassText()

    Draw.setColor(PALETTE["world_gray"], self.alpha)
    love.graphics.setFont(self.earthbound_font)

    local _, lines = self.earthbound_font:getWrap(description, 120)
    for i, line in ipairs(lines) do
        love.graphics.print(line, 116, 44 + ((i - 1) * 18))
        if i >= 3 then break end
    end

    love.graphics.setFont(self.font)
end

function DarkPowerMenu:drawStatRows()
    local party = self.party:getSelected()
    local icon_x = 264
    local text_x = 278
    local value_x = 360
    local y = 74
    local row_spacing = 26
    local stats = party:getStats(false)

    self:drawSectionHeader("STATS", 52, 246, 390)
    love.graphics.setFont(self.earthbound_font)

    for i, row in ipairs(self.stat_rows) do
        local row_y = y + ((i - 1) * row_spacing)
        local pending = self:getPendingStatAllocation(row.id)
        local selected = (self.state == "STATS" or self.state == "CONFIRM") and self.selected_stat == i
        local color = selected and PALETTE["world_text_hover"] or PALETTE["world_text"]

        Draw.setColor(color, self.alpha)
        if selected then
            local mult = math.floor(math.sin(self.selection_siner)/2+1)
            Draw.draw(self.heart_sprite, icon_x - (12 + 6 * mult), row_y + 2)
        end
        if self.stat_icons[row.id] then
            Draw.draw(self.stat_icons[row.id], icon_x, row_y + 1, 0, 1, 1)
        end
        love.graphics.print(row.label .. ":", text_x, row_y)

        local value = stats[row.id] or party:getStat(row.id, 0)
        if pending > 0 then
            Draw.setColor(PALETTE["world_text_selected"], self.alpha)
            local text = value .. " +" .. pending
            love.graphics.print(text, value_x - self.earthbound_font:getWidth(text), row_y)
        else
            Draw.setColor(color, self.alpha)
            local text = tostring(value)
            love.graphics.print(text, value_x - self.earthbound_font:getWidth(text), row_y)
        end

    end

    --love.graphics.setFont(self.mono_font)
    if self:getAvailableStatPoints() > 0 then
        Draw.setColor(PALETTE["world_text_hover"], self.alpha)
    else
        Draw.setColor(PALETTE["world_gray"], self.alpha)
    end

    local addon = (self:getTotalPendingStatAllocation() > 0) and (" (-" .. self:getTotalPendingStatAllocation() .. ")") or ""
    local points = " : " .. self:getAvailableStatPoints() .. addon
    local points_y = y + (#self.stat_rows * row_spacing) - 8
    Draw.draw(self.stat_icons["gift"], value_x - self.earthbound_font:getWidth(points) - 10, points_y + 1, 0, 1, 1)
    love.graphics.print(points, value_x - self.earthbound_font:getWidth(points), points_y)
    if self.state == "STATS" then
        local row = self:getCurrentStatRow()
        local row_y = y + ((self.selected_stat - 1) * row_spacing)
        self:drawStatDescription(row, text_x, row_y + 16)
    end
    love.graphics.setFont(self.font)
end

function DarkPowerMenu:drawStatDescription(row, x, y)
    if not row.description then
        return
    end

    love.graphics.setFont(self.earthbound_font)

    local width = self.earthbound_font:getWidth(row.description)
    Draw.setColor(0, 0, 0, 0.72 * self.alpha)
    love.graphics.rectangle("fill", x - 4, y - 4, width + 8, 13)

    Draw.setColor(PALETTE["world_gray"], self.alpha)
    love.graphics.print(row.description, x, y-3)
end

function DarkPowerMenu:getCharacterFlagName(stat)
    local character = self:getSelectedCharacterId()
    if stat.flag:find("%%s") then
        return string.format(stat.flag, character)
    end
    return stat.flag
end

function DarkPowerMenu:getSelectedCharacterId()
    local party = self.party:getSelected()
    return party and (party.id or string.lower(party.name or "")) or ""
end

function DarkPowerMenu:getCharacterStatisticValue(stat)
    return Game:getFlag(self:getCharacterFlagName(stat), 0)
end

function DarkPowerMenu:drawCharacterStatistics()
    local x = 212
    local y = 48
    local value_x = 344

    self:drawSectionHeader("RECORD", 52, 208, 380)
    love.graphics.setFont(self.earthbound_font)

    local row_y = y + 14
    for _, category in ipairs(self.character_statistics) do
        Draw.setColor(PALETTE["world_header"] or PALETTE["world_text"], self.alpha)
        love.graphics.print(category.name, x, row_y)
        row_y = row_y + 14

        for _, stat in ipairs(category.stats) do
            if self:shouldDrawCharacterStatistic(stat) then
                self:drawCharacterStatisticRow(stat, x + 20, row_y, value_x)
                row_y = row_y + 13
            end
        end

        row_y = row_y + 4
    end

    love.graphics.setFont(self.font)
end

function DarkPowerMenu:shouldDrawCharacterStatistic(stat)
    if stat.evan_only and self:getSelectedCharacterId() ~= "evan" then
        return false
    end
    if stat.glitch and self:getCharacterStatisticValue(stat) <= 0 then
        return false
    end
    return true
end

function DarkPowerMenu:drawCharacterStatisticRow(stat, x, y, value_x)
    local value = tostring(self:getCharacterStatisticValue(stat))
    local icon = self.stat_icons[stat.icon]

    if stat.glitch then
        self:drawGlitchedStatisticRow(stat.label, value, x, y, value_x, icon)
        return
    end

    Draw.setColor(PALETTE["world_text"], self.alpha)
    if icon then
        Draw.draw(icon, x - 12, y + 1, 0, 1, 1)
    end
    love.graphics.print(stat.label, x, y)
    love.graphics.print(value, value_x - self.earthbound_font:getWidth(value), y)
end

function DarkPowerMenu:drawGlitchedStatisticRow(label, value, x, y, value_x, icon)
    local t = Kristal.getTime()
    local glitching = (math.floor(t * 7) % 5 == 0)
    local jitter_x = glitching and Utils.random(-2, 2) or 0
    local jitter_y = glitching and Utils.random(-1, 1) or 0

    love.graphics.setFont(self.wingdings_font)
    Draw.setColor(0.28, 0.1, 0.1, 0.45 * self.alpha)
    for i = 1, #label do
        love.graphics.print(string.sub(label, i, i), x + ((i - 1) * 6), y + 1)
    end

    love.graphics.setFont(self.earthbound_font)
    if icon then
        Draw.setColor(1, 1, 1, self.alpha)
        Draw.draw(icon, x - 12 + jitter_x, y + 1 + jitter_y, 0, 1, 1)
    end
    if glitching then
        Draw.setColor(0.8, 0.1, 0.1, 0.75 * self.alpha)
        love.graphics.print(label, x + jitter_x - 1, y + jitter_y)
        love.graphics.print(value, value_x - self.earthbound_font:getWidth(value) + jitter_x - 1, y + jitter_y)
        Draw.setColor(0.25, 0.7, 0.8, 0.55 * self.alpha)
        love.graphics.print(label, x + jitter_x + 1, y - jitter_y)
        love.graphics.print(value, value_x - self.earthbound_font:getWidth(value) + jitter_x + 1, y - jitter_y)
    end

    Draw.setColor(PALETTE["world_text"], self.alpha)
    love.graphics.print(label, x + jitter_x, y + jitter_y)
    love.graphics.print(value, value_x - self.earthbound_font:getWidth(value) + jitter_x, y + jitter_y)
end

function DarkPowerMenu:drawOverviewPageIndicator()
    local center_x = (SCREEN_WIDTH / 2) - self.x
    local y = 250
    local text = self.overview_page .. "/" .. self.max_overview_pages
    local sine_off = math.sin((Kristal.getTime() * 30) / 12) * 3

    love.graphics.setFont(self.small_font)
    Draw.setColor(PALETTE["world_text"], self.alpha)
    love.graphics.print(text, center_x - (self.small_font:getWidth(text) / 2), y)

    Draw.setColor(1, 1, 1, self.alpha)
    if self.overview_page > 1 then
        Draw.draw(self.left_arrow_sprite, center_x - 35 - sine_off, y + 2)
    end
    if self.overview_page < self.max_overview_pages then
        Draw.draw(self.right_arrow_sprite, center_x + 24 + sine_off, y + 2)
    end

    love.graphics.setFont(self.font)
end

function DarkPowerMenu:drawCustomPowerStats()
    local party = self.party:getSelected()
    local x = 246
    local y = 214

    self:drawSectionHeader("TRAITS", 198, 220, 390)

    for i = 1, 3 do
        local row_y = y + ((i - 1) * 22)
        love.graphics.setFont(self.earthbound_font)
        Draw.setColor(PALETTE["world_text"], self.alpha)
        love.graphics.push()
        if not party:drawPowerStat(i, x, row_y, self) then
            Draw.setColor(PALETTE["world_dark_gray"], self.alpha)
            love.graphics.print("???", x, row_y)
        end
        love.graphics.pop()
    end
end

return DarkPowerMenu
