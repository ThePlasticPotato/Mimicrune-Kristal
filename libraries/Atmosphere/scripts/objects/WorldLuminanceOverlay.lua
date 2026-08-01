---@class WorldLuminanceOverlay : Object
local WorldLuminanceOverlay, super = Class(Object)

local SHADOW_OVERLAYS = {
    dawn = {
        color = {13 / 255, 5 / 255, 56 / 255},
        alpha = 0.3,
    },
    evening = {
        color = {35 / 255, 0, 35 / 255},
        alpha = 0.5,
    },
}

function WorldLuminanceOverlay:init()
    super.init(self)

    self.layer = WORLD_LAYERS["ui"] - 1
    self.shader = Assets.getShader("palettes/time")

    self.buffer = love.graphics.newCanvas(SCREEN_WIDTH, SCREEN_HEIGHT)
    self.buffer:setFilter("nearest", "nearest")
end

function WorldLuminanceOverlay:getTimePalette()
    local time = Atmosphere:getCurrentTime() or "default"
    if time == "day" then time = "default" end
    local texture = Assets.getTexture("palettes/"..time)
    if texture then
        return texture
    end
    return Assets.getTexture("palettes/default")
end

function WorldLuminanceOverlay:draw()
    local source = love.graphics.getCanvas()
    if not source then
        return
    end
    local texture = self:getTimePalette()
    if not texture then
        return
    end
    texture:setFilter("linear", "linear")
    texture:setWrap("clamp", "clamp")

    local strength = Atmosphere.time_fade

    local shadow = SHADOW_OVERLAYS[Atmosphere:getCurrentTime()]

    love.graphics.push("all")

    love.graphics.setCanvas(self.buffer)
    love.graphics.origin()
    love.graphics.clear(0, 0, 0, 0)
    love.graphics.setBlendMode("replace", "premultiplied")
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.setShader(self.shader)
    self.shader:send("lut_tex", texture)
    self.shader:send("strength", strength)
    love.graphics.draw(source)

    -- TODO: shadow masks
    if shadow then
        love.graphics.setShader()
        love.graphics.setBlendMode("alpha", "alphamultiply")
        love.graphics.setColor(shadow.color[1], shadow.color[2], shadow.color[3], shadow.alpha)
        love.graphics.rectangle("fill", 0, 0, SCREEN_WIDTH, SCREEN_HEIGHT)
    end

    love.graphics.setCanvas(source)
    love.graphics.origin()
    love.graphics.setShader()
    love.graphics.setBlendMode("replace", "premultiplied")
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(self.buffer)

    love.graphics.pop()
end

return WorldLuminanceOverlay
