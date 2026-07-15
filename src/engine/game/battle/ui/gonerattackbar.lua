---@class GonerAttackBar : Object
---@overload fun(x:number, y:number, width:number, height:number) : GonerAttackBar
local GonerAttackBar, super = Class(Object)

function GonerAttackBar:init(x, y, width, height)
    super.init(self, x, y, width, height)

    self.position = 0
    self.target = 0.72
    self.speed = 0.014
    self.time = 0
    self.active = true
    self.expired = false
    self.hit_flash = 0
end

function GonerAttackBar:lock(hit)
    self.active = false
    self.hit_flash = hit and 1 or 0
end

function GonerAttackBar:update()
    self.time = self.time + DT
    self.target = 0.72 + math.sin(self.time * 2.1) * 0.05
    self.hit_flash = MathUtils.approach(self.hit_flash, 0, 0.08 * DTMULT)

    if self.active then
        local signal_variance = 1 + math.sin(self.time * 8) * 0.18
        self.position = self.position + self.speed * signal_variance * DTMULT
        if self.position >= 1 then
            self.position = 1
            self.active = false
            self.expired = true
            self.scale_x = 0
        end
    end

    super.update(self)
end

function GonerAttackBar:draw()
    local target_x = math.floor(self.target * self.width)
    local marker_x = math.floor(self.position * self.width)

    Draw.setColor(0, 0, 0, 0.25)
    love.graphics.rectangle("fill", 0, 0, self.width, self.height)

    Draw.setColor(COLORS.black)
    love.graphics.setLineWidth(1)
    love.graphics.rectangle("line", 0.5, 0.5, self.width - 1, self.height - 1)
    love.graphics.line(0, self.height / 2, self.width, self.height / 2)

    for tick = 0, 10 do
        local x = math.floor((tick / 10) * self.width) + 0.5
        local tick_height = tick % 5 == 0 and 8 or 4
        love.graphics.line(x, self.height - tick_height, x, self.height)
    end

    Draw.setColor(0, 0, 0, 0.22 + self.hit_flash * 0.45)
    love.graphics.rectangle("fill", target_x - 13, 2, 26, self.height - 4)
    Draw.setColor(COLORS.black)
    love.graphics.rectangle("line", target_x - 13.5, 1.5, 27, self.height - 3)
    love.graphics.setLineWidth(3)
    love.graphics.line(marker_x + 0.5, -3, marker_x + 0.5, self.height + 3)

    Draw.setColor(1, 1, 1, 1)
    love.graphics.setLineWidth(1)
    super.draw(self)
end

return GonerAttackBar
