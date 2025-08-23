---@class maps.chapter_select : Map
local map, super = Class(Map)
function map:init(world,data)
    super.init(self,world,data)
    self.border = "simple"
end

function map:update()
    super.update(self)
end

function map:onEnter()
    Game.world.menu = nil
    self.world.can_open_menu = true
    local menu = self.world:openMenu(SettingsMenu())
    self.world.player.visible = false
    -- It's the funniest thing ever! If you press F6, you'll see A SINGLE GREEN PIXEL!!!
    self.world.player:setPosition(-4,19)
end

return map
