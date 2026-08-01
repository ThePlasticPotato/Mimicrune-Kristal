---@class VentSteam : Object
---@overload fun(x?: number, y?: number, z?: number, direction?: number, speed?: number): VentSteam
local VentSteam, super = Class(Object)

function VentSteam:init(x, y, z, direction, speed)
    super.init(self, x or 0, y or 0, 1, 1)
    self.z = tonumber(z) or 0
    self.debug_select = false
    self.height_sort_subject = true
    self.use_3d_collision = true
    self.height_depth_transparent = true
    self.height_depth_offset = -0.05

    self.sprite = Sprite("effects/ventsteam")
    self.sprite:setOrigin(0.5, 0.5)
    self.sprite.rotation = math.rad(love.math.random(0, 360))
    self:addChild(self.sprite)

    self.size = 0.8
    self:setScale(self.size)
    self.physics.direction = direction
        or math.rad(-80 + love.math.random(-20, 20))
    self.physics.speed = tonumber(speed) or 6
    self.physics.friction = 0.1
    self.layer = WORLD_LAYERS["above_events"]
end

function VentSteam:update()
    super.update(self)
    self.size = self.size + 0.12 * DTMULT
    self:setScale(self.size)
    self.sprite.alpha = self.sprite.alpha - 0.07 * DTMULT
    self.sprite.rotation = self.sprite.rotation + math.rad(6) * DTMULT
    if self.sprite.alpha < 0.1 then self:remove() end
end

function VentSteam:drawHeightOcclusionMask()
    if self.sprite and self.sprite.visible then
        self.sprite:fullDraw(false)
    end
end

return VentSteam
