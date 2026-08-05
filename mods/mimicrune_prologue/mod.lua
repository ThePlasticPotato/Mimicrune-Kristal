local CONNECTION_LOG_PATH = "plot/connection_log.txt"
local WASTES_ARRIVAL_FLAG = "wastes_arrival_complete"
local WASTES_SOUL_SPAWN_Y_OFFSET = -4

function Mod:init()
    self.playtest = false

    print("Loaded " .. self.info.name .. "!")
end

function Mod:getSoulColor()
    return ColorUtils.unpackColor(COLORS.gray)
end

function Mod:getInitialAssetBucket()
    if Kristal.checkPersistentVariable(CONNECTION_LOG_PATH) then
        return "area:wastes"
    end
    return "area:device"
end

function Mod:getWastesCage()
    local cages = Game.world.map.events_by_name.cage_back
    return cages and cages[1] or Game.world.map.events_by_id[63]
end

function Mod:getWastesCageFront()
    local cages = Game.world.map.events_by_name.cage_front
    return cages and cages[1] or Game.world.map.events_by_id[62]
end

---@param cage Object
---@return number x, number y
function Mod:getWastesSoulSpawnPosition(cage)
    local scale_x = math.abs(cage.scale_x or 1)
    local scale_y = math.abs(cage.scale_y or 1)
    return cage.x + cage.width * scale_x / 2,
        cage.y + cage.height * scale_y + WASTES_SOUL_SPAWN_Y_OFFSET
end

---@param cage_back? Object
---@return Object
function Mod:prepareWastesCageBack(cage_back)
    cage_back = cage_back or assert(self:getWastesCage(),
        "Wastes entrance is missing its cage_back object")
    cage_back.height_depth_transparent = true
    cage_back.height_depth_sort_offset = -16
    return cage_back
end

---@param cage_back? Object
---@param object_layer? number
---@return Object
function Mod:releaseWastesCageBack(cage_back, object_layer)
    cage_back = cage_back or assert(self:getWastesCage(),
        "Wastes entrance is missing its cage_back object")
    object_layer = object_layer or Game.world.map.object_layer
    cage_back.height_depth_transparent = false
    cage_back.height_depth_sort_offset = nil
    cage_back.height_sort_subject = true
    cage_back.height_depth_subject = true
    cage_back:setLayer(object_layer)
    return cage_back
end

---@param cage_front? Object
---@param object_layer? number
---@return Object
function Mod:releaseWastesCageFront(cage_front, object_layer)
    cage_front = cage_front or assert(self:getWastesCageFront(),
        "Wastes entrance is missing its cage_front object")
    object_layer = object_layer or Game.world.map.object_layer
    cage_front.height_sort_subject = true
    cage_front.height_depth_subject = true
    cage_front.height_depth_offset = 0.001
    cage_front:setLayer(object_layer)
    return cage_front
end

---@param play_arrival boolean
---@return WorldSoul
function Mod:spawnWastesSoul(play_arrival)
    local cage = assert(self:getWastesCage(), "Wastes entrance is missing its cage_back object")
    local x, y = self:getWastesSoulSpawnPosition(cage)
    local soul = WorldSoul(x, y, { Game:getSoulColor() }, cage.z)
    Game.world:addChild(soul)

    soul.arrival_hover_height = soul.hover_height
    soul.arrival_hover_bob = soul.hover_bob
    soul.arrival_ground_hover = soul.height / 2
    soul.can_move = not play_arrival
    soul.is_active = not play_arrival
    if play_arrival then
        soul.hover_height = soul.arrival_ground_hover
        soul.hover_bob = 0
        soul.hover_offset = soul.arrival_ground_hover
        soul:syncVisualHover()
    end
    return soul
end

---@param save DeltaruneSave
---@return boolean imported
function Mod:applyGonermakerChoices(save)
    if not save then
        return false
    end

    Game:setFlag("vessel_name", save.vessel_name)
    for choice, flag_id in pairs(DeltaruneConsts.VESSEL_PARTS) do
        local value = save:getFlag(flag_id, "number")
        if value ~= nil then
            Game:setFlag("vessel_" .. choice, value)
        end
    end
    return true
end

---@return boolean imported
function Mod:importGonermakerChoices()
    local save
    local success, err = pcall(function()
        DeltaruneLoader.load({chapter = 1, slot = 1})
        save = DeltaruneLoader.getSave(1, 1)
            or DeltaruneLoader.getCompletion(1, 1)
    end)

    if not success then
        return false
    end
    if not save then
        return false
    end
    return self:applyGonermakerChoices(save)
