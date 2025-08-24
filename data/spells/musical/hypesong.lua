local spell, super = Class(Spell, "hypesong")

function spell:init()
    super.init(self)

    -- Display name
    self.name = "HypeSong"
    -- Name displayed when cast (optional)
    self.cast_name = "Hype Song"

    -- Battle description
    self.effect = "Empower\nmusically"
    
    self.musical = true

    -- Menu description
    self.description = "Empowers allies next strikes with an energetic song."

    -- TP cost
    self.cost = 20
    self.note_min = 1

    -- Target mode (ally, party, enemy, enemies, or none)
    self.target = "party"

    -- Tags that apply to this spell
    self.tags = {"violence", "musical", "buff"}
end

function spell:onCast(user, target)
    local buff_amount = user.chara.notes + 1
    for index, value in ipairs(target) do
        if (user ~= value) then
            value:buffNextAttack(user.chara:getStat("magic", 5) * 2, false)
            value:buffNextAttack(buff_amount, true)
        end
    end

    user.sing_level = user.chara.notes
    user.chara.notes = 0

    local current_music = Game.battle.music.current
    Game.battle.music_additional:setVolume(0)
    Game.battle.music_additional:play(current_music.."/hypesong")
    Game.battle.music_additional:seek(Game.battle.music:tell())
    Game.battle.music_additional:fade(0.8, 0.5, nil)
end

function spell:hasWorldUsage(chara)
    return false
end

return spell