---@class DraftOverlayPanel : EditorControl
---@field add_button EditorButton
---@field editor Editor
---@field last_context_key string?
---@field list EditorItemList
---@field new_sheet_button EditorButton
---@field plugin DraftOverlayPlugin
---@field scope string
---@field scope_button EditorButton
---@overload fun(editor: Editor, plugin: DraftOverlayPlugin): DraftOverlayPanel
local DraftOverlayPanel, super = Class(EditorControl)

function DraftOverlayPanel:init(editor, plugin)
    super.init(self, 0, 0, 300, 360)
    self.editor = editor
    self.plugin = plugin
    self.scope = "map"
    self.scope_button = self:addChild(EditorButton("Scope: Map", function() self:openScopeMenu() end))
    self.new_sheet_button = self:addChild(EditorButton("New Sheet", function()
        self.plugin:createSheet(self.scope)
    end))
    self.add_button = self:addChild(EditorButton("Add...", function() self:openAddMenu() end))
    self.list = self:addChild(EditorItemList({
        on_select = function(item) self:selectListItem(item) end,
        on_activate = function(item)
            if item and item.data.kind == "sheet" then
                self:toggleSheetExpanded(item.data.sheet)
            end
        end,
        on_rename = function(item, _, name) self:renameListItem(item, name) end,
        on_context_menu = function(item, list, x, y) self:openItemMenu(item, list, x, y) end,
        on_request_focus = function(control) editor.dockspace:setFocus(control) end
    }))
    self:refresh()
end

function DraftOverlayPanel:getView()
    local document = self.editor.active_document
    return document and document.map_view
end

function DraftOverlayPanel:getContext()
    local view = self:getView()
    if not view then return nil end
    if self.scope == "world" and not self.plugin:getWorldId(view) then self.scope = "map" end
    return self.plugin:getCurrentContext(view, self.scope)
end

function DraftOverlayPanel:openScopeMenu()
    local view = self:getView()
    local items = {
        {
            label = "Map",
            checked = self.scope == "map",
            action = function() self:setScope("map") end
        }
    }
    if view and self.plugin:getWorldId(view) then
        table.insert(items, {
            label = "World",
            checked = self.scope == "world",
            action = function() self:setScope("world") end
        })
    end
    local x, y = self.scope_button:getGlobalPosition()
    self.editor.dockspace:openContextMenu(items, x, y + self.scope_button.height, self.scope_button)
end

function DraftOverlayPanel:setScope(scope)
    self.scope = scope == "world" and "world" or "map"
    self.last_context_key = nil
    self:refresh()
end

function DraftOverlayPanel:openAddMenu()
    local items = {
        { label = "Reference Image", action = function() self.plugin:beginCreate("image", self.scope) end },
        { label = "Box", action = function() self.plugin:beginCreate("box", self.scope) end },
        { label = "Ellipse", action = function() self.plugin:beginCreate("ellipse", self.scope) end },
        { label = "Line", action = function() self.plugin:beginCreate("line", self.scope) end },
        { label = "Polygon", action = function() self.plugin:beginCreate("polygon", self.scope) end },
        { label = "Note", action = function() self.plugin:beginCreate("note", self.scope) end }
    }
    local x, y = self.add_button:getGlobalPosition()
    self.editor.dockspace:openContextMenu(items, x, y + self.add_button.height, self.add_button)
end

function DraftOverlayPanel:selectListItem(list_item)
    if not list_item then return end
    local data = list_item.data
    local _, context_id = self:getContext()
    if data.kind == "sheet" then
        self.plugin:selectSheet(self.scope, context_id, data.sheet)
    else
        self.plugin:selectItem(self.scope, context_id, data.sheet, data.item)
        self.editor:setActiveTool(self.plugin.tool_ids.select)
    end
end

function DraftOverlayPanel:toggleSheetExpanded(sheet)
    sheet.expanded = sheet.expanded == false
    self.plugin.store:save()
    self:refresh()
end

function DraftOverlayPanel:renameListItem(list_item, name)
    local data = list_item.data
    self.plugin:perform("Rename Draft", function()
        if data.kind == "sheet" then data.sheet.name = name else data.item.name = name end
        return true
    end)
end

