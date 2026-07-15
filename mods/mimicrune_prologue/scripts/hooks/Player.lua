---@class Player
---@field was_running boolean
local Player, super = HookSystem.hookScript(Player)

function Player:init(chara, x, y)
    super.init(self, chara, x, y)
    self.was_running = false
end

function Player:handleMovement()
    super.handleMovement(self)
end

return Player