--- The settings for a FallingClimbArea.
---@class FallingClimbAreaSettings
---@field dont_break FacingDirection? If this is set, the area will not break in the specified direction.
---@field breaks_on_leave boolean? If true, leaving this area will cause it to fall. Defaults to true.
---@field fall_time number? If "timed" is true, this is the amount of time it takes for this area to fall, in frames. Defaults to 60 frames (2 seconds).
---@field timed boolean? If this is true, this area will fall after a set amount of time, starting once the player is on it. Defaults to false.
---@field no_unsafe_area boolean? If true, a [`ClimbUnsafe`](lua://ClimbUnsafe) area will NOT automatically be placed on top of this area. Defaults to false.

--- A FallingClimbArea is an area the player can climb on. It will fall once the player leaves it.
---
--- `FallingClimbArea` is an [`Event`](lua://Event.init) - naming an object `FallingClimbArea` on an `objects` layer in a map creates this object.
---
---@class FallingClimbArea : ClimbArea
---
---@overload fun(...) : FallingClimbArea
local FallingClimbArea, super = Class(ClimbArea)

---@param x number?
---@param y number?
---@param shape EventShape?
---@param settings FallingClimbAreaSettings?
function FallingClimbArea:init(x, y, shape, settings)
    settings = settings or {}
    shape = shape or { TILE_WIDTH, TILE_HEIGHT }
    super.init(self, x, y, shape)

    self.dont_break = settings.dont_break
    self.breaks_on_leave = settings.breaks_on_leave ~= false
    self.fall_time = settings.fall_time or 60
    self.timed = settings.timed or false
    self.no_unsafe_area = settings.no_unsafe_area or false

    self.state = 0 -- 0 = idle, 1 = player overlapping, 2 = falling
    self.timer = 0

    self.unsafe_area = nil
end

function FallingClimbArea:onLoad()
    super.onLoad(self)

    if (not self.no_unsafe_area) then
        self.unsafe_area = ClimbUnsafe(self.x, self.y, { self.width, self.height })
        self.unsafe_area:setParallax(self:getParallax())
        self.unsafe_area:setOrigin(self:getOrigin())
        self.unsafe_area.z = self.z
        self.unsafe_area.depth = self.depth
        self.unsafe_area.collider.depth = self.collider.depth
        self.unsafe_area.height_sensitive = self.height_sensitive
        self.parent:addChild(self.unsafe_area)
    end
end

function FallingClimbArea:onRemove(parent)
    super.onRemove(self, parent)

    if self.unsafe_area then
        self.unsafe_area:remove()
        self.unsafe_area = nil
    end
end

function FallingClimbArea:onCollide(character)
    if self.state == 0 and character.is_player and character:isClimbing() then
        self.state = 1
    end
end

function FallingClimbArea:update()
    super.update(self)

    if self.state ~= 1 then
        return
    end

    local should_destroy = false

    self.timer = self.timer + DTMULT

    local target = Game.world.player

    if self.breaks_on_leave then
        local visual_x, visual_y
        local overlapping = false
        if target ~= nil then
            if target.platforming_enabled and target:isClimbing() then
                visual_x, visual_y = target.climb_state:getClimbPosition()
                overlapping = target.climb_state:objectOverlapsAt(
                    self, visual_x, visual_y, target.z, false)
            else
                visual_x, visual_y = target.x, target.y
                overlapping = target:collidesWith(self)
            end
        end
        if target ~= nil and not overlapping then
            if self.dont_break == nil then
                self.state = 2
                should_destroy = true
            elseif (self.dont_break == "down") and visual_y < self.y - self:getFullZ() then
                self.state = 2
                should_destroy = true
            elseif (self.dont_break == "up")
                and visual_y >= self.y - self:getFullZ() + (self.height / 2) then
                self.state = 2
                should_destroy = true
            elseif (self.dont_break == "left") and visual_x >= self.x + (self.width / 2) then
                self.state = 2
                should_destroy = true
            elseif (self.dont_break == "right") and visual_x < self.x then
                self.state = 2
                should_destroy = true
            else
                self.state = 0
            end
        end
    end

    if self.timed and self.timer >= self.fall_time then
        self.state = 2
        if target ~= nil then
            target:climbFall(0)
        end
        should_destroy = true
    end

    if should_destroy then
        self:setClimbable(false)

        Assets.playSound("heavyswing")
        self.physics.gravity = 1

        Game.world.timer:after(1, function()
            self:remove()
        end)
    end
end

function FallingClimbArea:applyTileObject(data, map)
    local tile = map:createTileObject(data, 0, 0, self.width, self.height)
    tile.debug_select = false

    local ox, oy = tile:getOrigin()
    self:setOrigin(ox, oy)

    tile:setPosition(ox * self.width, oy * self.height)

    self:addChild(tile)
end

return FallingClimbArea