function DraftOverlayPanel:openItemMenu(list_item, list, x, y)
    local items = {
        { label = "New Sheet", action = function() self.plugin:createSheet(self.scope) end }
    }
    if list_item then
        local data = list_item.data
        if data.kind == "sheet" then
            table.insert(items, {
                label = data.sheet.visible == false and "Show" or "Hide",
                action = function() self.plugin:toggleSheetVisible(data.sheet) end
            })
            table.insert(items, {
                label = data.sheet.locked and "Unlock" or "Lock",
                action = function() self.plugin:toggleSheetLocked(data.sheet) end
            })
            table.insert(items, {
                label = "Rename",
                action = function() list:beginRename(list_item) end
            })
            local context = self.plugin.store:getContext(self.scope, select(2, self:getContext()), false)
            table.insert(items, {
                label = "Move Up",
                enabled = context and data.index > 1,
                action = function()
                    self.plugin:moveEntry(context.sheets, data.sheet, -1, "Reorder Draft Sheets")
                end
            })
            table.insert(items, {
                label = "Move Down",
                enabled = context and data.index < #context.sheets,
                action = function()
                    self.plugin:moveEntry(context.sheets, data.sheet, 1, "Reorder Draft Sheets")
                end
            })
            table.insert(items, {
                label = "Delete Sheet",
                action = function()
                    local _, context_id = self:getContext()
                    self.plugin:deleteSheet(self.scope, context_id, data.sheet)
                end
            })
        else
            local _, context_id = self:getContext()
            local link = self.plugin.tasks:getDraftLink(self.scope, context_id,
                data.sheet.id, data.item.id)
            table.insert(items, {
                label = "Rename",
                action = function() list:beginRename(list_item) end
            })
            table.insert(items, {
                label = "Duplicate",
                action = function()
                    local _, context_id = self:getContext()
                    self.plugin:duplicateItem(self.scope, context_id, data.sheet, data.item)
                end
            })
            table.insert(items, {
                label = "Link to Task",
                children = self.plugin.tasks:getTaskLinkMenuItems(link)
            })
            table.insert(items, {
                label = "Create Linked Task",
                action = function()
                    local task = self.plugin.tasks:createTask(nil, link)
                    if task then self.plugin:showTaskPanel() end
                end
            })
            table.insert(items, {
                label = "Move Up",
                enabled = data.index > 1,
                action = function()
                    self.plugin:moveEntry(data.sheet.items, data.item, -1, "Reorder Drafts")
                end
            })
            table.insert(items, {
                label = "Move Down",
                enabled = data.index < #data.sheet.items,
                action = function()
                    self.plugin:moveEntry(data.sheet.items, data.item, 1, "Reorder Drafts")
                end
            })
            table.insert(items, {
                label = "Delete",
                action = function()
                    local _, context_id = self:getContext()
                    self.plugin:deleteItem(self.scope, context_id, data.sheet, data.item)
                end
            })
        end
    end
    local global_x, global_y = list:getGlobalPosition()
    self.editor.dockspace:openContextMenu(items, global_x + x, global_y + y, list)
end

function DraftOverlayPanel:refresh()
    local context, context_id, context_key = self:getContext()
    local items = {}
    for sheet_index, sheet in ipairs(context and context.sheets or {}) do
        local current_sheet = sheet
        table.insert(items, {
            id = sheet.id,
            label = sheet.name .. "  [" .. (sheet.placement == "overlay" and "over" or "under") .. "]"
                .. (sheet.locked and "  (locked)" or ""),
            data = { kind = "sheet", sheet = sheet, index = sheet_index },
            expanded = sheet.expanded ~= false,
            on_toggle = function() self:toggleSheetExpanded(current_sheet) end,
            right_icon = sheet.visible == false and "editor/ui/eye_closed" or "editor/ui/eye_open",
            right_action = function() self.plugin:toggleSheetVisible(current_sheet) end
        })
        if sheet.expanded ~= false then
            for item_index, item in ipairs(sheet.items or {}) do
                table.insert(items, {
                    id = sheet.id .. ":" .. item.id,
                    label = item.name or StringUtils.titleCase(item.kind),
                    data = { kind = "item", sheet = sheet, item = item, index = item_index },
                    indent = 1,
                    color = item.color and ColorUtils.tryHexToRGB(item.color) or nil
                })
            end
        end
    end
    self.list:setItems(items)
    local selected = self.plugin.selected
    if selected and selected.scope == self.scope and selected.context_id == context_id then
        local selected_id = selected.item_id
            and selected.sheet_id .. ":" .. selected.item_id or selected.sheet_id
        for index, list_item in ipairs(self.list.filtered_items) do
            if list_item.id == selected_id then
                self.list.selected_index = index
                break
            end
        end
    end
    self.last_context_key = context_key
    self.scope_button.label = "Scope: " .. StringUtils.titleCase(self.scope)
    self.add_button.enabled = context_id ~= nil
    self.new_sheet_button.enabled = context_id ~= nil
end

function DraftOverlayPanel:update(dt)
    local padding, gap = 8, 6
    local width = math.max(0, self.width - padding * 2)
    local button_width = math.max(48, (width - gap * 2) / 3)
    self.scope_button:setBounds(padding, padding, button_width, 28)
    self.new_sheet_button:setBounds(padding + button_width + gap, padding, button_width, 28)
    self.add_button:setBounds(padding + (button_width + gap) * 2, padding, button_width, 28)
    self.list:setBounds(padding, 44, width, math.max(0, self.height - 70))
    local _, _, context_key = self:getContext()
    if context_key ~= self.last_context_key then self:refresh() end
    super.update(self, dt)
end

function DraftOverlayPanel:drawSelf()
    Draw.setColor(0.08, 0.08, 0.09, 1)
    love.graphics.rectangle("fill", 0, 0, self.width, self.height)
    local font = EditorFont.get(12)
    love.graphics.setFont(font)
    Draw.setColor(0.54, 0.54, 0.58, 1)
    love.graphics.print("Drafts are stored outside project files.", 8, self.height - font:getHeight() - 5)
end

return DraftOverlayPanel
