local spell, super = Class(Spell, "meditate")

function spell:init()
    super.init(self)

    -- Display name
    self.name = "Meditate"
    -- Name displayed when cast (optional)
    self.cast_name = nil

    -- Battle description
    self.effect = "Recover\nMind"
    -- Menu description
    self.description = "Focuses mental energy to recover power and reduce heat. Depends on Magic."

    -- TP cost
    self.cost = 30

    -- Target mode (ally, party, enemy, enemies, or none)
    self.target = "none"

    self.required = true

    -- Tags that apply to this spell
    self.tags = {"psy", "heal"}
end

function spell:onCast(user, target)
    local magic = user.chara:getStat("magic")
    user.chara.neural_power = math.min(user.chara.neural_power + (magic * 5), 100)
    user.chara.heat = math.max(user.chara.heat - magic, 0)
end

return spell