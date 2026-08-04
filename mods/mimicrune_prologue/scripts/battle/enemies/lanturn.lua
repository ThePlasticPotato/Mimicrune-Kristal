local Lanturn, super = Class(EnemyBattler)

function Lanturn:init()
    super.init(self)
    self.name = "???"
    self:setActor("spamton")
    self.max_health = 8000
    self.health = 8000
    self.attack = 12
    self.defense = 4
    self.money = 100
    self.spare_points = 0
    self.tired_percentage = 0
    self.dialogue_bubble = "agony"
    self.disable_mercy = true
    self.waves = {
        "lanturn/warninglabel",
        "lanturn/crush"
    }
    self.dialogue = {
        "[shake:1][color:maroon]your fault. your fault.[color:reset]",
        "[shake:1][color:gray]what is your\nearliest memory?",
        "[shake:1][color:gray]is it my fault?\nis it your fault?",
        "[shake:1][color:gray]proceed.",
        "[shake:1][color:gray]you were used up.",
        "[shake:1][color:gray]have you walked\nthe right path?",
    }
    self.check = "AT ?? DF ??\ninfo missing, looks like a shark."
    self.text = {
        "* ",
    }
    self.low_health_text = "* ..."
    self.sine = 0
    self.swing_width = 7
    self.swing_height = 7
    self.swing_speed = 0.05

end
function Lanturn:update()
    self.sine = self.sine + self.swing_speed * DTMULT
    self.sprite.x = math.sin(self.sine) * self.swing_width
    self.sprite.y = math.cos(self.sine * 1.5) * self.swing_height
    local afterimage = AfterImage(self, 0.2)
    afterimage.graphics.grow = 0.05
    afterimage:setLayer(self.layer - 90)
    Game.battle:addChild(afterimage)
    super.update(self)
end
return Lanturn
