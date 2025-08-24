---@class love : love
local lv, super = Utils.hookScript(love)

local imgui = Imgui.lib

function lv.update(dt)
    super.update(dt)
    Imgui.update()
end

function lv.draw(...)
    Imgui.preDraw()
    super.draw(...)
    love.graphics.origin()
    Imgui.draw()
end

function lv.mousemoved(x, y, dx, dy, istouch)
    imgui.love.MouseMoved(x,y)
    if not imgui.love.GetWantCaptureMouse() then
        return super.mousemoved(x, y, dx, dy, istouch)
    end
end

function lv.mousepressed(x, y, button, istouch, presses)
    imgui.love.MousePressed(button)
    if not imgui.love.GetWantCaptureMouse() then
        return super.mousepressed(x, y, button, istouch, presses)
    end
end

function lv.mousereleased(x, y, button, istouch, presses)
    imgui.love.MouseReleased(button)
    if not imgui.love.GetWantCaptureMouse() then
        return super.mousereleased(x, y, button, istouch, presses)
    end
end

function lv.wheelmoved(x, y)
    imgui.love.WheelMoved(x, y)
    if not imgui.love.GetWantCaptureMouse() then
        return super.wheelmoved(x, y)
    end
end

function lv.keypressed(key, ...)
    imgui.love.KeyPressed(key)
    if not Imgui.active or not imgui.love.GetWantCaptureKeyboard() then
        return super.keypressed(key, ...)
    end
end

function lv.keyreleased(key, ...)
    imgui.love.KeyReleased(key)
    if not Imgui.active or not imgui.love.GetWantCaptureKeyboard() then
        return super.keyreleased(key, ...)
    end
end

function lv.textinput(t)
    imgui.love.TextInput(t)
    if not Imgui.active or not imgui.love.GetWantCaptureKeyboard() then
        return super.textinput(t)
    end
end

function lv.focus(f)
    imgui.love.Focus(f)
end

function lv.quit()
    if super.quit() then
        return true
    end
    return imgui.love.Shutdown()
end

love.system.getClipboardText()
return lv
