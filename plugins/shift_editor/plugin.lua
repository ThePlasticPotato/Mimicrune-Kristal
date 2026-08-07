---@class ShiftEditorPlugin : EditorPlugin
---@overload fun(info: table): ShiftEditorPlugin
local ShiftEditorPlugin, super = Class(EditorPlugin)

local KIND_FOLDERS = { office = "offices", camera = "cameras", night = "nights" }

local function namedObject(base, name, description, initialize)
    local object, object_super = Class(base)
    object.editor_name = name
    object.editor_description = description
    function object:init(data, options)
        object_super.init(self, data, options)
        if initialize then initialize(self) end
    end
    return object
end

function ShiftEditorPlugin:init(info)
    super.init(self, info)
end

function ShiftEditorPlugin:registerShiftObjects(EditorShiftObject, EditorShiftDraggable)
    local OfficeInteractableObject = namedObject(EditorShiftObject, "Office Interactable",
        "A clickable control positioned in an office layout.")
    local OfficeDoorObject = namedObject(EditorShiftObject, "Office Door",
        "A standard animatronic move target and office door.", function(object)
            object:registerProperty("target_id", "string", { name = "Door ID Override" })
            object:registerProperty("close_shake_x", "number", {
                name = "Close Impact Shake", default = 4, min = 0
            })
            object:registerProperty("close_shake_friction", "number", {
                name = "Close Shake Friction", default = 1, min = 0.01
            })
        end)
    local DoorLeverObject = namedObject(EditorShiftDraggable, "Office Door Lever",
        "A draggable door lever. The selected axis keeps its path perfectly straight.", function(object)
            object:registerProperty("door", "object_reference", {
                name = "Door Target", allowed_types = { "office_door" }, same_map = true
            })
            object:registerProperty("close_resistance", "number", {
                name = "Closing Resistance", default = 1.35, min = 0.01
            })
            object:registerProperty("open_resistance", "number", {
                name = "Opening Resistance", default = 1, min = 0.01
            })
            object:registerProperty("drag_inertia", "number", {
                name = "Drag Inertia", default = 0.65, min = 0, max = 0.99
            })
            object:registerProperty("auto_return", "boolean", {
                name = "Return When Released", default = true
            })
            object:registerProperty("return_delay", "number", {
                name = "Return Creak Delay", default = 0.2, min = 0
            })
            object:registerProperty("return_speed", "number", {
                name = "Return Speed", default = 0.45, min = 0.01
            })
            object:registerProperty("jam_limit", "number", {
                name = "Jammed Pull Limit", default = 0.5, min = 0, max = 1
            })
            object:registerProperty("jam_shake", "number", {
                name = "Jammed Lever Shake", default = 1, min = 0
            })
            object:registerProperty("jam_creak_interval", "number", {
                name = "Jammed Creak Interval", default = 0.65, min = 0.05
            })
        end)
    DoorLeverObject.editor_sprite = "ui/shift/objects/door_lever_left"
    local CameraInteractableObject = namedObject(EditorShiftObject, "Camera Interactable",
        "A clickable control positioned in a camera feed.")
    local CameraButtonObject = namedObject(EditorShiftObject, "Camera Map Button",
        "A camera selector placed on the night's camera map.", function(object)
            object:registerProperty("camera", "string", { name = "Camera ID" })
            object:registerProperty("label", "string", { name = "Label", default = "CAM" })
        end)
    local PanelButtonObject = namedObject(EditorShiftObject, "Shift Panel Button",
        "A rectangular shift panel button.")

    self:registerEditorObject("office_interactable", OfficeInteractableObject)
    self:registerEditorObject("draggable_office_interactable", EditorShiftDraggable)
    self:registerEditorObject("office_door_lever", DoorLeverObject)
    self:registerEditorObject("office_door", OfficeDoorObject)
    self:registerEditorObject("camera_interactable", CameraInteractableObject)
    self:registerEditorObject("camera_button", CameraButtonObject)
    self:registerEditorObject("panel_button", PanelButtonObject)
    self:registerEditorObjectProperty("sprite", "layout_id", "string", {
        name = "Layout ID", placeholder = "Stable runtime identifier"
    })
end

