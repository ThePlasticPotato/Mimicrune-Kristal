local spell, super = Class(Spell, "deathtoll")

function spell:init()
    super.init(self)

    -- Display name
    self.name = "Death Toll"
    -- Name displayed when cast (optional)
    self.cast_name = nil

    -- Battle description
    self.effect = "Finish off\nfoes"
    
    -- Menu description
    self.description = "You toll the bell of death, causing enemies to feel the echoes."

    -- TP cost
    self.cost = 15

    -- Target mode (ally, party, enemy, enemies, or none)
    self.target = "enemies"

    -- Tags that apply to this spell
    self.tags = {"violence", "light"}
end

function spell:onCast(user, target)
end

function spell:hasWorldUsage(chara)
    return false
end

return spell