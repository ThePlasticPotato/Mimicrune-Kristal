---@class maps.wastes_vessel : Map
local map, super = Class(Map)

local VESSEL_EVENT_ID = 123
local VESSEL_NOTE_INTERVAL = 2.5
local VESSEL_VOICE_MAX_VOLUME = 0.65
local VESSEL_VOICE_AUDIBLE_DISTANCE = 400

local CAPTURE_MARKERS = {
    kindness = "grab_range",
    mind = "snatch_range",
    ambition = "lunge_range",
    bravery = "grab_range",
    voice = "snatch_range"
}

function map:init(world, data)
    super.init(self, world, data)
    self.vessel_intro_state = "inactive"
    self.vessel_intro_gift = nil
    self.vessel_voice_source = nil
    self.vessel_voice_notes = false
    self.vessel_note_timer = 0
    self.vessel_note_variant = 1
end

---@param subject Object
---@param marker_name string
---@return boolean
function map:isSubjectInMarker(subject, marker_name)
    local marker = self.markers[marker_name]
    if not subject or not marker then return false end

    local x, y = subject.x, subject.y
    local inside = x >= marker.x and x <= marker.x + marker.width
        and y >= marker.y and y <= marker.y + marker.height
    if not inside then return false end

    local vessel = self:getEvent(VESSEL_EVENT_ID)
    if not vessel or math.abs((subject.z or 0) - (vessel.z or 0)) > 0.001 then
        return false
    end
    return subject.height_state == nil
        or subject.height_state == "GROUNDED"
        or subject.height_state == "LAND"
end

function map:beginVesselVoice(vessel)
    self:stopVesselVoice()
    self.vessel_voice_notes = true
    self.vessel_note_timer = 0
    self.vessel_note_variant = 1
    self.vessel_voice_source = Assets.newSound("audio_call")
    self.vessel_voice_source:setLooping(true)
    self.vessel_voice_source:setVolume(0)
    self.vessel_voice_source:play()
    self:updateVesselVoiceVolume(vessel)
end

function map:stopVesselVoice()
    self.vessel_voice_notes = false
    if self.vessel_voice_source then
        self.vessel_voice_source:stop()
        self.vessel_voice_source:setVolume(0)
        self.vessel_voice_source = nil
    end
end

---@param vessel? Object
function map:updateVesselVoiceVolume(vessel)
    if not self.vessel_voice_source then return end

    vessel = vessel or self:getEvent(VESSEL_EVENT_ID)
    local listener = self.world and (self.world.world_soul or self.world.player)
    if not vessel or not listener then
        self.vessel_voice_source:setVolume(0)
        return
    end

    local distance = MathUtils.dist(vessel.x, vessel.y, listener.x, listener.y)
    local proximity = MathUtils.clamp(
        1 - distance / VESSEL_VOICE_AUDIBLE_DISTANCE, 0, 1
    )
    self.vessel_voice_source:setVolume(proximity * VESSEL_VOICE_MAX_VOLUME)
end

function map:spawnVesselNote()
    local vessel = self:getEvent(VESSEL_EVENT_ID)
    if not vessel or vessel.parent == nil then return end

    local soul = self.world.world_soul
    local vessel_distance = soul and MathUtils.dist(
        vessel.x, vessel.y, soul.x, soul.y
    ) or 0
    local note = VesselLureNote(
        self.vessel_note_variant,
        vessel.x,
        vessel.y - vessel.height - 32,
        soul,
        vessel_distance
    )
    note.z = vessel.z or 0
    note.surface_id = vessel.surface_id
    note.height_sort_subject = true
    note.height_depth_subject = true
    note.layer = WORLD_LAYERS["above_events"]
    note.height_depth_layer = note.layer
    self.world:addChild(note)

    self.vessel_note_variant = self.vessel_note_variant % 3 + 1
end

function map:onEnter()
    local vessel = self:getEvent(VESSEL_EVENT_ID)
    if Game:getFlag("plot", PLOT.intro_boot) >= PLOT.intro_vessel then
        self.vessel_intro_state = "complete"
        if vessel then vessel:remove() end
        return
    end

    if not vessel or not self.world.world_soul then return end
    local _, gift_name = Mod:resolveVesselGift()
    self.vessel_intro_gift = gift_name
    self.vessel_intro_state = "waiting_spot"
end

function map:onExit()
    self:stopVesselVoice()
end

function map:update()
    super.update(self)

    self:updateVesselVoiceVolume()

    if self.vessel_voice_notes then
        self.vessel_note_timer = self.vessel_note_timer + DT
        if self.vessel_note_timer >= VESSEL_NOTE_INTERVAL then
            self.vessel_note_timer = self.vessel_note_timer
                - VESSEL_NOTE_INTERVAL
            self:spawnVesselNote()
        end
    end

    if self.world:hasCutscene() then return end
    local soul = self.world.world_soul
    if not soul or not soul.is_active then return end

    if self.vessel_intro_state == "waiting_spot"
        and self:isSubjectInMarker(soul, "spot_range") then
        self.vessel_intro_state = "spotting"
        local spotting = self.world:startCutscene(
            "wastes_vessel", "spot",
            self, self:getEvent(VESSEL_EVENT_ID), soul, self.vessel_intro_gift
        )
        if spotting then spotting:enableMovement() end
    elseif self.vessel_intro_state == "waiting_capture" then
        local marker = CAPTURE_MARKERS[self.vessel_intro_gift]
        if marker and self:isSubjectInMarker(soul, marker) then
            self.vessel_intro_state = "capturing"
            self.world:startCutscene(
                "wastes_vessel", "capture",
                self, self:getEvent(VESSEL_EVENT_ID), soul, self.vessel_intro_gift
            )
        end
    end
end

return map
