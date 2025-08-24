local item, super = Class(Item, "classicmic")

function item:init()
    super.init(self)

    -- Display name
    self.name = "Classic Mic"
    -- Name displayed when used in battle (optional)
    self.use_name = nil

    -- Item type (item, key, weapon, armor)
    self.type = "weapon"
    -- Item icon (for equipment)
    self.icon = "ui/menu/icon/mic"
    -- Whether this item is for the light world
    self.light = false

    -- Battle description
    self.effect = "...It's a microphone.'"
    -- Shop description
    self.shop = "Kind of dull."
    -- Menu description
    self.description = "Fredbear's trusty microphone.\nWell used."
    -- Light world check text
    self.check = "A plastic microphone."

    -- Default shop price (sell price is halved)
    self.price = 0
    -- Whether the item can be sold
    self.can_sell = false

    -- Equip bonuses (for weapons and armor)
    self.bonuses = {
        attack = 4,
        defense = 1
    }

    self.can_equip = {
        fredbear = true
    }

    self.reactions = {
        evan = "(Does it even work??)",
        cassidy = "I'm... not a singer.",
        fredbear = "Testing, testing... good as new!"
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