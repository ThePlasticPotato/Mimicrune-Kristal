local imgui = Imgui.lib
local ffi = require("ffi")

---@class OffsetEditorApplet: ImguiApplet
local OffsetEditorApplet, super = Class("ImguiApplet", "OffsetEditorApplet")
---@cast super ImguiApplet

function OffsetEditorApplet:init()
    super.init(self, "Offset Editor", imgui.ImGuiWindowFlags_MenuBar)
    self.initial_size = imgui.ImVec2_Float(1440, 800)
    self:setActor(Registry.createPartyMember((Kristal.getModOption("party") or {})[1] or "kris"):getActor())
    self.scale_factor = 8
    self.closebutton_pointer[0]=true
    self.save_offsets_popop = imgui.bool(false)
end

function OffsetEditorApplet:setActor(actor)
    if type(actor) == "string" then
        actor = Registry.createActor(actor)
    end

    self.current_actor = actor
    self.current_actor_id = actor.id
    self.default_sprite = actor:getDefaultSprite() or actor:getDefault()
    local sprite_choices = Utils.copy(actor.offsets)
    self.current_sprite = next(sprite_choices) or self.default_sprite
    if sprite_choices[self.default_sprite .. "/down"] then
        self.current_sprite = self.default_sprite .. "/down"
    else
        sprite_choices[self.current_sprite] = true
    end
    self.sprite_choices = {}
    for key, _ in Utils.orderedPairs(sprite_choices) do
        table.insert(self.sprite_choices, key)
    end
end

function OffsetEditorApplet:getActorTextures()
    local actor_sprite_path = (self.current_actor):getSpritePath()
    local base_texture_path = actor_sprite_path.."/"..self.default_sprite
    local base_texture = (Assets.getFramesOrTexture(base_texture_path) or Assets.getFramesOrTexture(base_texture_path.."/down") or Assets.getFramesOrTexture(actor_sprite_path))[1]
    local current_texture_path = actor_sprite_path.."/"..self.current_sprite
    local current_texture = (Assets.getFramesOrTexture(current_texture_path) or Assets.getFramesOrTexture(current_texture_path.."/down") or {base_texture})[1]
    return base_texture, current_texture
end

