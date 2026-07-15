--- The config menu, for changing in-game settings.
---
---@class DarkConfigMenu : Object, StateManagedClass
---@overload fun(...) : DarkConfigMenu
local DarkConfigMenu, super = Class(Object)

function DarkConfigMenu:init()
    super.init(self, 82, 112, 477, 277)

    self.state = "MAIN"

    self.rebind_state = DarkConfigRebindState(self)
    self.volume_state = DarkConfigVolumeState(self)
    self.border_state = DarkConfigBorderState(self)

    self.state_manager = StateManager("MAIN", self, true)
    self.state_manager:addState("MAIN", { update = self.updateMainState, draw = self.drawMainState })
    self.state_manager:addState("REBIND", self.rebind_state)
    self.state_manager:addState("VOLUME", self.volume_state)
    self.state_manager:addState("BORDERS", self.border_state)
    self.state_manager:addState("EXIT", { enter = self.onExitState })

    self.draw_children_below = 0

    self.ui_move = Assets.newSound("ui_move_panel")
    self.ui_select = Assets.newSound("ui_select_panel")
    self.ui_cant_select = Assets.newSound("ui_error_panel")
    self.ui_cancel_small = Assets.newSound("ui_cancel_small_camera")

    self.heart_sprite = Assets.getTexture("player/heart")
    self.arrow_sprite = Assets.getTexture("ui/page_arrow_down")

    self.bg = UIBox(0, 0, self.width, self.height)
    self.bg.layer = -1
    self.bg.debug_select = false
    self.bg.visible = false
    self:addChild(self.bg)

    self.confirm_sprite = Assets.getTexture("ui/menu/confirm_changes")
    self.reset_sprite = Assets.getTexture("ui/menu/reset_defaults")

    -- MAIN, VOLUME, CONTROLS
    self.state = "MAIN"

    self.currently_selected = 0
    self.scroll_offset = 0
    self.noise_timer = 0

    self.reset_flash_timer = 0
    self.rebinding = false

    self.reset_siner = 0.2125
    self.confirm_siner = 0
end

function DarkConfigMenu:getMaxScroll()
    return 7
end

function DarkConfigMenu:getOptionHeight()
    return 35
end

--- Adds the default "return to title" and "back" buttons.
function DarkConfigMenu:addExitOptions()
    self:addOption(DarkConfigOption(self, "Return to Title", function()
        self:setState("EXIT")
        Game:returnToMenu()
    end))

    self:addOption(DarkConfigOption(self, "Back", function()
        if Game.chapter ~= 1 then -- TODO
            Assets.stopAndPlaySound("ui_cancel_small")
        end
        Game.world.menu:closeBox()
    end))
end

--- Clears all options from the menu.
function DarkConfigMenu:clearOptions()
    for i = #self.options, 1, -1 do
        self.options[i]:remove()
        self.options[i]:setAdded(false)
    end

    self.options = {}
end

