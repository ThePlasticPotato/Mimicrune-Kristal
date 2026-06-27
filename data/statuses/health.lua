local status, super = Class(Status, "health")

function status:init()
    super.init(self)

    --The display name
    self.name = "HP"
    self.icon = "ui/status/health"
    self.type_icon = nil
    -- The color(s) the status will display as
    self.color = COLORS.white
    -- Tags that apply to this status
    self.tags = {"stat", "hp"}

    self.positive = true
    self.curable = true

    self.amount = 10

    self.max = 1
    self.duration = 1
    self.decay = false
    self.decay_rate = 1
    self.tick_type = "TURN_START"
end

function status:isPositive()
    return self.amount > 0
end

function status:getColor(index)
    return self:isPositive() and self.color or COLORS.gray
end

---@param battler Battler
---@param effect table
function status:onTurnStart(battler, effect)
    effect.time_left = effect.time_left - 1
    if (effect.time_left <= 0) then
        battler:removeStatus(self.id, "TIMEOUT")
        return false
    end
end

---@param battler PartyBattler
function status:onApply(battler, effect)
    battler.chara:addStatBuff("health", self.amount * effect.stacks)
end

function status:onUpdate(battler, effect, old)
    battler.chara:addStatBuff("health", self.amount * (effect.stacks - old))
end

---@param battler PartyBattler
function status:onEnd(battler, effect, reason)
    battler.chara:addStatBuff("health", -self.amount * (effect.stacks))
    if battler.chara:getStatBuff("health") == 0 then
        battler.chara:resetBuff("health")
    end
end

return status