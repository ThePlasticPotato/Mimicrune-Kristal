---@class UIBox : Object
---@overload fun(...) : UIBox
local UIBox, super = Class(Object)

UIBox.MULTIPART_SKINS = {
    DEVICE = {
        fill_color = "#c8c9be",
        scale = 1,
        sides = {
            left = "left",
            right = "right",
            top = "top",
            bottom = "bottom",
        },
        corners = {
            top_left = "corner_top_left",
            top_right = "corner_top_right",
            bottom_right = "corner_bottom_right",
            bottom_left = "corner_bottom_left",
        },
    },
}

function UIBox:init(x, y, width, height, skin)
    super.init(self, x, y, width, height)

    -- If the callback returns something, use that instead
    self.skin = Kristal.callEvent(KRISTAL_EVENT.getUISkin, skin) or skin

    -- We still don't have one, let's figure it out
    if self.skin == nil then
        self.skin = self:getWorldSkin()
    end

    self.fill_color = {0,0,0}

    local skin_path = "ui/box/" .. self.skin .. "/"
    local multipart = self.MULTIPART_SKINS[self.skin]
    if multipart then
        self.multipart = true
        self.border_scale = multipart.scale or 2
        self.fill_color = ColorUtils.hexToRGB(multipart.fill_color)

        self.left   = Assets.getFramesOrTexture(skin_path .. multipart.sides.left)
        self.right  = Assets.getFramesOrTexture(skin_path .. multipart.sides.right)
        self.top    = Assets.getFramesOrTexture(skin_path .. multipart.sides.top)
        self.bottom = Assets.getFramesOrTexture(skin_path .. multipart.sides.bottom)

        self.corner_top_left     = Assets.getFramesOrTexture(skin_path .. multipart.corners.top_left)
        self.corner_top_right    = Assets.getFramesOrTexture(skin_path .. multipart.corners.top_right)
        self.corner_bottom_right = Assets.getFramesOrTexture(skin_path .. multipart.corners.bottom_right)
        self.corner_bottom_left  = Assets.getFramesOrTexture(skin_path .. multipart.corners.bottom_left)
    else
        self.border_scale = 2
        self.left   = Assets.getFramesOrTexture(skin_path .. "left")
        self.top    = Assets.getFramesOrTexture(skin_path .. "top")
        self.corner = Assets.getFramesOrTexture(skin_path .. "corner")
    end

    self.corners = {{0, 0}, {1, 0}, {1, 1}, {0, 1}}

    self.speed = 10

    self.frame = 0
end

function UIBox:getWorldSkin()
    if Game:isLight() then
        return Game:getConfig("lightTextboxStyle")
    end

    return Game:getConfig("darkTextboxStyle")
end

function UIBox:getSkin()
    return self.skin
end

function UIBox:getBorder()
    return self.left[1]:getWidth() * self.border_scale, self.top[1]:getHeight() * self.border_scale
end

function UIBox:getDebugRectangle()
    if not self.debug_rect then
        local bw, bh = self:getBorder()
        return {-bw, -bh, self.width + bw*2, self.height + bh*2}
    end
    return super.getDebugRectangle(self)
end

---@param frames love.Image[]
---@return love.Image
function UIBox:getCurrentFrame(frames)
    if Kristal.Config["simplifyVFX"] then
        return frames[1]
    end
    return frames[math.floor(((self.frame / self.speed) % #frames) + 1)]
end

function UIBox:drawMultipart(width, height)
    local left   = self:getCurrentFrame(self.left)
    local right  = self:getCurrentFrame(self.right)
    local top    = self:getCurrentFrame(self.top)
    local bottom = self:getCurrentFrame(self.bottom)

    local scale = self.border_scale

    Draw.draw(left, 0, 0, 0, scale, math.floor(height / left:getHeight()), left:getWidth(), 0)
    Draw.draw(right, width, 0, 0, scale, math.floor(height / right:getHeight()))

    Draw.draw(top, 0, 0, 0, math.floor(width / top:getWidth()), scale, 0, top:getHeight())
    Draw.draw(bottom, 0, height, 0, math.floor(width / bottom:getWidth()), scale)

    local top_left     = self:getCurrentFrame(self.corner_top_left)
    local top_right    = self:getCurrentFrame(self.corner_top_right)
    local bottom_right = self:getCurrentFrame(self.corner_bottom_right)
    local bottom_left  = self:getCurrentFrame(self.corner_bottom_left)

    Draw.draw(top_left, 0, 0, 0, scale, scale, top_left:getWidth(), top_left:getHeight())
    Draw.draw(top_right, width, 0, 0, scale, scale, 0, top_right:getHeight())
    Draw.draw(bottom_right, width, height, 0, scale, scale)
    Draw.draw(bottom_left, 0, height, 0, scale, scale, bottom_left:getWidth(), 0)
end

function UIBox:draw()
    -- VERY BAD AND EVIL FIELD INJECTION... for the sake of accuracy...
    if self.parent then
---@diagnostic disable-next-line: inject-field
        self.parent.uibox_frame = (self.parent.uibox_frame or 0) + DTMULT
        self.frame = self.parent.uibox_frame
    else
        self.frame = self.frame + DTMULT
    end

    self.left_frame   = ((self.frame / self.speed) % #self.left) + 1
    self.top_frame    = ((self.frame / self.speed) % #self.top) + 1
    if not self.multipart then
        self.corner_frame = ((self.frame / self.speed) % #self.corner) + 1
    end

    local left_width  = self.left[1]:getWidth()
    local left_height = self.left[1]:getHeight()
    local top_width   = self.top[1]:getWidth()
    local top_height  = self.top[1]:getHeight()

    local width = math.floor(self.width)
    local height = math.floor(self.height)

    local  r, g, b,a = self:getDrawColor()
    local fr,fg,fb   = unpack(self.fill_color)
    Draw.setColor(fr,fg,fb,a)
    love.graphics.rectangle("fill", 0, 0, width, height)

    Draw.setColor(r, g, b, a)

    if self.multipart then
        self:drawMultipart(width, height)
    else
        Draw.draw(self.left[math.floor(self.left_frame)], 0, 0, 0, 2, math.floor(height / left_height), left_width, 0)
        Draw.draw(self.left[math.floor(self.left_frame)], width, 0, math.pi, 2, math.floor(height / left_height), left_width, left_height)

        Draw.draw(self.top[math.floor(self.top_frame)], 0, 0, 0, math.floor(width / top_width), 2, 0, top_height)
        Draw.draw(self.top[math.floor(self.top_frame)], 0, height, math.pi, math.floor(width / top_width), 2, top_width, top_height)

        for i = 1, 4 do
            local cx, cy = self.corners[i][1] * width, self.corners[i][2] * height
            local sprite = Kristal.Config["simplifyVFX"] and self.corner[1] or self.corner[math.floor(self.corner_frame)]
            local corner_width  = 2 * ((self.corners[i][1] * 2) - 1) * -1
            local corner_height = 2 * ((self.corners[i][2] * 2) - 1) * -1
            Draw.draw(sprite, cx, cy, 0, corner_width, corner_height, sprite:getWidth(), sprite:getHeight())
        end
    end

    super.draw(self)
end

return UIBox
