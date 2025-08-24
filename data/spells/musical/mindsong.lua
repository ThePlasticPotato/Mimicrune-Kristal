local spell, super = Class(Spell, "mindsong")

function spell:init()
    super.init(self)

    -- Display name
    self.name = "Aegis"
    -- Name displayed when cast (optional)
    self.cast_name = nil

    -- Battle description
    self.effect = "Protect\nallies"
    
    -- Menu description
    self.description = "Your light shields your friends from harm."

    -- TP cost
    self.cost = 32

    -- Target mode (ally, party, enemy, enemies, or none)
    self.target = "party"

    -- Tags that apply to this spell
    self.tags = {"spare_tired", "musical", "buff"}
end

function spell:onCast(user, target)
end

function spell:hasWorldUsage(chara)
    return false
end

return spell