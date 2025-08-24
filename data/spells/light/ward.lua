local spell, super = Class(Spell, "ward")

function spell:init()
    super.init(self)

    -- Display name
    self.name = "Ward"
    -- Name displayed when cast (optional)
    self.cast_name = nil

    -- Battle description
    self.effect = "Save\nallies"
    
    -- Menu description
    self.description = "Your light embraces an ally, preventing their next fall."

    -- TP cost
    self.cost = 32

    -- Target mode (ally, party, enemy, enemies, or none)
    self.target = "ally"

    -- Tags that apply to this spell
    self.tags = {"defend", "light"}
end

function spell:onCast(user, target)
end

function spell:hasWorldUsage(chara)
    return false
end

return spell