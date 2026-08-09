--- A raiseable menu panel used during shifts.
---@class ShiftPanel : Object
---@field shift Shift?
---@field state PanelState
---@field progress number A value from `0` (closed) to `1` (open).
---@field open_time number
---@field close_time number
---@field sprite_path string?
---@field sprite love.Texture?
---@field open_sprite Sprite?
---@field close_sprite Sprite?
---@field screen Object
---@field screen_x number
---@field screen_y number
---@field screen_width number
---@field screen_height number
---@field screen_crt boolean
---@field buttons PanelButton[]
---@field open_sound love.Source?
---@field close_sound love.Source?
---@field screen_ambience love.Source?
---@field after_open fun()?
---@field after_close fun()?
---@overload fun(x?: number, y?: number, width?: number, height?: number) : ShiftPanel
local ShiftPanel, super = Class(Object)

---@alias PanelState
---| "CLOSED"
---| "OPENING"
---| "OPEN"
---| "CLOSING"

---@param x? number
---@param y? number
---@param width? number
---@param height? number
function ShiftPanel:init(x, y, width, height)
    super.init(self, x, y, width or SCREEN_WIDTH, height or SCREEN_HEIGHT)

    self.shift = nil
    self.state = "CLOSED"
    self.progress = 0
    self.open_time = 0.25
    self.close_time = 0.25

    self.sprite_path = nil
    self.sprite = nil
    self.open_sprite = nil
    self.close_sprite = nil

    self.screen_x = 0
    self.screen_y = 0
    self.screen_width = self.width
    self.screen_height = self.height
    self.screen_crt = true
    self.screen = self:addChild(Object(0, 0, self.screen_width, self.screen_height))

    self.buttons = {}
    self.open_sound = nil
    self.close_sound = nil
    self.screen_ambience = nil
    self.after_open = nil
    self.after_close = nil

    self.active = false
    self.visible = false
end

---@param sprite_path string
function ShiftPanel:setBackground(sprite_path)
    self.sprite_path = sprite_path
    self.sprite = Assets.getTexture(sprite_path)
    self.width = self.sprite:getWidth()
    self.height = self.sprite:getHeight()

    local open_frames = Assets.getFrames(sprite_path .. "_open")
    local close_frames = Assets.getFrames(sprite_path .. "_close")
    self.open_sprite = Sprite(open_frames or self.sprite)
    self.close_sprite = Sprite(close_frames or self.sprite)
    if open_frames then self.open_time = #open_frames / 20 end
    if close_frames then self.close_time = #close_frames / 20 end
end

---@param left number
---@param top number
---@param right number
---@param bottom number
function ShiftPanel:setScreenBounds(left, top, right, bottom)
    self.screen_x = left
    self.screen_y = top
    self.screen_width = math.max(1, right - left)
    self.screen_height = math.max(1, bottom - top)
    self.screen.x = left
    self.screen.y = top
    self.screen.width = self.screen_width
    self.screen.height = self.screen_height
end

---@param open_sound? string
---@param close_sound? string
---@param ambience_sound? string
function ShiftPanel:setSounds(open_sound, close_sound, ambience_sound)
    self.open_sound = open_sound and Assets.newSound(open_sound) or nil
    self.close_sound = close_sound and Assets.newSound(close_sound) or nil
    self.screen_ambience = ambience_sound and Assets.newSound(ambience_sound) or nil
    if self.screen_ambience then
        self.screen_ambience:setLooping(true)
        self.screen_ambience:setVolume(0.25)
    end
end

---@param child Object
---@return Object child
function ShiftPanel:addScreenChild(child)
    return self.screen:addChild(child)
end

---@param button PanelButton
---@return PanelButton button
function ShiftPanel:addButton(button)
    table.insert(self.buttons, button)
    button.panel = self
    self:addScreenChild(button)
    return button
end

---@param immediate? boolean
---@param after? fun()
---@return boolean changed
function ShiftPanel:open(immediate, after)
    if self.state ~= "CLOSED" then return false end
    local old = self.state
    self.state = immediate and "OPEN" or "OPENING"
    self.progress = immediate and 1 or 0
    self.after_open = after
    self.active = true
    self.visible = true
    if self.close_sound then self.close_sound:stop() end
    if self.close_sprite then self.close_sprite:stop() end
    if self.open_sound then
        self.open_sound:stop()
        self.open_sound:play()
    end
    if self.open_sprite and not immediate then
        self.open_sprite:stop()
        self.open_sprite:play(1 / 20, false)
    end
    local shift = self.shift or Game.shift
    if shift then shift:setPanel(self) end
    self:onStateChange(old, self.state)
    if immediate then self:finishOpening() end
    return true
end

