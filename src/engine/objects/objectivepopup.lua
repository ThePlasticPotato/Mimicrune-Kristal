---@class ObjectivePopup : Object
local ObjectivePopup, super = Class(Object)

function ObjectivePopup:init(x, y, width, height, text, display_time, sound, goner, auto_close, lower)
    super.init(self, x, y, width, height)
    self.target_x = x + 60
    self.x = -550
    local style = goner and "GONER" or nil
    self.text = Text(text, 20, 0, nil, nil, {auto_size = true, style = style})
    if (lower) then
        self.y = self.y + 400 - (self.text.text_height / 2)
    end
    self.bg = UIBox(0, 0, self.text.text_width + 20, self.text.text_height + 10, goner and "dark" or nil)
    self.bg.layer = self.layer -1
    self:addChild(self.bg)
    self:addChild(self.text)
    self.auto_close = auto_close ~= false
    self:slideTo(0, self.y, 1, "in-out-cubic", function () Game.stage.timer:after(display_time or 8, function () if(self.auto_close) then self:slideTo(-550, self.y, 1, "in-out-cubic", function () self:remove() end) end end) end)
    if (sound ~= "none") then Assets.playSound(sound or "cd_bagel/noelle", 0.9) end
end

function ObjectivePopup:close()
    self:slideTo(-550, self.y, 1, "in-out-cubic", function () self:remove() end)
end

return ObjectivePopup