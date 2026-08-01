---@class CatsAndDogs : Rain
local CatsAndDogs, super = Class("Rain")

function CatsAndDogs:init(intensity, wind_strength, wind_direction)
    super.init(self, intensity, wind_strength, wind_direction)
    self.type = "cd"
end

function CatsAndDogs:getRainSprites()
    return {"cat", "dog"}
end

return CatsAndDogs
