---@class Collider : Class
---@overload fun(...) : Collider
local Collider = Class()

---@class Collider.Mode
---@field invert boolean?
---@field inside boolean?

---@param parent Object
---@param x number?
---@param y number?
---@param mode Collider.Mode
function Collider:init(parent, x, y, mode)
    self.parent = parent

    self.x = x or 0
    self.y = y or 0
    self.z = 0
    self.depth = 0

    mode = mode or {}
    self.invert = mode.invert or false
    self.inside = mode.inside or false

    self.collidable = true
end

--- Gets the collider's Z position in world coordinates.
---@return number z
function Collider:getWorldZ()
    if self.parent and self.parent.getFullZ then
        return self.parent:getFullZ() + self.z
    end
    return self.z
end

--- Gets the collider's bottom and top Z bounds in world coordinates.
---@return number bottom
---@return number top
function Collider:getZBounds()
    local bottom = self:getWorldZ()
    return bottom, bottom + self.depth
end

--- Returns the walkable height of a slope at a world-space XY position.
--- Non-slope colliders return their ordinary top.
---@param world_x number
---@param world_y number
---@return number height
function Collider:getSupportHeightAt(world_x, world_y)
    local bottom, top = self:getZBounds()
    if not self.slope then return top end
    local bounds = self.map_bounds
    if not bounds then return top end
    local axis = self.slope_axis or "x"
    local coordinate = axis == "y" and world_y or world_x
    local minimum = axis == "y" and bounds.min_y or bounds.min_x
    local maximum = axis == "y" and bounds.max_y or bounds.max_x
    local extent = maximum - minimum
    local progress = extent ~= 0 and MathUtils.clamp((coordinate - minimum) / extent, 0, 1) or 1
    if self.slope_sign == -1 then progress = 1 - progress end
    return bottom + (top - bottom) * progress
end

--- Maximum height change produced by one pixel of movement along this ramp.
---@return number height
function Collider:getSlopeStepHeight()
    if not self.slope then return 0 end
    if self.slope_step_height then return self.slope_step_height end
    local bounds = self.map_bounds
    local extent = bounds and (self.slope_axis == "y"
        and bounds.max_y - bounds.min_y or bounds.max_x - bounds.min_x) or 0
    return extent > 0 and self.depth / extent + 0.25 or self.depth
end

function Collider:setZ(z)
    self.z = z or 0
end

function Collider:setDepth(depth)
    self.depth = math.max(depth or 0, 0)
end

--- Checks whether this collider's Z range overlaps another collider's Z range.
--- Positive-depth ranges use half-open bounds so touching platform tops do not
--- count as side collisions.
---@param other Object|Collider
---@return boolean
function Collider:collidesZ(other)
    other = self:getOtherCollider(other)
    if not other then return false end

    local a_bottom, a_top = self:getZBounds()
    local b_bottom, b_top = other:getZBounds()

    if self.depth == 0 and other.depth == 0 then
        return a_bottom == b_bottom
    elseif self.depth == 0 then
        return a_bottom >= b_bottom and a_bottom < b_top
    elseif other.depth == 0 then
        return b_bottom >= a_bottom and b_bottom < a_top
    end

    return math.max(a_bottom, b_bottom) < math.min(a_top, b_top)
end

function Collider:collidableCheck(other)
    return self.collidable and other and other.collidable and (not self.parent or self.parent.collidable) and (not other.parent or other.parent.collidable)
end
function Collider:insideCheck(other)
    return not (self.inside and other.inside)
end

function Collider:applyInvert(other, val)
    if self.invert ~= other.invert then
        return not val
    else
        return val
    end
end

function Collider:getOtherCollider(other)
    if isClass(other) then
        if other:includes(Collider) then
            return other
        elseif other:includes(Object) and other.collidable and other.collider then
            return other.collider
        end
    end
end

function Collider:getTransform()
    if self.parent then
        return self.parent:getFullTransform()
    else
        return nil
    end
end

function Collider:getTransformsWith(other)
    if self.parent and other.parent and self.parent.parent == other.parent.parent then
        return self.parent:getTransform(), other.parent:getTransform()
    else
        return self:getTransform(), other:getTransform()
    end
end

function Collider:getPointFor(other, x, y)
    if self.parent and other.parent then
        return other.parent:getRelativePos(other.x + x, other.y + y, self.parent)
    elseif self.parent then
        return self.parent:getFullTransform():inverseTransformPoint(other.x + x, other.y + y)
    elseif other.parent then
        return other.parent:getFullTransform():transformPoint(other.x + x, other.y + y)
    else
        return other.x + x, other.y + y
    end
end

--- Gets a single point relative to a target transformation.
---@param tf1 love.Transform? # The transformation of the source collider relative to the common parent.
---@param tf2 love.Transform? # The transformation of the target collider relative to the common parent.
---@param x number # The X coordinate of the point to be transformed.
---@param y number # The Y coordinate of the point to be transformed.
---@return number local_x # The transformed X coordinate.
---@return number local_y # The transformed Y coordinate.
function Collider:getLocalPoint(tf1, tf2, x, y)
    if tf2 ~= nil then
        x, y = tf2:transformPoint(x, y)
    end

    if tf1 ~= nil then
        x, y = tf1:inverseTransformPoint(x, y)
    end

    return x, y
end

function Collider:collidesWith(other)
    return self:applyInvert(other, false)
end

--- Performs a 3d collision check.
---@param other Object|Collider
---@return boolean collided
function Collider:collidesWith3D(other)
    other = self:getOtherCollider(other)
    if not self:collidableCheck(other) then return false end
    if not self:collidesZ(other) then return false end
    return self:collidesWith(other)
end

function Collider:clicked(button)
    if not button then
        local used_button = 0
        for i=1, Input.mouse_button_max do
            local success, success_button = self:clicked(i)
            used_button = math.max(used_button, success_button)
            if success then
                return true, success_button
            end
        end
        return false, used_button
    end
    local clicked, x, y, presses = Input.mousePressed(button)
    if not clicked then
        return false, 0
    end
    local point = PointCollider(nil, x, y)
    return self:collidesWith(point), button
end

function Collider:drawFor(obj, ...)
    if obj == self.parent or not self.parent then
        self:draw(...)
    else
        love.graphics.push()
        love.graphics.origin()
        love.graphics.applyTransform(self.parent:getFullTransform())
        self:draw(...)
        love.graphics.pop()
    end
end
function Collider:drawFillFor(obj, ...)
    if obj == self.parent or not self.parent then
        self:drawFill(...)
    else
        love.graphics.push()
        love.graphics.origin()
        love.graphics.applyTransform(self.parent:getFullTransform())
        self:drawFill(...)
        love.graphics.pop()
    end
end

function Collider:draw(...) end

function Collider:drawFill(...) end

function Collider:canDeepCopy()
    return true
end
function Collider:canDeepCopyKey(key)
    return key ~= "parent"
end

return Collider
