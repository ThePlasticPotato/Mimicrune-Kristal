---@class DarkConfigMenu : Object
---@overload fun(...) : DarkConfigMenu
local DarkConfigMenu, super = Class(Object)

function DarkConfigMenu:init()
    super.init(self, 82, 112, 477, 277)

    self.draw_children_below = 0

    self.font = Assets.getFont("main")

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
    self.noise_timer = 0

    self.reset_flash_timer = 0
    self.rebinding = false

    self.reset_siner = 0.2125
    self.confirm_siner = 0
end

function DarkConfigMenu:getBindNumberFromIndex(current_index)
    local shown_bind = 1
    local alias = Input.orderedNumberToKey(current_index)
    local keys = Input.getBoundKeys(alias, Input.usingGamepad())
    for index, current_key in ipairs(keys) do
        if Input.usingGamepad() then
            if StringUtils.startsWith(current_key, "gamepad:") then
                shown_bind = index
                break
            end
        else
            if not StringUtils.startsWith(current_key, "gamepad:") then
                shown_bind = index
                break
            end
        end
    end
    return shown_bind
end

function DarkConfigMenu:onKeyPressed(key)
    if self.state == "CONTROLS" then
        if self.rebinding then
            local gamepad = StringUtils.startsWith(key, "gamepad:")

            local worked = key ~= "escape" and
                Input.setBind(Input.orderedNumberToKey(self.currently_selected), 1, key, gamepad)

            self.rebinding = false

            if worked then
                Assets.stopAndPlaySound("ui_select")
            else
                Assets.stopAndPlaySound("ui_cant_select")
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
    end
end

function DarkConfigMenu:update()
    self.alpha = 1 - Game.world.menu.flicker_dur
    self.confirm_siner = self.confirm_siner + (DTMULT /8)
    self.reset_siner = self.reset_siner + (DTMULT /8)
    if self.state == "MAIN" then
        if Input.pressed("confirm") then
            Assets.stopAndPlaySound("ui_select")

            if self.currently_selected == 1 then
                self.state = "VOLUME"
                self.noise_timer = 0
            elseif self.currently_selected == 2 then
                self.state = "CONTROLS"
                self.currently_selected = 1
            elseif self.currently_selected == 3 then
                Kristal.Config["simplifyVFX"] = not Kristal.Config["simplifyVFX"]
            elseif self.currently_selected == 4 then
                Kristal.Config["fullscreen"] = not Kristal.Config["fullscreen"]
                love.window.setFullscreen(Kristal.Config["fullscreen"])
            elseif self.currently_selected == 5 then
                Kristal.Config["autoRun"] = not Kristal.Config["autoRun"]
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
            Draw.setColor(Utils.mergeColor(PALETTE["world_text_hover"], PALETTE["world_text_selected"],
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
