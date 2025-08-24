local character, super = Class(PartyMember, "elizabeth")

function character:init()
    super.init(self)
        -- Display name
    self.name = "Elizabeth"

    -- Actor (handles overworld/battle sprites)
    self:setActor("elizabeth")
    self:setLightActor("elizabeth_lw")

    -- Display level (saved to the save file)
    self.level = 1 -- todo: make this based on mimicrune chapters
    -- Default title / class (saved to the save file)
    self.title = "Ice Mage\nOut of her element.\nQuick to retort."

    -- Determines which character the soul comes from (higher number = higher priority)
    self.soul_priority = 0
    -- The color of this character's soul (optional, defaults to red)
    self.soul_color = {118/255, 66/255, 238/255}

    -- Whether the party member can act / use spells
    self.has_act = true
    self.has_spells = true

    -- Whether the party member can use their X-Action
    self.has_xact = false
    -- X-Action name (displayed in this character's spell menu)
    self.xact_name = "L-Action"

    -- Spells
    self:addKnownSpell("ice_shock", true)

    -- Current health (saved to the save file)
    self.health = 80

    -- Base stats (saved to the save file)
    self.stats = {
        health = 80,
        attack = 5,
        defense = 1,
        magic = 8
    }

    -- Max stats from level-ups
    self.max_stats = {
        health = 100
    }

    self.lw_health = 20
    self.lw_stats = {
        health = 20,
        attack = 1,
        defense = 1
    }

    -- Weapon icon in equip menu
    self.weapon_icon = "ui/menu/equip/scarf"

    -- Equipment (saved to the save file)
    self:setWeapon("cheerscarf")
    self:setArmor(1, "pink_ribbon")
    --self:setArmor(2, "amber_card")

    -- Default light world equipment item IDs (saves current equipment)
    self.lw_weapon_default = "light/cards"
    self.lw_armor_default = "light/bandage"

    -- Character color (for action box outline and hp bar)
    self.color = {223/255, 113/255, 38/255}
    -- Damage color (for the number when attacking enemies) (defaults to the main color)
    self.dmg_color = {223/255, 113/255, 38/255}
    -- Attack bar color (for the target bar used in attack mode) (defaults to the main color)
    self.attack_bar_color = {223/255, 113/255, 38/255}
    -- Attack box color (for the attack area in attack mode) (defaults to darkened main color)
    self.attack_box_color = {124/255, 31/255, 37/255}
    -- X-Action color (for the color of X-Action menu items) (defaults to the main color)
    self.xact_color = {223/255, 113/255, 38/255}

    -- Head icon in the equip / power menu
    self.menu_icon = "party/elizabeth/head"
    -- Path to head icons used in battle
    self.head_icons = "party/elizabeth/icon"
    -- Name sprite
    self.name_sprite = "party/elizabeth/name"
    
    -- Pitch of the attack sound
    self.attack_pitch = 1.1

    -- Battle position offset (optional)
    self.battle_offset = nil
    -- Head icon position offset (optional)
    self.head_icon_offset = nil
    -- Menu icon position offset (optional)
    self.menu_icon_offset = nil

    -- Message shown on gameover (optional)
    self.gameover_message = nil
end

function character:onLevelUp(level)
    self:increaseStat("health", 2)
    if level % 2 == 0 then
        self:increaseStat("health", 1)
    end
    if level % 10 == 0 then
        self:increaseStat("attack", 1)
        self:increaseStat("magic", 2)
    end
end

function character:getLightHeadIcon()
    return "party/elizabeth/light/head"
end

return character