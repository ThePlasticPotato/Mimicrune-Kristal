---@class GonerAttackBox : Object
---@overload fun(battler:PartyBattler, offset:number, index:number, x:number, y:number) : GonerAttackBox
local GonerAttackBox, super = Class(Object)

function GonerAttackBox:init(battler, offset, index, x, y)
    super.init(self, x, y, 390, 70)

    self.battler = battler
    self.offset = offset
    self.index = index
    self.font = Assets.getFont("eb")

    self.box = UIBox(0, 0, self.width, self.height, "DEVICE")
    self.box.layer = -100
    self:addChild(self.box)

    self.header_text = Text("ACQUIRE TARGET", 14, 9, 210, 20, {
        font = "eb",
        color = COLORS.black,
        wrap = false,
    })
    self.readout_text = Text("000", 260, 9, 116, 20, {
        font = "eb",
        color = COLORS.black,
        align = "right",
        wrap = false,
    })
    self:addChild(self.header_text)
    self:addChild(self.readout_text)

    self.bolt = GonerAttackBar(14, 31, self.width - 28, 24)
    self.bolt.layer = 1
    self:addChild(self.bolt)

    self.fade_rect = Rectangle(0, 0, self.width, self.height)
    self.fade_rect:setColor(0, 0, 0, 0)
    self.fade_rect.layer = 100
    self.fade_rect.visible = false
    self:addChild(self.fade_rect)
    self.fade_fx = self:addFX(AlphaFX(1))

    self.attacked = false
    self.removing = false
    self.perfect = false
    self.result_text = nil
end

function GonerAttackBox:getClose()
    return (self.bolt.target - self.bolt.position) * 5
end

function GonerAttackBox:hit()
    local error_distance = math.abs(self.bolt.position - self.bolt.target)
    local points

    self.attacked = true
    self.bolt:lock(true)

    if error_distance <= 0.025 + (self.battler.chara.sweet_spot_tolerance or 0) then
        points = 150
        self.perfect = true
        self.result_text = "LOCKED"
        Assets.playSound("violence/perfect")
    elseif error_distance <= 0.07 then
        points = 130
        self.result_text = "SYNC"
        Assets.playSound("violence/stupendous")
    elseif error_distance <= 0.14 then
        points = 115
        self.result_text = "PARTIAL"
        Assets.playSound("violence/fantastic")
    else
        points = math.max(30, 100 - error_distance * 100)
        self.result_text = "UNSTABLE"
        Assets.playSound("violence/great")
    end

    return points
end

function GonerAttackBox:miss()
    self.attacked = true
    self.bolt:lock(false)
    self.bolt.scale_x = 0
    self.result_text = "NO SIGNAL"
    Assets.playSound("violence/miss")
end

function GonerAttackBox:endAttack()
    self.removing = true
end

function GonerAttackBox:update()
    local readout = self.result_text or string.format("%03d", math.floor(self.bolt.position * 1000))
    if self.readout_text.text ~= readout then
        self.readout_text:setText(readout)
    end
    if self.removing or Game.battle.cancel_attack then
        self.fade_rect.alpha = MathUtils.approach(self.fade_rect.alpha, 1, 0.1 * DTMULT)
        self.fade_fx.alpha = 1 - self.fade_rect.alpha
    end
    super.update(self)
end

function GonerAttackBox:draw()
    super.draw(self)
end

return GonerAttackBox
