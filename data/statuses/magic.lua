local status, super = Class(Status, "magic")

function status:init()
    super.init(self)

    --The display name
    self.name = "MAG"
    self.icon = "ui/status/magic"
    self.type_icon = nil
    -- The color(s) the status will display as
    self.color = COLORS.white
    -- Tags that apply to this status
    self.tags = {"modifier", "magic"}

    self.positive = true
    self.curable = true

    self.modifier = 1
    self.consume_on_trigger = false

    self.max = 3
    self.duration = 1
    self.decay = false
    self.decay_rate = 1
    self.tick_type = "TURN_START"
end

function status:isPositive()
    return self.modifier > 0
end

function status:getColor(index)
    return self:isPositive() and self.color or COLORS.gray
end

---@param battler Battler
---@param effect table
---@param spell Spell
---@return number?
function status:onCast(battler, effect, spell)
    local amt = self.modifier * effect.stacks
    if (self.consume_on_trigger) then
        battler:removeStatus(self.id, "CONSUME")
    end
    return amt
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

return status