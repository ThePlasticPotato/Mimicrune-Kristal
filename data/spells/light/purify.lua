local spell, super = Class(Spell, "purify")

function spell:init()
    super.init(self)

    -- Display name
    self.name = "Purify"
    -- Name displayed when cast (optional)
    self.cast_name = nil

    -- Battle description
    self.effect = "Purify\nAGONY"
    
    -- Menu description
    self.description = "You... haven't found a use for this yet."

    -- TP cost
    self.cost = 100

    -- Target mode (ally, party, enemy, enemies, or none)
    self.target = "enemies"

    -- Tags that apply to this spell
    self.tags = {"purify", "finisher", "light"}
end

function spell:onCast(user, target)
end

function spell:hasWorldUsage(chara)
    return false
end

return spell