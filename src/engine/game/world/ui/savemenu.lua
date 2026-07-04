---@class SaveMenu : Object
---@overload fun(marker): SaveMenu
---@overload fun(...) : SaveMenu
local SaveMenu, super = Class(Object)

local PROMPT_WIDTH = 420
local PROMPT_HEIGHT = 116
local PROMPT_DRIFT = 22
local CHOICE_GAP = 34
local CHOICE_Y_OFFSET = 30
local SAVED_HOLD_TIME = 0.75
local SAVED_FADE_TIME = 0.45
local CHOICE_FADE_SPEED = 0.08
local PROMPT_HOLD_TIME = 0.65
local SAVE_TEXT_COLOR = { 0.95, 0.95, 0.95, 1 }
local PROMPT_BG_PADDING_X = 12
local PROMPT_BG_PADDING_Y = 7
local PROMPT_BG_ALPHA = 0.72
local STATIC_BG_PADDING_X = 9
local STATIC_BG_PADDING_Y = 6
local CHOICE_BG_PADDING_X = 5
local CHOICE_BG_PADDING_Y = 4
local TEXT_WAVE_OFFSET_X = 10

function SaveMenu:init(marker, point)
    super.init(self, 0, 0, SCREEN_WIDTH, SCREEN_HEIGHT)

    self.parallax_x = 0
    self.parallax_y = 0

    self.draw_children_below = 0

    self.font = Assets.getFont("main")
    self.ui_select = Assets.newSound("ui_select")

    self.marker = marker
    self.point = point
    if self.point then
        self.point:setInteracting(true)
    end

    -- DRIFT, CHOICE, SAVED
    self.state = "DRIFT"
    self.selected_x = 1
    self.choice_alpha = 0
    self.drift_timer = 0
    self.prompt_index = 0
    self.prompt_hold_timer = 0
    self.saved_timer = 0
    self.saved_fading = false
    self.prompts = {}

    self.anchor_x = SCREEN_WIDTH / 2
    self.anchor_y = SCREEN_HEIGHT / 2

    self.prompt_lines = self:getPromptLines()

    self.tomorrow_text = Text("[wave:1.2,12,8]TOMORROW IS ANOTHER DAY.", 0, 0, PROMPT_WIDTH, 40, {
        align = "center",
        wrap = false,
        font = "eb",
        style = "GONER_EB",
        color = SAVE_TEXT_COLOR,
    })
    self.tomorrow_text.alpha = 0
    self.tomorrow_text.layer = 2
    self:addChild(self.tomorrow_text)

    self.save_text = Text("[wave:1.5,14,8]SAVE", 0, 0, 100, 40, {
        align = "center",
        wrap = false,
        font = "eb",
        style = "GONER_EB",
        color = SAVE_TEXT_COLOR,
    })
    self.save_text.alpha = 0
    self.save_text.layer = 3
    self:addChild(self.save_text)

    self.do_not_text = Text("[wave:1.5,14,8]DO NOT", 0, 0, 120, 40, {
        align = "center",
        wrap = false,
        font = "eb",
        style = "GONER_EB",
        color = SAVE_TEXT_COLOR,
    })
    self.do_not_text.alpha = 0
    self.do_not_text.layer = 3
    self:addChild(self.do_not_text)

    self.saved_text = Text("[wave:2,12,8]FILE SAVED", 0, 0, 180, 40, {
        align = "center",
        wrap = false,
        font = "eb",
        style = "GONER_EB",
        color = SAVE_TEXT_COLOR,
    })
    self.saved_text.alpha = 0
    self.saved_text.layer = 4
    self:addChild(self.saved_text)

    self:updateElementPositions()
    self:startNextPrompt()
end

function SaveMenu:onRemove(parent)
    if self.point then
        self.point:setInteracting(false)
    end
    super.onRemove(self, parent)
end

