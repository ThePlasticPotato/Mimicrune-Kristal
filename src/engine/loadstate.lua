local Loading = {}

function Loading:init()
    self.logo = love.graphics.newImage("assets/sprites/kristal/title_logo.png")
    self.logo_fake = love.graphics.newImage("assets/sprites/kristal/title_logo_fake.png")
    self.logo_kristal = love.graphics.newImage("assets/sprites/IMAGE_LOGO.png") --love.graphics.newImage("assets/sprites/kristal/title_logo_kristal.png")
    self.logo_heart = love.graphics.newImage("assets/sprites/kristal/title_logo_heart.png")
    self.glitch_shader = love.graphics.newShader("assets/shaders/kinoglitch.glsl")
    self.font = love.graphics.newFont("assets/fonts/main.ttf", 8, "mono")
    self.wingdings = love.graphics.newFont("assets/fonts/wingdings.ttf", 4, "mono")
    self.dr_icon = love.image.newImageData("assets/sprites/dricon.png")
    self.heart_icon = love.image.newImageData("assets/sprites/hearticon.png")
end

---@enum Loading.States
Loading.States = {
    WAITING = 0,
    LOADING = 1,
    DONE = 2,
}

function Loading:enter(from, dir)
    Mod = nil
    MOD_PATH = nil

    self.loading_state = Loading.States.WAITING

    self.animation_done = false
    self.debug_wait = false
    self.debug_input_buffer = 0

    self.w = self.logo:getWidth()
    self.h = self.logo:getHeight()

    if not Kristal.Config["skipIntro"] then
        if not self.debug_wait then
            self:startIntro()
        end
    else
        self:beginLoad()
    end

    self.siner = 0
    self.factor = 1
    self.factor2 = 0
    self.x = (320 / 2) - (self.w / 2)
    self.y = (240 / 2) - (self.h / 2) - 10
    self.animation_phase = -1
    self.animation_phase_timer = 0
    self.animation_phase_plus = 0
    self.logo_alpha = 1
    self.logo_alpha_2 = 1
    self.skipped = false
    self.skiptimer = 0
    self.key_check = not Kristal.Args["wait"]

    self.fader_alpha = 0

    self.done_loading = false
end

function Loading:startIntro()
    love.window.setTitle("SURVEY_PROGRAM")
    love.window.setIcon(self.dr_icon)
    self.noise = love.audio.newSource("assets/sounds/kristal_intro.ogg", "static")
    self.intro = love.audio.newSource("assets/sounds/titlecard.wav", "static")
    self.end_noise = love.audio.newSource("assets/sounds/kristal_intro_end.ogg", "static")
    self.shine = love.audio.newSource("assets/sounds/snd_greatshine.wav", "static")
    self.glitch1 = love.audio.newSource("assets/sounds/intercept_short_1.ogg", "static")
    self.glitch1:setVolume(0.5)
    self.glitch2 = love.audio.newSource("assets/sounds/intercept_short_2.ogg", "static")
    self.glitch2:setVolume(0.5)
    self.noise:play()
    self.shaking_base_x = 0
    self.shaking_base_y = 0
    self.shaking = false
    self.shake_x = 0
    self.sahke_y = 0
    self.shake_friction = 0
    self.shake_timer = 0
    self.glitch1_played = false
    self.glitch2_played = false
end

-- Inspired by Agent 7's Window Utils, go check that out!
function Loading:shakeWindow(amt_x, amt_y, friction)
    self.shaking_base_x, self.shaking_base_y = love.window.getPosition()
    self.shake_x = amt_x or 4
    self.shake_y = amt_y or 4
    self.shaking = true
    self.shake_friction = friction or 0.25
end

function Loading:beginLoad()
    Kristal.clearAssets(true)

    self.loading_state = Loading.States.LOADING

    Kristal.loadAssets("", "all", "")
    Kristal.loadAssets("", "mods", "", function()
        self.loading_state = Loading.States.DONE

        Assets.saveData()

        Kristal.setDesiredWindowTitleAndIcon()

        -- Create the debug console
        Kristal.Console = Kristal.Stage:addChild(Console())
        -- Create the debug system
        Kristal.DebugSystem = Kristal.Stage:addChild(DebugSystem())

        REGISTRY_LOADED = true
    end)
end

