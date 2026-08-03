local Warning, super = Class(Wave)

function Warning:init()
    super.init(self)
    self.time = 30
end
function Warning:onEnd()
    local enemy = self:getAttackers()[1]
    enemy.layer = self.layer
end
function Warning:onStart()
    local linefunction = function(x,y)
        local line = Object()
        line.layer = 0
        local colors = { {1,0,0,0.5}, {1,1,0,0.5} }
        line.draw = function()
            local color_index = math.floor((love.timer.getTime() * 10) % 2) + 1
            love.graphics.setColor(unpack(colors[color_index]))
            love.graphics.setLineWidth(90)

            love.graphics.line(
                x + 1000,
                y,
                x + math.cos(math.rad(180)) * 1000,
                y + math.sin(math.rad(180)) * 1000
            )
        end
        self.warning_duration = 1
        self:addChild(line)
        self.timer:after(self.warning_duration, function() line:remove() end)
        local warning_times = 7
    end
    self.timer:script(function(wait)
        local enemy = self:getAttackers()[1]
        local original_x, original_y = enemy.x, enemy.y
        self.layer = enemy.layer
        enemy.layer = 18291
        local attackers = self:getAttackers()
        local arena = Game.battle.arena
        self.timer:tween(0.2, arena, {width=40,x=arena.x-20,height=100})
        local soul = Game.battle.soul
        enemy:alert()
        local bullet = self:spawnBullet("smallbullet", enemy.x, enemy.y - 60, 0, 0)
        bullet.remove_offscreen = false
        bullet.visible = false
        bullet:setScale(12, 15)
        bullet.destroy_on_hit = false
            Assets.playSound("defeatrun")
            bullet.y = enemy.y - 60
            linefunction(bullet.x,bullet.y)
                self.timer:tween(3.5, bullet, {x=-260}, "in-elastic", function()
                self.timer:tween(1, bullet, {x=original_x})
            end)
                self.timer:tween(3.5, enemy, {x=-260}, "in-elastic", function()
                self.timer:tween(1, enemy, {x=original_x})
            end)
            wait(5)
            enemy:alert()
            Assets.playSound("defeatrun")
            bullet.y = soul.y - 10
            linefunction(bullet.x,bullet.y)    
            self.timer:tween(1, enemy, {y=soul.y + 40})
                self.timer:tween(3, bullet, {x=-260}, "in-elastic", function()
                self.timer:tween(1, bullet, {x=original_x})
            end)
                self.timer:tween(3, enemy, {x=-260}, "in-elastic", function()
                self.timer:tween(1, enemy, {x=original_x})
            end)
            wait(4)
            enemy:alert()
            Assets.playSound("defeatrun")
            bullet.y = soul.y - 10
            linefunction(bullet.x,bullet.y)
                self.timer:tween(1, enemy, {y=soul.y + 40})
                self.timer:tween(2, bullet, {x=-260}, "in-elastic", function()
                self.timer:tween(1, bullet, {x=original_x})
            end)
                self.timer:tween(2, enemy, {x=-260}, "in-elastic", function()
                self.timer:tween(1, enemy, {x=original_x})
            end)
            wait(3)
            enemy:alert()
            Assets.playSound("defeatrun")
            bullet.y = soul.y - 10
            linefunction(bullet.x,bullet.y)
            self.timer:tween(1, enemy, {y=soul.y + 40})
                self.timer:tween(1, bullet, {x=-260}, "in-elastic", function()
                self.timer:tween(1, bullet, {x=original_x})
            end)
                self.timer:tween(1, enemy, {x=-260}, "in-elastic", function()
                self.timer:tween(1, enemy, {x=original_x})
            end)
            wait(2)
            enemy:alert()
            Assets.playSound("defeatrun")
            bullet.y = soul.y - 10
            linefunction(bullet.x,bullet.y)
            self.timer:tween(1, enemy, {y=soul.y + 40})
                self.timer:tween(1, bullet, {x=-260}, "in-elastic", function()
                self.timer:tween(1, bullet, {x=original_x})
            end)
                self.timer:tween(1, enemy, {x=-260}, "in-elastic", function()
                self.timer:tween(1, enemy, {x=original_x})
            end)
            wait(2)
            enemy:alert()
            Assets.playSound("defeatrun")
            bullet.y = soul.y - 10
            linefunction(bullet.x,bullet.y)    
            self.timer:tween(1, enemy, {y=soul.y + 40})
                self.timer:tween(1, bullet, {x=-260}, "in-elastic", function()
                self.timer:tween(1, bullet, {x=original_x})
            end)
                self.timer:tween(1, enemy, {x=-260}, "in-elastic", function()
                self.timer:tween(1, enemy, {x=original_x})
            end)
            wait(2)
                        enemy:alert()
            Assets.playSound("defeatrun")
            bullet.y = soul.y - 10
            linefunction(bullet.x,bullet.y)
                self.timer:tween(1, enemy, {y=soul.y + 40})
                self.timer:tween(1, bullet, {x=-260}, "in-elastic", function()
                self.timer:tween(0.5, bullet, {x=original_x})
            end)
                self.timer:tween(1, enemy, {x=-260}, "in-elastic", function()
                self.timer:tween(0.5, enemy, {x=original_x})
            end)
            wait(1.5)
                        enemy:alert()
            Assets.playSound("defeatrun")
            bullet.y = soul.y - 10
            linefunction(bullet.x,bullet.y)
                self.timer:tween(1, enemy, {y=soul.y + 40})
                self.timer:tween(1, bullet, {x=-260}, "in-elastic", function()
                self.timer:tween(0.5, bullet, {x=original_x})
            end)
                self.timer:tween(1, enemy, {x=-260}, "in-elastic", function()
                self.timer:tween(0.5, enemy, {x=original_x})
            end)
            wait(1.5)
                        enemy:alert()
            Assets.playSound("defeatrun")
            bullet.y = soul.y - 10
            linefunction(bullet.x,bullet.y)
                self.timer:tween(1, enemy, {y=soul.y + 40})
                self.timer:tween(1, bullet, {x=-260}, "in-elastic", function()
                self.timer:tween(0.5, bullet, {x=original_x})
            end)
                self.timer:tween(1, enemy, {x=-260}, "in-elastic", function()
                self.timer:tween(0.5, enemy, {x=original_x})
            end)
            wait(1.5)
                        enemy:alert()
            Assets.playSound("defeatrun")
            bullet.y = soul.y - 10
            linefunction(bullet.x,bullet.y)
                self.timer:tween(1, enemy, {y=soul.y + 40})
                self.timer:tween(1, bullet, {x=-260}, "in-elastic", function()
                self.timer:tween(0.5, bullet, {x=original_x})
            end)
                self.timer:tween(1, enemy, {x=-260}, "in-elastic", function()
                self.timer:tween(0.5, enemy, {x=original_x})
            end)
            wait(1.5)
            bullet.y = original_y - 20
            self.timer:tween(0.5, enemy, {y=original_y})
    end)
end

return Warning