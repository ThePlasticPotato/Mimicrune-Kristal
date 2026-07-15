---@class DarkEquipMenu : Object
---@overload fun(...) : DarkEquipMenu
local DarkEquipMenu, super = Class(Object)

---@enum EquipType
---| "weapons"
---| "armors"
---| "trinkets"
EquipType = {"weapons", "armors", "trinkets"}

function DarkEquipMenu:init()
    super.init(self, 82, 112, 477, 277)

    self.draw_children_below = 0

    self.font = Assets.getFont("main")
    self.small_font = Assets.getFont("small")
    self.earthbound_font = Assets.getFont("eb")
    self.lv_sprite = Assets.getTexture("ui/menu/caption_lv")

    self.ui_move = Assets.newSound("ui_move_panel")
    self.ui_select = Assets.newSound("ui_select_panel")
    self.ui_cant_select = Assets.newSound("ui_error_panel")
    self.ui_cancel_small = Assets.newSound("ui_cancel_small_camera")

    self.heart_sprite = Assets.getTexture("player/heart")
    self.arrow_sprite = Assets.getTexture("ui/flat_arrow_down")
    self.arrow_sprite_next = Assets.getTexture("ui/flat_arrow_right")

    self.caption_sprites = {
        ["char"] = Assets.getTexture("ui/menu/caption_char"),
        ["equipped"] = Assets.getTexture("ui/menu/caption_equipped"),
        ["stats"] = Assets.getTexture("ui/menu/caption_stats"),
        ["weapons"] = Assets.getTexture("ui/menu/caption_weapons"),
        ["armors"] = Assets.getTexture("ui/menu/caption_armors"),
    }

    self.stat_icons = {
        ["health"] = Assets.getTexture("ui/menu/icon/health"),
        ["attack"] = Assets.getTexture("ui/menu/icon/sword"),
        ["defense"] = Assets.getTexture("ui/menu/icon/armor"),
        ["magic"] = Assets.getTexture("ui/menu/icon/magic"),
    }

    self.armor_icons = {
        Assets.getTexture("ui/menu/equip/armor_1"),
        Assets.getTexture("ui/menu/equip/armor_2"),
    }

    self.displayed_description = nil

    self.left_arrow_sprite = Assets.getTexture("ui/page_arrow_left")
    self.right_arrow_sprite = Assets.getTexture("ui/page_arrow_right")

    self.popup_sprite = Assets.getTexture("ui/menu/popup")
    self.popup_text = nil

    -- self.bg = UIBox(0, 0, self.width, self.height)
    -- self.bg.layer = -1
    -- self.bg.debug_select = false
    -- self:addChild(self.bg)

    self.party = DarkMenuPartySelect(8, 48)
    self.party.focused = true
    self:addChild(self.party)

    self.type_sprites = {
        [1] = Assets.getTexture("ui/menu/equip_weapons"),
        [2] = Assets.getTexture("ui/menu/equip_armor"),
        [3] = Assets.getTexture("ui/menu/equip_trinkets")
    }

    self.type_scales = {
        [1] = 0.0,
        [2] = 0.0,
        [3] = 0.0
    }

    self.slot_scales = {
        [1] = 0.0,
        [2] = 0.0,
        [3] = 0.0
    }

    -- PARTY, TYPE, SLOTS, ITEMS
    self.state = "PARTY"

    self.selected_slot = 1

    self.selected_type = 2

    self.selected_item = {
        ["weapons"] = 1,
        ["armors"] = 1,
        ["trinkets"] = 1
    }
    self.item_scroll = {
        ["weapons"] = 1,
        ["armors"] = 1,
        ["trinkets"] = 1
    }

    self.smooth_scroll = 1

    Assets.stopAndPlaySound("item_trash_warning", 0.6)
end

function DarkEquipMenu:getCurrentItemType()
    return EquipType[self.selected_type]
end

function DarkEquipMenu:getCurrentStorage()
    return Game.inventory:getStorage(self:getCurrentItemType())
end

function DarkEquipMenu:getSelectedItem()
    local type = self:getCurrentItemType()
    return Game.inventory:getItem(type, self.selected_item[type])
end

function DarkEquipMenu:getMaxItems()
    return self:getCurrentStorage().max
end

function DarkEquipMenu:canEquipSelected()
    local item = self:getSelectedItem()
    local character = self.party:getSelected()

    if self:getCurrentItemType() == "weapons" then
        return character:canEquip(item, "weapon", self.selected_slot)
    elseif self:getCurrentItemType() == "armors" then
        return character:canEquip(item, "armor", self.selected_slot)
    else
        return character:canEquip(item, "trinket", self.selected_slot)
    end
