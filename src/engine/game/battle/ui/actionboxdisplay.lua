---@class ActionBoxDisplay : Object
---@overload fun(...) : ActionBoxDisplay
local ActionBoxDisplay, super = Class(Object)

---@param actbox ActionBox
---@param x number
---@param y number
function ActionBoxDisplay:init(actbox, x, y)
    super.init(self, x, y)

    self.font = Assets.getFont("smallnumbers")

    self.actbox = actbox
end

function ActionBoxDisplay:draw()
    if Game.battle.current_selecting == self.actbox.index then
        Draw.setColor(self.actbox.battler.chara:getColor())
    else
        Draw.setColor(PALETTE["action_strip"], 1)
    end

    Draw.setColor(PALETTE["action_health_bg"])
    love.graphics.rectangle("fill", 21, 39 - self.actbox.data_offset + self.actbox.partypanel_offset, 27, 9)

    local health = (self.actbox.battler.chara:getHealth() / self.actbox.battler.chara:getStat("health")) * 27

    if health > 0 then
        Draw.setColor(self.actbox.battler.chara:getColor())
        love.graphics.rectangle("fill", 21, 39 - self.actbox.data_offset + self.actbox.partypanel_offset, math.ceil(health), 9)
    end


    -- local color = PALETTE["action_health_text"]
    -- if health <= 0 then
    --     color = PALETTE["action_health_text_down"]
    -- elseif (self.actbox.battler.chara:getHealth() <= (self.actbox.battler.chara:getStat("health") / 4)) then
    --     color = PALETTE["action_health_text_low"]
    -- else
    --     color = PALETTE["action_health_text"]
    -- end


    -- local health_offset = 0
    -- health_offset = (#tostring(self.actbox.battler.chara:getHealth()) - 1) * 8

    -- Draw.setColor(color)
    -- love.graphics.setFont(self.font)
    -- love.graphics.print(self.actbox.battler.chara:getHealth(), 152 - health_offset, 9 - self.actbox.data_offset)
    -- Draw.setColor(PALETTE["action_health_text"])
    -- love.graphics.print("/", 161, 9 - self.actbox.data_offset)
    -- local string_width = self.font:getWidth(tostring(self.actbox.battler.chara:getStat("health")))
    -- Draw.setColor(color)
    -- love.graphics.print(self.actbox.battler.chara:getStat("health"), 205 - string_width, 9 - self.actbox.data_offset)

    if (self.actbox.battler.chara.is_psychic) then
        Draw.setColor(63/255, 63/255, 116/255, 1)
        love.graphics.rectangle("fill", 22, 49 - self.actbox.data_offset + self.actbox.partypanel_offset, 25, 2)

        Draw.setColor(70/255, 47/255, 47/255, 1)
        love.graphics.rectangle("fill", 22, 52 - self.actbox.data_offset + self.actbox.partypanel_offset, 25, 2)
        
        local power = (self.actbox.battler.chara.neural_power / 100) * 25
        local heat = (self.actbox.battler.chara.heat / self.actbox.battler.chara:getStat("heat")) * 25

        if (power > 0) then
            Draw.setColor(128/255, 233/255, 1, 1)
            love.graphics.rectangle("fill", 22, 49 - self.actbox.data_offset + self.actbox.partypanel_offset, math.ceil(power), 2)
        end

        if (heat > 0) then
            Draw.setColor(COLORS.red)
            love.graphics.rectangle("fill", 22, 52 - self.actbox.data_offset + self.actbox.partypanel_offset, math.ceil(heat), 2)
        end
        

        Draw.setColor(1,1,1,1)
    end

    if (self.actbox.battler.chara.is_musical) then
        Draw.setColor(112/255, 94/255, 129/255, 1)
        if (self.actbox.battler.chara.notes >= 3) then
            Draw.setColor(195/255, 134/255, 1, 1)
        end
        love.graphics.rectangle("fill", 42, 49 - self.actbox.data_offset + self.actbox.partypanel_offset, 5, 4)
        if (self.actbox.battler.chara.notes >= 2) then
            Draw.setColor(195/255, 134/255, 1, 1)
        end
        love.graphics.rectangle("fill", 32, 49 - self.actbox.data_offset + self.actbox.partypanel_offset, 5, 4)
        if (self.actbox.battler.chara.notes >= 1) then
            Draw.setColor(195/255, 134/255, 1, 1)
        end
        love.graphics.rectangle("fill", 22, 49 - self.actbox.data_offset + self.actbox.partypanel_offset, 5, 4)
        Draw.setColor(1,1,1,1)
    end

    super.draw(self)
end

return ActionBoxDisplay