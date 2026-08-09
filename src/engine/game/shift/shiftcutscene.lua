--- The cutscene class for cutscenes running during shifts. Their scripts should be located in
--- `scripts/shift/cutscenes/` and receive a ShiftCutscene as their first argument.
---
---@class ShiftCutscene : Cutscene
---@field last_shift_state ShiftState
---@overload fun(group: string, id?: string, ...) : ShiftCutscene
local ShiftCutscene, super = Class(Cutscene)

---@alias ShiftCutsceneFunc fun(cutscene: ShiftCutscene, ...)

---@overload fun(func: ShiftCutsceneFunc, ...)
---@param group string
---@param id? string
---@param ... any
function ShiftCutscene:init(group, id, ...)
    local scene, args = self:parseFromGetter(Registry.getShiftCutscene, group, id, ...)

    self.last_shift_state = Game.shift.state
    Game.shift:setState("CUTSCENE")

    super.init(self, scene, unpack(args))
end

function ShiftCutscene:onEnd()
    if Game.shift and Game.shift.cutscene == self then
        Game.shift.cutscene = nil
    end

    if self.finished_callback then
        self.finished_callback(self)
    elseif Game.shift then
        Game.shift:setState(self.last_shift_state, "CUTSCENE")
    end
end

return ShiftCutscene