---@class WindLeaf : Object
local WindLeaf, super = Class(Object)

function WindLeaf:init(x, y, speed, handler)
    super.init(self, x, y)
    self.handler = handler
    self.speed = speed
    self.phase = MathUtils.random(0, math.pi * 2)
    self.leaf = Sprite("world/wind/leaf")
    self.leaf:play(MathUtils.random(0.2, 0.5), true)
    self.leaf:setOrigin(0.5, 0.5)
    self:addChild(self.leaf)
    self:setLayer(((handler.addto == Game.battle) and BATTLE_LAYERS["below_ui"] or WORLD_LAYERS["below_ui"]) - 1)
end

function WindLeaf:update()
    super.update(self)
    if self.handler.paused then return end
    local direction = self.handler.direction >= 0 and 1 or -1
    self.x = self.x + self.speed * direction * DTMULT
    self.y = self.y + math.sin(Kristal.getTime() * 6 + self.phase) * 1.8 * DTMULT
    self.rotation = self.rotation + direction * DT * 2.5

    local screen_x, screen_y = self:localToScreenPos(0, 0)
    if screen_x < -80 or screen_x > SCREEN_WIDTH + 80 or screen_y < -80 or screen_y > SCREEN_HEIGHT + 80 then
        self:remove()
    end
end

return WindLeaf