---@param immediate? boolean
---@param after? fun()
---@return boolean changed
function ShiftPanel:close(immediate, after)
    if self.state ~= "OPEN" then return false end
    local old = self.state
    self.state = immediate and "CLOSED" or "CLOSING"
    self.progress = immediate and 0 or 1
    self.after_close = after
    if self.open_sound then self.open_sound:stop() end
    if self.open_sprite then self.open_sprite:stop() end
    if self.screen_ambience then self.screen_ambience:stop() end
    if self.close_sound then
        self.close_sound:stop()
        self.close_sound:play()
    end
    if self.close_sprite and not immediate then
        self.close_sprite:stop()
        self.close_sprite:play(1 / 20, false)
    end
    self:onStateChange(old, self.state)
    if immediate then self:finishClosing() end
    return true
end

---@return boolean changed
function ShiftPanel:toggle()
    if self.state == "CLOSED" then
        return self:open()
    elseif self.state == "OPEN" then
        return self:close()
    end
    return false
end

---@param old PanelState
---@param new PanelState
function ShiftPanel:onStateChange(old, new) end

function ShiftPanel:onOpened() end
function ShiftPanel:onClosed() end

function ShiftPanel:finishOpening()
    local old = self.state
    self.state = "OPEN"
    self.progress = 1
    if old ~= self.state then self:onStateChange(old, self.state) end
    if self.screen_ambience then self.screen_ambience:play() end
    self:onOpened()
    local after = self.after_open
    self.after_open = nil
    if after then after() end
end

function ShiftPanel:finishClosing()
    local old = self.state
    self.state = "CLOSED"
    self.progress = 0
    self.active = false
    self.visible = false
    local shift = self.shift or Game.shift
    if shift and shift.panel == self then shift:setPanel(nil) end
    if old ~= self.state then self:onStateChange(old, self.state) end
    self:onClosed()
    local after = self.after_close
    self.after_close = nil
    if after then after() end
end

function ShiftPanel:update()
    if self.open_sprite then self.open_sprite:fullUpdate() end
    if self.close_sprite then self.close_sprite:fullUpdate() end

    if self.state == "OPENING" then
        local amount = self.open_time > 0 and (DT / self.open_time) or 1
        self.progress = MathUtils.approach(self.progress, 1, amount)
        if self.progress >= 1 then self:finishOpening() end
    elseif self.state == "CLOSING" then
        local amount = self.close_time > 0 and (DT / self.close_time) or 1
        self.progress = MathUtils.approach(self.progress, 0, amount)
        if self.progress <= 0 then self:finishClosing() end
    end
    super.update(self)
end

--- *(Override)* Draw panel-specific content below its screen children.
function ShiftPanel:drawScreenContents() end

---@param progress? number Screen reveal from `0` (folded) to `1` (fully open).
function ShiftPanel:drawScreen(progress)
    progress = MathUtils.clamp(progress or 1, 0, 1)
    if progress <= 0 then return end

    local canvas = Draw.pushCanvas(self.screen_width, self.screen_height)
    self:drawScreenContents()
    love.graphics.translate(-self.screen_x, -self.screen_y)
    self.screen:fullDraw()
    Draw.popCanvas()

    Draw.setColor(1, 1, 1, 1)
    local stencil_comparison, stencil_value = love.graphics.getStencilTest()
    local left = self.screen_x
    local right = self.screen_x + self.screen_width
    local bottom = self.screen_y + self.screen_height
    local top = bottom - (self.screen_height * progress)
    local inset = (1 - progress) * self.screen_width * 0.08
    love.graphics.stencil(function()
        love.graphics.polygon(
            "fill",
            left + inset, top,
            right - inset, top,
            right, bottom,
            left, bottom
        )
    end, "replace", 1)
    love.graphics.setStencilTest("equal", 1)

    local last_shader = love.graphics.getShader()
    if self.screen_crt then
        local shader = Assets.getShader("crt")
        shader:send("iTime", Kristal.getTime())
        shader:send("texsize", { self.screen_width, self.screen_height })
        shader:send("vertJerkOpt", 0.1)
        shader:send("vertMovementOpt", 0.05)
        shader:send("bottomStaticOpt", 0.12)
        shader:send("scanlinesOpt", 0.35)
        shader:send("rgbOffsetOpt", 0.2)
        shader:send("horzFuzzOpt", 0.15)
        love.graphics.setShader(shader)
    end
    Draw.draw(canvas, self.screen_x, self.screen_y)
    if stencil_comparison then
        love.graphics.setStencilTest(stencil_comparison, stencil_value)
    else
        love.graphics.setStencilTest()
    end
    love.graphics.setShader(last_shader)
end

function ShiftPanel:draw()
    if self.state == "OPEN" then
        if self.sprite then Draw.draw(self.sprite) end
        self:drawScreen(1)
    elseif self.state == "OPENING" and self.open_sprite then
        self.open_sprite:fullDraw()
    elseif self.state == "CLOSING" and self.close_sprite then
        self.close_sprite:fullDraw()
    end
end

function ShiftPanel:onRemove(parent)
    if self.open_sound then self.open_sound:stop() end
    if self.close_sound then self.close_sound:stop() end
    if self.screen_ambience then self.screen_ambience:stop() end
    super.onRemove(self, parent)
end

return ShiftPanel
