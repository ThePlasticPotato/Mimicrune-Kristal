local AgonyBlob, super = Class(Bullet)

function AgonyBlob:init(x, y, dir, speed)
    -- Last argument = sprite path
    super.init(self, x, y)

    -- Move the bullet in dir radians (0 = right, pi = left, clockwise rotation)
    self.physics.direction = dir
    -- Speed the bullet moves (pixels per frame at 30FPS)
    self.physics.speed = speed
    self.rot = 0
    self.width = 4
    self.height = 4
    self.collider = Hitbox(self, -self.width/4, -self.height/4, self.width/2, self.height/2)

    --self.damage = self.damage * 2
end

function AgonyBlob:drawRotatedRectangle(mode, x, y, width, height, angle)
	-- We cannot rotate the rectangle directly, but we
	-- can move and rotate the coordinate system.
	love.graphics.push()
	love.graphics.translate(x, y)
	love.graphics.rotate(angle)
    love.graphics.setLineWidth(2)
	love.graphics.rectangle(mode, -width/2, -height/2, width, height) -- origin in the middle
	love.graphics.pop()
end

function AgonyBlob:update()
    super.update(self)
    self.rot = self.rot + DTMULT
end

function AgonyBlob:draw()
    super.draw(self)
    Draw.setColor(1, 0, 0, 1)
    self:drawRotatedRectangle("line", 0, 0, 4, 4, self.rot)
    Draw.setColor(0, 0, 0, 1)
    self:drawRotatedRectangle("fill", 0, 0, 2, 2, self.rot)
    Draw.setColor(1,1,1,1)
end

return AgonyBlob