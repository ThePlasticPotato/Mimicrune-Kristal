local ActionBoxDisplay, super = Class(ActionBoxDisplay)

local function map(tbl, func)
    local result = {}
    for index, value in ipairs(tbl) do
        result[index] = func(value, index)
    end
    return result
end

local function getConfig(name)
    return Kristal.getLibConfig("rolling-health", name)
end

function ActionBoxDisplay:drawCurrentHealth(color, x, y)
    local battler = self.actbox.battler
    local string_from = tostring(battler.health_rolling_last)
    local string_to = tostring(battler.chara:getHealth())
    local max_string_length = math.max(#string_from, #string_to)
    for i = 1, max_string_length - #string_from do
        string_from = ' ' .. string_from
    end
    for i = 1, max_string_length - #string_to do
        string_to = ' ' .. string_to
    end
    local health_offset = (max_string_length - 1) * 8
    x = x - health_offset
    local roll_progress = MathUtils.clamp((battler.health_rolling_timer / battler:getRollSpeed()) * getConfig("display_roll_speed"), 0, 1)
    local rolling_down = battler.chara:getHealth() < battler.health_rolling_last
    if rolling_down then roll_progress = 1 - roll_progress end
    if getConfig("stencil") then
        love.graphics.stencil(function()
            love.graphics.rectangle("fill", x, y, health_offset + 8, 10)
        end, "replace", 1)
        love.graphics.setStencilTest("equal", 1)
    end
    for i = 1, max_string_length do
        local number_from, number_to = string_from[i] or '', string_to[i] or ''
        if number_from == number_to then
            Draw.setColor(color)
            love.graphics.print(number_from, x + (i - 1) * 8, y)
        else
            -- Looks horrible (but it works)
            local function drawNumber(number, first, dark)
                Draw.setColor(map(color, function(value, index)
                    if index == 4 then return getConfig("change_alpha") and (first and roll_progress or (1 - roll_progress)) or value
                    else return (dark and getConfig("darken_previous")) and value * 0.25 or value
                    end
                end))
                love.graphics.print(number, x + (i - 1) * 8, y + (roll_progress - (first and 1 or 0)) * 12)
            end
            if rolling_down then
                drawNumber(number_to, false, false)
                drawNumber(number_from, true, true)
            else
                drawNumber(number_from, false, true)
                drawNumber(number_to, true, false)
            end
        end
    end
    if getConfig("stencil") then
        love.graphics.setStencilTest()
    end
end

-- function ActionBoxDisplay:draw()
--     if Game.battle.current_selecting == self.actbox.index then
--         Draw.setColor(self.actbox.battler.chara:getColor())
--     else
--         Draw.setColor(PALETTE["action_strip"], 1)
--     end

--     love.graphics.setLineWidth(2)
--     love.graphics.line(0  , Game:getConfig("oldUIPositions") and 2 or 1, 213, Game:getConfig("oldUIPositions") and 2 or 1)

--     love.graphics.setLineWidth(2)
--     if Game.battle.current_selecting == self.actbox.index then
--         love.graphics.line(1  , 2, 1,   36)
--         love.graphics.line(212, 2, 212, 36)
--     end

--     Draw.setColor(PALETTE["action_fill"])
--     love.graphics.rectangle("fill", 2, Game:getConfig("oldUIPositions") and 3 or 2, 209, Game:getConfig("oldUIPositions") and 34 or 35)

--     Draw.setColor(PALETTE["action_health_bg"])
--     love.graphics.rectangle("fill", 128, 22 - self.actbox.data_offset, 76, 9)

--     local health = (self.actbox.battler.chara:getHealth() / self.actbox.battler.chara:getStat("health")) * 76

--     if health > 0 then
--         Draw.setColor(self.actbox.battler.chara:getColor())
--         love.graphics.rectangle("fill", 128, 22 - self.actbox.data_offset, math.ceil(health), 9)
--     end

--     local health_rolling_diff = ((self.actbox.battler.health_rolling_to - self.actbox.battler.chara:getHealth()) / self.actbox.battler.chara:getStat("health")) * 76
--     if health_rolling_diff ~= 0 and health > 0 then
--         Draw.setColor(map({self.actbox.battler.chara:getColor()}, function(value, index)
--             if index == 4 then return value
--             else
--                 return value * 0.75
--             end
--         end))
--         local x_start = health
--         local width = health_rolling_diff
--         if health_rolling_diff < 0 then
--             x_start = math.ceil(health + width)
--             width = math.ceil(width) - 1
--         end
--         -- Kristal.Console:log(x_start + math.abs(math.floor(width)))
--         love.graphics.rectangle("fill", 128 + x_start, 22 - self.actbox.data_offset, math.abs(width), 9)
--     end

--     local color = PALETTE["action_health_text"]
--     if health <= 0 then
--         color = PALETTE["action_health_text_down"]
--     elseif (self.actbox.battler.chara:getHealth() <= (self.actbox.battler.chara:getStat("health") / 4)) then
--         color = PALETTE["action_health_text_low"]
--     else
--         color = PALETTE["action_health_text"]
--     end

--     local mortal_damage_color = getConfig("mortal_damage_color")
--     if mortal_damage_color and self.actbox.battler.health_rolling_to <= 0 and health > 0 then
--         color = mortal_damage_color
--     end

--     love.graphics.setFont(self.font)
--     self:drawCurrentHealth(color, 152, 9 - self.actbox.data_offset)
--     Draw.setColor(PALETTE["action_health_text"])
--     love.graphics.print("/", 161, 9 - self.actbox.data_offset)
--     local string_width = self.font:getWidth(tostring(self.actbox.battler.chara:getStat("health")))
--     Draw.setColor(color)
--     love.graphics.print(self.actbox.battler.chara:getStat("health"), 205 - string_width, 9 - self.actbox.data_offset)

--     super.super.draw(self)
-- end

return ActionBoxDisplay