function OffsetEditorApplet:show()
    if (imgui.BeginMenuBar()) then
        if (imgui.BeginMenu("File")) then
            if imgui.BeginMenu("Open") then
                for actor_id, actor_class in Utils.orderedPairs(Registry.actors) do
                    if actor_class.createSprite == Actor.createSprite then
                        if (imgui.Selectable_Bool(actor_id, self.current_actor_id == actor_id)) then
                            self:setActor(actor_id)
                        end
                    end
                end
                imgui.EndMenu()
            end
            if (imgui.MenuItem_Bool("Close", "Ctrl+W")) then self:setOpen(false) end
            imgui.EndMenu();
        end
        imgui.EndMenuBar();
    end
    do
        imgui.BeginChild_Str("sprite select pane", imgui.ImVec2_Float(200, 0), bit.bor(imgui.ImGuiChildFlags_Borders, imgui.ImGuiChildFlags_ResizeX));
        for _, sprite_id in ipairs(self.sprite_choices) do
            local label = sprite_id
            if label == "" then
                label = "<empty>"
            end
            if (imgui.Selectable_Bool(label, self.current_sprite == sprite_id)) then
                self.current_sprite = sprite_id
            end
        end
        imgui.EndChild();
    end
    imgui.SameLine();
    -- Right
    imgui.BeginGroup();

    imgui.BeginChild_Str("item view", imgui.ImVec2_Float(0, -imgui.GetFrameHeightWithSpacing())); -- Leave room for 1 line below us
    do
        local function floorvec(vec)
            vec.x = math.floor(vec.x)
            vec.y = math.floor(vec.y)
            return vec
        end
        -- self.scale_factor = Utils.wave(Kristal.getTime()*math.pi/32,8,16)
        local offsetx, offsety = self.current_actor:getOffset(self.current_sprite)
        offsetx, offsety = math.floor(offsetx), math.floor(offsety)
        imgui.Text(string.format("[%q] = {%d, %d}", self.current_sprite, offsetx, offsety))
        local base_texture, current_texture = self:getActorTextures()
        local canvas_p0 = imgui.GetCursorScreenPos()      -- ImDrawList API uses screen coordinates!
        local canvas_sz = imgui.GetContentRegionAvail()   -- Resize canvas to what's available
        local draw_list = imgui.GetWindowDrawList();
        local topleft = (canvas_p0 + (canvas_sz/2)) - imgui.ImVec2_Float(self.current_actor:getWidth()*self.scale_factor/2, self.current_actor:getHeight()*self.scale_factor/2) ---@type imgui.ImVec2
        local bottomright = (canvas_p0 + (canvas_sz/2)) + imgui.ImVec2_Float(self.current_actor:getWidth()*self.scale_factor/2, self.current_actor:getHeight()*self.scale_factor/2) ---@type imgui.ImVec2
        imgui.InvisibleButton("canvas", canvas_sz, bit.bor(imgui.ImGuiButtonFlags_MouseButtonLeft, imgui.ImGuiButtonFlags_MouseButtonRight));
        local dragging = imgui.IsItemHovered() and imgui.IsItemActive()
        if dragging then
            local delta = imgui.C.igGetIO().MouseDelta / self.scale_factor
            self.current_actor.offsets[self.current_sprite] = self.current_actor.offsets[self.current_sprite] or {0,0}
            self.current_actor.offsets[self.current_sprite][1] = self.current_actor.offsets[self.current_sprite][1] + delta.x
            self.current_actor.offsets[self.current_sprite][2] = self.current_actor.offsets[self.current_sprite][2] + delta.y
        elseif self.current_actor.offsets[self.current_sprite] then
            self.current_actor.offsets[self.current_sprite][1] = math.floor(self.current_actor.offsets[self.current_sprite][1]) + 0.5
            self.current_actor.offsets[self.current_sprite][2] = math.floor(self.current_actor.offsets[self.current_sprite][2]) + 0.5
        end
        local offset = floorvec(imgui.ImVec2_Float(self.current_actor:getOffset(self.default_sprite))) * self.scale_factor
        draw_list:AddImage(imgui.love.TextureRef(base_texture), floorvec(offset + topleft), floorvec(offset + topleft + (imgui.ImVec2_Float(base_texture:getDimensions())*self.scale_factor)), nil, nil, imgui.color(.5,.5,.5,0.5))
        offset = floorvec(imgui.ImVec2_Float(self.current_actor:getOffset(self.current_sprite))) * self.scale_factor
        draw_list:AddImage(imgui.love.TextureRef(current_texture), floorvec(offset + topleft), floorvec(offset + topleft + (imgui.ImVec2_Float(current_texture:getDimensions())*self.scale_factor)), nil, nil, imgui.color(1,1,1,0.8))
        draw_list:AddRect(topleft, bottomright, imgui.GetColorU32_Col(imgui.ImGuiCol_PlotLines, 0.25), nil, nil, 1)
    end
    imgui.EndChild();
    if (imgui.Button("Revert")) then end
    imgui.SameLine();
    if (imgui.Button("Copy code")) then
        local offset_code = "self.offsets = {\n"
        for key, value in Utils.orderedPairs(self.current_actor.offsets) do
            offset_code = offset_code .. ("[%q] = {%d, %d};\n"):format(key, math.floor(value[1]), math.floor(value[2]))
        end
        offset_code = offset_code .. "}"
        love.system.setClipboardText(offset_code)
    end
    imgui.SameLine();
    if self:getActorPath() and (imgui.Button("Save offsets")) then
        imgui.OpenPopup_Str("Save offsets?")
    end
    self:showSaveOffsetsModal()
    imgui.EndGroup();
end

---@return string? path
---@return string? error
function OffsetEditorApplet:getActorPath()
    local path = Mod.info.path .. "/scripts/data/actors/"..self.current_actor_id..".lua"
    if love.filesystem.getInfo(path) then
        return path
    end
    for i=#Mod.info.lib_order, 1, -1 do
        local lib = Mod.info.libs[Mod.info.lib_order[i]]
        path = lib.path .. "/scripts/data/actors/"..self.current_actor_id..".lua"
        if love.filesystem.getInfo(path) then
            return path
        end
    end
    return nil, "Couldn't find actor \""..self.current_actor_id.."\"! It could be from the engine, or have an unusual filename."
end

