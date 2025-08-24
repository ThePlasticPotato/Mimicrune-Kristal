local item, super = Class(Item, "promisering")

function item:init()
    super.init(self)

    -- Display name
    self.name = "Promise Ring"
    -- Name displayed when used in battle (optional)
    self.use_name = nil

    -- Item type (item, key, weapon, armor)
    self.type = "weapon"
    -- Item icon (for equipment)
    self.icon = "ui/menu/icon/ring"
    -- Whether this item is for the light world
    self.light = false

    -- Battle description
    self.effect = "...It's a promise."
    -- Shop description
    self.shop = "Represents a great promise."
    -- Menu description
    self.description = "A ring, holding deep meaning.\nYou feel power coursing within..."
    -- Light world check text
    self.check = "It's a ring."

    -- Default shop price (sell price is halved)
    self.price = 0
    -- Whether the item can be sold
    self.can_sell = false

    -- Equip bonuses (for weapons and armor)
    self.bonuses = {
        attack = 10,
        magic = 16
    }

-- Bonus name and icon (displayed in equip menu)
    self.bonus_name = "Power UP"
    self.bonus_icon = "ui/menu/icon/fire"

    self.can_equip = {
        cassidy = true
    }

    self.reactions = {
        evan = "(...this is... not for me...)",
        cassidy = "...What? ...Don't look at me like that...",
        fredbear = "It's beautiful. But it's not mine."
    }

    

    -- Consumable target mode (ally, party, enemy, enemies, or none)
    self.target = "none"
    -- Where this item can be used (world, battle, all, or none)
    self.usable_in = "none"
end

return item