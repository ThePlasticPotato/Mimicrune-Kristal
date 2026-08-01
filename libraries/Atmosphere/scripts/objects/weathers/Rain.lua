---@class Rain : Weather
---@field ambient_tracks string[]
---@field has_thunder boolean
---@field spawn_accumulator number
---@field thunder_timer number
---@field max_drops number
local Rain, super = Class("Weather")

function Rain:init(intensity, wind_strength, wind_direction, palette_amount, palette_harshness, has_thunder)
    super.init(self, intensity)
    self.type = "rain"
    self.wind_strength = wind_strength or 0
    self.wind_direction = wind_direction or 0
    self.has_overlay = true
    self.has_sfx = true
    self.palette_amount = palette_amount == nil and MathUtils.clamp(self.intensity, 0, 1) or palette_amount
    self.palette_harshness = palette_harshness or 0
    self.has_thunder = has_thunder == true
    self.spawn_accumulator = 0
    self.thunder_timer = MathUtils.random(6, 12)
    self.max_drops = 180
    self.ambient_tracks = {"drizzle", "rain", "downpour"}
end

---@return string
function Rain:getAmbientTrack()
    local index = MathUtils.clamp(math.ceil(self.intensity), 1, #self.ambient_tracks)
    return "rainfall/" .. (self:isInside() and "inside/" or "") .. self.ambient_tracks[index]
end

function Rain:getDropSpritePath()
    return "world/rain/"
end

---@return string[]
function Rain:getRainSprites()
    return {"three", "five", "six", "nine", "nine_alt"}
end

---@param number string
---@param x number
---@param y number
---@param speed number
---@return RainDrop
function Rain:createRainDrop(number, x, y, speed)
    return RainDrop(number, x, y, speed, self, self:getDropSpritePath())
end

---@param section number?
---@param speed number?
function Rain:spawnRainSection(section, speed)
    local target = self.addto or self:getTarget()
    if not target then return end

    local section_count = 6
    section = section or math.random(1, section_count)
    local section_width = SCREEN_WIDTH / section_count
    local screen_x = MathUtils.random(section_width * (section - 1), section_width * section)
    local screen_y = MathUtils.random(-48, -8)
    local x, y = self:getRelativePos(screen_x, screen_y, target)
    local number = TableUtils.pick(self:getRainSprites())
    self:addPiece(self:createRainDrop(number, x, y, speed or (20 * math.max(self.intensity, 0.25))))
end

function Rain:triggerThunder()
    local target = self.addto or self:getTarget()
    if not target then return end

    self:addPiece(ThunderFlash(self))
    Game.stage.timer:after(0.12, function()
        if not self.ending and self.parent then
            self:addPiece(ThunderFlash(self))
        end
    end)
    Game.stage.timer:after(MathUtils.random(0.25, 0.55), function()
        if not self.ending and self.parent and self.has_sfx then
            local sound = MathUtils.random() < 0.35 and "thunder/close" or "thunder/distant"
            Assets.stopAndPlaySound(sound, self:isInside() and 0.2 or 0.8, self:isInside() and 0.8 or 1)
        end
    end)
end

function Rain:update()
    super.update(self)
    if self.paused or self.ending then return end

    local rate = 24 + (math.max(self.intensity, 0) * 22)
    if self.has_thunder then rate = rate * 1.2 end
    self.spawn_accumulator = self.spawn_accumulator + DT * rate

    local spawned = 0
    while self.spawn_accumulator >= 1 and #self.pieces < self.max_drops and spawned < 8 do
        self.spawn_accumulator = self.spawn_accumulator - 1
        self:spawnRainSection(nil, 20 * math.max(self.intensity + (self.has_thunder and 0.5 or 0), 0.25))
        spawned = spawned + 1
    end

    if self.has_thunder then
        self.thunder_timer = self.thunder_timer - DT
        if self.thunder_timer <= 0 then
            self:triggerThunder()
            self.thunder_timer = MathUtils.random(math.max(3, 9 - self.intensity), math.max(5, 14 - self.intensity))
        end
    end
end

function Rain:drawOverlay(overlay)
    if self.intensity > 2 or self.has_thunder then
        overlay:drawDarkRainTint()
    else
        overlay:drawRainTint()
    end
end

return Rain
