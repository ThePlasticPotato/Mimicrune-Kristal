---@class maps.chapter_select : Map
local map, super = Class(Map)
function map:init(world,data)
    super.init(self,world,data)
    self.music = "AUDIO_DRONE"
    self.border = "simple"
end
function map:onEnter()
    self.world:openMenu(ChapterSelect())
    self.world.player.visible = false
    -- It's the funniest thing ever! If you press F6, you'll see A SINGLE GREEN PIXEL!!!
    self.world.player:setPosition(-4,19)
    self.world.can_open_menu = false
end

return map
