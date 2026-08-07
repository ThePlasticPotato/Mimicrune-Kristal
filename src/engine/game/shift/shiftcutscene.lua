--- The cutscene class for cutscenes running in battles, their scripts should be located in `scripts/shift/cutscenes/`. \
--- These cutscene scripts will receive a ShiftCutscene as their first argument.
---
---@class ShiftCutscene : Cutscene
---@overload fun(group: string, id?: string, ...) : ShiftCutscene
local ShiftCutscene, super = Class(Cutscene)

local function _true() return true end

---@overload fun(func: BattleCutsceneFunc, ...)
---@param group string
---@param id? string
---@param ... any
function ShiftCutscene:init(group, id, ...)
    local scene, args = self:parseFromGetter(Registry.getShiftCutscene, group, id, ...)

    self.last_shift_state = Game.shift.state
    Game.shift.state_manager:setState("CUTSCENE")

    super.init(self, scene, unpack(args))
end

return ShiftCutscene