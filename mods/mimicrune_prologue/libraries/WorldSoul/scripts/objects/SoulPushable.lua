---@class SoulPushable : Event A base class for an event pushable by the soul.
---@field weight number The weight of the object, determining the soul's speed when pushing it. Defaults to 2.
---@field axis string The allowed axis of movement. Either X, Y, or XY.
---@field dir_limit table<number> The limits of movement in each direction for this object. Defaults to the screen size if the axis is allowed, or 0 if it's locked.
---@field currently_pushable boolean Whether this object is currently pushable. Set this to false if/when you want to have it stop being pushable.
---@field sound string|nil The push sound for this object, defined by the property "push_sound".
local SoulPushable, super = Class(Event)

function SoulPushable:init(data)
    super.init(self, data)
    self:setOrigin(0.5, 0.5)

    local properties = data.properties or {}

    self.weight = properties["weight"] or 2
    self.axis = properties["axis"] or "XY"
    self.dir_limit = {
        ["up"] = properties["axis_limit_up"] or (self.axis ~= "X" and -self.y or 0),
        ["down"] = properties["axis_limit_up"] or (self.axis ~= "X" and Game.world.map.height - self.y or 0),
        ["left"] = properties["axis_limit_up"] or (self.axis ~= "Y" and -self.x or 0),
        ["right"] = properties["axis_limit_up"] or (self.axis ~= "Y" and Game.world.map.width - self.x or 0),
    }
    self.soul_only = properties["soul_only"] or true
    self.currently_pushable = properties["pushable"] or true
    self.sound = properties["push_sound"] or nil
    self.pushed_distance_x = 0
    self.pushed_distance_y = 0

    self.solid = true
    if (properties["sprite"]) then
        self:setSprite(properties["sprite"])
    end
end

function SoulPushable:onSoulCollide(soul, DT)
    if not self.currently_pushable then return true end

    local to_angle = Utils.angle(soul, self)
    local facing = Utils.facingFromAngle(to_angle)

    local dist = (soul.speed / self.weight) --* DTMULT

    if not self:checkCollision(facing, dist) and self:checkLimits(facing, dist) then
        self:onPush(facing, dist)
        self:playPushSound()
    else
        self:onPushFail(facing, dist)
    end

    return true
end

---@return boolean collided
function SoulPushable:checkCollision(facing, dist)
    local collided = false

    local dx, dy = Utils.getFacingVector(facing)
    local target_x, target_y = self.x + dx * dist, self.y + dy * dist

    local x1, y1 = math.min(self.x, target_x), math.min(self.y, target_y)
    local x2, y2 = math.max(self.x + self.width, target_x + self.width), math.max(self.y + self.height, target_y + self.height)

    local bound_check = Hitbox(self.world, x1 + 1, y1 + 1, x2 - x1 - 2, y2 - y1 - 2)

    Object.startCache()
    for _,collider in ipairs(Game.world.map.pushable_collision) do
        if collider:collidesWith(bound_check) then
            collided = true
            break
        end
    end
    if not collided then
        self.collidable = false
        collided = self.world:checkCollision(bound_check)
        self.collidable = true
    end
    Object.endCache()

    return collided
end

---@return boolean valid
function SoulPushable:checkLimits(facing, dist)
    local dx, dy = Utils.getFacingVector(facing)
    if (dx ~= 0) and self.axis == "Y" then
        return false
    elseif ((dx > 0) and self.pushed_distance_x + dist > self.dir_limit["right"]) or ((dx < 0) and self.pushed_distance_x - dist < self.dir_limit["left"]) then
        return false
    end

    if (dy ~= 0) and self.axis == "X" then
        return false
    elseif ((dy > 0) and self.pushed_distance_y + dist > self.dir_limit["down"]) or ((dy < 0) and self.pushed_distance_y - dist < self.dir_limit["up"]) then
        return false
    end
    return true
end

---Called whenever the soul successfully pushes the pushable. Feel free to override it, but don't forget to super call it if you want the default movement code.
function SoulPushable:onPush(facing, dist)
    local dx, dy = Utils.getFacingVector(facing)
    local target_x, target_y = self.x + dx * dist, self.y + dy * dist

    self.x = target_x
    self.y = target_y
    self.pushed_distance_x = self.pushed_distance_x + (dx * dist)
    self.pushed_distance_y = self.pushed_distance_y + (dy * dist)
end

---*(Override)* Called whenever the soul fails to push the pushable
function SoulPushable:onPushFail(facing, dist)
end

function SoulPushable:playPushSound()
    if (self.sound) then
        Assets.playSound(self.sound)
    end
end

return SoulPushable