function SaveMenu:getPromptLines()
    local text

    if self.point and self.point.text and #self.point.text > 0 then
        local index = MathUtils.clamp(self.point.interact_count or 1, 1, #self.point.text)
        text = self.point.text[index]
    end

    text = text or "* SAVE?"

    local pages = {}
    if type(text) == "table" then
        pages = text
    else
        pages = { text }
    end

    local cleaned = {}
    for _, page in ipairs(pages) do
        page = tostring(page)
        page = page:gsub("\n%*%s*", "\n")
        page = page:gsub("^%*%s*", "")
        page = page:gsub("^%s+", "")
        page = page:gsub("%s+$", "")
        if page ~= "" then
            table.insert(cleaned, page)
        end
    end

    return #cleaned > 0 and cleaned or { "SAVE?" }
end

function SaveMenu:formatPromptLine(line)
    return "[voice:none][speed:0.65][wave:2,12,8]" .. line
end

function SaveMenu:createPrompt(line)
    local prompt = DialogueText(self:formatPromptLine(line), 0, 0, PROMPT_WIDTH, PROMPT_HEIGHT, {
        align = "center",
        wrap = true,
        font = "eb",
        style = "GONER",
        color = SAVE_TEXT_COLOR,
        line_offset = 12,
    })
    prompt.skip_speed = true
    prompt.can_advance = false
    prompt.layer = 1
    prompt.drift_timer = 0
    self:addChild(prompt)
    table.insert(self.prompts, prompt)
    return prompt
end

function SaveMenu:startNextPrompt()
    if self.prompt then
        self.prompt:fadeTo(0, 0.35)
    end

    self.prompt_index = self.prompt_index + 1
    self.prompt_hold_timer = 0

    if self.prompt_index > #self.prompt_lines then
        self:startChoices()
        return
    end

    self.prompt = self:createPrompt(self.prompt_lines[self.prompt_index])
    self:updateElementPositions()
end

function SaveMenu:startChoices()
    self.state = "CHOICE"
    self.prompt = nil
    self.tomorrow_text:fadeTo(1, 0.4)
end

function SaveMenu:getAnchorPosition()
    if self.point and self.point.stage then
        local x, y = self.point:localToScreenPos(self.point.width / 4 + 2, self.point.height / 4 + 2)
        return x, y
    end
    return SCREEN_WIDTH / 2, SCREEN_HEIGHT / 2
end

function SaveMenu:updateElementPositions()
    self.anchor_x, self.anchor_y = self:getAnchorPosition()

    for _, prompt in ipairs(self.prompts) do
        if prompt.stage then
            prompt.x = self.anchor_x - PROMPT_WIDTH / 2
            prompt.y = self.anchor_y - 58 - math.min(prompt.drift_timer or 0, 1) * PROMPT_DRIFT
        end
    end

    self.tomorrow_text.x = self.anchor_x - PROMPT_WIDTH / 2
    self.tomorrow_text.y = self.anchor_y - 36

    self.save_text.x = self.anchor_x - CHOICE_GAP - self.save_text.width / 2
    self.save_text.y = self.anchor_y + CHOICE_Y_OFFSET

    self.do_not_text.x = self.anchor_x + CHOICE_GAP - self.do_not_text.width / 2
    self.do_not_text.y = self.anchor_y + CHOICE_Y_OFFSET

    self.saved_text.x = self.anchor_x - self.saved_text.width / 2
    self.saved_text.y = self.anchor_y + CHOICE_Y_OFFSET
end

function SaveMenu:drawPromptBackgrounds()
    for _, prompt in ipairs(self.prompts) do
        self:drawTextBackground(prompt, PROMPT_BG_PADDING_X, PROMPT_BG_PADDING_Y)
    end
end

function SaveMenu:drawTextBackground(text, padding_x, padding_y, alpha)
    alpha = alpha or text.alpha

    if not text.stage or alpha <= 0 then
        return
    end

    local width = math.max(1, text:getTextWidth())
    local height = math.max(1, text:getTextHeight())
    local x = text.x + (text.width / 2) - (width / 2) + TEXT_WAVE_OFFSET_X - padding_x
    local y = text.y - padding_y

    Draw.setColor(0, 0, 0, PROMPT_BG_ALPHA * alpha)
    love.graphics.rectangle(
        "fill",
        x,
        y,
        width + (padding_x * 2),
        height + (padding_y * 2)
    )
end

function SaveMenu:drawStaticTextBackgrounds()
    self:drawTextBackground(self.tomorrow_text, STATIC_BG_PADDING_X, STATIC_BG_PADDING_Y)
    self:drawTextBackground(self.save_text, CHOICE_BG_PADDING_X, CHOICE_BG_PADDING_Y, self.state == "CHOICE" and self.choice_alpha or nil)
    self:drawTextBackground(self.do_not_text, CHOICE_BG_PADDING_X, CHOICE_BG_PADDING_Y, self.state == "CHOICE" and self.choice_alpha or nil)
    self:drawTextBackground(self.saved_text, STATIC_BG_PADDING_X, STATIC_BG_PADDING_Y)
end

function SaveMenu:setChoicesVisible(alpha)
    self.choice_alpha = alpha
    self.save_text.alpha = alpha
    self.do_not_text.alpha = alpha
end

function SaveMenu:updateChoiceSelection()
    if self.selected_x == 1 then
        self.save_text.alpha = self.choice_alpha
        self.do_not_text.alpha = self.choice_alpha * 0.45
    else
        self.save_text.alpha = self.choice_alpha * 0.45
        self.do_not_text.alpha = self.choice_alpha
    end
end

function SaveMenu:save()
    Kristal.saveGame(Game.save_id, Game:save(self.marker))
    Assets.playSound("prognosticus")

    self.state = "SAVED"
    self.saved_timer = 0
    self.saved_fading = false
    self.tomorrow_text:fadeTo(0, 0.25)
    self.save_text:fadeTo(0, 0.25)
    self.do_not_text:fadeTo(0, 0.25)
    self.saved_text:fadeTo(1, 0.35)
    self.point:flash()
end

function SaveMenu:close()
    self:remove()
end

function SaveMenu:requestClose()
    if Game.world and Game.world.menu == self then
        Game.world:closeMenu()
    else
        self:close()
    end
end

function SaveMenu:update()
    self.drift_timer = self.drift_timer + DT
    for _, prompt in ipairs(self.prompts) do
        prompt.drift_timer = (prompt.drift_timer or 0) + DT
    end
    self:updateElementPositions()

    if self.state == "DRIFT" then
        if Input.pressed("cancel") then
            if self.prompt and self.prompt:isTyping() then
                self.prompt:skip()
            else
                self:requestClose()
            end
        elseif self.prompt and not self.prompt:isTyping() then
            self.prompt_hold_timer = self.prompt_hold_timer + DT
            if Input.pressed("confirm") or self.prompt_hold_timer >= PROMPT_HOLD_TIME then
                self:startNextPrompt()
            end
        end
    elseif self.state == "CHOICE" then
        self:setChoicesVisible(MathUtils.approach(self.choice_alpha, 1, CHOICE_FADE_SPEED * DTMULT))

        if Input.pressed("cancel") then
            self:requestClose()
        end
        if Input.pressed("left") or Input.pressed("right") or Input.pressed("up") or Input.pressed("down") then
            self.selected_x = self.selected_x == 1 and 2 or 1
            self.ui_select:stop()
            self.ui_select:play()
        end
        if Input.pressed("confirm") then
            if self.selected_x == 1 then
                self:save()
            else
                self:requestClose()
            end
        end

        self:updateChoiceSelection()
    elseif self.state == "SAVED" then
        self.saved_timer = self.saved_timer + DT
        if not self.saved_fading and self.saved_timer >= SAVED_HOLD_TIME then
            self.saved_fading = true
            self.saved_text:fadeTo(0, SAVED_FADE_TIME, function()
                self:requestClose()
            end)
        end
        if Input.pressed("confirm") or Input.pressed("cancel") then
            self:requestClose()
        end
    end

    super.update(self)
end

function SaveMenu:draw()
    self:drawPromptBackgrounds()
    self:drawStaticTextBackgrounds()
    super.draw(self)
end

return SaveMenu
