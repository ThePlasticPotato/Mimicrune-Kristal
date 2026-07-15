local lib = {}
Registry.registerGlobal("WeatherLib", lib)
WeatherLib = lib

local RAIN_PALETTE_FADE_TIME = 1.2
local LEAF_SWAY_FADE_TIME = 0.8

local rainytypes = {
    "rain",
    "thunder",
    "overcast",
    "dark_overcast"
}

local harsh_rain_types = {
    thunder = 0.85,
    dark_overcast = 1
}

local leaf_sway_weather = {
    rain = 0.55,
    overcast = 0.35,
    dark_overcast = 0.65,
    thunder = 1.25,
    wind = 1.25
}

local function getWeatherType(weather)
    return weather.type or weather[1]
end

local function getWeatherIntensity(weather)
    return weather.intensity or weather.multiplier or weather[2] or 1
end

local function getRainPaletteTargets(weathers)
    local amount = 0
    local harshness = 0

    for _, weather in ipairs(weathers or {}) do
        local weather_type = getWeatherType(weather)
        if TableUtils.contains(rainytypes, weather_type) then
            local intensity = getWeatherIntensity(weather)
            amount = math.max(amount, intensity)
            harshness = math.max(harshness, (harsh_rain_types[weather_type] or 0) * intensity)
        end
    end

    return MathUtils.clamp(amount, 0, 1), MathUtils.clamp(harshness, 0, 1)
end

local function getWeatherLeafSwayTarget(weathers)
    local amount = 0

    for _, weather in ipairs(weathers or {}) do
        local weather_type = getWeatherType(weather)
        local intensity = getWeatherIntensity(weather)
        amount = math.max(amount, (leaf_sway_weather[weather_type] or 0) * intensity)
    end

    return MathUtils.clamp(amount, 0, 1.5)
end

local function cancelRainPaletteTween(stage)
    if stage.rain_palette_tween then
        stage.timer:cancel(stage.rain_palette_tween)
        stage.rain_palette_tween = nil
    end
end

local function cancelLeafSwayTween(stage)
    if stage.weather_leaf_sway_tween then
        stage.timer:cancel(stage.weather_leaf_sway_tween)
        stage.weather_leaf_sway_tween = nil
    end
end

local function fadeRainPalette(stage, target, harshness)
    cancelRainPaletteTween(stage)
    harshness = harshness or 0

    stage.rain_palette = stage.rain_palette or {amount = 0, harshness = 0}

    local fx = stage:getFX("rainoverlay")
    if not fx and target > 0 then
        fx = stage:addFX(ShaderFX("palettes/rainy", {
            ["amount"] = function() return stage.rain_palette.amount end,
            ["harshness"] = function() return stage.rain_palette.harshness end
        }), "rainoverlay")
    elseif fx then
        fx.vars["amount"] = function() return stage.rain_palette.amount end
        fx.vars["harshness"] = function() return stage.rain_palette.harshness end
    end

    if not fx then
        return
    end

    stage.rain_palette_tween = stage.timer:tween(RAIN_PALETTE_FADE_TIME, stage.rain_palette, {amount = target, harshness = harshness}, "out-sine", function()
        stage.rain_palette_tween = nil

        if target <= 0 then
            stage:removeFX("rainoverlay")
        end
    end)
end

local function fadeWeatherLeafSway(stage, target)
    cancelLeafSwayTween(stage)

    stage.weather_leaf_sway = stage.weather_leaf_sway or {amount = 0}
    stage.weather_leaf_sway_tween = stage.timer:tween(LEAF_SWAY_FADE_TIME, stage.weather_leaf_sway, {amount = target}, "out-sine", function()
        stage.weather_leaf_sway_tween = nil
    end)
end

