---Represents a FNAF night. hoh boy
---@class Shift : Object, StateManagedClass
---
---@field state_manager StateManager
---@field state ShiftState
---
---@field timer Timer
---
---@field night Night
---@field office Office
---@field animatronics ShiftAnimatronic[]
---@field cameras ShiftCamera[]
---@field panel ShiftPanel? currently open menu panel, if any
---
---@field tracks string[] indexed list of ambient audio/danger audio
---@field ambience Music
---
---@field power number
---@field power_drainers table<string, PowerDrainer>
---
---@field last_camera ShiftCamera?
local Shift, super = Class(Object)

---@alias ShiftState # The state of the shift.
---| "NONE" # An empty state which does nothing.
---| "TRANSITION"  # The state used when first entering a shift.
---| "INTRO" # The state used after TRANSITION, where the shift intro animation plays.
---| "GAMEPLAY" # The main gameplay state.
---| "POWEROUT" # The state used after power outage.
---| "JUMPSCARE" # The state used during a jumpscare before gameover transition.
---| "VICTORY"  # The state used when the player has survived the shift.
---| "TRANSITIONOUT"  # The state used when transitioning out of the shift.
---| "CUTSCENE" # The state used when a shift cutscene is active.

---@class PowerDrainer
---@field source Object?
---@field power_usage number
---@field severity number?

---@param night Night
function Shift:init(night)
    super.init(self, 0, 0, SCREEN_WIDTH, SCREEN_HEIGHT)

    self.state = "TRANSITION"
    self.state_manager = StateManager("TRANSITION", self, true)
end

return Shift