---@class DraftOverlayTaskController
---@field editor Editor
---@field plugin DraftOverlayPlugin
---@field selected_task_id string?
---@field store DraftOverlayStore
---@overload fun(plugin: DraftOverlayPlugin): DraftOverlayTaskController
local DraftOverlayTaskController = Class()

function DraftOverlayTaskController:init(plugin)
    self.plugin = plugin
    self.editor = plugin.editor
    self.store = plugin.store
end

function DraftOverlayTaskController:createTask(parent, link)
    local task
    self.plugin:perform("Create Draft Task", function()
        task = self.store:addTask(parent, "New Task")
        task.link = link and TableUtils.copy(link, true) or nil
        return true
    end)
    if task then
        self:selectTask(task)
        if self.plugin.task_panel then self.plugin.task_panel:refresh() end
    end
    return task
end

function DraftOverlayTaskController:renameTask(task, name)
    return self.plugin:perform("Rename Draft Task", function()
        task.name = name
        return true
    end)
end

function DraftOverlayTaskController:toggleTask(task)
    return self.plugin:perform(task.done and "Reopen Draft Task" or "Complete Draft Task", function()
        task.done = not task.done
        return true
    end)
end

function DraftOverlayTaskController:deleteTask(task)
    if not task then return false end
    return self.plugin:perform("Delete Draft Task", function()
        self.store:removeTask(task.id)
        if self.selected_task_id == task.id then self.selected_task_id = nil end
        local target = self.editor.properties_browser and self.editor.properties_browser.target
        if target and target.task_id == task.id then
            self.editor:clearPropertiesTarget(self.plugin)
        end
        return true
    end)
end

function DraftOverlayTaskController:moveTask(task, _old_parent, new_parent, after)
    return self.plugin:perform("Move Draft Task", function()
        local _, old_list, old_index = self.store:findTask(task.id)
        if not old_list then return false end
        table.remove(old_list, old_index)
        local new_list = new_parent and new_parent.children or self.store.data.tasks
        if new_parent then new_parent.expanded = true end
        if after == false then
            table.insert(new_list, 1, task)
            return true
        end
        if after then
            for index, candidate in ipairs(new_list) do
                if candidate == after then
                    table.insert(new_list, index + 1, task)
                    return true
                end
            end
        end
        table.insert(new_list, task)
        return true
    end)
end

function DraftOverlayTaskController:selectTask(task)
    if not task then return false end
    self.selected_task_id = task.id
    self:setPropertiesTarget(task)
    return true
end

function DraftOverlayTaskController:setPropertiesTarget(task)
    local details = EditorPropertyFields.value(task, "Details", "details")
    details.multiline = true
    self.editor:setPropertiesTarget({
        title = "Draft Task: " .. tostring(task.name),
        task_id = task.id,
        history_owner = self.store,
        fields = {
            EditorPropertyFields.value(task, "Name", "name"),
            EditorPropertyFields.choice(task, "Completed", "done", {
                { label = "Yes", value = true },
                { label = "No", value = false }
            }),
            details,
            {
                label = "Linked To",
                readonly = true,
                get = function() return self:describeLink(task.link) end,
                set = function() return false end
            }
        },
        on_changed = function()
            self.store:save()
            if self.plugin.task_panel then self.plugin.task_panel:refresh() end
        end
    }, self.plugin)
end

function DraftOverlayTaskController:getCounts(tasks)
    local total, complete = 0, 0
    for _, task in ipairs(tasks or self.store.data.tasks or {}) do
        local child_total, child_complete = self:getCounts(task.children)
        total = total + 1 + child_total
        complete = complete + (task.done and 1 or 0) + child_complete
    end
    return total, complete
end

function DraftOverlayTaskController:getFocusedMapId()
    local document = self.editor.active_document
    return document and document.map_view and document.map_view:getFocusedMapId() or nil
end

function DraftOverlayTaskController:getCurrentWorldId()
    local document = self.editor.active_document
    return document and document.map_view and self.plugin:getWorldId(document.map_view) or nil
end

function DraftOverlayTaskController:setLink(task, link)
    return self.plugin:perform(link and "Link Draft Task" or "Clear Draft Task Link", function()
        task.link = link and TableUtils.copy(link, true) or nil
        return true
    end)