end

function DarkEquipMenu:getEquipPreview()
    local party = self.party:getSelected()
    local equipped = {}
    local item = self:getSelectedItem()
    if self:getCurrentItemType() == "weapons" then
        equipped[1] = item
    else
        equipped[1] = party.equipped.weapon
    end
    if self:getCurrentItemType() == "armors" then
        equipped[2] = item
    else
        equipped[2] = party.equipped.armor[1]
    end
    for i = 1, 3 do
        if self:getCurrentItemType() == "trinkets" then
            equipped[i + 2] = item
        else
            equipped[i + 2] = party.equipped.trinket[i]
        end
    end
    return equipped
end

function DarkEquipMenu:getStatsPreview()
    local party = self.party:getSelected()
    local current_stats = party:getStats()
    if self.state == "ITEMS" and self:canEquipSelected() then
        local preview_stats = TableUtils.copy(party.stats)
        local equipment = self:getEquipPreview()
        for i = 1, 3 do
            if equipment[i] then
                for stat, amount in pairs(equipment[i]:getStatBonuses()) do
                    if preview_stats[stat] then
                        preview_stats[stat] = preview_stats[stat] + amount
                    end
                end
            end
        end
        return preview_stats, current_stats
    else
        return current_stats, current_stats
    end
end

function DarkEquipMenu:getAbilityPreview()
    local party = self.party:getSelected()
    local current_abilities = {}
    local weapon = party.equipped.weapon
    if weapon and weapon:getBonusName() then
        current_abilities[1] = { name = weapon:getBonusName(), icon = weapon:getBonusIcon(), color = weapon:getBonusColor() }
    end
    for i = 1, 2 do
        local armor = party.equipped.armor[i]
        if armor and armor:getBonusName() then
            current_abilities[i + 1] = { name = armor:getBonusName(), icon = armor:getBonusIcon(), color = armor:getBonusColor() }
        end
    end
    for i = 1, 3 do
        local trinket = party.equipped.trinket[i]
        if trinket and trinket:getBonusName() then
            current_abilities[i + 3] = { name = trinket:getBonusName(), icon = trinket:getBonusIcon(), color = trinket.bonus_color }
        end
    end
    if self.state == "ITEMS" and self:canEquipSelected() then
        local preview_abilities = {}
        local equipment = self:getEquipPreview()
        for i = 1, 6 do
            if equipment[i] and equipment[i]:getBonusName() then
                preview_abilities[i] = {
                    name = equipment[i]:getBonusName(),
                    icon = equipment[i]:getBonusIcon(),
                    color = equipment[i]:getBonusColor()
                }
            end
        end
        return preview_abilities, current_abilities
    else
        return current_abilities, current_abilities
    end
end

function DarkEquipMenu:react()
    local item, party = self:getSelectedItem(), self.party:getSelected()

    for index, chara in ipairs(Game.party) do
        local reaction = chara:getReaction(item, party)
        if reaction then
            Game.world:partyReact(chara, reaction, 3)
        end
    end
end

function DarkEquipMenu:updateDescription()
    if self.state == "PARTY" or self.state == "TYPE" then
        self.displayed_description = nil
        --self.displayed_image = nil
    elseif self.state == "SLOTS" then
        local party = self.party:getSelected()
        local item
        if self:getCurrentItemType() == "weapons" then
            item = party:getWeapon()
        elseif self:getCurrentItemType() == "armors" then
            item = party:getArmor(self.selected_slot)
        else
            item = party:getTrinket(self.selected_slot)
        end
        self.displayed_description = item and item:getDescription() or nil
        --self.displayed_image = item and item:getMenuImage() or nil
    elseif self.state == "ITEMS" then
        local item = self:getSelectedItem()
        self.displayed_description = item and item:getDescription() or nil
        --self.displayed_image = item and item:getMenuImage() or nil
    end
end

function DarkEquipMenu:onRemove(parent)
    super.onRemove(self, parent)
    Game.world.menu:updateSelectedBoxes()
end

