---@class LightMenu : Object
---@overload fun(...) : LightMenu
local LightMenu, super = Class(Object)

function LightMenu:init()
    super.init(self, 0, 0)

    self.layer = 1 -- TODO

    self.parallax_x = 0
    self.parallax_y = 0

    self.animation_done = false
    self.animation_timer = 0
    self.animate_out = false

    self.selected_submenu = 1

    self.current_selecting = Game.world.current_selecting or 1

    -- Make sure that we're not selecting a menu that doesn't exist...
    self.current_selecting = Utils.clamp(self.current_selecting, 1, self:getMaxSelecting())

    self.item_selected = 1

    -- States: MAIN, ITEMMENU, ITEMUSAGE
    self.state = "MAIN"
    self.state_reason = nil
    self.heart_sprite = Assets.getTexture("player/heart_menu")

    self.ui_move = Assets.newSound("ui_move")
    self.ui_select = Assets.newSound("ui_select")
    self.ui_cant_select = Assets.newSound("ui_cant_select")
    self.ui_cancel_small = Assets.newSound("ui_cancel_small")

    self.font       = Assets.getFont("main")
    self.font_small = Assets.getFont("small")

    self.box = nil

    self.top = true

    self:realign()

    self.storage = "items"

    self.panel_bg = PanelMenuBackground("ui/menu/panels/main/menu", 0, 20, "camera_open", "camera_close", "ui_move_panel", "ui_select_camera", "ui_error_camera", "ui_cancel_small_camera", "ui_static", 0, 40)
    self.fx = ShaderFX("crt", {["iTime"] = function () return Kristal.getTime() end, ["texsize"] = {self.panel_bg.sprite:getWidth(), self.panel_bg.sprite:getHeight()}})
    self:addChild(self.panel_bg)
    self.ui_select = self.panel_bg.ui_select
    self.ui_move = self.panel_bg.ui_move
    self.ui_cancel = self.panel_bg.ui_cancel
    self.ui_error = self.panel_bg.ui_error
    self.objective = ObjectivePopup(0, 20, nil, nil, Game:getFlag("current_objective"), nil, "none", false, false, true)
    self.objective.layer = self.layer - 0.1
    Game.stage:addChild(self.objective)
end

function LightMenu:getMaxSelecting()
    return Game:getFlag("has_cell_phone", false) and 3 or 2
end

function LightMenu:close()
    if (Game.world and Game.world.menu == self) then
        Game.world.menu = nil
    end
    self:remove()
end

function LightMenu:closeBox(immediate)
    self.state = "MAIN"
    if (self.box) then
        if (self.box.panel_bg ~= nil) then 
            self.box.panel_bg:close(immediate, function () self.box:remove() ; self.box = nil end)
        else
            self.box:remove()
            self.box = nil
        end
        
    end
end

function LightMenu:transitionOut()
    local could_open = Game.world.can_open_menu
    Game.world.can_open_menu = false
    self.panel_bg:close(false, function ()
        Game.world.can_open_menu = could_open
        self:close()  
        end)
end

function LightMenu:onKeyPressed(key)
    if not self.panel_bg.operable then return end
    if (Input.isMenu(key) or Input.isCancel(key)) and self.state == "MAIN" then
        self.objective:close()
        Game.world:closeMenu()
        return
    end

    if self.state == "MAIN" then
        local old_selected = self.current_selecting
        if Input.is("up", key)    then self.current_selecting = self.current_selecting - 1 end
        if Input.is("down", key) then self.current_selecting = self.current_selecting + 1 end
        self.current_selecting = Utils.clamp(self.current_selecting, 1, self:getMaxSelecting())
        if old_selected ~= self.current_selecting then
            self.ui_move:stop()
            self.ui_move:play()
        end
        if Input.isConfirm(key) then
            self:onButtonSelect(self.current_selecting)
        end
    end
end

function LightMenu:onButtonSelect(button)
    if button == 1 then
        if Game.inventory:getItemCount(self.storage, false) > 0 then
            self.state = "ITEMMENU"
            Input.clear("confirm")
            self.box = LightItemMenu()
            self.box.layer = 1
            self:addChild(self.box)

            self.ui_select:stop()
            self.ui_select:play()
        end
    elseif button == 2 then
        self.state = "STATMENU"
        Input.clear("confirm")
        self.box = LightStatMenu()
        self.box.layer = 1
        self:addChild(self.box)

        self.ui_select:stop()
        self.ui_select:play()
    elseif button == 3 then
        if #Game.world.calls > 0 then
            Input.clear("confirm")
            self.state = "CELLMENU"
            self.box = LightCellMenu()
            self.box.layer = 1
            self:addChild(self.box)

            self.ui_select:stop()
            self.ui_select:play()
        end
    end
end

function LightMenu:update()
    super.update(self)
    self:realign()
end

function LightMenu:realign()
    local _, player_y = Game.world.player:localToScreenPos()
    self.top = player_y > 260

    local offset = 0
    if self.top then
        offset = 270
    end
end

function LightMenu:draw()
    super.draw(self)
    if (self.panel_bg.operable) then
        local offset = 0
        -- local current_canvas = love.graphics.getCanvas()
        -- local new_canvas = Draw.pushCanvas(SCREEN_WIDTH, SCREEN_HEIGHT)
        -- love.graphics.setCanvas(new_canvas)
        -- Draw.setColor(1, 1, 1)

        local chara = Game.party[1]

        local randAlpha = Utils.random(0.8, 1.0)

        love.graphics.setFont(self.font)
        Draw.setColor(PALETTE["world_text"], randAlpha)
        love.graphics.print(chara:getName(), 46, 60 + offset)

        love.graphics.setFont(self.font_small)
        love.graphics.print("LV  "..chara:getLightLV(), 46, 100 + offset)
        love.graphics.print("HP  "..chara:getHealth().."/"..chara:getStat("health"), 46, 118 + offset)
        love.graphics.print(Utils.padString(Game:getConfig("lightCurrencyShort"), 4)..Game.lw_money, 46, 136 + offset)

        love.graphics.setFont(self.font)
        if Game.inventory:getItemCount(self.storage, false) <= 0 then
            Draw.setColor(PALETTE["world_gray"], randAlpha)
        else
            Draw.setColor(PALETTE["world_text"], randAlpha)
        end
        love.graphics.print("ITEM", 84, 188 + (36 * 0))
        Draw.setColor(PALETTE["world_text"], randAlpha)
        love.graphics.print("STAT", 84, 188 + (36 * 1))
        if Game:getFlag("has_cell_phone", false) then
            if #Game.world.calls > 0 then
                Draw.setColor(PALETTE["world_text"], randAlpha)
            else
                Draw.setColor(PALETTE["world_gray"], randAlpha)
            end
            love.graphics.print("CELL", 84, 188 + (36 * 2))
        end

        if self.state == "MAIN" then
            Draw.setColor(Game:getSoulColor())
            Draw.draw(self.heart_sprite, 56, 160 + (36 * self.current_selecting), 0, 2, 2)
        end
        
    end
    
end

return LightMenu
