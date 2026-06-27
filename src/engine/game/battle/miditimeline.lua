-- midi_timeline.lua (we love vibecoded slop!!)
local MidiTimeline = Class()
local function durationToBeats(d)
  -- LuaMidi durations: "1","2","d2","4","8","8t","16", or "Tn" (explicit ticks) :contentReference[oaicite:6]{index=6}
  if d == nil then return 1 end -- default-ish: quarter note

  if type(d) == "table" then
    local sum = 0
    for i = 1, #d do sum = sum + durationToBeats(d[i]) end
    return sum
  end

  d = tostring(d)

  -- explicit ticks: Tn (we can't convert ticks->seconds without PPQ, so we treat it as 0 beats here)
  -- If your MIDI uses Tn a lot, tell me and I’ll show you a robust ticks-based conversion.
  if d:sub(1,1) == "T" then
    return 0
  end

  local dotted = false
  if d:sub(1,1) == "d" then
    dotted = true
    d = d:sub(2)
  end

  local triplet = false
  if d:sub(-1) == "t" then
    triplet = true
    d = d:sub(1, #d-1)
  end

  local denom = tonumber(d)
  if not denom or denom == 0 then return 0 end

  -- "4" = quarter note = 1 beat
  local beats = 4 / denom

  if dotted then beats = beats * 1.5 end
  if triplet then beats = beats * (2/3) end  -- e.g. eighth triplet: 0.5 * 2/3 = 1/3 beat

  return beats
end

local function ensureRealPath(lovePath)
  -- If LOVE can give you a real directory, use it.
  local realDir = love.filesystem.getRealDirectory(lovePath)
  if realDir then
    return realDir .. "/" .. lovePath
  end

  -- Otherwise, copy from LOVE's virtual FS into the save dir so io.open can see it.
  local data = assert(love.filesystem.read(lovePath))
  local outName = "midi_cache/" .. lovePath:gsub("[/\\]", "_")
  love.filesystem.createDirectory("midi_cache")
  assert(love.filesystem.write(outName, data))

  return love.filesystem.getSaveDirectory() .. "/" .. outName
end

local function getPPQFromPath(path)
  local bytes = assert(love.filesystem.read(path))
  if bytes:sub(1,4) ~= "MThd" then return 480 end
  local d1, d2 = bytes:byte(13, 14)
  local division = d1 * 256 + d2
  if division >= 0x8000 then return 480 end -- ignore SMPTE
  return division
end

local function getBpmFromTracks(tracks, fallback)
  fallback = fallback or 120
  for _, tr in ipairs(tracks) do
    local s = tr.get_tempo and tr:get_tempo()
    if type(s) == "number" then return s end
    if type(s) == "string" then
      local bpm = tonumber(s:match("(%d+)bpm"))
      if bpm then return bpm end
      local us = tonumber(s:match("^(%d+)%s*ms"))
      if us and us > 0 then return 60000000 / us end
    end
  end
  return fallback
end

function MidiTimeline:loadMidiTimeline(loveMidiPath, trackIndex)
  local tracks = LuaMidi.get_MIDI_tracks(loveMidiPath)
  assert(tracks and #tracks > 0, "No tracks found in MIDI")

  local track = tracks[trackIndex or 1]
  assert(track, "Track index out of range")

  local ppq = getPPQFromPath(loveMidiPath)
  local bpm = getBpmFromTracks(tracks, 120)
  local secPerTick = (60 / bpm) / ppq

  local timeline = {}
  local active = {}   -- active[ch][pitch] = {t=..., vel=...}
  local tTick = 0

  for _, ev in ipairs(track.events or {}) do
    -- Your parser's `timestamp` is a delta-time in ticks
    tTick = tTick + (ev.timestamp or 0)

    -- Identify note on/off events (metatable set in your parser)
    local mt = getmetatable(ev)
    local isOn  = mt and mt.__index == LuaMidi.NoteOnEvent
    local isOff = mt and mt.__index == LuaMidi.NoteOffEvent

    local ch = ev.channel or 1
    local pitch = ev.pitch
    local vel = ev.velocity or 0

    -- Treat NoteOn vel==0 as NoteOff (standard MIDI convention)
    if isOn and vel == 0 then isOn, isOff = false, true end

    if isOn and pitch then
      active[ch] = active[ch] or {}
      active[ch][pitch] = { tick = tTick, vel = vel }

    elseif isOff and pitch and active[ch] and active[ch][pitch] then
      local a = active[ch][pitch]
      local durTick = tTick - a.tick

      timeline[#timeline+1] = {
        t = a.tick * secPerTick,
        dur = durTick * secPerTick,
        pitch = pitch,
        vel = a.vel,
        ch = ch,
      }

      active[ch][pitch] = nil
    end
  end

  table.sort(timeline, function(a,b) return a.t < b.t end)
  return timeline, bpm
end

return MidiTimeline