function DarkEquipMenu:update()
    self.alpha = 1 - Game.world.menu.flicker_dur
    if self.state == "PARTY" then
        Game.world.menu:resetOverrides()
        self.popup_text = "PLEASE SELECT\nA VALID USER"
        if Input.pressed("cancel") then
            self.ui_cancel_small:stop()
            self.ui_cancel_small:play()
            self.popup_text = nil
            Game.world.menu:closeBox()
            return
        elseif Input.pressed("confirm") then
            self.state = "TYPE"

            self.party.focused = false
            self.popup_text = nil

            Assets.stopAndPlaySound("item_click")

            self.selected_slot = 1
            self:updateDescription()
        end
    elseif self.state == "TYPE" then
        for i, _ in ipairs(self.type_scales) do
            if (self.selected_type == i) then
                self.type_scales[i] = MathUtils.approach(self.type_scales[i], 1.0, DTMULT / 4)
            else
                self.type_scales[i] = MathUtils.approach(self.type_scales[i], 0.0, DTMULT / 2)
            end
        end

        Game.world.menu:resetOverrides()
        if Input.pressed("cancel") then
            self.state = "PARTY"

            Assets.stopAndPlaySound("item_cancel")

            self.party.focused = true
            self:updateDescription()
            return
        elseif Input.pressed("confirm") then
            self.state = "SLOTS"

            Assets.stopAndPlaySound("item_click")

            self:updateDescription()
            return
        end
        local old_type = self.selected_type
        if Input.pressed("right") then
            self.selected_type = self.selected_type + 1
        end
        if Input.pressed("left") then
            self.selected_type = self.selected_type - 1
        end
        
        self.selected_type = MathUtils.wrap(self.selected_type, 1, 4)

        if (old_type ~= self.selected_type) then
            self.ui_move:stop()
            self.ui_move:play()
            self:updateDescription()
        end
    elseif self.state == "SLOTS" then
        Game.world.menu:resetOverrides()
        if Input.pressed("cancel") then
            self.state = "TYPE"

            Assets.stopAndPlaySound("item_cancel")

            --self.party.focused = true
            self:updateDescription()
            return
        elseif Input.pressed("confirm") then
            self.state = "ITEMS"

            Assets.stopAndPlaySound("item_click")

            self:updateDescription()
            return
        end

        for i, _ in ipairs(self.slot_scales) do
            if (self.selected_slot == i) then
                self.slot_scales[i] = MathUtils.approach(self.slot_scales[i], 1.0, DTMULT / 4)
            else
                self.slot_scales[i] = MathUtils.approach(self.slot_scales[i], 0.0, DTMULT / 2)
            end
        end

        local old_selected = self.selected_slot
        if Input.pressed("left") then
            self.selected_slot = self.selected_slot - 1
        end
        if Input.pressed("right") then
            self.selected_slot = self.selected_slot + 1
        end
        if self:getCurrentItemType() ~= "trinkets" then
            self.selected_slot = 1
        end

        self.selected_slot = MathUtils.wrap(self.selected_slot, 1, 4)

        if old_selected ~= self.selected_slot then
            self.ui_move:stop()
            self.ui_move:play()
            self:updateDescription()
        end
    elseif self.state == "ITEMS" then
        if Input.pressed("cancel") then
            self.state = "SLOTS"

            Assets.stopAndPlaySound("item_cancel")

            self:updateDescription()
            return
        end
        local type = self:getCurrentItemType()
        self.smooth_scroll = MathUtils.approach(self.smooth_scroll, self.item_scroll[type], DTMULT / (4 / math.max(math.abs(self.smooth_scroll - self.item_scroll[type]), 0.1)))
        local max_items = #self:getCurrentStorage()
        local old_selected = self.selected_item[type]
        if Input.pressed("left", true) then
            self.selected_item[type] = self.selected_item[type] - 1
        end
        if Input.pressed("right", true) then
            self.selected_item[type] = self.selected_item[type] + 1
        end
        self.selected_item[type] = MathUtils.clamp(self.selected_item[type], 0, max_items)
        if self.selected_item[type] ~= old_selected then
            local min_scroll = math.max(1, self.selected_item[type] - 5)
            local max_scroll = math.min(math.max(1, max_items - 5), self.selected_item[type])
            self.item_scroll[type] = self.selected_item[type]

            self.ui_move:stop()
            self.ui_move:play()

            self:updateDescription()
            local item = self:getSelectedItem()

            local function statWithoutCurrent(stat)
                local base = self.party:getSelected():getBaseStat(stat)
                local equip_bonus = self.party:getSelected():getEquipmentBonus(stat)
                local current_bonus = 0
                if (self:getCurrentItemType() == "weapons") then
                    current_bonus = self.party:getSelected():getWeapon() and self.party:getSelected():getWeapon():getStatBonus(stat) or 0
                elseif (self:getCurrentItemType() == "armors") then
                    current_bonus = self.party:getSelected():getArmor(1) and self.party:getSelected():getArmor(1):getStatBonus(stat) or 0
                else
                    current_bonus = self.party:getSelected():getTrinket(self.selected_slot) and self.party:getSelected():getTrinket(self.selected_slot):getStatBonus(stat) or 0
                end
                return base + equip_bonus - current_bonus
            end

            Game.world.menu:setOverrides(statWithoutCurrent("health") + (item and item:getStatBonus("health") or 0), statWithoutCurrent("attack") + (item and item:getStatBonus("attack") or 0), statWithoutCurrent("magic") + (item and item:getStatBonus("magic") or 0), statWithoutCurrent("defense") + (item and item:getStatBonus("defense") or 0))
        end
        if Input.pressed("confirm") then
            self:react()
            local item, party = self:getSelectedItem(), self.party:getSelected()
            if not self:canEquipSelected() then
                Assets.playSound("item_trash_warning")
            else
                local swap_with = (self.selected_type == 1) and party:getWeapon() or
                    ((self.selected_type == 2) and party:getArmor(self.selected_slot)) or
                        party:getTrinket(self.selected_slot)

                local can_continue = true

                if item and (not item:onEquip(party, swap_with)) then can_continue = false end
                if swap_with and (not swap_with:onUnequip(party, item)) then can_continue = false end
                if (not party:onEquip(item, swap_with)) then can_continue = false end
                if (not party:onUnequip(swap_with, item)) then can_continue = false end

                -- If one of the functions returned false, don't continue

                local safe_slot = (self.selected_item[type] ~= 0) and self.selected_item[type] or nil
                
                if not safe_slot then
                    for i = 1, self:getMaxItems() do
                        if self:getCurrentStorage()[i] == nil then
                            safe_slot = i
                            break
                        end
                    end
                end
                if not safe_slot then can_continue = false end

                if (not can_continue) then
                    Assets.playSound("item_trash_warning")
                    return
                end

                Assets.playSound("item_use")

                if self.selected_type == 1 then
                    party:setWeapon(item)
                elseif self.selected_type == 2 then
                    party:setArmor(self.selected_slot, item)
                else
                    party:setTrinket(self.selected_slot, item)
                end

                Game.inventory:setItem(self:getCurrentStorage(), safe_slot, swap_with)

                self.state = "SLOTS"
                self:updateDescription()
                Game.world.menu:resetOverrides()
            end
        end
    end
    super.update(self)
