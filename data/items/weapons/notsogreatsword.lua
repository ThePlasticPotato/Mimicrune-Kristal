local item, super = Class(Item, "notsogreatsword")

function item:init()
    super.init(self)

    -- Display name
    self.name = "NotSoGrtswrd"
    -- Name displayed when used in battle (optional)
    self.use_name = nil

    -- Item type (item, key, weapon, armor)
    self.type = "weapon"
    -- Item icon (for equipment)
    self.icon = "ui/menu/icon/greatsword"
    -- Whether this item is for the light world
    self.light = false

    -- Battle description
    self.effect = "...It's a sword.'"
    -- Shop description
    self.shop = "Kind of dull."
    -- Menu description
    self.description = "A greatsword. Not bad for defense,\nbut its edge is kind of dull..."
    -- Light world check text
    self.check = "A gnarled tree branch."

    -- Default shop price (sell price is halved)
    self.price = 0
    -- Whether the item can be sold
    self.can_sell = false

    -- Equip bonuses (for weapons and armor)
    self.bonuses = {
        attack = 2,
        defense = 4
    }

    self.can_equip = {
        evan = true
    }

    self.reactions = {
        evan = "It's... not great... but it'll do...",
        cassidy = "Is it... bent? Or is it ment to be?",
        fredbear = "(Evan, where did you get this??)"
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