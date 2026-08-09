--- A representation of a FNAF animatronic. Takes movement opportunities based on its AI level.
---@class ShiftAnimatronic : Object
---@field id string
---@field shift Shift?
---@field name string
---@field actor Actor?
---@field jumpscare string? Jumpscare asset id. Defaults to this animatronic's id, then its actor id.
---@field ai_level number
---@field base_movement_chance number Divisor of the ai decision chance. Default 20.
---@field movement_interval number Seconds between movement opportunities. Default 5.
---@field movement_timer number
---@field active boolean
---@field starting_target string?
---@field starting_camera string?
---@field current_target ShiftMoveTarget?
---@field previous_target ShiftMoveTarget?
---@field current_camera ShiftCamera?
---@field previous_camera ShiftCamera?
---@field office_door OfficeDoor?
---@field office_attack_pending boolean
---@field attacking boolean
---@field door_light_sprite string? Fallback sprite used when seen at a lit office door.
---@field door_light_sprites table<string, string> Door-specific lit sprites indexed by door id.
---@overload fun(actor?: Actor|string) : ShiftAnimatronic
local ShiftAnimatronic, super = Class(Object)

---@param actor? Actor|string
function ShiftAnimatronic:init(actor)
    super.init(self)

    self.shift = nil
    self.name = "Animatronic"
    self.actor = nil
    self.jumpscare = nil
    if actor then self:setActor(actor) end

    self.ai_level = 0
    self.base_movement_chance = 20
    self.movement_interval = 5
    self.movement_timer = 0
    self.active = true

    self.starting_target = nil
    self.starting_camera = nil
    self.current_target = nil
    self.previous_target = nil
    self.current_camera = nil
    self.previous_camera = nil
    self.office_door = nil
    self.office_attack_pending = false
    self.attacking = false
    self.door_light_sprite = nil
    self.door_light_sprites = {}
end

---@param actor Actor|string
function ShiftAnimatronic:setActor(actor)
    if type(actor) == "string" then
        actor = Registry.createActor(actor)
    end
    self.actor = actor
    self.name = actor.name or self.name
end

---@param level number
function ShiftAnimatronic:setAILevel(level)
    self.ai_level = math.max(level, 0)
end

---@return string?
function ShiftAnimatronic:getJumpscareID()
    return self.jumpscare or self.id or (self.actor and self.actor.id)
end

---@param door OfficeDoor
---@return string?
function ShiftAnimatronic:getDoorLightSprite(door)
    return self.door_light_sprites[door.id] or self.door_light_sprite
end

---@return number chance A value between `0` and `1`.
function ShiftAnimatronic:getMovementChance()
    return MathUtils.clamp((self.ai_level / self.base_movement_chance), 0, 1)
end

---@return boolean
function ShiftAnimatronic:canMove()
    return self.active and self.current_target ~= nil
end

---@return ShiftMoveTarget?
function ShiftAnimatronic:selectMoveTarget()
    local shift = self.shift or Game.shift
    if not self.current_target or not shift then return nil end

    local targets = {}
    for _, route in ipairs(self.current_target.move_targets) do
        local target = route.target or shift:getMoveTarget(route.target_id)
        if target and target.enabled and self.current_target:canMoveTo(route, self) then
            table.insert(targets, target)
        end
    end
    if #targets > 0 then
        return TableUtils.pick(targets)
    end
end

---@param target ShiftMoveTarget|string|nil
function ShiftAnimatronic:setTarget(target)
    local shift = self.shift or Game.shift
    if type(target) == "string" and shift then
        target = shift:getMoveTarget(target)
    end
    if target == self.current_target then return end

    local old = self.current_target
    if old then old:removeAnimatronic(self) end
    self.previous_target = old
    self.current_target = target
    self.previous_camera = old and old:includes(ShiftCamera) and old or nil
    self.current_camera = target and target:includes(ShiftCamera) and target or nil
    if target then target:addAnimatronic(self) end
    self:onMove(target, old)

    if target and target:includes(Office) then
        local door = old and old:includes(OfficeDoor) and old or nil
        self:onOfficeEntered(target, door)
    end
end

---@param camera ShiftCamera|string|nil
function ShiftAnimatronic:setCamera(camera)
    self:setTarget(camera)
end

---@param target ShiftMoveTarget?
---@param old ShiftMoveTarget?
function ShiftAnimatronic:onMove(target, old) end

--- *(Override)* Called when the AI succeeds a movement check. Return `false` to cancel movement.
--- The default behavior refuses to pass from a door into the office while that door is closed.
---@param target ShiftMoveTarget
---@return boolean?
function ShiftAnimatronic:onMovementOpportunity(target)
    if self.current_target
        and self.current_target:includes(OfficeDoor)
        and target:includes(Office)
    then
        return self:canEnterOffice(self.current_target, target)
    end
end

--- *(Override)* Standard door-entry check. Specialized animatronics may bypass or replace it.
--- An animatronic revealed by the linked door light remains at the door.
---@param door OfficeDoor
---@param office Office
---@return boolean
function ShiftAnimatronic:canEnterOffice(door, office)
    return door:isOpen() and not door:isLightOn()
end

--- *(Override)* Called after this animatronic moves from a door into the office.
---@param office Office
---@param door OfficeDoor?
function ShiftAnimatronic:onOfficeEntered(office, door)
    self.office_door = door
    if door then door:jam(self) end
    self.office_attack_pending = true

    local shift = self.shift or Game.shift
    if shift then shift:checkOfficeAttack() end
end

--- *(Override)* Called when the camera panel exposes an animatronic waiting in the office.
--- Return `true` to replace the default panel pull-down and jumpscare.
---@param panel CameraPanel
---@return boolean?
function ShiftAnimatronic:onOfficeAttack(panel) end

---@param panel CameraPanel
---@return boolean attacked
function ShiftAnimatronic:tryOfficeAttack(panel)
    local shift = self.shift or Game.shift
    if not self.office_attack_pending
        or self.attacking
        or not shift
        or shift.state ~= "GAMEPLAY"
        or panel.state ~= "OPEN"
    then
        return false
    end

    self.office_attack_pending = false
    self.attacking = true
    self.active = false
    if self:onOfficeAttack(panel) == true then return true end

    local function jumpscare()
        if Game.shift == shift and shift.state == "GAMEPLAY" then
            shift:setState("JUMPSCARE", "OFFICE", self)
        end
    end
    if not panel:close(false, jumpscare) then
        jumpscare()
    end
    return true
end

function ShiftAnimatronic:update()
    local shift = self.shift or Game.shift
    if self.active and shift and shift.state == "GAMEPLAY" then
        self.movement_timer = self.movement_timer + DT
        if self.movement_interval <= 0 then
            self.movement_timer = 0
        elseif self.movement_timer >= self.movement_interval then
            self.movement_timer = self.movement_timer % self.movement_interval
            if self:canMove() and love.math.random() <= self:getMovementChance() then
                local target = self:selectMoveTarget()
                if target and self:onMovementOpportunity(target) ~= false then
                    self:setTarget(target)
                end
            end
        end
    end
    super.update(self)
end

return ShiftAnimatronic
