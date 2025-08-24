local spell, super = Class(Spell, "heartbind")

function spell:init()
    super.init(self)

    -- Display name
    self.name = "Heartbind"
    -- Name displayed when cast (optional)
    self.cast_name = nil

    -- Battle description
    self.effect = "Bind\nhealth"

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