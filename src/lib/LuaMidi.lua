-------------------------------------------------
-- LuaMidi library main module
-- <p>All other modules are available through it.
-- It also presents useful functions to handle
-- MIDI files.
-- 
-- @module LuaMidi
-- @author Pedro Alves Valentim
-- @license MIT
-------------------------------------------------

local LuaMidi = {}

LuaMidi.Util = require 'src.lib.LuaMidi.Util'
LuaMidi.Chunk = require 'src.lib.LuaMidi.Chunk'
LuaMidi.Track = require 'src.lib.LuaMidi.Track'
LuaMidi.Writer = require 'src.lib.LuaMidi.Writer'
LuaMidi.Constants = require 'src.lib.LuaMidi.Constants'
LuaMidi.MetaEvent = require 'src.lib.LuaMidi.MetaEvent'
LuaMidi.NoteEvent = require 'src.lib.LuaMidi.NoteEvent'
LuaMidi.NoteOnEvent = require 'src.lib.LuaMidi.NoteOnEvent'
LuaMidi.NoteOffEvent = require 'src.lib.LuaMidi.NoteOffEvent'
LuaMidi.ArbitraryEvent = require 'src.lib.LuaMidi.ArbitraryEvent'
LuaMidi.ProgramChangeEvent = require 'src.lib.LuaMidi.ProgramChangeEvent'

-------------------------------------------------
--- Functions
-- @section functions
-------------------------------------------------

local function open_file(path)
   local file = love.filesystem.newFile(path, "r")
   return file
end

