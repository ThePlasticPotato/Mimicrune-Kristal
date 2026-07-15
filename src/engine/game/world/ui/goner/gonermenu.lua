---@class GonerMenu : Object
---@overload fun() : GonerMenu
local GonerMenu, super = Class(Object)

local EQUIP_TYPES = {
    {label = "WEAPON", storage = "weapons", slot_type = "weapon", slots = 1},
    {label = "ARMOR", storage = "armors", slot_type = "armor", slots = 1},
    {label = "TRINKET", storage = "trinkets", slot_type = "trinket", slots = 3},
}

local ITEM_STORAGES = {"items", "key_items"}

local function storageItems(storage_id)
    local result = {}
    local storage = Game.inventory:getStorage(storage_id)
    if not storage then return result end
    for index = 1, storage.max do
        if storage[index] then
            table.insert(result, {item = storage[index], storage = storage_id, index = index})
        end
    end
    return result
end

function GonerMenu:init()
    super.init(self, 0, 0, SCREEN_WIDTH, SCREEN_HEIGHT)

    self.layer = WORLD_LAYERS["ui"]
    self.parallax_x = 0
    self.parallax_y = 0

    self.font = Assets.getFont("eb")
    self.cursor = Assets.getTexture("player/heart")
    self.ui_move = Assets.newSound("ui_move_panel")
    self.ui_select = Assets.newSound("ui_select_panel")
    self.ui_cancel = Assets.newSound("ui_cancel_small_camera")
    self.ui_error = Assets.newSound("ui_error_panel")

    self.state = "MAIN"
    self.selected = MathUtils.clamp(Game.world.current_selecting or 1, 1, 5)
    self.page_selected = 1
    self.item_storage_index = 1
    self.open_item_storage = nil
    self.equip_stage = "TYPE"
    self.equip_type = 1
    self.equip_slot = 1
    self.equip_selections = {1, 1, 1}
    self.animate_out = false
    self.saved_can_open = nil

    self.options = {
        {id = "TALK", description = "OPEN A LOCAL COMMUNICATION CHANNEL."},
        {id = "ITEM", description = "ACCESS ITEMS AND KEY DATA."},
        {id = "EQUIP", description = "REASSIGN VESSEL EQUIPMENT."},
        {id = "POWER", description = "INSPECT VESSEL STATUS AND PROGRAMS."},
        {id = "CONFIG", description = "MODIFY INTERFACE PARAMETERS."},
    }

    self.arrow_up = Assets.getTexture("ui/page_arrow_up")
    self.arrow_down = Assets.getTexture("ui/page_arrow_down")
    self.arrow_left = Assets.getTexture("ui/page_arrow_left")
    self.arrow_right = Assets.getTexture("ui/page_arrow_right")
    self.empty_image = Assets.getTexture("items/empty")
    self.unknown_image = Assets.getTexture("items/unknown")

    self.command_box = UIBox(28, 38, 200, 394, "DEVICE")
    self.status_box = UIBox(250, 38, 362, 128, "DEVICE")
    self.content_box = UIBox(250, 188, 362, 244, "DEVICE")
    self:addChild(self.command_box)
    self:addChild(self.status_box)
    self:addChild(self.content_box)

    self.fade = self:addFX(AlphaFX(0))
    self:refreshPageEntries()

    self:crt({SCREEN_WIDTH, SCREEN_HEIGHT}, false, {
        vertJerkOpt = 0,
        vertMovementOpt = 0,
        bottomStaticOpt = 0.02,
        scanlinesOpt = 0.10,
        rgbOffsetOpt = 0.04,
        horzFuzzOpt = 0.03,
    })
end

function GonerMenu:isOptionEnabled(index)
    local id = self.options[index].id
    if id == "TALK" then
        return Game.world:hasTalkCutscene()
    elseif id == "ITEM" then
        return #storageItems("items") + #storageItems("key_items") > 0
    elseif id == "EQUIP" or id == "POWER" then
        return #Game.party > 0
    end
    return true
