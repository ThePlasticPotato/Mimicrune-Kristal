---@class DraftOverlayTasksPanel : EditorControl
---@field editor Editor
---@field new_button EditorButton
---@field plugin DraftOverlayPlugin
---@field refreshing boolean
---@field search EditorSearchBar
---@field tree EditorTreeList
---@overload fun(editor: Editor, plugin: DraftOverlayPlugin): DraftOverlayTasksPanel
local DraftOverlayTasksPanel, super = Class(EditorControl)

function DraftOverlayTasksPanel:init(editor, plugin)
    super.init(self, 0, 0, 300, 360)
    self.editor = editor
    self.plugin = plugin
    self.search = self:addChild(EditorSearchBar({
        placeholder = "Search tasks...",
        on_changed = function(value) self.tree:setFilter(value) end
    }))
    self.new_button = self:addChild(EditorButton("New Task", function()
        self:createTask(nil)
    end))
    self.tree = self:addChild(EditorTreeList({
        on_select = function(node)
            if node and not self.refreshing then self.plugin.tasks:selectTask(node.data) end
        end,
        on_activate = function(node)
            if node then self.plugin.tasks:navigate(node.data) end
        end,
        on_toggle = function(node, expanded)
            node.data.expanded = expanded
            self.plugin.store:save()
        end,
        on_rename = function(node, _, name)
            self.plugin.tasks:renameTask(node.data, name)
        end,
        on_move = function(node, old_parent, new_parent, after)
            local after_task
            if after == false then
                after_task = false
            elseif after then
                after_task = after.data
            end
            self.plugin.tasks:moveTask(node.data, old_parent.data, new_parent.data,
                after_task)
        end,
        on_context_menu = function(node, tree, x, y)
            self:openContextMenu(node, tree, x, y)
        end,
        on_request_focus = function(control) editor.dockspace:setFocus(control) end
    }))
    self:refresh()
end

function DraftOverlayTasksPanel:addTaskNode(parent_node, task)
    local right_icons = {}
    if task.link then
        table.insert(right_icons, {
            text = "@",
            color = { 0.52, 0.76, 1, 1 },
            action = function() self.plugin.tasks:navigate(task) end
        })
    end
    table.insert(right_icons, {
        text = task.done and "[x]" or "[ ]",
        color = task.done and { 0.48, 0.78, 0.52, 1 } or { 0.72, 0.72, 0.76, 1 },
        action = function() self.plugin.tasks:toggleTask(task) end
    })
    local node = self.tree:newNode(#(task.children or {}) > 0 and "folder" or "map", task.name, {
        expanded = task.expanded ~= false,
        icon = "editor/ui/layer/default",
        virtual = task.done == true,
        data = task,
        right_icons = right_icons
    })
    node.parent = parent_node
    table.insert(parent_node.children, node)
    for _, child in ipairs(task.children or {}) do self:addTaskNode(node, child) end
    return node
end

function DraftOverlayTasksPanel:findNode(task_id)
    for _, entry in ipairs(self.tree.visible_nodes) do
        if entry.node.data and entry.node.data.id == task_id then return entry.node end
    end
end

function DraftOverlayTasksPanel:refresh()
    local selected_id = self.plugin.tasks.selected_task_id
    local filter = self.search and self.search.value or ""
    self.refreshing = true
    self.tree:clear()
    for _, task in ipairs(self.plugin.store.data.tasks or {}) do
        self:addTaskNode(self.tree.root, task)
    end
    self.tree:setFilter(filter)
    self.tree:refreshVisibleNodes()
    local selected = selected_id and self:findNode(selected_id)
    if selected then self.tree:selectNode(selected) end
    self.refreshing = false
end

function DraftOverlayTasksPanel:createTask(parent)
    local task = self.plugin.tasks:createTask(parent)
    if not task then return false end
    self:refresh()
    local node = self:findNode(task.id)
    if node then
        self.tree:selectNode(node)
        self.tree:beginRename(node)
    end
    return true
end

function DraftOverlayTasksPanel:openContextMenu(node, tree, x, y)
    local task = node and node.data
    local items = {
        { label = "New Task", action = function() self:createTask(nil) end }
    }
    if task then
        table.insert(items, {
            label = "Add Child Task",
            action = function() self:createTask(task) end
        })
        table.insert(items, {
            label = "Rename",
            action = function() tree:beginRename(node) end
        })
        table.insert(items, {
            label = task.done and "Mark Incomplete" or "Mark Complete",
            action = function() self.plugin.tasks:toggleTask(task) end
        })
        table.insert(items, {
            label = "Link",
            children = {
                {
                    label = "Selected Draft",
                    enabled = self.plugin.tasks:getSelectedDraftLink() ~= nil,
                    action = function() self.plugin.tasks:linkToSelectedDraft(task) end
                },
                {
                    label = "Focused Map",
                    enabled = self.plugin.tasks:getFocusedMapId() ~= nil,
                    action = function() self.plugin.tasks:linkToFocusedMap(task) end
                },
                {
                    label = "Clear Link",
                    enabled = task.link ~= nil,
                    action = function() self.plugin.tasks:setLink(task, nil) end
                }
            }
        })
        table.insert(items, {
            label = "Go to Link",
            enabled = task.link ~= nil,
            action = function() self.plugin.tasks:navigate(task) end
        })
        table.insert(items, {
            label = "Delete",
            action = function() self.plugin.tasks:deleteTask(task) end
        })
    end
    local global_x, global_y = tree:getGlobalPosition()
    self.editor.dockspace:openContextMenu(items, global_x + x, global_y + y, tree)
end

function DraftOverlayTasksPanel:update(dt)
    local padding, gap = 8, 6
    local width = math.max(0, self.width - padding * 2)
    local button_width = math.min(92, math.max(68, width * 0.32))
    self.search:setBounds(padding, padding, math.max(0, width - button_width - gap), 28)
    self.new_button:setBounds(self.width - padding - button_width, padding, button_width, 28)
    self.tree:setBounds(padding, 44, width, math.max(0, self.height - 70))
    super.update(self, dt)
end

function DraftOverlayTasksPanel:drawSelf()
    Draw.setColor(0.08, 0.08, 0.09, 1)
    love.graphics.rectangle("fill", 0, 0, self.width, self.height)
    local total, complete = self.plugin.tasks:getCounts()
    local font = EditorFont.get(12)
    love.graphics.setFont(font)
    Draw.setColor(0.54, 0.54, 0.58, 1)
    love.graphics.print(string.format("%d of %d complete", complete, total),
        8, self.height - font:getHeight() - 5)
end

return DraftOverlayTasksPanel
