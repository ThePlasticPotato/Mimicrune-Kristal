local spell, super = Class(Spell, "bigbite")

function spell:init()
    super.init(self)

    -- Display name
    self.name = "BigBite"
    -- Name displayed when cast (optional)
    self.cast_name = nil

    -- Battle description
    self.effect = "One and\ndone"
    
    -- Menu description
    self.description = "Out of the picture."

    -- TP cost
    self.cost = 100

    -- Target mode (ally, party, enemy, enemies, or none)
    self.target = "enemy"

    -- Tags that apply to this spell
    self.tags = {"violence"}
end

function spell:onCast(user, target)
end

function spell:hasWorldUsage(chara)
    return false
end

return spell