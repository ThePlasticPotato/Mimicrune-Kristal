
---@class Attackable : Event
---
---@field solid     boolean *[Property `solid`]* Whether the Attackable is solid
---
---@field max_hp number
---@field hp number
---@field destructible boolean
---@field trigger string *on_hit // on_destroy
---@field should_explode boolean
---
---@field hit_sound string
---@field break_sound string
---
---@field cutscene  string *[Property `cutscene`]* The name of a cutscene to start when interacting with this object
---@field script    string *[Property `script`]* The name of a script file to execute when interacting with this object
--- *[Property `text`]* A line of text to display when interacting with this object \
--- *[Property list `text`]* Several lines of text to display when interacting with this object \
--- *[Property multi-list `text`]* Several groups of lines of text to display on sequential interactions with this object - all of `text1_i` forms the first interaction, all of `text2_i` forms the second interaction etc...
---@field text string[] 
---
---@field set_flag string   *[Property `setflag`]* The name of a flag to set the value of when interacting with this object
---@field set_value any     *[Property `setvalue`]* The value to set the flag specified by [`set_flag`](lua://Attackable.set_flag) to (Defaults to `true`)
---
---@field once boolean      *[Property `once`]* Whether this event can only be interacted with once per save file (Defaults to `true`)
---
---
---@overload fun(...) : Attackable
local Attackable, super = Class(Event)

---@param x?            number
---@param y?            number
---@param shape?        { [1]: number, [2]: number, [3]: table? }
---@param properties?   table
function Attackable:init(x, y, shape, properties)
    shape = shape or {TILE_WIDTH, TILE_HEIGHT}
    super.init(self, x, y, shape)

    properties = properties or {}

    self.solid = properties["solid"] or false

    if (properties["sprite"]) then
        self:setSprite(properties["sprite"])
    end

    self.cutscene = properties["cutscene"]
    self.script = properties["script"]
    self.text = Utils.parsePropertyMultiList("text", properties)

    self.set_flag = properties["setflag"]
    self.set_value = properties["setvalue"]
    
    self.max_hp = properties["max_hp"] or 1
    self.hp = properties["hp"] or self.max_hp

    self.destructible = properties["destructible"] ~= false

    self.should_explode = properties["explode"] or false

    self.trigger = properties["trigger"] or "on_hit"

    self.once = properties["once"] ~= false

    self.hit_sound = properties["hit_sound"] or "bump"
    self.break_sound = properties["break_sound"] or "none"
end

function Attackable:getDebugInfo()
    local info = super.getDebugInfo(self)
    if self.cutscene  then table.insert(info, "Cutscene: "  .. self.cutscene)  end
    if self.script    then table.insert(info, "Script: "    .. self.script)    end
    if self.set_flag  then table.insert(info, "Set Flag: "  .. self.set_flag)  end
    if self.set_value then table.insert(info, "Set Value: " .. self.set_value) end
    table.insert(info, "Once: " .. (self.once and "True" or "False"))
    table.insert(info, "Text length: " .. #self.text)
    return info
end

function Attackable:onAdd(parent)
    super.onAdd(self, parent)
    if self.once and self:getFlag("used_once", false) then
        self:remove()
    end
end

function Attackable:onHit(player, dir)
    Assets.playSound(self.hit_sound)
    self.hp = self.hp - 1
    if (self.hp > 0 and self.trigger == "on_destroy") then
        return false
    end

    if self.script then
        Registry.getEventScript(self.script)(self, player, dir)
    end
    local cutscene
    if self.cutscene then
        cutscene = self.world:startCutscene(self.cutscene, self, player, dir)
    else
        cutscene = self.world:startCutscene(function(c)
            local text = self.text
            local text_index = Utils.clamp(self.interact_count, 1, #text)
            if type(text[text_index]) == "table" then
                text = text[text_index]
            end
            for _,line in ipairs(text) do
                c:text(line)
            end
        end)
    end
    cutscene:after(function()
        self:onTextEnd()
    end)

    if self.set_flag then
        Game:setFlag(self.set_flag, (self.set_value == nil and true) or self.set_value)
    end

    if (self.hp == 0) then
        self:setFlag("used_once", true)
        if self.once then
            self:destroy()
        end
    end
    return true
end

--- *(Override)*
function Attackable:destroy()
    Assets.playSound(self.break_sound)
    if (self.should_explode) then self:explode() else self:remove() end
end

--- *(Override)* Called when the cutscene/text of this Attackable finishes
function Attackable:onTextEnd() end

function Attackable:applyTileObject(data, map)
   local tile = map:createTileObject(data, 0, 0, self.width, self.height)

   local ox, oy = tile:getOrigin()
   self:setOrigin(ox, oy)

   tile:setPosition(ox * self.width, oy * self.height)

   self:addChild(tile)
end

return Attackable