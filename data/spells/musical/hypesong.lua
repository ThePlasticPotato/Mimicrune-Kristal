local spell, super = Class(Spell, "hypesong")

function spell:init()
    super.init(self)

    -- Display name
    self.name = "HypeSong"
    -- Name displayed when cast (optional)
    self.cast_name = "Hype Song"

    -- Battle description
    self.effect = "Empower musically"
    
    self.musical = true

    -- Menu description
    self.description = "Empowers allies next strikes with an energetic song."

    -- TP cost
    self.cost = 20
    self.note_min = 1

    -- Target mode (ally, party, enemy, enemies, or none)
    self.target = "party"

    -- Tags that apply to this spell
    self.tags = {"violence", "musical", "buff"}
end

function spell:onCast(user, target)
    local buff_amount = user.chara.notes + 1
    for index, value in ipairs(target) do
        if (user ~= value) then
            value:buffNextAttack(user.chara:getStat("magic", 5) * 2, false)
            value:buffNextAttack(buff_amount, true)
        end
    end

    user.sing_level = math.min(user.sing_level + user.chara.notes, 3)
    user.chara.notes = 0
    user.songstrument = "clean"
end

function spell:hasWorldUsage(chara)
    return false
end

return spell