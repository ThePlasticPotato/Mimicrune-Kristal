---@class WeatherRegistry
---@field weather_types table<string, Weather>
local WeatherRegistry = {
    weather_types = {}
}

function WeatherRegistry.init()
    WeatherRegistry.registerDefaults()
end

---@param id string
---@param weather Weather
function WeatherRegistry.register(id, weather)
    assert(type(id) == "string", "Weather IDs must be strings")
    assert(weather ~= nil, "Weather class cannot be nil")

    WeatherRegistry.weather_types[id] = weather
    return weather
end

---@param id string
---@return Weather?
function WeatherRegistry.get(id)
    return WeatherRegistry.weather_types[id]
end

---@param id string
---@return Weather?
function WeatherRegistry.create(id, ...)
    local weather = WeatherRegistry.get(id)
    if (weather) then
        local instance = weather(...)
        instance.id = id
        return instance
    end
    return nil
end

function WeatherRegistry.registerDefaults()
    WeatherRegistry.register("clear", Clear)
    WeatherRegistry.register("cloudy", Cloudy)
    WeatherRegistry.register("overcast", Overcast)
    WeatherRegistry.register("dark_overcast", DarkOvercast)
    WeatherRegistry.register("rain", Rain)
    WeatherRegistry.register("thunder", Thunder)
    WeatherRegistry.register("snow", Snow)
    WeatherRegistry.register("wind", Wind)
    WeatherRegistry.register("chilly", Chilly)
    WeatherRegistry.register("fog", Fog)
    WeatherRegistry.register("hot", Hot)
    WeatherRegistry.register("volcanic", Volcanic)
    WeatherRegistry.register("cd", CatsAndDogs)
    WeatherRegistry.register("cats_and_dogs", CatsAndDogs)
    WeatherRegistry.register("flipped_rain", FlippedRain)
end

return WeatherRegistry
