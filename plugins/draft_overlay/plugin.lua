---@class DraftOverlaySelection
---@field context_id string
---@field item_id string?
---@field scope string
---@field sheet_id string

---@class DraftOverlayPlugin : EditorPlugin
---@field create_mode table?
---@field drags table<EditorMapView, table>
---@field editor Editor
---@field enabled boolean
---@field panel DraftOverlayPanel?
---@field panel_definition table
---@field point_builds table<EditorMapView, table>
---@field selected DraftOverlaySelection?
---@field store DraftOverlayStore
---@field task_panel DraftOverlayTasksPanel?
---@field task_panel_definition table
---@field tasks DraftOverlayTaskController
---@field tool_ids table<string, string>
---@field tool_kinds table<string, string>
---@overload fun(info: table): DraftOverlayPlugin
local DraftOverlayPlugin, super = Class(EditorPlugin)

function DraftOverlayPlugin:init(info)
    super.init(self, info)
end

function DraftOverlayPlugin:onInit(editor)
    self.editor = editor
    self.enabled = true
    self.drags = setmetatable({}, { __mode = "k" })
    self.point_builds = setmetatable({}, { __mode = "k" })

    local DraftOverlayStore = self:require("scripts.draftstore")
    local DraftOverlayTaskController = self:require("scripts.taskcontroller")
    local DraftOverlayPanel = self:require("scripts.panels.drafts")
    local DraftOverlayTasksPanel = self:require("scripts.panels.tasks")
    self.store = DraftOverlayStore(self, editor)
    self.tasks = DraftOverlayTaskController(self)
    self.tool_ids = {}
    self.tool_ids.select = self:registerTool("draft_select", {
        name = "Draft Select", short_name = "Select", icon = "editor/ui/tool/select"
    })
    self.tool_ids.note = self:registerTool("draft_note", {
        name = "Draft Note", short_name = "Note", icon = "editor/marker"
    })
    self.tool_ids.box = self:registerTool("draft_shape_box", {
        name = "Draft Box", short_name = "Box", icon = "editor/ui/tool/shape_rect",
        toolbar_group = "draft_overlay_shape"
    })
    self.tool_ids.ellipse = self:registerTool("draft_shape_ellipse", {
        name = "Draft Ellipse", short_name = "Ellipse", icon = "editor/ui/tool/shape_ellipse",
        toolbar_group = "draft_overlay_shape"
    })
    self.tool_ids.line = self:registerTool("draft_shape_line", {
        name = "Draft Line", short_name = "Line", icon = "editor/ui/tool/shape_line",
        toolbar_group = "draft_overlay_shape"
    })
    self.tool_ids.polygon = self:registerTool("draft_shape_polygon", {
        name = "Draft Polygon", short_name = "Polygon", icon = "editor/ui/tool/shape_poly",
        toolbar_group = "draft_overlay_shape"
    })
    self.tool_kinds = {
        [self.tool_ids.note] = "note",
        [self.tool_ids.box] = "box",
        [self.tool_ids.ellipse] = "ellipse",
        [self.tool_ids.line] = "line",
        [self.tool_ids.polygon] = "polygon"
    }
    self.panel_definition = self:registerPanel("drafts", "Drafts", function()
        self.panel = DraftOverlayPanel(editor, self)
        return self.panel
    end, {
        region = "right",
        visible = true,
        minimum_width = 220,
        minimum_height = 220,
        preferred_width = 300,
        preferred_height = 420
    })
    self.task_panel_definition = self:registerPanel("draft_tasks", "Draft Tasks", function()
        self.task_panel = DraftOverlayTasksPanel(editor, self)
        return self.task_panel
    end, {
        region = "right",
        visible = true,
        minimum_width = 220,
        minimum_height = 220,
        preferred_width = 300,
        preferred_height = 360
    })
    self:registerMenuToggle("view", "show_drafts", "Show Draft Overlays",
        function() return self.enabled end,
        function(value) self.enabled = value end)
    self:registerCommand("open_drafts", "Open Drafts Panel", {
        category = "Editor",
        keywords = { "draft", "reference", "image", "overlay", "notes" },
        action = function() self:showPanel() end
    })
    self:registerCommand("delete_draft", "Delete Selected Draft", {
        category = "Drafts",
        is_enabled = function() return self:resolveSelection() ~= nil end,
        action = function()
            local item, sheet = self:resolveSelection()
            if item then
                self:deleteItem(self.selected.scope, self.selected.context_id, sheet, item)
            end
        end
    })
    self:registerCommand("open_draft_tasks", "Open Draft Tasks Panel", {
        category = "Editor",
        keywords = { "draft", "task", "todo", "checklist" },
        action = function() self:showTaskPanel() end
    })

    HookSystem.hook(EditorMapView, "drawDocument", function(original, view)
        if self.enabled then self:drawDrafts(view, "underlay") end
        original(view)
        if self.enabled then
            self:drawDrafts(view, "overlay")
            self:drawInteraction(view)
        end
    end)
    HookSystem.hook(EditorMapView, "onMousePressed", function(original, view, x, y, button, presses)
        if self:isActive(view) and (button == 1 or button == 2) then
            return self:onMapMousePressed(view, x, y, button, presses)
        end
        return original(view, x, y, button, presses)
    end)
    HookSystem.hook(EditorMapView, "onMouseMoved", function(original, view, x, y, dx, dy)
        if self:isActive(view) and (self.drags[view] or self.point_builds[view]) then
            return self:onMapMouseMoved(view, x, y, dx, dy)
        end
        return original(view, x, y, dx, dy)
    end)
    HookSystem.hook(EditorMapView, "onMouseReleased", function(original, view, x, y, button, presses)
        if self:isActive(view) and button == 1 and self.drags[view] then
            return self:onMapMouseReleased(view, x, y, button, presses)
        end
        return original(view, x, y, button, presses)
    end)
    HookSystem.hook(EditorMapView, "getCursorType", function(original, view, x, y)
        if self:isActive(view) then return self:getMapCursorType(view, x, y) end
        return original(view, x, y)
    end)
    HookSystem.hook(EditorMapView, "onKeyPressed", function(original, view, key, is_repeat)
        if self:isActive(view) and not is_repeat then
            if key == "escape" and self:cancelInteraction(view) then return true end
            if (key == "delete" or key == "backspace") and self.selected then
                local item, sheet = self:resolveSelection()
                if item then
                    return self:deleteItem(self.selected.scope, self.selected.context_id, sheet, item)
                end
            end
        end
        return original(view, key, is_repeat)
    end)
    HookSystem.hook(Editor, "setActiveTool", function(original, instance, id)
        if instance == self.editor then
            self.create_mode = nil
            if instance.active_tool ~= id then
                for view in pairs(self.point_builds) do self:cancelPointBuild(view) end
            end
        end
        return original(instance, id)
    end)
