local Basic, super = Class(Wave)
function Basic:init()
    super.init(self)

    -- Initialize timer
    self.time = 11

    --set the arena's size
    self:setArenaSize(142, 300)
end

function Basic:onStart()
    --swaps the soul to be purple
    Game.battle:swapSoul(PurpleSoul())

    --creates the strings table(the only string we have at the moment is almost the size of the arena and at about its center)
    self.strings = {
        self:spawnObject(PurpleString(320, Game.battle.arena:getTop()+150, BATTLE_LAYERS["below_soul"], 130, 0)),
    }

    --assigns the only string we have at the moment to be the player's string
    Game.battle.soul.currentString = self.strings[1]

    --give the string a y speed of 4(down)
    self.strings[1].physics.speed_y = 4

    --create strings in a random pattern so the every loop later flows with these strings
    for i=1, 5 do
        local string = self:spawnObject(PurpleString(love.math.random(Game.battle.arena.left+32, Game.battle.arena.right-32), Game.battle.arena:getTop()+150-30*i, BATTLE_LAYERS["below_soul"], 60, 0))
        string.physics.speed_y = 4
        table.insert(self.strings, string)
    end

    --spawn a new string in a random x between the left and right of the arena every quarter second, repeats 20 times
    self.timer:every(0.25, function ()
        local string = self:spawnObject(PurpleString(love.math.random(Game.battle.arena.left+32, Game.battle.arena.right-32), Game.battle.arena:getTop(), BATTLE_LAYERS["below_soul"], 60, 0))
        string.physics.speed_y = 4
        table.insert(self.strings, string)
    end, 20)

    --after 5 seconds(the time it takes for the last timer to end) spawn more strings this time moving up with a speed of -4, repeats 20 times
    self.timer:after(5, function ()
        self.timer:every(0.25, function ()
            local string = self:spawnObject(PurpleString(love.math.random(Game.battle.arena.left+32, Game.battle.arena.right-32), Game.battle.arena:getBottom(), BATTLE_LAYERS["below_soul"], 60, math.pi))
            string.physics.speed_y = -4
            table.insert(self.strings, string)
        end, 20)
    end)

    -- Spawn spikes on top of arena
    self:spawnBulletTo(Game.battle.arena, "arenahazard", Game.battle.arena.width/2, 0, math.rad(0))

    -- Spawn spikes on bottom of arena (rotated 180 degrees)
    self:spawnBulletTo(Game.battle.arena, "arenahazard", Game.battle.arena.width/2, Game.battle.arena.height, math.rad(180))
end

function Basic:update()
    super.update(self)

    --checks if the strings go outside of the arena and despawns them
    for k, string in ipairs(self.strings) do
        if string.y > Game.battle.arena:getBottom() then
            string:remove()
            table.remove(self.strings, k)
        elseif string.y < Game.battle.arena:getTop() then
            string:remove()
            table.remove(self.strings, k)
        end
    end
end

return Basic
