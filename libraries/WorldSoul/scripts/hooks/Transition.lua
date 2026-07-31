local Transition, super = HookSystem.hookScript(Transition)

---@param soul WorldSoul
function Transition:onSoulEnter(soul)
    if not soul.is_active or self.world.state ~= "GAMEPLAY" then return end

    local x, y = self.target.x, self.target.y
    local marker = self.target.marker
    local facing = self.target.facing or soul:getTransitionFacing()

    if self.sound then
        Assets.playSound(self.sound, 1, self.pitch)
    end

    if self.target.map then
        local callback = function(map)
            if self.exit_sound then
                Assets.playSound(self.exit_sound, 1, self.exit_pitch)
            end
            Game.world.door_delay = self.exit_delay
        end

        if marker then
            self.world:mapTransition(self.target.map, marker, facing, callback)
        else
            self.world:mapTransition(self.target.map, x, y, facing, callback)
        end
    end
end

return Transition