--- Updates the config options.
function DarkConfigMenu:updateConfigOptions()
    self.currently_selected = MathUtils.clamp(self.currently_selected, 1, #self.options)

    if self.currently_selected - self.scroll_offset > self:getMaxScroll() then
        self.scroll_offset = self.currently_selected - self:getMaxScroll()
    end

    if self.currently_selected <= self.scroll_offset then
        self.scroll_offset = self.currently_selected - 1
    end

    for i, option in ipairs(self.options) do
        option:setHovered(i == self.currently_selected)
        local position = i - 1 - self.scroll_offset
        option:setPosition(0, 38 + (position * self:getOptionHeight()))
        if self.options_hidden then
            option.visible = false
        else
            if position < 0 or position >= self:getMaxScroll() then
                option.visible = false
            else
                option.visible = true
            end
        end
    end
end

--- Removes an option from the menu.
---@param index integer
---@return DarkConfigOption option
function DarkConfigMenu:removeOption(index)
    if index < 1 or index > #self.options then
        error("DarkConfigMenu:removeOption() - Index out of bounds")
    end

    local option = self.options[index]

    option:remove()
    option:setAdded(false)
    table.remove(self.options, index)

    self:updateConfigOptions()

    return option
end

--- Removes an option from the menu.
---@generic T : DarkConfigOption
---@param child T
---@return T? option
function DarkConfigMenu:removeOptionByChild(child)
    for i, option in ipairs(self.options) do
        if option == child then
            self:removeOption(i)
            return child
        end
    end

    error("DarkConfigMenu:removeOptionByChild() - Child not found in options")
end

--- Inserts an option into the menu at a specific index.
---@generic T : DarkConfigOption
---@param index integer
---@param option T
---@return T option
function DarkConfigMenu:insertOption(index, option)
    if index < 1 or index > #self.options + 1 then
        error("DarkConfigMenu:insertOption() - Index out of bounds")
    end

    self:addChild(option)

    ---@cast option DarkConfigOption
    option:setAdded(true)

    table.insert(self.options, index, option)

    self:updateConfigOptions()

    return option
end

--- Adds an option to the menu.
---@generic T : DarkConfigOption
---@param option T
---@return T option
function DarkConfigMenu:addOption(option)
    ---@cast option DarkConfigOption
    self:addChild(option)
    option:setAdded(true)

    table.insert(self.options, option)

    self:updateConfigOptions()

    return option
end

function DarkConfigMenu:setState(state)
    local old_state = self.state
    self.state_manager:setState(state)
    self:onStateChanged(old_state, state)
end

function DarkConfigMenu:getState()
    return self.state
end

function DarkConfigMenu:showOptions()
    self.options_hidden = false
    self.config_text.visible = true

    self:updateConfigOptions()
end

function DarkConfigMenu:hideOptions()
    self.options_hidden = true
    self.config_text.visible = false

    self:updateConfigOptions()
end

function DarkConfigMenu:onStateChanged(old, new)
    for _, option in ipairs(self.options) do
        option:onStateChanged(old, new)
    end
end

--- Registers the default options.
---
--- If "forced fullscreen" is enabled (consoles, phones) then the fullscreen option is not present, and replaced with the border option.
function DarkConfigMenu:registerDefaults()
    self:addOption(DarkConfigVolumeOption(self))

    self:addOption(DarkConfigOption(self, "Controls", function()
        self:setState("REBIND")
    end))

    self:addOption(DarkConfigBooleanOption(self, "Simplify VFX", function(option)
        Kristal.Config["simplifyVFX"] = not Kristal.Config["simplifyVFX"]
        option:setEnabled(Kristal.Config["simplifyVFX"])
    end, Kristal.Config["simplifyVFX"]))

    if not Kristal.isForcedFullscreen() then
        self:addOption(DarkConfigBooleanOption(self, "Fullscreen", function(option)
            Kristal.Config["fullscreen"] = not Kristal.Config["fullscreen"]
            love.window.setFullscreen(Kristal.Config["fullscreen"])
            option:setEnabled(Kristal.Config["fullscreen"])
        end, Kristal.Config["fullscreen"]))
    end

    self:addOption(DarkConfigBooleanOption(self, "Auto-Run", function(option)
        Kristal.Config["autoRun"] = not Kristal.Config["autoRun"]
        option:setEnabled(Kristal.Config["autoRun"])
    end, Kristal.Config["autoRun"]))

    if Kristal.isForcedFullscreen() then
        self:addOption(DarkConfigBorderOption(self))
    end
end

function DarkConfigMenu:onKeyPressed(key)
    self.state_manager:call("keyPressed", key)
end

function DarkConfigMenu:updateMainState()
    if Input.pressed("confirm") then
        Assets.stopAndPlaySound("ui_select")

        local option = self.options[self.currently_selected]
        if option ~= nil then
            option:onSelected()
        end

        return
    end

    if Input.pressed("cancel") then
        Assets.stopAndPlaySound("ui_cancel_small")
        Game.world.menu:closeBox()
        return
    end

    if Input.pressed("up") then
        self.currently_selected = self.currently_selected - 1
        Assets.stopAndPlaySound("ui_move")
    end
    if Input.pressed("down") then
        self.currently_selected = self.currently_selected + 1
        Assets.stopAndPlaySound("ui_move")
    end

    self.currently_selected = MathUtils.clamp(self.currently_selected, 1, #self.options)

    self:updateConfigOptions()
end

-- Responsible for drawing the scroll bar in the main state.
function DarkConfigMenu:drawMainState()
    local item_count = #self.options

    if item_count <= self:getMaxScroll() then
        return
    end

    local x = 469
    local y = 38

    local bar_size = 190

    if item_count > self:getMaxScroll() then
        Draw.setColor(1, 1, 1)
        local sine_off = math.sin((Kristal.getTime() * 30) / 12) * 3
        if self.scroll_offset + self:getMaxScroll() < item_count then
            Draw.draw(self.arrow_sprite, x + 0, y + bar_size + 39 + sine_off)
        end
        if self.scroll_offset > 0 then
            Draw.draw(self.arrow_sprite, x + 0, y + 14 - sine_off, 0, 1, -1)
        end
    end

    if item_count <= 12 then
        Draw.setColor(1, 1, 1)
        for i = 1, item_count do
            local percentage = (i - 1) / (item_count - 1)
            if i == self.currently_selected then
                love.graphics.rectangle("fill", x + 1, y + 21 + percentage * bar_size, 10, 10)
            else
                love.graphics.rectangle("fill", x + 4, y + 25 + percentage * bar_size, 4, 4)
            end

            return
        end
        if Input.pressed("confirm") then
            if self.currently_selected < 10 then
                Assets.stopAndPlaySound("ui_select")
                self.rebinding = true
                return
            end

            if self.currently_selected == 10 then
                Assets.playSound("levelup")

                if Kristal.isConsole() then
                    Input.resetBinds(true)  -- Console, no keyboard, only reset gamepad binds
                elseif Input.hasGamepad() then
                    Input.resetBinds()      -- PC, keyboard and gamepad, reset all binds
                else
                    Input.resetBinds(false) -- PC, no gamepad, only reset keyboard binds
                end
                Input.saveBinds()
                self.reset_flash_timer = 10
            end

            if self.currently_selected == 11 then
                self.reset_flash_timer = 0
                self.state = "MAIN"
                self.currently_selected = 2

                Assets.stopAndPlaySound("ui_select")

                Input.clear("confirm", true)
            end
            return
        end

        if Input.pressed("cancel") and not self.rebinding then
            self.reset_flash_timer = 0
                self.state = "MAIN"
                self.currently_selected = 2

                Assets.stopAndPlaySound("ui_select")

                Input.clear("cancel", true)
            return
        end

        local old_selected = self.currently_selected
        if Input.pressed("up") then
            self.currently_selected = self.currently_selected - 1
        end
        if Input.pressed("down") then
            self.currently_selected = self.currently_selected + 1
        end

        self.currently_selected = MathUtils.clamp(self.currently_selected, 1, 11)

        if old_selected ~= self.currently_selected then
            Assets.stopAndPlaySound("ui_move")
        end
    else
        Draw.setColor(0.25, 0.25, 0.25)
        love.graphics.rectangle("fill", x + 4, y + 24, 6, bar_size + 9)
        local percent = self.scroll_offset / (item_count - self:getMaxScroll())
        Draw.setColor(1, 1, 1)
        love.graphics.rectangle("fill", x + 4, y + 24 + math.floor(percent * bar_size), 6, 6)
    end
end

function DarkConfigMenu:onExitState()
    self:hideOptions()
end

function DarkConfigMenu:update()
    self.alpha = 1 - Game.world.menu.flicker_dur
    self.confirm_siner = self.confirm_siner + (DTMULT /8)
    self.reset_siner = self.reset_siner + (DTMULT /8)
    if self.state == "MAIN" then
        if Input.pressed("confirm") then
            Assets.stopAndPlaySound("ui_select")

            if Kristal.isForcedFullscreen() then
                if self.currently_selected == 4 then
                    Kristal.Config["autoRun"] = not Kristal.Config["autoRun"]
                    return
                end

                if self.currently_selected == 5 then
                    self.state = "BORDERS"
                    return
                end
            else
                if self.currently_selected == 4 then
                    Kristal.Config["fullscreen"] = not Kristal.Config["fullscreen"]
                    love.window.setFullscreen(Kristal.Config["fullscreen"])
                    return
                elseif self.currently_selected == 5 then
                    Kristal.Config["autoRun"] = not Kristal.Config["autoRun"]
                    return
                end
            end

            if self.currently_selected == 1 then
                self.state = "VOLUME"
                self.noise_timer = 0
            elseif self.currently_selected == 2 then
                self.state = "CONTROLS"
                self.currently_selected = 1
            elseif self.currently_selected == 3 then
                Kristal.Config["simplifyVFX"] = not Kristal.Config["simplifyVFX"]
            elseif self.currently_selected == 6 then
                Game:returnToMenu()
            elseif self.currently_selected == 7 then
                Game.world.menu:closeBox()
            end

            return
        end

        if Input.pressed("cancel") then
            self.ui_cancel_small:stop()
            self.ui_cancel_small:play()
            Game.world.menu:closeBox()
            return
        end

        if Input.pressed("up") then
            self.currently_selected = self.currently_selected - 1
            self.ui_move:stop()
            self.ui_move:play()
        end
        if Input.pressed("down") then
            self.currently_selected = self.currently_selected + 1
            self.ui_move:stop()
            self.ui_move:play()
        end

        self.currently_selected = MathUtils.clamp(self.currently_selected, 1, 7)
    elseif self.state == "VOLUME" then
        if Input.pressed("cancel") or Input.pressed("confirm") then
            Kristal.setVolume(MathUtils.round(Kristal.getVolume() * 100) / 100)
            self.ui_select:stop()
            self.ui_select:play()
            self.state = "MAIN"
            return
        end

        self.noise_timer = self.noise_timer + DTMULT
        if Input.down("left") then
            Kristal.setVolume(Kristal.getVolume() - ((2 * DTMULT) / 100))
            if self.noise_timer >= 3 then
                self.noise_timer = self.noise_timer - 3
                Assets.stopAndPlaySound("noise")
            end
        end
        if Input.down("right") then
            Kristal.setVolume(Kristal.getVolume() + ((2 * DTMULT) / 100))
            if self.noise_timer >= 3 then
                self.noise_timer = self.noise_timer - 3
                Assets.stopAndPlaySound("noise")
            end
        end
        if (not Input.down("right")) and (not Input.down("left")) then
            self.noise_timer = 3
        end
    elseif self.state == "BORDERS" then
        if Input.pressed("cancel") or Input.pressed("confirm") then
            self.state = "MAIN"
            return
        end

        local types = Kristal.getBorderTypes()

        local border_index = -1
        for current_index, border in ipairs(types) do
            if border[1] == Kristal.Config["borders"] then
                border_index = current_index
            end
        end
        if border_index == -1 then
            border_index = 1
        end

        local old_index = border_index
        if Input.pressed("left") then
            border_index = math.max(border_index - 1, 1)
        end
        if Input.pressed("right") then
            border_index = math.min(border_index + 1, #types)
        end

        if old_index ~= border_index then
            Kristal.Config["borders"] = types[border_index][1]

            if types[border_index][1] == "off" then
                Kristal.resetWindow()
            elseif types[old_index][1] == "off" then
                Kristal.resetWindow()
            end
        end
    end

    self.reset_flash_timer = math.max(self.reset_flash_timer - DTMULT, 0)

    super.update(self)
end

function DarkConfigMenu:draw()
    Draw.setColor(1,1,1,1)
    love.graphics.stencil(function()
            love.graphics.circle("fill", SCREEN_WIDTH/2 - self.x, SCREEN_HEIGHT/2 - self.y, 162)
        end, "replace", 1)
    love.graphics.setStencilTest("greater", 0)
    if Game.state == "EXIT" then
        super.draw(self)
        love.graphics.setStencilTest()
        return
    end
    love.graphics.setFont(self.font)
    Draw.setColor(PALETTE["world_text"], self.alpha)
    local x_offset = function (index)
        return (math.abs(index - (7/2))/3.5) * 30
    end
    if self.state ~= "CONTROLS" then
        love.graphics.print("CONFIG", 198, -12)
        if (self.currently_selected == 1) then Draw.setColor({Game:getSoulColor()}, self.alpha) end
        if self.state == "VOLUME" then
            Draw.setColor(PALETTE["world_text_selected"], self.alpha)
        end
        
        love.graphics.print("Master Volume", 88 + x_offset(0), 28 + (0 * 35))
        Draw.setColor(PALETTE["world_text"], self.alpha)
        if (self.currently_selected == 2) then Draw.setColor(PALETTE["world_text_hover"], self.alpha) end
        love.graphics.print("Controls", 88 + x_offset(2), 28 + (1 * 35))
        Draw.setColor(PALETTE["world_text"], self.alpha)
        if (self.currently_selected == 3) then Draw.setColor(PALETTE["world_text_hover"], self.alpha) end
        love.graphics.print("Simplify VFX", 88 + x_offset(3), 28 + (2 * 35))
        Draw.setColor(PALETTE["world_text"], self.alpha)
        if (self.currently_selected == 4) then Draw.setColor(PALETTE["world_text_hover"], self.alpha) end
        love.graphics.print("Fullscreen", 88 + x_offset(4), 28 + (3 * 35))
        Draw.setColor(PALETTE["world_text"], self.alpha)
        if (self.currently_selected == 5) then Draw.setColor(PALETTE["world_text_hover"], self.alpha) end
        love.graphics.print("Auto-Run", 88 + x_offset(5), 28 + (4 * 35))
        Draw.setColor(PALETTE["world_text"], self.alpha)
        if (self.currently_selected == 6) then Draw.setColor(PALETTE["world_text_hover"], self.alpha) end
        love.graphics.print("Return to Title", SCREEN_WIDTH / 4.5, 28 + (5 * 35))
        Draw.setColor(PALETTE["world_text"], self.alpha)
        if (self.currently_selected == 7) then Draw.setColor(PALETTE["world_text_hover"], self.alpha) end
        love.graphics.print("Back", SCREEN_WIDTH / 3, 28 + (6 * 35))

        Draw.setColor(PALETTE["world_text"], self.alpha)
        if (self.currently_selected == 1) then Draw.setColor(PALETTE["world_text_hover"], self.alpha) end
        if self.state == "VOLUME" then
            Draw.setColor(PALETTE["world_text_selected"], self.alpha)
        end
        love.graphics.print(MathUtils.round(Kristal.getVolume() * 100) .. "%", 348-x_offset(0) - (math.max(0, (#tostring(Kristal.getVolume()*100)-2)) * 8), 28 + (0 * 32))
        Draw.setColor(PALETTE["world_text"], self.alpha)
        if (self.currently_selected == 3) then Draw.setColor(PALETTE["world_text_hover"], self.alpha) end
        love.graphics.print(Kristal.Config["simplifyVFX"] and "ON" or "OFF", 348 - x_offset(3), 28 + (2 * 35))
        Draw.setColor(PALETTE["world_text"], self.alpha)
        if (self.currently_selected == 4) then Draw.setColor(PALETTE["world_text_hover"], self.alpha) end
        love.graphics.print(Kristal.Config["fullscreen"] and "ON" or "OFF", 348 - x_offset(4), 28 + (3 * 35))
        Draw.setColor(PALETTE["world_text"], self.alpha)
        if (self.currently_selected == 5) then Draw.setColor(PALETTE["world_text_hover"], self.alpha) end
        love.graphics.print(Kristal.Config["autoRun"] and "ON" or "OFF", 348 - x_offset(5), 28 + (4 * 35))

        --Draw.setColor(Game:getSoulColor())
        
        --Draw.draw(self.heart_sprite, 63 + x_offset(self.currently_selected), 38 + ((self.currently_selected - 1) * 35))
    else
        -- NOTE: This is forced to true if using a PlayStation in DELTARUNE... Kristal doesn't have a PlayStation port though.
        local dualshock = Input.getControllerType() == "ps4"

        love.graphics.print("Function", 161, -8)
        -- Console accuracy for the Heck of it
        if not Kristal.isConsole() then
            love.graphics.print("Key", 283, -8)
        end
        if Input.hasGamepad() then
            love.graphics.print(Kristal.isConsole() and "Button" or "Gamepad", 283, -8)
        end

        for index, name in ipairs(Input.order) do
            if index > 9 then
                break
            end
            Draw.setColor(PALETTE["world_text"], self.alpha)
            if self.currently_selected == index then
                if self.rebinding then
                    Draw.setColor(PALETTE["world_text_rebind"], self.alpha)
                else
                    Draw.setColor(PALETTE["world_text_hover"], self.alpha)
                end
            end

            if dualshock then
                love.graphics.print(name:gsub("_", " "):upper(), 161, -14 + (29 * index))
            else
                love.graphics.print(name:gsub("_", " "):upper(), 161, -14 + (28 * index) + 4)
            end

            local shown_bind = self:getBindNumberFromIndex(index)

            if not Kristal.isConsole() then
                local alias = Input.getBoundKeys(name, false)[1]
                if type(alias) == "table" then
                    local title_cased = {}
                    for _, word in ipairs(alias) do
                        table.insert(title_cased, StringUtils.titleCase(word))
                    end
                    love.graphics.print(table.concat(title_cased, "+"), 283, -10 + (28 * index))
                elseif alias ~= nil then
                    love.graphics.print(StringUtils.titleCase(alias), 283, -10 + (28 * index))
                end
            end

            Draw.setColor(1, 1, 1, self.alpha)

            if Input.hasGamepad() then
                local alias = Input.getBoundKeys(name, true)[1]
                if alias then
                    local btn_tex = Input.getButtonTexture(alias)
                    if dualshock then
                        Draw.draw(btn_tex, 283 + 42, -10 + (29 * index), 0, 2, 2, btn_tex:getWidth() / 2, 0)
                    else
                        Draw.draw(btn_tex, 283 + 42 + 16 - 6, -10 + (28 * index) + 11 - 6 + 1, 0, 2, 2,
                                  btn_tex:getWidth() / 2, 0)
                    end
                end
            end
        end

        Draw.setColor(COLORS.red, self.alpha)
        if self.currently_selected == 10 then
            Draw.setColor(PALETTE["world_text_hover"], self.alpha)
        end

        if (self.reset_flash_timer > 0) then
            Draw.setColor(ColorUtils.mergeColor(PALETTE["world_text_hover"], PALETTE["world_text_selected"],
                                           ((self.reset_flash_timer / 10) - 0.1)), self.alpha)
        end

        -- if dualshock then
        --     love.graphics.print("Reset to default", 23, -4 + (29 * 8))
        -- else
        --     love.graphics.print("Reset to default", 23, -4 + (28 * 8) + 4)
        -- end

        Draw.draw(self.reset_sprite, 94 + math.cos(self.confirm_siner) * 2, 80 + math.sin(self.reset_siner) * 2, 0, 2, 2)

        Draw.setColor(COLORS.lime, self.alpha)
        if self.currently_selected == 11 then
            Draw.setColor(PALETTE["world_text_hover"], self.alpha)
        end

        Draw.draw(self.confirm_sprite, 94 + math.sin(self.reset_siner) * 2, 140 + math.cos(self.confirm_siner) * 2, 0, 2, 2)

        

        -- if dualshock then
        --     love.graphics.print("Finish", 23, -4 + (29 * 9))
        -- else
        --     love.graphics.print("Finish", 23, -4 + (28 * 9) + 4)
        -- end

        

        --Draw.setColor(Game:getSoulColor())

        -- if dualshock then
        --     Draw.draw(self.heart_sprite, -2, 34 + ((self.currently_selected - 1) * 29))
        -- else
        --     Draw.draw(self.heart_sprite, -2, 34 + ((self.currently_selected - 1) * 28) + 2)
        -- end
    end

    Draw.setColor(1, 1, 1, 1)

    love.graphics.setStencilTest()

    super.draw(self)
end

return DarkConfigMenu
