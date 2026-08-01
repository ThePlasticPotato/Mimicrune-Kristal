---@class FlippedRain : Rain
local FlippedRain, super = Class("Rain")

function FlippedRain:init(intensity, wind_strength, wind_direction)
    super.init(self, intensity, wind_strength, wind_direction)
    self.type = "flipped_rain"
end

function FlippedRain:getDropSpritePath()
    return "world/flippedrain/"
end

return FlippedRain
