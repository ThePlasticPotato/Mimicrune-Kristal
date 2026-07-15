---@class MainMenuTitle : StateClass
---
---@field menu MainMenu
---
---@field logo love.Image
---@field has_target_saves boolean
---
---@field options table
---@field selected_option number
---
---@overload fun(menu:MainMenu) : MainMenuTitle
local MainMenuTitle, super = Class(StateClass)

function MainMenuTitle:init(menu)
    self.menu = menu

    self.logo = Assets.getTexture("kristal/title_logo_fake")
    self.logo_soul = Assets.getTexture("kristal/title_logo_heart") 

    self.selected_option = 1
end

function MainMenuTitle:registerEvents()
    self:registerEvent("enter", self.onEnter)
    self:registerEvent("keypressed", self.onKeyPressed)
    self:registerEvent("draw", self.draw)
end

-------------------------------------------------------------------------------
-- Callbacks
-------------------------------------------------------------------------------

function MainMenuTitle:onEnter(old_state)
    self.has_target_saves = TARGET_MOD and Kristal.hasAnySaves(TARGET_MOD) or false

    if (self.menu.seen_intro) then
        self.logo = Assets.getTexture("kristal/title_logo")
    end

    if TARGET_MOD then
        self.options = {
            { "play", (self.menu.seen_intro and self.has_target_saves) and "CONTINUE" or "CONNECT" },
            { "options", "OPTIONS" },
            { "credits", "CREDITS" },
            { "quit", "ESCAPE" },
        }
    else
        self.options = {
            { "play", "Play" },
            { "modfolder", "Open folder" },
            { "options", "Options" },
            { "credits", "Credits" },
            { "wiki", "Open wiki" },
            { "quit", "Quit" },
        }
    end

    if not TARGET_MOD then
        self.menu.selected_mod = nil
        self.menu.selected_mod_button = nil
    else
        local mod = Kristal.Mods.getMod(TARGET_MOD)
        if mod and mod.soulColor then
            self.menu.heart:setColor(mod.soulColor)
        end
    end

    self.menu.heart_target_x = 159
    self.menu.heart_target_y = 138 + 64 + 32 * (self.selected_option - 1)

    local option = self.options[self.selected_option][1]
    self.menu.bg_heal.fade_in = (option == "play")
end

function MainMenuTitle:onKeyPressed(key, is_repeat)
    if Input.isConfirm(key) then
        Assets.stopAndPlaySound("ui_select_camera")

        local option = self.options[self.selected_option][1]

        if option == "play" then
            if not TARGET_MOD then
                self.menu:setState("MODSELECT")
            else
                local realTarget = (self.seen_intro) and "mimicrune_chapter_select" or "mimicrune_prologue"
                local mod = Kristal.Mods.getMod(realTarget)

                if (mod["useSaves"] == true) or (mod["useSaves"] == nil and self.has_target_saves) then
                    self.menu:setState("FILESELECT")
                elseif (mod["useSaves"] == false) or (mod["useSaves"] == nil and not self.has_target_saves) then
                    if not Kristal.loadMod(realTarget, 1) then
                        error("Failed to load mod: " .. realTarget)
                    end
                end
            end

        elseif option == "modfolder" then
            -- FIXME: the game might freeze when using love.system.openURL to open a file directory
            if (love.system.getOS() == "Windows") then
                os.execute('start /B \"\" \"' .. love.filesystem.getSaveDirectory() .. '/mods\"')
            else
                love.system.openURL("file://" .. love.filesystem.getSaveDirectory() .. "/mods")
            end

        elseif option == "options" then
            self.menu:setState("OPTIONS")

        elseif option == "credits" then
            self.menu:setState("CREDITS")

        elseif option == "wiki" then
            love.system.openURL("https://kristal.cc/wiki")

        elseif option == "quit" then
            love.event.quit()
        end

        return true
    end

    local old = self.selected_option
    if Input.is("up", key) then self.selected_option = self.selected_option - 1 end
    if Input.is("down", key) then self.selected_option = self.selected_option + 1 end
    if Input.is("left", key) and not Input.usingGamepad() then self.selected_option = self.selected_option - 1 end
    if Input.is("right", key) and not Input.usingGamepad() then self.selected_option = self.selected_option + 1 end
    if self.selected_option > #self.options then self.selected_option = is_repeat and #self.options or 1 end
    if self.selected_option < 1 then self.selected_option = is_repeat and 1 or #self.options end

    if old ~= self.selected_option then
        Assets.stopAndPlaySound("ui_move_panel")
    end

    self.menu.heart_target_x = 159
    self.menu.heart_target_y = 138 + 64 + (self.selected_option - 1) * 32

    local option = self.options[self.selected_option][1]
    self.menu.bg_heal.fade_in = (option == "play")
end

function MainMenuTitle:draw()
    local logo_img = self.menu.selected_mod and self.menu.selected_mod.logo or self.logo

    Draw.draw(logo_img, SCREEN_WIDTH / 2 - logo_img:getWidth() / 2, 155 - logo_img:getHeight() / 2)
    if (self.menu.seen_intro) then Draw.draw(self.logo_soul, SCREEN_WIDTH / 2 - logo_img:getWidth() / 2, 155 - logo_img:getHeight() / 2) end
    --Draw.draw(self.selected_mod and self.selected_mod.logo or self.logo, 160, 70)

    for i, option in ipairs(self.options) do
        love.graphics.print(option[2], 178, 119 + 64 + 32 * (i - 1))
    end
end

-------------------------------------------------------------------------------
-- Class Methods
-------------------------------------------------------------------------------

function MainMenuTitle:selectOption(id)
    for i, options in ipairs(self.options) do
        if options[1] == id then
            self.selected_option = i

            self.menu.heart_target_x = 159
            self.menu.heart_target_y = 138 + 64 + (self.selected_option - 1) * 32

            return true
        end
    end

    return false
end

return MainMenuTitle
