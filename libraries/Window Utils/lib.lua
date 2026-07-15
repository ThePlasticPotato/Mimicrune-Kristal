WindowUtils = {}
local lib = WindowUtils


function lib:init()
    self.do_window_move = false
    self.window_shaking = false

    self.windowtarget_x, self.windowtarget_y = love.window.getPosition()
    self.shaking_base_x, self.shaking_base_y = love.window.getPosition()
    self.windowmoving_x = 0
    self.windowmoving_y = 0
    self.shaker = nil
end

-- Closes the game window, then reopens it.
---@param time integer Time in seconds to keep the window closed before reopening. Passing no value means the window will not reopen automatically!
function lib:closeWindow(time)
    love.window.close()
    if time then
        if Game.battle then
            Game.battle.timer:after(time, function ()
                Kristal.resetWindow()
            end)
        else
            Game.world.timer:after(time, function ()
                Kristal.resetWindow()
            end)
        end
    end
end

function lib:setFullscreen(fs)
    if fs ~= nil then
        Kristal.Config["fullscreen"] = fs
    else
        Kristal.Config["fullscreen"] = not Kristal.Config["fullscreen"]
    end
    love.window.setFullscreen(Kristal.Config["fullscreen"])
end

-- Functions like the existing love2d function, but doesn't destroy tile layers in the process.
---@param width integer Window width. If nil, window will not change width.
---@param height integer Window height. If nil, window will not change height.
---@param settings table Settings that get changed. visit https://love2d.org/wiki/love.window.updateMode to see what can be changed.
function lib:updateMode(width, height, settings)

    local my_width, my_height = love.window.getMode()
    if width then my_width = width end
    if height then my_height = height end
    love.window.updateMode(my_width, my_height, settings)

    -- Force tilelayers to redraw, since resetWindow destroys their canvases
    if Game.world then
        for _,tilelayer in ipairs(Game.world.stage:getObjects(TileLayer)) do
            tilelayer.drawn = false
        end
    end

    
end


-- Slides the window to the specified screen position. Supports your usual ease types.
---@param x integer x position.
---@param y integer y position.
---@param time integer Time it will take in seconds for the window to complete its movement. Defaults to 1.
---@param ease string Ease type to use while moving. Defaults to "linear".
function lib:moveWindow(x, y, time, ease)
    if Kristal.Config["fullscreen"] then return end
    self.windowmoving_x, self.windowmoving_y = love.window.getPosition()
    self.windowtarget_x = x
    self.windowtarget_y = y
    if Game.battle then
        Game.battle.timer:tween(time or 1, self, {windowmoving_x = x}, ease or "linear")
        Game.battle.timer:tween(time or 1, self, {windowmoving_y = y}, ease or "linear")
        Game.battle.timer:tween(time or 1, self, {shaking_base_x = x}, ease or "linear")
        Game.battle.timer:tween(time or 1, self, {shaking_base_y = y}, ease or "linear")
        
    else
        Game.world.timer:tween(time or 1, self, {windowmoving_x = x}, ease or "linear")
        Game.world.timer:tween(time or 1, self, {windowmoving_y = y}, ease or "linear")
        Game.world.timer:tween(time or 1, self, {shaking_base_x = x}, ease or "linear")
        Game.world.timer:tween(time or 1, self, {shaking_base_y = y}, ease or "linear")
    end

    -- Failsafe
    if Game.battle then
        Game.battle.timer:after(time or 1, function ()
            love.window.setPosition(self.windowtarget_x, self.windowtarget_y)
            self.windowmoving_x, self.windowmoving_y = love.window.getPosition()
        end)
    else
        Game.world.timer:after((time or 1) + 0.1, function ()
            love.window.setPosition(self.windowtarget_x, self.windowtarget_y)
            self.windowmoving_x, self.windowmoving_y = love.window.getPosition()
        end)
    end

    self.do_window_move = true


end

-- Functions exactly like your usual shake function.
---@param x integer
---@param y integer
function lib:shake(x, y)
    if Kristal.Config["fullscreen"] then return end
    self.shaking_base_x, self.shaking_base_y = love.window.getPosition()
    love.window.setPosition(self.shaking_base_x + ((x and x/2 or 2)), self.shaking_base_y + ((y and y/2 or 0)))
    
    self.shaker = Sprite("kristal/banana") -- Yes, really.
    self.shaker.visible = false
    Game.stage:addChild(self.shaker)
    self.shaker:shake(x,y)
    self.window_shaking = true
end

function lib:preUpdate()

    if not Kristal.Config["fullscreen"] then

        local window_x, window_y = love.window.getPosition()
        --[[
        local offset_x, offset_y = 0, 0

        if (Kristal.DebugSystem and not Kristal.DebugSystem:isMenuOpen()) and (Kristal.Console and not Kristal.Console.is_open) then
            if Input.down("w") then
                offset_y = -10
            end

            if Input.down("a") then
                offset_x = -10
            end

            if Input.down("s") then
                offset_y = 10
            end

            if Input.down("d") then
                offset_x = 10
            end
        end

        love.window.setPosition(window_x + offset_x, window_y + offset_y)
        --]]

        if self.do_window_move then
                love.window.setPosition(self.windowmoving_x, self.windowmoving_y)
            if self.windowmoving_x == self.windowtarget_x and self.windowmoving_y == self.windowtarget_y then
                self.do_window_move = false
            end
        end
        if self.window_shaking == true and self.shaker ~= nil then
            love.window.setPosition(window_x + self.shaker.graphics.shake_x, window_y + self.shaker.graphics.shake_y)
        end


    end
    
end

function lib:postUpdate()
    if self.window_shaking and self.shaker then
        if self.shaker.graphics.shake_x == 0 and self.shaker.graphics.shake_y == 0 then
            love.window.setPosition(self.shaking_base_x, self.shaking_base_y)
            self.shaker:remove()
            self.window_shaking = false
        end

    end
    
end

return lib