local actor, super = Class(Actor, "cassidy_lw")

function actor:init()
    super.init(self)
        -- Display name (optional)
    self.name = "Cassidy"

    -- Width and height for this actor, used to determine its center
    self.width = 25
    self.height = 43

    -- Hitbox for this actor in the overworld (optional, uses width and height by default)
    self.hitbox = {3, 31, 19, 14}
    
    -- A table that defines where the Soul should be placed on this actor if they are a player.
    -- First value is x, second value is y.
    self.soul_offset = {12.5, 24}

    -- Color for this actor used in outline areas (optional, defaults to red)
    self.color = {1.0, 210/255, 53/255}

    -- Path to this actor's sprites (defaults to "")
    self.path = "party/cassidy/light"
    -- This actor's default sprite or animation, relative to the path (defaults to "")
    self.default = "walk"
    self.default_run = "run"

    self.animations = {
        ["sit"] = {"sit", 0.15, true}
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