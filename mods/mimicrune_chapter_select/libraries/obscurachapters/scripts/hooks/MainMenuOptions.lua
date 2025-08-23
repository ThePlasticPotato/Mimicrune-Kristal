---@class MainMenuOptions : MainMenuOptions
---@overload fun(menu: FileSelectMenu): MainMenuOptions
local MainMenuOptions, super = Class("MainMenuOptions")

function MainMenuOptions:onKeyPressed(key)
    if Input.isCancel(key) and self.state == "MENU" then
        Assets.stopAndPlaySound("ui_cancel")
        Kristal.saveConfig()
        self.menu:popState()
        return
    end
    local page = self.pages[self.selected_page]
    local options = self.options[page].options
    local max_option = #options + 1
    if Input.isConfirm(key) and self.selected_option == max_option then        
        Assets.stopAndPlaySound("ui_select")
        -- "Back" button
        Kristal.saveConfig()
        self.menu:popState()
        return
    end
    super.onKeyPressed(self,key)
end

return MainMenuOptions