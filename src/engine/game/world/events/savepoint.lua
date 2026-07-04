--- Savepoints allow the player to SAVE their game. \
--- `Savepoint` is an [`Event`](lua://Event.init) - naming an object `savepoint` on an `objects` layer in a map creates this object. \
--- See this object's Fields for the configurable properties on this object. The location displayed on the savefile is determined by the map's `name` property.
---
---@class Savepoint : Interactable
---
---@field marker        string  *[Property `marker`]* The name of the marker that the party should spawn at when a save from here is loaded
---@field simple_menu   boolean *[Property `simple`]* Whether this Savepoint uses the Simple (one slot, no storage/recruits) save menu
---@field text_once     boolean *[Prpoerty `text_once`]* Whether this Savepoint doesn't display its text on repeat interactions (Defaults to `false`)
---@field heals         boolean *[Property `heals`]* Whether this Savepoint heals the party when interacted with (Defaults to `true`)
---
---@field solid         boolean
---
---@field used          boolean
---
---@overload fun(...) : Savepoint
local Savepoint, super = Class(Interactable)

local SAVEPOINT_SPRITE = "world/events/savepoint"
local SAVEPOINT_EMPTY_SPRITE = "world/events/savepoint_blank"
local CLOCK_ANIMATION_SPEED = 1
local CLOCK_TICK_MAX_VOLUME = 0.5
local CLOCK_TICK_AUDIBLE_DISTANCE = 200

function Savepoint:init(x, y, properties)
    super.init(self, x, y, nil, properties)

    properties = properties or {}

    self.marker = properties["marker"]
    self.simple_menu = properties["simple"]
    self.text_once = properties["text_once"]
    self.heals = properties["heals"]

    if self.heals == nil then
        -- Default to true for the dark world and false for the light world.
        self.heals = not Game:isLight()
    end

    self.solid = true

    self:setOrigin(0.5, 0.5)
    self:setSprite(SAVEPOINT_SPRITE, CLOCK_ANIMATION_SPEED)

    self.used = false
    self.activated = false
    self.interacting = false
    self.clock_animating = true

    self.tick_sound = Assets.newSound("clocktick")
    self.tick_sound:setLooping(true)
    self.tick_sound:setVolume(0)

    self.outline_siner = 0

    -- The hitbox is ALMOST half the size of the sprite, but not quite.
    -- It's 9 pixels tall, 10 pixels away from the top.
    -- So divide by 2, round, then multiply by 2 to get the right size for 2x.
    local width, height = self:getSize()
    self:setHitbox(0, math.ceil(height / 4) * 2, width, math.floor(height / 4) * 2)

    self:setEmptySprite()
end

function Savepoint:onAdd(parent)
    super.onAdd(self, parent)

    self.activated = self:getFlag("activated", false)
    if self.activated then
        self:startClock(true)
    else
        self:setEmptySprite()
        self:stopClock()
    end
end

function Savepoint:onRemove(parent)
    self:stopClock()
    super.onRemove(self, parent)
end

function Savepoint:setEmptySprite()
    self:setSprite(SAVEPOINT_EMPTY_SPRITE, nil, false)
    self.clock_animating = false
    local outline_color = {1, 1, 1, 0.5}
    local fx = OutlineFX(outline_color)
    self.sprite:addFX(fx, "inactive_glow")
    Game.world.timer:doWhile(function() return not self.activated end, function()
        outline_color = {1, 1, 1, 0.5 + (math.sin(self.outline_siner)/2)}
        fx:setColor(TableUtils.unpack(outline_color))
    end,
    function() self.sprite:removeFX("inactive_glow") end)
end

function Savepoint:startClock(sync)
    if sync or not self.clock_animating then
        self:setSprite(SAVEPOINT_SPRITE, CLOCK_ANIMATION_SPEED, false)
        self.clock_animating = true
    end

    if sync or not self.tick_sound:isPlaying() then
        self.tick_sound:stop()
        self.tick_sound:seek(0)
        self.tick_sound:play()
    end
    self:updateTickVolume()
end

function Savepoint:stopClock()
    self.tick_sound:stop()
    self.tick_sound:setVolume(0)
end

function Savepoint:setInteracting(interacting)
    self.interacting = interacting
    self:updateTickVolume()
end

function Savepoint:updateTickVolume()
    if not self.activated then
        self.tick_sound:setVolume(0)
        return
    end

    if self.interacting then
        self.tick_sound:setVolume(CLOCK_TICK_MAX_VOLUME)
        return
    end

    local player = self.world and self.world.player or Game.world and Game.world.player
    if not player then
        self.tick_sound:setVolume(0)
        return
    end

    local dist = MathUtils.dist(self.x, self.y, player.x, player.y)
    local volume = MathUtils.clamp(1 - (dist / CLOCK_TICK_AUDIBLE_DISTANCE), 0, 1) * CLOCK_TICK_MAX_VOLUME
    self.tick_sound:setVolume(volume)
end

function Savepoint:onInteract(player, dir)
    if not self.activated then
        self.activated = true
        self:setFlag("activated", true)
        self:startClock(true)
    else
        self:startClock(false)
    end
    self:setInteracting(true)

    if self.text_once and self.used then
        self:onTextEnd()
        return
    end

    if self.text_once then
        self.used = true
    end

    super.onInteract(self, player, dir)
    return true
end

function Savepoint:onTextEnd()
    if not self.world then
        self:setInteracting(false)
        return
    end

    if self.heals then
        for _, party in pairs(Game.party_data) do
            party:heal(math.huge, false)
        end
    end

    if Game:isLight() then
        self.world:openMenu(LightSaveMenu(self.marker, self))
    elseif self.simple_menu or (self.simple_menu == nil and Game:getConfig("smallSaveMenu")) then
        self.world:openMenu(SimpleSaveMenu(Game.save_id, self.marker, self))
    else
        self.world:openMenu(SaveMenu(self.marker, self))
    end
end

function Savepoint:update()
    super.update(self)

    if Game:isLight() then
        self.sprite.alpha = 0.5

        if Game.world.player then
            local dist = MathUtils.dist(self.x, self.y, Game.world.player.x, Game.world.player.y)


            if dist <= 80 then
                self.sprite.alpha = math.min(1, ((1 - (dist / 80)) + 0.5))
            end
        end
    end

    if self.activated then
        if not self.tick_sound:isPlaying() then
            self:startClock(true)
        else
            self:updateTickVolume()
        end
    else
        self.outline_siner = self.outline_siner + DT
    end

end

function Savepoint:getDebugInfo()
    local info = super.getDebugInfo(self)
    table.insert(info, "Activated: " .. (self.activated and "True" or "False"))
    table.insert(info, "Interacting: " .. (self.interacting and "True" or "False"))
    if Game:isLight() and Game.world.player then
        table.insert(info, "Player Distance: " .. MathUtils.dist(self.x, self.y, Game.world.player.x, Game.world.player.y))
        table.insert(info, "Alpha: " .. self.sprite.alpha)
    end
    return info
end

return Savepoint
