---@class Interactable : Event
local Interactable, super = HookSystem.hookScript(Interactable)

function Interactable:onSoulInteract(soul)
    self.interact_count = self.interact_count + 1

    if self.script then
        Registry.getEventScript(self.script)(self, soul)
    end
    local cutscene
    if self.cutscene then
        cutscene = self.world:startCutscene(self.cutscene, self, soul)
    else
        cutscene = self.world:startCutscene(function(c)
            local text = self.text
            local text_index = MathUtils.clamp(self.interact_count, 1, #text)
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

    self:setFlag("used_once", true)
    if self.once then
        self:remove()
    end

    Assets.playSound("power")

    return true
end

function Interactable:onInteract(player, dir)
    if (not self.soul_only) then return super.onInteract(self, player, dir) end
    return false
end

return Interactable