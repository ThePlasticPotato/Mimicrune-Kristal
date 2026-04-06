---@class HealthBar : Object
---@overload fun(...) : HealthBar
local HealthBar, super = Class(Object)

function HealthBar:init()
    super.init(self, 0, -80)

    self.layer = WORLD_LAYERS["above_ui"] -- TODO

    self.parallax_x = 0
    self.parallax_y = 0

    self.animation_done = false
    self.animation_timer = 0
    self.animate_out = false
    self.animation_y = -63

    self.action_boxes = {}

    self.sprite = Assets.getTexture("ui/battle/panels/partypanel")

    for index, chara in ipairs(Game.party) do
        --local x_pos = (index - 1) * 213
        local size_offset = 0
        local box_gap = 0
        if #Game.party == 3 then
            size_offset = 0
            box_gap = 3
        elseif #Game.party == 2 then
            size_offset = 24
            box_gap = 10
        elseif #Game.party == 1 then
            size_offset = 213 / 4
            box_gap = 0
        end

        local action_box = OverworldActionBox(6, 48, index, chara,  size_offset+ (index - 1) * (48 + box_gap))
        action_box:setLayer(WORLD_LAYERS["above_ui"])
        self:addChild(action_box)
        table.insert(self.action_boxes, action_box)
        chara:onActionBox(action_box, true)
    end

    self.auto_hide_timer = 0
end

function HealthBar:transitionIn()
    if self.animate_out then
        self.animate_out = false
        self.animation_timer = 0
        self.animation_done = false
    end
end

function HealthBar:transitionOut()
    if not self.animate_out then
        self.animate_out = true
        self.animation_timer = 0
        self.animation_done = false
    end
end

function HealthBar:update()
    self.animation_timer = self.animation_timer + DTMULT
    self.auto_hide_timer = self.auto_hide_timer + DTMULT
    if Game.world.menu or Game.world:inBattle() then
        -- If we're in an overworld battle, or the menu is open, we don't want the health bar to disappear
        self.auto_hide_timer = 0
    end

    if self.auto_hide_timer > 60 then -- After two seconds outside of a battle, we hide the health bar
        self:transitionOut()
    end

    local max_time = self.animate_out and 3 or 8

    if self.animation_timer > max_time + 1 then
        self.animation_done = true
        self.animation_timer = max_time + 1
        if self.animate_out then
            Game.world.healthbar = nil
            self:remove()
            return
        end
    end

    if not self.animate_out then
        if self.animation_y < 0 then
            if self.animation_y > -40 then
                self.animation_y = self.animation_y + math.ceil(-self.animation_y / 2.5) * DTMULT
            else
                self.animation_y = self.animation_y + 30 * DTMULT
            end
        else
            self.animation_y = 0
        end
    else
        if self.animation_y > -63 then
            if self.animation_y > 0 then
                self.animation_y = self.animation_y - math.floor(self.animation_y / 2.5) * DTMULT
            else
                self.animation_y = self.animation_y - 30 * DTMULT
            end
        else
            self.animation_y = -63
        end
    end

    self.y = 480 - (self.animation_y + 63) * 3.5

    super.update(self)
end

function HealthBar:draw()
    -- Draw the black background
    Draw.draw(self.sprite, 0, 0)

    super.draw(self)
end

function HealthBar:react(chara, reaction)
    local index = Game:getPartyIndex(chara)
    if index and self.action_boxes[index] then
        self.action_boxes[index]:react(reaction)
    end
end

return HealthBar
