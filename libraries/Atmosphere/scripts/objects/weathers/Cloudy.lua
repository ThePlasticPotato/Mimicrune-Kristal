---@class Cloudy : Weather
local Cloudy, super = Class("Weather")

function Cloudy:init(intensity)
    super.init(self, intensity)
    self.type = "cloudy"
    self.has_overlay = true
end

function Cloudy:drawOverlay(overlay)
    overlay:drawRainTint(MathUtils.clamp(0.04 + self.intensity * 0.04, 0, 0.16))
end

return Cloudy
