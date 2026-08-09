---@class AfterImage : Object
---@overload fun(...) : AfterImage
local AfterImage, super = Class(Object)

function AfterImage:init(sprite, fade, speed)
    super.init(self, 0, 0, SCREEN_WIDTH, SCREEN_HEIGHT)

    self.sprite = sprite
    if sprite.height_sort_subject and sprite.use_3d_collision then
        self.height_sort_subject = true
        self.use_3d_collision = true
        self.height_depth_transparent = true
        self.height_depth_offset = -0.25
        self.height_occlusion_z = sprite:getFullZ()
        self.height_occlusion_sort_x, self.height_occlusion_sort_y =
            sprite:getSortPosition()
        self.ground_surface = sprite.ground_surface
        self.airborne_surface = sprite.airborne_surface
    end

    self.alpha = fade
    self:fadeOutSpeedAndRemove(speed)

    self.canvas = love.graphics.newCanvas(SCREEN_WIDTH, SCREEN_HEIGHT)
    Draw.pushCanvas(self.canvas)
    love.graphics.push()
    love.graphics.origin()
    love.graphics.clear()
    local visual_transform =
        self.sprite:getFullHeightTransform():getVisualTransform():clone()
    love.graphics.applyTransform(visual_transform)
    Draw.setColor(self.sprite:getDrawColor())
    local drawing_afterimage = self.sprite._drawing_afterimage
    self.sprite._drawing_afterimage = true
    self.sprite:draw()
    self.sprite._drawing_afterimage = drawing_afterimage
    love.graphics.pop()
    Draw.popCanvas()

    local sox, soy = self.sprite:getScaleOrigin()
    local rox, roy = self.sprite:getRotationOrigin()

    local sox_p, soy_p = visual_transform:transformPoint(
        sox * self.sprite.width, soy * self.sprite.height
    )
    local rox_p, roy_p = visual_transform:transformPoint(
        rox * self.sprite.width, roy * self.sprite.height
    )

    self:setScaleOrigin(sox_p / SCREEN_WIDTH, soy_p / SCREEN_HEIGHT)
    self:setRotationOrigin(rox_p / SCREEN_WIDTH, roy_p / SCREEN_HEIGHT)
end

function AfterImage:getFullZ()
    return self.height_occlusion_z or super.getFullZ(self)
end

function AfterImage:getSortPosition()
    if self.height_occlusion_sort_x then
        return self.height_occlusion_sort_x, self.height_occlusion_sort_y
    end
    return super.getSortPosition(self)
end

function AfterImage:drawHeightOcclusionMask()
    if self.height_sort_subject then
        Draw.drawCanvas(self.canvas)
    end
end

function AfterImage:onAdd(parent)
    local sibling

    local other_parents = self.sprite:getHierarchy()
    for _, v in ipairs(self:getHierarchy()) do
        for i, o in ipairs(other_parents) do
            if o.parent and o.parent == v then
                sibling = o
                break
            end
        end
        if sibling then break end
    end

    if sibling then
        self.height_depth_layer = sibling.height_depth_layer or sibling.layer
        self.layer = sibling.layer - 0.001
    end
end

function AfterImage:onRemove()
    self.canvas:release()
    self.canvas = nil
end

function AfterImage:applyTransformTo(transform)
    if self.parent then
        transform:reset()
    end
    super.applyTransformTo(self, transform)
end

function AfterImage:draw()
    Draw.drawCanvas(self.canvas)
    super.draw(self)
end

return AfterImage
