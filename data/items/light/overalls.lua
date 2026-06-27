local item, super = Class(Item, "overalls")

function item:init()
    super.init(self)

    -- Display name
    self.name = "Overalls"
    -- Name displayed when used in battle (optional)
    self.use_name = nil

    -- Item type (item, key, weapon, armor)
    self.type = "armor"
    -- Item icon (for equipment)
    self.icon = "ui/menu/icon/overalls"
    -- Whether this item is for the light world
    self.light = true

    -- Battle description
    self.effect = "...It's a pair of overmosts.'"
    -- Shop description
    self.shop = "Overalls."
    -- Menu description
    self.description = "Black-strap overalls."
    -- Light world check text
    self.check = "Black-strap overalls."

    -- Default shop price (sell price is halved)
    self.price = 0
    -- Whether the item can be sold
    self.can_sell = false

    -- Equip bonuses (for weapons and armor)
    self.bonuses = {
        defense = 4
    }

    self.can_equip = {
        cassidy = true,
        fredbear = false,
        evan = false
    }

    self.reactions = {
        evan = "...not really my style...",
        cassidy = "The classic.",
        fredbear = "(I think it's a size or two too small...)"
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