end

function DarkEquipMenu:draw()
    love.graphics.setFont(self.font)

    -- Draw.setColor(PALETTE["world_border"])
    -- love.graphics.rectangle("fill", 188, -24, 6, 139)
    -- love.graphics.rectangle("fill", -24, 109, 58, 6)
    -- love.graphics.rectangle("fill", 130, 109, 160, 6)
    -- love.graphics.rectangle("fill", 422, 109, 79, 6)
    -- love.graphics.rectangle("fill", 241, 109, 6, 192)

    -- Draw.setColor(1, 1, 1, 1)
    -- Draw.draw(self.caption_sprites["char"], 36, -26, 0, 2, 2)
    -- Draw.draw(self.caption_sprites["equipped"], 294, -26, 0, 2, 2)
    -- Draw.draw(self.caption_sprites["stats"], 34, 104, 0, 2, 2)
    -- if self.selected_slot == 1 then
    --     Draw.draw(self.caption_sprites["weapons"], 290, 104, 0, 2, 2)
    -- else
    --     Draw.draw(self.caption_sprites["armors"], 290, 104, 0, 2, 2)
    -- end
    -- self:drawEquipped()
    -- self:drawItems()
    -- self:drawStats()

    
    Draw.setColor(1,1,1,1)
    love.graphics.stencil(function()
            love.graphics.circle("fill", SCREEN_WIDTH/2 - self.x, SCREEN_HEIGHT/2 - self.y, 162)
        end, "replace", 1)
    love.graphics.setStencilTest("greater", 0)
    if (self.state ~= "PARTY") and (self.state ~= "ITEMS") then
        self:drawStats()
        self:drawChar()
        if (self.state == "TYPE") then self:drawTypes() end
        if (self.state == "SLOTS") then self:drawSlots() end
    end
    if (self.state == "ITEMS") then
        self:drawItems()
    end
    
    self:drawPopup()

    love.graphics.setStencilTest()

    super.draw(self)
end

