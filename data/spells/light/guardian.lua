local spell, super = Class(Spell, "guardian")

function spell:init()
    super.init(self)

    -- Display name
    self.name = "Guardian"
    -- Name displayed when cast (optional)
    self.cast_name = nil

    self.effect = "Defend\nally"

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
    local base_heal = user.chara:getStat("magic") * 5
    local heal_amount = Game.battle:applyHealBonuses(base_heal, user.chara)

    target:heal(heal_amount)
end

function spell:hasWorldUsage(chara)
    return true
end

function spell:onWorldCast(chara)
    Game.world:heal(chara, 100)
end

return spell