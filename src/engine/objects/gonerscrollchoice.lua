---@class GonerScrollChoice : GonerChoice
---@overload fun(...) : GonerScrollChoice
local GonerScrollChoice, super = Class(GonerChoice)

--- Creates a horizontally scrolling choice carousel.
---
--- Choices can be supplied as a flat list or as a GonerChoice-style row. Each
--- entry may be a normal choice (`{"Name"}`), an Item, or a descriptor with
--- `value`, `text`, `item`, and/or `image` fields.
---@param x? number
---@param y? number
---@param choices? table
---@param on_complete? function
---@param on_select? function
---@param draw_cards? boolean Whether to draw Equip-style image cards. (Defaults to false)
function GonerScrollChoice:init(x, y, choices, on_complete, on_select, draw_cards)
    choices = self:normalizeChoices(choices)


    self.card_size = 99
    self.image_size = 91
    self.choice_spacing = 120
    self.visible_choices = 5
    self.draw_cards = draw_cards == true
    self.label_y = self.draw_cards and 108 or 0
    self.arrow_y = self.draw_cards and 145 or 36

    super.init(self, x, y, { choices }, on_complete, on_select)

    self.small_font = Assets.getFont("small")

    self.left_arrow_sprite = Assets.getTexture("ui/page_arrow_left")
    self.right_arrow_sprite = Assets.getTexture("ui/page_arrow_right")
    self.empty_sprite = Assets.getTexture("items/empty")
    self.unknown_sprite = Assets.getTexture("items/unknown")

    self.smooth_scroll = self.selected_x

    self.soul.visible = false

    self:resetSize()
end

---@param draw_cards? boolean
function GonerScrollChoice:setDrawCards(draw_cards)
    self.draw_cards = draw_cards == true
    self.label_y = self.draw_cards and 108 or 0
    self.arrow_y = self.draw_cards and 145 or 36
    self:resetSize()
end

---@param choices? table
---@return table
function GonerScrollChoice:normalizeChoices(choices)
    choices = choices or { { "YES" }, { "NO" } }

    if #choices > 0 and type(choices[1]) == "table" and type(choices[1][1]) == "table" then
        local flattened = {}
        for _, row in ipairs(choices) do
            for _, choice in ipairs(row) do
                table.insert(flattened, choice)
            end
        end
        choices = flattened
    end

    local result = {}
    for _, entry in ipairs(choices) do
        if type(entry) ~= "table" then
            table.insert(result, { entry })
        elseif entry[1] ~= nil or entry.value ~= nil or entry.text ~= nil or entry.item ~= nil or entry.image ~= nil then
            local choice = TableUtils.copy(entry)
            if choice[1] == nil then
                if choice.value ~= nil then
                    choice[1] = choice.value
                elseif choice.item ~= nil then
                    choice[1] = choice.item
                else
                    choice[1] = choice.text
                end
            end
            table.insert(result, choice)
        else
            -- Class instances such as Items are tables too; wrap them so the
            -- inherited GonerChoice callbacks return the instance itself.
            table.insert(result, { entry, item = entry })
        end
    end

    if #result == 0 then
        error("GonerScrollChoice requires at least one choice")
    end

    return result
end

function GonerScrollChoice:setChoice(x, y, choice)
    if y ~= 1 then
        error("Attempt to set GonerScrollChoice choice outside its only row")
    end
    super.setChoice(self, x, 1, self:normalizeChoices({ choice })[1])
end

---@param choices? table
---@param selected_x? number
---@param selected_y? number
function GonerScrollChoice:setChoices(choices, selected_x, selected_y)
    self.choices = { self:normalizeChoices(choices) }
    self.selected_x = selected_x or 1
    self.selected_y = 1

    self:clampSelection()
    self.smooth_scroll = self.selected_x
    self:resetSize()
end

