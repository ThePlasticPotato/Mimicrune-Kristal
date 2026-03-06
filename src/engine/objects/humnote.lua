---@class HumNote : Sprite
local HumNote, super = Class(Sprite)

function HumNote:init(variant, x, y, width, height, base)
    base = base or "effects/cassinote_"
    local real_sprite = base..variant
    super.init(self, real_sprite, x, y, width, height)
    self:setOrigin(0.5, 0.5)
    self.note_timer = 0
    self:flash()
end

function HumNote:update()
    super.update(self)
    self.note_timer = self.note_timer + DT * 4

    self.x = self.x + (math.sin(self.note_timer) * DTMULT)
    self.y = self.y - (DTMULT * 2)
    self.scale_x = MathUtils.approach(self.scale_x, 0, DT / 1.5)
    self.scale_y = self.scale_x

    if (self.scale_x <= 0) then
        self:remove()
    end
end

return HumNote