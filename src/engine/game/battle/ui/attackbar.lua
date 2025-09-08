---@class AttackBar : Object
---@overload fun(...) : AttackBar
local AttackBar, super = Class(Object)

function AttackBar:init(x, y, width, height, sprite)
    self.sprite = Assets.getTexture(sprite)
    if (self.sprite) then
        width = self.sprite:getWidth()
        height = self.sprite:getHeight()
    end
    super.init(self, x, y, width, height)
    
    self:setOrigin(0.5, 0.5)

    self.bursting = false
    self.burst_speed = 0.1

    self.in_perfect_range = false
    self.afterimage = false
end

function AttackBar:burst()
    self.bursting = true
    self:fadeOutSpeedAndRemove(0.1)
end

function AttackBar:update()
    if self.bursting then
        self.scale_x = self.scale_x + self.burst_speed * DTMULT
        self.scale_y = self.scale_y + self.burst_speed * DTMULT
    else
        if (not self.afterimage) then self.alpha = Utils.approach(self.alpha, 1.0, DT * 4) end
    end

    super.update(self)
end

function AttackBar:draw()
    --love.graphics.rectangle("fill", 0, 0, self.width, self.height)
    Draw.setColor(1,1,1,self.alpha)

    if (self.in_perfect_range and not self.afterimage) then
        Draw.setColor(COLORS.yellow, self.alpha)
    end

    if (self.sprite) then Draw.draw(self.sprite) end

    Draw.setColor(1,1,1,1)

    super.draw(self)
end

return AttackBar