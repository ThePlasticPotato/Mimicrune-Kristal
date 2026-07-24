---@class HeightShadow : Object
---@overload fun(owner: Player) : HeightShadow
local HeightShadow, super = Class(Object)

---@param owner Player
function HeightShadow:init(owner)
    super.init(self, 0, 0, owner.width, owner.height)

    self.owner = owner
    self.height_sort_subject = true
    self.use_3d_collision = true
    self.height_depth_transparent = true
    self.height_depth_offset = -0.25
    self.debug_select = false
    self.active = false
    self.persistent = owner.persistent
end

function HeightShadow:syncOwner()
    local owner = self.owner
    if not owner then return end

    self.x, self.y = owner.x, owner.y
    self.z = owner.shadow_z or 0
    self.width, self.height = owner.width, owner.height
    self.layer = owner.layer
    self.origin_x, self.origin_y = owner.origin_x, owner.origin_y
    self.origin_exact = owner.origin_exact
    self.scale_x, self.scale_y = owner.scale_x, owner.scale_y
    self.scale_origin_x, self.scale_origin_y =
        owner.scale_origin_x, owner.scale_origin_y
    self.scale_origin_exact = owner.scale_origin_exact
    self.rotation = owner.rotation
    self.rotation_origin_x, self.rotation_origin_y =
        owner.rotation_origin_x, owner.rotation_origin_y
    self.rotation_origin_exact = owner.rotation_origin_exact
    self.flip_x, self.flip_y = owner.flip_x, owner.flip_y
    self.parallax_x, self.parallax_y = owner.parallax_x, owner.parallax_y
    self.parallax_origin_x, self.parallax_origin_y =
        owner.parallax_origin_x, owner.parallax_origin_y
    self.ground_surface = owner.shadow_surface
    self.visible = owner.visible and owner.platforming_enabled
        and owner.shadow_z ~= nil
end

function HeightShadow:getFullZ()
    self:syncOwner()
    return super.getFullZ(self)
end

function HeightShadow:getSortPosition()
    self:syncOwner()
    return self.owner:getSortPosition()
end

function HeightShadow:applyVisualTransformTo(transform, floor_x, floor_y)
    self:syncOwner()
    super.applyVisualTransformTo(self, transform, floor_x, floor_y)
end

function HeightShadow:shouldDraw()
    local owner = self.owner
    return owner and owner.visible and owner.shouldDrawHeightShadow
        and owner:shouldDrawHeightShadow()
end

--- Returns the receiving surface's top footprint in this object's local draw coords.
---@return number[]? coordinates
function HeightShadow:getSurfaceCoordinates()
    local surface = self.owner and self.owner.shadow_surface
    local bounds = surface and (surface.support_bounds or surface.bounds)
    if not bounds or self.owner.shadow_z == nil then return nil end

    local parent_transform = self.parent and self.parent:getFullVisualTransform()
        or love.math.newTransform()
    local shadow_transform = self:getFullVisualTransform()
    local coordinates = {}
    for _, point in ipairs({
        { bounds.min_x, bounds.min_y - self.owner.shadow_z },
        { bounds.max_x, bounds.min_y - self.owner.shadow_z },
        { bounds.max_x, bounds.max_y - self.owner.shadow_z },
        { bounds.min_x, bounds.max_y - self.owner.shadow_z }
    }) do
        local screen_x, screen_y =
            parent_transform:transformPoint(point[1], point[2])
        local local_x, local_y =
            shadow_transform:inverseTransformPoint(screen_x, screen_y)
        table.insert(coordinates, local_x)
        table.insert(coordinates, local_y)
    end
    return coordinates
end

function HeightShadow:draw()
    if not self:shouldDraw() then return end

    local coordinates = self:getSurfaceCoordinates()
    local previous_comparison, previous_value = love.graphics.getStencilTest()
    if coordinates then
        love.graphics.stencil(function()
            love.graphics.polygon("fill", coordinates)
        end, "replace", 1)
        love.graphics.setStencilTest("equal", 1)
    end

    local r, g, b, a = love.graphics.getColor()
    Draw.setColor(0, 0, 0, self.owner:getHeightShadowAlpha())
    love.graphics.ellipse("fill", self.width / 2, self.height - 2, 6, 2.5)
    love.graphics.setColor(r, g, b, a)

    if previous_comparison then
        love.graphics.setStencilTest(previous_comparison, previous_value)
    else
        love.graphics.setStencilTest()
    end
end

function HeightShadow:drawHeightOcclusionMask()
    self:draw()
end

return HeightShadow
