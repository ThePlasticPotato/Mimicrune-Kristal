---@class AtmosphereRainPalette
---@field amount number
---@field harshness number

---@class Atmosphere
---@field active_weather Weather?
---@field rain_palette AtmosphereRainPalette
---@field rain_palette_tween table?
---@field time string
---@field time_fade number
local Atmosphere = {
    active_weather = nil,
    rain_palette = {amount = 0, harshness = 0},
    rain_palette_tween = nil,
    time = "default",
    time_fade = 1.0
}
Registry.registerGlobal("Atmosphere", Atmosphere)

function Atmosphere:init()
end

---@param weather Weather?
local function getRainPaletteTargets(weather)
    if not weather then return 0, 0 end
    return MathUtils.clamp(weather.palette_amount or 0, 0, 1),
           MathUtils.clamp(weather.palette_harshness or 0, 0, 1)
end

function Atmosphere:getCurrentTime()
    return self.time
end

function Atmosphere:setCurrentTime(time, duration)
    if (not duration) or duration == 0 then
        self.time = time
        self.time_fade = 1
        return
    end
    Game.stage.timer:tween(duration / 2, self, {time_fade = 0}, "linear", function()
        self.time = time
        Game.stage.timer:tween(duration / 2, self, {time_fade = 1}, "linear")
    end)
end

function Atmosphere:cancelRainPaletteTween()
    if self.rain_palette_tween and Game.stage then
        Game.stage.timer:cancel(self.rain_palette_tween)
    end
    self.rain_palette_tween = nil
end

function Atmosphere:fadeRainPalette(target, harshness, instant)
    local stage = Game.stage
    if not stage then return end

    self:cancelRainPaletteTween()
    target = MathUtils.clamp(target or 0, 0, 1)
    harshness = MathUtils.clamp(harshness or 0, 0, 1)

    local fx = stage:getFX("rain_fx")
    if not fx and target > 0 then
        fx = stage:addFX(ShaderFX("palettes/rain", {
            amount = function() return self.rain_palette.amount end,
            harshness = function() return self.rain_palette.harshness end
        }), "rain_fx")
    end

    if not fx then
        self.rain_palette.amount = 0
        self.rain_palette.harshness = 0
        return
    end

    local function finish()
        self.rain_palette_tween = nil
        if target <= 0 and stage:getFX("rain_fx") then
            stage:removeFX("rain_fx")
        end
    end

    if instant then
        self.rain_palette.amount = target
        self.rain_palette.harshness = harshness
        finish()
    else
        self.rain_palette_tween = stage.timer:tween(
            1.2,
            self.rain_palette,
            {amount = target, harshness = harshness},
            "out-sine",
            finish
        )
    end
end

---@param weather Weather?
---@param instant boolean?
function Atmosphere:refreshRainPalette(weather, instant)
    weather = weather or self.active_weather
    local amount, harshness = getRainPaletteTargets(weather)
    if weather and not weather:isInside() and amount > 0 then
        self:fadeRainPalette(amount, harshness, instant)
    else
        self:fadeRainPalette(0, 0, instant)
    end
end

function Atmosphere:onInit()
    Game:setFlag("audible_footsteps", self:getConfig("footsteps_audible_by_default"))
end

---@return Weather?
function Atmosphere:setWeather(id, instant, ...)
    if id == nil or id == "none" then
        self:stopWeather(instant)
        return nil
    end

    local weather = WeatherRegistry.create(id, ...)
    if not weather then
        Kristal.Console:error("Failed to create weather instance with id '" .. tostring(id) .. "'!")
        return nil
    end

    local previous = self.active_weather
    self.active_weather = weather
    Game.stage:addChild(weather)
    self:refreshRainPalette(weather, instant)

    if previous then previous:onEnd(instant) end
    return weather
end

function Atmosphere:stopWeather(instant)
    local previous = self.active_weather
    self.active_weather = nil
    self:refreshRainPalette(nil, instant)
    if previous then previous:onEnd(instant) end
end

function Atmosphere:getWeather()
    return self.active_weather
end

function Atmosphere:hasWeather(id)
    return self.active_weather ~= nil and (id == nil or self.active_weather.id == id or self.active_weather.type == id)
end

function Atmosphere:setWeatherPaused(paused)
    if self.active_weather then self.active_weather:setPaused(paused) end
end

function Atmosphere:getConfig(name)
    return Kristal.getLibConfig("atmosphere", name)
end

function Atmosphere:onRegisterObjects()
    WeatherRegistry.init()
end

---@param character Character
function Atmosphere:getStepVolume(character)
    local speed = 4
    local follower = character:includes(Follower)

    if follower then
        ---@cast character Follower
        local target = character:getTarget()
        if target and target.getCurrentSpeed then
            speed = target:getCurrentSpeed(target.state == "RUN" or target.run_timer > 0)
        end
    elseif character:includes(Player) then
        ---@cast character Player
        if character.getCurrentSpeed then
            speed = character:getCurrentSpeed(character.state == "RUN" or character.run_timer > 0)
        end
    end

    local volume = math.min(
        self:getConfig("step_volume") * (speed / 4),
        self:getConfig("step_volume_max")
    )
    if follower and self:getConfig("follower_volume_mult") then
        volume = volume * self:getConfig("follower_volume_mult")
    end
    return volume
end

function Atmosphere:onFootstep(character, num)
    local world = Game.world
    local water_depth = character.water_depth or 0
    if Game:getFlag("audible_footsteps", false) and world and world.map then
        local random_pitch = MathUtils.random(-0.15, 0.15)
        num = MathUtils.wrap(num, 1, 3)
        local sound, pitch = world:getStepSound(character.x, character.y, num, character.actor)
        if character.in_water then
            sound = "step/water_" .. ((water_depth < 3) and "shallow" or "deep") .. tostring(num)
        end
        Assets.stopAndPlaySound(sound, self:getStepVolume(character), pitch or (1 + random_pitch))
    end
end

return Atmosphere
