local item, super = Class(Item, "faz_bowtie")

function item:init()
    super.init(self)

    -- Display name
    self.name = "Fazbear Bowtie"
    -- Name displayed when used in battle (optional)
    self.use_name = nil

    -- Item type (item, key, weapon, armor)
    self.type = "armor"
    -- Item icon (for equipment)
    self.icon = "ui/menu/icon/bowtie"
    -- Whether this item is for the light world
    self.light = false

    -- Battle description
    self.effect = "...It's a bowtie.'"
    -- Shop description
    self.shop = "A snazzy bowtie. Reminiscent of a\ncertain plushie turned prince..."
    -- Menu description
    self.description = "A snazzy bowtie. Reminiscent of a\ncertain plushie turned prince..."
    -- Light world check text
    self.check = "A snazzy bowtie. Reminiscent of a\ncertain plushie turned prince..."

    -- Default shop price (sell price is halved)
    self.price = 0
    -- Whether the item can be sold
    self.can_sell = false

    -- Equip bonuses (for weapons and armor)
    self.bonuses = {
        defense = 2
    }

    self.can_equip = {
        cassidy = false
    }

    self.reactions = {
        evan = "...Do I look alright?",
        cassidy = "That'd be far too much bow to handle.",
        fredbear = "Snazzy as always!"
    }

    -- Bonus name and icon (displayed in equip menu)
    self.bonus_name = "Style"
    self.bonus_icon = "ui/menu/icon/up"

    -- Consumable target mode (ally, party, enemy, enemies, or none)
    self.target = "none"
    -- Where this item can be used (world, battle, all, or none)
    self.usable_in = "none"
end

return item