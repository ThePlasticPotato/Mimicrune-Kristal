--- A representation of a FNAF animatronic. Takes movement opportunities based on its AI level.
---@class ShiftAnimatronic : Object
---@field id string
---@field shift Shift?
---@field name string
---@field actor Actor?
---@field ai_level number
---@field base_movement_chance number Divisor of the ai decision chance. Default 20.
---@field movement_interval number Seconds between movement opportunities. Default 5.
---@field movement_timer number
---@field active boolean
---@field starting_camera string?
---@field current_camera ShiftCamera?
---@field previous_camera ShiftCamera?
---@overload fun(actor?: Actor|string) : ShiftAnimatronic
local ShiftAnimatronic, super = Class(Object)

---@param actor? Actor|string
function ShiftAnimatronic:init(actor)
    super.init(self)

    self.shift = nil
    self.name = "Animatronic"
    self.actor = nil
    if actor then self:setActor(actor) end

    self.ai_level = 0
    self.base_movement_chance = 20
    self.movement_interval = 5
    self.movement_timer = 0
    self.active = true

    self.starting_camera = nil
    self.current_camera = nil
    self.previous_camera = nil
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

---@return number chance A value between `0` and `1`.
function ShiftAnimatronic:getMovementChance()
    return MathUtils.clamp((self.ai_level / self.base_movement_chance), 0, 1)
end

---@return boolean
function ShiftAnimatronic:canMove()
    return self.active and self.current_camera ~= nil
end

---@return ShiftCamera?
function ShiftAnimatronic:selectMoveTarget()
    local shift = self.shift or Game.shift
    if not self.current_camera or not shift then return nil end

    local targets = {}
    for _, target in ipairs(self.current_camera.move_targets) do
        local camera = shift:getCamera(target.target_id)
        if camera and camera.enabled and self.current_camera:canMoveTo(target, self) then
            table.insert(targets, camera)
        end
    end
    if #targets > 0 then
        return TableUtils.pick(targets)
    end
end

---@param camera ShiftCamera?
function ShiftAnimatronic:setCamera(camera)
    if camera == self.current_camera then return end

    local old = self.current_camera
    if old then old:removeAnimatronic(self) end
    self.previous_camera = old
    self.current_camera = camera
    if camera then camera:addAnimatronic(self) end
    self:onMove(camera, old)
end

---@param camera ShiftCamera?
---@param old ShiftCamera?
function ShiftAnimatronic:onMove(camera, old) end

--- *(Override)* Called when the AI succeeds a movement check. Return `false` to cancel movement.
---@param target ShiftCamera
---@return boolean?
function ShiftAnimatronic:onMovementOpportunity(target) end

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
                    self:setCamera(target)
                end
            end
        end
    end
    super.update(self)
end

return ShiftAnimatronic