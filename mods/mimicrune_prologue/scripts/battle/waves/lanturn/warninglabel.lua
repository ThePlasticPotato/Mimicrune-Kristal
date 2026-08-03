local Warning, super = Class(Wave)

function Warning:init()
    super.init(self)
    self.time = 20
end

function Warning:onStart()
    self.timer:script(function(wait)
        local enemy = self:getAttackers()[1]
        local original_x, original_y = enemy.x, enemy.y
        local layer = enemy.layer
        enemy.layer = BATTLE_LAYERS["above_arena"] or 300
        local attackers = self:getAttackers()
        local arena = Game.battle.arena
        local soul = Game.battle.soul
        enemy:alert()
        local bullet = self:spawnBullet("smallbullet", enemy.x, enemy.y - 60, 0, 0)
        bullet.visible = false
        bullet:setScale(7, 15)
        bullet.destroy_on_hit = false
        Assets.playSound("defeatrun")
        bullet.y = enemy.y
        self.timer:tween(1, bullet, {x=-260}, "in-elastic")
        self.timer:tween(1, enemy, {x=-260}, "in-elastic", function()
        self.timer:tween(1, bullet, {x=original_x})
        self.timer:tween(1, enemy, {x=original_x})
        end)
        wait(2)
        enemy:alert()
        Assets.playSound("defeatrun")
        bullet.y = enemy.y + 40
        enemy.y = enemy.y + 40
        self.timer:tween(1, bullet, {x=-260}, "in-elastic")
        self.timer:tween(1, enemy, {x=-260}, "in-elastic", function()
        self.timer:tween(1, bullet, {x=original_x})
        self.timer:tween(1, enemy, {x=original_x})
        end)
        wait(2)
        enemy:alert()
        Assets.playSound("defeatrun")
        bullet.y = enemy.y - 40
        enemy.y = enemy.y - 40
        self.timer:tween(1, bullet, {x=-260}, "in-elastic")
        self.timer:tween(1, enemy, {x=-260}, "in-elastic", function()
        self.timer:tween(1, bullet, {x=original_x})
        self.timer:tween(1, enemy, {x=original_x})
        end)
        wait(2)
        enemy:alert()
        bullet.y = enemy.y - 40
        enemy.y = enemy.y - 40
        Assets.playSound("defeatrun")
        self.timer:tween(1, bullet, {x=-260}, "in-elastic")
        self.timer:tween(1, enemy, {x=-260}, "in-elastic", function()
        self.timer:tween(1, bullet, {x=original_x})
        self.timer:tween(1, enemy, {x=original_x})
        end)
        wait(2)
        bullet.y = enemy.y + 40
        enemy.y = enemy.y + 40
    end)
end

return Warning