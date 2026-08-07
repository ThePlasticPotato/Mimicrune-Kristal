local EditorShiftLayoutDocument, EditorShiftLayoutView = ...

---@class ShiftLayoutDocumentProvider : EditorDocumentProvider
---@overload fun(plugin: ShiftEditorPlugin, editor: Editor, layer_types: table): ShiftLayoutDocumentProvider
local ShiftLayoutDocumentProvider, super = Class(EditorDocumentProvider)

function ShiftLayoutDocumentProvider:init(plugin, editor, layer_types)
    super.init(self, editor, { priority = 200 })
    self.plugin = plugin
    self.layer_types = layer_types
    self.documents = {}
    self.next_panel_id = 1
end

function ShiftLayoutDocumentProvider:supportsPath(path, file_type, options)
    local normalized = tostring(path or ""):gsub("\\", "/"):lower()
    local folder = normalized:match("/scripts/shift/layouts/([^/]+)/.+%.json$")
    return options.read_only ~= true
        and (folder == "offices" or folder == "cameras" or folder == "nights")
end

function ShiftLayoutDocumentProvider:createDocument(workspace, path, contents)
    local success, document = pcall(EditorShiftLayoutDocument,
        workspace, path, contents, self.layer_types)
    if success then return document end
    self.editor:addError("Could not open shift layout", document, "shift_layout")
    return nil
end

function ShiftLayoutDocumentProvider:supports(document)
    return isClass(document) and document:includes(EditorShiftLayoutDocument)
end

function ShiftLayoutDocumentProvider:activate(document, focus)
    if not document or not document.panel then return false end
    self.editor:activateMapDocument(document, { select_panel = false, set_mode = false })
    if not self.editor.tile_editing_mode then self.editor:setTileEditingMode(true) end
    if document.panel.stack then document.panel.stack:setActivePanel(document.panel) end
    if focus ~= false then self.editor.dockspace:setFocus(document.map_view) end
    return true
end

function ShiftLayoutDocumentProvider:open(document, options)
    if not document.panel then
        local view = EditorShiftLayoutView(self.editor, document)
        local panel_id = "shift_layout_document:" .. self.next_panel_id
        self.next_panel_id = self.next_panel_id + 1
        local panel = EditorPanel(panel_id, document.name, view, {
            minimum_width = 320,
            minimum_height = 240,
            preferred_width = 800,
            preferred_height = 600,
            on_remove = function() return self:close(document) end,
            on_activate = function() self:activate(document, false) end
        })
        document.panel, document.map_view, document.game_view = panel, view, view
        panel.map_document, panel.map_view = document, view
        table.insert(self.documents, document)
        self.editor.dockspace:registerPanel(panel, "center")
    end
    return self:activate(document, options.focus ~= false)
end

function ShiftLayoutDocumentProvider:isFocused()
    local focused = self.editor.dockspace and self.editor.dockspace.focused_control
    while focused do
        for _, document in ipairs(self.documents) do
            if focused == document.map_view then return true end
        end
        if self.editor.active_document and self:supports(self.editor.active_document)
            and (focused == self.editor.layers_browser or focused == self.editor.properties_browser) then
            return true
        end
        focused = focused.parent
    end
    return false
end

function ShiftLayoutDocumentProvider:getActive()
    local document = self.editor.active_document
    return document and self:supports(document) and document or nil
end

function ShiftLayoutDocumentProvider:close(document)
    if not document or not TableUtils.contains(self.documents, document) then return false end
    if document:isDirty() and not self.editor:confirmUnsavedChanges({
        dirty = true,
        save_label = "Save",
        message = "Save changes to '" .. document:getName() .. "' before closing it?",
        save = function() return document:save() end
    }) then return false end
    local panel = document.panel
    TableUtils.removeValue(self.documents, document)
    if panel then self.editor.dockspace:unregisterPanel(panel) end
    if self.editor.active_document == document then
        self.editor.active_document = nil
        if self.editor.layers_browser then self.editor.layers_browser:setDocument(nil) end
    end
    document.panel, document.map_view, document.game_view = nil, nil, nil
    return document.workspace:closeDocument(document, { discard = true })
end

function ShiftLayoutDocumentProvider:closeActive()
    local active = self:getActive()
    return active and self:close(active) or nil
end

function ShiftLayoutDocumentProvider:saveActive()
    local active = self:getActive()
    return active and active:save() or nil
end

function ShiftLayoutDocumentProvider:canSave()
    return self:getActive() ~= nil
end

function ShiftLayoutDocumentProvider:saveAll()
    for _, document in ipairs(self.documents) do
        if document:isDirty() then
            local saved, reason = document:save()
            if not saved then
                self.editor:addError("Could not save " .. document.relative_path,
                    reason, "shift_layout")
                return false
            end
        end
    end
    return true
end

function ShiftLayoutDocumentProvider:hasUnsavedChanges()
    for _, document in ipairs(self.documents) do
        if document:isDirty() then return true end
    end
    return false
end

function ShiftLayoutDocumentProvider:shutdown()
    for index = #self.documents, 1, -1 do
        local document = self.documents[index]
        if document.panel then self.editor.dockspace:unregisterPanel(document.panel) end
        document:release()
    end
    self.documents = {}
end

return ShiftLayoutDocumentProvider