end

function DraftOverlayTaskController:getDraftLink(scope, context_id, sheet_id, item_id)
    return {
        kind = "draft",
        scope = scope,
        context_id = context_id,
        sheet_id = sheet_id,
        item_id = item_id,
        world_id = self:getCurrentWorldId(),
        map_id = scope == "map" and context_id or self:getFocusedMapId()
    }
end

function DraftOverlayTaskController:linkToSelectedDraft(task)
    return self:setLink(task, self:getSelectedDraftLink())
end

function DraftOverlayTaskController:getSelectedDraftLink()
    local item = self.plugin:resolveSelection()
    local selected = self.plugin.selected
    if not item or not selected then return nil end
    return self:getDraftLink(selected.scope, selected.context_id,
        selected.sheet_id, selected.item_id)
end

function DraftOverlayTaskController:isLinkedToDraft(task, link)
    local current = task and task.link
    return current and link and current.kind == "draft"
        and current.scope == link.scope
        and current.context_id == link.context_id
        and current.sheet_id == link.sheet_id
        and current.item_id == link.item_id
end

function DraftOverlayTaskController:getTaskLinkMenuItems(link, tasks, path, items)
    local root = items == nil
    items = items or {}
    for _, task in ipairs(tasks or self.store.data.tasks or {}) do
        local label = path and (path .. " / " .. tostring(task.name)) or tostring(task.name)
        local linked = self:isLinkedToDraft(task, link)
        table.insert(items, {
            label = label,
            checked = linked,
            action = function()
                if linked then return self:setLink(task, nil) end
                return self:setLink(task, link)
            end
        })
        if task.children then
            self:getTaskLinkMenuItems(link, task.children, label, items)
        end
    end
    if root and #items == 0 then
        table.insert(items, { label = "No Tasks", enabled = false })
    end
    return items
end

function DraftOverlayTaskController:linkToFocusedMap(task)
    local map_id = self:getFocusedMapId()
    if not map_id then return false end
    return self:setLink(task, {
        kind = "map",
        map_id = map_id,
        world_id = self:getCurrentWorldId()
    })
end

function DraftOverlayTaskController:describeLink(link)
    if not link then return "None" end
    if link.kind == "map" then return "Map: " .. tostring(link.map_id) end
    if link.kind == "draft" then
        local item = self.store:getItem(link.scope, link.context_id, link.sheet_id, link.item_id)
        return item and (StringUtils.titleCase(item.kind) .. ": " .. tostring(item.name)
                .. " (" .. tostring(link.context_id) .. ")")
            or "Missing draft item"
    end
    return "Unknown link"
end

function DraftOverlayTaskController:openLinkMap(link)
    if link.world_id then
        local world = Registry.getEditorWorld(link.world_id)
        if world and self.editor:openWorld(world) then
            local document = self.editor:findWorldDocument(world.id)
            if document and document.map_view then
                if not link.map_id or document.map_view:focusMap(link.map_id) then
                    return document
                end
            end
        end
    end
    if link.map_id and self.editor:openMap(link.map_id) then
        return self.editor:findMapDocument(link.map_id)
    end
end

function DraftOverlayTaskController:navigate(task)
    local link = task and task.link
    if not link then return false end
    if link.kind == "map" then
        if self:openLinkMap(link) then return true end
    elseif link.kind == "draft" then
        local item, sheet = self.store:getItem(
            link.scope, link.context_id, link.sheet_id, link.item_id)
        if item then
            local navigation = TableUtils.copy(link, true)
            if link.scope == "world" then navigation.world_id = link.context_id end
            if link.scope == "map" then navigation.map_id = link.context_id end
            local document = self:openLinkMap(navigation)
            if document then
                self.plugin:selectItem(link.scope, link.context_id, sheet, item)
                self.editor:setActiveTool(self.plugin.tool_ids.select)
                self.plugin:showPanel()
                return true
            end
        end
    end
    self.editor:addWarning("Could not open the linked draft task target",
        self:describeLink(link), "draft_overlay")
    return false
end

return DraftOverlayTaskController
