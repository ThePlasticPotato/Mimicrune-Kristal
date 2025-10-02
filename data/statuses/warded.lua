local status, super = Class(Status, "warded")

function status:init()
    super.init(self)

    --The display name
    self.name = "WARD"
    self.icon = "ui/status/defense"
    self.type_icon = "ui/status/type/neutral"
    -- The color(s) the status will display as
    self.color = COLORS.lime
    -- Tags that apply to this status
    self.tags = {"hiteffect"}

    self.positive = true
    self.curable = false

    self.max = 1
    self.duration = 3
    self.decay = false
    self.decay_rate = 1
    self.tick_type = "DEFEND_END"
end

---@param battler PartyBattler
---@param effect table
---@param amount number
---@return boolean
function status:onHurt(battler, effect, amount)
    local activated = not (effect.data.source.is_down) and (battler.chara:getHealth() - amount <= 0)
    if (activated) then
        battler:removeStatus(self.id, "CONSUME")
    end
    return activated
end

---@param battler Battler
---@param effect table
function status:onDefendEnd(battler, effect)
    effect.time_left = effect.time_left - 1
    if (effect.time_left <= 0) then
        battler:removeStatus(self.id, "TIMEOUT")
        return false
    end
end

return status