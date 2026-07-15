---@class Battle
---@field should_prioritize_fredbear boolean
---@field music_additional Music
local Battle, super = HookSystem.hookScript(Battle)

function Battle:init()
    super.init(self)
    self.should_prioritize_fredbear = false
    self.music_additional = Music()
end

---@param parent Object
function Battle:onRemove(parent)
    super.onRemove(self, parent)

    self.music_additional:remove()
end

function Battle:returnToWorld()
    self.music_additional:stop()
    super.returnToWorld(self)
end

function Battle:commitAction(battler, action_type, target, data, extra)
    data = data or {}
    extra = extra or {}

    local is_xact = action_type:upper() == "XACT"
    if is_xact then
        action_type = "ACT"
    end

    local priority = false
    if (data.data and data.data.musical) then
        priority = true
    end
    local tp_diff = 0
    if data.tp then
        tp_diff = MathUtils.clamp(-data.tp, -Game:getTension(), Game:getMaxTension() - Game:getTension())
    end
    local np_diff = 0
    local heat_diff = 0
    if data.np and battler.chara.is_psychic then
        np_diff = MathUtils.clamp(-data.np, -battler.chara.neural_power, 100 - battler.chara.neural_power)
    end
    if data.heat and battler.chara.is_psychic then
        heat_diff = math.max(data.heat, -battler.chara.heat)
    end
    local note_diff = 0
    if data.notes and battler.chara.is_musical then
        note_diff = MathUtils.clamp(data.notes, -battler.chara.notes, 3 - battler.chara.notes)
    end

    local party_id = self:getPartyIndex(battler.chara.id)

    -- Dont commit action for an inactive party member
    if not battler:isActive() then return end

    -- Make sure this action doesn't cancel any uncancellable actions
    if data.party then
        for _,v in ipairs(data.party) do
            local index = self:getPartyIndex(v)

            if index ~= party_id then
                local action = self.character_actions[index]
                if action then
                    if action.cancellable == false then
                        return
                    end
                    if action.act_parent then
                        local parent_action = self.character_actions[action.act_parent]
                        if parent_action.cancellable == false then
                            return
                        end
                    end
                end
            end
        end
    end

    self:commitSingleAction(TableUtils.merge({
        ["character_id"] = party_id,
        ["action"] = action_type:upper(),
        ["party"] = data.party,
        ["name"] = data.name,
        ["target"] = target,
        ["data"] = data.data,
        ["tp"] = tp_diff,
        ["np"] = np_diff,
        ["heat"] = heat_diff,
        ["notes"] = note_diff,
        ["priority"] = priority,
        ["cancellable"] = data.cancellable,
    }, extra))

    if data.party then
        for _,v in ipairs(data.party) do
            local index = self:getPartyIndex(v)

            if index ~= party_id then
                local action = self.character_actions[index]
                if action then
                    if action.act_parent then
                        self:removeAction(action.act_parent)
                    else
                        self:removeAction(index)
                    end
                end

                self:commitSingleAction(TableUtils.merge({
                    ["character_id"] = index,
                    ["action"] = "SKIP",
                    ["reason"] = action_type:upper(),
                    ["name"] = data.name,
                    ["target"] = target,
                    ["data"] = data.data,
                    ["act_parent"] = party_id,
                    ["cancellable"] = data.cancellable,
                }, extra))
            end
        end
    end
end

