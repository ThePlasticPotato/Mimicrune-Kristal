--- The main controller for a FNAF shift. A globally available reference to the active
--- instance is expected to be stored in [`Game.shift`](lua://Game.shift).
---
---@class Shift : Object, StateManagedClass
---
---@field state_manager StateManager
---@field state ShiftState The current state. Use [`Shift:setState()`](lua://Shift.setState) instead of assigning this directly.
---@field state_reason string?
---@field changing_state boolean
---
---@field timer Timer
---@field cutscene ShiftCutscene?
---
---@field night Night
---@field office Office
---@field animatronics ShiftAnimatronic[]
---@field animatronic_by_id table<string, ShiftAnimatronic>
---@field cameras ShiftCamera[]
---@field camera_by_id table<string, ShiftCamera>
---@field current_camera ShiftCamera?
---@field last_camera ShiftCamera?
---@field panel ShiftPanel? The currently open panel, if any.
---
---@field tracks string[] Indexed ambient/danger music tracks.
---@field ambience Music
---
---@field power number
---@field max_power number
---@field base_power_usage number
---@field power_drain_rate number Power drained per second for each point of usage.
---@field power_drainers table<string, PowerDrainer>
---
---@field elapsed number Elapsed gameplay time, in seconds.
---@field duration number? Total gameplay time, in seconds. `nil` disables automatic victory.
---@field hour integer Number of completed in-game hours.
---@field complete boolean
---@field failed boolean
---@overload fun(night: Night|string) : Shift
local Shift, super = Class(Object)

---@alias ShiftState # The state of the shift.
---| "NONE" # An empty state which does nothing.
---| "TRANSITION" # The state used when first entering a shift.
---| "INTRO" # The state used after TRANSITION, where the shift intro animation plays.
---| "GAMEPLAY" # The main gameplay state.
---| "POWEROUT" # The state used after power outage.
---| "JUMPSCARE" # The state used during a jumpscare before the game-over transition.
---| "VICTORY" # The state used when the player has survived the shift.
---| "TRANSITIONOUT" # The state used when transitioning out of the shift.
---| "CUTSCENE" # The state used when a shift cutscene is active.

---@class PowerDrainer
---@field source Object?
---@field power_usage number
---@field severity number?
---@field active boolean?
---@field isPowerDraining? fun(self: PowerDrainer): boolean

---@param night Night|string
function Shift:init(night)
    super.init(self, 0, 0, SCREEN_WIDTH, SCREEN_HEIGHT)

    if type(night) == "string" then
        night = Registry.createNight(night)
    end
    if night == nil then
        error("Attempt to create a shift without a night")
    end

    self.state = "NONE"
    self.state_reason = nil
    self.changing_state = false
    self.state_manager = StateManager("NONE", self, true)
    self.state_manager:addState("NONE")
    self.state_manager:addState("TRANSITION", {
        enter = self.beginTransition,
        update = self.updateTransition,
    })
    self.state_manager:addState("INTRO", {
        enter = self.beginIntro,
        update = self.updateIntro,
    })
    self.state_manager:addState("GAMEPLAY", {
        enter = self.beginGameplay,
        update = self.updateGameplay,
    })
    self.state_manager:addState("POWEROUT", {
        enter = self.beginPowerOut,
        update = self.updatePowerOut,
    })
    self.state_manager:addState("JUMPSCARE", {
        enter = self.beginJumpscare,
        update = self.updateJumpscare,
    })
    self.state_manager:addState("VICTORY", {
        enter = self.beginVictory,
        update = self.updateVictory,
    })
    self.state_manager:addState("TRANSITIONOUT", {
        enter = self.beginTransitionOut,
        update = self.updateTransitionOut,
    })
    self.state_manager:addState("CUTSCENE")

    self.timer = self:addChild(Timer())
    self.cutscene = nil

    self.night = night
    self.office = night:createOffice()
    if self.office == nil then
        error("Night \"" .. tostring(night.id) .. "\" did not create an office")
    end
    self.office.shift = self
    self:addChild(self.office)

    self.animatronics = {}
    self.animatronic_by_id = {}
    self.cameras = {}
    self.camera_by_id = {}
    self.current_camera = nil
    self.last_camera = nil
    self.panel = nil

    for _, camera in ipairs(self.office:createCameras()) do
        self:addCamera(camera)
    end
    for _, animatronic in ipairs(self.night:createAnimatronics()) do
        self:addAnimatronic(animatronic)
    end

    self.tracks = {}
    self.ambience = Music()

    self.max_power = night.max_power
    self.power = self.max_power
    self.base_power_usage = night.base_power_usage
    self.power_drain_rate = night.power_drain_rate
    self.power_drainers = {}
    for index, door in ipairs(self.office.doors) do
        self:addPowerDrainer(door.id or ("door_" .. index), door)
    end

    self.elapsed = 0
    self.duration = night.duration
    self.hour = 0
    self.complete = false
    self.failed = false

    local handled = self.night:onShiftInit(self)
    if not handled and self.state == "NONE" then
        self:setState("TRANSITION")
    end
end

--- Changes the shift state through its [`StateManager`](lua://StateManager).
---@param state ShiftState
---@param reason? string
---@param ... any
function Shift:setState(state, reason, ...)
    local old = self.state
    local result = self.night:beforeStateChange(old, state, reason)
    if result or self.state ~= old then return end

    self.changing_state = true
    self.state_manager:setState(state, reason, ...)
    self.changing_state = false
end

---@return ShiftState
function Shift:getState()
    return self.state
end

--- *(Override)* Called before the state changes. Returning `true` cancels the change.
---@param old ShiftState
---@param new ShiftState
---@param reason? string
---@return boolean?
function Shift:beforeStateChange(old, new, reason)
    if not self.changing_state then
        return self.night:beforeStateChange(old, new, reason)
    end
end

--- Called by the state manager after a state change has completed.
---@param old ShiftState
---@param new ShiftState
---@param reason? string
function Shift:onStateChange(old, new, reason)
    self.state_reason = reason
    self.night:onStateChange(old, new, reason)
end

---@private
function Shift:beginTransition()
    self.night:onTransition(self)
end

---@private
function Shift:updateTransition()
    self:setState("INTRO")
end

---@private
function Shift:beginIntro()
    self.night:onIntro(self)
end

---@private
function Shift:updateIntro()
    self:setState("GAMEPLAY")
end

---@private
function Shift:beginGameplay()
    self.night:onShiftStart(self)
end

---@private
function Shift:updateGameplay()
    self.elapsed = self.elapsed + DT
    self:updatePower()
    if self.state ~= "GAMEPLAY" then return end

    if self.duration then
        local new_hour = math.min(math.floor((self.elapsed / self.duration) * self.night.hours), self.night.hours)
        if new_hour ~= self.hour then
            local old_hour = self.hour
            self.hour = new_hour
            self.night:onHourChange(self.hour, old_hour)
        end
        if self.elapsed >= self.duration then
            self:setState("VICTORY")
        end
    end
end

---@private
function Shift:beginPowerOut()
    self.power = 0
    self.night:onPowerOut(self)
end

---@private
function Shift:updatePowerOut() end

---@private
---@param old ShiftState
---@param reason? string
---@param animatronic? ShiftAnimatronic
function Shift:beginJumpscare(old, reason, animatronic)
    self.failed = true
    self.night:onJumpscare(animatronic, reason)
end

---@private
function Shift:updateJumpscare() end

---@private
function Shift:beginVictory()
    self.complete = true
    self.night.complete = true
    self.night:onVictory(self)
end

---@private
function Shift:updateVictory() end

---@private
function Shift:beginTransitionOut()
    self.night:onShiftEnd(self, self.complete)
end

---@private
function Shift:updateTransitionOut() end

---@param camera ShiftCamera|string
---@return ShiftCamera?
function Shift:getCamera(camera)
    if type(camera) == "string" then
        return self.camera_by_id[camera]
    end
    return camera
end

---@param camera ShiftCamera
---@return ShiftCamera camera
function Shift:addCamera(camera)
    table.insert(self.cameras, camera)
    if camera.id then
        self.camera_by_id[camera.id] = camera
    end
    camera.shift = self
    camera.office = self.office
    camera.active = false
    camera.visible = false
    self:addChild(camera)
    return camera
end

---@param camera ShiftCamera|string|nil
function Shift:setCamera(camera)
    camera = camera and self:getCamera(camera) or nil
    if camera == self.current_camera then return end

    local old = self.current_camera
    self.last_camera = old
    self.current_camera = camera
    if old then old:onUnviewed(camera) end
    if camera then camera:onViewed(old) end
    self.night:onCameraChanged(camera, old)
end

---@param animatronic ShiftAnimatronic|string
---@return ShiftAnimatronic?
function Shift:getAnimatronic(animatronic)
    if type(animatronic) == "string" then
        return self.animatronic_by_id[animatronic]
    end
    return animatronic
end

---@param animatronic ShiftAnimatronic
---@return ShiftAnimatronic animatronic
function Shift:addAnimatronic(animatronic)
    table.insert(self.animatronics, animatronic)
    if animatronic.id then
        self.animatronic_by_id[animatronic.id] = animatronic
    end
    animatronic.shift = self
    self:addChild(animatronic)

    if animatronic.starting_camera then
        animatronic:setCamera(self:getCamera(animatronic.starting_camera))
    end
    return animatronic
end

---@param id string
---@param drainer PowerDrainer
function Shift:addPowerDrainer(id, drainer)
    self.power_drainers[id] = drainer
end

---@param id string
---@return PowerDrainer?
function Shift:removePowerDrainer(id)
    local drainer = self.power_drainers[id]
    self.power_drainers[id] = nil
    return drainer
end

---@return number usage
---@return number severity
function Shift:getPowerUsage()
    local usage = self.base_power_usage
    local severity = 0
    for _, drainer in pairs(self.power_drainers) do
        local active = drainer.active
        if drainer.isPowerDraining then
            active = drainer:isPowerDraining()
        end
        if active then
            usage = usage + drainer.power_usage
            severity = severity + (drainer.severity or drainer.power_usage)
        end
    end
    return usage, severity
end

function Shift:updatePower()
    local usage = self:getPowerUsage()
    if usage <= 0 then return end

    self.power = MathUtils.approach(self.power, 0, usage * self.power_drain_rate * DT)
    if self.power <= 0 and self.state == "GAMEPLAY" then
        self:setState("POWEROUT")
    end
end

---@param amount number
function Shift:addPower(amount)
    self.power = MathUtils.clamp(self.power + amount, 0, self.max_power)
end

---@param panel ShiftPanel?
function Shift:setPanel(panel)
    if self.panel == panel then return end
    local old = self.panel
    self.panel = panel
    if old and panel and old.state ~= "CLOSED" and old.state ~= "CLOSING" then
        old:close()
    end
    if panel and panel.parent ~= self then
        self:addChild(panel)
    end
    if panel then panel.shift = self end
    self.night:onPanelChanged(panel, old)
end

---@return boolean
function Shift:hasCutscene()
    return self.cutscene ~= nil
end

---@overload fun(self: Shift, func: ShiftCutsceneFunc, ...): ShiftCutscene
---@param group string
---@param id? string
---@param ... any
---@return ShiftCutscene
function Shift:startCutscene(group, id, ...)
    if self.cutscene then
        error("Attempt to start a shift cutscene while another cutscene is active")
    end
    self.cutscene = self:addChild(ShiftCutscene(group, id, ...))
    return self.cutscene
end

---@return number progress A value between `0` and `1`.
function Shift:getProgress()
    if not self.duration or self.duration <= 0 then return 0 end
    return MathUtils.clamp(self.elapsed / self.duration, 0, 1)
end

---@return integer hour
function Shift:getDisplayHour()
    local hour = (self.night.start_hour + self.hour) % 12
    return hour == 0 and 12 or hour
end

function Shift:update()
    self.state_manager:update()
    self.night:update()
    super.update(self)
end

function Shift:draw()
    self.night:drawBackground()
    super.draw(self)
    self.state_manager:draw()
    self.night:draw()
end

---@param key string
function Shift:onKeyPressed(key)
    if self.night:onKeyPressed(key) then return true end
    return self.state_manager:call("keyPressed", key)
end

---@param parent Object
function Shift:onRemove(parent)
    super.onRemove(self, parent)
    self.ambience:remove()
end

---@return boolean
function Shift:canDeepCopy()
    return false
end

return Shift