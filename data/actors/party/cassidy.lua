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
    self.default_run = "run"

    self.animations = {
                -- Battle animations
        ["battle/idle"]         = {"battle/idle", 0.15, true},

        ["battle/attack"]       = {"battle/attack", 1/14, false},
        ["battle/act"]          = {"battle/act", 1/15, false},
        ["battle/spell"]        = {"battle/spell", 1/15, false, next="battle/idle"},
        ["battle/item"]         = {"battle/item", 1/12, false, next="battle/idle"},
        ["battle/spare"]        = {"battle/act", 1/15, false, next="battle/idle"},

        ["battle/attack_ready"] = {"battle/attackready", 0.2, true},
        ["battle/act_ready"]    = {"battle/actready", 0.2, true},
        ["battle/spell_ready"]  = {"battle/spellready", 0.2, true},
        ["battle/item_ready"]   = {"battle/itemready", 0.2, true},
        ["battle/defend"] = {"battle/defend", 1/15, false},

        ["battle/act_end"]      = {"battle/actend", 1/15, false, next="battle/idle"},

        ["battle/hurt"]         = {"battle/hurt", 1/15, false, temp=true, duration=0.5},
        ["battle/defeat"]       = {"battle/defeat", 1/15, true},

        ["battle/transition"]   = {"battle/battle_transition", 0.2, true},
        ["battle/intro"]        = {"battle/attack", 1/15, true},
        ["battle/victory"]      = {"battle/victory", 1/10, false},
    }

    self.offsets = {
        ["battle/act"] = {-15, -6};
        ["battle/actend"] = {-15, -6};
        ["battle/actready"] = {-15, -6};
        ["battle/attack"] = {-15, -6};
        ["battle/attackready"] = {-15, -6};
        ["battle/battle_transition"] = {-15, -6};
        ["battle/defeat"] = {-17, -4};
        ["battle/defend"] = {0, 0};
        ["battle/hurt"] = {-15, -6};
        ["battle/idle"] = {-6, 1};
        ["battle/item"] = {-15, -6};
        ["battle/itemend"] = {-15, -6};
        ["battle/itemready"] = {-15, -6};
        ["battle/spell"] = {-15, -6};
        ["battle/spellready"] = {-15, -5};
        ["battle/victory"] = {-15, -6};
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