---@class DraftOverlayStore
---@field data table
---@field editor Editor
---@field filename string?
---@field history_revision number
---@field legacy_filename string
---@field plugin DraftOverlayPlugin
---@field saved_history_revision number
local DraftOverlayStore = Class()

function DraftOverlayStore:init(plugin, editor)
    self.plugin = plugin
    self.editor = editor
    self.history_revision = 0
    self.saved_history_revision = 0
    local project_id = tostring(editor.project_id or Mod and Mod.info and Mod.info.id or "project")
    local filename = project_id:gsub("[^%w%._%-]", "_")
    self.filename = Mod and Mod.info and Mod.info.path
        and Mod.info.path .. "/editor/drafts.json" or nil
    self.legacy_filename = "editor/drafts/" .. filename .. ".json"
    self.data = { version = 1, next_id = 1, maps = {}, worlds = {}, tasks = {} }
    self:load()
end

function DraftOverlayStore:load()
    local contents, reason
    local migrate = false
    if self.filename and love.filesystem.getInfo(self.filename, "file") then
        contents, reason = ProjectFileSystem.readFile(self.filename)
        if not contents then
            self.editor:addWarning("Could not load draft overlays", tostring(reason), "draft_overlay")
            return false
        end
    else
        contents = love.filesystem.read(self.legacy_filename)
        migrate = contents ~= nil
    end
    if not contents then return false end
    local success, data = pcall(JSON.decode, contents)
    if not success or type(data) ~= "table" then
        self.editor:addWarning("Could not load draft overlays",
            success and "The draft file does not contain a JSON object." or tostring(data),
            "draft_overlay")
        return false
    end
    data.version = tonumber(data.version) or 1
    data.next_id = tonumber(data.next_id) or 1
    data.maps = type(data.maps) == "table" and data.maps or {}
    data.worlds = type(data.worlds) == "table" and data.worlds or {}
    data.tasks = type(data.tasks) == "table" and data.tasks or {}
    self.data = data
    self:normalizeTasks(data.tasks)
    if migrate then self:save() end
    return true
end

function DraftOverlayStore:normalizeTasks(tasks)
    for _, task in ipairs(tasks or {}) do
        task.id = task.id or self:nextId("task")
        task.name = tostring(task.name or "New Task")
        task.done = task.done == true
        task.expanded = task.expanded ~= false
        task.children = type(task.children) == "table" and task.children or {}
        self:normalizeTasks(task.children)
    end
end

function DraftOverlayStore:save()
    if not self.filename then
        self.editor:addWarning("Could not save draft overlays",
            "No writable project is loaded", "draft_overlay")
        return false
    end
    local success, encoded = pcall(JSON.encode, self.data)
    if not success then
        self.editor:addWarning("Could not encode draft overlays", tostring(encoded), "draft_overlay")
        return false
    end
    local written, reason = ProjectFileSystem.writeFile(self.filename, encoded)
    if not written then
        self.editor:addWarning("Could not save draft overlays", tostring(reason), "draft_overlay")
        return false
    end
    self.editor:clearDiagnostics("draft_overlay")
    return true
end

function DraftOverlayStore:captureHistoryState()
    return TableUtils.copy(self.data, true)
end

function DraftOverlayStore:restoreHistoryState(state)
    self.data = TableUtils.copy(state, true)
    self:save()
    self.plugin:onStoreRestored()
end

function DraftOverlayStore:nextId(prefix)
    local id = tostring(prefix or "draft") .. "_" .. tostring(self.data.next_id)
    self.data.next_id = self.data.next_id + 1
    return id
end

function DraftOverlayStore:getContext(scope, id, create)
    local contexts = scope == "world" and self.data.worlds or self.data.maps
    local context = contexts[id]
    if not context and create then
        context = { sheets = {} }
        contexts[id] = context
    end
    return context
end

function DraftOverlayStore:addSheet(scope, context_id, name, placement)
    local context = self:getContext(scope, context_id, true)
    local sheet = {
        id = self:nextId("sheet"),
        name = name or "Draft Sheet",
        visible = true,
        locked = false,
        opacity = 1,
        placement = placement or "underlay",
        expanded = true,
        items = {}
    }
    table.insert(context.sheets, sheet)
    return sheet
end

function DraftOverlayStore:getSheet(scope, context_id, sheet_id)
    local context = self:getContext(scope, context_id, false)
    for _, sheet in ipairs(context and context.sheets or {}) do
        if sheet.id == sheet_id then return sheet end
    end
end

function DraftOverlayStore:getItem(scope, context_id, sheet_id, item_id)
    local sheet = self:getSheet(scope, context_id, sheet_id)
    for _, item in ipairs(sheet and sheet.items or {}) do
        if item.id == item_id then return item, sheet end
    end
end

function DraftOverlayStore:removeSheet(scope, context_id, sheet_id)
    local context = self:getContext(scope, context_id, false)
    for index, sheet in ipairs(context and context.sheets or {}) do
        if sheet.id == sheet_id then
            table.remove(context.sheets, index)
            return sheet
        end
    end
end

function DraftOverlayStore:removeItem(scope, context_id, sheet_id, item_id)
    local sheet = self:getSheet(scope, context_id, sheet_id)
    for index, item in ipairs(sheet and sheet.items or {}) do
        if item.id == item_id then
            table.remove(sheet.items, index)
            return item
        end
    end
end

function DraftOverlayStore:addTask(parent, name)
    local task = {
        id = self:nextId("task"),
        name = name or "New Task",
        details = "",
        done = false,
        expanded = true,
        children = {}
    }
    if parent then parent.expanded = true end
    table.insert(parent and parent.children or self.data.tasks, task)
    return task
end

function DraftOverlayStore:findTask(id, tasks, parent)
    for index, task in ipairs(tasks or self.data.tasks) do
        if task.id == id then return task, tasks or self.data.tasks, index, parent end
        local found, list, found_index, found_parent = self:findTask(id, task.children, task)
        if found then return found, list, found_index, found_parent end
    end
end

function DraftOverlayStore:removeTask(id)
    local task, list, index = self:findTask(id)
    if not task then return nil end
    table.remove(list, index)
    return task
end

return DraftOverlayStore
