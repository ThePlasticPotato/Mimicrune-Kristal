---@class GonerBattleChoicebox : Choicebox
---@overload fun(x:number, y:number, width:number, height:number) : GonerBattleChoicebox
local GonerBattleChoicebox, super = Class(Choicebox)

function GonerBattleChoicebox:init(x, y, width, height)
    super.init(self, x, y, width, height, true)
    self.font = Assets.getFont("eb")
    self.heart = Assets.getTexture("player/heart")
    self:setColors(COLORS.black, COLORS.gray)
end

function GonerBattleChoicebox:draw()
    Object.draw(self)
    love.graphics.setFont(self.font)
    local positions = {
        {18, 10},
        {self.width / 2 + 14, 10},
        {18, 44},
        {self.width / 2 + 14, 44},
    }
    for index, choice in ipairs(self.choices) do
        local x, y = unpack(positions[index])
        Draw.setColor(index == self.current_choice and self.hover_colors[index] or self.main_colors[index])
        love.graphics.print(choice, x + 20, y)
        if index == self.current_choice then
            Draw.setColor(COLORS.black)
            local cursor_offset = (self.font:getHeight() - self.heart:getHeight() * 0.5) / 2
            Draw.draw(self.heart, x, y + cursor_offset, 0, 0.5, 0.5)
        end
    end
end

return GonerBattleChoicebox
