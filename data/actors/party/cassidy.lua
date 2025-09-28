local actor, super = Class(Actor, "cassidy")

function actor:init()
    super.init(self)
        -- Display name (optional)
    self.name = "Cassidy"

    -- Width and height for this actor, used to determine its center
    self.width = 25
    self.height = 43

    -- Hitbox for this actor in the overworld (optional, uses width and height by default)
    self.hitbox = {0, 31, 25, 14}
    
    -- A table that defines where the Soul should be placed on this actor if they are a player.
    -- First value is x, second value is y.
    self.soul_offset = {12.5, 24}

    -- Color for this actor used in outline areas (optional, defaults to red)
    self.color = {1.0, 210/255, 53/255}

    -- Path to this actor's sprites (defaults to "")
    self.path = "party/cassidy/dark"
    -- This actor's default sprite or animation, relative to the path (defaults to "")
    self.default = "walk"
    -- TODO: Change this back to "run" when the sprites are made
    self.default_run = "walk"

    self.animations = {
                -- Battle animations
        ["battle/idle"]         = {"battle/idle", 0.15, true},
        ["battle/idle_tense"]   = {"battle/idle_tense", 0.15, true},

        ["battle/attack"]       = {"battle/attack", 1/20, false},
        ["battle/act"]          = {"battle/act", 1/15, false},
        ["battle/spell"]        = {"battle/spell", 1/15, false},
        ["battle/item"]         = {"battle/item", 1/12, false, next="battle/idle"},
        ["battle/spare"]        = {"battle/act", 1/15, false, next="battle/idle"},

        ["battle/attack_ready"] = {"battle/attackready", 1/10, true},
        ["battle/act_ready"]    = {"battle/actready", 1/10, true},
        ["battle/spell_ready"]  = {"battle/spellready", 1/10, true},
        ["battle/item_ready"]   = {"battle/itemready", 1/10, true},
        ["battle/defend"]       = {"battle/defendready", 1/10, false, next="battle/defend_loop"},
        ["battle/defend_loop"]  = {"battle/defend", 1/10, true},

        ["battle/act_end"]      = {"battle/actend", 1/15, false, next="battle/idle"},
        ["battle/spell_end"]    = {"battle/spellend", 1/15, false, next="battle/idle"},

        ["battle/meditate"]     = {"battle/meditate", 1/20, false, next="battle/spell_end"},

        ["battle/hurt"]         = {"battle/hurt", 1/15, false, temp=true, duration=0.5},
        ["battle/defeat"]       = {"battle/defeat", 1/15, true},
        ["battle/overheat"]     = {"battle/overheat", 0.1, true},

        ["battle/transition"]   = {"battle/battle_transition", 1/15, false},
        ["battle/intro"]        = {"battle/intro", 1/20, true},
        ["battle/victory"]      = {"battle/victory", 1/10, false},

        ["dash"]   = {"dash", 1/15, true},
        ["skid"] = {"skid", 0.15, false},
    }

    self.offsets = {
        ["battle/act"] = {-15, -6};
        ["battle/actend"] = {-15, -6};
        ["battle/actready"] = {-15, -6};
        ["battle/attack"] = {-15, -6};
        ["battle/attackready"] = {-15, -6};
        ["battle/battle_transition"] = {-15, -6};
        ["battle/intro"] = {-15, -6};
        ["battle/defeat"] = {-17, -4};
        ["battle/defend"] = {-4, -1};
        ["battle/defendready"] = {-4, -1};
        ["battle/hurt"] = {-15, -6};
        ["battle/idle"] = {-6, 1};
        ["battle/idle_tense"] = {-6, 1};
        ["battle/item"] = {-15, -6};
        ["battle/itemend"] = {-15, -6};
        ["battle/itemready"] = {-15, -6};
        ["battle/meditate"] = {-15, -6};
        ["battle/spell"] = {-15, -6};
        ["battle/spellend"] = {-15, -6};
        ["battle/spellready"] = {-15, -5};
        ["battle/victory"] = {-4, 1};
        ["battle/overheat"] = {-7, 0};
        ["dash"] = {-13, -6};
        ["run"] = {-5, -2};
        ["skid"] = {-5, -2};
    }

    -- Sound to play when this actor speaks (optional)
    self.voice = "party/cassidy"
    -- Path to this actor's portrait for dialogue (optional)
    self.portrait_path = "face/cassidy"
    -- Offset position for this actor's portrait (optional)
    self.portrait_offset = nil

    -- Whether this actor as a follower will blush when close to the player
    self.can_blush = true
end

return actor
