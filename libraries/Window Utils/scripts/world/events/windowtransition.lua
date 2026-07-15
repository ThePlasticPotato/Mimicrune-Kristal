-- This should cause the game window to go off one side of the screen, load a map, and then come back from another.
local WindowTransition, super = Class(Event)

function WindowTransition:init(data)
    super:init(self, data)

    local properties = data.properties or {}

    self.target = {
        map = properties.map,
        shop = properties.shop,
        x = properties.x,
        y = properties.y,
        marker = properties.marker,
        facing = properties.facing,
        out_dir = properties.out_dir,
        in_dir = properties.in_dir
    }


end

function WindowTransition:getDebugInfo()
    local info = super.getDebugInfo(self)
    if self.target.map then table.insert(info, "Map: " .. self.target.map) end
    if self.target.x then table.insert(info, "X: " .. self.target.x) end
    if self.target.y then table.insert(info, "Y: " .. self.target.y) end
    if self.target.marker then table.insert(info, "Marker: " .. self.target.marker) end
    if self.target.facing then table.insert(info, "Facing: " .. self.target.facing) end
    if self.target.out_dir then table.insert(info, "Out Direction: " .. self.target.out_dir) end
    if self.target.in_dir then table.insert(info, "In Direction: " .. self.target.in_dir) end
    return info
end

function WindowTransition:onEnter(chara)
    if chara.is_player then
        if Kristal.Config["fullscreen"] then -- Unable to move window like this, default to normal transition
            local x, y = self.target.x, self.target.y
            local facing = self.target.facing
            local marker = self.target.marker

            if self.stairs then
                Assets.playSound("escaped")
            end
            if self.target.shop then
                self.world:shopTransition(self.target.shop, {x=x, y=y, marker=marker, facing=facing, map=self.target.map})
            elseif self.target.map then
                if marker then
                    self.world:mapTransition(self.target.map, marker, facing)
                else
                    self.world:mapTransition(self.target.map, x, y, facing)
                end
            end
        else
            Game.world:startCutscene(function (cs)

            local width, height = love.window.getMode()
            local d_width, d_height = love.window.getDesktopDimensions()
            local x, y = love.window.getPosition()


            -- If no out direction is set, make it the direction the player is facing.
            if self.target.out_dir == nil then
                self.target.out_dir = chara.facing
            end

            -- Move the window offscreen in the appropriate direction
            if self.target.out_dir == "up" then
                WindowUtils:moveWindow(x, 0 - height, 1, "in-cubic")
            elseif self.target.out_dir == "down" then
                WindowUtils:moveWindow(x, d_height, 1, "in-cubic")
            elseif self.target.out_dir == "left" then
                WindowUtils:moveWindow(0 - width, y, 1, "in-cubic")
            elseif self.target.out_dir == "right" then
                WindowUtils:moveWindow(d_width, y, 1, "in-cubic")
            end

            -- Wait until the window has moved offscreen
            cs:wait(function ()
                local x, y = love.window.getPosition()
                if self.target.out_dir == "up" then
                    return y <= 0 - height
                elseif self.target.out_dir == "down" then
                    return y >= d_height
                elseif self.target.out_dir == "left" then
                    return x <= 0 - width
                elseif self.target.out_dir == "right" then
                    return x >= d_width
                end
            end)
            -- Wait 2 frames for the window to settle into the right position
            cs:wait(1/15)
            
            if self.target.map then
                if self.target.marker then
                    Game.world:loadMap(self.target.map, self.target.marker, self.target.facing)
                else
                    Game.world:loadMap(self.target.map, self.target.x, self.target.y, self.target.facing)
                end
            end

            Kristal.transitionBorder(1/30)


            -- If no in direction is set, make it the direction the player is facing.
            if self.target.in_dir == nil then
                self.target.in_dir = chara.facing
            end

            if self.target.in_dir == "up" then
                love.window.setPosition(x, d_height)
            elseif self.target.in_dir == "down" then
                love.window.setPosition(x, 0 - height)
            elseif self.target.in_dir == "left" then
                love.window.setPosition(d_width, y)
            elseif self.target.in_dir == "right" then
                love.window.setPosition(0 - width, y)
            end
            
            WindowUtils:moveWindow(x, y, 1, "out-cubic")

            cs:wait(function ()
                local curr_x, curr_y = love.window.getPosition()
                return x == curr_x and y == curr_y
            end)
        end)
        end
    end

end

return WindowTransition