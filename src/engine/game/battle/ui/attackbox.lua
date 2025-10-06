---@class AttackBox : Object
---@overload fun(...) : AttackBox
local AttackBox, super = Class(Object)

AttackBox.BOLTSPEED = 0.2

---comment
---@param battler PartyBattler
---@param offset number
---@param index number
---@param x number
---@param y number
function AttackBox:init(battler, offset, index, x, y)
    super.init(self, x, y)

    self.battler = battler
    self.offset = offset
    self.index = index

    self.hit_sounds = {
        ["miss"] = Assets.newSound("violence/miss"),
        ["great"] = Assets.newSound("violence/great"),
        ["fantastic"] = Assets.newSound("violence/fantastic"),
        ["amazing"] = Assets.newSound("violence/amazing"),
        ["stupendous"] = Assets.newSound("violence/stupendous"),
        ["perfect"] = Assets.newSound("violence/perfect")
    }

    self.bolt_target = 3
    self.bolt_start_x = self.bolt_target + (self.offset * AttackBox.BOLTSPEED)

    self.bolt = AttackBar(0, 0, 6, 38, battler.chara:getAttackBar())
    self.bolt:setScale(self.bolt_start_x)
    self.bolt.layer = 1
    self:addChild(self.bolt)

    self.circle = Sprite(battler.chara:getAttackCircle())
    self.circle.layer = 0
    self.circle:setOrigin(0.5, 0.5)
    self:addChild(self.circle)

    self.fade_rect = Rectangle(0, 0, SCREEN_WIDTH, 300)
    self.fade_rect:setColor(0, 0, 0, 0)
    self.fade_rect.layer = -10
    self.fade_rect.visible = false
    self:addChild(self.fade_rect)

    self.afterimage_timer = 0
    self.afterimage_count = -1

    self.flash = 0

    self.attacked = false
    self.removing = false
    self.perfect = false
end

function AttackBox:getClose()
    return (self.bolt.scale_x - (self.bolt_target - 2)) / 2
end

function AttackBox:hit()
    local p = math.abs(self:getClose())

    self.attacked = true

    self.circle:flash()

    self.bolt:burst()
    self.bolt.layer = 1
    local relativex, relativey = self:getRelativePos(self.bolt.x, self.bolt.y, self.parent)
    self.bolt:setParent(self.parent)
    self.bolt:setPosition(relativex, relativey)

    self.circle:fadeOutAndRemove(1)
    if p <= 0.10 + self.battler.chara.sweet_spot_tolerance then
        self.hit_sounds["perfect"]:play()
        self.bolt:setColor(1, 1, 0)
        self.bolt.burst_speed = 0.2
        self.perfect = true
        return 150
    elseif p <= 0.85 then
        self.hit_sounds["stupendous"]:play()
        return 130
    elseif p <= 1.3 then
        self.hit_sounds["amazing"]:play()
        return 120
    elseif p <= 2.6 then
        self.hit_sounds["fantastic"]:play()
        return 110
    else
        self.hit_sounds["great"]:play()
        self.bolt:setColor(self.battler.chara:getDamageColor())
        return 100 - (p * 2)
    end

    
end

function AttackBox:miss()
    self.hit_sounds["miss"]:play()
    self.bolt:remove()
    self.attacked = true
end

function AttackBox:endAttack()
    self.removing = true
end

function AttackBox:update()
    if self.removing or Game.battle.cancel_attack then
        self.fade_rect.alpha = MathUtils.approach(self.fade_rect.alpha, 1, 0.08 * DTMULT)
    end

    if not self.attacked then
        self.bolt.scale_x = MathUtils.approach(self.bolt.scale_x, 0, AttackBox.BOLTSPEED * DTMULT)
        self.bolt.scale_y = self.bolt.scale_x

        local p = math.abs(self:getClose())
        if (p <= 0.10 + self.battler.chara.sweet_spot_tolerance) then
            if not self.bolt.in_perfect_range then
                self.bolt.in_perfect_range = true
                Assets.playSound("bell_bounce_short", 0.5, 1)
            end
        else
            self.bolt.in_perfect_range = false
        end

        self.afterimage_timer = self.afterimage_timer + DTMULT/2
        while math.floor(self.afterimage_timer) > self.afterimage_count do
            self.afterimage_count = self.afterimage_count + 1
            local afterimg = AttackBar(0, 0, 6, 38, self.battler.chara:getAttackBar())
            afterimg.afterimage = true
            afterimg:setScale(self.bolt.scale_x)
            afterimg.layer = 3
            afterimg.alpha = 0.4
            afterimg:fadeOutSpeedAndRemove()
            self:addChild(afterimg)
        end
    end

    if not Game.battle.cancel_attack and Input.pressed("confirm") then
        self.flash = 1
    else
        self.flash = MathUtils.approach(self.flash, 0, DTMULT/5)
    end

    super.update(self)
end

function AttackBox:draw()
    local target_color = {self.battler.chara:getAttackBarColor()}
    local box_color = {self.battler.chara:getAttackBoxColor()}

    if self.flash > 0 then
        box_color = ColorUtils.mergeColor(box_color, {1, 1, 1}, self.flash)
    end

    love.graphics.setLineWidth(2)
    love.graphics.setLineStyle("rough")

    local ch1_offset = Game:getConfig("oldUIPositions")

    Draw.setColor(box_color)
    love.graphics.rectangle("line", 80, ch1_offset and 0 or 1, (15 * AttackBox.BOLTSPEED) + 3, ch1_offset and 37 or 36)

    Draw.setColor(target_color)
    love.graphics.rectangle("line", 83, 1, 8, 36)
    Draw.setColor(0, 0, 0)
    love.graphics.rectangle("fill", 84, 2, 6, 34)

    love.graphics.setLineWidth(1)

    super.draw(self)
end

return AttackBox
