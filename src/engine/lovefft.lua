--[[
    A simple FFT module for LÖVE.
]]
---@class LoveFFT
local loveFFT = {}

function loveFFT:init(fftSize) -- The number of samples used to calculate FFT, must be a power of 2
    self:release()

    if fftSize == nil then
        fftSize = 2048
    end
    local fftArray = {}
    for i = 1, fftSize/2 do fftArray[i] = 0 end
    self.fftSize = fftSize
    self.fftArray = fftArray
    self.worker_generation = (self.worker_generation or 0) + 1
    local channel_suffix = tostring(self.worker_generation)
    self.channelFFT = love.thread.getChannel("fft_" .. channel_suffix)
    self.channelToFFT = love.thread.getChannel("toFFT_" .. channel_suffix)
    self.channelFFT:clear()
    self.channelToFFT:clear()
    self.threadFFT = love.thread.newThread("src/engine/ffthread.lua")
    self.threadFFT:start(fftSize, "toFFT_" .. channel_suffix, "fft_" .. channel_suffix)
    self.loaded_song = nil
end

function loveFFT:setFFTSize(fftSize) -- Usually, avoid setting FFTSize in run time to save you from chores
    local sound_data = self.soundData
    self:init(fftSize)
    if sound_data then
        self:setSoundData(sound_data)
    end
end

function loveFFT:getFFTSize()
    return self.fftSize
end

function loveFFT:getFFTArray()
    return self.fftArray
end

function loveFFT:setSoundData(soundDataOrPath) -- The sound data or path to the sound data
    if type(soundDataOrPath) == "string" then
        self.soundData = love.sound.newSoundData(soundDataOrPath)
    elseif type(soundDataOrPath) == "userdata" and soundDataOrPath:typeOf("SoundData") then
        self.soundData = soundDataOrPath
    else
        error("Invalid sound data or path.\n\nWhen you use setSoundData, you should provide a path to the audio file or a SoundData object that is created using love.sound.newSoundData.")
    end
    self.sampleRate = self.soundData:getSampleRate()
    self.bitDepth = self.soundData:getBitDepth()
    self.channelCount = self.soundData:getChannelCount()
    --error("DID WE GET IT? " .. tostring(self.soundData and true or false))
end

function loveFFT:getSoundData()
    return self.soundData
end

function loveFFT:updatePlayTime(time) -- Sync with audio playback position and start an FFT computation in a separate thread
    self.playPosition = time
    self:push()
    local err = self.threadFFT:getError()
    if err then
        error(err)
    end
end

function loveFFT:setPlayPosition(time) -- Set the audio playback position but does not start an FFT computation
    self.playPosition = time
end

function loveFFT:getPlayPosition() -- Why do you need this? Getting playback position from the Audio object is better
    return self.playPosition
end

function loveFFT:push() -- Launch a new FFT computation in a separate thread using self.playPosition. Set the position using self.updatePlayTime or self.setPlayPosition
    local sample = self.playPosition * self.sampleRate
    local toFFT = {}
    for i = 1, self.fftSize do
        toFFT[i] = 0
        for j = 1, self.channelCount do
            local success, result = pcall(self.soundData.getSample, self.soundData, math.max(1, sample + i - 1), j)
            toFFT[i] = toFFT[i] + (success and result or 0)
        end
    end
    -- Send to thread
    self.channelToFFT:clear()
    self.channelToFFT:push(toFFT)
end

function loveFFT:get() -- Gets the result of an FFT computation. This function promises a non-blocking call and yields a valid list
    -- Get from thread
    if self.channelFFT:getCount() > 0 then
        self.fftArray = self.channelFFT:pop()
        return self.fftArray, true
    else
        return self.fftArray, false
    end
end

function loveFFT:release()
    if self.threadFFT then
        if self.threadFFT:isRunning() then
            self.channelToFFT:clear()
            self.channelToFFT:push("stop")
            self.threadFFT:wait()
        end
        self.threadFFT:release()
    end
    if self.channelFFT then self.channelFFT:clear() end
    if self.channelToFFT then self.channelToFFT:clear() end
    self.threadFFT = nil
    self.channelFFT = nil
    self.channelToFFT = nil
    self.soundData = nil
end

-- Aliases
loveFFT.pop = loveFFT.get
loveFFT.destroy = loveFFT.release
loveFFT.tell = loveFFT.getPlayPosition

return loveFFT
