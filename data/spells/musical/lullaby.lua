local spell, super = Class(Spell, "lullaby")

function spell:init()
    super.init(self)

    -- Display name
    self.name = "Lullaby"
    -- Name displayed when cast (optional)
    self.cast_name = nil

    -- Battle description
    self.effect = "Spare\ntired"
    
    -- Menu description
    self.description = "Your light shields your friends from harm."

    -- TP cost
    self.cost = 32

    -- Target mode (ally, party, enemy, enemies, or none)
    self.target = "party"

    -- Tags that apply to this spell
    self.tags = {"spare_tired", "musical"}
end

function spell:onCast(user, target)
end

function spell:hasWorldUsage(chara)
    return false
end

return spell