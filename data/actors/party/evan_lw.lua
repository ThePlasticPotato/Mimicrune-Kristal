local actor, super = Class(Actor, "evan_lw")

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
    self.path = "party/evan/light"
    -- This actor's default sprite or animation, relative to the path (defaults to "")
    self.default = "walk"
    self.default_run = "run"

    -- Sound to play when this actor speaks (optional)
    self.voice = "party/evan"
    -- Path to this actor's portrait for dialogue (optional)
    self.portrait_path = "face/evan"
    -- Offset position for this actor's portrait (optional)
    self.portrait_offset = {-2, 0}

    self.animations = {
        ["splat"]         = {"splat", 0.2, true},
        ["lift"]    = {"lift", 0.2, true},
        ["sat"]     = {"sat", 0.2, true},
        ["sit"] = {"sit", 0.15, true}
    }

    self.offsets = {
        ["run"] = {-5, -2},
        ["splat"] = {-10, 8},
        ["lift"] = {-10, 8},
        ["sat"] = {-10, 8},
    }

    -- Whether this actor as a follower will blush when close to the player
    self.can_blush = true
end

return actor