function WeatherLib:init()

    WeatherRegistry.init()

    HookSystem.hook(Stage, "setWeather", function(orig, self, typer, keep, sfx, addto)
        orig(self)
        --print(Game.world.player)
        local weather_type = {}
        local wrongtype = false
        local istable = false
        local nuh_uh = false
        local possible_types_a = {
            "rain",
            "thunder",
            "snow",
            "wind",
            --"volcanic",
            "chilly",
            "cloudy",
            "overcast",
            "dark_overcast",
            --"hot",
            "clear",
            "cd",
        }
        local possible_types = possible_types_a
        if Kristal.getLibConfig("weatherlib", "extraWeathers") then
            possible_types = TableUtils.merge(possible_types_a, Kristal.getLibConfig("weatherlib", "extraWeathers"))
        end

        if type(typer) == "string" then
            typer = {typer}
        end

        if typer and type(typer[2]) ~= "number" then
            for i, t in ipairs(typer) do
                if type(t) ~= "table" then
                    t = {t, 1}
                    table.remove(typer, i)
                    table.insert(typer, i, t)
                    --print(t[2])
                else
                    if #t < 2 then table.insert(t, 2, 1) end
                end
            end
            --print(typer[1])
        elseif typer and #typer == 2 and type(typer[2]) == "number" then
            typer = {typer}
        end

        if sfx == nil then sfx = true end

        if type(typer) == "table" then
            TableUtils.merge(weather_type, typer)
        end

        for i, symb in ipairs(weather_type) do
            for i, again in ipairs (symb) do if i == 1 then
                local number = 0
                for i, symb2 in ipairs(possible_types) do
                    if again == symb2 then number = number + 1 end
                end
                if number < 1 then wrongtype = true end
            end end
        end

        local haveoverlay = true
        if typer then for i, all in ipairs(typer) do
            --print(i, all[1])
            --print(all[i])
            if all[1] == "clear" then haveoverlay = false end
        end end

        if not typer or typer[1][1] == "none" then
            --if Game.stage.weathersounds then self.weathersounds:stop() end
            Game.stage.weather_type = nil
            Game.stage.keep_weather = nil
            if Game.stage.overlay then 
                if Game.stage.weather then
                    for i, o in ipairs(Game.stage.overlay) do
                        o[2]:remove()
                    end
                end
            end
            Game.stage.overlay = {}
            if Game.stage.weather then
                for i, weather in ipairs(Game.stage.weather) do
                    weather:remove()
                end
            end
            Game.stage.weather = {}
            Game.stage.weather_type = typer
            if #Game.stage.weather > 0 then Game:setFlag("weather_save", false) end
            fadeRainPalette(Game.stage, 0)
            fadeWeatherLeafSway(Game.stage, 0)

            --Game.stage.overlay = nil
            self.addto = nil
        elseif wrongtype then
            
            local first = typer[1][1]
            for i, ty in ipairs(typer) do
                if #typer > 1 and i > 1 then
                    first = first + " + " + ty[1]
                end
            end

            error("Attempt to set nonexistent weather \"" .. first .."\"")
        else
            
            --if Game.stage.weathersounds then self.weathersounds:stop() end
            Game.stage.weather_type = nil
            Game.stage.keep_weather = nil
            if Game.stage.overlay then 
                if Game.stage.weather then
                    for i, o in ipairs(Game.stage.overlay) do
                        o[2]:remove()
                    end
                end
            end
            if Game.stage.weather then
                for i, weather in ipairs(Game.stage.weather) do
                    weather:remove()
                end
            end
            self.weather = {}
            Game.stage.overlay = {}

            if keep then
                Game.stage.keep_weather = true
            end
            
            for i, typ in ipairs (typer) do
                --print(typ)
                local w
                local possible_types_again = {
                    "rain",
                    "thunder",
                    "snow",
                    "wind",
                    "volcanic",
                    "chilly",
                    "cloudy",
                    "overcast",
                    "dark_overcast",
                    "hot",
                    "clear",
                    "cd",
                }
                if TableUtils.contains(possible_types_again, typ[1]) then
                    w = Game.stage:addChild(WeatherHandler(typ[1], sfx, addto, typ[2], haveoverlay))
                    --print("A", typ[1])
                else
                    local b = WeatherRegistry.createWeatherData(typ[1], sfx, addto, typ[2], haveoverlay)

                    --print(b.type, "type")
                    w = Game.stage:addChild(b)
                    --print("B")]]
                end
                table.insert(self.weather, w)
            end

            local first = typer[1][1]
            for i, ty in ipairs(typer) do
                if #typer > 1 then
                    first = first + " + " + ty[1]
                end
            end
            Game.stage.weather_type = first
            Game.stage.last_weather = {typer, keep, sfx, addto}
            Game:setFlag("weather_save", {typer, keep, sfx})
            if Game.world.map.inside or Game.world.map.data.properties["inside"] then
                Game.stage:setWeatherLayer(-10)
                for i, weather in ipairs(self.weather) do
                    weather.weathersounds.volume = weather.weathersounds.volume / 8
                    weather.weathersounds.pitch = weather.weathersounds.pitch - 0.09
                end
                Game.stage.was_weather_inside = true
            else 
                Game.stage.was_weather_inside = false
            end
            --print(typer)
            self.addto = addto

            local rain_palette_amount, rain_palette_harshness = getRainPaletteTargets(typer)
            if ((not Game.world.map.inside) and rain_palette_amount > 0) then
                if (Game.world and Game.world.music and Game.world.music.current) then
                    if StringUtils.contains(Game.world.music.current, "day") then
                        Game.world:transitionMusicTimed(StringUtils.split(Game.world.music.current, "day", true)[1] .. "rain", true)
                    end
                end
                fadeRainPalette(Game.stage, rain_palette_amount, rain_palette_harshness)
            else
                if (Game.world and Game.world.music and Game.world.music.current) then
                    if StringUtils.contains(Game.world.music.current, "rain") then
                        Game.world:transitionMusicTimed(StringUtils.split(Game.world.music.current, "rain", true)[1] .. Game:getFlag("daytime", "day"), true)
                    end
                end
                fadeRainPalette(Game.stage, 0)
            end

            local leaf_sway_amount = getWeatherLeafSwayTarget(typer)
            if not (Game.world.map.inside or Game.world.map.data.properties["inside"]) then
                fadeWeatherLeafSway(Game.stage, leaf_sway_amount)
            else
                fadeWeatherLeafSway(Game.stage, 0)
            end
        end
    end)

    HookSystem.hook(Stage, "getWeatherMask", function(orig, self)
        orig(self)
        local currentMap = Game.world.map.id
        return Assets.getTexture("masks/"..currentMap.."_mask")
    end)

    HookSystem.hook(Stage, "getWeatherInverseMask", function(orig, self)
        orig(self)
        local currentMap = Game.world.map.id
        return Assets.getTexture("masks/"..currentMap.."_inverse_mask")
    end)

    HookSystem.hook(Stage, "hasWeather", function(orig, self, weather)
        orig(self)
        if Game.stage.weather then
            if not weather then
                return (#Game.stage.weather > 0)
            else
                for i, w in ipairs(Game.stage.weather) do
                    if w.type == weather then
                        return true
                    end
                end
            end
            return false
        end
    end)

    HookSystem.hook(Stage, "getWeatherParent", function(orig, self)
        if Game.battle then
            return Game.battle
        elseif Game.world then
            return Game.world
        end

        return false
    end)

    HookSystem.hook(Stage, "setWeatherParent", function(orig, self, parent)

        if not parent then parent = self:getWeatherParent() end

        if Game.stage.weather and #Game.stage.weather > 0 then
            if parent then
                for i, w in ipairs(Game.stage.weather) do
                    w.addto = parent
                end
                self.addto = parent
            end
        end
    end)

    HookSystem.hook(Stage, "setWeatherLayer", function(orig, self, layer)
        self.weather_layer = layer and layer + 1 or nil
    end)

    HookSystem.hook(Stage, "resetWeatherLayer", function(orig, self, layer)
        self.weather_layer = nil
    end)

    HookSystem.hook(Stage, "getWeatherLayer", function(orig, self, layer)
        return self.weather_layer
    end)

    HookSystem.hook(Stage, "resetWeather", function(orig, self)
        self:setWeather()
    end)

    HookSystem.hook(Stage, "pauseWeather", function(orig, self, reason)
        if not self.wpaused then
            if Game.stage.overlay then 
                if Game.stage.weather then
                    for i, o in ipairs(Game.stage.overlay) do
                        o.paused = true
                    end
                end
            end
            if Game.stage.weather then
                for i, weather in ipairs(Game.stage.weather) do
                    weather.pause = true
                    --weather.weathersounds.volume = weather.weathersounds.volume / 4
                    --weather.weathersounds.pitch = weather.weathersounds.pitch - 0.09
                end
            end

            Game.stage.wpaused = true
            if reason then Game.stage.pause_reason = reason end
        end
    end)

    HookSystem.hook(Stage, "playWeather", function(orig, self)
        if not self.wpaused then
            error("WEATHERLIB: Attempt to play when not paused")
        else
            if Game.stage.overlay then 
                if Game.stage.weather then
                    for i, o in ipairs(Game.stage.overlay) do
                        o.paused = false
                    end
                end
            end
            if Game.stage.weather then
                for i, weather in ipairs(Game.stage.weather) do
                    weather.pause = false
                    --weather.weathersounds.volume = weather.weathersounds.volume * 4
                    --weather.weathersounds.pitch = weather.weathersounds.pitch + 0.09
                end
            end
        end

        Game.stage.wpaused = false
        Game.stage.pause_reason = nil
    end)

    HookSystem.hook(Stage, "keepWeather", function(orig, self, keep)
        if keep == nil then keep = true end
        
        if keep then self.keep_weather = true else self.keep_weather = false end
    end)

    HookSystem.hook(Stage,  "addWeatherOverlays", function(orig, self)
        orig(self)

        local possible_overlays = {
            "chilly",
            "overcast",
            "dark_overcast",
            "hot",
            "clear",
            "cd",
        }

        local number = 0
        if not Game.stage.weather or #Game.stage.weather < 1 then return end

        for i, weather in ipairs(Game.stage.weather) do
            if weather.type == "clear" then number = 1 return end
        end
        if number == 0 then for i, weather in ipairs(Game.stage.weather) do
            local overlay = weather:addOverlay()
            table.insert(Game.stage.overlay, overlay)
        end end
    end)

    HookSystem.hook(Stage,  "getWeathers", function(orig, self, item)
        orig(self, item)
        if item == nil then item = "object" end
        
        local function valid(string)
            if string ~= "object" and string ~= "type" then return false else return true end
        end

        if type(item) ~= "string" or not valid(item) then error("WEATHERLIB: argument must be a valid string. arguments include:\n[color:red]\"object\", \"type\"") return end

        local tbl = {}
        for _, weather in ipairs(self.weather) do
            if item == "object" then table.insert(tbl, weather)
                elseif item == "type" then table.insert(tbl, weather.type) end
        end

        return tbl
    end)

    HookSystem.hook(Sprite, "drawAlpha", function(orig, self, alpha)
        local r,g,b,a = self:getDrawColor()
        a = alpha
        local function drawSprite(...)
            if self.crossfade_alpha > 0 and self.crossfade_texture ~= nil then
                Draw.setColor(r, g, b, self.crossfade_out and MathUtils.lerp(a, 0, self.crossfade_alpha) or alpha)
                Draw.draw(self.texture, ...)
    
                Draw.setColor(r, g, b, MathUtils.lerp(0, a, self.crossfade_alpha))
                Draw.draw(self.crossfade_texture, ...)
            else
                Draw.setColor(r, g, b, alpha)
                Draw.draw(self.texture, ...)
            end
        end
        if self.texture then
            if self.wrap_texture_x or self.wrap_texture_y then
                local screen_l, screen_u = love.graphics.inverseTransformPoint(0, 0)
                local screen_r, screen_d = love.graphics.inverseTransformPoint(SCREEN_WIDTH, SCREEN_HEIGHT)
    
                local x1, y1 = math.min(screen_l, screen_r), math.min(screen_u, screen_d)
                local x2, y2 = math.max(screen_l, screen_r), math.max(screen_u, screen_d)
    
                local x_offset = math.floor(x1 / self.texture:getWidth()) * self.texture:getWidth()
                local y_offset = math.floor(y1 / self.texture:getHeight()) * self.texture:getHeight()
    
                local wrap_width = math.ceil((x2 - x_offset) / self.texture:getWidth())
                local wrap_height = math.ceil((y2 - y_offset) / self.texture:getHeight())
    
                if self.wrap_texture_x and self.wrap_texture_y then
                    for i = 1, wrap_width do
                        for j = 1, wrap_height do
                            drawSprite(x_offset + (i-1) * self.texture:getWidth(), y_offset + (j-1) * self.texture:getHeight())
                        end
                    end
                elseif self.wrap_texture_x then
                    for i = 1, wrap_width do
                        drawSprite(x_offset + (i-1) * self.texture:getWidth(), 0)
                    end
                elseif self.wrap_texture_y then
                    for j = 1, wrap_height do
                        drawSprite(0, y_offset + (j-1) * self.texture:getHeight())
                    end
                end
            else
                drawSprite()
            end
        end
    
        Object.draw(self)
    end)

    HookSystem.hook(World, "setupMap", function(orig, self, map, ...)
        orig(self, map, ...)
        local weather = Game.stage.last_weather
        if (Game.stage.was_weather_inside == nil) then Game.stage.was_weather_inside = false end
        Game.stage.overlay = {}

        if self.map.inside or self.map.data.properties["inside"] then
            --Game.stage:pauseWeather("inside")
            Game.stage:setWeatherLayer(-10)
            fadeWeatherLeafSway(Game.stage, 0)
            if (not Game.stage.was_weather_inside) then
                for i, weather in ipairs(Game.stage.weather or {}) do
                    weather.weathersounds.volume = weather.weathersounds.volume / 8
                    weather.weathersounds.pitch = weather.weathersounds.pitch - 0.09
                end
                Game.stage.was_weather_inside = true
            end
            
        else
            if Game.stage.pause_reason == "inside" then Game.stage:playWeather() Game.stage.wpaused = false print("played") end
            fadeWeatherLeafSway(Game.stage, getWeatherLeafSwayTarget(Game.stage.weather))
            if (Game.stage.was_weather_inside) then
                Game.stage:resetWeatherLayer()
                Game.stage.was_weather_inside = false
                
                for i, weather in ipairs(Game.stage.weather) do
                    weather.weathersounds.volume = weather.weathersounds.volume * 8
                    weather.weathersounds.pitch = weather.weathersounds.pitch + 0.09
                end
            end
            
        end

        if not Game.stage.keep_weather then
            Game.stage:resetWeather()
        end
    end)

    HookSystem.hook(Object, "onAddToStage", function(orig, self, stage)
        orig(self)

        if Game.stage then
            local NONONO = {
                LightMenu,
                LightItemMenu,
                LightCellMenu,
                LightStatMenu,
                BattleUI,
                TensionBar,
                Textbox,
                DustPiece
            }

            local number = 0
            for i, cc in ipairs(NONONO) do
                if self:includes(cc) then
                    number = number + 1
                    break
                end
            end

            local yes = true
            if number ~= 0 then yes = false end

            local yes2 = false
            if Game.stage:hasWeather("volcanic") or Game.stage:hasWeather("hot") then yes2 = true end

            local yes3 = false
            if not self:getFX("wave_fx") then yes3 = true end

            if Game.stage and Game.stage.weather and yes and yes2 and yes3 then

                local wave_shader = love.graphics.newShader([[
                    extern number wave_sine;
                    extern number wave_mag;
                    extern number wave_height;
                    extern vec2 texsize;
                    vec4 effect( vec4 color, Image texture, vec2 texture_coords, vec2 screen_coords )
                    {
                        number i = texture_coords.x * texsize.x;
                        vec2 coords = vec2(max(0.0, min(1.0, texture_coords.x + 0.0)), max(0.0, min(1.0, texture_coords.y + (sin((i / wave_height) + (wave_sine / 30.0)) * wave_mag) / texsize.y)));
                        return Texel(texture, coords) * color;
                    }
                ]])
                
                local wave_fx = ShaderFX(wave_shader, {
                    ["wave_sine"] = function() return Kristal.getTime() * 50 end,
                    ["wave_mag"] = function () return 0.5 end,
                    ["wave_height"] = function () return 8 end,
                    ["texsize"] = {SCREEN_WIDTH, SCREEN_HEIGHT}
                }, false, 10)

                self:addFX(wave_fx, "wave_fx")
            end
        end
    end)
    
    HookSystem.hook(Battle, "postInit", function(orig, self, state, encounter)
        orig(self, state, encounter)

        if not self.encounter.background then if #Game.stage.weather > 0 then
            for i, w in ipairs(Game.stage.weather) do
                w.addto = self
            end
            Game.stage.addto = self
        end end
    end)

    HookSystem.hook(Battle, "onStateChange", function(orig, self, old, new)
        orig(self, old, new)

        if new == "TRANSITIONOUT" then
            if not self.encounter.background then if #Game.stage.weather > 0 then
                for i, w in ipairs(Game.stage.weather) do
                    w.addto = Game.world
                end end
                Game.stage.addto = self
            end
        end
    end)
end

function WeatherLib:postInit()
    -- local weather = Game:getFlag("weather_save")
    -- --print(weather, " (this is the weather)")
    -- if weather then
    --     Game.stage:setWeather(weather[1], weather[2], weather[3], Game.stage:getWeatherParent())
    -- end
end

------------------------------ function copies, added V1.1.0

function WeatherLib:setWeather(...)
    Game.stage:setWeather(...)
end

function WeatherLib:resetWeather(...)
    Game.stage:resetWeather(...)
end

function WeatherLib:keepWeather(...)
    Game.stage:keepWeather(...)
end

function WeatherLib:getWeathers(...)
    return Game.stage:getWeathers(...)
end

function WeatherLib:hasWeather(...)
    return Game.stage:hasWeather(...)
end

function WeatherLib:getWeatherParent(...)
    return Game.stage:getWeatherParent(...)
end

function WeatherLib:setWeatherParent(...)
    Game.stage:setWeatherParent(...)
end

function WeatherLib:setWeatherLayer(...)
    Game.stage:setWeatherLayer(...)
end

function WeatherLib:resetWeatherLayer(...)
    Game.stage:resetWeatherLayer(...)
end

function WeatherLib:getWeatherLayer(...)
    Game.stage:getWeatherLayer(...)
end

return WeatherLib
