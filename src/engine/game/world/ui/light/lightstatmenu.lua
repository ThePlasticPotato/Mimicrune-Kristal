---@class LightStatMenu : Object
---@overload fun(...) : LightStatMenu
local LightStatMenu, super = Class(Object)

function LightStatMenu:init()
    super.init(self, 212, 76, 298, 370)

    self.panel_bg = PanelMenuBackground("ui/menu/panels/stat/menu", -14, -44, "panel_open", "panel_close", "ui_move_panel", "ui_select_panel", "ui_error_panel", "ui_cancel_small_camera", nil, 212-28, -12)
    self.fx = ShaderFX("crt", {["iTime"] = function () return Kristal.getTime() end, ["texsize"] = {self.panel_bg.sprite:getWidth(), self.panel_bg.sprite:getHeight()}})
    self:addChild(self.panel_bg)
    self.ui_select = self.panel_bg.ui_select
    self.ui_move = self.panel_bg.ui_move
    self.ui_cancel = self.panel_bg.ui_cancel
    self.ui_error = self.panel_bg.ui_error
    self.chara_selecting = 1

    self.heart_siner = 0
    self.swapping = 0

    self.draw_children_below = 0

    self.font = Assets.getFont("main")

    self.ui_move = Assets.newSound("ui_move")
    self.ui_select = Assets.newSound("ui_select")

    self.heart_sprite = Assets.getTexture("player/heart_menu")
end

function LightStatMenu:update()
    super.update(self)
    if (self.swapping > 0) then self.swapping = self.swapping - DT end
    self.heart_siner = self.heart_siner + DTMULT
    if self.panel_bg.operable == false then return end
    if Input.pressed("cancel") then
        self.panel_bg.panel_close:stop()
        self.panel_bg.panel_close:play()
        Game.world.menu:closeBox(false)
        return
    end
    local old_selecting = self.chara_selecting

    if Input.pressed("left") then
        self.chara_selecting = self.chara_selecting - 1
    end
    if Input.pressed("right") then
        self.chara_selecting = self.chara_selecting + 1
    end

    self.chara_selecting = Utils.clampWrap(self.chara_selecting, 1, Utils.tableLength(Game.party))

    if self.chara_selecting ~= old_selecting then
        self.panel_bg.ui_move:stop()
        self.panel_bg.ui_move:play()
    end

    if Input.pressed("confirm") and (self.swapping <= 0) then
        self.swapping = 3
        local chara = Game.party[self.chara_selecting]
        local old_player = Game.world:getPartyCharacterInParty(Game.party[1])
        local new_player = Game.world:getPartyCharacterInParty(chara)
        if (old_player == new_player) then
            self.panel_bg.ui_error:stop()
            self.panel_bg.ui_error:play()
            self.swapping = 0
            return
        end
        Game:movePartyMember(chara, 1)
        new_player:convertToPlayer()
        old_player:convertToFollower(self.chara_selecting-1)
        Assets.playSound("dtrans_flip")
        self.chara_selecting = 1
    end
end

function LightStatMenu:draw()
    if (self.panel_bg.operable) then
        love.graphics.setFont(self.font)
        local randAlpha = Utils.random(0.8, 1.0)

        for i,party in ipairs(Game.party) do
            if self.chara_selecting ~= i then
                Draw.setColor(1, 1, 1, 1.2 - randAlpha)
            else
                Draw.setColor(1, 1, 1, 1.8 - randAlpha)
            end
            local ox, oy = party:getMenuIconOffset()
            ox = ox + 16 + (46 * i / Utils.tableLength(Game.party))
            oy = oy - 16
            Draw.draw(Assets.getTexture(party:getLightHeadIcon()), (i-1)*50 + (ox*2), oy*2, 0, 2, 2)
        end

        Draw.setColor(PALETTE["world_text"], randAlpha)

        local chara = Game.party[self.chara_selecting]

        love.graphics.print("\"" .. chara:getName() .. "\"", 4, 8)
        love.graphics.print("LV  "..chara:getLightLV(), 4, 68)
        love.graphics.print("HP  "..chara:getHealth().." / "..chara:getStat("health"), 4, 100)

        local exp_needed = math.max(0, chara:getLightEXPNeeded(chara:getLightLV() + 1) - chara:getLightEXP())

        love.graphics.print("AT  "..chara:getBaseStats()["attack"] .." ("..chara:getEquipmentBonus("attack") ..")", 4, 164)
        love.graphics.print("DF  "..chara:getBaseStats()["defense"].." ("..chara:getEquipmentBonus("defense")..")", 4, 196)
        love.graphics.print("EXP: "..chara:getLightEXP(),   172, 164)
        love.graphics.print("NEXT: "..exp_needed, 172, 196)

        local weapon_name = chara:getWeapon() and chara:getWeapon():getName() or "None"
        local armor_name = chara:getArmor(1) and chara:getArmor(1):getName() or "None"

        love.graphics.print("WEAPON: "..weapon_name, 4, 256)
        love.graphics.print("ARMOR: "..armor_name, 4, 288)

        love.graphics.print(Game:getConfig("lightCurrency"):upper()..": "..Game.lw_money, 4, 328)

    end
    super.draw(self)
end

return LightStatMenu