function DarkEquipMenu:drawPopup()
    if (self.popup_text) then
        Draw.setColor(1,1,1,self.alpha)
        Draw.draw(self.popup_sprite, SCREEN_WIDTH / 3.95, 86)
        Draw.setColor(0,0,0,self.alpha)
        love.graphics.setFont(self.earthbound_font)
        local _, wrapped = self.earthbound_font:getWrap(self.popup_text, 150)
        local base_y = 96
        if (#wrapped < 4) then
            base_y = base_y + (16 * (3.5 - #wrapped))
        end
        for i, textline in ipairs(wrapped) do
            love.graphics.print(textline, (SCREEN_WIDTH/4) + 10,  base_y + (16 * (i-1)))
            if (i > 4) then break end
        end
        love.graphics.setFont(self.font)
        Draw.setColor(1,1,1,1)
    end
end

function DarkEquipMenu:drawTypes()
    Draw.setColor(1,1,1,self.alpha)
    love.graphics.setLineWidth(2)
    love.graphics.setFont(self.small_font)
    local width = self.small_font:getWidth(self:getCurrentItemType():upper())
    love.graphics.line(88, 104, 92, 104)
    love.graphics.line(94, 104, 238 - width*3/4, 104)
    love.graphics.line(238 + width*3/4, 104, 382, 104)
    love.graphics.line(384, 104, 388, 104)
    love.graphics.print(self:getCurrentItemType():upper(), 45 + 388/2 - width/2, 98)
    for i = 1, 3 do
        Draw.setColor(ColorUtils.mergeColor(PALETTE["world_gray"], PALETTE["world_text_hover"], self.type_scales[i]))
        Draw.draw(self.type_sprites[i], 140 + (i-1) * 100, 180, 0, (self.type_scales[i] / 4) + 0.75, (self.type_scales[i] / 4) + 0.75, self.type_sprites[i]:getPixelWidth()/2, self.type_sprites[i]:getPixelHeight()/2)
    end
    love.graphics.setFont(self.font)
end

function DarkEquipMenu:drawMenuItem(x, y, item, scale, color, text)
    Draw.setColor(color, self.alpha)
    love.graphics.setLineWidth(2)
    
    if (true) then
        Draw.setColor(0,0,0,(self.alpha - 0.25) * scale)
        Draw.rectangle("fill", x-4 + (99/2.5) * (1 - scale), y-4 + (99/2.5) * (1 - scale),99 * scale, 99 * scale)
        Draw.setColor(color, self.alpha)
        Draw.rectangle("line", x-4 + (99/2.5) * (1 - scale), y-4 + (99/2.5) * (1 - scale),99 * scale, 99 * scale)
    end
    Draw.setColor(color, self.alpha)
    Draw.draw(item and (Assets.getTexture("items/" .. item:getMenuImage()) or Assets.getTexture("items/unknown")) or Assets.getTexture("items/empty"), x+((91/2)*scale), y+((91/2)*scale), 0, 1*scale, 1*scale, ((91/2)*scale), ((91/2)*scale))
    if not item then
        Draw.setColor(PALETTE["world_text_unusable"], self.alpha)
    end
    if (text) then
        love.graphics.setFont(self.small_font)
        local width = self.small_font:getWidth(item and item:getName() or "(Empty.)")
        love.graphics.print(item and item:getName() or "(Empty.)", (x + 91/2) - width/2, y + 108)
    end
    love.graphics.setFont(self.font)
    Draw.setColor(1,1,1,self.alpha)
end

function DarkEquipMenu:drawSlots()
    Draw.setColor(1,1,1,self.alpha)
    love.graphics.setLineWidth(2)
    love.graphics.line(88, 104, 92, 104)
    love.graphics.line(94, 104, 382, 104)
    love.graphics.line(384, 104, 388, 104)

    ---@type [Item|nil, Item|nil, Item|nil]
    local items = {}

    local party = self.party:getSelected()

    if (party) then
        items = (self.selected_type ~= 1) and party.equipped[StringUtils.sub(self:getCurrentItemType(), 1, #self:getCurrentItemType() - 1)] or {party.equipped.weapon}
    end

    local slots = (self.selected_type == 3) and 3 or 1
    
    if (slots > 1) then
        local center_x = 194
        local center_y = 118

        local boxes = {
            [1] = {center_x - 80, center_y},
            [2] = {center_x, center_y},
            [3] = {center_x + 80, center_y}
        }

        for i = 1, slots do
            local scale = self.slot_scales[i]
            local selected_x = MathUtils.lerp(boxes[i][1], center_x, 0.5)
            Draw.setColor(1,1,1,self.alpha)
            if i ~= self.selected_slot then
                Draw.setColor(PALETTE["world_gray"], self.alpha)
                boxes[i][1] = Utils.ease(selected_x, boxes[i][1], 1 - scale, "out-cubic")
            else
                boxes[i][1] = Utils.ease(boxes[i][1], selected_x, scale, "out-cubic")
            end
            --Draw.rectangle("line", boxes[i][1]-4 ,boxes[i][2]-4 , 99, 99)
            if (i ~= self.selected_slot) then
                self:drawMenuItem(boxes[i][1], boxes[i][2], items[i], scale/4 + 0.75, ColorUtils.mergeColor(PALETTE["world_gray"], COLORS.white, self.slot_scales[i]))
            end
        end

        self:drawMenuItem(boxes[self.selected_slot][1], boxes[self.selected_slot][2], items[self.selected_slot], 1, ColorUtils.mergeColor(PALETTE["world_gray"], COLORS.white, self.slot_scales[self.selected_slot]), true)
        Draw.draw(self.arrow_sprite, boxes[self.selected_slot][1] + 46 - self.arrow_sprite:getWidth(), 118 - 8, 0, 2, 2)
    else
        self:drawMenuItem(194, 118, items[1], 1, COLORS.white, true)
        Draw.draw(self.arrow_sprite, 192 + 48 - self.arrow_sprite:getWidth(), 118 - 8, 0, 2, 2)
    end
end

function DarkEquipMenu:drawChar()
    local party = self.party:getSelected()
    Draw.setColor(1, 1, 1, self.alpha)
    local width = self.font:getWidth(party:getName())
    love.graphics.print(party:getName(), SCREEN_WIDTH / 2.67 - width/2, -28)
    Draw.draw(self.lv_sprite, -self.x, 10 -self.y)
    love.graphics.setFont(Game.world.menu.small_font)
    love.graphics.print(party:getLevel(), SCREEN_WIDTH / 2.6, 2)
    love.graphics.setFont(self.font)
end

function DarkEquipMenu:drawEquipped()
    local party = self.party:getSelected()
    Draw.setColor(1, 1, 1, 1)

    if self.state ~= "SLOTS" or self.selected_slot ~= 1 then
        local weapon_icon = Assets.getTexture(party:getWeaponIcon())
        if weapon_icon then
            Draw.draw(weapon_icon, 220, -4, 0, 2, 2)
        end
    end
    if self.state ~= "SLOTS" or self.selected_slot ~= 2 then Draw.draw(self.armor_icons[1], 220, 30, 0, 2, 2) end
    if self.state ~= "SLOTS" or self.selected_slot ~= 3 then Draw.draw(self.armor_icons[2], 220, 60, 0, 2, 2) end

    if self.state == "SLOTS" then
        --Draw.setColor(Game:getSoulColor())
        --Draw.draw(self.heart_sprite, 226, 10 + ((self.selected_slot - 1) * 30))
    end

    for i = 1, 3 do
        self:drawEquippedItem(i, 261, 6 + ((i - 1) * 30))
    end
end

function DarkEquipMenu:drawEquippedItem(index, x, y)
    local party = self.party:getSelected()
    local item
    if index == 1 then
        item = party:getWeapon()
    else
        item = party:getArmor(index - 1)
    end
    if item then
        Draw.setColor(1, 1, 1)
        if item:getEquipIcon() and Assets.getTexture(item:getEquipIcon()) then
            Draw.draw(Assets.getTexture(item:getEquipIcon()), x, y, 0, 2, 2)
        end
        love.graphics.print(item:getName(), x + 22, y - 6)
    else
        Draw.setColor(PALETTE["world_dark_gray"])
        love.graphics.print("(Nothing)", x + 22, y - 6)
    end
end

function DarkEquipMenu:drawItems()

    local type = self:getCurrentItemType()
    local party = self.party:getSelected()
    local items = Game.inventory:getStorage(type)

    local x, y = 194, 0

    local scroll = self.item_scroll[type]

    if #items > 7 then
        Draw.setColor(1, 1, 1, self.alpha)
        local sine_off = math.sin((Kristal.getTime() * 30) / 12) * 3
        if scroll < #items then
            Draw.draw(self.right_arrow_sprite, x + 50 + sine_off, y + 250)
        end
        if scroll > 0 then
            Draw.draw(self.left_arrow_sprite, x + 20 - sine_off, y + 250)
        end
    end

    for i = math.max(0, scroll-2), math.min(#items, scroll + 2) do
        local item = items[i]
        local offset = i - self.smooth_scroll

        Draw.setColor(1,1,1,self.alpha)
        local width = self.small_font:getWidth(item and item:getName() or "(Unequip)")
        if (self.selected_item[self:getCurrentItemType()] == i) then
            love.graphics.setLineWidth(2)
            love.graphics.line(88, 112, 92, 112)
            love.graphics.line(94, 112, 238 - width*3/4, 112)
            love.graphics.line(238 + width*3/4, 112, 382, 112)
            love.graphics.line(384, 112, 388, 112)
        end

        if item then
            local usable = false
            if self.selected_type == 1 then
                usable = party:canEquip(item, "weapon", self.selected_slot)
            elseif self.selected_type == 2 then
                usable = party:canEquip(item, "armor", self.selected_slot)
            else
                usable = party:canEquip(item, "trinket", self.selected_slot)
            end
            if usable then
                Draw.setColor(1, 1, 1, self.alpha)
            else
                Draw.setColor(PALETTE["world_gray"], self.alpha)
            end
            if item:getEquipIcon() and Assets.getTexture(item:getEquipIcon()) then
                --Draw.draw(Assets.getTexture(item.icon), x, y + (offset * 27), 0, 2, 2)
                self:drawMenuItem(x + 120 * offset, y, items[i], (self.selected_item[self:getCurrentItemType()] == i) and (1 - (math.abs(self.smooth_scroll - scroll)/4)) or 0.75, ColorUtils.mergeColor(PALETTE["world_gray"], COLORS.white, (self.selected_item[self:getCurrentItemType()] == i) and 1 or 0), false)
                --Draw.draw(self.arrow_sprite, boxes[self.selected_slot][1] + 46 - self.arrow_sprite:getWidth(), 118 - 8, 0, 2, 2)
            end
            love.graphics.setFont(self.small_font)
            if (self.selected_item[self:getCurrentItemType()] == i) then love.graphics.print(item:getName(), (x + 91/2) - width/2, y + 108) end
            love.graphics.setFont(self.font)
        else
            Draw.setColor(PALETTE["world_gray"], self.alpha)
            self:drawMenuItem(x + 120 * offset, y, nil, (self.selected_item[self:getCurrentItemType()] == i) and (1 - (math.abs(self.smooth_scroll - scroll)/4)) or 0.75, ColorUtils.mergeColor(PALETTE["world_gray"], COLORS.white, (self.selected_item[self:getCurrentItemType()] == i) and 1 or 0), false)
            love.graphics.setFont(self.small_font)
            if (self.selected_item[self:getCurrentItemType()] == i) then
                Draw.setColor(PALETTE["world_gray"], self.alpha)
                love.graphics.print("(Unequip)", (x + 91/2) - width/2, y + 108)
            end
            love.graphics.setFont(self.font)
        end
    end

    local current_item = self:getSelectedItem()
    if current_item then
        love.graphics.setFont(self.earthbound_font)
        local desc = current_item:getDescription()
        local _, lines = self.earthbound_font:getWrap(desc, 328)
        for i, line in ipairs(lines) do
            local width = self.earthbound_font:getWidth(line)
            love.graphics.print(line, 194 + 48 - (width/2), 108 + (i * 16))
        end
        
        love.graphics.setFont(self.earthbound_font)
        local i = 0
        for key, bonus in pairs(current_item:getStatBonuses()) do
            local y_offset = i * 16
            love.graphics.print(key:upper() .. " : " .. bonus, 214, 168 + y_offset)
            i = i + 1
        end

        love.graphics.setFont(self.font)

        local effect = current_item:getBonusName()
        if (effect and effect ~= "") then
            local y_offset = (2 + 1) * 16
            local width = self.font:getWidth(effect)
            love.graphics.print(effect, 258 - width/2, 168 + y_offset)

            local icon = current_item:getBonusIcon()
            local color = current_item.bonus_color
            if (icon) then
                Draw.setColor(color, self.alpha)
                Draw.draw(Assets.getTexture(icon), 164, 168 + y_offset + 6, 0, 2, 2)
            end
            Draw.setColor(1,1,1,self.alpha)
        end
        
        
    end

    -- if self.state == "ITEMS" then
    --     --Draw.setColor(Game:getSoulColor())
    --     --Draw.draw(self.heart_sprite, x - 20, y + 4 + ((self.selected_item[type] - scroll) * 27))

        
    --     if items.max <= 12 then
    --         Draw.setColor(1, 1, 1)
    --         for i = 1, items.max do
    --             local item = items[i]
    --             local percentage = (i - 1) / (items.max - 1)
    --             if self.selected_item[type] == i and item then
    --                 love.graphics.rectangle("fill", x + 188, y + 21 + percentage * 110, 10, 10)
    --             elseif self.selected_item[type] == i then
    --                 love.graphics.rectangle("fill", x + 189, y + 22 + percentage * 110, 8, 8)
    --             elseif item then
    --                 love.graphics.rectangle("fill", x + 191, y + 24 + percentage * 110, 4, 4)
    --             else
    --                 love.graphics.rectangle("fill", x + 192, y + 25 + percentage * 110, 2, 2)
    --             end
    --         end
    --     else
    --         Draw.setColor(0.25, 0.25, 0.25)
    --         love.graphics.rectangle("fill", x + 191, y + 24, 6, 119)
    --         local percent = (scroll - 1) / (items.max - 6)
    --         Draw.setColor(1, 1, 1)
    --         love.graphics.rectangle("fill", x + 191, y + 24 + math.floor(percent * (119 - 6)), 6, 6)
    --     end
    -- end
end

function DarkEquipMenu:drawStats()
    local party = self.party:getSelected()
    Draw.setColor(1, 1, 1, 1)
    -- Draw.draw(self.stat_icons["attack"], -8, 124, 0, 2, 2)
    -- Draw.draw(self.stat_icons["defense"], -8, 151, 0, 2, 2)
    -- Draw.draw(self.stat_icons["magic"], -8, 178, 0, 2, 2)
    -- love.graphics.print("Attack:", 18, 118)
    -- love.graphics.print("Defense:", 18, 145)
    -- love.graphics.print("Magic:", 18, 172)
    -- local stats, compare = self:getStatsPreview()
    -- self:drawStatPreview("attack", 148, 118, stats, compare, self:getCurrentItemType() == "weapons")
    -- self:drawStatPreview("defense", 148, 145, stats, compare, false)
    -- self:drawStatPreview("magic", 148, 172, stats, compare, false)

    local base_x = SCREEN_WIDTH / 5.45
    local base_y = -12
    local abilities, ability_comp = self:getAbilityPreview()
    for i = 1, 2 do
        self:drawAbilityPreview(i, base_x, base_y + (27 * i), abilities, ability_comp)
    end
    for i = 1, 2 do
        self:drawAbilityPreview(i + 2, base_x + 128, base_y + (27 * i), abilities, ability_comp)
    end
    self:drawAbilityPreview(5, base_x + 64, base_y + (27 * 3), abilities, ability_comp)
end

function DarkEquipMenu:drawStatPreview(stat, x, y, stats, compare, show_difference)
    local stat_num = stats[stat] or 0
    local comp_num = compare[stat] or 0
    if stat_num > comp_num then
        Draw.setColor(1, 1, 0)
    elseif stat_num < comp_num then
        Draw.setColor(1, 0, 0)
    else
        Draw.setColor(1, 1, 1)
    end
    local display = tostring(stat_num)
    if show_difference and stat_num ~= comp_num then
        if Game:getConfig("oldUIPositions") or stat_num < comp_num then
            display = display .. "(" .. (stat_num - comp_num) .. ")"
        else
            display = display .. "(+" .. (stat_num - comp_num) .. ")"
        end
    end
    love.graphics.print(display, x, y)
end

function DarkEquipMenu:drawAbilityPreview(index, x, y, abilities, compare)
    local name = abilities[index] and abilities[index].name or nil
    local comp_name = compare[index] and compare[index].name or nil
    if abilities[index] and abilities[index].icon then
        local texture = Assets.getTexture(abilities[index].icon)
        if texture then
            Draw.setColor(abilities[index].color, self.alpha)
            Draw.draw(texture, x, y + 2, 0, 2, 2)
        end
    end
    if name ~= comp_name then
        if name ~= nil then
            Draw.setColor(1, 1, 0, self.alpha)
        else
            Draw.setColor(1, 0, 0, self.alpha)
        end
    else
        if (name and self.state ~= "ITEMS") or (self.state == "ITEMS" and self.selected_slot == index and self:canEquipSelected()) then
            Draw.setColor(1, 1, 1, self.alpha)
        else
            Draw.setColor(0.25, 0.25, 0.25, self.alpha)
        end
    end
    love.graphics.print(name or "(N/A)", x + 26, y - 6)
end

return DarkEquipMenu