-------------------------------------------------
-- Reads all tracks from a MIDI file and convert
-- them to LuaMidi's Track objects.
--
-- @string path the MIDI file path
--
-- @return an array of the tracks
--
-- @see Track
-------------------------------------------------
function LuaMidi.get_MIDI_tracks_fucked(path)
   local MIDI = love.filesystem.newFile(path)
   --Kristal.Console:log(path)
   --Kristal.Console:log(sizeerror)
   --Kristal.Console:log(MIDI)
   if MIDI then
      local bytes = assert(love.filesystem.read(path), "Failed to read MIDI: " .. path)
      local buffer = { bytes:byte(1, #bytes) }

      local function isMTrk(i)
      return buffer[i] == 0x4D and buffer[i+1] == 0x54
         and buffer[i+2] == 0x72 and buffer[i+3] == 0x6B
      end

      local function u32be(i)
      return buffer[i] * 16777216
            + buffer[i+1] * 65536
            + buffer[i+2] * 256
            + buffer[i+3]
      end

      local track_list = {}
      local i = 1

      while i <= #buffer - 8 do
         if isMTrk(i) then
            local len = u32be(i + 4)
            local start = i + 8
            local finish = start + len - 1
            local raw_track = {}

            for j = start, finish do
               raw_track[#raw_track+1] = buffer[j]
            end

            track_list[#track_list+1] = raw_track
            i = finish + 1
         else
            i = i + 1
         end
      end

      function sum_timestamp(timestamp)
         local total = 0
         for i=1, #timestamp-1 do
            total = total + ((timestamp[i]-128) * (2 ^ (7*(#timestamp-i))))
         end
         total = total + timestamp[#timestamp]
         return total
      end

      local function read_vlq(arr, idx)
         local value = 0
         local b
         repeat
            b = arr[idx]
            value = value * 128 + (b % 128)
            idx = idx + 1
         until b < 128
         return value, idx
      end

      local band = LuaMidi.Util.bitwise.band
      
      local EVENTS = {}
      EVENTS[0x80] = function(bytes, current_timestamp)
         local event = LuaMidi.NoteOffEvent.new({
            channel = band(bytes[1], 0x0F) + 1,
            pitch = bytes[2],
            velocity = LuaMidi.Util.revert_velocity(bytes[3]),
            timestamp = sum_timestamp(current_timestamp),
         })
         return event
      end
      EVENTS[0x90] = function(bytes, current_timestamp)
         local event = LuaMidi.NoteOnEvent.new({
            channel = band(bytes[1], 0x0F) + 1,
            pitch = bytes[2],
            velocity = LuaMidi.Util.revert_velocity(bytes[3]),
            timestamp = sum_timestamp(current_timestamp),
         })
         return event
      end
      EVENTS[0xA0] = function() end
      EVENTS[0xB0] = function() end
      EVENTS[0xC0] = function() end
      EVENTS[0xD0] = function() end
      EVENTS[0xE0] = function() end
      
      for track_number, raw_track in ipairs(track_list) do
         local track = {
            type = {raw_track[1], raw_track[2], raw_track[3], raw_track[4]},
            events = {},
            metadata = {},
            size = {},
            data = {},
         }
         --for i=1, 8 do table.remove(raw_track,1) end
         
         local metadata_types = LuaMidi.Constants.METADATA_TYPES
         
         local current_timestamp = {}
         local is_timestamp = true
         
         local function next_timestamp(i, bytes_to_skip)
            current_timestamp = {}
            is_timestamp = true
            return i + bytes_to_skip
         end
         
         local last_control_byte = nil
         
         local i=1
         while i <= #raw_track do
         
            while is_timestamp do
               current_timestamp[#current_timestamp+1] = raw_track[i]
               if raw_track[i] < 0x80 then
                  is_timestamp = false
               end
               i = i + 1
            end
            
            -- TODO fix
            if raw_track[i] == 0xFF then -- METADATA
            local metaType = raw_track[i+1]

            -- length is VLQ starting at i+2
            local data_length, data_start = read_vlq(raw_track, i + 2)
            local data_end = data_start + data_length - 1

            -- collect raw bytes for the meta event (optional, but keep consistent)
            local raw_metadata = {}
            raw_metadata[#raw_metadata+1] = 0xFF
            raw_metadata[#raw_metadata+1] = metaType
            -- store the VLQ length bytes too (reconstruct them from the source)
            for j = i+2, data_start-1 do
               raw_metadata[#raw_metadata+1] = raw_track[j]
            end
            for j = data_start, data_end do
               raw_metadata[#raw_metadata+1] = raw_track[j]
            end

            local converted_data = nil
            if metaType < 0x08 then
               -- text-ish meta types: sequence name, copyright, track name, etc.
               local s = {}
               for j = data_start, data_end do
                  s[#s+1] = string.char(raw_track[j])
               end
               converted_data = table.concat(s)

            elseif metaType == LuaMidi.Constants.META_TEMPO_ID then
               if data_length >= 3 then
                  local ms = LuaMidi.Util.number_from_bytes({ raw_track[data_start], raw_track[data_start+1], raw_track[data_start+2] })
                  local bpm = LuaMidi.Util.round(60000000 / ms)
                  converted_data = tostring(ms) .. " ms (" .. bpm .. "bpm)"
               end

            elseif metaType == LuaMidi.Constants.META_TIME_SIGNATURE_ID then
               if data_length >= 2 then
                  converted_data = tostring(raw_track[data_start]) .. "/" .. tostring(2 ^ raw_track[data_start+1])
               end

            elseif metaType == LuaMidi.Constants.META_KEY_SIGNATURE_ID then
               if data_length >= 2 then
                  local majmin = { "major", "minor" }
                  local keys = {{'C','A'},{'G','E'},{'D','B'},{'A','F#'},
                              {'E','C#'},{'B','G#'},{'F#','D#'},{'C#','A#'}}

                  local sharps = raw_track[data_start]
                  local mode = raw_track[data_start+1] + 1
                  -- sharps might be signed in spec; this old code assumes 0..7 sharps
                  local sharps_num = tostring(sharps)
                  converted_data = sharps_num .. "#"
                  if sharps >= 0 and sharps <= 7 and keys[sharps+1] then
                  converted_data = converted_data .. " (" .. keys[sharps+1][mode] .. " " .. majmin[mode] .. ")"
                  end
               end
            end

            local subtype = (LuaMidi.Constants.METADATA_TYPES or {})[metaType] or ("meta_" .. string.format("%02X", metaType))
            if converted_data ~= nil then
               track.metadata[subtype] = converted_data
            end

            local event = {
               type = 'meta',
               subtype = subtype,
               data = raw_metadata,
               timestamp = sum_timestamp(current_timestamp),
            }
            event = setmetatable(event, { __index = LuaMidi.MetaEvent })
            track.events[#track.events+1] = event

            -- move i to the byte just before the next delta-time begins
            i = next_timestamp(i, (data_start - (i + 2)) + data_length + 1)
               
            -- must test this later:
            elseif raw_track[i] < 0x80 and raw_track[i+1] == LuaMidi.Constants.PROGRAM_CHANGE_STATUS then
            
               last_control_byte = LuaMidi.Constants.PROGRAM_CHANGE_STATUS
               
               local event = {
                  type = 'program-change',
                  data = { raw_track[i], raw_track[i+1], raw_track[i+2] },
                  timestamp = sum_timestamp(current_timestamp),
               }
               event = setmetatable(event, { __index = LuaMidi.ProgramChangeEvent })
               track.events[#track.events+1] = EVENTS[LuaMidi.Constants.PROGRAM_CHANGE_STATUS]()
               current_timestamp = {}
               is_timestamp = true
               
            elseif band(raw_track[i], 0xF0) == 0x90 then -- NOTE ON
            
               last_control_byte = 0x90
            
               local channel = raw_track[i]-0x8F
               local pitch = { raw_track[i+1] }
               local pitch_code = raw_track[i+1]
               local velocity = raw_track[i+2]
               
               local event = LuaMidi.NoteOnEvent.new({
                  channel = channel,
                  pitch = pitch_code,
                  velocity = LuaMidi.Util.round(velocity / 127 * 100),
                  timestamp = sum_timestamp(current_timestamp),
               })

               track.events[#track.events+1] = event
               i = next_timestamp(i, 2)
            
            elseif band(raw_track[i], 0xF0) == 0x80 then -- NOTE OFF
                                             
               last_control_byte = 0x80
                                             
               local event = LuaMidi.NoteOffEvent.new({
                  channel = band(raw_track[i], 0x0F) + 1,
                  pitch = raw_track[i+1],
                  velocity = LuaMidi.Util.round(raw_track[i+2] / 127 * 100),
                  timestamp = sum_timestamp(current_timestamp),
               })
               
               track.events[#track.events+1] = event
               i = next_timestamp(i, 2)
               
            elseif raw_track[i] < 0x80 then -- RUNNING STATUS
              assert(type(last_control_byte) == "number", "Running status with no prior status byte")
               local event = EVENTS[band(last_control_byte, 0xF0)]({
                  last_control_byte,
                  raw_track[i],
                  raw_track[i+1],
               }, current_timestamp)
               track.events[#track.events+1] = event
               i = next_timestamp(i, 1)
            
            end
            
            i = i + 1
         
         end
         
         track = setmetatable(track, { __index = LuaMidi.Track })
         track_list[track_number] = track
      end
      return track_list
   end 
   return false
end

--original
function LuaMidi.get_MIDI_tracks(path)
   local MIDI= love.filesystem.newFile(path)
   if MIDI then
      local buffer = {}
      local bytes = love.filesystem.read(path)
      for i=1, #bytes do
         buffer[#buffer+1] = string.byte(bytes:sub(i,i))
      end
      --MIDI:close()
      local append = false
      local track_list = {}
      local track_number = 0
      for i=1, #buffer do
         if LuaMidi.Util.is_track_header({buffer[i], buffer[i+1], buffer[i+2], buffer[i+3]}) then
            append = true
            track_number = track_number + 1
            track_list[track_number] = {}
         end
         if buffer[i] == 0x00 and
            buffer[i+1] == 0xFF and
            buffer[i+2] == 0x2F and
            buffer[i+3] == 0x00 then
            append = false
         end
         if append then
            table.insert(track_list[track_number],buffer[i])
         end
      end

      function sum_timestamp(timestamp)
         local total = 0
         for i=1, #timestamp-1 do
            total = total + ((timestamp[i]-128) * (2 ^ (7*(#timestamp-i))))
         end
         total = total + timestamp[#timestamp]
         return total
      end

      local band = LuaMidi.Util.bitwise.band
      
      local EVENTS = {}
      EVENTS[0x80] = function(bytes, current_timestamp)
         local event = LuaMidi.NoteOffEvent.new({
            channel = band(bytes[1], 0x0F) + 1,
            pitch = bytes[2],
            velocity = LuaMidi.Util.revert_velocity(bytes[3]),
            timestamp = sum_timestamp(current_timestamp),
         })
         return event
      end
      EVENTS[0x90] = function(bytes, current_timestamp)
         local event = LuaMidi.NoteOnEvent.new({
            channel = band(bytes[1], 0x0F) + 1,
            pitch = bytes[2],
            velocity = LuaMidi.Util.revert_velocity(bytes[3]),
            timestamp = sum_timestamp(current_timestamp),
         })
         return event
      end
      EVENTS[0xA0] = function() end
      EVENTS[0xB0] = function() end
      EVENTS[0xC0] = function() end
      EVENTS[0xD0] = function() end
      EVENTS[0xE0] = function() end
      
      for track_number, raw_track in ipairs(track_list) do
         local track = {
            type = {raw_track[1], raw_track[2], raw_track[3], raw_track[4]},
            events = {},
            metadata = {},
            size = {},
            data = {},
         }
         for i=1, 8 do table.remove(raw_track,1) end
         
         local metadata_types = LuaMidi.Constants.METADATA_TYPES
         
         local current_timestamp = {}
         local is_timestamp = true
         
         local function next_timestamp(i, bytes_to_skip)
            current_timestamp = {}
            is_timestamp = true
            return i + bytes_to_skip
         end
         
         local last_control_byte = false
         
         local i=1
         while i <= #raw_track do
         
            while is_timestamp do
               current_timestamp[#current_timestamp+1] = raw_track[i]
               if raw_track[i] < 0x80 then
                  is_timestamp = false
               end
               i = i + 1
            end
            
            -- TODO fix
            if raw_track[i] == 0xFF then -- METADATA
            
               local raw_metadata = {}
               local length_byte = i+2
               local data_length = raw_track[length_byte] + 1
               for j=i, length_byte + data_length do
                  raw_metadata[#raw_metadata+1] = raw_track[j-1]
               end
               local converted_data
               if raw_track[i+1] < 0x08 then
                  converted_data = ""
                  for j=5, #raw_metadata do
                     converted_data = converted_data..string.char(raw_metadata[j])
                  end
               elseif raw_track[i+1] == LuaMidi.Constants.META_TEMPO_ID then
                  local data_bytes = {raw_track[i+3], raw_track[i+4], raw_track[i+5]}
                  local ms = LuaMidi.Util.number_from_bytes(data_bytes)
                  local bpm = LuaMidi.Util.round(60000000/ms)
                  converted_data = tostring(ms).." ms ("..bpm.."bpm)"
               elseif raw_track[i+1] == LuaMidi.Constants.META_TIME_SIGNATURE_ID then
                  converted_data = raw_track[i+3]
                  converted_data = converted_data.."/"..math.ceil(2^raw_track[i+4])
               elseif raw_track[i+1] == LuaMidi.Constants.META_KEY_SIGNATURE_ID then
                  local majmin = {'major', 'minor'}
                  local keys = {{'C','A'},{'G','E'},{'D','B'},{'A','F#'},
                     {'E','C#'},{'B','G#'},{'F#','D#'},{'C#','A#'}}
                  local sharps_num = tostring(raw_track[i+3])
                  converted_data = sharps_num.."#"
                  converted_data = converted_data.." ("..keys[sharps_num+1][raw_track[i+4]+1].." "..majmin[raw_track[i+4]+1]..")"
               end
               local subtype = metadata_types[raw_track[i+1]]
               track.metadata[subtype] = converted_data
               local event = {
                  type = 'meta',
                  subtype = subtype,
                  data = raw_metadata,
                  timestamp = sum_timestamp(current_timestamp),
               }
               event = setmetatable(event, { __index = LuaMidi.MetaEvent })
               track.events[#track.events+1] = event
               i = next_timestamp(i, data_length+1)
               
            -- must test this later:
            elseif raw_track[i] < 0x80 and raw_track[i+1] == LuaMidi.Constants.PROGRAM_CHANGE_STATUS then
            
               last_control_byte = LuaMidi.Constants.PROGRAM_CHANGE_STATUS
               
               local event = {
                  type = 'program-change',
                  data = { raw_track[i], raw_track[i+1], raw_track[i+2] },
                  timestamp = sum_timestamp(current_timestamp),
               }
               event = setmetatable(event, { __index = LuaMidi.ProgramChangeEvent })
               track.events[#track.events+1] = EVENTS[LuaMidi.Constants.PROGRAM_CHANGE_STATUS]()
               current_timestamp = {}
               is_timestamp = true
               
            elseif band(raw_track[i], 0xF0) == 0x90 then -- NOTE ON
            
               last_control_byte = 0x90
            
               local channel = raw_track[i]-0x8F
               local pitch = { raw_track[i+1] }
               local pitch_code = raw_track[i+1]
               local velocity = raw_track[i+2]
               
               local event = LuaMidi.NoteOnEvent.new({
                  channel = channel,
                  pitch = pitch_code,
                  velocity = LuaMidi.Util.round(velocity / 127 * 100),
                  timestamp = sum_timestamp(current_timestamp),
               })

               track.events[#track.events+1] = event
               i = next_timestamp(i, 2)
            
            elseif band(raw_track[i], 0xF0) == 0x80 then -- NOTE OFF
                                             
               last_control_byte = 0x80
                                             
               local event = LuaMidi.NoteOffEvent.new({
                  channel = band(raw_track[i], 0x0F) + 1,
                  pitch = raw_track[i+1],
                  velocity = LuaMidi.Util.round(raw_track[i+2] / 127 * 100),
                  timestamp = sum_timestamp(current_timestamp),
               })
               
               track.events[#track.events+1] = event
               i = next_timestamp(i, 2)
               
            elseif raw_track[i] < 0x80 then -- RUNNING STATUS
            
               local event = EVENTS[band(last_control_byte, 0xF0)]({
                  last_control_byte,
                  raw_track[i],
                  raw_track[i+1],
               }, current_timestamp)
               track.events[#track.events+1] = event
               i = next_timestamp(i, 1)
            
            end
            
            i = i + 1
         
         end
         
         track = setmetatable(track, { __index = LuaMidi.Track })
         track_list[track_number] = track
      end
      return track_list
   end 
   return false
end


-------------------------------------------------
-- Adds tracks to a MIDI file.
--
-- @string input the original MIDI file path
-- @param tracks a track object or a table of tracks
-- @string[opt=`input`] output altered MIDI file path
--
-- @return `true` if successful, `false` if not
--
-- @see Track
-------------------------------------------------
function LuaMidi.add_tracks_to_MIDI(input, tracks, output)
   output = output or input
   if input:sub(#input-3) ~= ".mid" and input:sub(#input-4) ~= ".midi" then
      return false
   end
   local MIDI = open_file(input)
   if MIDI then
      local buffer = {}
      for line in MIDI:lines() do
         for i=1, #line do
            buffer[#buffer+1] = string.byte(line:sub(i,i))
         end
      end
      MIDI:close()
      if not (buffer[1] == 0x4D and
         buffer[2] == 0x54 and
         buffer[3] == 0x68 and
         buffer[4] == 0x64) then
         return false
      end
      if #tracks == 0 and tracks.type then
         if LuaMidi.Util.is_track_header(tracks.type) then
            tracks = {tracks}
         end
      end
      buffer[10] = 0x01
      local original_n_tracks = 0
      for i=1, #buffer do
         if LuaMidi.Util.is_track_header({buffer[i], buffer[i+1], buffer[i+2], buffer[i+3]}) then
            original_n_tracks = original_n_tracks + 1
         end
      end
      local bytes_n_tracks = LuaMidi.Util.number_to_bytes(original_n_tracks + #tracks, 2)
      buffer[11] = bytes_n_tracks[1]
      buffer[12] = bytes_n_tracks[2]
      local tracks_bytes = {}
      for _, track in ipairs(tracks) do
         track:add_events(LuaMidi.MetaEvent.new({data = LuaMidi.Constants.META_END_OF_TRACK_ID}))
         local raw_track = LuaMidi.Util.table_concat(track.type, track.size)
         raw_track = LuaMidi.Util.table_concat(raw_track, track.data)
         tracks_bytes[#tracks_bytes+1] = raw_track
      end
      for _, track in ipairs(tracks_bytes) do
         buffer = LuaMidi.Util.table_concat(buffer, track)
      end
      MIDI = open_file(output)--, 'wb')
      local unpack = unpack or table.unpack
      buffer = string.char(unpack(buffer))
      MIDI:write(buffer)
      MIDI:close()
      return true
   end
   return false
end

return LuaMidi
