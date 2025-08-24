local spell, super = Class(Spell, "cure")

function spell:init()
    super.init(self)

    -- Display name
    self.name = "Cure"
    -- Name displayed when cast (optional)
    self.cast_name = nil

    -- Battle description
    self.effect = "Heal\nally"
    
    -- Menu description
    self.description = "Your light restores some HP to one party member."

    -- TP cost
    self.cost = 32

    -- Target mode (ally, party, enemy, enemies, or none)
    self.target = "ally"

    -- Tags that apply to this spell
    self.tags = {"heal"}
end

function spell:calcHealing(chara)
    return (chara:getStat("magic") * 5) + (chara:getStat("defense") * 2) + (chara:getStat("health") / 4)
end

function spell:onCast(user, target)
    local base_heal = self:calcHealing(user.chara)
    local heal_amount = Game.battle:applyHealBonuses(base_heal, user.chara)

    target:heal(heal_amount)
end

function spell:hasWorldUsage(chara)
    return true
end

function spell:onWorldCast(chara)
    Game.world:heal(chara, self:calcHealing(chara))
end

return spell