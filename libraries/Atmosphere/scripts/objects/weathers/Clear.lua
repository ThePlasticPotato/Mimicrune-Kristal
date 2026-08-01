---@class Clear : Weather
local Clear, super = Class("Weather")

function Clear:init()
    super.init(self, 0)
    self.type = "clear"
end

return Clear
