local actor, super = Class(Actor, "evan")

function actor:init()
    super.init(self)
        -- Display name (optional)
    self.name = "Evan"

    -- Width and height for this actor, used to determine its center
    self.width = 19
    self.height = 38

    -- Hitbox for this actor in the overworld (optional, uses width and height by default)
    self.hitbox = {0, 25, 19, 14}

    -- A table that defines where the Soul should be placed on this actor if they are a player.
    -- First value is x, second value is y.
    self.soul_offset = {10, 24}

    -- Color for this actor used in outline areas (optional, defaults to red)
    self.color = {2/255, 1, 2/255}

    -- Path to this actor's sprites (defaults to "")
    self.path = "party/evan/dark"
    -- This actor's default sprite or animation, relative to the path (defaults to "")
    self.default = "walk"
    self.default_run = "run"

    self.animations = {
                -- Battle animations
        ["battle/idle"]         = {"battle/idle", 0.2, true},
        ["battle/idle_tense"]   = {"battle/idle_tense", 0.2, true},

        ["battle/attack"]       = {"battle/attack", 1/15, false},
        ["battle/act"]          = {"battle/act", 1/15, false},
        ["battle/spell"]        = {"battle/spell", 1/15, false, next="battle/idle"},
        ["battle/item"]         = {"battle/item", 1/12, false, next="battle/idle"},
        ["battle/spare"]        = {"battle/act", 1/15, false, next="battle/idle"},

        ["battle/attack_ready"] = {"battle/attackready", 1/15, false},
        ["battle/act_ready"]    = {"battle/actready", 0.2, false},
        ["battle/spell_ready"]  = {"battle/spellready", 0.2, true},
        ["battle/item_ready"]   = {"battle/itemready", 0.2, true},
        ["battle/defend_ready"] = {"battle/defend", 0.2, true},

        ["battle/act_end"]      = {"battle/actend", 1/15, false, next="battle/idle"},

        ["battle/hurt"]         = {"battle/hurt", 1/15, false, temp=true, duration=0.5},
        ["battle/defeat"]       = {"battle/defeat", 0.2, true},

        ["battle/transition"]   = {"battle/battle_transition", 1/15, false},
        ["battle/intro"]        = {"battle/intro", 1/15, true},
        ["battle/victory"]      = {"battle/victory", 1/10, false},

        ["dash"]   = {"dash", 1/15, true},
        ["skid"] = {"skid", 0.15, false},
    }

    self.offsets = {
        ["battle/act"] = {-19, -11};
        ["battle/actend"] = {-19, -11};
        ["battle/actready"] = {-19, -11};
        ["battle/attack"] = {-19, -6};
        ["battle/attackready"] = {-19, -6};
        ["battle/battle_transition"] = {-19, -12};
        ["battle/defeat"] = {-7, 1};
        ["battle/defend"] = {-19, -9};
        ["battle/hurt"] = {-19, -11};
        ["battle/idle"] = {-8, 0};
        ["battle/idle_tense"] = {-19, -11};
        ["battle/intro"] = {-19, -11};
        ["battle/item"] = {-13, -6};
        ["battle/itemend"] = {-13, -6};
        ["battle/itemready"] = {-13, -6};
        ["battle/spell"] = {-13, -6};
        ["battle/spellready"] = {-13, -6};
        ["battle/victory"] = {-1, 0};
        ["dash"] = {-17, -12};
        ["run"] = {-5, -2};
        ["skid"] = { -5, -2};
    }

    -- Sound to play when this actor speaks (optional)
    self.voice = "assets/sounds/voice/party/evan"
    -- Path to this actor's portrait for dialogue (optional)
    self.portrait_path = "face/evan"
    -- Offset position for this actor's portrait (optional)
    self.portrait_offset = {-2, 0}

    -- Whether this actor as a follower will blush when close to the player
    self.can_blush = true
end

function actor:preSetAnimation(sprite, anim, callback)
    if (anim == "battle/idle" and Game.battle and Game.battle.tense) then
        sprite:setAnimation("battle/idle_tense")
        return true
    end
end

return actor