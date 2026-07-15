---@class Character : Object
---@field sitting boolean
---@field seat Sittable
local Character, super = HookSystem.hookScript(Character)

function Character:init(actor, x, y)
    super.init(self, actor, x, y)
    self.sitting = false
    self.seat = nil
    self.should_sit = false
end

function Character:update()
    super.update(self)
    if (not self.should_sit and self.sitting) then
        self.seat:trySitting(self, self.facing, true)
    end
end

---@param original Sittable
---@param dir string
function Character:attemptSit(original, dir)
    if (self.sitting and self.seat and self.seat.trySitting) then
        self.seat:trySitting(self, self.facing, true)
        if (self.returnToFollowing) then self:returnToFollowing(6) end
        return true
    end
    local sittables = TableUtils.filter(Game.world.map:getEvents(nil), function (v)
        if (v.trySitting and v.occupied ~= true and v.currently_targeted ~= true and v ~= original) then return true end
        return false
    end)
    local closest_valid = nil
    local best_score = 9999
    for index, value in ipairs(sittables) do
        local score = 0
        local distance_from_original = MathUtils.dist(original.x, original.y, value.x, value.y)
        score = score + distance_from_original
        local distance_from_me = MathUtils.dist(self.x, self.y, value.x, value.y)
        score = score + distance_from_me
        local facing_bonus = value.facing == original.facing and -100 or 0
        score = score + facing_bonus
        if (score < best_score) then
            closest_valid = value
            best_score = score
        end
    end
    if (closest_valid) then
        local distance_from_me = MathUtils.dist(self.x, self.y, closest_valid.x, closest_valid.y)
        if (distance_from_me > 41) then
            closest_valid.currently_targeted = true
            self:pathfindTo(closest_valid.x, closest_valid.y, {speed = 8, refollow = false, valid_distance = 4, after = function () 
                if (self.should_sit) then 
                    closest_valid:trySitting(self, self.facing, true)
                else
                    if (self.returnToFollowing) then self:returnToFollowing(6) end
                end
                end})
        else
            closest_valid:trySitting(self, self.facing, true)
        end
    end

    return false
end

return Character