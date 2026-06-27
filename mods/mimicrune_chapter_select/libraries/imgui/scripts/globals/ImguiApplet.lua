local imgui = Imgui.lib
local ffi = require("ffi")
---@class ImguiApplet : Class
local ImguiApplet, super = Class(nil, "ImguiApplet")

function ImguiApplet:init(title, flags)
    self.title = title or "Untitled Window"
    self.unique_id = self.id
    self.flags = flags or 0
    self.closable = true
    self.closebutton_pointer = ffi.new('bool[1]', true)
    ---@type [number,number]?
    self.initial_size = nil
end

function ImguiApplet:isOpen()
    ---@diagnostic disable-next-line: need-check-nil, undefined-field
    return self.closebutton_pointer[0]
end

function ImguiApplet:setOpen(open)
    ffi.copy(self.closebutton_pointer, ffi.new("bool[1]", open), 1)
end

function ImguiApplet:fullShow()
    if not self:isOpen() then
        return
    end
    if self.initial_size then
        imgui.SetNextWindowSize(self.initial_size, imgui.ImGuiCond_FirstUseEver);
    end
    if imgui.Begin(self:getTitle() .. "###" .. self.unique_id, self.closable and self.closebutton_pointer or nil, self:getFlags()) then
        self:show()
    end
    imgui.End()
end

function ImguiApplet:show()
    imgui.Button("Hello World")
end

function ImguiApplet:getFlags()
    return self.flags
end

function ImguiApplet:getTitle()
    return (self.title or "Untitled Window")
end

return ImguiApplet
