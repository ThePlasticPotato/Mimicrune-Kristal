local item, super = Class(HealItem, "fizzyfaz")

function item:init()
    super.init(self)

    -- Display name
    self.name = "FizzyFaz"
    -- Name displayed when used in battle (optional)
    self.use_name = nil

    -- Item type (item, key, weapon, armor)
    self.type = "item"

    -- Battle description
    self.effect = "Lukewarm and painfully fizzy.\nHurts 10HP, Boosts ATK"
    -- Shop description
    self.shop = ""
    self.menu_image = "fizzy_faz"
    -- Menu description
    self.description = "FazEnt Soda. Always somehow tastes lukewarm... and painfully fizzy.\nHurts 10HP, Boosts ATK"

    -- Amount healed (HealItem variable)
    self.heal_amount = -10
    self.buffs = {
        {"attack", 3, 1, true}
    }

    -- Default shop price (sell price is halved)
    self.price = 2
    -- Whether the item can be sold
    self.can_sell = true

    -- Consumable target mode (ally, party, enemy, enemies, or none)
    self.target = "ally"
    -- Where this item can be used (world, battle, all, or none/nil)
    self.usable_in = "all"
    -- Item this item will get turned into when consumed
    self.result_item = nil
    -- Will this item be instantly consumed in battles?
    self.instant = false

    -- Character reactions (key = party member id)
    self.reactions = {
        evan = "(...ow...)",
        cassidy = "I can feel my teeth disintegrating...",
        fredbear = "I'm not much for 'pop'."
    }
end

return item