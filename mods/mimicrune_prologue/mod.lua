function Mod:init()
    self.playtest = false

    print("Loaded " .. self.info.name .. "!")
end

function Mod:getUISkin(skin)
    return skin or "DEVICE"
end

function Mod:postInit(new_file)
    love.window.setTitle("INTERFACE")
    if new_file then
        if Game.world.player then
            Game.world.player.visible = false
        end
        Game:setFlag("playtest_mode", self.playtest)
        Game:setFlag("audible_footsteps", true)

        if self.playtest then
            Game.world:startCutscene("connection", "battle_test")
        else
            Game.world:startCutscene("connection", "startup")
        end
    end
end

function Mod:onDrawText(text, node, state, x, y, scale, font, use_color)
    if not text:includes(DialogueText) then
        return
    end

    if text.connection then
        text.draw_every_frame = true
        text.specfade = text.specfade or 1
        node.height_mult = node.height_mult or 0.5

        y = y + ((1 - node.height_mult) * font:getHeight())

        local scale_y = scale * node.height_mult
        local scale_x = scale / node.height_mult
        local r, g, b, a = text:getTextColor(state, use_color)

        Draw.setColor(r, g, b, a * text.specfade)
        love.graphics.print(node.character, x, y, 0, scale_x, scale_y)

        Draw.setColor(r, g, b, a * ((0.3 + (math.sin(text.timer / 14) * 0.1)) * text.specfade))
        love.graphics.print(node.character, x + 2, y, 0, scale_x, scale_y)
        love.graphics.print(node.character, x - 2, y, 0, scale_x, scale_y)
        love.graphics.print(node.character, x, y + 2, 0, scale_x, scale_y)
        love.graphics.print(node.character, x, y - 2, 0, scale_x, scale_y)

        Draw.setColor(r, g, b, a * ((0.08 + (math.sin(text.timer / 14) * 0.04)) * text.specfade))
        love.graphics.print(node.character, x + 2, y, 0, scale_x, scale_y)
        love.graphics.print(node.character, x - 2, y, 0, scale_x, scale_y)
        love.graphics.print(node.character, x, y + 2, 0, scale_x, scale_y)
        love.graphics.print(node.character, x, y - 2, 0, scale_x, scale_y)

        Draw.setColor(r, g, b, 1)
        node.height_mult = MathUtils.lerp(node.height_mult, 1, 0.6)
    end

    if state.temp_shake > 0 then
        if text.timer - state.last_temp_shake >= DTMULT then
            state.last_temp_shake = text.timer
            state.offset_x = MathUtils.round(MathUtils.random(-state.temp_shake, state.temp_shake))
            state.offset_y = MathUtils.round(MathUtils.random(-state.temp_shake, state.temp_shake))
        end
        state.temp_shake = MathUtils.approach(state.temp_shake, 0, 8 * DT)
    end
end

---@param text Text|DialogueText
function Mod:registerTextCommands(text)
    if not text:includes(DialogueText) then
        return
    end

    text:registerCommand("tempshake", function(command_text, node, dry)
        command_text.state.temp_shake = tonumber(node.arguments[1]) or 1
        command_text.draw_every_frame = true
    end)
end

function Mod:shakifyText(text)
    local no_sound = { "\n", " ", "^", "!", ".", "?", ",", ":", "/", "\\", "|", "*" }
    local output = ""
    local is_command = false

    for i = 1, #text do
        local character = text:sub(i, i)
        if character == "[" then
            is_command = true
        end

        if not is_command and not TableUtils.contains(no_sound, character) then
            output = output .. "[tempshake:4]"
        end
        output = output .. character

        if character == "]" then
            is_command = false
        end
    end

    return output .. "[tempshake:0]"
end
