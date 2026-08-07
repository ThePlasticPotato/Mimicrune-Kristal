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
---@field max_power number
---@field base_power_usage number
---@field power_drain_rate number Power drained per second for each point of usage.
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

    self.max_power = 100
    self.base_power_usage = 0
    self.power_drain_rate = 1

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
---@param shift Shift
---@param completed boolean
function Night:onShiftEnd(shift, completed) end

--- *(Override)* Called when the shift enters its initial transition.
---@param shift Shift
function Night:onTransition(shift) end

--- *(Override)* Called when the shift enters its intro state.
---@param shift Shift
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

--- *(Override)* Called when power reaches zero.
---@param shift Shift
function Night:onPowerOut(shift) end

--- *(Override)* Called when a jumpscare begins.
---@param animatronic ShiftAnimatronic?
---@param reason string?
function Night:onJumpscare(animatronic, reason) end

--- *(Override)* Called when the shift is won.
---@param shift Shift
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

--- *(Override)* Called when the shift receives a key press. Return `true` to consume it.
---@param key string
---@return boolean?
function Night:onKeyPressed(key) end

-- Functions

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