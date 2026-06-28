---@class DarkItemMenu : Object
---@overload fun(...) : DarkItemMenu
local DarkItemMenu, super = Class(Object)

function DarkItemMenu:init()
    super.init(self, 92, 112, 457, 227)

    self.draw_children_below = 0

    self.font = Assets.getFont("main")

    self.ui_move = Assets.newSound("ui_move_panel")
    self.ui_select = Assets.newSound("ui_select_panel")
    self.ui_cant_select = Assets.newSound("ui_error_panel")
    self.ui_cancel_small = Assets.newSound("ui_cancel_small_camera")

    self.heart_sprite = Assets.getTexture("player/heart")

    self.displayed_description = ""
    self.displayed_image = nil

    self.up_arrow_sprite = Assets.getTexture("ui/page_arrow_up")
    self.down_arrow_sprite = Assets.getTexture("ui/page_arrow_down")

    self.popup_sprite = Assets.getTexture("ui/menu/popup")

    self.popup_text = nil

    --self.bg = UIBox(0, 0, self.width, self.height)
    --self.bg.layer = -1
    --self.bg.debug_select = false
    --self:addChild(self.bg)

    -- States: MENU, SELECT, USE
    self.state = "MENU"

    self.small_font = Assets.getFont("small")
    self.small_numbers = Assets.getFont("smallnumbers")
    self.earthbound_font = Assets.getFont("eb")

    --self.scroll = 0

    self.item_header_selected = 1
    self.item_selected_x = 1
    self.item_selected_y = 1
    for _, item in ipairs(self:getCurrentStorage()) do
        item:onMenuOpen(self.parent)
    end

    self.selected_item = 1
end

function DarkItemMenu:getCurrentItemType()
    if self.item_header_selected == 3 then
        return "key_items"
    else
        return "items"
    end
end

function DarkItemMenu:getCurrentStorage()
    return Game.inventory:getStorage(self:getCurrentItemType())
end

function DarkItemMenu:getSelectedItem()
    return Game.inventory:getItem(self:getCurrentItemType(), self.selected_item)
end

