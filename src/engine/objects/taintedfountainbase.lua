---@class TaintedFountainBase : Event
local TaintedFountainBase, super = Class(Event)

function TaintedFountainBase:init(data, battlemode)
    super.init(self, data)
    self.pillar_sprite = Assets.getTexture("world/nowhere/twistedfountain")
    self.edge_sprite = Assets.getTexture("world/nowhere/twistedfountain_edges")
    self.height = self.pillar_sprite:getHeight()
    self.width = self.pillar_sprite:getWidth()
    self:setOrigin(0.5, 0)
    self.wing_left = Sprite("world/nowhere/wings/left", data.x - 200, battlemode and -40 or (data.y + self.height/4))
    self.wing_left.layer = self.layer + 1
    self.wing_left:setRotationOrigin(1, 0.5)
    if (battlemode) then
        Game.battle:addChild(self.wing_left)
        --self.wing_left:setLayer(BATTLE_LAYERS["top"])
    else
        Game.world:addChild(self.wing_left)
    end
    
    self.wing_right = Sprite("world/nowhere/wings/right", data.x + 100, battlemode and -40 or (data.y + self.height/4))
    self.wing_right.layer = self.layer + 1
    self.wing_right:setRotationOrigin(0, 0.5)
    if (battlemode) then
        Game.battle:addChild(self.wing_right)
        --self.wing_right:setLayer(BATTLE_LAYERS["top"])
    else
        Game.world:addChild(self.wing_right)
    end
    --self.particles = {}

    self.mask_fx = self:addFX(MaskFX(self))

    self.left_wing_glitch_timer = 40
    self.right_wing_glitch_timer = 50

    self.bg_siner = 0
    self.wing_siner = 0
    self.outline_siner = 0
end

function TaintedFountainBase:shortGlitch(left)
    local wing = left and self.wing_left or self.wing_right
    local glitch_timer = 10
    wing:addFX(ShaderFX("kinoglitch", { ["iTime"] = function () return Kristal.getTime() end, ["scan_line_jitter"] = function () return 0.015 * (glitch_timer / 10) end, ["horizontal_shake"] = function () return 0.01 * (glitch_timer / 10) end }, false), "glitchy")
    local timer = (Game.battle) and Game.battle.timer or Game.world.timer
    timer:doWhile(function ()
        return glitch_timer > 0
    end, function ()
        glitch_timer = glitch_timer - DTMULT
    end, function ()
        wing:removeFX("glitchy")
    end)
end

function TaintedFountainBase:update()
    super.update(self)
    self.outline_siner = self.outline_siner + DTMULT
    self.bg_siner = self.bg_siner + (0.0325) * DTMULT
    -- if self.bg_siner > 7 then
    --     self.bg_siner = self.bg_siner - 7
    -- end
    self.wing_siner = self.wing_siner + 0.1250 * DTMULT
    local sind = math.sin(self.wing_siner/12) / 4
    local sind2 = math.sin((self.wing_siner / 12)) / 4

    self.wing_left.x = self.wing_left.x - (sind2 * 2 * DT)
    self.wing_left.y = self.wing_left.y + (sind2 * 1 * DT)
    self.wing_left.rotation = -(sind * DTMULT)

    self.wing_right.x = self.wing_right.x + (sind2 * 2 * DT)
    self.wing_right.y = self.wing_right.y + (sind2 * 1 * DT)
    self.wing_right.rotation = (sind * DTMULT)

    self.left_wing_glitch_timer = self.left_wing_glitch_timer - DTMULT
    self.right_wing_glitch_timer = self.right_wing_glitch_timer - DTMULT
    if (self.left_wing_glitch_timer <= 0) then
        self.left_wing_glitch_timer = MathUtils.random(30, 50)
        self:shortGlitch(true)
    end
    if (self.right_wing_glitch_timer <= 0) then
        self.right_wing_glitch_timer = MathUtils.random(30, 50)
        self:shortGlitch(false)
    end
    --self.outline.amount = self.outline.amount + (math.sin(self.outline_siner) / 4)
end

function TaintedFountainBase:onRemove(parent)
    super.onRemove(self, parent)
    self.wing_left:remove()
    self.wing_right:remove()
end

function TaintedFountainBase:draw()
    super.draw(self)
    Draw.drawWrapped(self.pillar_sprite, false, true, 0, self.height - (self.bg_siner * 280) / 7, 0, 1, 1)
    Draw.setColor(1,1,1, 0.5)
    Draw.drawWrapped(self.edge_sprite, false, true, -8 + math.sin(self.outline_siner / 16) * 6, self.height - (self.bg_siner * 280) / 7, 0, 1, 1)
    Draw.drawWrapped(self.edge_sprite, false, true, -8 - math.sin(self.outline_siner / 16) * 6, self.height - (self.bg_siner * 280) / 7, 0, 1, 1)
    Draw.setColor(1,1,1, 0.25)
    Draw.drawWrapped(self.edge_sprite, false, true, -8 + math.sin(self.outline_siner / 8) * 12, self.height - (self.bg_siner * 280) / 7, 0, 1, 1)
    Draw.drawWrapped(self.edge_sprite, false, true, -8 - math.sin(self.outline_siner / 8) * 12, self.height - (self.bg_siner * 280) / 7, 0, 1, 1)
    Draw.setColor(1,1,1,1)
end

function TaintedFountainBase:drawMask()
    Draw.setColor(1, 1, 1)
    love.graphics.rectangle("fill", -self.width/2, 0, self.width * 2, self.height)
end

return TaintedFountainBase