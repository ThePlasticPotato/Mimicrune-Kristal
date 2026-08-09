---@class VesselLureNote : Sprite
local VesselLureNote, super = Class(Sprite)

local RISE_TIME = 0.7
local RISE_SPEED = 34
local RISE_WOBBLE = 4
local MIN_TRAVEL_DISTANCE = 72
local TRAVEL_DISTANCE_FACTOR = 0.7
local MAX_TRAVEL_DISTANCE = 360
local MIN_LURE_SPEED = 45
local MAX_LURE_SPEED = 75
local DISTANT_SOUL_RANGE = 450
local END_LINGER_TIME = 0.35

---@param variant integer
---@param x number
---@param y number
---@param target? WorldSoul
---@param vessel_distance? number
function VesselLureNote:init(variant, x, y, target, vessel_distance)
    super.init(self, "effects/vesselnote_" .. variant, x, y)
    self:setOrigin(0.5, 0.5)
    self:flash()

    self.target = target
    self.age = 0
    self.rise_x = x
    self.rise_y = y

    vessel_distance = math.max(tonumber(vessel_distance) or 0, 0)
    self.travel_remaining = MathUtils.clamp(
        MIN_TRAVEL_DISTANCE + vessel_distance * TRAVEL_DISTANCE_FACTOR,
        MIN_TRAVEL_DISTANCE,
        MAX_TRAVEL_DISTANCE
    )
    local distance_progress = MathUtils.clamp(
        vessel_distance / DISTANT_SOUL_RANGE, 0, 1
    )
    self.lure_speed = MathUtils.lerp(
        MIN_LURE_SPEED, MAX_LURE_SPEED, distance_progress
    )
    self.duration = RISE_TIME
        + self.travel_remaining / self.lure_speed
        + END_LINGER_TIME
end

---@return number? x
---@return number? y
function VesselLureNote:getLureTargetPosition()
    local target = self.target
    if not target or target.parent == nil then return nil end
    return target.x, target.y - (target.hover_offset or 0)
end

function VesselLureNote:update()
    super.update(self)
    self.age = self.age + DT

    if self.age < RISE_TIME then
        local progress = self.age / RISE_TIME
        self.x = self.rise_x
            + math.sin(progress * math.pi * 2) * RISE_WOBBLE
        self.y = self.rise_y - RISE_SPEED * self.age
    elseif self.travel_remaining > 0 then
        local target_x, target_y = self:getLureTargetPosition()
        if target_x then
            local dx, dy = target_x - self.x, target_y - self.y
            local distance = MathUtils.dist(0, 0, dx, dy)
            if distance > 0 then
                local movement = math.min(
                    self.lure_speed * DT,
                    self.travel_remaining,
                    distance
                )
                self.x = self.x + dx / distance * movement
                self.y = self.y + dy / distance * movement
                self.travel_remaining = self.travel_remaining - movement
            end
        end
    end

    local life_progress = MathUtils.clamp(self.age / self.duration, 0, 1)
    self:setScale(1 - life_progress)
    if life_progress >= 1 then self:remove() end
end

return VesselLureNote
