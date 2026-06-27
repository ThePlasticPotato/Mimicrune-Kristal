local spell, super = Class(Spell, "guardian")

function spell:init()
    super.init(self)

    -- Display name
    self.name = "Guardian"
    -- Name displayed when cast (optional)
    self.cast_name = nil

    self.effect = "Defend ally"

    -- Menu description
    self.description = "Shield a party member with the light of your SOUL."

    -- TP cost
    self.cost = 16

    -- Target mode (ally, party, enemy, enemies, or none)
    self.target = "ally"

    -- Tags that apply to this spell
    self.tags = {"defend"}
end

function spell:onCast(user, target)
    super.onCast(self, user, target)
    target.protected = true
end

function spell:hasWorldUsage(chara)
    return false
end

return spell