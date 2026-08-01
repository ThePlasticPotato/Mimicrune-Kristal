---@class Fog : Weather
local Fog, super = Class("Weather")

function Fog:init(intensity)
    super.init(self, intensity)
    self.type = "fog"
    self.has_overlay = true
end

function Fog:drawOverlay(overlay)
    overlay:drawFog(MathUtils.clamp(0.12 + self.intensity * 0.12, 0, 0.55))
end

return Fog
