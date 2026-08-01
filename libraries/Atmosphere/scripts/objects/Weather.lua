---@alias WeatherType
---| "clear"
---| "cloudy"
---| "overcast"
---| "dark_overcast"
---| "rain"
---| "thunder"
---| "snow"
---| "wind"
---| "chilly"
---| "fog"
---| "hot"
---| "volcanic"
---| "cd"
---| "flipped_rain"

---@class Weather : Object
---@field id string? Registry ID for this weather type.
---@field type WeatherType
---@field intensity number
---@field has_sfx boolean
---@field has_overlay boolean
---@field paused boolean
---@field ending boolean
---@field ambience Music
---@field palette_amount number Rain palette strength.
---@field palette_harshness number Rain palette harshness.
---@field wind_strength number
---@field wind_direction number
---@field overlay WeatherOverlay?
---@field addto Object?
---@field pieces Object[]
local Weather, super = Class(Object)

function Weather:init(intensity)
    super.init(self, 0, 0, 0, 0)
    self.parallax_x, self.parallax_y = 0, 0

    self.id = nil
    self.type = "clear"
    self.intensity = math.max(tonumber(intensity) or 1, 0)
    self.has_sfx = false
    self.has_overlay = false
    self.paused = false
    self.ending = false
    self.ambience = Music()
    self.palette_amount = 0
    self.palette_harshness = 0
    self.wind_strength = 0
    self.wind_direction = 0
    self.overlay = nil
    self.addto = nil
    self.pieces = {}
    self._inside = nil
end

---@return Object?
function Weather:getTarget()
    if Game.battle and Game.battle.stage then
        return Game.battle
    end
    return Game.world
end

---@return boolean
function Weather:isInside()
    local map = Game.world and Game.world.map
    if not map then return false end
    local properties = map.data and map.data.properties or {}
    return map.inside == true or properties.inside == true
end

---@return string?
function Weather:getAmbientTrack()
    return nil
end

---@return number
function Weather:getAmbientVolume()
    return self:isInside() and 0.35 or 1
end

---@return number
function Weather:getAmbientPitch()
    return self:isInside() and 0.91 or 1
end

function Weather:updateAmbientTrack(fade_out)
    if not self.has_sfx then return end
    self:transitionAmbientTrack(self:getAmbientTrack(), fade_out)
end

function Weather:onAdd(parent)
    super.onAdd(self, parent)
    self.addto = self:getTarget()
    self._inside = self:isInside()
    self:ensureOverlay()
    self:updateAmbientTrack(false)
end

function Weather:onRemove(parent)
    self.ambience:stop()
    if self.overlay and self.overlay.parent then
        self.overlay:remove()
    end
    self.overlay = nil

    for _, piece in ipairs(self.pieces) do
        if piece.parent then piece:remove() end
    end
    self.pieces = {}
    super.onRemove(self, parent)
end

---@param next string?
---@param fade_out boolean?
function Weather:transitionAmbientTrack(next, fade_out)
    local music = next
    local volume = self:getAmbientVolume()
    local pitch = self:getAmbientPitch()

    if type(next) == "table" then
        music = next[1]
        volume = next[2] or volume
        pitch = next[3] or pitch
    end

    if music and music ~= "" then
        if self.ambience.current ~= music then
            local play = function()
                self.ambience:stop()
                self.ambience:play(music, volume, pitch)
            end
            if self.ambience:isPlaying() and fade_out then
                self.ambience:fade(0, 10 / 30, play)
            else
                play()
            end
        elseif self.ambience:isPlaying() then
            self.ambience:setVolume(volume)
            self.ambience:setPitch(pitch)
        else
            self.ambience:play(music, volume, pitch)
        end
    elseif self.ambience:isPlaying() then
        if fade_out then
            self.ambience:fade(0, 10 / 30, function() self.ambience:stop() end)
        else
            self.ambience:stop()
        end
    end
end

function Weather:update()
    super.update(self)

    local target = self:getTarget()
    if target ~= self.addto then
        self.addto = target
        self:ensureOverlay()
    elseif self.has_overlay then
        self:ensureOverlay()
    end

    local inside = self:isInside()
    if inside ~= self._inside then
        self._inside = inside
        self:updateAmbientTrack(true)
        if Atmosphere.active_weather == self then
            Atmosphere:refreshRainPalette(self)
        end
    end

    for i = #self.pieces, 1, -1 do
        if self.pieces[i]:isRemoved() then
            table.remove(self.pieces, i)
        end
    end
end

---@param piece Object
---@return Object
function Weather:addPiece(piece)
    local target = self.addto or self:getTarget()
    if target then
        target:addChild(piece)
        table.insert(self.pieces, piece)
    end
    return piece
end

---@return WeatherOverlay?
function Weather:createOverlay()
    local target = self.addto or self:getTarget()
    return target and target:addChild(WeatherOverlay(self)) or nil
end

function Weather:ensureOverlay()
    if not self.has_overlay then return end

    local target = self.addto or self:getTarget()
    if not target then return end

    if not self.overlay or self.overlay:isRemoved() then
        self.overlay = self:createOverlay()
    elseif self.overlay.parent ~= target then
        self.overlay:setParent(target)
    end
end

---@param overlay WeatherOverlay
function Weather:drawOverlay(overlay)
end

---@param paused boolean
function Weather:setPaused(paused)
    self.paused = paused == true
    if self.overlay then self.overlay.paused = self.paused end
end

function Weather:onEnd(instant)
    if self.ending then return end
    self.ending = true

    if instant or not Game.stage then
        self:remove()
        return
    end

    if self.ambience:isPlaying() then
        self.ambience:fade(0, 0.4, function() self.ambience:stop() end)
    end

    if self.overlay then
        Game.stage.timer:tween(0.4, self.overlay, {alpha = 0}, "out-sine")
    end
    Game.stage.timer:after(0.4, function()
        if self.parent then self:remove() end
    end)
end

return Weather
