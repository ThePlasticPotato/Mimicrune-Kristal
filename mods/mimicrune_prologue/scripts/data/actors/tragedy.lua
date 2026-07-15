local actor, super = Class(Actor, "tragedy")

function actor:init()
    super.init(self)

    -- Display name (optional)
    self.name = "???"

    -- Width and height for this actor, used to determine its center
    self.width = 64
    self.height = 72

    -- Hitbox for this actor in the overworld (optional, uses width and height by default)
    self.hitbox = { 0, 25, 19, 14 }

    -- Color for this actor used in outline areas (optional, defaults to red)
    self.color = { 1, 0, 0 }

    -- Whether this actor flips horizontally (optional, values are "right" or "left", indicating the flip direction)
    self.flip = nil

    -- Path to this actor's sprites (defaults to "")
    self.path = "enemies/tragedy"
    -- This actor's default sprite or animation, relative to the path (defaults to "")
    self.default = "idle"

    -- Sound to play when this actor speaks (optional)
    self.voice = nil
    -- Path to this actor's portrait for dialogue (optional)
    self.portrait_path = nil
    -- Offset position for this actor's portrait (optional)
    self.portrait_offset = nil

    -- Whether this actor as a follower will blush when close to the player
    self.can_blush = false

    -- Table of talk sprites and their talk speeds (default 0.25)
    self.talk_sprites = {}

    -- Table of sprite animations
    self.animations = {
        -- Looping animation with 0.25 seconds between each frame
        -- (even though there's only 1 idle frame)
        ["idle"] = { "idle", 0.1, true },
        ["battle/hurt"] = { "flinch", 0.25, false },
        ["gonerbattle/hurt"] = { "flinch", 0.25, false }
    }

    -- Table of sprite offsets (indexed by sprite name)
    self.offsets = {
        -- Every battle frame uses the actor's 64x72 canvas, so no correction
        -- is needed between the idle and flinch animations.
        ["idle"] = { 0, 0 },
        ["flinch"] = { 0, 0 },
    }
end

return actor
