---@class DarkOvercast : Overcast
local DarkOvercast, super = Class("Overcast")

function DarkOvercast:init(intensity)
    super.init(self, intensity)
    self.type = "dark_overcast"
    self.palette_harshness = MathUtils.clamp(self.intensity, 0, 1)
end

function DarkOvercast:drawOverlay(overlay)
    overlay:drawDarkRainTint(MathUtils.clamp(0.28 + self.intensity * 0.18, 0, 0.65))
end

return DarkOvercast
