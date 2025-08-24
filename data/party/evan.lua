local character, super = Class(PartyMember, "evan")

function character:init()
    super.init(self)
        -- Display name
    self.name = "Evan"

    -- Actor (handles overworld/battle sprites)
    self:setActor("evan")
    self:setLightActor("evan_lw")

    -- Display level (saved to the save file)
    self.level = 1 -- todo: make this based on mimicrune chapters
    -- Default title / class (saved to the save file)
    self.title = "Paladin\nStill learning.\nKind of a crybaby."

    -- Determines which character the soul comes from (higher number = higher priority)
    self.soul_priority = 2
    -- The color of this character's soul (optional, defaults to red)
    self.soul_color = {2/255, 1, 2/255}

    -- Whether the party member can act / use spells
    self.has_act = true
    self.has_spells = true

    -- Whether the party member can use their X-Action
    self.has_xact = false
    -- X-Action name (displayed in this character's spell menu)
    self.xact_name = "E-Action"

    -- Spells
    self:addKnownSpell("heal_prayer", true)
    self:addKnownSpell("pacify", false)

    -- Current health (saved to the save file)
    self.health = 100

    -- Base stats (saved to the save file)
    self.stats = {
        health = 100,
        attack = 3,
        defense = 10,
        magic = 5
    }

    -- Max stats from level-ups
    self.max_stats = {
        health = 200
    }

    self.lw_health = 30
    self.lw_stats = {
        health = 30,
        attack = 4,
        defense = 12
    }

    -- Weapon icon in equip menu
    self.weapon_icon = "ui/menu/equip/greatsword"

    -- Equipment (saved to the save file)
    self:setWeapon("notsogreatsword")
    self:setArmor(1, "faz_bowtie")
    --self:setArmor(2, "amber_card")

    -- Default light world equipment item IDs (saves current equipment)
    self.lw_weapon_default = "stick"
    self.lw_armor_default = "light/bandage"

    -- Character color (for action box outline and hp bar)
    self.color = {2/255, 1, 2/255}
    -- Damage color (for the number when attacking enemies) (defaults to the main color)
    self.dmg_color = {2/255, 1, 2/255}
    -- Attack bar color (for the target bar used in attack mode) (defaults to the main color)
    self.attack_bar_color = {2/255, 1, 2/255}
    -- Attack box color (for the attack area in attack mode) (defaults to darkened main color)
    self.attack_box_color = {0, 0.63, 0}
    -- X-Action color (for the color of X-Action menu items) (defaults to the main color)
    self.xact_color = {2/255, 1, 2/255}

    -- Head icon in the equip / power menu
    self.menu_icon = "party/evan/head"
    -- Path to head icons used in battle
    self.head_icons = "party/evan/icon"
    -- Name sprite
    self.name_sprite = "party/evan/name"
    
    -- Pitch of the attack sound
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
        self:increaseStat("defense", 1)
    end
    if level % 10 == 0 then
        self:increaseStat("health", 1)
        self:increaseStat("magic", 1)
    end
end

function character:getLightHeadIcon()
    return "party/evan/light/head"
end

return character