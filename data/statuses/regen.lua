local status, super = Class(Status, "regen")

function status:init()
    super.init(self)

    --The display name
    self.name = "REGEN"
    self.icon = "ui/status/regen"
    self.type_icon = nil
    -- The color(s) the status will display as
    self.color = COLORS.lime
    -- Tags that apply to this status
    self.tags = {"continual", "healing"}

    self.positive = true
    self.curable = true

    self.amount = 10
    self.triggered = false

    self.max = 0
    self.duration = 1
    self.decay = false
    self.decay_rate = 1
    self.tick_type = "DEFEND_END"
end

---@param battler EnemyBattler|PartyBattler
---@param effect table
function status:onApply(battler, effect)
    local amt = self.amount * effect.stacks
    amt = Game.battle:applyHealBonuses(amt, effect.data.source and effect.data.source.chara)
    battler:heal(amt, nil, true)
end

---@param battler EnemyBattler|PartyBattler
---@param effect table
function status:onDefendEnd(battler, effect)
    local amt = self.amount * effect.stacks
    amt = Game.battle:applyHealBonuses(amt, effect.data.source and effect.data.source.chara)
    battler:heal(amt, nil, true)

    effect.time_left = effect.time_left - 1
    if (effect.time_left <= 0) then
        battler:removeStatus(self.id, "TIMEOUT")
        return false
    end
end

return status