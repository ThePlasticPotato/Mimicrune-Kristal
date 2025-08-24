local lib = {}

---@class KristalImgui
local Imgui = _G.Imgui or {}
_G.Imgui = Imgui

Imgui.first_update = false

function lib:preInit()
    Imgui.init()
end

function lib:onRegistered()
    self.applets = {} ---@type table<string, ImguiApplet>
    self.applet_classes = {}
    for _,path,applet in Registry.iterScripts("applets") do
        assert(applet ~= nil, '"applets/'..path..'.lua" does not return value')
        applet.id = applet.id or path
        self.applet_classes[applet.id] = applet
    end
    for key, value in pairs(self.applet_classes) do
        self.applets[key] = value()
        self.applets[key]:setOpen(false)
    end
end

function Imgui.firstInit()
    -- this is the worst thing i've ever done
    package.path = package.path .. ";"..love.filesystem.getSaveDirectory().."/?.lua"
    package.cpath = package.cpath .. ";"..love.filesystem.getSaveDirectory().."/?."..((function()
        local os = require("ffi").os
        if os == "Windows" then
            return "dll"
        elseif os == "Linux" then
            return "so"
        elseif os == "OSX" then -- TODO: Is "OSX" correct?
            return "dylib"
        else
            error("\"" ..os.."\" isn't supported, sorry! If you're a player, tell the dev to remove the imgui stuff.")
        end
    end)())
    Imgui.active = true
    ---@type imgui
    Imgui.lib = libRequire("imgui", "cimgui.cimgui.init")
end

function Imgui.init()
    if Imgui.active == nil then
        Imgui.firstInit()
    end
    if not Imgui.initialized then
        Imgui.lib.love.Init()

        Imgui.initialized = true
        local io = Imgui.lib.C.igGetIO()
        io.ConfigFlags = bit.bor(
            io.ConfigFlags,
            Imgui.lib.ImGuiConfigFlags_NavEnableGamepad,
            Imgui.lib.ImGuiConfigFlags_DockingEnable,
        0)
    end
end

function Imgui.preDraw() end

function Imgui.draw()
    if not (Imgui.first_update and Imgui.active) then
        return
    end
    if not Kristal.callEvent("drawImgui") then
        if Imgui.lib.BeginMainMenuBar() then
            if Imgui.lib.BeginMenu("Applets") then
                for index, value in pairs(lib.applets) do
                    if Imgui.lib.MenuItem_Bool(value:getTitle(), nil, value:isOpen()) then
                        value:setOpen(not value:isOpen())
                    end
                end
                Imgui.lib.EndMenu()
            end
            Imgui.lib.EndMainMenuBar()
        end
        for key, value in pairs(lib.applets) do
            value:fullShow()
        end
    end
    Imgui.lib.Render()
    Imgui.lib.love.RenderDrawLists()
end

function Imgui.update()
    if not (Imgui.active and Imgui.initialized) then
        return
    end
    Imgui.lib.love.Update(DT)
    if Imgui.lib.love.GetWantCaptureKeyboard() then
        love.keyboard.setTextInput(true)
        Imgui.captured_keyboard = true
    end
    if Imgui.captured_keyboard and not Imgui.lib.love.GetWantCaptureKeyboard() then
        love.keyboard.setTextInput(false)
        Imgui.captured_keyboard = false
    end
    Imgui.lib.NewFrame()
    Imgui.first_update = true
end

function lib:unload()
    Imgui.first_update = false
    Imgui.initialized = false
    Imgui.lib.love.Shutdown()
end

function lib:onKeyPressed(key)
    if key == "f10" then
        Imgui.active = not Imgui.active
    end
end

return lib