---@class LightItemMenu : Object
---@overload fun(...) : LightItemMenu
local LightItemMenu, super = Class(Object)

function LightItemMenu:init()
    super.init(self, 212, 76, 298, 314)

    self.draw_children_below = 0

    self.font = Assets.getFont("main")

    self.ui_move = Assets.newSound("ui_move")
    self.ui_select = Assets.newSound("ui_select")

    self.heart_sprite = Assets.getTexture("player/heart_menu")

    self.panel_bg = PanelMenuBackground("ui/menu/panels/side/menu", -14, -14, "panel_open", "panel_close", "ui_move_panel", "ui_select_panel", "ui_error_panel", "ui_cancel_small_camera", nil, 212-28, 76-28)
    self.fx = ShaderFX("crt", {["iTime"] = function () return Kristal.getTime() end, ["texsize"] = {self.panel_bg.sprite:getWidth(), self.panel_bg.sprite:getHeight()}})
    self:addChild(self.panel_bg)
    self.ui_select = self.panel_bg.ui_select
    self.ui_move = self.panel_bg.ui_move
    self.ui_cancel = self.panel_bg.ui_cancel
    self.ui_error = self.panel_bg.ui_error

    -- States: ITEMSELECT, ITEMOPTION
    self.state = "ITEMSELECT"

    self.item_selecting = 1
    self.option_selecting = 1

    self.storage = Game.world.menu.storage
end

function LightItemMenu:update()
    if self.panel_bg.operable == false then super.update(self) ; return end
    if self.state == "ITEMSELECT" then
        if Input.pressed("cancel") then
            Game.world.menu:closeBox()
            return
        end

        local old_selecting = self.item_selecting

        if Input.pressed("up") then
            self.item_selecting = self.item_selecting - 1
        end
        if Input.pressed("down") then
            self.item_selecting = self.item_selecting + 1
        end

        self.item_selecting = Utils.clamp(self.item_selecting, 1, Game.inventory:getItemCount(self.storage, false))

        if self.item_selecting ~= old_selecting then
            self.ui_move:stop()
            self.ui_move:play()
        end

        if Input.pressed("confirm") then
            self.ui_select:stop()
            self.ui_select:play()

            self.state = "ITEMOPTION"
        end
    elseif self.state == "ITEMOPTION" then
        if Input.pressed("cancel") then
            self.state = "ITEMSELECT"
            return
        end

        local old_selecting = self.option_selecting

        if Input.pressed("left") then
            self.option_selecting = self.option_selecting - 1
        end
        if Input.pressed("right") then
            self.option_selecting = self.option_selecting + 1
        end

        self.option_selecting = Utils.clamp(self.option_selecting, 1, 3)

        if self.option_selecting ~= old_selecting then
            self.ui_move:stop()
            self.ui_move:play()
        end

        if Input.pressed("confirm") then
            local item = Game.inventory:getItem(self.storage, self.item_selecting)
            if self.option_selecting == 1 then
                self:useItem(item)
            elseif self.option_selecting == 2 then
                item:onCheck()
            else
                self:dropItem(item)
            end
        end
    end

    super.update(self)
end

function LightItemMenu:draw()
    if (self.panel_bg.operable) then
        love.graphics.setFont(self.font)
        local randAlpha = Utils.random(0.8, 1.0)

        local inventory = Game.inventory:getStorage(self.storage)

        for index, item in ipairs(inventory) do
            if item.usable_in == "world" or item.usable_in == "all" then
                Draw.setColor(PALETTE["world_text"], randAlpha)
            else
                Draw.setColor(PALETTE["world_text_unusable"], randAlpha)
            end
            love.graphics.print(item:getName(), 20, -28 + (index * 32))
        end

        Draw.setColor(PALETTE["world_text"], randAlpha)
        love.graphics.print("USE" , 20 , 284)
        love.graphics.print("INFO", 116, 284)
        love.graphics.print("DROP", 230, 284)

        Draw.setColor(Game:getSoulColor())
        if self.state == "ITEMSELECT" then
            Draw.draw(self.heart_sprite, -4, -20 + (32 * self.item_selecting), 0, 2, 2)
        else
            if self.option_selecting == 1 then
                Draw.draw(self.heart_sprite, -4, 292, 0, 2, 2)
            elseif self.option_selecting == 2 then
                Draw.draw(self.heart_sprite, 92, 292, 0, 2, 2)
            elseif self.option_selecting == 3 then
                Draw.draw(self.heart_sprite, 206, 292, 0, 2, 2)
            end
        end
    end

    super.draw(self)
end

function LightItemMenu:useItem(item)
    local result = item:onWorldUse(Game.party)

    if result then
        if item:hasResultItem() then
            Game.inventory:replaceItem(item, item:createResultItem())
        else
            Game.inventory:removeItem(item)
        end
    end
end

function LightItemMenu:dropItem(item)
    local result = item:onToss()

    if result ~= false then
        Game.inventory:removeItem(item)
    end
end

return LightItemMenu