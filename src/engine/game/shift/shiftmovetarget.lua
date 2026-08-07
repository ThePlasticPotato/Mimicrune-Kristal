--- A location which can hold animatronics and connect to other shift locations.
--- Cameras, office doors, and offices all derive from this class.
---@class ShiftMoveTarget : Object
---@field id string?
---@field move_targets MoveTarget[]
---@field animatronics ShiftAnimatronic[]
---@field enabled boolean
---@overload fun(x?: number, y?: number, width?: number, height?: number) : ShiftMoveTarget
local ShiftMoveTarget, super = Class(Object)

---@class MoveTarget
---@field target_id string?
---@field target ShiftMoveTarget?
---@field allowed_animatronics string[] An empty list allows every animatronic.
---@field blocked boolean

---@param x? number
---@param y? number
---@param width? number
---@param height? number
function ShiftMoveTarget:init(x, y, width, height)
    super.init(self, x, y, width, height)

    self.move_targets = {}
    self.animatronics = {}
    self.enabled = true
end

---@param target string|ShiftMoveTarget|MoveTarget
---@param allowed_animatronics? string[]
---@return MoveTarget target
function ShiftMoveTarget:addMoveTarget(target, allowed_animatronics)
    if type(target) == "string" then
        target = {
            target_id = target,
            allowed_animatronics = allowed_animatronics or {},
            blocked = false,
        }
    elseif isClass(target) and target:includes(ShiftMoveTarget) then
        target = {
            target_id = target.id,
            target = target,
            allowed_animatronics = allowed_animatronics or {},
            blocked = false,
        }
    else
        target.allowed_animatronics = target.allowed_animatronics or allowed_animatronics or {}
        target.blocked = target.blocked or false
    end
    table.insert(self.move_targets, target)
    return target
end

---@param id string
---@return MoveTarget?
function ShiftMoveTarget:getMoveTarget(id)
    for _, target in ipairs(self.move_targets) do
        if target.target_id == id or (target.target and target.target.id == id) then
            return target
        end
    end
end

---@param target MoveTarget
---@param animatronic ShiftAnimatronic
---@return boolean
function ShiftMoveTarget:canMoveTo(target, animatronic)
    if target.blocked then return false end
    return #target.allowed_animatronics == 0
        or TableUtils.contains(target.allowed_animatronics, animatronic.id)
end

---@param animatronic ShiftAnimatronic
function ShiftMoveTarget:addAnimatronic(animatronic)
    if not TableUtils.contains(self.animatronics, animatronic) then
        table.insert(self.animatronics, animatronic)
    end
end

---@param animatronic ShiftAnimatronic
function ShiftMoveTarget:removeAnimatronic(animatronic)
    TableUtils.removeValue(self.animatronics, animatronic)
end

return ShiftMoveTarget
