local spell, super = Class(Spell, "bodybash")

function spell:init()
    super.init(self)

    -- Display name
    self.name = "BodyBash"
    -- Name displayed when cast (optional)
    self.cast_name = "Body Bash"

    -- Battle description
    self.effect = "Self\nprojectile."
    
    -- Menu description
    self.description = "Sometimes, your body IS the ammunition."

    -- TP cost
    self.cost = 40
    self.note_min = 1
    self.musical = true

    -- Target mode (ally, party, enemy, enemies, or none)
    self.target = "enemy"

    -- Tags that apply to this spell
    self.tags = {"violence", "musical"}
end

function spell:onCast(user, target)
    local damage = (user.chara:getStat("magic") * 4) + (user.chara:getHealth() / 2)
    local self_damage = math.min(-1 * (1 - user.chara:getHealth()), damage)
    user:hurt(self_damage, true, COLORS.purple)
    target:hurt(damage * math.max(user.chara.notes, 1), true, COLORS.purple)
end

function spell:hasWorldUsage(chara)
    return false
end

return spell