---Statuses are data classes that represent status effects, both in and out of combat.
---@class Status : Class
---
---@field name          string          The name of the status, displayed in the menu.
---@field icon          string?         The string path to the icon of the status effect.
---@field type_icon     string?         The string path to the icon of the status effect's direction, such as power UP or speed DOWN.
---@field color         table<number>|table<table<number>>   A table of numbers representing the draw color of the effect. A nested table instead uses a color for each intensity of the effect.
---@field tags          table<string>   The tags of the status, which can be used to determine certain information in a more generic way.
---
---@field positive      boolean         Whether the effect is a buff, and should be ignored by curatives.
---@field curable       boolean         Whether the effect can be cured. Ignored if the effect is positive.
---
---@field max           number          The maximum stacking of the effect that can be achieved through normal means of effect extension. A value of 0 disables this property.
---@field duration      number          The duration of the effect at base, in rounds.
---@field decay         boolean         Whether the effect should lose a stack each turn. Decaying effects vanish at 0 stacks, even if their duration would be longer.
---@field decay_rate    number          Decay rate if decay is true. Defaults to 1.
---@field tick_type     string          The way this effect ticks down its duration. Possible values: NONE, TURN_START, TURN_END, DEFEND_START, DEFEND_END
---
local Status = Class()

function Status:init()
    self.name = "Status"
    self.icon = nil
    self.type_icon = nil
    self.color = COLORS.white
    self.tags = {}

    self.positive = true
    self.curable = true

    self.max = 0
    self.duration = 1
    self.decay = false
    self.decay_rate = 1
    self.tick_type = "TURN_START"
end

---(OVERRIDES)

---@return string name
function Status:getDisplayName() return self.name end
---@return string path
function Status:getIcon() return self.icon or (self:isPositive() and "ui/menu/icon/up" or "ui/menu/icon/down") end
function Status:getTypeIcon() return self.type_icon end
---@param index number
---@return table<number> color
function Status:getColor(index)
    if (type(self.color[1]) == "table") then
        return self.color[index]
    end
    return self.color
end
---@param tag string
---@return boolean
function Status:hasTag(tag) return Utils.containsValue(self.tags, tag) end

---@return boolean
function Status:isPositive() return self.positive end
---@return boolean
function Status:isCurable() return self.curable end
---@return boolean
function Status:isReplacable() return self:isPositive() or self:isCurable() end

---@return number
function Status:getMaxStacking() return self.max end
---@return number
function Status:getDefaultDuration() return self.duration end

---@return boolean
function Status:shouldDecay() return self.decay end
---@return number
function Status:getDecayRate() return self.decay_rate end

---@return string
function Status:getTickType() return self.tick_type end

function Status:onApply(battler, effect) end

function Status:onUpdate(battler, effect, old) end
Status.onUpdate = nil

function Status:onTurnStart(battler, effect) end
Status.onTurnStart = nil

function Status:onTurnEnd(battler, effect) end
Status.onTurnEnd = nil

function Status:onDefendStart(battler, effect) end
Status.onDefendStart = nil

function Status:onDefendEnd(battler, effect) end
Status.onDefendEnd = nil

function Status:onEnd(battler, effect, reason) end

function Status:onHurt(battler, effect, amount) end
Status.onHurt = nil

function Status:onAttack(battler, effect) end
Status.onAttack = nil

function Status:onCast(battler, effect, spell) end
Status.onCast = nil

return Status