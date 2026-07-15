---@class GonerBattleMeter : Object
---@overload fun(x:number, y:number, width:number, label:string, orientation?:string, height?:number) : GonerBattleMeter
local GonerBattleMeter, super = Class(Object)

function GonerBattleMeter:init(x, y, width, label, orientation, height)
    super.init(self, x, y, width, height or 38)
    self.font = Assets.getFont("eb")
    self.label = label
    self.orientation = orientation or "horizontal"
    self.value = 0
    self.maximum = 1
    self.value_text = "0 / 0"
end

function GonerBattleMeter:setMeter(label, value, maximum, value_text)
    self.label = label
    self.value = value or 0
    self.maximum = math.max(maximum or 0, 1)
    self.value_text = value_text or tostring(value or 0)
end

function GonerBattleMeter:draw()
    love.graphics.setFont(self.font)
    local fill = MathUtils.clamp(self.value / self.maximum, 0, 1)
    Draw.setColor(COLORS.black)

    if self.orientation == "vertical" then
        love.graphics.printf(self.label, 0, 0, self.width, "center")
        love.graphics.printf(self.value_text, 0, self.font:getHeight(), self.width, "center")

        local bar_width = 12
        local bar_x = math.floor((self.width - bar_width) / 2)
        local bar_y = (self.font:getHeight() * 2) + 5
        local bar_height = self.height - bar_y
        local inner_height = math.max(0, bar_height - 6)
        local fill_height = math.floor(inner_height * fill)

        love.graphics.setLineWidth(1)
        love.graphics.rectangle("line", bar_x + 0.5, bar_y + 0.5, bar_width - 1, bar_height - 1)
        love.graphics.rectangle("fill", bar_x + 3, bar_y + 3 + inner_height - fill_height, bar_width - 6, fill_height)
    else
        love.graphics.print(self.label, 0, 0)
        love.graphics.printf(self.value_text, 0, 0, self.width, "right")

        local bar_y = self.font:getHeight() + 4
        love.graphics.setLineWidth(1)
        love.graphics.rectangle("line", 0.5, bar_y + 0.5, self.width - 1, 10)
        love.graphics.rectangle("fill", 3, bar_y + 3, math.floor((self.width - 6) * fill), 5)
    end
    Draw.setColor(1, 1, 1, 1)

    super.draw(self)
end

return GonerBattleMeter
