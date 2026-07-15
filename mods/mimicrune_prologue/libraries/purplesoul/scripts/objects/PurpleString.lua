---@class PurpleString : Object
local PurpleString, super = Class(Object)

function PurpleString:init(x, y, lay, l, r)
    super.init(self, x, y)

    --set some variables to the arguments
    self:setLayer(lay)
    self.x = x
    self.y = y
    self.len = l or 0
    self.rot = r or 0

    --get the left and right bounds(extreme points) of the string
    self.leftBound = {
        ["x"] = self:lengthDirX(self.x, -self.len/2, self.rot)-self.x, 
        ["y"] = self:lengthDirY(self.y, -self.len/2, self.rot)-self.y
    }
    self.rightBound = {
        ["x"] = self:lengthDirX(self.x, self.len/2, self.rot)-self.x, 
        ["y"] = self:lengthDirY(self.y, self.len/2, self.rot)-self.y
    }

    --create a LineCollider so the soul can collide with the string
    self.collider = LineCollider(self, self.leftBound.x, self.leftBound.y, self.rightBound.x, self.rightBound.y)
end

--get the the X location of a point on the end of a line that's l away from x in the direction of r
function PurpleString:lengthDirX(x, l, r)
    return x+l*math.cos(r)
end

--get the the Y location of a point on the end of a line that's l away from y in the direction of r
function PurpleString:lengthDirY(y, l, r)
    return y+l*math.sin(r)
end

--get the position the soul should be at from it's progress on the string(where it is between the left and right bounds in a range of 0-1)
function PurpleString:getPositionBetweenBounds(progress)
    local x = self.leftBound.x+((self.rightBound.x-self.leftBound.x)/2)*progress*2
    local y = self.leftBound.y+((self.rightBound.y-self.leftBound.y)/2)*progress*2
    return x, y
end

--get the progress a point should be at when it's on the string, only use if the point is on the string
function PurpleString:getProgressFromLocation(x, y)
    local dist = Utils.dist(self.x+self.leftBound.x, self.y+self.leftBound.y, x, y)
    local progress = dist/self.len
    return progress
end

function PurpleString:update()
    super.update(self)

    --get the left and right bounds again because the string moves and rotates around
    self.leftBound = {
        ["x"] = self:lengthDirX(self.x, -self.len/2, self.rot)-self.x, 
        ["y"] = self:lengthDirY(self.y, -self.len/2, self.rot)-self.y
    }
    self.rightBound = {
        ["x"] = self:lengthDirX(self.x, self.len/2, self.rot)-self.x, 
        ["y"] = self:lengthDirY(self.y, self.len/2, self.rot)-self.y
    }

    --get the collider again for the same reason as the bounds
    self.collider = LineCollider(self, self.leftBound.x, self.leftBound.y, self.rightBound.x, self.rightBound.y)
end

function PurpleString:draw()
    super.draw(self)

    --set the line's width and color
    love.graphics.setLineWidth(Kristal.getLibConfig("purplesoulskerchv2", "stringWidth"))
    Draw.setColor(Kristal.getLibConfig("purplesoulskerchv2", "stringColor").r, Kristal.getLibConfig("purplesoulskerchv2", "stringColor").g, Kristal.getLibConfig("purplesoulskerchv2", "stringColor").b, Kristal.getLibConfig("purplesoulskerchv2", "stringColor").a)

    --draw a purple line to visually show the string
    love.graphics.line(self.leftBound.x, self.leftBound.y, self.rightBound.x, self.rightBound.y)

    --draw the string's collider if debug rendering is on
    if DEBUG_RENDER then
        self.collider:draw(0, 1, 1)
    end
end

return PurpleString