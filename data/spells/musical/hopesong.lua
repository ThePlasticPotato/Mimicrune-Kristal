local spell, super = Class(Spell, "hopesong")

function spell:init()
    super.init(self)

    -- Display name
    self.name = "BigBite"
    -- Name displayed when cast (optional)
    self.cast_name = nil

    -- Battle description
    self.effect = "One and done"
    
    -- Menu description
    self.description = "Out of the picture."

    -- TP cost
    self.cost = 100
    self.note_min = 3

    -- Target mode (ally, party, enemy, enemies, or none)
    self.target = "enemy"

    -- Tags that apply to this spell
    self.tags = {"heal", "musical", "buff"}
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
    user.songstrument = "trumpet"
end

function spell:hasWorldUsage(chara)
    return false
end

return spell