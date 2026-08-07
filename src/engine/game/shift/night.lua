--- Basically an encounter for a [`Shift`](lua://Shift). Night files
--- should be placed inside `scripts/shift/nights/`.
---
---@class Night : Class
---@field id string
---@field name string
---@field office string|Office Office id or instance.
---@field animatronics (string|ShiftAnimatronic)[] ShiftAnimatronic ids or instances.
---@field ai_levels table<string, number> AI level overrides, indexed by animatronic id.
---@field duration number? Gameplay duration in seconds. `nil` disables timed victory (for conditional things like Sister Location).
---@field hours integer Number of hour changes during the shift. Divides up the base duration into said hours.
---@field start_hour integer First displayed hour.
---@field transition_time number
---@field transition_out_time number
---@field max_power number
---@field base_power_usage number
---@field power_drain_rate number Power drained per second for each point of usage.
---@field power_out_delay number Seconds before an unhandled power outage starts its jumpscare.
---@field power_out_animatronic string|ShiftAnimatronic? Animatronic used by the default power out jumpscare.
---@field jumpscare_static_duration number Seconds of fading static after a jumpscare animation.
---@field victory_duration number Seconds the default victory screen remains visible.
---@field victory_sound string|false Victory sound; `false` disables it.
---@field victory_text string? Text drawn by the default victory screen.
---@field complete boolean
---@overload fun() : Night
local Night = Class()

function Night:init()
    self.name = "Shift"
    self.office = ""

    self.animatronics = {}
    self.ai_levels = {}

    self.duration = 360
    self.hours = 6
    self.start_hour = 12

    self.transition_time = 26 / 30
    self.transition_out_time = 26 / 30

    self.max_power = 100
    self.base_power_usage = 0
    self.power_drain_rate = 1
    self.power_out_delay = 5
    self.power_out_animatronic = nil

    self.jumpscare_static_duration = 3

    self.victory_duration = 5
    self.victory_sound = "bell"
    self.victory_text = nil

    self.complete = false
end

-- Callbacks

--- *(Override)* Called once the shift has created its office, cameras, and animatronics.
--- Returning `true` prevents the shift from automatically entering `"TRANSITION"`.
---@param shift Shift
---@return boolean?
function Night:onShiftInit(shift) end

--- *(Override)* Called when gameplay begins.
---@param shift Shift
function Night:onShiftStart(shift) end

--- *(Override)* Called when the shift begins transitioning back to the previous game state.
--- Returning `true` prevents the default return to the overworld.
---@param shift Shift
---@param completed boolean
---@return boolean?
function Night:onShiftEnd(shift, completed) end

--- *(Override)* Called when the shift enters its initial transition.
--- Returning `true` prevents the default transition to `"INTRO"`.
---@param shift Shift
---@return boolean?
function Night:onTransition(shift) end

--- *(Override)* Called when the shift enters its intro state.
--- Returning `true` prevents the default transition to `"GAMEPLAY"`.
---@param shift Shift
---@return boolean?
function Night:onIntro(shift) end

--- *(Override)* Called each time the displayed in-game hour changes.
---@param new integer Completed hour count, from `1` to [`Night.hours`](lua://Night.hours).
---@param old integer
function Night:onHourChange(new, old) end

--- *(Override)* Called when the currently viewed surveillance camera changes.
---@param camera ShiftCamera?
---@param old ShiftCamera?
function Night:onCameraChanged(camera, old) end

--- *(Override)* Called when the active shift panel changes.
---@param panel ShiftPanel?
---@param old ShiftPanel?
function Night:onPanelChanged(panel, old) end

--- *(Override)* Called when power reaches zero. Returning `true` replaces the default
--- office power-out presentation and delayed jumpscare.
---@param shift Shift
---@return boolean?
function Night:onPowerOut(shift) end

--- *(Override)* Called when a jumpscare begins. Returning `true` replaces the default
--- [`Jumpscare`](lua://Jumpscare) animation, static fade, and game-over sequence.
---@param animatronic ShiftAnimatronic?
---@param reason string?
---@return boolean?
function Night:onJumpscare(animatronic, reason) end

--- *(Override)* Called when the shift is won. Returning `true` keeps the shift in
--- `"VICTORY"`; otherwise it proceeds to `"TRANSITIONOUT"` on the next update.
---@param shift Shift
---@return boolean?
function Night:onVictory(shift) end

--- *(Override)* Called before a shift state change. Returning `true` cancels the change.
---@param old ShiftState
---@param new ShiftState
---@param reason string?
---@return boolean?
function Night:beforeStateChange(old, new, reason) end

--- *(Override)* Called after a shift state change.
---@param old ShiftState
---@param new ShiftState
---@param reason string?
function Night:onStateChange(old, new, reason) end

--- *(Override)* Called every frame after the shift's state-specific update.
function Night:update() end

--- *(Override)* Called before the shift and its children are drawn.
function Night:drawBackground() end

--- *(Override)* Called after the shift and its children are drawn.
function Night:draw() end

--- *(Override)* Draws the victory screen. Return `true` to replace the fallback screen.
---@param shift Shift
---@return boolean?
function Night:drawVictory(shift) end

--- *(Override)* Draws the camera-map artwork behind a CameraPanel's map buttons.
---@param panel CameraPanel
function Night:drawCameraMap(panel) end

--- *(Override)* Called when the shift receives a key press. Return `true` to consume it.
---@param key string
---@return boolean?
function Night:onKeyPressed(key) end

-- Functions

---@param shift Shift
---@return ShiftAnimatronic?
function Night:getPowerOutAnimatronic(shift)
    if self.power_out_animatronic then
        return shift:getAnimatronic(self.power_out_animatronic)
    end
    for _, animatronic in ipairs(shift.animatronics) do
        if animatronic.active then return animatronic end
    end
end

---@param animatronic ShiftAnimatronic?
---@return string?
function Night:getJumpscareID(animatronic)
    return animatronic and animatronic:getJumpscareID() or nil
end

---@param animatronic string|ShiftAnimatronic
---@param ai_level? number
function Night:addAnimatronic(animatronic, ai_level)
    table.insert(self.animatronics, animatronic)
    if type(animatronic) == "string" and ai_level ~= nil then
        self.ai_levels[animatronic] = ai_level
    elseif type(animatronic) ~= "string" and ai_level ~= nil then
        animatronic.ai_level = ai_level
    end
end

---@return Office
function Night:createOffice()
    if type(self.office) == "string" then
        if self.office == "" then
            error("Night \"" .. tostring(self.id) .. "\" does not define an office")
        end
        return Registry.createOffice(self.office)
    end
    return self.office
end

---@return ShiftAnimatronic[]
function Night:createAnimatronics()
    local result = {}
    for _, entry in ipairs(self.animatronics) do
        local animatronic = entry
        if type(entry) == "string" then
            animatronic = Registry.createAnimatronic(entry)
            if self.ai_levels[entry] ~= nil then
                animatronic.ai_level = self.ai_levels[entry]
            end
        end
        table.insert(result, animatronic)
    end
    return result
end

---@param flag string
---@param value any
function Night:setFlag(flag, value)
    Game:setFlag("night#" .. self.id .. ":" .. flag, value)
end

---@param flag string
---@param default? any
---@return any
function Night:getFlag(flag, default)
    return Game:getFlag("night#" .. self.id .. ":" .. flag, default)
end

---@param flag string
---@param amount? number
---@return number
function Night:addFlag(flag, amount)
    return Game:addFlag("night#" .. self.id .. ":" .. flag, amount)
end

---@return boolean
function Night:canDeepCopy()
    return false
end

return Night
