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
---@field cursor_locked boolean
---@field cursor_was_grabbed boolean?
---@field cursor_was_visible boolean?
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
---@field move_targets table<string, ShiftMoveTarget>
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
---@field transition_timer number
---@field transition_snapshot love.Image?
---@field transition_started boolean
---@field transition_handled boolean
---@field intro_started boolean
---@field intro_handled boolean
---@field power_out_started boolean
---@field power_out_handled boolean
---@field power_out_timer number
---@field jumpscare_started boolean
---@field jumpscare_handled boolean
---@field jumpscare_animatronic ShiftAnimatronic?
---@field jumpscare_object Jumpscare?
---@field jumpscare_phase "ANIMATION"|"STATIC"?
---@field jumpscare_static_timer number
---@field game_over_started boolean
---@field victory_started boolean
---@field victory_handled boolean
---@field victory_timer number
---@field end_started boolean
---@field end_handled boolean
---@field transition_out_timer number
---@field transition_out_snapshot love.Image?
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
    self.cursor_locked = false
    self.cursor_was_grabbed = nil
    self.cursor_was_visible = nil
    self.state_manager = StateManager("NONE", self, true)
    self.state_manager:addState("NONE")
    self.state_manager:addState("TRANSITION", {
        enter = self.beginTransition,
        update = self.updateTransition,
        draw = self.drawGonerTransition,
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
        draw = self.drawJumpscare,
    })
    self.state_manager:addState("VICTORY", {
        enter = self.beginVictory,
        update = self.updateVictory,
        draw = self.drawVictory,
    })
    self.state_manager:addState("TRANSITIONOUT", {
        enter = self.beginTransitionOut,
        update = self.updateTransitionOut,
        draw = self.drawGonerTransition,
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
    self.move_targets = {}
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
    self.transition_timer = 0
    self.transition_snapshot = nil
    self.intro_started = false
    self.intro_handled = false
    self.power_out_started = false
    self.power_out_handled = false
    self.power_out_timer = 0
    self.jumpscare_started = false
    self.jumpscare_handled = false
    self.jumpscare_animatronic = nil
    self.jumpscare_object = nil
    self.jumpscare_phase = nil
    self.jumpscare_static_timer = 0
    self.game_over_started = false
    self.victory_started = false
    self.victory_handled = false
    self.victory_timer = 0
    self.end_started = false
    self.end_handled = false
    self.transition_out_timer = 0
    self.transition_out_snapshot = nil

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
    self:addMoveTarget(self.office)
    for _, door in ipairs(self.office.doors) do
        self:addMoveTarget(door)
    end

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
    local control_index = 0
    for _, controls in ipairs({ self.office.interactables, self.office.static_interactables }) do
        for _, control in ipairs(controls) do
            if control.isPowerDraining and control.power_usage ~= nil then
                control_index = control_index + 1
                local id = control.layout_id or control.id or tostring(control_index)
                self:addPowerDrainer("office_control:" .. tostring(id), control)
            end
        end
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
        if not self.transition_handled then
            self.transition_timer = 0
            self.transition_snapshot = self:captureTransitionSnapshot()
        end
    end
end

---@private
function Shift:updateTransition()
    if self.transition_handled then return end

    self.transition_timer = self.transition_timer + DT
    if self.transition_timer >= self.night.transition_time then
        self:releaseTransitionSnapshot("transition_snapshot")
        self:setState("INTRO")
    end
end

---@private
function Shift:beginIntro()
    if self.intro_started then return end
    self.intro_started = true
    self.intro_handled = self.night:onIntro(self) == true
    if self.intro_handled then return end

    self.intro_handled = self.office:startIntro(function()
        if Game.shift == self and self.state == "INTRO" then
            self:setState("GAMEPLAY", "INTRO")
        end
    end)
    if not self.intro_handled then
        return "GAMEPLAY", { "INTRO" }
    end
end

---@private
function Shift:updateIntro() end

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

    if self.duration and self.duration > 0 then
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
        self.power_out_handled = self.night:onPowerOut(self) == true
        if not self.power_out_handled then
            self.power_out_timer = 0
            self:setCamera(nil)
            if self.panel then self.panel:close() end
            self.office:setPowerOut()
        end
    end
end

---@private
function Shift:updatePowerOut()
    if self.power_out_handled then return end

    self.power_out_timer = self.power_out_timer + DT
    if self.power_out_timer >= self.night.power_out_delay then
        local animatronic = self.night:getPowerOutAnimatronic(self)
        self:setState("JUMPSCARE", "POWEROUT", animatronic)
    end
end

---@private
---@param old ShiftState
---@param reason? string
---@param animatronic? ShiftAnimatronic
function Shift:beginJumpscare(old, reason, animatronic)
    self.failed = true
    if not self.jumpscare_started then
        self.jumpscare_started = true
        self.jumpscare_animatronic = animatronic
        self.jumpscare_handled = self.night:onJumpscare(animatronic, reason) == true
        if not self.jumpscare_handled then
            self.ambience:stop()
            local jumpscare_id = self.night:getJumpscareID(animatronic)
            if jumpscare_id then
                self.jumpscare_phase = "ANIMATION"
                self.jumpscare_object = self:addChild(Jumpscare(jumpscare_id, function()
                    if Game.shift == self and self.state == "JUMPSCARE" then
                        self:beginJumpscareStatic()
                    end
                end))
            else
                self:beginJumpscareStatic()
            end
        end
    end
end

---@private
function Shift:updateJumpscare()
    if self.jumpscare_handled or self.jumpscare_phase ~= "STATIC" then return end

    self.jumpscare_static_timer = self.jumpscare_static_timer + DT
    if self.jumpscare_static_timer >= self.night.jumpscare_static_duration then
        self:gameOver()
    end
end

---@private
function Shift:beginVictory()
    self.complete = true
    self.night.complete = true
    if not self.victory_started then
        self.victory_started = true
        self.victory_handled = self.night:onVictory(self) == true
        if not self.victory_handled then
            self.victory_timer = 0
            if self.night.victory_sound then
                Assets.playSound(self.night.victory_sound)
            end
        end
    end
end

---@private
function Shift:updateVictory()
    if self.victory_handled then return end

    self.victory_timer = self.victory_timer + DT
    if self.victory_timer >= self.night.victory_duration then
        self:setState("TRANSITIONOUT", "VICTORY")
    end
end

---@private
function Shift:beginTransitionOut()
    if not self.end_started then
        self.end_started = true
        self.end_handled = self.night:onShiftEnd(self, self.complete) == true
        if not self.end_handled then
            self.transition_out_timer = 0
            self.transition_out_snapshot = self:captureTransitionSnapshot()
        end
    end
end

---@private
function Shift:updateTransitionOut()
    if self.end_handled then return end

    self.transition_out_timer = self.transition_out_timer + DT
    if self.transition_out_timer >= self.night.transition_out_time then
        self:releaseTransitionSnapshot("transition_out_snapshot")
        self:returnToWorld()
    end
end

---@return love.Image?
function Shift:captureTransitionSnapshot()
    if not SCREEN_CANVAS then return nil end
    local success, image = pcall(function()
        return love.graphics.newImage(SCREEN_CANVAS:newImageData())
    end)
    if success then return image end
end

---@param field "transition_snapshot"|"transition_out_snapshot"
function Shift:releaseTransitionSnapshot(field)
    local snapshot = self[field]
    self[field] = nil
    if snapshot then snapshot:release() end
end

---@param snapshot love.Image?
---@param progress number
function Shift:drawBleedSnapshot(snapshot, progress)
    if not snapshot then return end

    local shader = Assets.getShader("goner_bleed")
    shader:send("progress", MathUtils.clamp(progress, 0, 1))
    shader:send("time", Kristal.getTime())
    love.graphics.setShader(shader)
    Draw.setColor(1, 1, 1, 1)
    Draw.draw(snapshot)
    love.graphics.setShader()
end

function Shift:drawGonerTransition()
    local snapshot, timer, duration
    if self.state == "TRANSITION" and not self.transition_handled then
        snapshot = self.transition_snapshot
        timer = self.transition_timer
        duration = self.night.transition_time
    elseif self.state == "TRANSITIONOUT" and not self.end_handled then
        snapshot = self.transition_out_snapshot
        timer = self.transition_out_timer
        duration = self.night.transition_out_time
    else
        return
    end

    love.graphics.push("all")
    love.graphics.origin()
    Draw.setColor(0, 0, 0, 1)
    love.graphics.rectangle("fill", 0, 0, SCREEN_WIDTH, SCREEN_HEIGHT)
    self:drawBleedSnapshot(snapshot, duration > 0 and (timer / duration) or 1)
    love.graphics.pop()
end

function Shift:beginJumpscareStatic()
    if self.jumpscare_object then
        self.jumpscare_object:remove()
        self.jumpscare_object = nil
    end
    self.jumpscare_phase = "STATIC"
    self.jumpscare_static_timer = 0
end

function Shift:drawJumpscare()
    if self.jumpscare_handled or self.jumpscare_phase ~= "STATIC" then return end

    local duration = self.night.jumpscare_static_duration
    local progress = duration > 0 and MathUtils.clamp(self.jumpscare_static_timer / duration, 0, 1) or 1
    local alpha = 1 - progress

    love.graphics.push("all")
    love.graphics.origin()
    Draw.setColor(0, 0, 0, 1)
    love.graphics.rectangle("fill", 0, 0, SCREEN_WIDTH, SCREEN_HEIGHT)
    if alpha > 0 then
        local shader = Assets.getShader("tv_static")
        shader:send("time", Kristal.getTime())
        love.graphics.setShader(shader)
        Draw.setColor(1, 1, 1, alpha)
        love.graphics.rectangle("fill", 0, 0, SCREEN_WIDTH, SCREEN_HEIGHT)
        love.graphics.setShader()
    end
    love.graphics.pop()
end

function Shift:drawVictory()
    if self.victory_handled or self.night:drawVictory(self) then return end

    love.graphics.push("all")
    love.graphics.origin()
    Draw.setColor(0, 0, 0, 1)
    love.graphics.rectangle("fill", 0, 0, SCREEN_WIDTH, SCREEN_HEIGHT)
    Draw.setColor(1, 1, 1, 1)
    love.graphics.setFont(Assets.getFont("main", 64))
    local text = self.night.victory_text or (tostring(self:getDisplayHour()) .. " AM")
    love.graphics.printf(text, 0, (SCREEN_HEIGHT - 64) / 2, SCREEN_WIDTH, "center")
    love.graphics.pop()
end

---@param camera ShiftCamera|string
---@return ShiftCamera?
function Shift:getCamera(camera)
    if type(camera) == "string" then
        return self.camera_by_id[camera]
    end
    return camera
end

---@param target ShiftMoveTarget|string
---@return ShiftMoveTarget?
function Shift:getMoveTarget(target)
    if type(target) == "string" then
        return self.move_targets[target]
    end
    return target
end

---@param target ShiftMoveTarget
---@return ShiftMoveTarget target
function Shift:addMoveTarget(target)
    if type(target.id) ~= "string" or target.id == "" then
        error("Shift movement targets require a non-empty id")
    end
    local existing = self.move_targets[target.id]
    if existing and existing ~= target then
        error("Duplicate shift movement target id \"" .. target.id .. "\"")
    end
    self.move_targets[target.id] = target
    return target
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
    self:addMoveTarget(camera)
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

    local starting_target = animatronic.starting_target or animatronic.starting_camera
    if starting_target then
        animatronic:setTarget(self:getMoveTarget(starting_target))
    end
    return animatronic
end

---@param panel? CameraPanel
---@return ShiftAnimatronic?
function Shift:checkOfficeAttack(panel)
    panel = panel or self.panel
    if not panel or not panel:includes(CameraPanel) or panel.state ~= "OPEN" then return nil end

    for _, animatronic in ipairs(self.office.animatronics) do
        if animatronic:tryOfficeAttack(panel) then
            return animatronic
        end
    end
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
    self:unlockCursor()

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
    if self.game_over_started then return end
    self.game_over_started = true
    self:unlockCursor()
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
    if not MOUSE_VISIBLE then Kristal.showCursor() end
    if self.cursor_locked and love.window.hasFocus() and not love.mouse.isGrabbed() then
        love.mouse.setGrabbed(true)
    end
    self.state_manager:update()
    self.night:update()
    super.update(self)
end

function Shift:lockCursor()
    if self.cursor_locked then return end
    self.cursor_was_grabbed = love.mouse.isGrabbed()
    self.cursor_was_visible = MOUSE_VISIBLE
    self.cursor_was_type = MOUSE_CURSOR_TYPE
    Kristal.setCursorType("default")
    Kristal.showCursor()
    love.mouse.setGrabbed(true)
    self.cursor_locked = true
end

function Shift:unlockCursor()
    if not self.cursor_locked then return end
    love.mouse.setGrabbed(self.cursor_was_grabbed == true)
    Kristal.setCursorType(self.cursor_was_type or "default")
    if self.cursor_was_visible then
        Kristal.showCursor()
    else
        Kristal.hideCursor()
    end
    self.cursor_locked = false
    self.cursor_was_grabbed = nil
    self.cursor_was_visible = nil
    self.cursor_was_type = nil
end

---@param stage Object
function Shift:onAddToStage(stage)
    super.onAddToStage(self, stage)
    self:lockCursor()
end

function Shift:draw()
    self.night:drawBackground()
    super.draw(self)
    self.state_manager:draw()
    self.night:draw()
    if DEBUG_RENDER then self:drawDebug() end
end

---@param target ShiftMoveTarget?
---@return string
function Shift:getDebugTargetName(target)
    if not target then return "NONE" end
    return tostring(target.id or target.layout_id or target.name or "UNNAMED")
end

---@param animatronics ShiftAnimatronic[]?
---@return string
function Shift:getDebugAnimatronicList(animatronics)
    local names = {}
    for _, animatronic in ipairs(animatronics or {}) do
        table.insert(names, tostring(animatronic.id or animatronic.name or "?"))
    end
    return #names > 0 and table.concat(names, ", ") or "none"
end

function Shift:drawDebug()
    local lines = {}
    local function add(text, color)
        table.insert(lines, { text = text, color = color })
    end

    local usage = self:getPowerUsage()
    local camera = self.current_camera and self:getDebugTargetName(self.current_camera) or "NONE"
    local panel = self.panel and tostring(self.panel.state or "OPEN") or "NONE"
    add("SHIFT DEBUG", { 0.35, 0.9, 1, 1 })
    add(string.format("State: %s  Reason: %s", self.state, self.state_reason or "-"))
    add(string.format("Hour: %d AM  Time: %.1fs", self:getDisplayHour(), self.elapsed))
    add(string.format("Power: %.1f/%.1f  Usage: %.1f", self.power, self.max_power, usage))
    add(string.format("Camera: %s  Panel: %s", camera, panel))

    add(string.format("ANIMATRONICS (%d)", #self.animatronics), { 1, 0.85, 0.3, 1 })
    for _, animatronic in ipairs(self.animatronics) do
        local flags = {}
        if animatronic.active then table.insert(flags, "ACTIVE") else table.insert(flags, "INACTIVE") end
        if animatronic.office_attack_pending then table.insert(flags, "OFFICE READY") end
        if animatronic.attacking then table.insert(flags, "ATTACKING") end
        if animatronic.door_grace_timer and animatronic.door_grace_timer > 0 then
            table.insert(flags, string.format("DOOR GRACE %.1fs", animatronic.door_grace_timer))
        end
        add(string.format("%s [%s] @ %s",
            animatronic.name or "Animatronic",
            animatronic.id or "?",
            self:getDebugTargetName(animatronic.current_target)))
        add(string.format("  AI %.1f/%.1f  Move %.1f/%.1fs  %s",
            animatronic.ai_level,
            animatronic.base_movement_chance,
            animatronic.movement_timer,
            animatronic.movement_interval,
            table.concat(flags, ", ")), { 0.8, 0.8, 0.8, 1 })
    end

    local doors = self.office and self.office.doors or {}
    add(string.format("DOORS (%d)", #doors), { 1, 0.55, 0.35, 1 })
    for _, door in ipairs(doors) do
        local status = door.state .. "  LIGHT " .. (door:isLightOn() and "ON" or "OFF")
        if door.jammed then
            status = status .. "  JAMMED BY "
                .. tostring(door.jammer and (door.jammer.id or door.jammer.name) or "?")
        elseif door.locked then
            status = status .. "  LOCKED"
        end
        add(string.format("%s: %s", door.id or "?", status))
        add("  Occupants: " .. self:getDebugAnimatronicList(door.animatronics),
            { 0.8, 0.8, 0.8, 1 })
    end
    if self.office then
        add("OFFICE: " .. self:getDebugAnimatronicList(self.office.animatronics),
            { 0.75, 1, 0.75, 1 })
    end

    local font = Assets.getFont("main", 12)
    local line_height = 13
    local padding = 6
    local width = math.min(370, SCREEN_WIDTH - 12)
    local max_lines = math.max(1, math.floor((SCREEN_HEIGHT - 12 - padding * 2) / line_height))
    if #lines > max_lines then
        lines[max_lines] = { text = "... " .. (#lines - max_lines + 1) .. " more", color = { 1, 0.5, 0.5, 1 } }
        for index = #lines, max_lines + 1, -1 do lines[index] = nil end
    end
    local height = padding * 2 + #lines * line_height
    local x, y = SCREEN_WIDTH - width - 6, 6

    love.graphics.push("all")
    love.graphics.origin()
    love.graphics.setFont(font)
    Draw.setColor(0, 0, 0, 0.82)
    love.graphics.rectangle("fill", x, y, width, height)
    Draw.setColor(0.35, 0.9, 1, 0.8)
    love.graphics.rectangle("line", x, y, width, height)
    for index, line in ipairs(lines) do
        Draw.setColor(line.color or { 1, 1, 1, 1 })
        love.graphics.print(line.text, x + padding, y + padding + (index - 1) * line_height)
    end
    love.graphics.pop()
end

---@param key string
function Shift:onKeyPressed(key)
    if self.night:onKeyPressed(key) then return true end
    return self.state_manager:call("keyPressed", key)
end

---@param parent Object
function Shift:onRemove(parent)
    self:unlockCursor()
    self:releaseTransitionSnapshot("transition_snapshot")
    self:releaseTransitionSnapshot("transition_out_snapshot")
    super.onRemove(self, parent)
    self.ambience:remove()
end

---@return boolean
function Shift:canDeepCopy()
    return false
end

return Shift