end

function Mod:enterWastes()
    self:importGonermakerChoices()
    Assets.transitionToMapBucket("wastes_entrance", function()
        Game.world:loadMap("wastes_entrance")
        Atmosphere:setWeather("wind", true, 3, false, -1)
        local play_arrival = not Game:getFlag(WASTES_ARRIVAL_FLAG, false)
        local soul = self:spawnWastesSoul(play_arrival)
        if play_arrival then
            self:prepareWastesCageBack()
            Game.world:startCutscene("wastes", "arrival", soul, WASTES_ARRIVAL_FLAG)
        else
            self:releaseWastesCageBack()
            self:releaseWastesCageFront()
            Game.world:setCameraAttached(true)
            local camera_x, camera_y = Game.world.camera:getTargetPosition()
            Game.world.camera:setPosition(camera_x, camera_y)
        end
    end)
end

function Mod:getUISkin(skin)
    return skin or "DEVICE"
end

function Mod:postInit(new_file)
    love.window.setTitle("INTERFACE")
    Game:setFlag("playtest_mode", self.playtest)
    Game:setFlag("audible_footsteps", true)
    if not self.playtest and Kristal.checkPersistentVariable(CONNECTION_LOG_PATH) then
        self:enterWastes()
        return
    end
    if new_file then
        if Game.world.player then
            Game.world.player.visible = false
        end

        if self.playtest then
            Game.world:startCutscene("connection", "battle_test")
        else
            Game.world:startCutscene("connection", "startup")
        end
    end
end

function Mod:onDrawText(text, node, state, x, y, scale, font, use_color)
    if not text:includes(DialogueText) then
        return
    end

    if text.connection then
        text.draw_every_frame = true
        text.specfade = text.specfade or 1
        node.height_mult = node.height_mult or 0.5

        y = y + ((1 - node.height_mult) * font:getHeight())

        local scale_y = scale * node.height_mult
        local scale_x = scale / node.height_mult
        local r, g, b, a = text:getTextColor(state, use_color)

        Draw.setColor(r, g, b, a * text.specfade)
        love.graphics.print(node.character, x, y, 0, scale_x, scale_y)

        Draw.setColor(r, g, b, a * ((0.3 + (math.sin(text.timer / 14) * 0.1)) * text.specfade))
        love.graphics.print(node.character, x + 2, y, 0, scale_x, scale_y)
        love.graphics.print(node.character, x - 2, y, 0, scale_x, scale_y)
        love.graphics.print(node.character, x, y + 2, 0, scale_x, scale_y)
        love.graphics.print(node.character, x, y - 2, 0, scale_x, scale_y)

        Draw.setColor(r, g, b, a * ((0.08 + (math.sin(text.timer / 14) * 0.04)) * text.specfade))
        love.graphics.print(node.character, x + 2, y, 0, scale_x, scale_y)
        love.graphics.print(node.character, x - 2, y, 0, scale_x, scale_y)
        love.graphics.print(node.character, x, y + 2, 0, scale_x, scale_y)
        love.graphics.print(node.character, x, y - 2, 0, scale_x, scale_y)

        Draw.setColor(r, g, b, 1)
        node.height_mult = MathUtils.lerp(node.height_mult, 1, 0.6)
    end

    if state.temp_shake > 0 then
        if text.timer - state.last_temp_shake >= DTMULT then
            state.last_temp_shake = text.timer
            state.offset_x = MathUtils.round(MathUtils.random(-state.temp_shake, state.temp_shake))
            state.offset_y = MathUtils.round(MathUtils.random(-state.temp_shake, state.temp_shake))
        end
        state.temp_shake = MathUtils.approach(state.temp_shake, 0, 8 * DT)
    end
end

---@param text Text|DialogueText
function Mod:registerTextCommands(text)
    if not text:includes(DialogueText) then
        return
    end

    text:registerCommand("tempshake", function(command_text, node, dry)
        command_text.state.temp_shake = tonumber(node.arguments[1]) or 1
        command_text.draw_every_frame = true
    end)
end

function Mod:shakifyText(text)
    local no_sound = { "\n", " ", "^", "!", ".", "?", ",", ":", "/", "\\", "|", "*" }
    local output = ""
    local is_command = false

    for i = 1, #text do
        local character = text:sub(i, i)
        if character == "[" then
            is_command = true
        end

        if not is_command and not TableUtils.contains(no_sound, character) then
            output = output .. "[tempshake:4]"
        end
        output = output .. character

        if character == "]" then
            is_command = false
        end
    end

    return output .. "[tempshake:0]"
end
