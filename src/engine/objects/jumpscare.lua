---@class Jumpscare : Object
local Jumpscare, super = Class(Object)

function Jumpscare:init(scarer, after)
    super.init(self, 0, 0, SCREEN_WIDTH, SCREEN_HEIGHT)
    self:setLayer(WORLD_LAYERS["top"])
    self.jumpscare_sprite = Sprite("jumpscares/"..scarer)
    self.after = after

    self:addChild(self.jumpscare_sprite)
    self.jumpscare_sprite:play(1/15, false, after)
    Assets.playSound("jumpscares/"..scarer, 1.0, 1.0)
end

return Jumpscare