end

function DraftOverlayPlugin:showPanel()
    local panel = self.panel_definition and self.panel_definition.panel
    if not panel then return false end
    self.editor.dockspace:setPanelVisible(panel, true, panel.last_region or "right")
    if panel.stack then panel.stack:setActivePanel(panel) end
    self.editor.dockspace:setFocus(panel.content)
    return true
end

function DraftOverlayPlugin:showTaskPanel()
    local panel = self.task_panel_definition and self.task_panel_definition.panel
    if not panel then return false end
    self.editor.dockspace:setPanelVisible(panel, true, panel.last_region or "right")
    if panel.stack then panel.stack:setActivePanel(panel) end
    self.editor.dockspace:setFocus(panel.content)
    return true
end

function DraftOverlayPlugin:isActive(view)
    return self.enabled and (self.editor.active_tool == self.tool_ids.select
        or self.tool_kinds[self.editor.active_tool] ~= nil)
        and self.editor.live_document ~= view.document
end

function DraftOverlayPlugin:getWorldId(view)
    local document = view and view.document
    return document and document.editor_world and document.world and document.world.id or nil
end

function DraftOverlayPlugin:getCurrentContext(view, scope)
    local context_id
    if scope == "world" then
        context_id = self:getWorldId(view)
    else
        context_id = view and view:getFocusedMapId()
    end
    if not context_id then return nil, nil, nil end
    return self.store:getContext(scope, context_id, false), context_id,
        scope .. ":" .. tostring(context_id)
end

function DraftOverlayPlugin:getActiveSheet(view, scope)
    local context, context_id = self:getCurrentContext(view, scope)
    if not context then return nil, context_id end
    local selected = self.selected
    if selected and selected.scope == scope and selected.context_id == context_id then
        local sheet = self.store:getSheet(scope, context_id, selected.sheet_id)
        if sheet then return sheet, context_id end
    end
    local sheet = context.sheets[1]
    return sheet, context_id
end

function DraftOverlayPlugin:perform(label, callback)
    local result = self.editor:performHistoryEdit(label, self.store, callback)
    if result then
        self.store:save()
        if self.panel then self.panel:refresh() end
        if self.task_panel then self.task_panel:refresh() end
    end
    return result
end

function DraftOverlayPlugin:createSheet(scope)
    local view = self.editor.active_document and self.editor.active_document.map_view
    local _, context_id = self:getCurrentContext(view, scope)
    if not context_id then return false end
    local sheet
    self:perform("Create Draft Sheet", function()
        sheet = self.store:addSheet(scope, context_id, "Draft Sheet")
        return true
    end)
    if sheet then self:selectSheet(scope, context_id, sheet) end
    return sheet ~= nil
end

function DraftOverlayPlugin:deleteSheet(scope, context_id, sheet)
    if not sheet then return false end
    return self:perform("Delete Draft Sheet", function()
        self.store:removeSheet(scope, context_id, sheet.id)
        if self.selected and self.selected.sheet_id == sheet.id then
            self.selected = nil
            self.editor:clearPropertiesTarget(self)
        end
        return true
    end)
end

function DraftOverlayPlugin:toggleSheetVisible(sheet)
    return self:perform(sheet.visible == false and "Show Draft Sheet" or "Hide Draft Sheet", function()
        sheet.visible = sheet.visible == false
        return true
    end)
end

function DraftOverlayPlugin:toggleSheetLocked(sheet)
    return self:perform(sheet.locked and "Unlock Draft Sheet" or "Lock Draft Sheet", function()
        sheet.locked = not sheet.locked
        return true
    end)
end