function DarkItemMenu:updateSelectedItem()
    if (not Game.world.menu) or self:isRemoved() then
        return
    end

    local items = self:getCurrentStorage()
    if #items == 0 then
        self.state = "MENU"
        Game.world.menu:setDescription("", false)
    else
        if self.selected_item > #items then
            --self.item_selected_x = (#items - 1) % 2 + 1
            self.item_selected_y = 1
            self.selected_item = 1
        elseif self.selected_item < 1 then
            self.item_selected_y = #items
            self.selected_item = #items
        end
        if items[self.selected_item] then
            self.displayed_description = (items[self.selected_item]:getDescription())
            self.displayed_image = items[self.selected_item]:getMenuImage()
        else
            self.displayed_description = ""
            self.displayed_image = nil
            --Game.world.menu:setDescription("", true)
        end
    end
end

function DarkItemMenu:useItem(item, party)
    local result = item:onWorldUse(party)
    if isClass(party) then
        party = {party}
    end
    for _,char in ipairs(party) do
        for index, chara in ipairs(Game.party) do
            local reaction = chara:getReaction(item, char)
            if reaction then
                --Game.world.healthbar.action_boxes[index].reaction_alpha = 50
                -- Game.world.healthbar.action_boxes[index].reaction_text = reaction
                Game.world:partyReact(chara, reaction, 3)
            end
        end
    end
    if (item.type == "item" and (result == nil or result)) or (item.type ~= "item" and result) then
        if item:hasResultItem() then
            Game.inventory:replaceItem(item, item:createResultItem())
        else
            Game.inventory:removeItem(item)
        end
    end
    if item.type == "key" then
        local boxes = Game.world.healthbar.action_boxes
        for _, box in ipairs(boxes) do
            box.selected = true
        end
    end
    self:updateSelectedItem()
end

function DarkItemMenu:update()
    self.alpha = 1 - Game.world.menu.flicker_dur

    if self.state == "MENU" then
        if Input.pressed("cancel") then
            self.ui_cancel_small:stop()
            self.ui_cancel_small:play()
            Game.world.menu:closeBox()
            return
        end
        local header_move = 0
        if Input.pressed("left") then
            header_move = -1
        end
        if Input.pressed("right") then
            header_move = 1
        end
        if header_move ~= 0 then
            local prev_type = self:getCurrentItemType()
            self.item_header_selected = MathUtils.wrapIndex(self.item_header_selected + header_move, 3)
            self.ui_move:stop()
            self.ui_move:play()
            if prev_type ~= self:getCurrentItemType() then
                for _, item in ipairs(Game.inventory:getStorage(prev_type)) do
                    item:onMenuClose(self)
                end
                for _, item in ipairs(self:getCurrentStorage()) do
                    item:onMenuOpen(self)
                end
            end
        end
        if self.item_header_selected < 1 then self.item_header_selected = 3 end
        if self.item_header_selected > 3 then self.item_header_selected = 1 end
        if Input.pressed("confirm") and (#Game.inventory:getStorage(self:getCurrentItemType()) > 0) then
            self.ui_select:stop()
            self.ui_select:play()
            self.item_selected_x = 1
            self.item_selected_y = 1
            self.selected_item = 1
            self.state = "SELECT"

            self:updateSelectedItem()
        end
    elseif self.state == "SELECT" then
        if Input.pressed("cancel") then
            self.ui_cancel_small:stop()
            self.ui_cancel_small:play()
            self.state = "MENU"

            Game.world.menu:setDescription("", false)
            return
        end
        local old_x, old_y = self.item_selected_x, self.item_selected_y
        if Input.pressed("left") or Input.pressed("right") then
            if self.item_selected_x == 1 then
                self.item_selected_x = 2
            else
                self.item_selected_x = 1
            end
        end
        if Input.pressed("up") then
            self.item_selected_y = self.item_selected_y - 1
        end
        if Input.pressed("down") then
            self.item_selected_y = self.item_selected_y + 1
        end
        local items = self:getCurrentStorage()
        --if (not self.item_selected_y) or (self.item_selected_y < 1) then self.item_selected_y = 1 end
        -- if (2 * (self.item_selected_y - 1) + self.item_selected_x) > #items then
        --     if (#items % 2) ~= 0 then
        --         self.item_selected_x = ((#items - 1) % 2) + 1
        --     end
        --     self.item_selected_y = math.floor((#items - 1) / 2) + 1
        -- end

        self.selected_item_y = MathUtils.wrap(self.selected_item_y or 1, 1, #items+1)
        self.selected_item = self.item_selected_y
        if self.item_selected_y ~= old_y or self.item_selected_x ~= old_x then
            self.ui_move:stop()
            self.ui_move:play()
            self:updateSelectedItem()
        end
        if Input.pressed("confirm") then
            --self.selected_item = (2 * (self.item_selected_y - 1) + self.item_selected_x)
            local item = items[self.selected_item]
            if self.item_header_selected == 2 then
                self.state = "USE"

                Assets.playSound("item_trash_warning")

                --Game.world.menu:setDescription("Really throw away the\n" .. item:getName() .. "?", true)
                self.popup_text = "Are you sure you want to delete the " .. item:getName() .. "?"
                Game.world.menu:partySelect("ALL", function(success, party)
                    self.state = "SELECT"
                    if success then
                        Assets.playSound("item_trash")

                        local result = item:onToss()

                        if result ~= false then
                            Game.inventory:removeItem(item)
                        end
                    else
                        Assets.playSound("item_cancel")
                    end
                    --Game.world.menu:setDescription("", false)
                    self.popup_text = nil
                    self:updateSelectedItem()
                end)
            elseif item.usable_in == "world" or item.usable_in == "all" then
                if item:getTarget() == "ally" or item:getTarget() == "party" then
                    self.state = "USE"

                    local target_type = item:getTarget() == "ally" and "SINGLE" or "ALL"

                    Assets.playSound("item_click")

                    self.popup_text = "Select a target for:\n" .. item:getName()

                    Game.world.menu:partySelect(target_type, function(success, party)
                        self.state = "SELECT"
                        if success then
                            Assets.playSound("item_use")
                            self:useItem(item, party)
                        else
                            Assets.playSound("item_cancel")
                        end
                        self.popup_text = nil
                        self:updateSelectedItem()
                    end)
                else
                    self:useItem(item, Game.party)
                end
            else
                self.ui_cant_select:stop()
                self.ui_cant_select:play()
            end
        end
    end

    for _, item in ipairs(self:getCurrentStorage()) do
        item:onMenuUpdate(self.parent)
    end

    super.update(self)
end

function DarkItemMenu:draw()
    Draw.setColor(1,1,1,1)
    love.graphics.stencil(function()
            love.graphics.circle("fill", SCREEN_WIDTH/2 - self.x, SCREEN_HEIGHT/2 - self.y, 162)
        end, "replace", 1)
    love.graphics.setStencilTest("greater", 0)
    love.graphics.setFont(self.font)

    local headers = {"USE", "TRASH", "KEY"}

    for i,name in ipairs(headers) do
        if self.state == "MENU" then
            Draw.setColor(PALETTE["world_header"], self.alpha)
            if (self.item_header_selected == i) then Draw.setColor(PALETTE["world_text_hover"], self.alpha) end
        elseif self.item_header_selected == i then
            Draw.setColor(PALETTE["world_header_selected"], self.alpha)
        else
            Draw.setColor(PALETTE["world_gray"], self.alpha)
        end
        local offset = (i == 1) and 0 or ((i == 2) and 62 or (62+78))
        local x = 140 + offset
        love.graphics.print(name, x - #name, -2)
    end

    -- local heart_x = 20
    -- local heart_y = 20

    -- if self.state == "MENU" then
    --     heart_x = 88 + ((self.item_header_selected - 1) * 120) - 25
    --     heart_y = 8
    -- elseif self.state == "SELECT" then
    --     heart_x = 28 + (self.item_selected_x - 1) * 210
    --     heart_y = 50 + (self.item_selected_y - 1) * 30
    -- end
    -- if self.state ~= "USE" then
    --     --Draw.setColor(Game:getSoulColor())
    --     --Draw.draw(self.heart_sprite, heart_x, heart_y)
    -- end

    local item_x = 0
    local item_y = 0
    local inventory = self:getCurrentStorage()

    local active_item_type = (self:getCurrentItemType() == "key_items") and "KEY" or "ITEM"
    if (inventory[self.selected_item]) then
        if (inventory[self.selected_item]:includes(HealItem)) then
            active_item_type = "CONSUMABLE"
        end
    end

    for i, item in ipairs(inventory) do
        if math.abs(i - self.selected_item) <= 2 then
            -- Draw the item shadow
            Draw.setColor(PALETTE["world_text_shadow"], self.alpha)
            item_y = 3 + i - self.selected_item
            local name = item:getWorldMenuName()
            love.graphics.print(name, 94 + (item_x * 142) + 2, 20 + (item_y * 30) + 2)

            if self.state == "MENU" then
                Draw.setColor(PALETTE["world_gray"], self.alpha)
            else
                if item.usable_in == "world" or item.usable_in == "all" then
                    Draw.setColor(PALETTE["world_text"], self.alpha)
                    if (i == self.selected_item) then
                        Draw.setColor((self.item_header_selected == 2) and COLORS.red or PALETTE["world_text_hover"], self.alpha)
                    end
                else
                    Draw.setColor(PALETTE["world_text_unusable"], self.alpha)
                end
            end
            love.graphics.print(name, 94 + (item_x * 142), 20 + (item_y * 30))
            item_y = item_y + 1
            -- if item_x >= 2 then
            --     item_x = 0
            --     item_y = item_y + 1
            -- end
        end
    end

    Draw.setColor(PALETTE["world_gray"], self.alpha)
    if (1 < (self.selected_item - 2)) then
        Draw.setColor(1,1,1, self.alpha)
    end
    Draw.draw(self.up_arrow_sprite, 72, 98)

    Draw.setColor(PALETTE["world_gray"], self.alpha)
    if (#inventory > (self.selected_item + 2)) then
        Draw.setColor(1,1,1, self.alpha)
    end
    Draw.draw(self.down_arrow_sprite, 72, 149)

    Draw.setColor(1,1,1, self.alpha)
    love.graphics.setFont(self.small_numbers)
    love.graphics.print(self.selected_item .. "\n-\n".. #inventory, 70, 116)

    if (self.state ~= "MENU") and (self.displayed_image) then
        Draw.setColor(1,1,1, self.alpha)
        love.graphics.setLineWidth(2)
        Draw.rectangle("line", 260-4 ,50-4 ,99, 99)
        Draw.draw(Assets.getTexture("items/" .. self.displayed_image) or Assets.getTexture("items/unknown"), 260, 50, 0, 1, 1)
        love.graphics.line(260-8, 50+99, 260+99, 50+99)

        love.graphics.setFont(self.font)
        love.graphics.print(active_item_type, 260 + 35 - (#active_item_type) * 5.5, 145)

        love.graphics.setFont(self.earthbound_font)
        local _, wrapped = self.earthbound_font:getWrap(self.displayed_description, 140)
        for i, textline in ipairs(wrapped) do
            love.graphics.print(textline, 242, 178 + (16 * (i-1)))
            if (i > 3) then break end
        end
        

        love.graphics.setFont(self.font)
    end

    --love.graphics.print("|\n|\n|\n|\n|\n|", SCREEN_WIDTH / 2.85, 38)

    for _, item in ipairs(inventory) do
        Draw.setColor(1,1,1, self.alpha)
        item:onMenuDraw(self.parent)
    end

    self:drawPopup()

    super.draw(self)
    love.graphics.setStencilTest()
end

function DarkItemMenu:drawPopup()
    if (self.popup_text) then
        Draw.setColor(1,1,1, self.alpha)
        Draw.draw(self.popup_sprite, (SCREEN_WIDTH / 3.92) - 10, 86)
        Draw.setColor(0,0,0, self.alpha)
        love.graphics.setFont(self.earthbound_font)
        local _, wrapped = self.earthbound_font:getWrap(self.popup_text, 150)
        local base_y = 96
        if (#wrapped < 4) then
            base_y = base_y + (16 * (3.5 - #wrapped))
        end
        for i, textline in ipairs(wrapped) do
            love.graphics.print(textline, SCREEN_WIDTH/4,  base_y + (16 * (i-1)))
            if (i > 4) then break end
        end
        love.graphics.setFont(self.font)
        Draw.setColor(1,1,1,1)
    end
end

return DarkItemMenu
