local Tragedy, super = Class(EnemyBattler)

function Tragedy:init()
    super.init(self)

    -- Enemy name
    self.name = "???"
    -- Sets the actor, which handles the enemy's sprites (see scripts/data/actors/dummy.lua)
    self:setActor("tragedy")

    -- Enemy health
    self.max_health = 8000
    self.health = 8000
    -- Enemy attack (determines bullet damage)
    self.attack = 12
    -- Enemy defense (usually 0)
    self.defense = 4
    -- Enemy reward
    self.money = 100

    -- Mercy given when sparing this enemy before its spareable (20% for basic enemies)
    self.spare_points = 0
    self.tired_percentage = 0
    self.dialogue_bubble = "agony"
    self.disable_mercy = true

    -- List of possible wave ids, randomly picked each turn
    self.waves = {
        "twistedspiral",
        "agonybrood",
        "agonyquarantine",
        "agonyimpact",
        "agonyecho",
        "agonyundertow",
    }

    -- Dialogue randomly displayed in the enemy's speech bubble
    self.dialogue = {
        "[shake:1][color:maroon]your fault. your fault.[color:reset]",
        "[shake:1][color:gray]what is your\nearliest memory?",
        "[shake:1][color:gray]is it my fault?\nis it your fault?",
        "[shake:1][color:gray]proceed.",
        "[shake:1][color:gray]you were used up.",
        "[shake:1][color:gray]have you walked\nthe right path?",
    }

    -- Check text (automatically has "ENEMY NAME - " at the start)
    self.check = "AT ?? DF ??\ninfo missing"

    -- Text randomly displayed at the bottom of the screen each turn
    self.text = {
        "* ",
    }
    -- Text displayed at the bottom of the screen when the enemy has low health
    self.low_health_text = "* ..."
end

return Tragedy
