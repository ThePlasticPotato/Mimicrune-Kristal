---@class Hot : Weather
local Hot, super = Class("Weather")

function Hot:init(intensity)
    super.init(self, intensity)
    self.type = "hot"
    self.has_overlay = true
end

function Hot:drawOverlay(overlay)
    overlay:drawHeatTint(MathUtils.clamp(0.1 + self.intensity * 0.1, 0, 0.35))
end

return Hot
