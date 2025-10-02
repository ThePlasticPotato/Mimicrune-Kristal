---Statuses are data classes that represent status effects, both in and out of combat.
---@class Status : Class
---
---@field name          string          The name of the status, displayed in the menu.
---@field icon          string?         The string path to the icon of the status effect.
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
---
local Status = Class()

function Status:init()
    self.name = "Status"
    self.icon = nil
    self.color = COLORS.white
    self.tags = {}

    self.positive = true
    self.curable = true

    self.max = 0
    self.duration = 1
    self.decay = false
    self.decay_rate = 1
end

---(OVERRIDES)

---@return string name
function Status:getDisplayName() return self.name end
---@return string path
function Status:getIcon() return self.icon end
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

---@return number
function Status:getMaxStacking() return self.max end
---@return number
function Status:getDefaultDuration() return self.duration end

---@return boolean
function Status:shouldDecay() return self.decay end
---@return number
function Status:getDecayRate() return self.decay_rate end

function Status:onApply() end
Status.onApply = nil

function Status:onUpdate() end
Status.onUpdate = nil

function Status:onTurnStart() end
Status.onTurnStart = nil

function Status:onEnd(cured) end
Status.onEnd = nil

function Status:onHurt() end
Status.onHurt = nil

function Status:onAttack() end
Status.onAttack = nil

function Status:onCast(spell) end
Status.onCast = nil

return Status