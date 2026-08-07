--- The main controller for a FNAF shift. A globally available reference to the active
--- instance is expected to be stored in [`Game.shift`](lua://Game.shift).
---
---@class Shift : Object, StateManagedClass
---
---@field state_manager StateManager
---@field state ShiftState The current state. Use [`Shift:setState()`](lua://Shift.setState) instead of assigning this directly.
---@field state_reason string?
---@field changing_state boolean
---@field initialized boolean
---@field started boolean
---@field resume_world_music boolean
---@field resume_additional_world_music boolean
---@field returned boolean
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
---@field transition_started boolean
---@field transition_handled boolean
---@field intro_started boolean
---@field intro_handled boolean
---@field power_out_started boolean
---@field jumpscare_started boolean
---@field victory_started boolean
---@field victory_handled boolean
---@field end_started boolean
---@field end_handled boolean
---@overload fun(night?: Night|string) : Shift
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

---@param night? Night|string
function Shift:init(night)
    super.init(self, 0, 0, SCREEN_WIDTH, SCREEN_HEIGHT)

    self.state = "NONE"
    self.state_reason = nil
    self.changing_state = false
    self.initialized = false
    self.started = false
    self.resume_world_music = false
    self.resume_additional_world_music = false
    self.returned = false
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

    self.night = nil
    self.office = nil
    self.animatronics = {}
    self.animatronic_by_id = {}
    self.cameras = {}
    self.camera_by_id = {}
    self.current_camera = nil
    self.last_camera = nil
    self.panel = nil

    self.tracks = {}
    self.ambience = Music()

    self.max_power = 0
    self.power = self.max_power
    self.base_power_usage = 0
    self.power_drain_rate = 1
    self.power_drainers = {}

    self.elapsed = 0
    self.duration = nil
    self.hour = 0
    self.complete = false
    self.failed = false

    self.transition_started = false
    self.transition_handled = false
    self.intro_started = false
    self.intro_handled = false
    self.power_out_started = false
    self.jumpscare_started = false
    self.victory_started = false
    self.victory_handled = false
    self.end_started = false
    self.end_handled = false

    if night ~= nil then
        self:postInit(night)
    end
end

--- Finishes constructing the shift after [`Game.shift`](lua://Game.shift) has been assigned.
---@param night Night|string
function Shift:postInit(night)
    if self.initialized then
        error("Attempt to initialize a shift more than once")
    end
    if type(night) == "string" then
        night = Registry.createNight(night)
    end
    if night == nil then
        error("Attempt to initialize a shift without a night")
    end

    self.night = night
    self.office = night:createOffice()
    if self.office == nil then
        error("Night \"" .. tostring(night.id) .. "\" did not create an office")
    end
    self.office.shift = self
    self:addChild(self.office)

    for _, camera in ipairs(self.office:createCameras()) do
        self:addCamera(camera)
    end
    for _, animatronic in ipairs(self.night:createAnimatronics()) do
        self:addAnimatronic(animatronic)
    end

    self.max_power = night.max_power
    self.power = self.max_power
    self.base_power_usage = night.base_power_usage
    self.power_drain_rate = night.power_drain_rate
    for index, door in ipairs(self.office.doors) do
        self:addPowerDrainer(door.id or ("door_" .. index), door)
    end

    self.duration = night.duration
    self.initialized = true

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
    if not self.transition_started then
        self.transition_started = true
        self.transition_handled = self.night:onTransition(self) == true
    end
end

---@private
function Shift:updateTransition()
    if not self.transition_handled then
        self:setState("INTRO")
    end
end

---@private
function Shift:beginIntro()
    if not self.intro_started then
        self.intro_started = true
        self.intro_handled = self.night:onIntro(self) == true
    end
end

---@private
function Shift:updateIntro()
    if not self.intro_handled then
        self:setState("GAMEPLAY")
    end
end

---@private
function Shift:beginGameplay()
    if not self.started then
        self.started = true
        self.night:onShiftStart(self)
    end
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
    if not self.power_out_started then
        self.power_out_started = true
        self.night:onPowerOut(self)
    end
end

---@private
function Shift:updatePowerOut() end

---@private
---@param old ShiftState
---@param reason? string
---@param animatronic? ShiftAnimatronic
function Shift:beginJumpscare(old, reason, animatronic)
    self.failed = true
    if not self.jumpscare_started then
        self.jumpscare_started = true
        self.night:onJumpscare(animatronic, reason)
    end
end

---@private
function Shift:updateJumpscare() end

---@private
function Shift:beginVictory()
    self.complete = true
    self.night.complete = true
    if not self.victory_started then
        self.victory_started = true
        self.victory_handled = self.night:onVictory(self) == true
    end
end

---@private
function Shift:updateVictory()
    if not self.victory_handled then
        self:setState("TRANSITIONOUT", "VICTORY")
    end
end

---@private
function Shift:beginTransitionOut()
    if not self.end_started then
        self.end_started = true
        self.end_handled = self.night:onShiftEnd(self, self.complete) == true
    end
end

---@private
function Shift:updateTransitionOut()
    if not self.end_handled then
        self:returnToWorld()
    end
end

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

--- Sets the completed in-game hour count and keeps elapsed time in sync.
---@param hour integer
function Shift:setHour(hour)
    hour = MathUtils.clamp(math.floor(hour), 0, self.night.hours)
    if hour == self.hour then return end

    local old = self.hour
    self.hour = hour
    if self.duration and self.night.hours > 0 then
        self.elapsed = self.duration * (self.hour / self.night.hours)
    end
    self.night:onHourChange(self.hour, old)
end

--- Advances the shift by a number of in-game hours.
---@param amount? integer
function Shift:advanceHour(amount)
    self:setHour(self.hour + (amount or 1))
    if self.hour >= self.night.hours and self.state ~= "VICTORY" and self.state ~= "TRANSITIONOUT" then
        self:setState("VICTORY", "TIME")
    end
end

--- Begins the normal shift exit flow.
---@param completed? boolean
function Shift:endShift(completed)
    if completed then
        self:setState("VICTORY", "END")
    else
        self:setState("TRANSITIONOUT", "END")
    end
end

--- Immediately removes this shift and restores the overworld.
function Shift:returnToWorld()
    if self.returned then return end
    self.returned = true

    if not self.end_started then
        self.end_started = true
        self.night:onShiftEnd(self, self.complete)
    end

    self.ambience:stop()
    if Game.world then
        if self.resume_world_music and Game.world.music then
            Game.world.music:resume()
        end
        if self.resume_additional_world_music and Game.world.additional_music then
            Game.world.additional_music:resume()
        end
        Game.world.active = true
        Game.world.visible = true
    end

    if self.parent then
        self:remove()
    elseif not self.ambience.removed then
        self.ambience:remove()
    end
    if Game.shift == self then Game.shift = nil end
    if Game.state == "SHIFT" then Game.state = "OVERWORLD" end
end

--- Ends the shift in a game over without resuming overworld audio.
---@param x? number
---@param y? number
function Shift:gameOver(x, y)
    self.failed = true
    if not self.end_started then
        self.end_started = true
        self.night:onShiftEnd(self, false)
    end
    self.ambience:stop()
    Game:gameOver(x, y)
    if not self.parent and not self.ambience.removed then
        self.ambience:remove()
    end
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