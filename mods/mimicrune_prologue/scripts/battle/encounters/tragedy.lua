local Tragedy, super = Class(Encounter)

function Tragedy:init()
    super.init(self)

    -- Text displayed at the bottom of the screen at the start of the encounter
    self.text = "danger."

    -- Battle music ("battle" is rude buster)
    self.music = "battle"
    -- Enables the purple grid battle background
    self.background = true

    self:addEnemy("tragedy")
end

return Tragedy
