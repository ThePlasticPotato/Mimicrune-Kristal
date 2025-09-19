local item, super = Class(HealItem, "kris_tea")

function item:init()
    super.init(self)

    -- Display name
    self.name = "Kris Tea"
    -- Name displayed when used in battle (optional)
    self.use_name = nil

    -- Item type (item, key, weapon, armor)
    self.type = "item"
    -- Item icon (for equipment)
    self.icon = nil

    -- Battle description
    self.effect = "Healing\nvaries"
    -- Shop description
    self.shop = ""
    -- Menu description
    self.description = "It's own-flavored tea.\nThe flavor just says \"Cassidy.\""

    -- Amount healed (HealItem variable)
    self.heal_amount = 50
    -- Amount this item heals for specific characters
    self.heal_amounts = {
        ["kris"] = 10,
        ["susie"] = 10,
        ["ralsei"] = 10,
        ["noelle"] = 10,
        ["evan"] = 200,
        ["cassidy"] = 10,
        ["fredbear"] = 120
    }

    -- Default shop price (sell price is halved)
    self.price = 10
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
        kris = {
            susie = "(No reaction?)",
            noelle = "(... no reaction?)"
        },
        susie = {
            susie = "Huh. Can't taste anything...",
            ralsei = "(Maybe because you drank it so fast...)"
        },
        ralsei = {
            ralsei = "Um... this is just water...?",
            susie = "Huh. Weird..."
        },
        noelle = "Hey, this is just water!",

        evan = {
            evan = "Bitter... with a sweet aftertaste...",
            cassidy = "What's that supposed to mean?"
        },
        cassidy = {
            cassidy = "Wait- this is just water! Ugh.",
            evan = "Are you just... tasting it... wrong?"
        },
        fredbear = "Mmm. Lemon-y!"
    }
end

function item:getBattleHealAmount(id)
    -- Dont heal less than 40HP in battles
    return math.max(40, super.getBattleHealAmount(self, id))
end

return item