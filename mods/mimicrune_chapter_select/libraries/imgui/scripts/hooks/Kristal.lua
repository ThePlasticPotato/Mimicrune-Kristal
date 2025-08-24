---@class Kristal : Kristal
local Kristal, super = Utils.hookScript(Kristal)

function Kristal.onKeyPressed(key, is_repeat)
    super.onKeyPressed(key, is_repeat)
end

return Kristal