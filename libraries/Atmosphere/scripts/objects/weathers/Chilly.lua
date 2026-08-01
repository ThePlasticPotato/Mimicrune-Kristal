---@class Chilly : Weather
local Chilly, super = Class("Weather")

function Chilly:init(intensity)
    super.init(self, intensity)
    self.type = "chilly"
    self.has_overlay = true
end

function Chilly:drawOverlay(overlay)
    overlay:drawColdTint(MathUtils.clamp(0.08 + self.intensity * 0.1, 0, 0.3))
end

return Chilly
