local character, super = Class(PartyMember, "vessel")

function character:init()
    super.init(self)

    -- Display name
    self.name = "You"

    -- Actor (handles overworld/battle sprites)
    self:setActor("vessel")
    self:setLightActor("vessel_lw")
    --self:setDarkTransitionActor("kris_dark_transition")

    -- Display level (saved to the save file)
    self.level = 0
    -- Default title / class (saved to the save file)
    self.title = "Only You"

    -- Determines which character the soul comes from (higher number = higher priority)
    self.soul_priority = 10
    -- The color of this character's soul (optional, defaults to red)
    self.soul_color = COLORS.gray

    -- Whether the party member can act / use spells
    self.has_act = true
    self.has_spells = false

    -- Whether the party member can use their X-Action
    self.has_xact = false
    -- X-Action name (displayed in this character's spell menu)
    self.xact_name = "V-Action"

    -- Current health (saved to the save file)
    self.health = 240

    -- Base stats (saved to the save file)
    self.stats = {
        health = 240,
        attack = 17,
        defense = 2,
        magic = 0
    }

    -- Max stats from level-ups
    self.max_stats = {
        health = 280,
        attack = 19
    }

    -- Party members which will also get stronger when this character gets stronger, even if they're not in the party
    self.stronger_absent = {}

    -- Weapon icon in equip menu
    self.weapon_icon = "ui/menu/equip/sword"

    -- Equipment (saved to the save file)
    self:setWeapon("lostshard")

    -- Character color (for action box outline and hp bar)
    self.color = COLORS.dkgray
    -- Damage color (for the number when attacking enemies) (defaults to the main color)
    self.dmg_color = COLORS.gray
    -- Attack bar color (for the target bar used in attack mode) (defaults to the main color)
    self.attack_bar_color = COLORS.gray
    -- Attack box color (for the attack area in attack mode) (defaults to darkened main color)
    self.attack_box_color = COLORS.gray
    -- X-Action color (for the color of X-Action menu items) (defaults to the main color)
    self.xact_color = COLORS.gray

    -- Head icon in the equip / power menu
    self.menu_icon = "party/vessel/head"
    -- Path to head icons used in battle
    self.head_icons = "party/vessel/icon"
    -- Name sprite
    self.name_sprite = "party/vessel/name"

    -- Effect shown above enemy after attacking it
    self.attack_sprite = "effects/attack/cut"
    -- Sound played when this character attacks
    self.attack_sound = "laz_c"
    -- Pitch of the attack sound
    self.attack_pitch = 1

    -- Battle position offset (optional)
    self.battle_offset = {2, 1}
    -- Head icon position offset (optional)
    self.head_icon_offset = nil
    -- Menu icon position offset (optional)
    self.menu_icon_offset = nil

    -- Message shown on gameover (optional)
    self.gameover_message = nil
end

function character:onLevelUp(level)
    self:increaseStat("health", 2)
    if level % 10 == 0 then
        self:increaseStat("attack", 1)
    end
end

return character
