---@class Actor
---@field step_sound string The actor step sound override. Will play instead of tile specific steps.
local Actor, super = HookSystem.hookScript(Actor)

---OVERRIDE
---Returns the step sound of an actor, which takes priority over tile-specific step sounds.
function Actor:getStepSoundOverride()
    return self.step_sound
end

return Actor
