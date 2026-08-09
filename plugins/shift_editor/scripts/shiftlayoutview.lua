---@class EditorShiftLayoutView : EditorMapView
---@overload fun(editor: Editor, document: EditorShiftLayoutDocument): EditorShiftLayoutView
local EditorShiftLayoutView, super = Class(EditorMapView)

function EditorShiftLayoutView:activate()
    if not self.editor then return false end
    self.editor:activateMapDocument(self.document, { select_panel = false, set_mode = false })
    if not self.editor.tile_editing_mode then self.editor:setTileEditingMode(true) end
    if #(self.editor:getSelectedMapObjects(self.document) or {}) == 0 then
        self.editor:setPropertiesTarget(self.document:getPropertiesTarget(), self)
    end
    return true
end

function EditorShiftLayoutView:onFocus()
    if not self.editor.suppress_panel_activation then self:activate() end
end

function EditorShiftLayoutView:onMousePressed(x, y, button, presses)
    local consumed = super.onMousePressed(self, x, y, button, presses)
    if button == 1 and #(self.editor:getSelectedMapObjects(self.document) or {}) == 0 then
        self.editor:setPropertiesTarget(self.document:getPropertiesTarget(), self)
    end
    return consumed
end

return EditorShiftLayoutView
