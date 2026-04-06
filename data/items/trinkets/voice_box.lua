local item, super = Class(Item, "voice_box")

function item:init()
    super.init(self)

    -- Display name
    self.name = "Voice Box"
    -- Name displayed when used in battle (optional)
    self.use_name = nil

    -- Item type (item, key, weapon, armor)
    self.type = "trinket"
    -- Item icon (for equipment)
    self.icon = "ui/menu/icon/note"
    -- Whether this item is for the light world
    self.light = false

    -- Battle description
    self.effect = ""
    -- Shop description
    self.shop = "Sing\nbetter"
    -- Menu description
    self.menu_image = "voice_box"
    self.description = "A voice box, to improve an Animatronic's singing prowess."
    -- Light world check text
    self.check = "A broken walkie-talkie."

    -- Default shop price (sell price is halved)
    self.price = 0
    -- Whether the item can be sold
    self.can_sell = false

    -- Equip bonuses (for weapons and armor)
    self.bonuses = {
        magic = 2,
        starting_notes = 1
    }

    self.can_equip = {
        cassidy = false
    }

    self.reactions = {
        evan = "(I can't... um...)",
        cassidy = "What do you want me to do with this? Swallow it??",
        fredbear = "Testing, testing- Do~Re~Mi~!"
    }

    -- Bonus name and icon (displayed in equip menu)
    self.bonus_name = "Singing"
    self.bonus_icon = "ui/menu/icon/up"

    -- Consumable target mode (ally, party, enemy, enemies, or none)
    self.target = "none"
    -- Where this item can be used (world, battle, all, or none)
    self.usable_in = "none"

    self.animatronic_only = true
end

return item