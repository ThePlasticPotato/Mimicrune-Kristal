local socket = require('socket')

function Mod:init()
    -- If you set up your engine to have Kristal.returnToMenu load your TARGET_MOD, this will be helpful.
    Utils.hook(Kristal.Overlay, "update", function (orig, self)
        if not (TARGET_MOD and AUTO_MOD_START) then
            return orig(self)
        end
        local do_orig = true
        if love.keyboard.isDown("escape") and not self.quit_release then
            if Kristal.Config and Kristal.Config["instantQuit"] then
                love.event.quit()
                do_orig = false
            else
                if self.quit_alpha < 1 then
                    self.quit_alpha = math.min(1, self.quit_alpha + DT / 0.75)
                end
                self.quit_timer = self.quit_timer + DT
                if self.quit_timer > 1.2 then
                    love.event.quit()
                    self.quit_timer = 0
                    self.quit_alpha = 0
                    self.quit_release = true
                    do_orig = false
                else
                    self.quit_timer = self.quit_timer - DT
                end
            end
        else
            self.quit_timer = 0
            if self.quit_alpha > 0 then
                self.quit_alpha = math.max(0, self.quit_alpha - DT / 0.25)
            end
        end

        if self.quit_release and not love.keyboard.isDown("escape") then
            self.quit_release = false
        end
        if do_orig then
            orig(self)
        end
    end)
end

-- -- Uncomment if you setup RPC for your engine build
-- function Mod:getPresenceState()
--     return "On the chapter select"
-- end
