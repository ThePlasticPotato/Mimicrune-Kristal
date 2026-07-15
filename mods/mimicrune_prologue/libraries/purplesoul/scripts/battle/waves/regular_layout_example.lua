local Basic, super = Class(Wave)
function Basic:init()
    super.init(self)

    -- Initialize timer
    self.time = -1

    --change the arena's size
    self:setArenaSize(240, 142)
end

function Basic:onStart()
    --swaps the soul to be purple(if you wanna change the whole encounter to use the purple soul then you can move the next few lines to init)
    Game.battle:swapSoul(PurpleSoul())

    --create the strings
    self.strings = {
        self:spawnObject(PurpleString(320, Game.battle.arena:getTop()+30, BATTLE_LAYERS["below_soul"], Game.battle.arena.width-16, 0)),
        self:spawnObject(PurpleString(320, Game.battle.arena.y, BATTLE_LAYERS["below_soul"], Game.battle.arena.width-16, 0)),
        self:spawnObject(PurpleString(320, Game.battle.arena:getBottom()-30, BATTLE_LAYERS["below_soul"], Game.battle.arena.width-16, 0)),
    }

    --assign the fourth string(the bottom one) as the soul's current string
    Game.battle.soul.currentString = self.strings[2]
end

return Basic
