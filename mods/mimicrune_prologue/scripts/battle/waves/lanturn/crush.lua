local Crush, super = Class(Wave)

function Crush:init()
    super.init(self)
    self.time = 20
    self.siner = 0
end

function Crush:onStart()
    local soul = Game.battle.soul
    local arena = Game.battle.arena
    local y = Game.battle.arena.y
    self.arena_start_x = arena.x
    self.arena_start_y = arena.y
    self.timer:everyInstant(3, function()
         self.timer:script(function(wait)
            self.timer:tween(0.2, arena, {width=140,height=140,y=y})
            local selectedy = soul.y
            wait(1)
            Assets.playSound("alert")
            self.timer:tween(0.2, arena, {height=90,y=selectedy})
            wait(0.2)
            local top = self:spawnBulletTo(Game.battle.arena, "arenahazard", arena.width / 2, 0, math.rad(0))
            local bottom = self:spawnBulletTo(Game.battle.arena, "arenahazard", arena.width / 2, arena.height, math.rad(180))
            wait(1)
            top:remove()
            bottom:remove()
            self.timer:tween(0.2, arena, {width=140,height=140,y=y})
         end)
    end)
end

function Crush:update()
    self.siner = self.siner + DT
    local offset = math.sin(self.siner * 1.5) * 60
    Game.battle.arena:setPosition(self.arena_start_x, self.arena_start_y + offset)
    super.update(self)
end

return Crush