local Basic, super = Class(Wave)
function Basic:init()
    super.init(self)

    -- Initialize timer
    self.time = -1

    --change the arena's size
    self:setArenaSize(300, 300)
end

function Basic:onStart()
    --swaps the soul to be purple(if you wanna change the whole encounter to use the purple soul then you can move the next few lines to init)
    Game.battle:swapSoul(PurpleSoul())

    --create the strings
    self.strings = {
        self:spawnObject(PurpleString(320, 72, BATTLE_LAYERS["below_soul"], 200, math.pi)),
        self:spawnObject(PurpleString(320, 172, BATTLE_LAYERS["below_soul"], 282, -math.pi/4)),
        self:spawnObject(PurpleString(320, 172, BATTLE_LAYERS["below_soul"], 282, math.pi/4)),
        self:spawnObject(PurpleString(320, 272, BATTLE_LAYERS["below_soul"], 200, 0)),
        self:spawnObject(PurpleString(420, 172, BATTLE_LAYERS["below_soul"], 200, math.pi*1.5)),
        self:spawnObject(PurpleString(220, 172, BATTLE_LAYERS["below_soul"], 200, math.pi/2))
    }

    --assign the fourth string(the bottom one) as the soul's current string
    Game.battle.soul.currentString = self.strings[4]
end

return Basic
