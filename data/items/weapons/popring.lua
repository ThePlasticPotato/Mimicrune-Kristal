local item, super = Class(Item, "popring")

function item:init()
    super.init(self)

    -- Display name
    self.name = "PopRing"
    -- Name displayed when used in battle (optional)
    self.use_name = nil

    -- Item type (item, key, weapon, armor)
    self.type = "weapon"
    -- Item icon (for equipment)
    self.icon = "ui/menu/icon/lollipop"
    -- Whether this item is for the light world
    self.light = false

    -- Battle description
    self.effect = "...It's a ring.'"
    -- Shop description
    self.shop = "Grape-flavored."
    -- Menu description
    self.description = "A candy ring. Holds some power,\nbut is mostly just a snack..."
    -- Light world check text
    self.check = "A popring candy."

    -- Default shop price (sell price is halved)
    self.price = 0
    -- Whether the item can be sold
    self.can_sell = false

    -- Equip bonuses (for weapons and armor)
    self.bonuses = {
        attack = 2,
        magic = 4
    }

    self.can_equip = {
        cassidy = true
    }

    self.reactions = {
        evan = "(...I think Cassidy already licked it.)",
        cassidy = "Hmm. Tastes like grape soda.",
        fredbear = "Ah... I'm not hungry."
    }

    -- Bonus name and icon (displayed in equip menu)
    self.bonus_name = nil
    self.bonus_icon = nil

    -- Consumable target mode (ally, party, enemy, enemies, or none)
    self.target = "none"
    -- Where this item can be used (world, battle, all, or none)
    self.usable_in = "none"
end

return item