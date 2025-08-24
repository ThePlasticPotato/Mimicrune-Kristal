local character, super = Class(PartyMember, "fredbear")

function character:init()
    super.init(self)
        -- Display name
    self.name = "Fredbear"

    -- Actor (handles overworld/battle sprites)
    self:setActor("fredbear")

    -- Display level (saved to the save file)
    self.level = 1 -- todo: make this based on mimicrune chapters
    -- Default title / class (saved to the save file)
    self.title = "Tank\nCuddly and fuzzy\nfriend in the dark."

    -- Determines which character the soul comes from (higher number = higher priority)
    self.soul_priority = 0
    -- The color of this character's soul (optional, defaults to red)
    self.soul_color = {118/255, 66/255, 238/255}

    -- Whether the party member can act / use spells
    self.has_act = false
    self.has_spells = true

    -- Whether the party member can use their X-Action
    self.has_xact = true
    -- X-Action name (displayed in this character's spell menu)
    self.xact_name = "F-Action"

    -- Spells
    self:addKnownSpell("bodybash", true)
    self:addKnownSpell("hypesong", true)

    -- Current health (saved to the save file)
    self.health = 225

    -- Base stats (saved to the save file)
    self.stats = {
        health = 225,
        attack = 4,
        defense = 16,
        magic = 2
    }

    -- Max stats from level-ups
    self.max_stats = {
        health = 500
    }

    self.is_musical = true

    -- Weapon icon in equip menu
    self.weapon_icon = "ui/menu/equip/mic"

    -- Equipment (saved to the save file)
    self:setWeapon("classicmic")
    self:setArmor(1, "faz_bowtie")
    --self:setArmor(2, "amber_card")

    -- Character color (for action box outline and hp bar)
    self.color = {118/255, 66/255, 238/255}
    -- Damage color (for the number when attacking enemies) (defaults to the main color)
    self.dmg_color = {118/255, 66/255, 238/255}
    -- Attack bar color (for the target bar used in attack mode) (defaults to the main color)
    self.attack_bar_color = {118/255, 66/255, 238/255}
    -- Attack box color (for the attack area in attack mode) (defaults to darkened main color)
    self.attack_box_color = {64/255, 23/255, 93/255}
    -- X-Action color (for the color of X-Action menu items) (defaults to the main color)
    self.xact_color = {118/255, 66/255, 238/255}

    -- Head icon in the equip / power menu
    self.menu_icon = "party/fredbear/head"
    -- Path to head icons used in battle
    self.head_icons = "party/fredbear/icon"
    -- Name sprite
    self.name_sprite = "party/fredbear/name"
    
    -- Pitch of the attack sound
    self.attack_sprite = "effects/attack/slap_f"
    self.attack_sound = "michit"
    self.attack_pitch = 1.0

    -- Battle position offset (optional)
    self.battle_offset = nil
    -- Head icon position offset (optional)
    self.head_icon_offset = nil
    -- Menu icon position offset (optional)
    self.menu_icon_offset = nil

    -- Message shown on gameover (optional)
    self.gameover_message = nil
end

function character:onAttackHit(enemy, damage)
    if damage > 0 then
        Assets.playSound("impact", 0.8)
        Game.battle:shakeCamera(2)
    end
end

function character:onTurnStart(battler)
    super.onTurnStart(self, battler)
    if (battler.sing_level) then
        battler.sing_level = 0
    end
    if (not battler.was_hit_last) then
        self.notes = math.min(self.notes + 1, 3)
        Assets.playSound("bell_bounce_short")
    end
    battler.was_hit_last = false
end

function character:onLevelUp(level)
    self:increaseStat("health", 4)
    if level % 2 == 0 then
        self:increaseStat("health", 1)
    end
    if level % 10 == 0 then
        self:increaseStat("attack", 1)
        self:increaseStat("magic", 1)
    end
end

function character:getLightHeadIcon()
    return "party/fredbear/light"
end

return character