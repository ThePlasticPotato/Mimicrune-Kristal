---@class Overcast : Weather
local Overcast, super = Class("Weather")

function Overcast:init(intensity)
    super.init(self, intensity)
    self.type = "overcast"
    self.has_overlay = true
    self.palette_amount = MathUtils.clamp(self.intensity, 0, 1)
end

function Overcast:drawOverlay(overlay)
    overlay:drawRainTint(MathUtils.clamp(0.12 + self.intensity * 0.1, 0, 0.35))
end

return Overcast
