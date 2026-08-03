local fftSize, input_channel_name, output_channel_name = ...
local fft = require("src.lib.luafft")
local inChannel = love.thread.getChannel(input_channel_name)
local outChannel = love.thread.getChannel(output_channel_name)

local fftSizeInv = 1 / fftSize -- Because multiplication is slightly faster
local function postprocess(x)
    return x * fftSizeInv * 0.5 -- Normalization
end

while true do
    local toFFT = inChannel:demand()
    if toFFT == "stop" then
        break
    end

    -- Perform FFT
    local res = fft.fft(toFFT, false)
    -- Process the results to build an intuitive FFT result
    local fftArray = {}
    for i = 1, fftSize / 2 do
        fftArray[i] = postprocess(res[i]:abs() + res[#res-i+1]:abs())
    end
    -- Only retain the newest result if the main thread has not consumed one yet.
    outChannel:clear()
    outChannel:push(fftArray)
end