function Loading:update()
    if (self.debug_input_buffer > 0) then
        self.debug_input_buffer = self.debug_input_buffer - DT
    end
    if (self.shaking) then
        if (self.shake_x ~= 0) or (self.shake_y ~= 0) then
            self.shake_timer = self.shake_timer + DT

            local shake_x, shake_y = self.shake_x, self.shake_y
            local shake_timer = self.shake_timer
            while shake_timer >= (2/30) do
                shake_x = (MathUtils.approach(shake_x, 0, self.shake_friction)) * -1
                shake_y = (MathUtils.approach(shake_y, 0, self.shake_friction)) * -1
                shake_timer = shake_timer - (2/30)
            end

            self.shake_x = shake_x
            self.shake_y = shake_y
        else
            self.shake_timer = 0
            self.shaking = false
            love.window.setPosition(self.shaking_base_x, self.shaking_base_y)
        end

        local window_x, window_y = love.window.getPosition()
        love.window.setPosition(window_x + self.shake_x, window_y + self.shake_y)
    end
    if self.done_loading then
        if (self.shaking and (self.animation_done or KRistal.Config["skipIntro"])) then
            self.shake_x = 0
            self.shake_y = 0
            self.shaking = false
            love.window.setPosition(self.shaking_base_x, self.shaking_base_y)
        end
        return
    end

    if (self.loading_state == Loading.States.DONE) and self.key_check and (self.animation_done or Kristal.Config["skipIntro"]) then
        -- We're done loading! This should only happen once.
        self.done_loading = true

        if Kristal.Args["test"] then
            Kristal.setState("Testing")
        elseif AUTO_MOD_START and TARGET_MOD then
            if not Kristal.hasAnySaves("mimicrune") then
                TARGET_MOD = "mimicrune"
            end
            if not Kristal.loadMod(TARGET_MOD) then
                error("Failed to load mod: " .. TARGET_MOD)
            end
        else
            Kristal.setState("MainMenu")
        end
    end
end

function Loading:drawScissor(image, left, top, width, height, x, y, alpha)
    love.graphics.push()

    local scissor_x = ((math.floor(x) >= 0) and math.floor(x) or 0)
    local scissor_y = ((math.floor(y) >= 0) and math.floor(y) or 0)
    love.graphics.setScissor(scissor_x, scissor_y, width, height)

    Draw.setColor(1, 1, 1, alpha)
    Draw.draw(image, math.floor(x) - left, math.floor(y) - top)
    Draw.setColor(1, 1, 1, 1)
    love.graphics.setScissor()
    love.graphics.pop()
end

function Loading:drawSprite(image, x, y, alpha)
    love.graphics.push()
    love.graphics.setScissor()

    Draw.setColor(1, 1, 1, alpha)
    Draw.draw(image, math.floor(x), math.floor(y), 0, 1, 1, image:getWidth() / 2, image:getHeight() / 2)
    Draw.setColor(1, 1, 1, 1)
    love.graphics.pop()
end

function Loading:drawTerminalText(text, x, y, color)
    if not (color) then
        color = {1,1,1,1}
    end
    love.graphics.push()
    local next_y = y + 12
    local line_wrap = 0
    for i = 1, #text, 1 do
        if (x + (6 * i) - (6 * line_wrap)) > 280 then
            next_y = next_y + 12
            y = y + 12
            line_wrap = line_wrap + i
        end
        love.graphics.setColor(color[1], color[2], color[3], color[4]/3)
        love.graphics.setFont(self.wingdings)
        love.graphics.print(string.sub(text, i, i), x + (6 * i) - (6 * line_wrap), y)
        love.graphics.setColor(unpack(color))
        love.graphics.setFont(self.font)
        love.graphics.print(string.sub(text, i, i), x + (6 * i) - (6 * line_wrap), y)
        love.graphics.setColor(1,1,1,1)
    end
    
    love.graphics.pop()
    return next_y
end

