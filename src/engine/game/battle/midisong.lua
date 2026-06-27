local midi = require("src.lib.midi")

local MidiSong = Class()

function MidiSong:loadMidiEvents(path, opts)
  opts = opts or {}
  local trackToRead = opts.track or 1

  -- LOVE file stream works because lua-midi only needs :read(n) and :seek(...)
  local f = love.filesystem.newFile(path)
  assert(f:open("r")) -- LÖVE reads bytes; no newline translation

  local events = {}

  local division = nil           -- ticks per quarter note
  local tempoBPM = 120           -- default MIDI tempo assumption :contentReference[oaicite:6]{index=6}
  local tSeconds = 0

  local function cb(event, ...)
    if event == "header" then
      local format, tracks, div = ...
      division = div
    elseif event == "setTempo" then
      tempoBPM = ...
    elseif event == "deltatime" then
      local ticks = ...
      -- convert delta ticks to delta seconds (using current tempo)
      -- secondsPerTick = (60 / tempoBPM) / division
      tSeconds = tSeconds + (ticks / division) * (60 / tempoBPM)
    elseif event == "noteOn" then
      local channel, key, vel = ...
      -- Important MIDI quirk: noteOn with velocity 0 is often used as noteOff. :contentReference[oaicite:7]{index=7}
      local typ = (vel == 0) and "noteOff" or "noteOn"
      events[#events+1] = { t = tSeconds, type = typ, ch = channel, key = key, vel = vel }
    elseif event == "noteOff" then
      local channel, key, vel = ...
      events[#events+1] = { t = tSeconds, type = "noteOff", ch = channel, key = key, vel = vel }
    end
  end

  midi.processTrack(f, cb, trackToRead) -- the library supports reading one track :contentReference[oaicite:8]{index=8}
  f:close()

  table.sort(events, function(a,b) return a.t < b.t end)
  return events
end

return MidiSong