function DraftOverlayPlugin:moveEntry(list, entry, amount, label)
    local index
    for candidate_index, candidate in ipairs(list) do
        if candidate == entry then
            index = candidate_index
            break
        end
    end
    local target = index and MathUtils.clamp(index + amount, 1, #list)
    if not index or target == index then return false end
    return self:perform(label, function()
        table.remove(list, index)
        table.insert(list, target, entry)
        return true
    end)
end

function DraftOverlayPlugin:selectSheet(scope, context_id, sheet)
    if not sheet or not context_id then return false end
    if self.panel then self.panel.scope = scope end
    self.selected = {
        scope = scope,
        context_id = context_id,
        sheet_id = sheet.id
    }
    self:setSheetPropertiesTarget(sheet)
    return true
end

function DraftOverlayPlugin:selectItem(scope, context_id, sheet, item)
    if not sheet or not item or not context_id then return false end
    if self.panel then self.panel.scope = scope end
    self.selected = {
        scope = scope,
        context_id = context_id,
        sheet_id = sheet.id,
        item_id = item.id
    }
    self:setItemPropertiesTarget(item, sheet)
    if self.panel then self.panel:refresh() end
    return true
end

function DraftOverlayPlugin:resolveSelection()
    local selection = self.selected
    if not selection then return nil end
    if selection.item_id then
        local item, sheet = self.store:getItem(selection.scope, selection.context_id,
            selection.sheet_id, selection.item_id)
        if item then return item, sheet end
    else
        local sheet = self.store:getSheet(selection.scope, selection.context_id, selection.sheet_id)
        if sheet then return nil, sheet end
    end
    self.selected = nil
    return nil
end

function DraftOverlayPlugin:onStoreRestored()
    local property_target = self.editor.properties_browser and self.editor.properties_browser.target
    local task_id = property_target and property_target.task_id
    local task = task_id and self.store:findTask(task_id)
    if task then
        self.tasks.selected_task_id = task.id
        self.tasks:setPropertiesTarget(task)
        if self.panel then self.panel:refresh() end
        if self.task_panel then self.task_panel:refresh() end
        return
    end
    local item, sheet = self:resolveSelection()
    if item then
        self:setItemPropertiesTarget(item, sheet)
    elseif sheet then
        self:setSheetPropertiesTarget(sheet)
    else
        self.editor:clearPropertiesTarget(self)
    end
    if self.panel then self.panel:refresh() end
    if self.task_panel then self.task_panel:refresh() end
end

function DraftOverlayPlugin:setSheetPropertiesTarget(sheet)
    self.editor:setPropertiesTarget({
        title = "Draft Sheet: " .. tostring(sheet.name),
        history_owner = self.store,
        fields = {
            EditorPropertyFields.value(sheet, "Name", "name"),
            EditorPropertyFields.number(sheet, "Opacity", "opacity", {
                on_set = function(value)
                    sheet.opacity = MathUtils.clamp(value, 0, 1)
                end
            }),
            EditorPropertyFields.choice(sheet, "Placement", "placement", {
                { label = "Under Maps", value = "underlay" },
                { label = "Over Maps", value = "overlay" }
            }),
            EditorPropertyFields.choice(sheet, "Visible", "visible", {
                { label = "Yes", value = true },
                { label = "No", value = false }
            }),
            EditorPropertyFields.choice(sheet, "Locked", "locked", {
                { label = "Yes", value = true },
                { label = "No", value = false }
            })
        },
        on_changed = function()
            self.store:save()
            if self.panel then self.panel:refresh() end
        end
    }, self)
end

function DraftOverlayPlugin:resizePointItem(item, width, height)
    local old_width, old_height = math.max(1, item.width or 1), math.max(1, item.height or 1)
    width, height = math.max(1, width or old_width), math.max(1, height or old_height)
    for _, point in ipairs(item.points or {}) do
        point.x = (point.x or 0) * width / old_width
        point.y = (point.y or 0) * height / old_height
    end
    item.width, item.height = width, height
end

function DraftOverlayPlugin:setItemPropertiesTarget(item, sheet)
    local width_field = EditorPropertyFields.number(item, "Width", "width", {
        on_set = function(value) item.width = math.max(1, value) end
    })
    local height_field = EditorPropertyFields.number(item, "Height", "height", {
        on_set = function(value) item.height = math.max(1, value) end
    })
    if item.points then
        width_field.set = function(value)
            value = tonumber(value)
            if not value then return false end
            self:resizePointItem(item, value, nil)
            return true
        end
        height_field.set = function(value)
            value = tonumber(value)
            if not value then return false end
            self:resizePointItem(item, nil, value)
            return true
        end
    end
    local fields = {
        EditorPropertyFields.value(item, "Name", "name"),
        { label = "Type", readonly = true, get = function() return StringUtils.titleCase(item.kind) end,
            set = function() return false end },
        EditorPropertyFields.number(item, "X", "x"),
        EditorPropertyFields.number(item, "Y", "y"),
        width_field,
        height_field,
        EditorPropertyFields.number(item, "Rotation", "rotation"),
        EditorPropertyFields.number(item, "Opacity", "opacity", {
            on_set = function(value) item.opacity = MathUtils.clamp(value, 0, 1) end
        }),
        EditorPropertyFields.color(item, "Color", "color")
    }
    if item.kind == "image" then
        table.insert(fields, EditorPropertyFields.assetPath(item, "Image", "image", {
            path_root = "assets/sprites",
            asset_categories = { "sprites" },
            asset_registry = "texture",
            extensions = { "png", "jpg", "jpeg", "bmp", "tga", "webp" },
            strip_extension = true,
            on_set = function(value)
                if item.natural_size then
                    local texture = Assets.resolveTextureReference(value)
                    if texture then
                        item.width, item.height = texture:getWidth(), texture:getHeight()
                        item.natural_size = nil
                    end
                end
            end
        }))
    elseif item.kind == "note" then
        table.insert(fields, EditorPropertyFields.choice(item, "Zoom Behavior", "fixed_zoom", {
            { label = "Scale With Map", value = false },
            { label = "Fixed Screen Size", value = true }
        }, { default = false }))
        local text = EditorPropertyFields.value(item, "Text", "text")
        text.multiline = true
        table.insert(fields, text)
    end
    self.editor:setPropertiesTarget({
        title = "Draft: " .. tostring(item.name),
        history_owner = self.store,
        fields = fields,
        on_changed = function()
            self.store:save()
            if self.panel then self.panel:refresh() end
        end
    }, self)
end

function DraftOverlayPlugin:beginCreate(kind, scope)
    local view = self.editor.active_document and self.editor.active_document.map_view
    if not view then
        self.editor:addWarning("Open a map or world before adding a draft", nil, "draft_overlay")
        return false
    end
    local sheet = self:getActiveSheet(view, scope)
    if not sheet then
        if not self:createSheet(scope) then return false end
        sheet = self:getActiveSheet(view, scope)
    end
    if sheet and sheet.locked then
        self.editor:addWarning("Unlock the active draft sheet before adding to it",
            nil, "draft_overlay")
        return false
    end
    local tool_id = self.tool_ids[kind]
    if tool_id then
        self.create_mode = nil
        self.editor:setActiveTool(tool_id)
    else
        self.editor:setActiveTool(self.tool_ids.select)
        self.create_mode = { kind = kind, scope = scope }
    end
    if self.editor.message_bar then
        local action = kind == "note" and "click to place"
            or kind == "line" and "click two points"
            or kind == "polygon" and "click vertices; double-click or right-click to finish"
            or "drag to size"
        self.editor.message_bar:setStatus("Draft " .. StringUtils.titleCase(kind) .. ": " .. action)
    end
    return true
end

function DraftOverlayPlugin:createItem(kind, scope, context_id, sheet, x, y, width, height)
    local item = {
        id = self.store:nextId(kind),
        kind = kind,
        name = kind == "image" and "Reference Image"
            or kind == "note" and "Note"
            or kind == "ellipse" and "Ellipse"
            or kind == "line" and "Line"
            or kind == "polygon" and "Polygon" or "Box",
        x = x,
        y = y,
        width = width,
        height = height,
        rotation = 0,
        opacity = 1,
        color = kind == "image" and "#FFFFFFFF"
            or kind == "note" and "#FFD95CFF" or "#55A9FFFF"
    }
    if kind == "image" then
        item.image = ""
        item.natural_size = true
    elseif kind == "note" then
        item.text = "Draft note"
        item.fixed_zoom = false
    end
    table.insert(sheet.items, item)
    self:selectItem(scope, context_id, sheet, item)
    return item
end

function DraftOverlayPlugin:createPointItem(view, kind, scope, context_id, sheet, points)
    local min_x, min_y, max_x, max_y
    for _, point in ipairs(points) do
        min_x = min_x and math.min(min_x, point.x) or point.x
        min_y = min_y and math.min(min_y, point.y) or point.y
        max_x = max_x and math.max(max_x, point.x) or point.x
        max_y = max_y and math.max(max_y, point.y) or point.y
    end
    if not min_x then return nil end
    local origin_x, origin_y = self:getScopeOrigin(view, scope, context_id)
    local item = self:createItem(kind, scope, context_id, sheet,
        min_x - origin_x, min_y - origin_y,
        math.max(1, max_x - min_x), math.max(1, max_y - min_y))
    item.points = {}
    for _, point in ipairs(points) do
        table.insert(item.points, { x = point.x - min_x, y = point.y - min_y })
    end
    return item
end

function DraftOverlayPlugin:duplicateItem(scope, context_id, sheet, item)
    local duplicate
    self:perform("Duplicate Draft", function()
        duplicate = TableUtils.copy(item, true)
        duplicate.id = self.store:nextId(item.kind)
        duplicate.name = tostring(item.name or StringUtils.titleCase(item.kind)) .. " Copy"
        duplicate.x = (duplicate.x or 0) + 16
        duplicate.y = (duplicate.y or 0) + 16
        table.insert(sheet.items, duplicate)
        return true
    end)
    if duplicate then self:selectItem(scope, context_id, sheet, duplicate) end
    return duplicate ~= nil
end

function DraftOverlayPlugin:deleteItem(scope, context_id, sheet, item)
    if not item then return false end
    return self:perform("Delete Draft", function()
        self.store:removeItem(scope, context_id, sheet.id, item.id)
        if self.selected and self.selected.item_id == item.id then
            self.selected = nil
            self.editor:clearPropertiesTarget(self)
        end
        return true
    end)
end

function DraftOverlayPlugin:getScopeOrigin(view, scope, context_id)
    if scope == "map" then
        local entry = view.document and view.document.map_lookup[context_id]
        return entry and entry.x or 0, entry and entry.y or 0
    end
    return 0, 0
end

function DraftOverlayPlugin:snapToMapGrid(view, scope, context_id, world_x, world_y)
    local document = view.document
    local entry = scope == "map" and document and document.map_lookup[context_id]
        or view:getMapAt(world_x, world_y)
    entry = entry or document and document.map_lookup[view:getFocusedMapId()]
        or document and document:getPrimaryMap()
    if not entry then return world_x, world_y end
    world_x, world_y = view:snapToMapGrid(entry, world_x, world_y)
    return world_x, world_y, entry
end

function DraftOverlayPlugin:getItemRect(view, scope, context_id, item)
    local origin_x, origin_y = self:getScopeOrigin(view, scope, context_id)
    local scale = item.kind == "note" and item.fixed_zoom == true
        and math.max(view.view_zoom or 1, 0.001) or 1
    return origin_x + (item.x or 0), origin_y + (item.y or 0),
        math.max(1, item.width or 1) / scale, math.max(1, item.height or 1) / scale
end

function DraftOverlayPlugin:isPointNearSegment(x, y, first, second, distance)
    local x1, y1 = MapUtils.getPointCoordinates(first)
    local x2, y2 = MapUtils.getPointCoordinates(second)
    local dx, dy = x2 - x1, y2 - y1
    local length = dx * dx + dy * dy
    local amount = length > 0 and MathUtils.clamp(
        ((x - x1) * dx + (y - y1) * dy) / length, 0, 1) or 0
    return MathUtils.dist(x, y, x1 + dx * amount, y1 + dy * amount) <= distance
end

function DraftOverlayPlugin:containsItem(view, scope, context_id, item, world_x, world_y)
    local x, y, width, height = self:getItemRect(view, scope, context_id, item)
    local center_x, center_y = x + width / 2, y + height / 2
    local rotation = -math.rad(item.rotation or 0)
    local relative_x, relative_y = world_x - center_x, world_y - center_y
    local local_x = relative_x * math.cos(rotation) - relative_y * math.sin(rotation)
    local local_y = relative_x * math.sin(rotation) + relative_y * math.cos(rotation)
    if item.kind == "line" and item.points and #item.points >= 2 then
        return self:isPointNearSegment(local_x + width / 2, local_y + height / 2,
            item.points[1], item.points[2], 7 / view.view_zoom)
    end
    if item.kind == "polygon" and item.points and #item.points >= 3 then
        local point_x, point_y = local_x + width / 2, local_y + height / 2
        if MapUtils.pointInPolygon(point_x, point_y, item.points) then return true end
        local previous = item.points[#item.points]
        for _, point in ipairs(item.points) do
            if self:isPointNearSegment(point_x, point_y, previous, point,
                7 / view.view_zoom) then return true end
            previous = point
        end
        return false
    end
    return math.abs(local_x) <= width / 2 and math.abs(local_y) <= height / 2
end

function DraftOverlayPlugin:findItemAt(view, world_x, world_y)
    local scopes = { "map", "world" }
    for _, placement in ipairs({ "overlay", "underlay" }) do
        for _, scope in ipairs(scopes) do
            local context_id = scope == "world" and self:getWorldId(view) or view:getFocusedMapId()
            local context = context_id and self.store:getContext(scope, context_id, false)
            for sheet_index = 1, #(context and context.sheets or {}) do
                local sheet = context.sheets[sheet_index]
                if sheet.visible ~= false and not sheet.locked
                    and (sheet.placement or "underlay") == placement then
                    for item_index = 1, #(sheet.items or {}) do
                        local item = sheet.items[item_index]
                        if self:containsItem(view, scope, context_id, item, world_x, world_y) then
                            return item, sheet, scope, context_id
                        end
                    end
                end
            end
        end
    end
end

function DraftOverlayPlugin:isResizeHandleAt(view, item, scope, context_id, world_x, world_y)
    if (item.rotation or 0) % 360 ~= 0 then return false end
    local x, y, width, height = self:getItemRect(view, scope, context_id, item)
    local radius = 7 / view.view_zoom
    return math.abs(world_x - x - width) <= radius and math.abs(world_y - y - height) <= radius
end

function DraftOverlayPlugin:cancelPointBuild(view)
    local build = self.point_builds[view]
    if not build then return false end
    self.point_builds[view] = nil
    self.editor:cancelHistoryTransaction()
    return true
end

function DraftOverlayPlugin:finishPointBuild(view)
    local build = self.point_builds[view]
    if not build then return false end
    local minimum = build.item_kind == "polygon" and 3 or 2
    if #build.points < minimum then return self:cancelPointBuild(view) end
    local sheet = self.store:getSheet(build.scope, build.context_id, build.sheet_id)
    if not sheet then return self:cancelPointBuild(view) end
    self.point_builds[view] = nil
    self:createPointItem(view, build.item_kind, build.scope,
        build.context_id, sheet, build.points)
    self.editor:markHistoryChanged()
    self.store:save()
    self.editor:commitHistoryTransaction()
    return true
end

function DraftOverlayPlugin:addPointShapeVertex(view, kind, scope, context_id, sheet,
        world_x, world_y, presses)
    local build = self.point_builds[view]
    if not build then
        self.editor:beginHistoryTransaction("Create Draft " .. StringUtils.titleCase(kind), self.store)
        build = {
            item_kind = kind,
            scope = scope,
            context_id = context_id,
            sheet_id = sheet.id,
            points = {}
        }
        self.point_builds[view] = build
    end
    world_x, world_y = self:snapToMapGrid(
        view, build.scope, build.context_id, world_x, world_y)
    local first = build.points[1]
    if kind == "polygon" and #build.points >= 3 and first
        and MathUtils.dist(world_x, world_y, first.x, first.y) <= 9 / view.view_zoom then
        return self:finishPointBuild(view)
    end
    local previous = build.points[#build.points]
    if not previous or previous.x ~= world_x or previous.y ~= world_y then
        table.insert(build.points, { x = world_x, y = world_y })
    end
    build.current_x, build.current_y = world_x, world_y
    if kind == "line" and #build.points >= 2 then return self:finishPointBuild(view) end
    if kind == "polygon" and presses and presses >= 2 and #build.points >= 3 then
        return self:finishPointBuild(view)
    end
    return true
end

function DraftOverlayPlugin:onMapMousePressed(view, x, y, button, presses)
    local world_x, world_y = view:getMapCoordinates(x, y)
    if button == 2 then
        local build = self.point_builds[view]
        if build then
            if build.item_kind == "polygon" and #build.points >= 3 then
                return self:finishPointBuild(view)
            end
            return self:cancelPointBuild(view)
        end
        local transient_create = self.create_mode ~= nil
        self.create_mode = nil
        if transient_create then self.editor:setActiveTool(self.tool_ids.select) end
        local item, sheet, scope, context_id = self:findItemAt(view, world_x, world_y)
        if not item then return true end
        self:selectItem(scope, context_id, sheet, item)
        local global_x, global_y = view:getGlobalPosition()
        local link = self.tasks:getDraftLink(scope, context_id, sheet.id, item.id)
        self.editor.dockspace:openContextMenu({
            {
                label = "Link to Task",
                children = self.tasks:getTaskLinkMenuItems(link)
            },
            {
                label = "Create Linked Task",
                action = function()
                    local task = self.tasks:createTask(nil, link)
                    if task then self:showTaskPanel() end
                end
            },
            { label = "Duplicate", action = function()
                self:duplicateItem(scope, context_id, sheet, item)
            end },
            { label = "Delete", action = function()
                self:deleteItem(scope, context_id, sheet, item)
            end }
        }, global_x + x, global_y + y, view)
        return true
    end

    if not self.point_builds[view] then
        view:focusInteractionMap(world_x, world_y, self.editor.active_tool, false)
    end

    local tool_kind = self.tool_kinds[self.editor.active_tool]
    if self.create_mode or tool_kind then
        local transient_create = self.create_mode ~= nil
        local kind = transient_create and self.create_mode.kind or tool_kind
        local scope = transient_create and self.create_mode.scope
            or self.panel and self.panel.scope or "map"
        local sheet, context_id = self:getActiveSheet(view, scope)
        if not sheet then
            if not self:createSheet(scope) then return true end
            sheet, context_id = self:getActiveSheet(view, scope)
        end
        if not sheet or sheet.locked then return true end
        if kind == "line" or kind == "polygon" then
            return self:addPointShapeVertex(view, kind, scope, context_id, sheet,
                world_x, world_y, presses)
        end
        local grid_entry
        if kind == "box" or kind == "ellipse" then
            world_x, world_y, grid_entry = self:snapToMapGrid(
                view, scope, context_id, world_x, world_y)
        end
        self.editor:beginHistoryTransaction("Create Draft " .. StringUtils.titleCase(kind), self.store)
        if kind == "note" then
            local origin_x, origin_y = self:getScopeOrigin(view, scope, context_id)
            local item = self:createItem("note", scope, context_id, sheet,
                world_x - origin_x, world_y - origin_y, 180, 64)
            self.editor:markHistoryChanged()
            self.store:save()
            self.editor:commitHistoryTransaction()
            if transient_create then
                self.create_mode = nil
                self.editor:setActiveTool(self.tool_ids.select)
            end
            return item ~= nil
        end
        self.drags[view] = {
            kind = "create",
            item_kind = kind,
            scope = scope,
            context_id = context_id,
            sheet_id = sheet.id,
            transient_create = transient_create,
            grid_width = grid_entry and grid_entry.tile_width,
            grid_height = grid_entry and grid_entry.tile_height,
            start_x = world_x,
            start_y = world_y,
            current_x = world_x,
            current_y = world_y
        }
        return true
    end

    local selected_item, selected_sheet = self:resolveSelection()
    if selected_item and selected_sheet and not selected_sheet.locked
        and self:isResizeHandleAt(view, selected_item, self.selected.scope,
            self.selected.context_id, world_x, world_y) then
        self.editor:beginHistoryTransaction("Resize Draft", self.store)
        self.drags[view] = {
            kind = "resize",
            scope = self.selected.scope,
            context_id = self.selected.context_id,
            sheet_id = selected_sheet.id,
            item_id = selected_item.id,
            original_width = selected_item.width,
            original_height = selected_item.height,
            original_points = selected_item.points and TableUtils.copy(selected_item.points, true),
            fixed_zoom = selected_item.kind == "note" and selected_item.fixed_zoom == true,
            view_zoom = view.view_zoom or 1,
            start_x = world_x,
            start_y = world_y,
            changed = false
        }
        return true
    end

    local item, sheet, scope, context_id = self:findItemAt(view, world_x, world_y)
    if not item then
        self.selected = nil
        self.editor:clearPropertiesTarget(self)
        if self.panel then self.panel:refresh() end
        return true
    end
    self:selectItem(scope, context_id, sheet, item)
    self.editor:beginHistoryTransaction("Move Draft", self.store)
    self.drags[view] = {
        kind = "move",
        item_kind = item.kind,
        scope = scope,
        context_id = context_id,
        sheet_id = sheet.id,
        item_id = item.id,
        original_x = item.x or 0,
        original_y = item.y or 0,
        start_x = world_x,
        start_y = world_y,
        changed = false
    }
    return true
end

function DraftOverlayPlugin:onMapMouseMoved(view, x, y)
    local world_x, world_y = view:getMapCoordinates(x, y)
    local build = self.point_builds[view]
    if build then
        build.current_x, build.current_y = self:snapToMapGrid(
            view, build.scope, build.context_id, world_x, world_y)
        return true
    end
    local drag = self.drags[view]
    if not drag then return false end
    if drag.kind == "create" then
        if drag.item_kind == "box" or drag.item_kind == "ellipse" then
            world_x, world_y = self:snapToMapGrid(
                view, drag.scope, drag.context_id, world_x, world_y)
        end
        drag.current_x, drag.current_y = world_x, world_y
        return true
    end
    local item = self.store:getItem(drag.scope, drag.context_id, drag.sheet_id, drag.item_id)
    if not item then return true end
    local delta_x, delta_y = world_x - drag.start_x, world_y - drag.start_y
    if drag.kind == "move" then
        if item.kind == "box" or item.kind == "ellipse"
            or item.kind == "line" or item.kind == "polygon" then
            local origin_x, origin_y = self:getScopeOrigin(view, drag.scope, drag.context_id)
            local snapped_x, snapped_y = self:snapToMapGrid(view, drag.scope, drag.context_id,
                origin_x + drag.original_x + delta_x, origin_y + drag.original_y + delta_y)
            item.x, item.y = snapped_x - origin_x, snapped_y - origin_y
        else
            item.x = drag.original_x + delta_x
            item.y = drag.original_y + delta_y
        end
    elseif drag.kind == "resize" then
        if item.kind == "box" or item.kind == "ellipse"
            or item.kind == "line" or item.kind == "polygon" then
            local origin_x, origin_y = self:getScopeOrigin(view, drag.scope, drag.context_id)
            local item_x, item_y = origin_x + (item.x or 0), origin_y + (item.y or 0)
            local right, bottom = self:snapToMapGrid(view, drag.scope, drag.context_id,
                item_x + drag.original_width + delta_x,
                item_y + drag.original_height + delta_y)
            local width, height = math.max(1, right - item_x), math.max(1, bottom - item_y)
            if item.points then
                self:resizePointItem(item, width, height)
            else
                item.width, item.height = width, height
            end
        else
            local resize_scale = drag.fixed_zoom and drag.view_zoom or 1
            item.width = math.max(1, drag.original_width + delta_x * resize_scale)
            item.height = math.max(1, drag.original_height + delta_y * resize_scale)
        end
        item.natural_size = nil
    end
    drag.changed = drag.changed or math.abs(delta_x) + math.abs(delta_y) > 0.01
    return true
end

function DraftOverlayPlugin:onMapMouseReleased(view, x, y)
    local drag = self.drags[view]
    self.drags[view] = nil
    if not drag then return false end
    if drag.kind == "create" then
        local sheet = self.store:getSheet(drag.scope, drag.context_id, drag.sheet_id)
        if not sheet then
            self.editor:cancelHistoryTransaction()
            return true
        end
        local x1, y1 = math.min(drag.start_x, drag.current_x), math.min(drag.start_y, drag.current_y)
        local width = math.abs(drag.current_x - drag.start_x)
        local height = math.abs(drag.current_y - drag.start_y)
        if width < 4 / view.view_zoom or height < 4 / view.view_zoom then
            if drag.item_kind == "image" then
                width, height = 320, 180
            else
                width, height = drag.grid_width or 40, drag.grid_height or 40
            end
            x1, y1 = drag.start_x, drag.start_y
        end
        local origin_x, origin_y = self:getScopeOrigin(view, drag.scope, drag.context_id)
        self:createItem(drag.item_kind, drag.scope, drag.context_id, sheet,
            x1 - origin_x, y1 - origin_y, width, height)
        self.editor:markHistoryChanged()
        self.store:save()
        self.editor:commitHistoryTransaction()
        if drag.transient_create then
            self.create_mode = nil
            self.editor:setActiveTool(self.tool_ids.select)
        end
        return true
    end
    if drag.changed then
        self.editor:markHistoryChanged()
        self.store:save()
        self.editor:commitHistoryTransaction()
        local item, sheet = self:resolveSelection()
        if item then self:setItemPropertiesTarget(item, sheet) end
    else
        self.editor:cancelHistoryTransaction()
    end
    return true
end

function DraftOverlayPlugin:cancelInteraction(view)
    if self:cancelPointBuild(view) then return true end
    local transient_create = self.create_mode ~= nil
    self.create_mode = nil
    local drag = self.drags[view]
    if not drag then
        if self.tool_kinds[self.editor.active_tool] then
            self.editor:setActiveTool(self.tool_ids.select)
        end
        return true
    end
    self.drags[view] = nil
    if drag.kind == "move" or drag.kind == "resize" then
        local item = self.store:getItem(drag.scope, drag.context_id, drag.sheet_id, drag.item_id)
        if item then
            if drag.kind == "move" then
                item.x, item.y = drag.original_x, drag.original_y
            else
                item.width, item.height = drag.original_width, drag.original_height
                if drag.original_points then
                    item.points = TableUtils.copy(drag.original_points, true)
                end
            end
        end
    end
    self.editor:cancelHistoryTransaction()
    if transient_create or drag.transient_create then
        self.editor:setActiveTool(self.tool_ids.select)
    end
    return true
end

function DraftOverlayPlugin:getMapCursorType(view, x, y)
    local drag = self.drags[view]
    if drag then return drag.kind == "resize" and "resize_diag_r" or "grab" end
    if self.create_mode or self.tool_kinds[self.editor.active_tool] then return "crosshair" end
    local world_x, world_y = view:getMapCoordinates(x, y)
    local item, sheet, scope, context_id = self:findItemAt(view, world_x, world_y)
    if item and self.selected and self.selected.item_id == item.id
        and self:isResizeHandleAt(view, item, scope, context_id, world_x, world_y) then
        return "resize_diag_r"
    end
    return item and not sheet.locked and "grab" or "default"
end

function DraftOverlayPlugin:drawItem(view, scope, context_id, sheet, item)
    local x, y, width, height = self:getItemRect(view, scope, context_id, item)
    local color = ColorUtils.tryHexToRGB(item.color or "#FFFFFFFF") or { 1, 1, 1, 1 }
    local opacity = MathUtils.clamp((sheet.opacity or 1) * (item.opacity or 1), 0, 1)
    local fixed_note = item.kind == "note" and item.fixed_zoom == true
    local old_line_width
    love.graphics.push()
    love.graphics.translate(x + width / 2, y + height / 2)
    love.graphics.rotate(math.rad(item.rotation or 0))
    if fixed_note then
        old_line_width = love.graphics.getLineWidth()
        love.graphics.scale(1 / math.max(view.view_zoom or 1, 0.001))
        width = math.max(1, item.width or 1)
        height = math.max(1, item.height or 1)
        love.graphics.setLineWidth(2)
    end
    if item.kind == "image" then
        local texture = Assets.resolveTextureReference(item.image or "")
        if texture then
            Draw.setColor(color[1], color[2], color[3], (color[4] or 1) * opacity)
            love.graphics.draw(texture, -width / 2, -height / 2, 0,
                width / texture:getWidth(), height / texture:getHeight())
        else
            Draw.setColor(0.14, 0.18, 0.24, 0.72 * opacity)
            love.graphics.rectangle("fill", -width / 2, -height / 2, width, height)
            Draw.setColor(color[1], color[2], color[3], opacity)
            love.graphics.rectangle("line", -width / 2, -height / 2, width, height)
            love.graphics.line(-width / 2, -height / 2, width / 2, height / 2)
            love.graphics.line(width / 2, -height / 2, -width / 2, height / 2)
        end
    elseif item.kind == "note" then
        Draw.setColor(0.08, 0.08, 0.09, 0.84 * opacity)
        love.graphics.rectangle("fill", -width / 2, -height / 2, width, height)
        Draw.setColor(color[1], color[2], color[3], opacity)
        love.graphics.rectangle("line", -width / 2, -height / 2, width, height)
        love.graphics.setFont(EditorFont.get(14))
        love.graphics.printf(tostring(item.text or ""), -width / 2 + 8, -height / 2 + 7,
            math.max(0, width - 16), "left")
    elseif item.kind == "line" then
        local points = {}
        for _, point in ipairs(item.points or {}) do
            table.insert(points, (point.x or 0) - width / 2)
            table.insert(points, (point.y or 0) - height / 2)
        end
        if #points >= 4 then
            Draw.setColor(color[1], color[2], color[3], opacity)
            love.graphics.line(points)
        end
    elseif item.kind == "polygon" then
        local points = {}
        for _, point in ipairs(item.points or {}) do
            table.insert(points, (point.x or 0) - width / 2)
            table.insert(points, (point.y or 0) - height / 2)
        end
        if #points >= 6 then
            Draw.setColor(color[1], color[2], color[3], 0.18 * opacity)
            love.graphics.polygon("fill", points)
            Draw.setColor(color[1], color[2], color[3], opacity)
            love.graphics.polygon("line", points)
        end
    elseif item.kind == "ellipse" then
        Draw.setColor(color[1], color[2], color[3], 0.18 * opacity)
        love.graphics.ellipse("fill", 0, 0, width / 2, height / 2)
        Draw.setColor(color[1], color[2], color[3], opacity)
        love.graphics.ellipse("line", 0, 0, width / 2, height / 2)
    else
        Draw.setColor(color[1], color[2], color[3], 0.18 * opacity)
        love.graphics.rectangle("fill", -width / 2, -height / 2, width, height)
        Draw.setColor(color[1], color[2], color[3], opacity)
        love.graphics.rectangle("line", -width / 2, -height / 2, width, height)
    end
    if old_line_width then love.graphics.setLineWidth(old_line_width) end
    love.graphics.pop()
end

function DraftOverlayPlugin:drawContext(view, scope, context_id, placement)
    local context = context_id and self.store:getContext(scope, context_id, false)
    local sheets = context and context.sheets or {}
    for sheet_index = #sheets, 1, -1 do
        local sheet = sheets[sheet_index]
        if sheet.visible ~= false and (sheet.placement or "underlay") == placement then
            for item_index = #(sheet.items or {}), 1, -1 do
                self:drawItem(view, scope, context_id, sheet, sheet.items[item_index])
            end
        end
    end
end

function DraftOverlayPlugin:drawDrafts(view, placement)
    local document = view.document
    local primary = view:getPrimaryEntry()
    if not document or not primary then return end
    love.graphics.push()
    love.graphics.translate(view.canvas_x, view.canvas_y)
    love.graphics.scale(view.view_zoom, view.view_zoom)
    love.graphics.translate(-primary.x, -primary.y)
    local old_width = love.graphics.getLineWidth()
    love.graphics.setLineWidth(2 / view.view_zoom)
    local world_id = self:getWorldId(view)
    if world_id then self:drawContext(view, "world", world_id, placement) end
    for _, entry in ipairs(document.maps or {}) do
        self:drawContext(view, "map", entry.id, placement)
    end
    love.graphics.setLineWidth(old_width)
    Draw.setColor(1, 1, 1, 1)
    love.graphics.pop()
end

function DraftOverlayPlugin:drawInteraction(view)
    if not self:isActive(view) then return end
    local primary = view:getPrimaryEntry()
    if not primary then return end
    love.graphics.push()
    love.graphics.translate(view.canvas_x, view.canvas_y)
    love.graphics.scale(view.view_zoom, view.view_zoom)
    love.graphics.translate(-primary.x, -primary.y)
    local old_width = love.graphics.getLineWidth()
    love.graphics.setLineWidth(2 / view.view_zoom)

    local item = self:resolveSelection()
    local selection_in_view = self.selected and (self.selected.scope == "world"
        and self.selected.context_id == self:getWorldId(view)
        or self.selected.scope == "map"
        and view.document and view.document.map_lookup[self.selected.context_id] ~= nil)
    if item and selection_in_view then
        local x, y, width, height = self:getItemRect(view, self.selected.scope,
            self.selected.context_id, item)
        love.graphics.push()
        love.graphics.translate(x + width / 2, y + height / 2)
        love.graphics.rotate(math.rad(item.rotation or 0))
        Draw.setColor(1, 0.84, 0.22, 1)
        love.graphics.rectangle("line", -width / 2, -height / 2, width, height)
        if (item.rotation or 0) % 360 == 0 then
            local handle = 8 / view.view_zoom
            love.graphics.rectangle("fill", width / 2 - handle / 2,
                height / 2 - handle / 2, handle, handle)
        end
        love.graphics.pop()
    end

    local drag = self.drags[view]
    if drag and drag.kind == "create" then
        local x1, y1 = math.min(drag.start_x, drag.current_x), math.min(drag.start_y, drag.current_y)
        local width, height = math.abs(drag.current_x - drag.start_x),
            math.abs(drag.current_y - drag.start_y)
        Draw.setColor(0.45, 0.75, 1, 0.25)
        love.graphics.rectangle("fill", x1, y1, width, height)
        Draw.setColor(0.45, 0.75, 1, 0.95)
        love.graphics.rectangle("line", x1, y1, width, height)
    end

    local build = self.point_builds[view]
    if build then
        local points = {}
        for _, point in ipairs(build.points) do
            table.insert(points, point.x)
            table.insert(points, point.y)
        end
        local previous = build.points[#build.points]
        if build.current_x and (not previous
            or previous.x ~= build.current_x or previous.y ~= build.current_y) then
            table.insert(points, build.current_x)
            table.insert(points, build.current_y)
        end
        if build.item_kind == "polygon" and #points >= 6 then
            Draw.setColor(0.45, 0.75, 1, 0.18)
            love.graphics.polygon("fill", points)
        end
        if #points >= 4 then
            Draw.setColor(0.45, 0.75, 1, 0.95)
            love.graphics.line(points)
            if build.item_kind == "polygon" and #build.points >= 2 then
                love.graphics.line(points[#points - 1], points[#points],
                    build.points[1].x, build.points[1].y)
            end
        end
        local handle = 5 / view.view_zoom
        Draw.setColor(0.72, 0.86, 1, 1)
        for _, point in ipairs(build.points) do
            love.graphics.rectangle("fill", point.x - handle / 2,
                point.y - handle / 2, handle, handle)
        end
    end

    love.graphics.setLineWidth(old_width)
    Draw.setColor(1, 1, 1, 1)
    love.graphics.pop()
end

return DraftOverlayPlugin