function ShiftEditorPlugin:openCreationDialog()
    local workspace = self.editor.project_workspace
    if not workspace then return false end
    return self.editor:openCreationDialog({
        title = "Create Shift Layout",
        templates = { { id = "shift_layout", name = "Shift Layout", variables = {} } },
        initial_template_id = "shift_layout",
        fields = {
            {
                id = "kind", name = "Kind", type = "choice", default = "office",
                choices = {
                    { value = "office", label = "Office" },
                    { value = "camera", label = "Camera" },
                    { value = "night", label = "Night Camera Map" }
                }
            },
            {
                id = "id", name = "Layout ID", type = "string", default = "new_layout",
                validate = function(value)
                    return value:match("^[%w_%-/]+$") ~= nil,
                        "Use letters, numbers, underscores, hyphens, or folders"
                end
            },
            { id = "name", name = "Display Name", type = "string", default = "New Shift Layout" },
            { id = "width", name = "Width", type = "integer", default = SCREEN_WIDTH, min = 1 },
            { id = "height", name = "Height", type = "integer", default = SCREEN_HEIGHT, min = 1 }
        },
        on_create = function(values)
            local folder = KIND_FOLDERS[values.kind]
            if not folder then return false, "Unknown shift layout kind" end
            local directory = FileSystemUtils.join(workspace.virtual_root,
                "scripts/shift/layouts/" .. folder)
            local created, reason = ProjectFileSystem.createProjectDirectory(directory)
            if not created then return false, reason end
            local path = FileSystemUtils.join(directory, values.id .. ".json")
            if love.filesystem.getInfo(path) then return false, "That shift layout already exists" end
            local mode = values.kind == "office" and "panorama"
                or values.kind == "camera" and "camera_feed" or "camera_map"
            local layout = {
                version = ShiftLayout.VERSION,
                kristal_version = tostring(Kristal.Version),
                kind = values.kind,
                id = values.id,
                name = values.name,
                width = values.width,
                height = values.height,
                pan = values.kind == "office" and 0 or nil,
                layers = {
                    {
                        id = mode,
                        name = StringUtils.titleCase(mode:gsub("_", " ")),
                        type = "object",
                        kind = "object",
                        mode = mode,
                        depth = 0,
                        visible = true,
                        objects = {}
                    }
                }
            }
            local encoded
            encoded, reason = ShiftLayout.encode(layout)
            if not encoded then return false, reason end
            local written
            written, reason = ProjectFileSystem.writeFile(path, encoded)
            if not written then return false, reason end
            if self.editor.file_browser then self.editor.file_browser:refresh(path) end
            local document
            document, reason = workspace:openDocument(path)
            if not document then return false, reason end
            self.editor:openDocument(document)
            return true
        end
    })
end

function ShiftEditorPlugin:onInit(editor)
    self.editor = editor
    local function shiftDocumentOnly(document)
        return document and document.getLayoutKind ~= nil
    end
    local layer_types = {
        panorama = self:registerLayerType("panorama", {
            name = "Shift Panorama", kind = "object", editor_objects = true,
            is_available = shiftDocumentOnly,
            icon = "editor/ui/layer/objects", color = { 0.35, 0.8, 1, 1 }
        }),
        static = self:registerLayerType("static", {
            name = "Static Screen Controls", kind = "object", editor_objects = true,
            is_available = shiftDocumentOnly,
            icon = "editor/ui/layer/objects", color = { 1, 0.72, 0.25, 1 }
        }),
        camera_feed = self:registerLayerType("camera_feed", {
            name = "Camera Feed", kind = "object", editor_objects = true,
            is_available = shiftDocumentOnly,
            icon = "editor/ui/layer/objects", color = { 0.45, 1, 0.65, 1 }
        }),
        camera_map = self:registerLayerType("camera_map", {
            name = "Camera Map", kind = "object", editor_objects = true,
            is_available = shiftDocumentOnly,
            icon = "editor/ui/layer/objects", color = { 0.82, 0.55, 1, 1 }
        }),
        contents = self:registerLayerType("contents", {
            name = "Shift Contents", kind = "object", editor_objects = true,
            is_available = shiftDocumentOnly,
            icon = "editor/ui/layer/objects", color = { 0.8, 0.8, 0.85, 1 }
        })
    }

    local EditorShiftObject = self:require("scripts.objects.shiftobject")
    local EditorShiftDraggable = self:require("scripts.objects.draggable", EditorShiftObject)
    self:registerShiftObjects(EditorShiftObject, EditorShiftDraggable)

    local Document = self:require("scripts.shiftlayoutdocument")
    local View = self:require("scripts.shiftlayoutview")
    local Provider = self:require("scripts.documentprovider", Document, View)
    self.provider = self:registerDocumentProvider("shift_layout", Provider(self, editor, layer_types))

    self:registerCommand("new_shift_layout", "New Shift Layout", {
        category = "File",
        keywords = { "shift", "night", "office", "camera", "layout" },
        action = function() return self:openCreationDialog() end
    })
    self:registerMenuItem("file", "new_shift_layout", "New Shift Layout...", {
        on_activate = function() return self:openCreationDialog() end
    })
    self:registerFileContextProvider("shift_layout", function(data)
        if not data or data.type ~= "file" then return nil end
        local relative = tostring(data.relative_path or ""):gsub("\\", "/"):lower()
        local folder = relative:match("^scripts/shift/layouts/([^/]+)/.+%.json$")
        if folder ~= "offices" and folder ~= "cameras" and folder ~= "nights" then
            return nil
        end
        return {
            label = "Open Shift Layout",
            action = function()
                local document, reason = editor.project_workspace:openDocument(data.path)
                if document then
                    editor:openDocument(document)
                else
                    editor:addError("Could not open shift layout", reason, "shift_layout")
                end
            end
        }
    end)
end

return ShiftEditorPlugin
