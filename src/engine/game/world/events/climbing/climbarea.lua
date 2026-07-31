--- A ClimbArea is an area the player can climb on.
---
--- To enter one, you must either use a [`ClimbEntry`](lua://ClimbEntry), or enter the room at a marker with "player_state" set to "CLIMB".
---
--- To exit one, you must use a [`ClimbExit`](lua://ClimbExit).
---
--- `ClimbArea` is an [`Event`](lua://Event.init) - naming an object `climbarea` on an `objects` layer in a map creates this object.
---
---@class ClimbArea : Event
---
---@overload fun(...) : ClimbArea
local ClimbArea, super = Class(Event)

---@param x number?
---@param y number?
---@param shape EventShape?
function ClimbArea:init(x, y, shape)
    shape = shape or { TILE_WIDTH, TILE_HEIGHT }
    super.init(self, x, y, shape)

    self.climbable = true
    self.climb_height_mode = "auto"
    self.climb_height_axis = "y"
    self.climb_height_reverse = false
end

function ClimbArea:onLoad()
    local properties = self.data and self.data.properties or {}
    self.climb_height_mode = properties.climb_height_mode or "auto"
    self.climb_height_axis = properties.climb_height_axis or "y"
    self.climb_height_reverse = properties.climb_height_reverse == true
end

function ClimbArea:usesHeightPlane()
    if not self.world or not self.world.map or not self.world.map.platforming then
        return false
    end
    if self.climb_height_mode == "flat" then return false end
    if self.climb_height_mode == "vertical" then return true end
    return (self.collider.depth or self.depth or 0) > 0
end

--- Samples the elevation represented by a projected point on this area.
---@param world_x number Projected world X
---@param world_y number Projected world Y
---@return number z
function ClimbArea:getClimbHeightAt(world_x, world_y)
    local bottom, top = self.collider:getZBounds()
    if not self:usesHeightPlane() or top <= bottom then return bottom end

    local logical_y = world_y + self:getFullZ()
    local local_x, local_y = self:getFullTransform():inverseTransformPoint(
        world_x, logical_y)
    local axis = self.climb_height_axis == "x" and "x" or "y"
    local coordinate = axis == "x" and local_x or local_y
    local extent = axis == "x" and self.width or self.height
    local progress
    if extent == 0 then
        progress = 0
    elseif axis == "y" then
        progress = 1 - coordinate / extent
    else
        progress = coordinate / extent
    end
    if self.climb_height_reverse then progress = 1 - progress end
    progress = MathUtils.clamp(progress, 0, 1)
    return MathUtils.lerp(bottom, top, progress)
end

--- *(Override)* Called when the player finishes a move on this area. Examples being moving, jumping, or falling onto this area.
---@param player Player
function ClimbArea:onClimbMove(player)
end

--- Whether or not this area can be climbed on.
function ClimbArea:isClimbable()
    return self.climbable
end

--- Sets whether or not this area can be climbed on.
function ClimbArea:setClimbable(climbable)
    self.climbable = climbable
end

function ClimbArea:drawDebug()
    self.collider:draw(0, 1, 1)
end

return ClimbArea
