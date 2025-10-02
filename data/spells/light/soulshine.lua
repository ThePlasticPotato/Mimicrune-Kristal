local spell, super = Class(Spell, "soulshine")

function spell:init()
    super.init(self)

    -- Display name
    self.name = "Soul Shine"
    -- Name displayed when cast (optional)
    self.cast_name = nil

    -- Battle description
    self.effect = "Empower ally"

    -- Menu description
    self.description = "Your SOUL's light shines on an ally, empowering their next strike."

    -- TP cost
    self.cost = 25

    -- Target mode (ally, party, enemy, enemies, or none)
    self.target = "ally"

    -- Tags that apply to this spell
    self.tags = {"buff", "violence", "soul"}
end

function spell:onCast(user, target)
    local effect = Registry.createStatus("attack")
    effect.consume_on_trigger = true
    target:addStatus({effect = effect, source = user, duration = 3, stacks = math.max(math.floor(user.chara:getStat("magic") / 5), 1)}, true, false)
end

function spell:hasWorldUsage(chara)
    return false
end

return spell