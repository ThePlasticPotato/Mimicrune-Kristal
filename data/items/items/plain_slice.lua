local item, super = Class(HealItem, "plain_slice")

function item:init()
    super.init(self)

    -- Display name
    self.name = "PizzaSlice"
    -- Name displayed when used in battle (optional)
    self.use_name = "Plain Slice"

    -- Item type (item, key, weapon, armor)
    self.type = "item"
    -- Item icon (for equipment)
    self.icon = nil

    -- Battle description
    self.effect = "A slice of perfectly mediocre pizza.\nBoring, but filling. Heals 70HP"
    -- Shop description
    self.shop = "Reheated\npizza\nheals 70HP"
    -- Menu description
    self.menu_image = "pizza_slice"
    self.description = "A slice of perfectly mediocre pizza.\nBoring, but filling. +70HP"

    -- Amount healed (HealItem variable)
    self.heal_amount = 70
    -- Amount this item heals for specific characters in the overworld (optional)
    self.world_heal_amounts = {
        evan = 90,
        fredbear = 110
    }

    -- Default shop price (sell price is halved)
    self.price = 70
    -- Whether the item can be sold
    self.can_sell = true

    -- Consumable target mode (ally, party, enemy, enemies, or none)
    self.target = "ally"
    -- Where this item can be used (world, battle, all, or none)
    self.usable_in = "all"
    -- Item this item will get turned into when consumed
    self.result_item = nil
    -- Will this item be instantly consumed in battles?
    self.instant = false

    -- Equip bonuses (for weapons and armor)
    self.bonuses = {}
    -- Bonus name and icon (displayed in equip menu)
    self.bonus_name = nil
    self.bonus_icon = nil

    -- Equippable characters (default true for armors, false for weapons)
    self.can_equip = {}

    -- Character reactions (key = party member id)
    self.reactions = {
        evan = "M-My favorite...",
        cassidy = "Bland, but it's better than nothing.",
        fredbear = "Pizza!"
    }
end

return item