function Battle:commitSingleAction(action)
    local battler = self.party[action.character_id]

    battler.action = action
    self.character_actions[action.character_id] = action

    if Kristal.callEvent(KRISTAL_EVENT.onBattleActionCommit, action, action.action, battler, action.target) then
        return
    end

    if action.action == "ITEM" and action.data then
        local result = action.data:onBattleSelect(battler, action.target)
        if result ~= false then
            local storage, index = Game.inventory:getItemIndex(action.data)
            action.item_storage = storage
            action.item_index = index
            if action.data:hasResultItem() then
                local result_item = action.data:createResultItem()
                Game.inventory:setItem(storage, index, result_item)
                action.result_item = result_item
            else
                Game.inventory:removeItem(action.data)
            end
            action.consumed = true
        else
            action.consumed = false
        end
    end

    local anim = action.action:lower()
    if action.action == "SPELL" and action.data then
        anim = action.data:getSelectAnimation()
        local result = action.data:onSelect(battler, action.target)
        if result ~= false then
            if action.tp then
                if action.tp > 0 then
                    Game:giveTension(action.tp)
                elseif action.tp < 0 then
                    Game:removeTension(-action.tp)
                end
            end
            if action.np then
                battler.chara.neural_power = battler.chara.neural_power + action.np
            end
            if action.heat then
                battler.chara.heat = battler.chara.heat + action.heat
            end
            if action.data and action.data.hasTag and action.data:hasTag("buff") then
                self.should_prioritize_fredbear = true
            end
            battler:setAnimation(anim)
            action.icon = anim
        end
    else
        if action.tp then
            if action.tp > 0 then
                Game:giveTension(action.tp)
            elseif action.tp < 0 then
                Game:removeTension(-action.tp)
            end
        end

        if action.action == "SKIP" and action.reason then
            anim = action.reason:lower()
        end

        if (action.action == "ITEM" and action.data and (not action.data.instant)) or (action.action ~= "ITEM") then
            battler:setAnimation("battle/"..anim.."_ready")
            action.icon = anim
        end
    end
end

function Battle:removeSingleAction(action)
    local battler = self.party[action.character_id]

    if Kristal.callEvent(KRISTAL_EVENT.onBattleActionUndo, action, action.action, battler, action.target) then
        battler.action = nil
        self.character_actions[action.character_id] = nil
        return
    end

    battler:resetSprite()

    if action.tp then
        if action.tp < 0 then
            Game:giveTension(-action.tp)
        elseif action.tp > 0 then
            Game:removeTension(action.tp)
        end
    end

    if action.np then
        battler.chara.neural_power = battler.chara.neural_power - action.np
    end
    if action.heat then
        battler.chara.heat = battler.chara.heat - action.heat
    end
    
    if action.data and action.data.hasTag and action.data:hasTag("buff") then
        self.should_prioritize_fredbear = false
    end


    if action.action == "ITEM" and action.data then
        if action.item_index and action.consumed then
            if action.result_item then
                Game.inventory:setItem(action.item_storage, action.item_index, action.data)
            else
                Game.inventory:addItemTo(action.item_storage, action.item_index, action.data)
            end
        end
        action.data:onBattleDeselect(battler, action.target)
    elseif action.action == "SPELL" and action.data then
        action.data:onDeselect(battler, action.target)
    end

    battler.action = nil
    self.character_actions[action.character_id] = nil
end

function Battle:processActionGroup(group)
    local fredbear_index
    if (self:getPartyIndex("fredbear")) then
        fredbear_index = self:getPartyIndex("fredbear")
    end
    if type(group) == "string" then
        local found = false
        if self.should_prioritize_fredbear and fredbear_index then
            local action = self.character_actions[fredbear_index]
            if action and action.action == group then
                found = true
                self:beginAction(action)
                self.character_actions[fredbear_index] = nil
                self.should_prioritize_fredbear = false
            end
        end
        for i,battler in ipairs(self.party) do
            local action = self.character_actions[i]
            if action and action.action == group then
                found = true
                self:beginAction(action)
            end
        end
        for _,action in ipairs(self.current_actions) do
            self.character_actions[action.character_id] = nil
        end
        return found
    else
        if self.should_prioritize_fredbear and fredbear_index then
            local action = self.character_actions[fredbear_index]
            if action and TableUtils.contains(group, action.action) then
                self.character_actions[fredbear_index] = nil
                self:beginAction(action)
                self.should_prioritize_fredbear = false
                return true
            end
        end
        for i,battler in ipairs(self.party) do
            -- If the table contains the action
            -- Ex. if {"SPELL", "ITEM", "SPARE"} contains "SPARE"
            local action = self.character_actions[i]
            if action and TableUtils.contains(group, action.action) then
                self.character_actions[i] = nil
                self:beginAction(action)
                return true
            end
        end
    end
end

return Battle