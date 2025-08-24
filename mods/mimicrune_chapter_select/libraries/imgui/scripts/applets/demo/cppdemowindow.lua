local imgui = Imgui.lib;
---@class ImguiApplet.demo.cppdemowindow : ImguiApplet
local applet, super = Class("ImguiApplet", "demo/cppdemowindow")
---@cast super ImguiApplet

function applet:init()
    super.init(self)
    self.closable = true
    self.title = "C++ Demo Window"
end

function applet:fullShow()
    if not self:isOpen() then
        return
    end
    imgui.ShowDemoWindow(self.closebutton_pointer)
end

return applet