end

function GonerMenu:refreshPageEntries()
    self.page_entries = {}
    if self.state == "ITEM" then
        TableUtils.merge(self.page_entries, storageItems(ITEM_STORAGES[self.item_storage_index]))
    elseif self.state == "EQUIP" then
        local equip = EQUIP_TYPES[self.equip_type]
        table.insert(self.page_entries, {item = nil, storage = equip.storage, index = nil})
        TableUtils.merge(self.page_entries, storageItems(equip.storage))
    elseif self.state == "CONFIG" then
        self.page_entries = {"VOLUME", "FULLSCREEN", "AUTO RUN", "REDUCED FX", "BACK"}
    end
    self.page_selected = MathUtils.clamp(self.page_selected, 1, math.max(#self.page_entries, 1))
end

function GonerMenu:closeItemStorage()
    if not self.open_item_storage then return end
    local storage = Game.inventory:getStorage(self.open_item_storage)
    if storage then
        for _, item in ipairs(storage) do item:onMenuClose(self) end
    end
    self.open_item_storage = nil
end

function GonerMenu:setItemStorage(index)
    self:closeItemStorage()
    self.item_storage_index = MathUtils.wrap(index, 1, #ITEM_STORAGES + 1)
    self.page_selected = 1
    self:refreshPageEntries()
    self.open_item_storage = ITEM_STORAGES[self.item_storage_index]
    local storage = Game.inventory:getStorage(self.open_item_storage)
    if storage then
        for _, item in ipairs(storage) do item:onMenuOpen(self) end
    end
end

function GonerMenu:getSelectedEntry()
    return self.page_entries[self.page_selected]
end

function GonerMenu:getItemTexture(item, empty)
    if not item then return empty and self.empty_image or self.unknown_image end
    local image = item:getMenuImage()
    if not image then return self.unknown_image end
    return Assets.getTexture("items/" .. image) or self.unknown_image
end

function GonerMenu:getEquippedItem()
    local party = Game.party[1]
    if not party then return nil end
    local equip = EQUIP_TYPES[self.equip_type]
    if equip.slot_type == "weapon" then
        return party:getWeapon()
    elseif equip.slot_type == "armor" then
        return party:getArmor(self.equip_slot)
    else
        return party:getTrinket(self.equip_slot)
    end
end

function GonerMenu:changeEquipType(direction)
    self.equip_selections[self.equip_type] = self.page_selected
    self.equip_type = MathUtils.wrap(self.equip_type + direction, 1, #EQUIP_TYPES + 1)
    self.equip_slot = 1
    self.page_selected = self.equip_selections[self.equip_type] or 1
    self:refreshPageEntries()
end

function GonerMenu:close()
    self:closeItemStorage()
    if Game.world and Game.world.menu == self then
        Game.world.menu = nil
    end
    if self.saved_can_open ~= nil then
        Game.world.can_open_menu = self.saved_can_open
        self.saved_can_open = nil
    end
    self:remove()
end

function GonerMenu:transitionOut()
    if self.animate_out then return end
    self.animate_out = true
    self.saved_can_open = Game.world.can_open_menu
    Game.world.can_open_menu = false
end

function GonerMenu:returnToMain()
    self:closeItemStorage()
    self.state = "MAIN"
    self.page_selected = 1
    self.page_entries = {}
    self.ui_cancel:stop()
    self.ui_cancel:play()
end

function GonerMenu:openOption(index)
    if not self:isOptionEnabled(index) then
        self.ui_error:stop()
        self.ui_error:play()
        return
    end

    local id = self.options[index].id
    self.ui_select:stop()
    self.ui_select:play()
    Input.clear("confirm")

    if id == "TALK" then
        Game.world.current_selecting = index
        Game.world:closeMenu()
        Game.world:startCutscene("_talk")
        return
    end

    self.state = id
    self.page_selected = 1
    if id == "ITEM" then
        self:setItemStorage(self.item_storage_index)
    elseif id == "EQUIP" then
        self.equip_stage = "TYPE"
        self.equip_type = 1
        self.equip_slot = 1
        self.page_selected = self.equip_selections[1] or 1
        self:refreshPageEntries()
    else
        self:refreshPageEntries()
    end
end

function GonerMenu:useSelectedItem()
    local entry = self:getSelectedEntry()
    local item = entry and entry.item
    if not item or (item.usable_in ~= "world" and item.usable_in ~= "all") then
        self.ui_error:stop()
        self.ui_error:play()
        return
    end

    local target
    if item:getTarget() == "ally" then
        target = Game.party[1]
    else
        target = Game.party
    end
    if not target then
        self.ui_error:stop()
        self.ui_error:play()
        return
    end

    local result = item:onWorldUse(target)
    if (item.type == "item" and (result == nil or result)) or (item.type ~= "item" and result) then
        if item:hasResultItem() then
            Game.inventory:replaceItem(item, item:createResultItem())
        else
            Game.inventory:removeItem(item)
        end
    end

    self.ui_select:stop()
    self.ui_select:play()
    self:setItemStorage(self.item_storage_index)
end

function GonerMenu:equipSelectedItem()
    local party = Game.party[1]
    local entry = self:getSelectedEntry()
    local item = entry and entry.item or nil
    local equip = EQUIP_TYPES[self.equip_type]
    if not party or not entry then
        self.ui_error:stop()
        self.ui_error:play()
        return
    end

    local current = self:getEquippedItem()
    local storage = Game.inventory:getStorage(equip.storage)
    local safe_index = entry.index
    if not item then
        for index = 1, storage.max do
            if storage[index] == nil then
                safe_index = index
                break
            end
        end
    end

    if not safe_index
        or not party:canEquip(item, equip.slot_type, self.equip_slot)
        or (item and not item:onEquip(party, current))
        or (current and not current:onUnequip(party, item))
        or not party:onEquip(item, current)
        or not party:onUnequip(current, item) then
        self.ui_error:stop()
        self.ui_error:play()
        return
    end

    if equip.slot_type == "weapon" then
        party:setWeapon(item)
    elseif equip.slot_type == "armor" then
        party:setArmor(self.equip_slot, item)
    else
        party:setTrinket(self.equip_slot, item)
    end
    Game.inventory:setItem(storage, safe_index, current)

    self.ui_select:stop()
    self.ui_select:play()
    self.equip_stage = "SLOT"
    self.equip_selections[self.equip_type] = 1
    self.page_selected = 1
    self:refreshPageEntries()
end

function GonerMenu:changeConfig(direction, confirm)
    local selected = self.page_entries[self.page_selected]
    if selected == "VOLUME" then
        if direction ~= 0 then
            Kristal.setVolume(MathUtils.clamp(Kristal.getVolume() + direction * 0.05, 0, 1))
            Assets.stopAndPlaySound("noise")
        end
    elseif selected == "FULLSCREEN" and confirm and not Kristal.isForcedFullscreen() then
        Kristal.Config["fullscreen"] = not Kristal.Config["fullscreen"]
        love.window.setFullscreen(Kristal.Config["fullscreen"])
    elseif selected == "AUTO RUN" and confirm then
        Kristal.Config["autoRun"] = not Kristal.Config["autoRun"]
    elseif selected == "REDUCED FX" and confirm then
        Kristal.Config["simplifyVFX"] = not Kristal.Config["simplifyVFX"]
    elseif selected == "BACK" and confirm then
        self:returnToMain()
        return
    end
    if confirm then
        self.ui_select:stop()
        self.ui_select:play()
    end
end

function GonerMenu:onKeyPressed(key)
    if self.animate_out then return end

    if self.state == "MAIN" then
        if Input.isMenu(key) or Input.isCancel(key) then
            Game.world.current_selecting = self.selected
            Game.world:closeMenu()
            return
        end

        local old = self.selected
        if Input.is("up", key) then self.selected = MathUtils.wrap(self.selected - 1, 1, #self.options + 1) end
        if Input.is("down", key) then self.selected = MathUtils.wrap(self.selected + 1, 1, #self.options + 1) end
        if old ~= self.selected then
            self.ui_move:stop()
            self.ui_move:play()
        end
        if Input.isConfirm(key) then
            self:openOption(self.selected)
        end
        return
    end

    if self.state == "POWER" then
        if Input.isCancel(key) or Input.isMenu(key) then self:returnToMain() end
        if Input.isConfirm(key) then self:returnToMain() end
        return
    end

    if self.state == "ITEM" then
        if Input.isCancel(key) or Input.isMenu(key) then
            self:returnToMain()
            return
        end

        local old = self.page_selected
        local count = math.max(#self.page_entries, 1)
        if Input.is("up", key) then self.page_selected = MathUtils.wrap(self.page_selected - 1, 1, count + 1) end
        if Input.is("down", key) then self.page_selected = MathUtils.wrap(self.page_selected + 1, 1, count + 1) end
        if Input.is("left", key) then self:setItemStorage(self.item_storage_index - 1) end
        if Input.is("right", key) then self:setItemStorage(self.item_storage_index + 1) end
        if old ~= self.page_selected or Input.is("left", key) or Input.is("right", key) then
            self.ui_move:stop()
            self.ui_move:play()
        end
        if Input.isConfirm(key) then self:useSelectedItem() end
        return
    end

    if self.state == "EQUIP" then
        if Input.isMenu(key) then
            self:returnToMain()
            return
        end

        if self.equip_stage == "TYPE" then
            if Input.isCancel(key) then
                self:returnToMain()
                return
            end
            local direction = Input.is("left", key) and -1 or Input.is("right", key) and 1 or 0
            if direction ~= 0 then
                self:changeEquipType(direction)
                self.ui_move:stop()
                self.ui_move:play()
            elseif Input.isConfirm(key) then
                self.equip_stage = "SLOT"
                self.equip_slot = 1
                self.ui_select:stop()
                self.ui_select:play()
            end
        elseif self.equip_stage == "SLOT" then
            if Input.isCancel(key) then
                self.equip_stage = "TYPE"
                self.ui_cancel:stop()
                self.ui_cancel:play()
                return
            end
            local slots = EQUIP_TYPES[self.equip_type].slots
            local old = self.equip_slot
            if Input.is("left", key) then self.equip_slot = MathUtils.wrap(self.equip_slot - 1, 1, slots + 1) end
            if Input.is("right", key) then self.equip_slot = MathUtils.wrap(self.equip_slot + 1, 1, slots + 1) end
            if old ~= self.equip_slot then
                self.ui_move:stop()
                self.ui_move:play()
            elseif Input.isConfirm(key) then
                self.equip_stage = "ITEM"
                self.page_selected = self.equip_selections[self.equip_type] or 1
                self:refreshPageEntries()
                self.ui_select:stop()
                self.ui_select:play()
            end
        else
            if Input.isCancel(key) then
                self.equip_selections[self.equip_type] = self.page_selected
                self.equip_stage = "SLOT"
                self.ui_cancel:stop()
                self.ui_cancel:play()
                return
            end
            local old = self.page_selected
            if Input.is("left", key) then self.page_selected = math.max(1, self.page_selected - 1) end
            if Input.is("right", key) then self.page_selected = math.min(#self.page_entries, self.page_selected + 1) end
            if old ~= self.page_selected then
                self.equip_selections[self.equip_type] = self.page_selected
                self.ui_move:stop()
                self.ui_move:play()
            elseif Input.isConfirm(key) then
                self:equipSelectedItem()
            end
        end
        return
    end

    if Input.isCancel(key) or Input.isMenu(key) then
        self:returnToMain()
        return
    end

    local count = math.max(#self.page_entries, 1)
    local old = self.page_selected
    if Input.is("up", key) then self.page_selected = MathUtils.wrap(self.page_selected - 1, 1, count + 1) end
    if Input.is("down", key) then self.page_selected = MathUtils.wrap(self.page_selected + 1, 1, count + 1) end
    if old ~= self.page_selected then
        self.ui_move:stop()
        self.ui_move:play()
    end

    if self.state == "CONFIG" then
        local direction = Input.is("left", key) and -1 or Input.is("right", key) and 1 or 0
        self:changeConfig(direction, Input.isConfirm(key))
    end
end

function GonerMenu:update()
    if self.state == "ITEM" and self.open_item_storage then
        local storage = Game.inventory:getStorage(self.open_item_storage)
        if storage then
            for _, item in ipairs(storage) do item:onMenuUpdate(self) end
        end
    end
    if self.animate_out then
        self.fade.alpha = MathUtils.approach(self.fade.alpha, 0, 0.14 * DTMULT)
        if self.fade.alpha == 0 then self:close() end
    else
        self.fade.alpha = MathUtils.approach(self.fade.alpha, 1, 0.14 * DTMULT)
    end
    super.update(self)
end

function GonerMenu:drawCursor(x, y)
    Draw.setColor(COLORS.black)
    Draw.draw(self.cursor, x, y + (self.font:getHeight() - self.cursor:getHeight() * 0.5) / 2, 0, 0.5, 0.5)
end

function GonerMenu:drawPageArrow(texture, x, y, active)
    Draw.setColor(active and COLORS.black or {0.52, 0.52, 0.49})
    Draw.draw(texture, x, y)
end

function GonerMenu:drawItemCard(item, x, y, scale, selected, empty)
    scale = scale or 1
    local image_size = 91 * scale
    local border = selected and COLORS.black or {0.48, 0.48, 0.45}
    Draw.setColor(border)
    love.graphics.setLineWidth(1)
    love.graphics.rectangle("line", x - 4, y - 4, image_size + 8, image_size + 8)

    local texture = self:getItemTexture(item, empty)
    if texture then
        local last_shader = love.graphics.getShader()
        love.graphics.setShader(Kristal.Shaders["GonerPalette"])
        Draw.setColor(1, 1, 1, 1)
        Draw.draw(texture, x + image_size / 2, y + image_size / 2, 0, scale, scale, 45.5, 45.5)
        love.graphics.setShader(last_shader)
    end
    Draw.setColor(COLORS.black)
end

function GonerMenu:drawStatus()
    local party = Game.party[1]
    love.graphics.setFont(self.font)
    Draw.setColor(COLORS.black)
    if not party then
        love.graphics.print("NO VESSEL DETECTED", 270, 58)
        love.graphics.print("HP -- / --", 270, 88)
        love.graphics.print("STATUS: UNASSIGNED", 270, 116)
        return
    end

    love.graphics.print(party:getName():upper(), 270, 56)
    love.graphics.print(party:getTitle():upper(), 270, 78)
    love.graphics.print(string.format("HP %d / %d", party:getHealth(), party:getStat("health")), 270, 104)
    love.graphics.print(string.format("AT %d   DF %d   MG %d", party:getStat("attack"), party:getStat("defense"), party:getStat("magic")), 270, 128)
end

function GonerMenu:drawMainContent()
    local option = self.options[self.selected]
    Draw.setColor(COLORS.black)
    love.graphics.print(option.id, 272, 208)
    love.graphics.printf(option.description, 272, 244, 316, "left")
    love.graphics.print(self:isOptionEnabled(self.selected) and "STATUS: AVAILABLE" or "STATUS: UNAVAILABLE", 272, 354)
end

function GonerMenu:drawItemPage()
    Draw.setColor(COLORS.black)
    love.graphics.print("STORAGE", 272, 206)
    local storage_label = self.item_storage_index == 1 and "ITEMS" or "KEY DATA"
    local label_width = self.font:getWidth(storage_label)
    love.graphics.print(storage_label, 430 - label_width / 2, 230)
    self:drawPageArrow(self.arrow_left, 330, 231, true)
    self:drawPageArrow(self.arrow_right, 520, 231, true)

    if #self.page_entries == 0 then
        love.graphics.print("NO DATA", 300, 280)
        love.graphics.print("0 / 0", 276, 326)
        self:drawItemCard(nil, 486, 263, 1, true, true)
        return
    end

    local first = math.max(1, self.page_selected - 2)
    local last = math.min(#self.page_entries, self.page_selected + 2)
    for index = first, last do
        local y = 266 + ((index - self.page_selected + 2) * 25)
        local item = self.page_entries[index].item
        love.graphics.printf(item:getWorldMenuName(), 306, y, 154, "left")
        if index == self.page_selected then self:drawCursor(280, y) end
    end

    self:drawPageArrow(self.arrow_up, 274, 266, first > 1)
    self:drawPageArrow(self.arrow_down, 274, 366, last < #self.page_entries)
    love.graphics.printf(self.page_selected .. " / " .. #self.page_entries, 266, 326, 54, "center")

    local item = self:getSelectedEntry().item
    self:drawItemCard(item, 486, 263, 1, true)
    Draw.setColor(COLORS.black)
    local description = item:getDescription() or ""
    local _, lines = self.font:getWrap(description, 130)
    for index, line in ipairs(lines) do
        if index > 3 then break end
        love.graphics.print(line, 474, 372 + ((index - 1) * 16))
    end
end

function GonerMenu:drawEquipPage()
    local party = Game.party[1]
    Draw.setColor(COLORS.black)
    love.graphics.print("EQUIPMENT LINK", 272, 206)
    local equip = EQUIP_TYPES[self.equip_type]
    local stage_label = self.equip_stage == "TYPE" and "TYPE" or self.equip_stage == "SLOT" and "SLOT" or "DATA"
    love.graphics.print("TYPE > SLOT > DATA    [" .. stage_label .. "]", 272, 230)
    if not party then return end

    if self.equip_stage == "TYPE" then
        for index, definition in ipairs(EQUIP_TYPES) do
            local x = 288 + ((index - 1) * 103)
            Draw.setColor(index == self.equip_type and COLORS.black or {0.48, 0.48, 0.45})
            love.graphics.printf(definition.label, x, 274, 90, "center")
        end
        self:drawPageArrow(self.arrow_left, 276, 276, true)
        self:drawPageArrow(self.arrow_right, 576, 276, true)
        local current = self:getEquippedItem()
        self:drawItemCard(current, 368, 312, 0.75, true, true)
        Draw.setColor(COLORS.black)
        love.graphics.print("CURRENT", 456, 316)
        love.graphics.printf(current and current:getName() or "(EMPTY)", 456, 342, 126, "left")
        love.graphics.print("SELECT EQUIPMENT CLASS", 456, 382)
    elseif self.equip_stage == "SLOT" then
        local slots = equip.slots
        for index = 1, slots do
            local current
            if equip.slot_type == "weapon" then current = party:getWeapon()
            elseif equip.slot_type == "armor" then current = party:getArmor(index)
            else current = party:getTrinket(index) end
            local x = slots == 1 and 379 or 290 + ((index - 1) * 104)
            self:drawItemCard(current, x, 278, slots == 1 and 1 or 0.68, index == self.equip_slot, true)
            Draw.setColor(COLORS.black)
            love.graphics.printf("SLOT " .. index, x - 4, slots == 1 and 380 or 350, slots == 1 and 99 or 70, "center")
            if index == self.equip_slot then
                Draw.setColor(COLORS.black)
                Draw.draw(self.arrow_down, x + (slots == 1 and 38 or 24), 258)
            end
        end
        local current = self:getEquippedItem()
        Draw.setColor(COLORS.black)
        love.graphics.printf(current and current:getName() or "(EMPTY)", 272, 402, 316, "center")
    else
        local entry = self:getSelectedEntry()
        local current = self:getEquippedItem()
        love.graphics.printf("CURRENT: " .. (current and current:getName() or "(EMPTY)"), 272, 252, 316, "center")

        for offset = -1, 1 do
            local index = self.page_selected + offset
            local candidate = self.page_entries[index]
            if candidate then
                local selected = offset == 0
                local scale = selected and 1 or 0.58
                local x = selected and 379 or offset < 0 and 286 or 526
                local y = selected and 282 or 302
                self:drawItemCard(candidate.item, x, y, scale, selected, candidate.item == nil)
            end
        end

        local name = entry.item and entry.item:getName() or "(UNEQUIP)"
        Draw.setColor(COLORS.black)
        love.graphics.printf(name, 272, 380, 316, "center")
        love.graphics.printf(self.page_selected .. " / " .. #self.page_entries, 272, 402, 316, "center")
        self:drawPageArrow(self.arrow_left, 342, 403, self.page_selected > 1)
        self:drawPageArrow(self.arrow_right, 506, 403, self.page_selected < #self.page_entries)
    end
end

function GonerMenu:drawPowerPage()
    local party = Game.party[1]
    Draw.setColor(COLORS.black)
    love.graphics.print("VESSEL POWER", 272, 206)
    if not party then return end
    love.graphics.print(string.format("HEALTH     %d", party:getStat("health")), 272, 238)
    love.graphics.print(string.format("ATTACK     %d", party:getStat("attack")), 272, 264)
    love.graphics.print(string.format("DEFENSE    %d", party:getStat("defense")), 272, 290)
    love.graphics.print(string.format("MAGIC      %d", party:getStat("magic")), 272, 316)
    local spells = party:getSpells()
    love.graphics.print("PROGRAMS   " .. (#spells > 0 and spells[1]:getName() or "NONE"), 272, 350)
end

function GonerMenu:drawConfigPage()
    Draw.setColor(COLORS.black)
    love.graphics.print("INTERFACE CONFIG", 272, 206)
    for index, label in ipairs(self.page_entries) do
        local y = 240 + ((index - 1) * 34)
        local value = ""
        if label == "VOLUME" then
            value = math.floor(Kristal.getVolume() * 100) .. "%"
        elseif label == "FULLSCREEN" then
            value = Kristal.Config["fullscreen"] and "ON" or "OFF"
        elseif label == "AUTO RUN" then
            value = Kristal.Config["autoRun"] and "ON" or "OFF"
        elseif label == "REDUCED FX" then
            value = Kristal.Config["simplifyVFX"] and "ON" or "OFF"
        end
        love.graphics.print(label, 300, y)
        love.graphics.printf(value, 272, y, 314, "right")
        if index == self.page_selected then self:drawCursor(274, y) end
    end
end

function GonerMenu:draw()
    Draw.setColor(0, 0, 0, 0.42)
    love.graphics.rectangle("fill", 0, 0, SCREEN_WIDTH, SCREEN_HEIGHT)
    super.draw(self)

    love.graphics.setFont(self.font)
    Draw.setColor(COLORS.black)
    love.graphics.print("INTERFACE", 50, 56)
    for index, option in ipairs(self.options) do
        local y = 94 + ((index - 1) * 52)
        Draw.setColor(self:isOptionEnabled(index) and COLORS.black or {0.42, 0.42, 0.40})
        love.graphics.print(option.id, 82, y)
        if index == self.selected and self.state == "MAIN" then self:drawCursor(54, y) end
    end

    self:drawStatus()
    if self.state == "MAIN" then
        self:drawMainContent()
    elseif self.state == "ITEM" then
        self:drawItemPage()
        if self.open_item_storage then
            local storage = Game.inventory:getStorage(self.open_item_storage)
            if storage then
                for _, item in ipairs(storage) do item:onMenuDraw(self) end
            end
        end
    elseif self.state == "EQUIP" then
        self:drawEquipPage()
    elseif self.state == "POWER" then
        self:drawPowerPage()
    elseif self.state == "CONFIG" then
        self:drawConfigPage()
    end
    Draw.setColor(1, 1, 1, 1)
end

return GonerMenu
