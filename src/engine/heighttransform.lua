--- A paired logical/visual transform for top-down height projection.
---@class HeightTransform : Class
---@overload fun(logical?:love.Transform, visual?:love.Transform, z?:number): HeightTransform
local HeightTransform = Class()

HeightTransform.PROJECTION_X = 0
HeightTransform.PROJECTION_Y = -1
HeightTransform.DEPTH_SCALE = 1 / 16384
HeightTransform.DEPTH_BIAS = 0.5

---@param logical? love.Transform
---@param visual? love.Transform
---@param z? number
function HeightTransform:init(logical, visual, z)
    self.logical = logical and logical:clone() or love.math.newTransform()
    self.visual = visual and visual:clone() or self.logical:clone()
    self.z = tonumber(z) or 0
end

---@param transform love.Transform
---@param z? number
---@return HeightTransform
function HeightTransform.fromLoveTransform(transform, z)
    return HeightTransform(transform, transform, z)
end

---@param x? number
---@param y? number
---@param z? number
---@return number x
---@return number y
function HeightTransform.projectPoint(x, y, z)
    z = tonumber(z) or 0
    return (x or 0) + z * HeightTransform.PROJECTION_X,
        (y or 0) + z * HeightTransform.PROJECTION_Y
end

---@param x? number
---@param y? number
---@param z? number
---@return number x
---@return number y
function HeightTransform.unprojectPoint(x, y, z)
    z = tonumber(z) or 0
    return (x or 0) - z * HeightTransform.PROJECTION_X,
        (y or 0) - z * HeightTransform.PROJECTION_Y
end

--- Resolves accumulated object elevation without constructing draw matrices.
---@param object Object
---@return number z
function HeightTransform.getFullZ(object)
    local z = 0
    while object do
        z = z + (tonumber(object.z) or 0)
        object = object.parent
    end
    return z
end

---@param transform love.Transform
---@param z? number
---@param floor_x? number
---@param floor_y? number
function HeightTransform.applyElevationTo(transform, z, floor_x, floor_y)
    z = tonumber(z) or 0
    if z == 0 then return end
    local offset_x = z * HeightTransform.PROJECTION_X
    local offset_y = z * HeightTransform.PROJECTION_Y
    if floor_x then
        offset_x = MathUtils.floorToMultiple(offset_x, floor_x)
        offset_y = MathUtils.floorToMultiple(offset_y, floor_y)
    end
    transform:translate(offset_x, offset_y)
end

---@return HeightTransform
function HeightTransform:clone()
    return HeightTransform(self.logical, self.visual, self.z)
end

---@return HeightTransform
function HeightTransform:reset()
    self.logical:reset()
    self.visual:reset()
    self.z = 0
    return self
end

--- Composes another height transform after this one.
---@param other HeightTransform
---@return HeightTransform
function HeightTransform:apply(other)
    self.logical:apply(other.logical)
    self.visual:apply(other.visual)
    self.z = self.z + other.z
    return self
end

--- Applies an XYZ translation to both logical and projected space.
---@param x? number
---@param y? number
---@param z? number
---@return HeightTransform
function HeightTransform:translate(x, y, z)
    x, y, z = x or 0, y or 0, z or 0
    self.logical:translate(x, y)
    local visual_x, visual_y = HeightTransform.projectPoint(x, y, z)
    self.visual:translate(visual_x, visual_y)
    self.z = self.z + z
    return self
end

---@param angle number
---@return HeightTransform
function HeightTransform:rotate(angle)
    self.logical:rotate(angle)
    self.visual:rotate(angle)
    return self
end

---@param x number
---@param y? number
---@return HeightTransform
function HeightTransform:scale(x, y)
    self.logical:scale(x, y or x)
    self.visual:scale(x, y or x)
    return self
end

---@param x number
---@param y number
---@return HeightTransform
function HeightTransform:shear(x, y)
    self.logical:shear(x, y)
    self.visual:shear(x, y)
    return self
end

--- Applies an Object's complete local transform and elevation.
---@param object Object
---@param floor_x? number
---@param floor_y? number
---@return HeightTransform
function HeightTransform:applyObject(object, floor_x, floor_y)
    HeightTransform.applyElevationTo(self.visual, object.z, floor_x, floor_y)
    object:applyTransformTo(self.logical, floor_x, floor_y)
    object:applyTransformTo(self.visual, floor_x, floor_y)
    self.z = self.z + (tonumber(object.z) or 0)
    return self
end

---@return love.Transform
function HeightTransform:getLogicalTransform()
    return self.logical
end

---@return love.Transform
function HeightTransform:getVisualTransform()
    return self.visual
end

--- Applies either half of this transform to another LOVE transform.
---@param transform love.Transform
---@param visual? boolean Defaults to the projected visual matrix.
---@return love.Transform
function HeightTransform:applyTo(transform, visual)
    transform:apply(visual == false and self.logical or self.visual)
    return transform
