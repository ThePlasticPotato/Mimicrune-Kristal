local status, super = Class(Status, "heartbound")

function status:init()
    super.init(self)

    --The display name
    self.name = "HBND"
    self.icon = "ui/status/health"
    self.type_icon = nil
    -- The color(s) the status will display as
    self.color = COLORS.lime
    -- Tags that apply to this status
    self.tags = {"modifier", "hiteffect"}

    self.positive = true
    self.curable = false

    self.modifier = 0.5

    self.max = 1
    self.duration = 1
    self.decay = false
    self.decay_rate = 1
    self.tick_type = "DEFEND_END"
end

---@param battler PartyBattler
---@param effect table
---@param amount number
---@return number?
function status:onHurt(battler, effect, amount)
    if (effect.data.source.is_down) then return 0 end
    local reduction = amount * self.modifier
    local defender = effect.data.source
    reduction = math.max(0, math.min(defender.chara:getHealth(), reduction))
    defender:hurt(reduction)
    return -reduction
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