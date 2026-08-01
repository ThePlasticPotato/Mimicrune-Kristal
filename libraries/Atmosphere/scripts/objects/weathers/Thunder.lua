---@class Thunder : Rain
local Thunder, super = Class("Rain")

function Thunder:init(intensity, wind_strength, wind_direction)
    super.init(self, intensity, wind_strength, wind_direction, 1, 0.85, true)
    self.type = "thunder"
end

return Thunder
