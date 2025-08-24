-- todo: darkworld elizabeth, its not necessary for ch1 anyways but yk
local actor, super = Class(Actor, "elizabeth")

function actor:init()
    super.init(self)
        -- Display name (optional)
    self.name = "Elizabeth"

    -- Width and height for this actor, used to determine its center
    self.width = 19
    self.height = 38

    -- Hitbox for this actor in the overworld (optional, uses width and height by default)
    self.hitbox = {0, 25, 19, 14}

    -- A table that defines where the Soul should be placed on this actor if they are a player.
    -- First value is x, second value is y.
    self.soul_offset = {10, 24}

    -- Color for this actor used in outline areas (optional, defaults to red)
    self.color = {118/255, 66/255, 238/255}

    -- Path to this actor's sprites (defaults to "")
    self.path = "party/elizabeth/light"
    -- This actor's default sprite or animation, relative to the path (defaults to "")
    self.default = "walk"
    self.default_run = "run"

    -- Sound to play when this actor speaks (optional)
    self.voice = "elizabeth"
    -- Path to this actor's portrait for dialogue (optional)
    self.portrait_path = "face/elizabeth"
    -- Offset position for this actor's portrait (optional)
    self.portrait_offset = {-2, 0}

    self.animations = {
    }

    self.offsets = {
    }

    -- Whether this actor as a follower will blush when close to the player
    self.can_blush = false
end

return actor