function Loading:draw()
    if (self.debug_wait) then
        return
    end
    if Kristal.Config["skipIntro"] then
        love.graphics.push()
        love.graphics.translate(SCREEN_WIDTH / 2, SCREEN_HEIGHT / 2)
        love.graphics.scale(2, 2)
        self:drawSprite(self.logo, 0, 0, 1)
        self:drawSprite(self.logo_heart, 0, 0, 1)
        love.graphics.pop()
        return
    end

    local dt_mult = DT * 15

    -- We need to draw the logo on a canvas
    local logo_canvas = Draw.pushCanvas(320, 240)
    love.graphics.clear()
    if (self.animation_phase == -1) then
        self.siner = self.siner + 1 * dt_mult
        self.factor = self.factor - (0.003 + (self.siner / 900)) * dt_mult

        if self.factor < -1.5 then
            self.animation_phase = 0
            self.factor = 1
            self.siner = 0
            self.intro:play()
            self:shakeWindow(-4, -4, 1)
            self.glitch1_played = false
            self.glitch2_played = false
        else
            if (self.factor <= 0.50 and self.factor >= 0.40) or (self.factor <= 0 and self.factor >= -0.15) then
                love.graphics.setShader(self.glitch_shader)
                if (self.factor <= 0.50 and self.factor >= 0.40) and not self.glitch1_played then
                    self.glitch1:play()
                    self:shakeWindow(2, 2, 0.8)
                    love.window.setTitle("DE LT A R U NE")
                    self.glitch1_played = true
                elseif (self.factor <= 0 and self.factor >= -0.15) and not self.glitch2_played then
                    self.glitch2:play()
                    self:shakeWindow(3, -1, 0.25)
                    self.glitch2_played = true
                    love.window.setTitle("grievous_error")
                    love.window.setIcon(self.heart_icon)
                    self.logo_kristal = self.logo_fake
                end
                self.glitch_shader:send("scan_line_jitter", 0.015 * math.random(0.5, 2.0))
                self.glitch_shader:send("horizontal_shake", 0.01)
                self.glitch_shader:send("color_drift", 0.03)
            end
            for i = 0, self.h - 1 do
                self.ia = ((self.siner / 25) - (math.abs((i - (self.h / 2))) * 0.05))
                self.xoff = ((40 * math.sin(((self.siner / 5) + (i / 3)))) * self.factor)
                self.xoff2 = ((40 * math.sin((((self.siner / 5) + (i / 3)) + 0.6))) * self.factor)
                self.xoff3 = ((40 * math.sin((((self.siner / 5) + (i / 3)) + 1.2))) * self.factor)
                
                self:drawScissor(self.logo_kristal, 0, i, self.w, 2, (self.x + self.xoff), (self.y + i), (not self.glitch2_played) and ((1 - self.factor) / 2) or 0)
                self:drawScissor(self.logo_kristal, 0, i, self.w, 2, (self.x + self.xoff2), (self.y + i), (not self.glitch2_played) and ((1 - self.factor) / 2) or 0)
                self:drawScissor(self.logo_kristal, 0, i, self.w, 2, (self.x + self.xoff3), (self.y + i), (not self.glitch2_played) and ((1 - self.factor) / 2) or 0)
            end
            love.graphics.setShader()
            if (self.glitch1_played) then
                local nextline = self:drawTerminalText("> [FATAL] : UNABLE TO ESTABLISH CONNECTION TO 'deltarune'. (125 : PREEXISTING_CONNECTION)", 8, 4, {1, 0.25, 0.25, 1})
                if (self.glitch2_played) then
                    self:drawSprite(self.logo_kristal, self.x + (self.w / 2), self.y + (self.h / 2), 1 - self.factor)
                    nextline = self:drawTerminalText("> REROUTING TO ALTERNATIVE DEVICE SERVER...", 8, nextline)
                end
            end
        end
    end
    if (self.animation_phase == 0) then
        self.siner = self.siner + 1 * dt_mult
        self.factor = self.factor - (0.003 + (self.siner / 900)) * dt_mult
        if (self.factor < 0) then
            self.factor = 0
            self.animation_phase = 1
            self.shine:play()
            if self.loading_state == Loading.States.WAITING then
                self:beginLoad()
            end
        end
        love.graphics.setShader(self.glitch_shader)
        self.glitch_shader:send("iTime", Kristal:getTime())
        for i = 0, self.h - 1 do
            self.glitch_shader:send("scan_line_jitter", 0.015 * math.max(0, self.factor) * math.random(0.4, 1.2))
            self.glitch_shader:send("horizontal_shake", 0.01 * math.max(0, self.factor) * math.random(0.4, 1.5))
            self.glitch_shader:send("color_drift", 0.03 * math.max(0, self.factor)* math.random(0.4, 1.5))
            self.ia = ((self.siner / 25) - (math.abs((i - (self.h / 2))) * 0.05))
            self.xoff = ((40 * math.sin(((self.siner / 5) + (i / 3)))) * self.factor)
            self.xoff2 = ((40 * math.sin((((self.siner / 5) + (i / 3)) + 0.6))) * self.factor)
            self.xoff3 = ((40 * math.sin((((self.siner / 5) + (i / 3)) + 1.2))) * self.factor)
            
            self:drawScissor(self.logo, 0, i, self.w, 2, (self.x + self.xoff), (self.y + i), ((1 - self.factor) / 4))
            self:drawScissor(self.logo, 0, i, self.w, 2, (self.x + self.xoff2), (self.y + i), ((1 - self.factor) / 4))
            --self:drawScissor(self.logo, 0, i, self.w, 2, (self.x + self.xoff3), (self.y + i), ((1 - self.factor) / 4))
        end

        self.glitch_shader:send("scan_line_jitter", 0.015 * math.max(0, self.factor))
        self.glitch_shader:send("horizontal_shake", 0.01 * math.max(0, self.factor))
        self.glitch_shader:send("color_drift", 0.03 * math.max(0, self.factor))
        self:drawSprite(self.logo_fake, self.x + (self.w / 2), self.y + (self.h / 2), self.logo_alpha - math.max(0, 1 - self.factor))
        love.graphics.setShader()
        local nextline = self:drawTerminalText("> [FATAL] : UNABLE TO ESTABLISH CONNECTION TO 'deltarune'.", 8, 4, {1, 0.25, 0.25, 1})
        nextline = self:drawTerminalText("> REROUTING TO ALTERNATIVE DEVICE SERVER...", 8, nextline)
        self:drawTerminalText("> ALIGNING TO ALTERNATIVE DEVICE PARAMETERS", 8, nextline)
    end
    if (self.animation_phase == 1) then
        self:drawSprite(self.logo, self.x + (self.w / 2), self.y + (self.h / 2), self.logo_alpha)
        if (self.animation_phase_timer >= 10 and self.animation_phase_timer <= 13) or (self.animation_phase_timer >= 15 and self.animation_phase_timer <= 16.5) then
            love.graphics.setShader(self.glitch_shader)
            if (self.animation_phase_timer >= 10 and self.animation_phase_timer <= 13) and not self.glitch1_played then
                self.glitch2:play()
                self.glitch1_played = true
                self:shakeWindow(1, 1, 0.25)
            elseif (self.animation_phase_timer >= 15 and self.animation_phase_timer <= 16.5) and not self.glitch2_played then
                self.glitch1:play()
                self.glitch2_played = true
            end
            self.glitch_shader:send("scan_line_jitter", 0.015 * math.random(0.5, 2.0))
            self.glitch_shader:send("horizontal_shake", 0.01)
            self.glitch_shader:send("color_drift", 0.03)
        end
        self:drawSprite(self.logo_heart, self.x + (self.w / 2), self.y + (self.h / 2), self.logo_alpha)
        love.graphics.setShader()
        self.animation_phase_timer = self.animation_phase_timer + 1 * dt_mult
        if (self.animation_phase_timer >= 40) and (self.loading_state == Loading.States.DONE) then
            self.siner = 0
            self.factor = 0
            self.animation_phase = 2
            self.end_noise:play()
        end
        local nextline = self:drawTerminalText("> [FATAL] : UNABLE TO ESTABLISH CONNECTION TO 'deltarune'.", 8, 4, {1, 0.25, 0.25, 1})
        nextline = self:drawTerminalText("> REROUTING TO ALTERNATIVE DEVICE SERVER...", 8, nextline)
        nextline = self:drawTerminalText("> ALIGNING TO ALTERNATIVE DEVICE PARAMETERS", 8, nextline)
        nextline = self:drawTerminalText("> CONNECTION_REROUTE_SUCCESS_MSG", 8, nextline)
        Draw.setColor(1, 1, 1, 1 - math.min(1, self.animation_phase_timer / 20))
        love.graphics.rectangle("fill", 0, 0, 640, 480)
    end
    if (self.animation_phase == 2) then
        if (self.animation_phase_plus == 0) then
            self.siner = self.siner + 0.5 * dt_mult
        end
        if (self.siner >= 20) then
            self.animation_phase_plus = 1
        end
        if (self.animation_phase_plus == 1) then
            self.siner = self.siner + 0.5 * dt_mult
            self.logo_alpha = self.logo_alpha - 0.02 * dt_mult
            self.logo_alpha_2 = self.logo_alpha_2 - 0.08 * dt_mult
        end

        self:drawSprite(self.logo, self.x + (self.w / 2), self.y + (self.h / 2), self.logo_alpha_2)
        self.mina = (self.siner / 30)
        if (self.mina >= 0.14) then
            self.mina = 0.14
        end

        self.factor2 = self.factor2 + 0.05 * dt_mult

        local angle_offset = (self.siner / 8)
        local alpha = (self.mina * self.logo_alpha)

        local center_x = self.x + (self.w / 2)
        local center_y = self.y + (self.h / 2)

        for i = 0, 9 do
            self:drawSprite(self.logo_fake,
                            ((self.x + (self.w / 2)) - (math.sin(((self.siner / 8) + (i / 2))) * (i * self.factor2))),
                            ((self.y + (self.h / 2)) - (math.cos(((self.siner / 8) + (i / 2))) * (i * self.factor2))),
                            (self.mina * self.logo_alpha))
            self:drawSprite(self.logo_fake,
                            ((self.x + (self.w / 2)) + (math.sin(((self.siner / 8) + (i / 2))) * (i * self.factor2))),
                            ((self.y + (self.h / 2)) - (math.cos(((self.siner / 8) + (i / 2))) * (i * self.factor2))),
                            (self.mina * self.logo_alpha))
            self:drawSprite(self.logo_fake,
                            ((self.x + (self.w / 2)) - (math.sin(((self.siner / 8) + (i / 2))) * (i * self.factor2))),
                            ((self.y + (self.h / 2)) + (math.cos(((self.siner / 8) + (i / 2))) * (i * self.factor2))),
                            (self.mina * self.logo_alpha))
            self:drawSprite(self.logo_fake,
                            ((self.x + (self.w / 2)) + (math.sin(((self.siner / 8) + (i / 2))) * (i * self.factor2))),
                            ((self.y + (self.h / 2)) + (math.cos(((self.siner / 8) + (i / 2))) * (i * self.factor2))),
                            (self.mina * self.logo_alpha))
        end
        self:drawSprite(self.logo_heart, self.x + (self.w / 2), self.y + (self.h / 2), self.logo_alpha)
        local nextline = self:drawTerminalText("> [FATAL] : UNABLE TO ESTABLISH CONNECTION TO 'deltarune'.", 8, 4, {1, 0.25, 0.25, math.min(1, self.logo_alpha)})
        nextline = self:drawTerminalText("> REROUTING TO ALTERNATIVE DEVICE SERVER...", 8, nextline, {1, 1, 1, math.min(1, self.logo_alpha)})
        nextline = self:drawTerminalText("> ALIGNING TO ALTERNATIVE DEVICE PARAMETERS", 8, nextline, {1, 1, 1, math.min(1, self.logo_alpha)})
        nextline = self:drawTerminalText("> CONNECTION_REROUTE_SUCCESS_MSG", 8, nextline, {1, 1, 1, math.min(1, self.logo_alpha)})
        self:drawTerminalText("> ESTABLISHING UPLINK", 8, nextline, {1, 242/255, 0, math.min(1, self.logo_alpha)})
        for i = 1, self.factor2 / 0.5, 1 do
            self:drawTerminalText(".", string.len("> ESTABLISHING UPLINK") * 6 + (6 + (6 * i)), nextline, {1, 242/255, 0, self.logo_alpha})
        end
        if (self.logo_alpha <= -0.5 and self.skipped == false) then
            self.animation_done = true
        end
    end

    -- Reset canvas to draw to
    Draw.popCanvas()

    -- Draw the canvas on the screen scaled by 2x
    Draw.setColor(1, 1, 1, 1)
    Draw.draw(logo_canvas, 0, 0, 0, 2, 2)

    if self.skipped then
        -- Draw the screen fade
        Draw.setColor(0, 0, 0, self.fader_alpha)
        love.graphics.rectangle("fill", 0, 0, 640, 480)

        if self.fader_alpha > 1 then
            self.animation_done = true
            self.noise:stop()
            self.end_noise:stop()
        end

        -- Change the fade opacity for the next frame
        self.fader_alpha = math.max(0, self.fader_alpha + (0.04 * dt_mult))
        self.noise:setVolume(math.max(0, 1 - self.fader_alpha))
        self.end_noise:setVolume(math.max(0, 1 - self.fader_alpha))
    end

    -- Reset the draw color
    Draw.setColor(1, 1, 1, 1)
end

function Loading:onKeyPressed(key)
    if (self.debug_wait) then
        self.debug_wait = false
        self.debug_input_buffer = 1
        self:startIntro()
    elseif self.debug_input_buffer <= 0 then
        self.key_check = true
        self.skipped = true
        if self.loading_state == Loading.States.WAITING then
            self:beginLoad()
        end
    end
end

return Loading