function GonerScrollChoice:clampSelection()
    self.selected_y = 1
    self.selected_x = MathUtils.clamp(self.selected_x, 1, #self.choices[1])
end

function GonerScrollChoice:resetSize()
    self.width = self.choice_spacing * (self.visible_choices - 1) + self.card_size
    self.height = self.arrow_y + 16
end

function GonerScrollChoice:getSoulTarget(choice, x, y)
    return 0, 0
end

---@param choice table
---@param x? number
---@param y? number
---@return string
function GonerScrollChoice:getChoiceText(choice, x, y)
    if choice.text ~= nil then
        return tostring(choice.text)
    end

    local item = choice.item
    if not item and type(choice[1]) == "table" and choice[1].getName then
        item = choice[1]
    end
    if item and item.getName then
        return tostring(item:getName())
    end

    local value = choice[1]
    local escaped = {
        ["\\<<"] = "<<",
        ["\\>>"] = ">>",
        ["\\^^"] = "^^",
        ["\\vv"] = "vv"
    }
    if escaped[value] ~= nil then
        value = escaped[value]
    end
    return value == nil and "" or tostring(value)
end

--- Returns the texture displayed in a choice's card.
---@param choice table
---@param x? number
---@param y? number
---@return love.Texture?
function GonerScrollChoice:getChoiceTexture(choice, x, y)
    local texture = choice.texture or choice.image
    if not texture and type(choice[2]) ~= "number" then
        texture = choice[2]
    end

    if type(texture) == "string" then
        return Assets.getTexture(texture) or Assets.getTexture("items/" .. texture) or self.unknown_sprite
    elseif texture then
        return texture
    end

    local item = choice.item
    if not item and type(choice[1]) == "table" and choice[1].getMenuImage then
        item = choice[1]
    end
    if item and item.getMenuImage then
        local image = item:getMenuImage()
        if image then
            return Assets.getTexture("items/" .. image) or self.unknown_sprite
        end
    end

    return self.empty_sprite
end

function GonerScrollChoice:setSelectedOption(x, y, move_soul)
    self.selected_x = x
    self.selected_y = 1
    self:clampSelection()

    if move_soul ~= false then
        self.smooth_scroll = self.selected_x
    end
end

function GonerScrollChoice:moveSelection(x, y, dx, dy)
    if dx == 0 then
        return
    end

    local old_x = self.selected_x
    super.moveSelection(self, x, 1, dx, 0)

    if math.abs(self.selected_x - old_x) > 1 then
        self.smooth_scroll = self.selected_x
    end
end

function GonerScrollChoice:update()
    super.update(self)

    local distance = math.abs(self.smooth_scroll - self.selected_x)
    local speed = DTMULT / (4 / math.max(distance, 0.1))
    self.smooth_scroll = MathUtils.approach(self.smooth_scroll, self.selected_x, speed)
end

---@param x number
---@param y number
---@param texture love.Texture
---@param scale number
---@param color table
function GonerScrollChoice:drawChoiceCard(x, y, texture, scale, color)
    Draw.setColor(0, 0, 0, math.max(0, self.alpha - 0.25) * scale)
    Draw.rectangle(
        "fill",
        x - 4 + (self.card_size / 2.5) * (1 - scale),
        y - 4 + (self.card_size / 2.5) * (1 - scale),
        self.card_size * scale,
        self.card_size * scale
    )

    Draw.setColor(color, self.alpha)
    love.graphics.setLineWidth(2)
    Draw.rectangle(
        "line",
        x - 4 + (self.card_size / 2.5) * (1 - scale),
        y - 4 + (self.card_size / 2.5) * (1 - scale),
        self.card_size * scale,
        self.card_size * scale
    )

    if texture then
        Draw.draw(
            texture,
            x + (self.image_size / 2) * scale,
            y + (self.image_size / 2) * scale,
            0,
            scale,
            scale,
            (self.image_size / 2) * scale,
            (self.image_size / 2) * scale
        )
    end
end

function GonerScrollChoice:drawSelectionLine(text_width, half_width)
    half_width = half_width or (self.choice_spacing * (self.visible_choices - 2)) / 2
    local gap = math.min(text_width * 0.75, half_width - 8)

    Draw.setColor(1, 1, 1, self.alpha)
    love.graphics.setLineWidth(2)
    love.graphics.line(-half_width, self.label_y + 4, -half_width + 4, self.label_y + 4)
    love.graphics.line(-half_width + 6, self.label_y + 4, -gap, self.label_y + 4)
    love.graphics.line(gap, self.label_y + 4, half_width - 6, self.label_y + 4)
    love.graphics.line(half_width - 4, self.label_y + 4, half_width, self.label_y + 4)
end

function GonerScrollChoice:draw()
    Object.draw(self)

    local row = self.choices[1]
    local radius = math.floor(self.visible_choices / 2)
    local first = math.max(1, math.floor(self.smooth_scroll) - radius - 1)
    local last = math.min(#row, math.ceil(self.smooth_scroll) + radius + 1)

    local choice = self:getChoice(self.selected_x, 1)
    local text = self:getChoiceText(choice, self.selected_x, 1)

    love.graphics.setFont(self.small_font)
    local width = self.small_font:getWidth(text)

    if self.draw_cards then
        for i = first, last do
            local row_choice = row[i]
            local offset = i - self.smooth_scroll
            local selected = i == self.selected_x
            local scale = selected and (1 - math.abs(self.smooth_scroll - self.selected_x) / 4) or 0.75
            local color = ColorUtils.mergeColor(PALETTE["world_gray"], COLORS.white, selected and 1 or 0)
            local x = offset * self.choice_spacing - (self.image_size / 2)

            self:drawChoiceCard(x, 0, self:getChoiceTexture(row_choice, i, 1), scale, color)
        end

        self:drawSelectionLine(width)
        Draw.setColor(1, 1, 1, self.alpha)
        love.graphics.print(text, -width / 2, self.label_y)
    else
        self:drawSelectionLine(width, (self.choice_spacing / 2) - 8)
        for i = first, last do
            local row_choice = row[i]
            local row_text = self:getChoiceText(row_choice, i, 1)
            local offset = i - self.smooth_scroll
            local selected = i == self.selected_x
            local scale = selected and (1 - math.abs(self.smooth_scroll - self.selected_x) / 4) or 0.75
            local color = ColorUtils.mergeColor(PALETTE["world_gray"], COLORS.white, selected and 1 or 0)
            local row_width = self.small_font:getWidth(row_text)

            Draw.setColor(color, self.alpha)
            love.graphics.print(
                row_text,
                offset * self.choice_spacing,
                self.label_y,
                0,
                scale,
                scale,
                row_width / 2,
                0
            )
        end
    end

    if #row > self.visible_choices then
        local sine_off = math.sin((Kristal.getTime() * 30) / 12) * 3
        if self.selected_x > 1 then
            Draw.setColor(1, 1, 1, self.alpha)
            Draw.draw(self.left_arrow_sprite, -25 - sine_off, self.arrow_y)
        end
        if self.selected_x < #row then
            Draw.setColor(1, 1, 1, self.alpha)
            Draw.draw(self.right_arrow_sprite, 15 + sine_off, self.arrow_y)
        end
    end

    love.graphics.setFont(self.font)
    Draw.setColor(1, 1, 1, self.alpha)
end

return GonerScrollChoice
