---@class SoulGlow : Object
local SoulGlow, super = Class(Object)

function SoulGlow:init(x, y, soul, no_sound)
    super.init(self, x, y)

    self:setScale((not no_sound) and 2 or 1)
    self:setOrigin(0.5, 0.5)

    self.soul = soul
    self.width = 64
    self.height = 64
    self.runtime = 0.0
    self.t = -10
    self.m = 64
    self.momentum = 2.0
    self.scale_offset = 0.0
    self.radius = self.t
    self.remove_when_hidden = false

    if not no_sound then Assets.playSound("snd_greatshine", 1.0, 0.75) end
    self:setColor(250/255, 1, 250/255, 1)
end

function SoulGlow:setShown(shown)
    if shown then
        self.remove_when_hidden = false
        self.momentum = 2.0
        self.visible = true
    else
        self.momentum = 0
        self.visible = false
    end
end

function SoulGlow:hide(dont_remove)
    self.momentum = -2.0
    self.remove_when_hidden = not dont_remove
    if self.radius <= -9 then
        if self.remove_when_hidden then self:remove() end
        self:setShown(false)
    end
end

function SoulGlow:show(sound)
    self:setShown(true)
    if (sound) then
        Assets.playSound("snd_greatshine", 1.0, 0.75)
    end
end

function SoulGlow:update()
    super.update(self)
    self.runtime = self.runtime + (DT/1.5)

    if self.visible and self.momentum == 0 and self.radius <= -9 then
        self:setShown(true)
    end

    if (self.momentum > 0) then
        if (self.radius < (self.m + 2)) then
            self.radius = MathUtils.lerp(self.radius, self.m, 1 - math.exp(-self.momentum * DT))
        end
        if (self.m - self.radius > 0 and self.m - self.radius < 0.001) then
            self.radius = self.m
        end
    end
    if (self.momentum < 0) then
        self.radius = MathUtils.approach(self.radius, self.t, math.abs(self.momentum) * 2 * DTMULT)
        if self.radius <= -9 then
            if self.remove_when_hidden then self:remove() end
            self:setShown(false)
        end
    end

    if (self.radius >= self.m) then
        self.scale_offset = self.scale_offset + math.sin(self.runtime) / 10
    else
        self.scale_offset = 0
    end
end

function SoulGlow:draw()
    super.draw(self)

    if (self.radius >= 0) then
        love.graphics.setLineWidth(math.max(2, 4 + self.scale_offset))
        love.graphics.setColor(100/255, 1, 100/255, 0.05)
        love.graphics.circle("line", 32, 32 + self.soul.pos_offset, (self.radius + self.scale_offset)*1.25)
        love.graphics.setColor(220/255, 1, 220/255, 0.25)
        love.graphics.circle("fill", 32, 32 + self.soul.pos_offset, (self.radius + self.scale_offset))
        love.graphics.setColor(250/255, 1, 250/255, 0.5)
        love.graphics.circle("fill", 32, 32 + self.soul.pos_offset, (self.radius + self.scale_offset)*0.75)
    end
end

return SoulGlow
