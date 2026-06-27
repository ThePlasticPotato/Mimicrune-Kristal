---@class DisplaySoul : Object
---@overload fun(...) : DisplaySoul
local DisplaySoul, super = Class(Object)

function DisplaySoul:init(x, y)
    super.init(self, x, y, 16, 16)
    self.sprite = self:addChild(Sprite("player/heart_dodge", 0, 0))
    self.sprite:setOrigin(0.5, 0.5)
    self.sprite:setColor(Kristal.getSoulColor())
    self.pos_offset = 0
    self.soul_visible = false
    self.sprite.visible = false
    self.soul_glow = SoulGlow(x, y, self, true)
    self.soul_glow:hide(true)
    self.runtime = 0
    self.flash_timer = 20
end

function DisplaySoul:onAdd(parent)
    super.onAdd(self, parent)
    parent:addChild(self.soul_glow)
end

function DisplaySoul:onRemove(parent)
    super.onRemove(self, parent)
    self.soul_glow:remove()
end

function DisplaySoul:flipVisible(sound)
    if (self.soul_visible) then
        self.sprite.visible = false
        self.soul_glow:hide(true)
        self.soul_visible = false
    else
        self.sprite.visible = true
        self.soul_visible = true
        self.soul_glow:show(sound)
    end
end

function DisplaySoul:update()
    super.update(self)
    self.flash_timer = self.flash_timer - DTMULT
    if (self.flash_timer <= 0) then
        self.sprite:flash()
        self.flash_timer = 40 + MathUtils.random(1, 10)
    end
    self.soul_glow.x = self.x
    self.soul_glow.y = self.y
    --self.soul_glow:setLayer(self.layer-1)
    self.runtime = self.runtime + DT

    self.pos_offset = self.pos_offset + ((math.sin(self.runtime)/8) * DTMULT)
    self.sprite.y = self.pos_offset
end


return DisplaySoul
