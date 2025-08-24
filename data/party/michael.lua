local character, super = Class(PartyMember, "michael")

function character:init()
    super.init(self)
        -- Display name
    self.name = "Michael"

    -- Actor (handles overworld/battle sprites)
    self:setActor("michael")
    self:setLightActor("michael_lw")

    -- Display level (saved to the save file)
    self.level = 1 -- todo: make this based on mimicrune chapters
    -- Default title / class (saved to the save file)
    self.title = "Berzerker\nBig bro.\nEasily frustrated."

    -- Determines which character the soul comes from (higher number = higher priority)
    self.soul_priority = 0
    -- The color of this character's soul (optional, defaults to red)
    self.soul_color = nil

    -- Whether the party member can act / use spells
    self.has_act = true
    self.has_spells = true

    -- Whether the party member can use their X-Action
    self.has_xact = false
    -- X-Action name (displayed in this character's spell menu)
    self.xact_name = "M-Action"

    -- Spells
    self:addKnownSpell("rude_buster", true)

    -- Current health (saved to the save file)
    self.health = 180

    -- Base stats (saved to the save file)
    self.stats = {
        health = 180,
        attack = 8,
        defense = 2,
        magic = 7
    }

    -- Max stats from level-ups
    self.max_stats = {
        health = 250
    }

    self.lw_health = 40
    self.lw_stats = {
        health = 40,
        attack = 4,
        defense = 1
    }

    -- Weapon icon in equip menu
    self.weapon_icon = "ui/menu/equip/greatsword"

    -- Equipment (saved to the save file)
    self:setWeapon("blackshard")
    self:setArmor(1, "spikeband")
    --self:setArmor(2, "amber_card")

    -- Default light world equipment item IDs (saves current equipment)
    self.lw_weapon_default = "light/pencil"
    self.lw_armor_default = "light/bandage"

    -- Character color (for action box outline and hp bar)
    self.color = {1, 0, 2/255}

    -- Head icon in the equip / power menu
    self.menu_icon = "party/michael/head"
    -- Path to head icons used in battle
    self.head_icons = "party/michael/icon"
    -- Name sprite
    self.name_sprite = "party/michael/name"
    
    -- Pitch of the attack sound
    self.attack_sound = "laz_c"
    self.attack_pitch = 0.8

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
        self:increaseStat("attack", 1)
    end
    if level % 10 == 0 then
        self:increaseStat("health", 1)
        self:increaseStat("magic", 1)
    end
end

function character:getLightHeadIcon()
    return "party/michael/light/head"
end

return character