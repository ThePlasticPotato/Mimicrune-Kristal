---@class OverworldActionBox : Object
---@overload fun(...) : OverworldActionBox
local OverworldActionBox, super = Class(Object)

function OverworldActionBox:init(x, y, index, chara, partypanel_offset)
    super.init(self, x, y)

    self.index = index
    ---@type PartyMember
    self.chara = chara
    self.partypanel_offset = partypanel_offset

    self.head_offset_x, self.head_offset_y = chara:getHeadIconOffset()
    self.head_sprite = Sprite(chara:getHeadIcons() .. "/head", 34 + self.head_offset_x, 11 + self.head_offset_y)
    self.head_sprite:setOrigin(0.5, 0)

    self.selector_sprite = Sprite("ui/battle/selector", 3, self.partypanel_offset + 5)
    self.selector_sprite:setLayer(5)
    self.selector_sprite.visible = false
    self.selector_sprite:play(1/2, true)

    -- if chara:getNameSprite() then
    --     self.name_sprite = Sprite(chara:getNameSprite(), 51, 16)
    --     self:addChild(self.name_sprite)
    -- end

    --self.hp_sprite   = Sprite("ui/hp", 109, 24)

    -- local ox, oy = chara:getHeadIconOffset()
    -- self.head_sprite.x = self.head_sprite.x + ox
    -- self.head_sprite.y = self.head_sprite.y + oy

    self:addChild(self.head_sprite)
    self:addChild(self.selector_sprite)
    --self:addChild(self.hp_sprite)

    self.font = Assets.getFont("smallnumbers")
    self.main_font = Assets.getFont("main")

    self.selected = false

    self.reaction_text = ""
    self.reaction_alpha = 0
    self.bubble = nil
end

function OverworldActionBox:setHeadIcon(icon)
    self.head_sprite:setSprite(self.chara:getHeadIcons() .. "/" .. icon)
end

function OverworldActionBox:react(text, display_time)
    if (self.bubble) then
        self.bubble:remove()
        self.bubble = nil
    end
    self.reaction_alpha = display_time and (display_time * 30) or 50
    self.reaction_text = text
    self.bubble = SpeechBubble({"[speed:0.5]" .. self.reaction_text}, 50, 28 + self.partypanel_offset, {right = true, actor = self.chara:getActor(false), style = "cyber", after = function () Game.stage.timer:afterCond(function() return self.reaction_alpha <= 0 end, function() self.bubble:remove() end) end})
    self.bubble:setAuto(false)
    self.bubble:setSkippable(false)
    self.bubble:setLayer(WORLD_LAYERS["top"])
    self:addChild(self.bubble)
    Game.stage.timer:afterCond(function() return self.reaction_alpha <= 0 end, function() self.bubble:advance() end)
end

function OverworldActionBox:update()
    self.reaction_alpha = self.reaction_alpha - DTMULT
    self.head_sprite.y = 11 + self.head_offset_y + self.partypanel_offset
    self.selector_sprite.visible = self.selected
    super.update(self)
end

function OverworldActionBox:draw()
    -- Draw health
    Draw.setColor(PALETTE["action_health_bg"])
    love.graphics.rectangle("fill", 21, 39 - 0 + self.partypanel_offset, 27, 9)

    local health = (self.chara:getHealth() / self.chara:getStat("health")) * 27

    if health > 0 then
        Draw.setColor(self.chara:getColor())
        love.graphics.rectangle("fill", 21, 39 - 0 + self.partypanel_offset, math.ceil(health), 9)
    end

    -- Draw.setColor(color)
    -- love.graphics.setFont(self.font)
    -- love.graphics.print(self.chara:getHealth(), 152 - health_offset, 11)
    -- Draw.setColor(PALETTE["action_health_text"])
    -- love.graphics.print("/", 161, 11)
    -- local string_width = self.font:getWidth(tostring(self.chara:getStat("health")))
    -- Draw.setColor(color)
    -- love.graphics.print(self.chara:getStat("health"), 205 - string_width, 11)

    -- Draw name text if there's no sprite
    -- if not self.name_sprite then
    --     local font = Assets.getFont("name")
    --     love.graphics.setFont(font)
    --     Draw.setColor(1, 1, 1, 1)

    --     local name = self.chara:getName():upper()
    --     local spacing = 5 - StringUtils.len(name)

    --     local off = 0
    --     for i = 1, StringUtils.len(name) do
    --         local letter = StringUtils.sub(name, i, i)
    --         love.graphics.print(letter, 51 + off, 16 - 1)
    --         off = off + font:getWidth(letter) + spacing
    --     end
    -- end

    -- local reaction_x = -1

    -- if self.x == 0 then -- lazy check for leftmost party member
    --     reaction_x = 3
    -- end

    --love.graphics.setFont(self.main_font)
    --Draw.setColor(1, 1, 1, self.reaction_alpha / 6)
    --love.graphics.print(self.reaction_text, reaction_x, 43, 0, 0.5, 0.5)

    super.draw(self)
end

return OverworldActionBox