function OffsetEditorApplet:showSaveOffsetsModal()
    imgui.SetNextWindowPos(imgui.GetMainViewport():GetCenter(), imgui.ImGuiCond_Appearing, imgui.ImVec2_Float(0.5, 0.5));
    if imgui.BeginPopupModal("Save offsets?", nil, imgui.ImGuiWindowFlags_AlwaysAutoResize) then
        imgui.Text([[
This functionality is experimental!
Please make sure you have a backup
and/or git repo set up!
]])
        if (imgui.Button("Do it!", imgui.ImVec2_Float(120, 0))) then
            self:saveOffsets()
            imgui.CloseCurrentPopup();
        end
        imgui.SameLine()
        if (imgui.Button("Cancel", imgui.ImVec2_Float(120, 0))) then imgui.CloseCurrentPopup(); end
        imgui.EndPopup()
    end
end

---@alias OffsetEditorApplet.OffsetFileEntry {type:"literal",text:string}|{type:"offset",prefix:string,name:string,x:number,y:number}

-- Save offsets in-place of the existing file
function OffsetEditorApplet:saveOffsets()
    local filepath = assert(self:getActorPath())
    ---@return OffsetEditorApplet.OffsetFileEntry[] data
    ---@return string prefix
    ---@return string postfix
    local function parseActorFile()
        local readfile = love.filesystem.newFile(filepath, "r")
        local readfileiter = readfile:lines() ---@type fun():string
        -- TODO: fix this shit
        local fileprefix = ""
        local merge = false
        do
            for line in readfileiter do
                fileprefix = fileprefix .. line .. "\n"
                if Utils.contains(line, "Utils.merge%(self.offsets, *{") then
                    merge = true
                    break
                end
                if Utils.contains(line, "self.offsets *= *{") then
                    break
                end
            end
        end
        if readfile:isEOF() then
            error("Couldn't find offsets definition (self.offsets = { or Utils.merge(self.offsets, {))")
        end

        local offset_lines = {} ---@type OffsetEditorApplet.OffsetFileEntry[]
        ---@param entry OffsetEditorApplet.OffsetFileEntry
        local function addEntry(entry)
            table.insert(offset_lines, entry)
        end
        local filepostfix = ""
        local entry_pattern = "(.*)%[\"(.+)\"%] *= *{(.+), *(.+)}"
        for line in readfileiter do
            if line:find("^ +}") then
                filepostfix = line .. "\n"
                break
            end
            if string.find(line, entry_pattern) then
                
                local _,_, prefix, name, x, y = string.find(line, entry_pattern)
                addEntry({ type = "offset", prefix = prefix, name = name, x = tonumber(x), y = tonumber(y) })
            else
                addEntry({ type = "literal"; text = line; })
            end
        end

        for line in readfileiter do
            filepostfix = filepostfix .. line .. "\n"
        end
        readfile:close()
        return offset_lines, fileprefix, filepostfix
    end

    local data, fileprefix, filepostfix = parseActorFile()
    local lineprefix = "        "
    local offsets = Utils.copy(self.current_actor.offsets)
    for offsetid, offset in pairs(self.current_actor.offsets) do
        for line, entry in ipairs(data) do
            if entry.type == "offset" and entry.name == offsetid then
                offsets[offsetid] = nil
                entry.x, entry.y = offset[1], offset[2]
                break
            end
        end
    end

    for offsetid, offset in pairs(offsets) do
        table.insert(data, {type = "offset", x = offset[1], y = offset[2], prefix = lineprefix})
    end

    local file = love.filesystem.newFile(filepath, "w")

    file:write(fileprefix)

    for index, entry in ipairs(data) do
        if entry.type == "literal" then
            file:write(entry.text.."\n")
        elseif entry.type == "offset" then
            file:write(entry.prefix.. "[\""..entry.name.."\"] = {"..math.floor(entry.x)..", "..math.floor(entry.y).."},\n")
        end
    end

    file:write(filepostfix)
    file:close()

    -- Swap out actors
    Mod.info.loaded_scripts = false
    Mod.info.script_chunks = {}
    Kristal.Mods.getAndLoadMod(Mod.info.id)
    Registry.initActors()
    for _, party in pairs(Game.party_data) do
        if party.actor then
            party:setActor(party.actor.id)
        end
        if party.lw_actor then
            party:setLightActor(party.lw_actor.id)
        end
    end
    local current_sprite = self.current_sprite
    self:setActor(self.current_actor_id)
    self.current_sprite = current_sprite
end

return OffsetEditorApplet
