---@class SettingsMenu: Object
---@overload fun(): SettingsMenu
local SettingsMenu, super = Class(Object)

function SettingsMenu:init()
    super.init(self)
    self.heart_target_x, self.heart_target_y = 0,0
    self.state_manager = StateManager("", self, true)
    self.options = MainMenuOptions(self)
    self.deadzone_config = MainMenuDeadzone(self)
    self.state_manager:addState("OPTIONS", self.options)

    -- OPTIONS substates
    self.state_manager:addState("CONTROLS", MainMenuControls(self--[[@as MainMenu]]))
    self.state_manager:addState("DEFAULTNAME", MainMenuDefaultName(self--[[@as MainMenu]]))
    self.state_manager:addState("DEADZONE", self.deadzone_config)
    self.state_manager:addState("DEFAULT", {
        enter = function ()
            self:pushState("OPTIONS")
        end,
        resume = function ()
            Game.world:loadMap("chapter_select")
            self.heart.visible = false
        end
    })

    self.font = Assets.getFont("main")
    
    self.heart = Sprite("player/heart_menu")
    self.heart.visible = true
    self.heart:setOrigin(0.5, 0.5)
    self.heart:setScale(2, 2)
    self.heart:setColor(Kristal.getSoulColor())
    self.heart.layer = 100
    self:addChild(self.heart)
end

function SettingsMenu:onAddToStage()
    self.state_manager:setState("DEFAULT")
end

function SettingsMenu:setState(state, ...)
    self.state_manager:setState(state, ...)
end

function SettingsMenu:pushState(state, ...)
    self.state_manager:pushState(state, ...)
end

function SettingsMenu:popState(...)
    self.state_manager:popState(...)
end

function SettingsMenu:draw()
    love.graphics.setFont(self.font)
    self.state_manager:draw()
    super.draw(self)
end

function SettingsMenu:update()
    super.update(self)
    self.state_manager:update()
    self.heart.x = self.heart_target_x
    self.heart.y = self.heart_target_y
end

function SettingsMenu:loadGame(id)
    local path = "saves/" .. Mod.info.id .. "/file_" .. id .. ".json"
    local fade = true
    if love.filesystem.getInfo(path) then
        local data = JSON.decode(love.filesystem.read(path))
        Game:load(data, id, fade)
    else
        Game:load(nil, id, fade)
    end
end

function SettingsMenu:onKeyPressed(key, is_repeat)
    self.state_manager:call("keypressed", key, is_repeat)
end

function SettingsMenu:onKeyReleased(key)
    self.state_manager:call("keyreleased", key)
end

return SettingsMenu