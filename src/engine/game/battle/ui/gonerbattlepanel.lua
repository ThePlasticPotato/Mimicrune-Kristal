---@class GonerBattlePanel : Object
---@overload fun(x:number, y:number, width:number, height:number) : GonerBattlePanel
local GonerBattlePanel, super = Class(Object)

function GonerBattlePanel:init(x, y, width, height)
    super.init(self, x, y, width, height)

    self:setOrigin(0.5, 0.5)
    self.progress = 0
    self.target = 0
    self.visible = false
    self.hung = false

    self.hang_brightness = self:addFX(ColorMaskFX(COLORS.white, 0), "hang_brightness")

    self.box = UIBox(0, 0, width, height, "DEVICE")
    self.box.layer = -100
    self:addChild(self.box)
end

function GonerBattlePanel:setHung(hung)
    self.hung = hung
    self.hang_brightness.amount = hung and 0.32 or 0
end

function GonerBattlePanel:setOpen(open, immediate)
    self.target = open and 1 or 0
    if immediate then
        self.progress = self.target
    end
    if open then
        self.visible = true
    end
end

function GonerBattlePanel:update()
    self.progress = MathUtils.approach(self.progress, self.target, 0.12 * DTMULT)
    local eased = 1 - ((1 - self.progress) ^ 3)
    self:setScale(0.88 + (0.12 * eased))
    self:setColor(1, 1, 1, self.progress)
    if self.progress == 0 and self.target == 0 then
        self.visible = false
    end
    super.update(self)
end

return GonerBattlePanel
