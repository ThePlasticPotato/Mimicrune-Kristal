local spell, super = Class(Spell, "heartbind")

function spell:init()
    super.init(self)

    -- Display name
    self.name = "Heartbind"
    -- Name displayed when cast (optional)
    self.cast_name = nil

    -- Battle description
    self.effect = "Bind vitality"

    -- Menu description
    self.description = "Binds to an ally, splitting damage taken by one between two."

    -- TP cost
    self.cost = 32

    -- Target mode (ally, party, enemy, enemies, or none)
    self.target = "ally"

    -- Tags that apply to this spell
    self.tags = {"defend", "soul"}
end

function spell:onCast(user, target)
    super.onCast(self, user, target)
    target:addStatus({effect = "heartbound", duration = Game:getFlag("heartbind_upgrade", false) and 3 or 1, stacks = 1, source = user}, false, false)
end

function spell:hasWorldUsage(chara)
    return false
end

return spell