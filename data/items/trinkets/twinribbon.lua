local item, super = Class(Item, "twinribbon")

function item:init()
    super.init(self)

    -- Display name
    self.name = "TwinRibbon"

    -- Item type (item, key, weapon, armor)
    self.type = "trinket"
    -- Item icon (for equipment)
    self.icon = "ui/menu/icon/bowtie"
    self.menu_image = "twin_ribbons"

    -- Battle description
    self.effect = ""
    -- Shop description
    self.shop = ""
    -- Menu description
    self.description = "Two ribbons. You'll have to put\nyour hair into pigtails."

    -- Default shop price (sell price is halved)
    self.price = 400
    -- Whether the item can be sold
    self.can_sell = true

    -- Consumable target mode (ally, party, enemy, enemies, or none)
    self.target = "none"
    -- Where this item can be used (world, battle, all, or none)
    self.usable_in = "all"
    -- Item this item will get turned into when consumed
    self.result_item = nil
    -- Will this item be instantly consumed in battles?
    self.instant = false

    -- Equip bonuses (for weapons and armor)
    self.bonuses = {
        defense = 3,

        graze_size = 0.2,
    }
    -- Bonus name and icon (displayed in equip menu)
    self.bonus_name = "GrazeArea"
    self.bonus_icon = "ui/menu/icon/up"

    -- Equippable characters (default true for armors, false for weapons)
    self.can_equip = {
        susie = false,
        evan = false,
        fredbear = false
    }

    -- Character reactions
    self.reactions = {
        susie = "NOT the hair though.",
        ralsei = "Try around my horns!",
        noelle = "... nostalgic, huh.",
        evan = "I, um, draw the line at one.",
        cassidy = {
            cassidy = "Yeah, this works.",
            evan = "I think it's cute..."
        },
        fredbear = "Far too much bow for me."
    }
    self.susie_rejection = "... it gets worse and worse."
end

function item:canEquip(character, slot_type, slot_index)
    if character.id == "susie" and not character:getFlag("can_wear_ribbons", false) then
        return false
    end

    return super.canEquip(self, character, slot_type, slot_index)
end

function item:getReaction(user_id, reactor_id)
    if user_id == "susie" and reactor_id == "susie" then
        local susie = Game:getPartyMember("susie")

        if not susie:getFlag("can_wear_ribbons", false) then
            return self.susie_rejection
        end
    end

    return super.getReaction(self, user_id, reactor_id)
end

return item