end

--- Applies either half of this transform to the active graphics transform.
---@param visual? boolean Defaults to the projected visual matrix.
function HeightTransform:applyToGraphics(visual)
    love.graphics.applyTransform(
        visual == false and self.logical or self.visual)
end

--- Replaces the active graphics transform with either half of this transform.
---@param visual? boolean Defaults to the projected visual matrix.
function HeightTransform:replaceGraphicsTransform(visual)
    love.graphics.replaceTransform(
        visual == false and self.logical or self.visual)
end

---@return number
function HeightTransform:getZ()
    return self.z
end

--- Converts a local XYZ point to logical ground space.
---@param x? number
---@param y? number
---@param z? number
---@return number x
---@return number y
---@return number z
function HeightTransform:transformPoint3D(x, y, z)
    local world_x, world_y = self.logical:transformPoint(x or 0, y or 0)
    return world_x, world_y, self.z + (z or 0)
end

--- Converts a logical ground-space XYZ point back to local space.
---@param x? number
---@param y? number
---@param z? number
---@return number x
---@return number y
---@return number z
function HeightTransform:inverseTransformPoint3D(x, y, z)
    local local_x, local_y = self.logical:inverseTransformPoint(x or 0, y or 0)
    return local_x, local_y, (z or 0) - self.z
end

--- Converts a local point to projected visual space. The optional Z is an
--- additional local elevation above this transform.
---@param x? number
---@param y? number
---@param z? number
---@return number x
---@return number y
function HeightTransform:transformVisualPoint(x, y, z)
    local projected_x, projected_y = HeightTransform.projectPoint(x, y, z)
    return self.visual:transformPoint(projected_x, projected_y)
end

--- Converts a projected visual-space point back to local space at a known
--- additional local elevation.
---@param x? number
---@param y? number
---@param z? number
---@return number x
---@return number y
function HeightTransform:inverseTransformVisualPoint(x, y, z)
    local local_x, local_y =
        self.visual:inverseTransformPoint(x or 0, y or 0)
    return HeightTransform.unprojectPoint(local_x, local_y, z)
end

--- Projects a ground-space point through the logical matrix at an explicit
--- absolute elevation. This is used for terrain faces and depth anchors whose
--- X/Y coordinates are already relative to the current draw parent.
---@param x? number
---@param y? number
---@param z? number
---@return number x
---@return number y
function HeightTransform:transformProjectedPoint(x, y, z)
    local projected_x, projected_y = HeightTransform.projectPoint(x, y, z)
    return self.logical:transformPoint(projected_x, projected_y)
end

--- Builds the complete screenspace inputs consumed by the height-depth shader.
---@param options {anchor_x:number?, anchor_y:number?, z:number?, horizontal_z:number?, depth_offset:number?, face_x:number?, face_y:number?, face_top_z:number?}
---@return table parameters
function HeightTransform:getDepthParameters(options)
    options = options or {}
    local anchor_x, anchor_y = options.anchor_x or 0, options.anchor_y or 0
    local _, screen_anchor_y = self:transformProjectedPoint(anchor_x, anchor_y, 0)
    local depth_scale = HeightTransform.DEPTH_SCALE
    local depth_offset = tonumber(options.depth_offset) or 0
    local parameters = {
        depth_mode = 0,
        anchor_y = screen_anchor_y,
        face_ground_y = screen_anchor_y,
        face_top_y = screen_anchor_y,
        height_pixels = 0,
        depth_scale = depth_scale,
        depth_bias = HeightTransform.DEPTH_BIAS + depth_offset * depth_scale,
        alpha_threshold = 0.0001,
        sort_depth = screen_anchor_y + depth_offset
    }

    if options.horizontal_z ~= nil then
        local _, projected_y = self:transformProjectedPoint(
            anchor_x, anchor_y, options.horizontal_z)
        local height_pixels = screen_anchor_y - projected_y
        parameters.depth_mode = 2
        parameters.height_pixels = height_pixels
        parameters.sort_depth = screen_anchor_y + height_pixels + depth_offset
    elseif options.face_top_z ~= nil then
        local face_x = options.face_x or anchor_x
        local face_y = options.face_y or anchor_y
        local _, face_ground_y =
            self:transformProjectedPoint(face_x, face_y, 0)
        local _, face_top_y =
            self:transformProjectedPoint(face_x, face_y, options.face_top_z)
        local height_pixels = face_ground_y - face_top_y
        parameters.depth_mode = 1
        parameters.face_ground_y = face_ground_y
        parameters.face_top_y = face_top_y
        parameters.height_pixels = height_pixels
        parameters.sort_depth = face_ground_y + height_pixels + depth_offset
    else
        local _, projected_y =
            self:transformProjectedPoint(anchor_x, anchor_y, options.z or 0)
        parameters.sort_depth =
            2 * screen_anchor_y - projected_y + depth_offset
    end
    return parameters
end

return HeightTransform
