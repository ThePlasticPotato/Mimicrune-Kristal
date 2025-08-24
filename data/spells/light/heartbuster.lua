local spell, super = Class(Spell, "heartbuster")

function spell:init()
    super.init(self)

    -- Display name
    self.name = "???"
    -- Name displayed when cast (optional)
    self.cast_name = "HEARTBUSTER"

    -- Battle description
    self.effect = "Unleash"
    
    -- Menu description
    self.description = "Your POWER."

    -- TP cost
    self.cost = 100

    -- Target mode (ally, party, enemy, enemies, or none)
    self.target = "enemy"

    -- Tags that apply to this spell
    self.tags = {"violence", "light", "attack"}
end

function spell:onCast(user, target)
end

function spell:hasWorldUsage(chara)
    return false
end

return spell