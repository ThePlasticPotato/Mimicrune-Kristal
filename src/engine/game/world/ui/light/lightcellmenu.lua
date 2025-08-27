---@class LightCellMenu : Object
---@overload fun(...) : LightCellMenu
local LightCellMenu, super = Class(Object)

function LightCellMenu:init()
    super.init(self, 212, 76, 298, 222)

    self.draw_children_below = 0

    self.font = Assets.getFont("main")

    self.ui_move = Assets.newSound("ui_move")
    self.ui_select = Assets.newSound("ui_select")

    self.heart_sprite = Assets.getTexture("player/heart_menu")

    self.panel_bg = PanelMenuBackground("ui/menu/panels/call/menu", -14, -14, "panel_open", "panel_close", "ui_move_panel", "ui_select_panel", "ui_error_panel", "ui_cancel_small_camera", nil, 212-28, 76-28)
    self.fx = ShaderFX("crt", {["iTime"] = function () return Kristal.getTime() end, ["texsize"] = {self.panel_bg.sprite:getWidth(), self.panel_bg.sprite:getHeight()}})
    self:addChild(self.panel_bg)
    self.ui_select = self.panel_bg.ui_select
    self.ui_move = self.panel_bg.ui_move
    self.ui_cancel = self.panel_bg.ui_cancel
    self.ui_error = self.panel_bg.ui_error

    self.current_selecting = 1
end

function LightCellMenu:update()
    if self.panel_bg.operable == false then super.update(self) ; return end
    if Input.pressed("cancel") then
        self.ui_move:stop()
        self.ui_move:play()
        Game.world.menu:closeBox()
        return
    end

    local old_selecting = self.current_selecting

    if Input.pressed("up") then
        self.current_selecting = self.current_selecting - 1
    end
    if Input.pressed("down") then
        self.current_selecting = self.current_selecting + 1
    end

    self.current_selecting = Utils.clamp(self.current_selecting, 1, #Game.world.calls)

    if self.current_selecting ~= old_selecting then
        self.ui_move:stop()
        self.ui_move:play()
    end

    if Input.pressed("confirm") then
        self:runCall(Game.world.calls[self.current_selecting])
    end

    super.update(self)
end

function LightCellMenu:draw()
    if (self.panel_bg.operable) then
        love.graphics.setFont(self.font)
        local randAlpha = Utils.random(0.8, 1.0)
        Draw.setColor(PALETTE["world_text"], randAlpha)

        for index, call in ipairs(Game.world.calls) do
            love.graphics.print(call[1], 20, -28 + (index * 32))
        end

        Draw.setColor(Game:getSoulColor())
        Draw.draw(self.heart_sprite, -4, -20 + (32 * self.current_selecting), 0, 2, 2)
    end
    super.draw(self)
end

function LightCellMenu:runCall(call)
    Assets.playSound("phone", 0.7)
    Game.world.menu:closeBox()
    Game.world.menu.state = "TEXT"
    Game.world:setCellFlag(call[2], Game.world:getCellFlag(call[2], -1) + 1)
    Game.world:startCutscene(call[2])
end

return LightCellMenu