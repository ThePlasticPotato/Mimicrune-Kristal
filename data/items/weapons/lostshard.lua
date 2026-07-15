local item, super = Class(Item, "lostshard")

function item:init()
    super.init(self)

    -- Display name
    self.name = "LostShard"

    -- Item type (item, key, weapon, armor)
    self.type = "weapon"
    -- Item icon (for equipment)
    self.icon = "ui/menu/icon/shard"

    -- Battle description
    self.effect = ""
    -- Shop description
    self.shop = ""
    -- Menu description
    self.menu_image = "black_shard"
    self.description = "An ancient fragment of something in the depths.\nInflicts fatal wounds."

    -- Default shop price (sell price is halved)
    self.price = 0
    -- Whether the item can be sold
    self.can_sell = false

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
        attack = 16,
    }
    -- Bonus name and icon (displayed in equip menu)
    self.bonus_name = ""
    self.bonus_icon = "ui/menu/icon/shard"

    -- Equippable characters (default true for armors, false for weapons)
    self.can_equip = {
        kris = true,
        noelle = true,
        evan = true,
        vessel = true
    }

    -- Character reactions
    self.reactions = {
    }
end

function item:convertToLightEquip(chara)
    return "light/blackshard"
end

function item:convertToLight(inventory)
    return "light/blackshard"
end

function item:getAttackSprite(battler, enemy, points)
    return "effects/attack/shard"
end

return item
