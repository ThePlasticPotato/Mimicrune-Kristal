local spell, super = Class(Spell, "flashbang")

function spell:init()
    super.init(self)

    -- Display name
    self.name = "Flashbang"
    -- Name displayed when cast (optional)
    self.cast_name = nil

    -- Battle description
    self.effect = "Disorient\nfoes"
    
    -- Menu description
    self.description = "Your light disorients your enemies momentarily, weakening them."

    -- TP cost
    self.cost = 32

    -- Target mode (ally, party, enemy, enemies, or none)
    self.target = "enemies"

    -- Tags that apply to this spell
    self.tags = {"debuff", "light"}
end

function spell:onCast(user, target)
end

function spell:hasWorldUsage(chara)
    return false
end

return spell