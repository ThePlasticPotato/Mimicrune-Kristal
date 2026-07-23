local actor, super = Class(Actor, "vessel")

local function jumpAnimation(sprite, wait)
    sprite:setSprite("jump", true)
    sprite:setFrame(1)
    wait(1/15)
    sprite:setFrame(2)
    wait(1/15)
    sprite:setFrame(3)
    while true do wait(1) end
end

function actor:init()
    super.init(self)

    -- Display name (optional)
    self.name = "You"

    -- Width and height for this actor, used to determine its center
    self.width = 19
    self.height = 37

    -- Hitbox for this actor in the overworld (optional, uses width and height by default)
    self.hitbox = {0, 25, 19, 14}
    self.collision_depth = 20

    -- A table that defines where the Soul should be placed on this actor if they are a player.
    -- First value is x, second value is y.
    self.soul_offset = {10, 24}

    self.jump_strength = 8
    self.jump_windup = 1/15

    self.run_speed = 6
    self.run_momentum_max = 0.5
    self.run_acceleration = 4
    self.run_deceleration = 4
    self.run_transition_frames = 4

    -- Color for this actor used in outline areas (optional, defaults to red)
    self.color = {0, 1, 1}

    -- Path to this actor's sprites (defaults to "")
    self.path = "party/vessel/dark"
    -- This actor's default sprite or animation, relative to the path (defaults to "")
    self.default = "walk"

    -- Sound to play when this actor speaks (optional)
    self.voice = nil
    -- Path to this actor's portrait for dialogue (optional)
    self.portrait_path = nil
    -- Offset position for this actor's portrait (optional)
    self.portrait_offset = nil

    -- Whether this actor as a follower will blush when close to the player
    self.can_blush = false
    self.default_run = "run"

    -- Table of sprite animations
    self.animations = {
        -- Movement animations
        ["slide"]               = {"slide", 4/30, true},
        ["jump"]                = jumpAnimation,
        ["fall"]                = {"fall", 1/10, true},
        ["landed"]              = {"landed", 1/15, false},

        -- Battle animations
        ["battle/idle"]         = {"battle/idle", 1/6, true},
        ["gonerbattle/idle"]    = {"gonerbattle/idle", 1/6, true},

        ["battle/attack"]       = {"battle/attack", 1/15, false},
        ["battle/act"]          = {"battle/act", 1/15, false},
        ["battle/spell"]        = {"battle/act", 1/15, false},
        ["battle/item"]         = {"battle/item", 1/12, false, next="battle/idle"},
        ["battle/spare"]        = {"battle/act", 1/15, false, next="battle/idle"},

        ["battle/attack_ready"] = {"battle/attackready", 0.2, true},
        ["battle/act_ready"]    = {"battle/actready", 0.2, true},
        ["battle/spell_ready"]  = {"battle/actready", 0.2, true},
        ["battle/item_ready"]   = {"battle/itemready", 0.2, true},
        ["battle/defend_ready"] = {"battle/defend", 1/15, false},

        ["battle/act_end"]      = {"battle/actend", 1/15, false, next="battle/idle"},

        ["battle/hurt"]         = {"battle/hurt", 1/15, false, temp=true, duration=0.5},
        ["battle/defeat"]       = {"battle/defeat", 1/15, false},
        ["battle/swooned"]      = {"battle/defeat", 1/15, false},

        ["battle/transition"]   = {"sword_jump_down", 0.2, true},
        ["battle/intro"]        = {"battle/attack", 1/15, false},
        ["battle/victory"]      = {"battle/victory", 1/10, false},
        ["battle/transition_out"] = {"battle/transition_out", 1/15, false},

        -- Cutscene animations
        ["jump_fall"]           = {"fall", 1/5, true},
        ["jump_ball"]           = {"ball", 1/15, true},
        ["jump_ball_slow"]      = {"ball", 4/30, true},

        ["dash"]   = {"dash", 1/15, true},
        ["run"] = {-5, -2};
    }

    if Game.chapter == 1 then
        self.animations["battle/transition"] = {"walk/right", 0, true}
    end

    -- Tables of sprites to change into in mirrors
    self.mirror_sprites = {
        ["walk/down"] = "walk/up",
        ["walk/up"] = "walk/down",
        ["walk/left"] = "walk/left",
        ["walk/right"] = "walk/right",
    }

    -- Table of sprite offsets (indexed by sprite name)
    self.offsets = {
        -- Movement offsets
        ["walk/left"] = {0, 0},
        ["walk/right"] = {0, 0},
        ["walk/up"] = {0, 0},
        ["walk/down"] = {0, 0},

        ["walk_blush/down"] = {0, 0},

        ["slide"] = {0, 0},

        -- Battle offsets
        ["battle/idle"] = {-5, -1},

        ["battle/attack"] = {-8, -6},
        ["battle/attackready"] = {-8, -6},
        ["battle/act"] = {-6, -6},
        ["battle/actend"] = {-6, -6},
        ["battle/actready"] = {-6, -6},
        ["battle/item"] = {-6, -6},
        ["battle/itemready"] = {-6, -6},
        ["battle/defend"] = {-5, -3},

        ["battle/defeat"] = {-8, -5},
        ["battle/hurt"] = {-5, -6},

        ["battle/intro"] = {-8, -9},
        ["battle/victory"] = {-3, 0},

        -- Climb offsets
        ["climb/climbing"] = {-5, -15},
        ["climb/fall"] = {-3, -14},
        ["climb/charge"] = {-4, -12},
        ["climb/charge_right"] = {-4, -12},
        ["climb/charge_left"] = {-4, -12},
        ["climb/slip_right"] = {-3, -13},
        ["climb/slip_left"] = {-2, -13},
        ["climb/jump_up"] = {-4, -13},
        ["climb/land_right"] = {-4, -13},
        ["climb/land_left"] = {-4, -13},

        -- Cutscene offsets
        ["pose"] = {-4, -2},

        ["fall"] = {0, 0},
        ["ball"] = {1, 8},
        ["landed"] = {-5, -2},

        ["fell"] = {-14, 1},

        ["sword_jump_down"] = {-19, -5},
        ["sword_jump_settle"] = {-27, 4},
        ["sword_jump_up"] = {-17, 2},

        ["hug_left"] = {-4, -1},
        ["hug_right"] = {-2, -1},

        ["peace"] = {0, 0},
        ["rude_gesture"] = {0, 0},

        ["reach"] = {-3, -1},

        ["sit"] = {-3, 0},

        ["t_pose"] = {-4, 0},

        ["dash"] = {-17, -12};
        ["run"] = {-2, 0};
    }
end

-- BEGIN KRISTAL ACTOR EDITOR
-- KRISTAL_ACTOR_EDITOR_DATA_BEGIN
local __kristal_actor_editor_data = {
    animation_overrides = {},
    animation_removals = {},
    fields = {
        soul_offset = {
            10,
            22
        }
    },
    nil_fields = {},
    offset_overrides = {
        ["fall/down"] = {
            0,
            0
        },
        ["jump/down"] = {
            0,
            0
        }
    },
    offset_removals = {}
}
-- KRISTAL_ACTOR_EDITOR_DATA_END
local __kristal_actor_editor_init = actor.init
function actor:init(...)
    __kristal_actor_editor_init(self, ...)
    self.soul_offset = {
        10,
        22
    }
    self.offsets["fall/down"] = {
        0,
        0
    }
    self.offsets["jump/down"] = {
        0,
        0
    }
end
-- END KRISTAL ACTOR EDITOR

return actor
