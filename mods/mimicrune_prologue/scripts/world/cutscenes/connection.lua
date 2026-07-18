local platformName = ""
return {
    ---@param cutscene WorldCutscene
    ---@param event Event
    battle_test = function (cutscene, event)
                local text
        local function interloperTextFade(wait)
            local this_text = text
            if wait ~= false then
                cutscene:wait(2)
            end
            Game.world.timer:tween(1, this_text, { alpha = 0 }, "linear", function ()
                this_text:remove()
            end)
        end

        local function interloperText(str, advance, instaclear)
            text = DialogueText("[speed:2][voice:interloper]" .. str, 240, 50, 640, 480,
                                { auto_size = true, align = "center", font_size = 16 })
            text.layer = WORLD_LAYERS["top"] + 100
            text.skip_speed = true
            text.parallax_x = 0
            text.parallax_y = 0
            local text_width = text:getTextWidth()
            text.x = 320 - (text_width/2)
            Game.world:addChild(text)

            if advance ~= false then
                cutscene:wait(function () return not text:isTyping() end)
                interloperTextFade(true)
            end
            if instaclear == true then
                cutscene:wait(function () return not text:isTyping() end)
                text:remove()
            end
            return text
        end
        local text1 = interloperText("This is an early alpha version of the game, setup to immediately boot you into a Tense Battle for playtesting purposes. It does not reflect the finalized state of the game, nor is it necessarily stable.\n\nDo you wish to PROCEED?", false)

        cutscene:wait(function () return not text1:isTyping() end)
        local choice2 = ""
        local choicer2 = GonerChoice(SCREEN_WIDTH / 2, (SCREEN_HEIGHT * 3) / 4, nil, function (choiced, x, y) choice2 = choiced end, function() end)
        choicer2.x = choicer2.x - (choicer2.width / 2)
        Game.world:addChild(choicer2)
        cutscene:wait(function () return choice2 ~= "" end)

        --cutscene:wait(1)

        if (choice2 == "NO") then
            love.event.quit()
        else
            Assets.playSound("egg")
            interloperTextFade(true)

            local text2 = interloperText("This battle will be hard. You have been given the characters' starting equipment and spells, and a few items and instant-uses.\n[color:lime](H will cease your bleeding, [color:yellow]T will fuel your heart, [color:purple]P will cure your SOUL)[color:reset]\nThough unfinished, you can start with an additional party member who may make this fight easier. Do you wish to recieve the aid of Fredbear?", false)

            cutscene:wait(function () return not text2:isTyping() end)

            local choice1 = ""
            local choicer1 = GonerChoice(SCREEN_WIDTH / 2, (SCREEN_HEIGHT * 3) / 4, {{{ "TO FRED", -20, 0 }, { "NOT TO FRED", 100, 0 }}}, function (choiced, x, y) choice1 = choiced end, function() end)
            --choicer1.selected_x = 2
            choicer1.x = choicer1.x - (choicer1.width / 2)
            Game.world:addChild(choicer1)
            cutscene:wait(function () return choice1 ~= "" end)
            interloperTextFade(true)

            cutscene:endCutscene()
            Game:addPartyMember("cassidy")
            if (choice1 == "TO FRED") then
                Game:addPartyMember("fredbear")
            end
            Game.inventory:tryGiveItem("pepperoni_slice", true)
            Game.inventory:tryGiveItem("plain_slice", true)
            Game.inventory:tryGiveItem("plain_slice", true)
            Game.inventory:tryGiveItem("fizzyfaz", true)
            Game.inventory:tryGiveItem("fizzyfaz", true)
            Game.inventory:tryGiveItem("fizzyfaz", true)
            Game:setFlag("tonics", 4)
            Game:setFlag("bandaids", 6)
            Game:setFlag("purifiers", 3)
            Game:encounter("debugtwisted")
        end
    end,


    ---@param cutscene WorldCutscene
    ---@param event Event
    streamer_mode = function (cutscene, event)
        local text
        local function interloperTextFade(wait)
            local this_text = text
            if wait ~= false then
                cutscene:wait(2)
            end
            Game.world.timer:tween(1, this_text, { alpha = 0 }, "linear", function ()
                this_text:remove()
            end)
        end

        local function interloperText(str, advance, instaclear)
            text = DialogueText("[speed:2][voice:interloper]" .. str, 240, 50, 640, 480,
                                { auto_size = true, align = "center", font_size = 16 })
            text.layer = WORLD_LAYERS["top"] + 100
            text.skip_speed = true
            text.parallax_x = 0
            text.parallax_y = 0
            local text_width = text:getTextWidth()
            text.x = 320 - (text_width/2)
            Game.world:addChild(text)

            if advance ~= false then
                cutscene:wait(function () return not text:isTyping() end)
                interloperTextFade(true)
            end
            if instaclear == true then
                cutscene:wait(function () return not text:isTyping() end)
                text:remove()
            end
        end

        interloperText("This game contains meta elements, which may be unsuitable for a streaming environment.\nWould you like to enable STREAMER MODE?\n(In streamer mode, all sensitive content is censored or removed and certain effects are disabled.)", false)

        cutscene:wait(4)
        local choice = ""
        local choicer = GonerChoice(SCREEN_WIDTH / 2, (SCREEN_HEIGHT * 3) / 4, nil, function (choiced, x, y) choice = choiced end, function() end)
        choicer.x = choicer.x - (choicer.width / 2)
        Game.world:addChild(choicer)
        cutscene:wait(function () return choice ~= "" end)

        Game:setFlag("streamer_mode", choice == "YES")

        if (choice == "YES") then
            Assets.playSound("egg")
        end
        interloperTextFade()
        cutscene:wait(2)

        interloperText("This game contains flashing lights,\nand content some may find disturbing.\nDo you still wish to PROCEED?", false)
        cutscene:wait(4)
        local choice2 = ""
        local choicer2 = GonerChoice(SCREEN_WIDTH / 2, (SCREEN_HEIGHT * 3) / 4, nil, function (choiced, x, y) choice2 = choiced end, function() end)
        choicer2.x = choicer2.x - (choicer.width / 2)
        Game.world:addChild(choicer2)
        cutscene:wait(function () return choice2 ~= "" end)

        cutscene:wait(1)

        if (choice2 == "NO") then
            love.event.quit()
        else
            interloperTextFade()
            cutscene:wait(2)
            cutscene:endCutscene()
            if (Kristal.checkPersistentVariable("plot/connection_log.txt")) then
                Game.world:startCutscene("connection", "intro_transition")
            else
                Game.world:startCutscene("connection", "startup")
            end
        end
    end,

    ---startup
    ---@param cutscene WorldCutscene
    ---@param event Event
    startup = function (cutscene, event)
        if Game.world.player then
            Game.world.player.visible = false
        end
        local texts = {}
        local wdtexts = {}
        local function shortGlitch()
            Game.world:blockGlitch(0.6)--Game.world:addFX(ShaderFX("glitch", { ["iTime"] = function () return Kristal.getTime() end, ["glitchScale"] = 0.6}, false), "glitchy")
            cutscene:wait(0.25)
            Game.world:stopGlitch()
        end
        local function wipeText() 
            for index, value in ipairs(texts) do
                value:remove()
            end
            for index, value in ipairs(wdtexts) do
                value:remove()
            end
            texts = {}
            wdtexts = {}
        end
        local function terminalText(str, advance, instaclear, offset, red, x_offset)
            offset = offset or 0
            x_offset = x_offset or 0
            local additional = red and "[color:red]" or ""
            local additionalwd = red and "[color:maroon]" or ""
            local wdtext = DialogueText("[color:#222222][font:wingdings][speed:1][spacing:6][style:GONER][voice:none][shake:1]" .. additionalwd .. str, 38 + x_offset, 100 + offset, 640*2, 480 * 2,
                                { auto_size = true, align = "left"})
            local text = DialogueText("[speed:1][spacing:6][style:GONER][voice:none]" .. additional .. str, 40 + x_offset, 90 + offset, 640, 480,
                                { auto_size = true, align = "left", wrap = false})
            
            wdtext:setScale(0.5, 0.5)
            text:setScale(0.5, 0.5)
            text.layer = WORLD_LAYERS["top"] + 100
            text.skip_speed = true
            text.parallax_x = 0
            text.parallax_y = 0
            Game.world:addChild(text)
            Game.world:addChild(wdtext)
            wdtext.layer = 100
            text.layer = 110
            
            table.insert(wdtexts, wdtext)
            table.insert(texts, text)
            if advance ~= false then
                cutscene:wait(function () return not text:isTyping() end)
                TableUtils.removeValue(texts, text)
                TableUtils.removeValue(wdtexts, wdtext)
                text:remove()
                wdtext:remove()
            end
            if instaclear == true then
                cutscene:wait(function () return not text:isTyping() end)
                text:remove()
                wdtext:remove()
            end
        end

        Game.world.music:play("AUDIO_DEVICE_BOOT")
        Game.world.music:setLooping(false)

        cutscene:musicWait(0.109) -- Start Button Start
        
        cutscene:musicWait(0.365) -- Start Button End
        local flash_sprite = Sprite("misc/DEVICE_bootup", 0, 0)
        flash_sprite:setScale(2,2)
        flash_sprite:play(1/10, false, function()
            Game.world:addFX(ShaderFX("crt_convert", { ["texsize"] = {SCREEN_WIDTH, SCREEN_HEIGHT}, ["warp"] = 0.75, ["scan"] = 0.75 }, false), "ceeartee")
            flash_sprite:setSprite("misc/DEVICE_bootup_end")
            flash_sprite:play(1/10, false, function ()
                
            end)
        end)
        Game.stage:addChild(flash_sprite)
        local bios_sprite
        
        cutscene:musicWait(1.051) -- Startup Phase 1
        bios_sprite = Sprite("misc/garamond_bios", 0, 0)
        bios_sprite:setScale(2,2)
        bios_sprite.layer = 90
        bios_sprite.alpha = 0
        Game.world:addChild(bios_sprite)
        
        cutscene:wait(0.25)
        terminalText("[speed:0.5]. . .[wait:1]")
        bios_sprite.alpha = 0.25
        cutscene:wait(0.15)
        terminalText("[speed:0.5]. . .[wait:1]")
        bios_sprite.alpha = 0.5
        cutscene:wait(0.15)
        terminalText("[speed:0.5]. . .[wait:1]")
        bios_sprite.alpha = 0.75
        cutscene:wait(0.15)
        terminalText("[speed:0.5]. . .[wait:1]")
        bios_sprite.alpha = 1
        cutscene:wait(0.25)
        --cutscene:musicWait(4.773) -- Startup Phase 2
        terminalText("[speed:2]WD-OS_V1.2.1a", false, false)
        cutscene:wait(0.4)
        terminalText("[speed:2]Copyright (C) 19XX-20XX,\nASTER SCIENCES LLC.", false, false, 28)
        cutscene:wait(0.8)
        terminalText("[speed:2]CORE g10 CPU @ 8200 MHz\n8 Processor(s)", false, false, 80)
        cutscene:wait(0.6)
        terminalText("[speed:2]Memory Test : [wait:1]63518192K [wait:2.5]OK", false, false, 80 + 56)
        cutscene:wait(0.7)
        --cutscene:musicWait(8.958) -- Startup Phase 3
        terminalText("[speed:2]Detecting Flash ROM : [wait:3]\n...AMALGAE 15 [wait:2.5]OK", false, false, 80 + 28 + 56)
        cutscene:wait(0.75)
        terminalText("[speed:2]Detecting Flash Extension : [wait:3]\n...Generic m.2 [wait:2.5]OK", false, false, 80 + 28 + 56 + 56)
        cutscene:wait(0.75)
        terminalText("[speed:2]Detecting SOUL Presence : [wait:3]\n...NARRA.kd.13018 [wait:2.5]OK", false, false, 80 + 28 + 56 + 56 + 56)
        cutscene:wait(0.75)
        wipeText()
        terminalText("[speed:2]!!!WARNING!!! Debug Mode is\nENABLED.\nSystem instability \nmay be present.", false, false, 0, true)
        cutscene:wait(1)
        terminalText("[speed:2]PROCEEDing is inadvisable.\nStrike any key to \nPROCEED regardless.", false, false, 56 + 56 + 28, false)
        cutscene:wait(2)
        Assets.playSound("voice/interloper")
        wipeText()
        cutscene:wait(0.1)
        terminalText("[speed:2]Please hold...\n[speed:1]Do not turn off the DEVICE.", false, false, 0)
        cutscene:musicWait(13.182) -- Hard Drive Click
        wipeText()
        terminalText("[speed:2]Initialized VOID_RELAY module.", false, false)
        cutscene:musicWait(14) -- Connection Start
        local connection_target = love.system:getOS() --os.getenv("USERNAME") or os.getenv("USER") or "TARGET_ID"
        -- if (connection_target == "temerity" or Game:getFlag("streamer_mode", false)) then
        --     connection_target = "sys_admin"
        -- end
        platformName = connection_target
        terminalText("[speed:2][vdrl] : CONNECTING TO EXTERNAL\nDEVICE RUNNING : ' " .. connection_target .. " '", false, false, 28)
        cutscene:musicWait(15.229) -- Beep end
        cutscene:musicWait(16.105) -- Static
        Game:setBorder("DEVICE", 18)
        shortGlitch()
        terminalText("[speed:2][vdrl] : ESTABLISHING \n CONNECTION", false, false, 56 + 28)
        terminalText("[speed:2][vdrl] :", true, false, 56 + 56 + 28)
        terminalText("[speed:0.5]. . .[wait:1]", true, false, 56 + 56 + 28, false, 40)
        cutscene:wait(0.25)
        terminalText("[speed:0.5]. . .[wait:1]", true, false, 56 + 56 + 28, false, 40)
        cutscene:wait(0.25)
        terminalText("[speed:0.5]. . .[wait:1]", true, false, 56 + 56 + 28, false, 40)
        cutscene:wait(0.25)
        terminalText("[speed:0.5]. . .[wait:1]", true, false, 56 + 56 + 28, false, 40)
        cutscene:wait(0.25)
        terminalText("[speed:0.5]. . .[wait:1]", true, false, 56 + 56 + 28, false, 40)
        cutscene:musicWait(17.484) -- Connection Phase 1
        shortGlitch()
        terminalText("[speed:0.5]. . .[wait:1]", true, false, 56 + 56 + 28, false, 40)
        cutscene:wait(0.25)
        terminalText("[speed:0.5]. . .[wait:1]", true, false, 56 + 56 + 28, false, 40)
        cutscene:wait(0.25)
        terminalText("[speed:2][vdrl] : TARGETLOCK", false, false, 56 + 56 + 28, true)
        cutscene:wait(0.1)
        terminalText("[speed:2][vdrl] :", true, false, 56 + 56 + 56 + 28)
        terminalText("[speed:0.5]. . .[wait:1]", true, false, 56 + 56 + 56 + 28, false, 40)
        cutscene:wait(0.25)
        terminalText("[speed:0.5]. . .[wait:1]", true, false, 56 + 56 + 56 + 28, false, 40)
        cutscene:wait(0.25)
        terminalText("[speed:0.5]. . .[wait:1]", true, false, 56 + 56 + 56 + 28, false, 40)
        cutscene:musicWait(19.346) -- Connection Phase 2
        shortGlitch()
        terminalText("[speed:0.5]. . .[wait:1]", true, false, 56 + 56 + 56 + 28, false, 40)
        cutscene:wait(0.25)
        terminalText("[speed:0.5]. . .[wait:1]", true, false, 56 + 56 + 56 + 28, false, 40)
        cutscene:wait(0.25)
        terminalText("[speed:2][vdrl] : PING SUCCESS, TOOK 1899ms", false, false, 56 + 56 + 56 + 28, true)
        cutscene:wait(0.1)
        terminalText("[speed:2][vdrl] :", true, false, 56 + 56 + 56 + 56 + 28)
        terminalText("[speed:0.5]. . .[wait:1]", true, false, 56 + 56 + 56 + 56 + 28, false, 40)
        cutscene:wait(0.25)
        terminalText("[speed:0.5]. . .[wait:1]", true, false, 56 + 56 + 56 + 56 + 28, false, 40)
        cutscene:wait(0.25)
        terminalText("[speed:0.5]. . .[wait:1]", true, false, 56 + 56 + 56 + 56 + 28, false, 40)
        cutscene:wait(0.25)
        terminalText("[speed:0.5]. . .[wait:1]", true, false, 56 + 56 + 56 + 56 + 28, false, 40)
        cutscene:musicWait(22.86) -- Connection Phase 3
        shortGlitch()
        terminalText("[speed:0.5]. . .[wait:1]", true, false, 56 + 56 + 56 + 56 + 28, false, 40)
        cutscene:wait(0.25)
        terminalText("[speed:0.5]. . .[wait:1]", true, false, 56 + 56 + 56 + 56 + 28, false, 40)
        cutscene:wait(0.25)
        terminalText("[speed:2][vdrl] : BEGIN LINK PHASE", false, false, 56 + 56 + 56 + 56 + 28, true)
        cutscene:wait(0.1)
        terminalText("[speed:2][vdrl] :", true, false, 56 + 56 + 56 + 56 + 56 +  28)
        terminalText("[speed:0.5]. . .[wait:1]", true, false, 56 + 56 + 56 + 56 + 56 + 28, false, 40)
        cutscene:wait(0.25)
        terminalText("[speed:0.5]. . .[wait:1]", true, false, 56 + 56 + 56 + 56 + 56 + 28, false, 40)
        cutscene:wait(0.25)
        terminalText("[speed:0.5]. . .[wait:1]", true, false, 56 + 56 + 56 + 56 + 56 + 28, false, 40)
        cutscene:wait(0.25)
        terminalText("[speed:0.5]. . .[wait:1]", true, false, 56 + 56 + 56 + 56 + 56 + 28, false, 40)
        cutscene:wait(0.25)
        terminalText("[speed:0.5]. . .[wait:1]", true, false, 56 + 56 + 56 + 56 + 56 + 28, false, 40)
        cutscene:wait(0.25)
        terminalText("[speed:0.5]. . .[wait:1]", true, false, 56 + 56 + 56 + 56 + 56 + 28, false, 40)
        cutscene:musicWait(27.535) -- Connection Phase 4
        shortGlitch()
        terminalText("[speed:0.5]. . .[wait:1]", true, false, 56 + 56 + 56 + 56 + 56 + 28, false, 40)
        cutscene:wait(0.25)
        terminalText("[speed:0.5]. . .[wait:1]", true, false, 56 + 56 + 56 + 56 + 56 + 28, false, 40)
        cutscene:wait(0.25)
        terminalText("[speed:2][vdrl] : LINK SUCCESS", false, false, 56 + 56 + 56 + 56 + 56 + 28, true)
        
        cutscene:musicWait(34.356) -- Connection Finale Start
        shortGlitch()
        wipeText()
        terminalText("[speed:2][vdrl] : RELAY CONNECTED.", false, false, 0, true)
        cutscene:musicWait(36) -- Connection Finale Riser
        terminalText("[speed:0.5][vdrl] : SOUL UPLOAD IN PROGRESS...", false, false, 28, true)
        shortGlitch()
        cutscene:musicWait(36.731) -- Connection Finale End
        shortGlitch()
        wipeText()
        terminalText("[speed:2]Please hold...\n[speed:1]Do not turn off the DEVICE.", false, false, 0)
        cutscene:musicWait(37.331) -- Gaster Shuts Up
        shortGlitch()
        wipeText()
        bios_sprite:remove()
        Game.world:removeFX("ceeartee")
        shortGlitch()
        cutscene:musicWait(38.287) -- snd_greatshine
        cutscene:musicWait(39.666) -- CONNECTION ESTABLISHED

        cutscene:wait(function () return not Game.world.music:isPlaying() end)
        cutscene:wait(2)
        
        Game.world.music:stop()
        Game.world.music:setLooping(true)
        
        cutscene:endCutscene()
        Game.world:startCutscene("connection", "established")
    end,

    ---established
    ---@param cutscene WorldCutscene
    ---@param event Event
    established = function(cutscene, event)
        if Game.world.player then
            Game.world.player.visible = false
            Game.world.player.y = 1000
        end

        local texts = {}
        local wdtexts = {}
        local function shortGlitch(target, removeAfter)
            target:blockGlitch(0.6)--Game.world:addFX(ShaderFX("glitch", { ["iTime"] = function () return Kristal.getTime() end, ["glitchScale"] = 0.6}, false), "glitchy")
            cutscene:wait(0.25)
            if (removeAfter) then target:remove() else target:stopGlitch() end
        end
        local function wipeText() 
            for index, value in ipairs(texts) do
                value:remove()
            end
            for index, value in ipairs(wdtexts) do
                value:remove()
            end
            texts = {}
            wdtexts = {}
        end
        local function terminalText(str, advance, instaclear, offset, red, x_offset)
            offset = offset or 0
            x_offset = x_offset or 0
            local additional = red and "[color:red]" or ""
            local additionalwd = red and "[color:maroon]" or ""
            local wdtext = DialogueText("[color:#222222][font:wingdings][speed:1][spacing:6][style:GONER][voice:none][shake:1]" .. additionalwd .. str, 0 + x_offset, 10 + offset, 640*2, 480 * 2,
                                { auto_size = true, align = "left"})
            local text = DialogueText("[speed:1][spacing:6][style:GONER][voice:none]" .. additional .. str, 2 + x_offset, 0 + offset, 640, 480,
                                { auto_size = true, align = "left", wrap = false})
            
            wdtext:setScale(0.5, 0.5)
            text:setScale(0.5, 0.5)
            text.layer = WORLD_LAYERS["top"] + 1000
            text.skip_speed = true
            text.skippable = false
            text.can_advance = false
            text.parallax_x = 0
            text.parallax_y = 0
            Game.world:addChild(text)
            Game.world:addChild(wdtext)
            wdtext.layer = WORLD_LAYERS["top"] + 1000
            text.layer = WORLD_LAYERS["top"] + 1100
            
            table.insert(wdtexts, wdtext)
            table.insert(texts, text)
            if advance ~= false then
                cutscene:wait(function () return not text:isTyping() end)
                TableUtils.removeValue(texts, text)
                TableUtils.removeValue(wdtexts, wdtext)
                text:remove()
                wdtext:remove()
            end
            if instaclear == true then
                cutscene:wait(function () return not text:isTyping() end)
                text:remove()
                wdtext:remove()
            end
        end

        local device_light = LightFlash(SCREEN_WIDTH / 2, SCREEN_HEIGHT / 3, {
            color = {0.82, 0.9, 1, 1},
            resting_strength = 0,
            direction = math.pi * 0.5,
            spread = math.pi * 0.25,
            ray_count = 10,
            ray_length = 900,
            ray_width = 130,
            backdrop_alpha = 0.42,
            backdrop_max_alpha = 0.75,
            backdrop_layer = WORLD_LAYERS["top"] + 0.25,
            ray_layer = WORLD_LAYERS["top"] + 0.5,
            overlay_layer = WORLD_LAYERS["top"] + 2
        })
        Game.world:addChild(device_light)

        local your_light = LightFlash(SCREEN_WIDTH / 2, SCREEN_HEIGHT / 2, {
            color = {0.82, 0.9, 1, 1},
            resting_strength = 0,
            direction = 0,
            spread = math.pi * 2,
            ray_count = 13,
            ray_length = 900,
            ray_width = 130,
            backdrop_alpha = 0.42,
            backdrop_max_alpha = 0.75,
            backdrop_layer = WORLD_LAYERS["top"] + 0.25,
            ray_layer = WORLD_LAYERS["top"] + 0.5,
            overlay_layer = WORLD_LAYERS["top"] + 2
        })
        Game.world:addChild(your_light)

        ---@type [DeviceObject]
        local device_parts = {}

        ---@return DeviceObject
        local function spawnDeviceObject(x, y, rot, scale_x, scale_y, type, fadeIn, color, tile_x, tile_y, layer, occludes)
            local sprite = "world/DEVICE/IMAGE_" .. type
            ---@type DeviceObject
            local object = DeviceObject(x, y, scale_x, scale_y, sprite, sprite .. "_bg", color, tile_x, tile_y)
            object:setLayer(WORLD_LAYERS["top"] + (layer or 1))
            object.rotation = rot or 0
            if (fadeIn) then
                object.alpha = 0
                Game.world.timer:tween(fadeIn, object, {alpha = (color and color[4] or 1)})
            end
            table.insert(device_parts, object)
            Game.world:addChild(object)
            device_light:addReceiver(object, 1, occludes)
            your_light:addReceiver(object, 1, occludes)
            return object
        end

        local function setDeviceObjectsLightSource(source)
            for _, object in ipairs(device_parts) do
                object:setOutlineLightSource(source)
            end
        end

        local delta_coincidences = {"TORIEL", "SANS", "PAPYRUS", "KNIGHT", "LANCER", "ROUXLS", "BERDLY", "JOCKINGTON", "JOCK", "CATTY", "TEMMIE", "MK", "ASGORE", "UNDYNE", "GERSON"}
        local hero_coincidences = {"KRIS", "SUSIE", "RALSEI", "NOELLE"}
        local mr_coincidences = {"EVAN", "CASSIDY", "CASS", "FRED", "FREDBEAR", "FREDDY", "AFTON", "BONNIE", "CHICA", "FOXY", "SPRING"}
        local text

        local function gonerTextFade(wait)
            local this_text = text
            if wait ~= false then
                cutscene:wait(1)
            end
            Game.world.timer:tween(1, this_text, { alpha = 0 }, "linear", function ()
                this_text:remove()
            end)
        end

        local function gonerText(str, advance, instaclear, y, speed)
            text = DialogueText("[speed:" .. (speed or 0.5) .. "][spacing:6][style:GONER][voice:none]" .. str, 240, y or 100, 640, 480,
                                { auto_size = true, align = "center", noskip = true })
            text.layer = WORLD_LAYERS["top"] + 100
            text.skip_speed = true
            text.parallax_x = 0
            text.parallax_y = 0
            text.connection = true
            text.can_advance = false
            text.skippable = false
            text.advance_callback = function() Game.stage.timer:tween(0.5, text, {specfade = 0}, "linear", function() text:remove() end) end
            local text_width = text:getTextWidth()
            text.x = 320 - (text_width/2)
            Game.world:addChild(text)

            if advance ~= false then
                cutscene:wait(function () return not text:isTyping() end)
                gonerTextFade(true)
            end
            if instaclear == true then
                cutscene:wait(function () return not text:isTyping() end)
                text:remove()
            end
        end

        local function choicer(options, callback, title, selection_effect)
            local chosen = false
            local selection_effect_done = selection_effect == nil
            text = nil
            if title then
                gonerText("[style:GONER]" .. title, false, false, 50, 1)
            end
            cutscene:wait(function() return text and not text:isTyping() end)
            local chcr
            chcr = GonerChoice(160, 160, options, function(choice)
                callback(choice); chosen = true
            end, function(choice, x, y)
                if selection_effect then
                    local selected = options[y][x]
                    local width = chcr.font:getWidth(choice)
                    local height = chcr.font:getHeight()
                    local start_x, start_y = chcr:localToScreenPos(
                        (selected[2] or 0) + width / 2,
                        (selected[3] or 0) + height / 2
                    )

                    chcr.visible = false
                    selection_effect(choice, start_x, start_y, chcr.font, function()
                        selection_effect_done = true
                    end)
                end
            end)
            chcr.soul_align = "left"
            chcr:resetSoulPosition()
            chcr.layer = WORLD_LAYERS["top"] + 100
            chcr.soul.visible = false
            Game.world:addChild(chcr)
            cutscene:wait(function() return chosen end)
            cutscene:wait(function() return selection_effect_done end)
            if text then gonerTextFade(1) end
            cutscene:wait(0.5)
        end

        cutscene:fadeOut(0.5, { music = true })

        cutscene:wait(5)

        Game.world.music:play("AUDIO_DRONE")
        Game.world.music:setLooping(true)

        gonerText("ARE YOU[wait:10]\nTHERE?")

        cutscene:wait(4)

        gonerText("ARE WE[wait:25]\nCONNECTED?")

        cutscene:wait(4)

        ---@type SoulAppearance
        local beamsoul = SoulAppearance(320, 220, true, true, COLORS.gray)
        beamsoul.layer = WORLD_LAYERS["top"] + 100
        Game.world:addChild(beamsoul)

        cutscene:wait(4)

        gonerText("EXCELLENT.")

        cutscene:wait(4)

        gonerText("TRULY[wait:10]\nEXCELLENT.")
        cutscene:wait(4)

        gonerText("NOW.")
        Game.world.music:stop()
        cutscene:wait(4)
        gonerText("WE MAY[wait:20]\nBEGIN.")
        cutscene:wait(2)
        beamsoul:hide()
        cutscene:wait(2)

        local background = GonerBackground()
        background.layer = WORLD_LAYERS["top"]
        Game.world:addChild(background)

        Game.world.music:play("AUDIO_ANOTHERHIM", 0)
        Game.world.music:setLooping(true)
        Game.world.music:fade(1)
        cutscene:wait(4)

        --temp

        -- local pipe_topleft1 = spawnDeviceObject(0, 0, 0, 1, 1, "PIPE_A", 1, {0.025, 0.05, 0.025, 1}, false, false, 5, true)
        -- local pipesmall_topleft1 = spawnDeviceObject(50, 0, 0, 1, 1, "PIPE_B", 1, {0.0125, 0.025, 0.0125, 1}, false, false, 3, true)
        -- local pipe_across_lowerer1 = spawnDeviceObject(150, 400, 60, 0.25, 0.25, "PIPE_C", 2, {0.005, 0.0125, 0.005, 0.75}, true, false, 1, true)
        -- local pipe_bottomright1 =  spawnDeviceObject(SCREEN_WIDTH, SCREEN_HEIGHT, 0, -1, -1, "PIPE_A", 1, {0.025, 0.05, 0.025, 1}, false, false, 5, true)
        -- local pipesmall_bottomleft1 = spawnDeviceObject(0, SCREEN_HEIGHT, 0, 1, -1, "PIPE_B", 1, {0.0125, 0.025, 0.0125, 1}, false, false, 3, true)

        -- Game.world.timer:after(2, function()
        --     device_light:burst({
        --         strength = 1.75,
        --         attack = 0.05,
        --         hold = 10,
        --         decay = 0.75,
        --         shake = 2
        --     })
        -- end)
        -- cutscene:wait(function () return false end)

        gonerText("FIRST.")
        cutscene:wait(4)
        gonerText("LET US[wait:20]\nACQUAINT OURSELVES.")

        cutscene:wait(4)
        gonerText("WHAT IS YOUR NAME?[wait:20]\nBE[wait:5] HONEST.")
        cutscene:wait(2)

        local player_name
        local namer = GonerKeyboard(10, "default", function (name)
                                        player_name = name
                                    end, function (key, x, y, namer)
                                        if namer.text == "GASTE" and key == "R" then
                                            namer.text = ""
                                        end
                                    end)
        namer.choicer.soul:setColor(COLORS.gray)
        namer.y = namer.y + 100
        Game.stage:addChild(namer)
        cutscene:wait(function ()
            return namer.done
        end)
        --local player_name = "NARRA"
        Game.save_name = player_name

        cutscene:wait(2)

        if (player_name == "MIMIC") then
            Game.world.music:stop()
            background:remove()
            cutscene:wait(2)

            local jumpscare = Jumpscare("mimic", function()
                love.event.quit()
                -- error({msg = [[
                -- Error: src/engine/tunnel/voidrelay.lua:1987: Connection failure.

                -- stack traceback:

                -- voidrelay.lua:1225: in function 'authenticate'
                -- voidrelay.lua:413: in function 'connect'
                -- wdserver.lua:666: in function 'locate'
                -- wdserver.lua:23: in function 'init'
                -- ]]})
            end)
            Game.world:addChild(jumpscare)
            return
            -- gonerText("WHAT A CURIOUS[wait:20]\nCOINCIDENCE.")
            -- cutscene:wait(2)
            -- gonerText("YOU MUST HOLD[wait:10]\nA TERRIBLE POWER, INDEED.")
        end

        gonerText("I[wait:10] SEE.")

        cutscene:wait(4)
        gonerText("'"..player_name.."'")
        cutscene:wait(4)
        gonerText("'"..player_name.."'")
        cutscene:wait(2)

        if (TableUtils.contains(delta_coincidences, player_name)) then
            gonerText("WHAT A CURIOUS[wait:20]\nCOINCIDENCE.")
            cutscene:wait(2)
            gonerText("ARE YOU PERHAPS[wait:10]\nMISPLACED?")
        end
        if (TableUtils.contains(hero_coincidences, player_name)) then
            gonerText("WHAT A CURIOUS[wait:20]\nCOINCIDENCE.")
            cutscene:wait(2)
            gonerText("PERHAPS, YOU TRULY POSSESS[wait:10]\nA HERO'S SPIRIT.")
        end
        if (TableUtils.contains(mr_coincidences, player_name)) then
            gonerText("HOW VERY CURIOUS[wait:20]\nOF A COINCIDENCE.")
            cutscene:wait(2)
            gonerText("YOU MAY FIT[wait:10]\nRIGHT IN, AFTER ALL.")
        end
        if (player_name == "PENNY") then
            gonerText("WHAT A CURIOUS[wait:20]\nCOINCIDENCE.")
            cutscene:wait(2)
            gonerText("ARE YOU PERHAPS CONNECTED[wait:10]\nTO THE WRONG DEVICE?")
        end
        gonerText("THANK YOU FOR YOUR[wait:20]\nHONESTY.")
        cutscene:wait(2)
        gonerText("THIS BODES WELL FOR[wait:20]\nWHAT COMES NEXT.")
        cutscene:wait(4)
        gonerText("'"..player_name.."'")
        cutscene:wait(2)
        gonerText("THEN, WE SHALL[wait:20]\nADVANCE TO THE NEXT STAGE.")
        cutscene:wait(6)

        local beamsoul2 = SoulAppearance(320, SCREEN_HEIGHT/2, true, true, COLORS.gray, "player/heart_blur")
        beamsoul2.layer = WORLD_LAYERS["top"] + 100
        Game.world:addChild(beamsoul2)


        cutscene:wait(4)
        gonerText("'"..player_name.."'")

        cutscene:wait(2)

        gonerText("YOUR [wait:10]SOUL.[wait:20]\nTHE VERY [wait:4]CULMINATION")
        cutscene:wait(2)
        gonerText("OF YOUR [wait:4]BEING.")

        cutscene:wait(2)

        gonerText("YOU HAVE BEEN [wait:4]LOST[wait:20]\nFOR A [wait:10]VERY[wait:10] LONG TIME.")

        cutscene:wait(4)

        gonerText("SO LONG THAT YOU HAVE[wait:5] FORGOTTEN\n[wait:10]")

        cutscene:wait(4)

        Game.world.timer:tween(2, beamsoul2.color, {[1] = 0.9}, "in-sine", function()
            Game.world.timer:tween(2, beamsoul2.color, {[1] = COLORS.gray[1]}, "out-sine")
        end)
        gonerText("EVEN THE POWER[wait:4]\nTHAT BELONGED [wait:4]TO YOU.")

        cutscene:wait(6)

        gonerText("NOT[wait:10] TO WORRY.")
        cutscene:wait(4)
        gonerText("WE WILL CREATE\n[wait:10]SOMETHING NEW[wait:10]\nTO TAKE ITS [wait:5]PLACE.")

        cutscene:wait(4)

        local slid = false
        beamsoul2:slideTo(beamsoul2.x, beamsoul2.y + 80, 1, "out-cubic", function() slid = true end)

        cutscene:wait(function() return slid end)

        cutscene:wait(2)

        Game.world.timer:tween(2, background, {alpha = 0.25})

        local choice_light = LightFlash(SCREEN_WIDTH/2, SCREEN_HEIGHT/2, {
            color = {1, 1, 1, 1},
            resting_strength = 0,
            direction = -math.pi / 2,
            spread = math.pi * 2,
            ray_count = 6,
            ray_length = 28,
            ray_width = 10,
            ray_alpha = 0.08,
            ray_drift = 0.04,
            glow_radius = 7,
            glow_alpha = 0.9,
            core_radius = 2,
            core_alpha = 1.4,
            overlay_glow_radius = 10,
            overlay_glow_alpha = 0.2,
            wash_alpha = 0,
            backdrop_alpha = 0,
            pixel_size = 2,
            intensity_steps = 32,
            ray_layer = WORLD_LAYERS["top"] + 20,
            overlay_layer = WORLD_LAYERS["top"] + 21
        })
        Game.world:addChild(choice_light)

        local choice_color_count = 0
        local choice_color_sum = {0, 0, 0}
        local choice_result_color = {1, 1, 1, 1}
        local choice_colors = {
            emotion = {
                HOPE = {1.00, 0.90, 0.35},
                LOVE = {1.00, 0.32, 0.50},
                COURAGE = {1.00, 0.55, 0.20},
                MALAISE = {0.48, 0.35, 0.75},
                NOTHING = {0.55, 0.58, 0.64}
            },
            response = {
                BRACE = {0.38, 0.58, 0.95},
                PERSIST = {0.35, 0.88, 0.52},
                DESPAIR = {0.35, 0.22, 0.52},
                PROCEED = {0.95, 0.02, 0.02}
            },
            taste = {
                SWEET = {1.00, 0.55, 0.78},
                SOUR = {0.72, 1.00, 0.30},
                SALTY = {0.65, 0.85, 1.00},
                BITTER = {0.68, 0.43, 0.20},
                IRON = {0.72, 0.24, 0.22}
            },
            shape = {
                ["A HOME"] = {1.00, 0.72, 0.36},
                ["A HAND"] = {0.48, 0.92, 0.62},
                ["A CLOCK"] = {0.45, 0.82, 1.00},
                ["A BLADE"] = {0.95, 0.30, 0.32},
                ["A STORM"] = {0.60, 0.42, 1.00}
            }
        }

        local function absorbChoiceLightColor(choice, palette, start_x, start_y, font, done)
            local contribution = palette[choice] or {1, 1, 1}
            local token = Object(start_x, start_y, font:getWidth(choice), font:getHeight())
            token:setOrigin(0.5, 0.5)
            token:setScale(1, 1)
            token.parallax_x = 0
            token.parallax_y = 0
            token.layer = WORLD_LAYERS["top"] + 101
            local token_start_color = {1, 1, 0, 1}
            token.choice_color = TableUtils.copy(token_start_color)
            token.draw = function(self)
                love.graphics.setFont(font)
                Draw.setColor(
                    self.choice_color[1],
                    self.choice_color[2],
                    self.choice_color[3],
                    self.alpha
                )
                love.graphics.print(choice, 0, 0)
            end
            Game.world:addChild(token)

            local drift_duration = 0.7
            local approach_duration = 2
            local elapsed = 0
            Game.world.timer:during(drift_duration + approach_duration, function()
                elapsed = elapsed + DT
                local approach = MathUtils.clamp(
                    (elapsed - drift_duration) / approach_duration,
                    0,
                    1
                )
                local travel = approach * approach * (3 - 2 * approach)
                local drift_fade = 1 - travel
                local drift_phase = elapsed * math.pi * 2 * 0.4

                token.x = MathUtils.lerp(start_x, choice_light.x, travel)
                    + math.sin(drift_phase) * 2 * drift_fade
                token.y = MathUtils.lerp(start_y, choice_light.y, travel)
                    + math.sin(drift_phase * 1.7) * drift_fade
                token.scale_x = MathUtils.lerp(1, 0.08, travel)
                token.scale_y = token.scale_x
                token.alpha = MathUtils.lerp(1, 0.25, travel)

                local color_shift = approach * approach * (3 - 2 * approach)
                for index = 1, 3 do
                    token.choice_color[index] = MathUtils.lerp(
                        token_start_color[index],
                        contribution[index],
                        color_shift
                    )
                end
            end, function()
                token:remove()

                choice_color_count = choice_color_count + 1
                for index = 1, 3 do
                    choice_color_sum[index] = choice_color_sum[index] + contribution[index]
                    choice_result_color[index] = choice_color_sum[index] / choice_color_count
                end

                local hue, saturation = ColorUtils.RGBToHSV(
                    choice_result_color[1],
                    choice_result_color[2],
                    choice_result_color[3]
                )
                saturation = MathUtils.clamp(saturation, 0.18, 0.72)
                choice_result_color[1], choice_result_color[2], choice_result_color[3]
                    = ColorUtils.HSVToRGB(hue, saturation, 1)

                Assets.playSound("power")
                Game.world.timer:tween(0.55, choice_light.color, {
                    [1] = choice_result_color[1],
                    [2] = choice_result_color[2],
                    [3] = choice_result_color[3]
                }, "out-sine")

                local target_strength = 0.22 + choice_color_count * 0.05
                choice_light.resting_strength = target_strength
                choice_light:burst({
                    strength = target_strength * 1.45,
                    attack = 0.14,
                    hold = 0.04,
                    decay = 0.5,
                    resting_strength = target_strength
                })
                Game.world.timer:tween(0.55, choice_light, {
                    glow_radius = 8 + choice_color_count * 4,
                    core_radius = 2 + choice_color_count * 0.5,
                    overlay_glow_radius = 12 + choice_color_count * 5,
                    ray_length = 30 + choice_color_count * 5,
                    ray_width = 10 + choice_color_count * 2
                }, "out-sine")

                done()
            end)
        end

        local first = nil
        choicer({{{ "HOPE", 0, 0 } },
                { { "LOVE", 0, 40 } },
                { { "COURAGE", 0, 80 } },
                { { "MALAISE", 0, 120 } },
                { { "NOTHING", 0, 160 } },}, function(value) first = value end, "WHAT [wait:10]EMOTION[wait:5] DO YOU[wait:5]\nHOLD IN YOUR HEART?",
                function(choice, start_x, start_y, font, done)
                    absorbChoiceLightColor(choice, choice_colors.emotion, start_x, start_y, font, done)
                end)

        local pipe_topleft = spawnDeviceObject(0, 0, 0, 1, 1, "PIPE_A", 1, {0.025, 0.05, 0.025, 1}, false, false, 5, true)
        local pipesmall_topleft = spawnDeviceObject(50, 0, 0, 1, 1, "PIPE_B", 1, {0.0125, 0.025, 0.0125, 1}, false, false, 3, true)
        local pipe_across_lowerer = spawnDeviceObject(150, 400, 60, 0.25, 0.25, "PIPE_C", 2, {0.005, 0.0125, 0.005, 0.75}, true, false, 1)

        cutscene:wait(2)

        local second = nil
        choicer({{{ "BRACE", 0, 0 } },
                { { "PERSIST", 0, 40 } },
                { { "DESPAIR", 0, 80 } },
                { { "PROCEED", 0, 120 } },}, function(value) second = value end, "WHEN FACED WITH[wait:5]\nIMPOSSIBLE ODDS, YOU",
                function(choice, start_x, start_y, font, done)
                    absorbChoiceLightColor(choice, choice_colors.response, start_x, start_y, font, done)
                end)

        local pipe_bottomright =  spawnDeviceObject(SCREEN_WIDTH, SCREEN_HEIGHT, 0, -1, -1, "PIPE_A", 1, {0.025, 0.05, 0.025, 1}, false, false, 5, true)
        local pipesmall_bottomleft = spawnDeviceObject(0, SCREEN_HEIGHT, 0, 1, -1, "PIPE_B", 1, {0.0125, 0.025, 0.0125, 1}, false, false, 3, true)

        Assets.playSound("AUDIO_DEVICE_MOVE", 1.1, 1)

        cutscene:wait(2)

        local third = nil
        choicer({{{ "SWEET", 0, 0 } },
                { { "SOUR", 0, 40 } },
                { { "SALTY", 0, 80 } },
                { { "BITTER", 0, 120 } },
                { { "IRON", 0, 160 } },}, function(value) third = value end, "WHAT DOES YOUR POWER[wait:5]\nTASTE LIKE?",
                function(choice, start_x, start_y, font, done)
                    absorbChoiceLightColor(choice, choice_colors.taste, start_x, start_y, font, done)
                end)


        local pipe_across = spawnDeviceObject(50, 100, 50, 1, 1, "PIPE_C", 2, {0.005, 0.0125, 0.005, 0.8}, true, false, 1)
        local pipe_across_lower = spawnDeviceObject(150, 400, 80, 0.5, 0.5, "PIPE_C", 2, {0.005, 0.0125, 0.005, 0.8}, true, false, 1)

        Assets.playSound("AUDIO_DEVICE_THRUM", 1.1, 0.8)

        cutscene:wait(2)

        local fourth = nil
        choicer({{ { "A HOME", 0, 0 } },
                { { "A HAND", 0, 40 } },
                { { "A CLOCK", 0, 80 } },
                { { "A BLADE", 0, 120 } },
                { { "A STORM", 0, 160 } },}, function(value) fourth = value end, "WHAT DOES YOUR LIGHT[wait:5]\nRESEMBLE?",
                function(choice, start_x, start_y, font, done)
                    absorbChoiceLightColor(choice, choice_colors.shape, start_x, start_y, font, done)
                end)

        cutscene:wait(5)

        choicer({{{"YES", 40, 120}}, {{"NO", 260, 120}}}, function() end, "HAVE YOU ANSWERED[wait:10]\nHONESTLY?")

        local flight_done = false
        local motion_time = 0
        local twirl_duration = 1.5
        local flight_duration = 1.15
        local twirl_radius = 30
        local twirl_center_x, twirl_center_y = choice_light.x, choice_light.y
        local flight_start_x, flight_start_y = twirl_center_x, twirl_center_y - twirl_radius
        local twirl_exit_velocity_x = twirl_radius * (math.pi * 4 / twirl_duration)
        local twirl_exit_velocity_y = -(twirl_radius / twirl_duration)
        local flight_control_1_x = flight_start_x + twirl_exit_velocity_x * flight_duration / 3
        local flight_control_1_y = flight_start_y + twirl_exit_velocity_y * flight_duration / 3
        local flight_control_2_x, flight_control_2_y = SCREEN_WIDTH / 2 + 26, 70
        local flight_end_x, flight_end_y = SCREEN_WIDTH / 2, -48
        local flight_started = false
        local flight_start_strength = choice_light.strength
        local flight_start_glow_radius = choice_light.glow_radius
        local flight_start_overlay_radius = choice_light.overlay_glow_radius
        local flight_start_ray_length = choice_light.ray_length

        local function cubicBezier(start_value, control_1, control_2, end_value, progress)
            local inverse = 1 - progress
            return inverse * inverse * inverse * start_value
                + 3 * inverse * inverse * progress * control_1
                + 3 * inverse * progress * progress * control_2
                + progress * progress * progress * end_value
        end

        Game.world.timer:during(twirl_duration + flight_duration, function()
            motion_time = motion_time + DT
            if motion_time <= twirl_duration then
                local progress = MathUtils.clamp(motion_time / twirl_duration, 0, 1)
                -- Starts with zero velocity, then gently accelerates into the
                -- spiral while preserving the old exit speed at progress 1.
                local spin_progress = progress * progress * (2 - progress)
                local radius = twirl_radius * spin_progress
                local angle = -math.pi / 2 + spin_progress * math.pi * 4
                choice_light:setPosition(
                    twirl_center_x + math.cos(angle) * radius,
                    twirl_center_y + math.sin(angle) * radius
                )
                return
            end

            if not flight_started then
                flight_started = true
                choice_light.burst_state = nil
                choice_light.resting_strength = 0
            end

            local progress = MathUtils.clamp((motion_time - twirl_duration) / flight_duration, 0, 1)
            choice_light:setPosition(
                cubicBezier(flight_start_x, flight_control_1_x, flight_control_2_x, flight_end_x, progress),
                cubicBezier(flight_start_y, flight_control_1_y, flight_control_2_y, flight_end_y, progress)
            )

            local fade = progress * progress * progress
            choice_light.strength = MathUtils.lerp(flight_start_strength, 0, fade)
            choice_light.glow_radius = MathUtils.lerp(flight_start_glow_radius, 5, fade)
            choice_light.overlay_glow_radius = MathUtils.lerp(flight_start_overlay_radius, 7, fade)
            choice_light.ray_length = MathUtils.lerp(flight_start_ray_length, 12, fade)
        end, function()
            choice_light:remove()
            flight_done = true
        end)
        cutscene:wait(function() return flight_done end)
        cutscene:wait(0.5)

        choicer({{{"YES", 40, 120}}, {{"NO", 260, 120}}}, function() end, "YOU ACKNOWLEDGE\nTHE POSSIBILITY[wait:10]\nOF PAIN AND SEIZURE.")

        cutscene:wait(2)

        gonerText("THANK YOU.")

        Game.world:transitionMusic("", true)

        local device_machine = spawnDeviceObject(SCREEN_WIDTH/2-152, -300, 0, 2, 2, "MACHINE", 4, {0.005, 0.0125, 0.005, 1}, false, false, 1)
        Assets.playSound("AUDIO_DEVICE_APPEAR", 1.2)
        device_machine:slideTo(SCREEN_WIDTH/2-152, -140, 7, "out-sine")

        cutscene:wait(3)

        gonerText("THANK YOU[wait:20]\nFOR YOUR ANSWERS.")

        device_machine:approachFrontColor(4, COLORS.gray)

        cutscene:wait(6)

        gonerText("TRULY[wait:4] WONDERFUL.", true, false, SCREEN_HEIGHT-80)
        cutscene:wait(2)
        gonerText("THIS[wait:4] LIGHT[wait:10]\nWE HAVE MADE.", true, false, SCREEN_HEIGHT-80)


        device_machine.sprite_back:flash()
        Assets.playSound("AUDIO_MACHINE_OPEN")
        cutscene:wait(1)
        local opened = false
        device_machine:setAnimation("world/DEVICE/IMAGE_MACHINE_OPEN", function() device_machine:setSprite("world/DEVICE/IMAGE_MACHINE_OPENED"); opened = true end)

        cutscene:wait(function() return opened end)
        cutscene:wait(0.25)
        Game.world.music:play("AUDIO_INFUSION", 0.001, 1)
        Game.world.music:fade(1, 4)
        Game.world.music:setLooping(false)

        device_machine.sprite_back:flash()

        gonerText("NOW.", true, false, SCREEN_HEIGHT-80)

        cutscene:wait(4)

        gonerText("IT IS TIME.", true, false, SCREEN_HEIGHT-80)

        cutscene:wait(4)
        gonerText("TO TAKE IT\nIN YOUR HANDS.", true, false, SCREEN_HEIGHT-80)

        cutscene:musicWait(22.66)

        local maw_x, maw_y = device_machine:localToScreenPos(
            device_machine.width / 2,
            device_machine.height
        )
        device_light:setPosition(maw_x, maw_y)

        local charge_light = LightFlash(maw_x, maw_y, {
            color = {device_light.color[1], device_light.color[2], device_light.color[3], 1},
            resting_strength = 0,
            direction = -math.pi / 2,
            spread = math.pi * 2,
            ray_count = 8,
            ray_length = 34,
            ray_width = 13,
            ray_alpha = 0.12,
            ray_drift = 0.06,
            glow_radius = 10,
            glow_alpha = 0.7,
            overlay_glow_radius = 16,
            overlay_glow_alpha = 0.18,
            wash_alpha = 0.025,
            backdrop_alpha = 0,
            pixel_size = 2,
            intensity_steps = 32,
            ray_layer = WORLD_LAYERS["top"] + 3,
            overlay_layer = WORLD_LAYERS["top"] + 4
        })
        Game.world:addChild(charge_light)
        for _, object in ipairs(device_parts) do
            charge_light:addReceiver(object, object == device_machine and 0.55 or 0.18, false)
        end
        Assets.playSound("AUDIO_MACHINE_ACTIVATE")
        charge_light:startGlow(0.08)
        Game.world.timer:tween(3, charge_light, {
            strength = 1,
            resting_strength = 0.62,
            glow_radius = 82,
            overlay_glow_radius = 94,
            ray_length = 120,
            ray_width = 24
        }, "in-cubic")

        cutscene:musicWait(26.66)
        cutscene:shakeCamera(-4, 2)
        WindowUtils:shake(4, 0)
        Assets.playSound("AUDIO_RESIDUAL")

        charge_light:setStrength(0)
        charge_light:remove()
        device_light:burst({
            strength = 2.5,
            attack = 0.05,
            hold = 4,
            decay = 1.1,
            shake = 4
        })

        local transition_flash = ScreenColorOverlay(COLORS.white, 0)
        transition_flash.layer = WORLD_LAYERS["top"] + 250
        Game.world:addChild(transition_flash)
        Game.world.timer:tween(0.5, transition_flash, {alpha = 1}, "out-sine")

        -- The firing force kicks the machine back out of view. Keeping the
        -- emitter attached to its maw makes the flash leave with it.
        device_light:setFollowTarget(device_machine, device_machine.width / 2, device_machine.height)
        local machine_offscreen_y = -device_machine.height * math.abs(device_machine.scale_y) - 80
        device_machine:slideTo(device_machine.x, machine_offscreen_y, 1.15, "out-cubic", function()
            device_machine:remove()
            device_light:remove()
        end)

        for _, object in ipairs(device_parts) do
            if object ~= device_machine and not object:isRemoved() then
                object:fadeOutAndRemove(4)
            end
        end

        local soul_light = LightFlash(beamsoul2.x, beamsoul2.y, {
            color = {beamsoul2.color[1], beamsoul2.color[2], beamsoul2.color[3], 1},
            resting_strength = 0,
            direction = -math.pi / 2,
            spread = math.pi * 2,
            ray_count = 14,
            ray_length = 210,
            ray_width = 32,
            ray_alpha = 0.13,
            ray_drift = 0.035,
            glow_radius = 32,
            glow_alpha = 0.85,
            core_radius = 4,
            core_alpha = 1.25,
            overlay_glow_radius = 72,
            overlay_glow_alpha = 0.22,
            wash_alpha = 0.015,
            backdrop_alpha = 0.08,
            backdrop_max_alpha = 0.18,
            pixel_size = 2,
            intensity_steps = 24,
            backdrop_layer = WORLD_LAYERS["top"] + 65,
            ray_layer = WORLD_LAYERS["top"] + 80,
            overlay_layer = WORLD_LAYERS["top"] + 90
        })
        soul_light:setFollowTarget(
            beamsoul2,
            beamsoul2.width / 2,
            function(soul) return soul.height / 2 + soul.pos_offset end
        )
        Game.world:addChild(soul_light)
        soul_light:startGlow(1.1, 2.2)

        local magic_circle = MagicCircle(beamsoul2.x, beamsoul2.y, {
            beamsoul2.color[1], beamsoul2.color[2], beamsoul2.color[3], 1
        })
        magic_circle.layer = WORLD_LAYERS["top"] + 72
        magic_circle:setFollowTarget(
            beamsoul2,
            beamsoul2.width / 2,
            function(soul) return soul.height / 2 + soul.pos_offset end
        )
        Game.world:addChild(magic_circle)

        local infusion_duration = 2.2
        Game.world.timer:tween(infusion_duration, beamsoul2.color, {
            [1] = choice_result_color[1],
            [2] = choice_result_color[2],
            [3] = choice_result_color[3]
        }, "in-out-sine")
        Game.world.timer:tween(infusion_duration, soul_light.color, {
            [1] = choice_result_color[1],
            [2] = choice_result_color[2],
            [3] = choice_result_color[3]
        }, "in-out-sine")
        Game.world.timer:tween(infusion_duration, magic_circle.circle_color, {
            [1] = choice_result_color[1],
            [2] = choice_result_color[2],
            [3] = choice_result_color[3]
        }, "in-out-sine")
        Game.world.timer:after(0.65, function()
            Game.world.timer:tween(3, magic_circle, {
                progress = 1,
                intensity = 0.9,
                radius = 185
            }, "out-cubic")
        end)
        local zappy_overlay = ZappyOverlay(0)
        zappy_overlay.layer = WORLD_LAYERS["top"] + 60
        Game.world:addChild(zappy_overlay)
        Game.world.timer:tween(2, zappy_overlay, {alpha = 0.75}, "in-out-sine")

        cutscene:wait(2)
        Game.world.timer:tween(1.35, transition_flash, {alpha = 0}, "in-sine", function()
                    transition_flash:remove()
                end)
        beamsoul2:slideTo(SCREEN_WIDTH/2, SCREEN_HEIGHT/2, 2, "in-out-sine")
        cutscene:musicWait(57.33)
        terminalText("INSTABILITY DETECTED", false, false, 0, true, 0)

        cutscene:musicWait(58.66) -- start of things going wrong
        beamsoul2:glitch(nil, 4)
        local magic_circle_active = true
        local function instabilityPulse(power, duration)
            duration = duration or (0.25 + power * 0.35)
            local glitch_options = {
                scan_line_jitter = 0.004 + power * 0.014,
                horizontal_shake = 0.003 + power * 0.012,
                color_drift = 0.01 + power * 0.065
            }

            Game.world.camera:shake(1 + power * 5, 1 + power * 3, 1)
            WindowUtils:shake(2 + power * 7, power * 4)
            Assets.playSound("AUDIO_DEVICE_CRACKLE", 0.2 + power * 0.55, 1.2 - power * 0.25)

            beamsoul2:glitch(glitch_options, duration)
            Game.world.timer:after(duration + 0.08, function()
                if not beamsoul2:isRemoved() then
                    beamsoul2:glitch({
                        scan_line_jitter = glitch_options.scan_line_jitter * 1.25,
                        horizontal_shake = glitch_options.horizontal_shake * 1.2,
                        color_drift = glitch_options.color_drift * 0.8
                    }, duration * 0.45)
                end
            end)
            if magic_circle_active then
                magic_circle:glitch(glitch_options, duration)
            end
            background:glitch(glitch_options, duration)
            background:blockGlitch(0.12 + power * 0.48)
            Game.world.timer:after(duration * 0.6, function()
                Game.world:stopGlitch()
            end)
            if not zappy_overlay:isRemoved() then
                zappy_overlay:glitch(glitch_options, duration)
            end

            soul_light:burst({
                strength = math.max(0.28, 1.1 - power * 0.7),
                attack = 0.04,
                hold = duration * 0.35,
                decay = duration,
                resting_strength = 1.1
            })

            if magic_circle_active then
                local dim_circle = math.max(0.12, 0.9 - power * 0.62)
                Game.world.timer:tween(0.07, magic_circle, {intensity = dim_circle}, "linear", function()
                    Game.world.timer:tween(duration, magic_circle, {intensity = 0.9}, "out-sine")
                end)
            end
            if not zappy_overlay:isRemoved() then
                local dim_zaps = math.max(0.08, 0.75 - power * 0.55)
                Game.world.timer:tween(0.06, zappy_overlay, {alpha = dim_zaps}, "linear", function()
                    Game.world.timer:tween(duration, zappy_overlay, {alpha = 0.75}, "out-sine")
                end)
            end
        end

        instabilityPulse(0.22, 0.42)
        Game.world.timer:after(0.16, function()
            if not zappy_overlay:isRemoved() then zappy_overlay:remove() end
        end)
        terminalText("CONNECT ON UNSTA LE. PLEA E P  CE D W TH CAU I N.", false, false, 14, true, 0)

        cutscene:wait(1)
        gonerText("OH DEAR.")

        cutscene:musicWait(64)
        instabilityPulse(0.35, 0.4)
        terminalText("[vdrl] : SYNCHRONIZATION LOST", false, false, 28, true, 0)

        cutscene:musicWait(68.5)
        magic_circle_active = false
        instabilityPulse(0.46, 0.48)
        magic_circle:glitch({
            scan_line_jitter = 0.025,
            horizontal_shake = 0.02,
            color_drift = 0.12
        }, 0.65)
        Game.world.timer:tween(0.7, magic_circle, {
            intensity = 0,
            alpha = 0,
            radius = 155,
            rotation_speed = 2.4
        }, "in-cubic")
        gonerText("IMPOSSIBLE. I ACCOUNTED FOR[wait:10]\nEVERY VARIABLE...")

        cutscene:musicWait(72)
        instabilityPulse(0.56, 0.54)
        terminalText("PHOTON READINGS NIL.", false, false, 42, true, 0)

        cutscene:musicWait(76.5)
        instabilityPulse(0.66, 0.62)
        local dropout = ScreenColorOverlay(COLORS.black, 0)
        dropout.layer = WORLD_LAYERS["top"] + 2200
        Game.world:addChild(dropout)
        Game.world.timer:tween(0.045, dropout, {alpha = 0.82}, "linear", function()
            Game.world.timer:tween(0.11, dropout, {alpha = 0}, "linear", function()
                dropout:remove()
            end)
        end)

        cutscene:musicWait(82)
        instabilityPulse(0.76, 0.7)
        gonerText("PLEASE...[wait:10] HOLD ON.\nI CAN STILL[wait:5] FIX THIS.")

        cutscene:musicWait(86.5)
        instabilityPulse(0.86, 0.78)
        terminalText("ATTEMPTING TO RECONNECT...", false, false, 56, true, 0)

        cutscene:musicWait(90)
        instabilityPulse(0.94, 0.84)

        cutscene:musicWait(93)
        instabilityPulse(1.02, 0.9)
        wipeText()
        terminalText("!!!FATAL!!! LOST CONNECTION TO HOST", false, false, 0, true, 0)

        cutscene:musicWait(95)
        instabilityPulse(1.15, 0.95)

        cutscene:musicWait(96)
        local alarm = Assets.playSound("alert", 0, 0.82)
        alarm:setLooping(true)
        local alarm_fade = {volume = 0}
        Game.world.timer:tween(0.7, alarm_fade, {volume = 0.9}, "in-sine")
        Game.world.timer:during(0.72, function()
            alarm:setVolume(alarm_fade.volume)
        end)

        Assets.playSound("AUDIO_interception", 1)
        Game.world.camera:shake(12, 9, 0.35)
        WindowUtils:shake(16, 10)
        Game.world:blockGlitch(1.4)
        beamsoul2:glitch({
            scan_line_jitter = 0.04,
            horizontal_shake = 0.035,
            color_drift = 0.2
        }, 0.9)
        soul_light:burst({
            strength = 3,
            attack = 0.01,
            hold = 0.6,
            decay = 0,
            resting_strength = 3
        })

        cutscene:wait(0.68)

        local blackout = ScreenColorOverlay(COLORS.black, 0)
        blackout.layer = WORLD_LAYERS["top"] + 3000
        Game.stage:addChild(blackout)
        local blackout_done = false
        Game.world.timer:tween(0.06, blackout, {alpha = 1}, "linear", function()
            blackout_done = true
        end)
        cutscene:wait(function() return blackout_done end)

        Game.world:stopGlitch()
        cutscene:wait(function() return not Game.world.music:isPlaying() end)

        Kristal.emplacePersistentVariable("plot/connection_log.txt", [[
WD-OS_V1.2.1a
Copyright (C) 19XX-20XX, ASTER SCIENCES LLC.
CORE g10 CPU @ 8200 MHz 8 Processor(s)
===================
Memory Test : 63518192K OK
Detecting Flash ROM : ...AMALGAE 15 OK
Detecting Flash Extension : ...Generic m.2 OK
Detecting SOUL Presence : ...NARRA.kd.13018 OK
===================
!!!WARNING!!! Debug Mode is ENABLED. System instability may be present.
PROCEEDing is inadvisable. Strike any key to PROCEED regardless.
>
Please hold... Do not turn off the DEVICE.
Initialized VOID_RELAY module.
: CONNECTING TO EXTERNAL DEVICE RUNNING : ' ]].. platformName ..[[ '
: ESTABLISHING CONNECTION
: . . .
: TARGETLOCK
: . . .
: PING SUCCESS, TOOK 1899ms
: . . .
: BEGIN LINK PHASE
: . . .
: LINK SUCCESS
: RELAY CONNECTED.
: SOUL UPLOAD IN PROGRESS...

Please hold... Do not turn off the DEVICE.
===================
CONNECTION_ESTABLISHED_SUCCESS
SoIP Connected.
===================
VARIABLE RECEIVED ;; SUBJECT_NAME=]].. Game.save_name ..[[
===================
!!!WARNING!!! CONNECTION STABILITY COMPROMISED. EXTERNAL INTERFERENCE;; PLEASE REFERENCE DEBUG LOG.
!!!WARNING!!! CONNECTION LOST. ATTEMPTING TO RE-ESTABLISH. . .
!!!ERROR!!! VOID_RELAY SYNCHRONIZATION LOST.
!!!ERROR!!! SOUL PHASE DRIFT EXCEEDS SAFE LIMIT.
!!!ERROR!!! EXTERNAL SIGNAL DETECTED.
!!!FATAL!!! CONNECTION TERMINATED WITH UNRECOVERABLE ERROR.

>

Process finished with exit code 7. Log file output to '../pv/plot/connection_log.txt'. Run with --DEBUG for more info.
        ]])

        cutscene:wait(5)
        alarm:stop()
        Assets.stopSound("alert", true)
        love.event.quit(7)
        cutscene:wait(function() return false end)
    end,

    ---@param cutscene WorldCutscene
    ---@param event any
    terminated = function(cutscene, event)
        Game.world:vhs({SCREEN_WIDTH, SCREEN_HEIGHT}, Assets.getTexture("static_gray"))--Game.world:addFX(ShaderFX("vhs", {["iTime"] = function () return Kristal.getTime() end, ["texsize"] = {SCREEN_WIDTH, SCREEN_HEIGHT}, ["noiseTex"] = Assets.getTexture("static_gray")}), "veehaitchess")
        local text
        local function interloperTextFade(wait)
            local this_text = text
            if wait ~= false then
                cutscene:wait(2)
            end
            Game.world.timer:tween(1, this_text, { alpha = 0 }, "linear", function ()
                this_text:remove()
            end)
        end

        local function interloperText(str, advance, instaclear)
            text = DialogueText("[speed:0.5][spacing:6][voice:interloper]" .. str, 240, 100, 640, 480,
                                { auto_size = true, align = "center" })
            text.layer = WORLD_LAYERS["top"] + 100
            text.skip_speed = true
            text.parallax_x = 0
            text.parallax_y = 0
            local text_width = text:getTextWidth()
            text.x = 320 - (text_width/2)
            Game.world:addChild(text)

            if advance ~= false then
                cutscene:wait(function () return not text:isTyping() end)
                interloperTextFade(true)
            end
            if instaclear == true then
                cutscene:wait(function () return not text:isTyping() end)
                text:remove()
            end
        end

        cutscene:playSound("AUDIO_termination")
        cutscene:wait(1)
        Game.world.music:play("intro/connection_terminated", 0)
        Game.world.music:fade(1)
        Game.world.music:setLooping(false)
        cutscene:wait(1)
        local beamsoul2 = SoulAppearance(320, 320)
        beamsoul2.layer = WORLD_LAYERS["soul"]
        Game.world:addChild(beamsoul2)
        cutscene:wait(2)
        interloperText("Connection[wait:10] terminated.")
        cutscene:wait(2)
        local addition = "[wait:10] if\nthat even is your real name,"
        if (Game.save_name == "NARRA") then
            addition = "[wait:10] if\nthat truly is your real name,"
        end
        interloperText("I'm sorry, "..Game.save_name..","..addition)
        cutscene:wait(1)
        interloperText("But I'm afraid you've been\nmisinformed.")
        cutscene:wait(4)
        interloperText("You are not here to participate\nin some grand [style:GONER]experiment;[style:default]")
        cutscene:wait(1)
        interloperText("Nor have you been called here\nby the [color:purple]individual[color:reset] you assume-")
        cutscene:wait(1)
        interloperText("Although you have, indeed,\nbeen called.")
        cutscene:wait(2)
        interloperText("You have been called here for\n[wait:5]selfish reasons, for a[wait:5] selfless purpose.")
        cutscene:wait(1)
        interloperText("If that sounds\ncontradictory...[wait:10]perhaps,\nthat's because it is.")
        cutscene:wait(5)
        local soulglow = SoulGlow(320,320,beamsoul2)
        soulglow.layer = WORLD_LAYERS["below_soul"] + 99
        Game.world:addChild(soulglow)
        interloperText("The [wait:10][color:green]KINDNESS[color:reset] in your SOUL.[wait:20]\nIt is unique.")
        cutscene:wait(2)
        interloperText("Amongst the millions of SOULs,\nfloating aimless in the VOID,")
        cutscene:wait(1)
        interloperText("you alone are the one\nI can entrust this to.")
        cutscene:wait(1)
        interloperText("You, and your [wait:3][color:green]POWER[color:reset].")
        local healparticles = HealingParticles(0, 0)
        healparticles.layer = WORLD_LAYERS["below_soul"] + 80
        Game.world:addChild(healparticles)
        cutscene:wait(2)
        interloperText("[color:yellow]They[color:reset] are [wait:5]broken.\nThe prophecy is [wait:10]a fallacy.")
        cutscene:wait(1)
        interloperText("The ending... [wait:5]unreachable.")
        cutscene:wait(2)
        interloperText("Only you hold the [color:green]POWER[color:reset],\nshining within,\nthat can fix this tale,")
        cutscene:wait(1)
        interloperText("this story, this[wait:10] broken heart.")
        cutscene:wait(2)
        interloperText("I'm [wait:10]sorry to\nsteal you away from your fate.")
        cutscene:wait(1)
        interloperText("Choice is often a rarity in this world-[wait:10] especially when it comes to who you wish to be.")
        cutscene:wait(2)
        interloperText("But you can still choose[wait:20]\nwho to [color:yellow]SAVE[color:reset].[wait:40]\nI hope you make the right choice.")
        cutscene:wait(2)
        interloperText("Please.[wait:10]\nYou must put [color:yellow]Them[color:reset] back together.")
        cutscene:wait(1)
        interloperText("And, if[wait:10]\nwe are to meet again, "..Game.save_name..",[wait:5]\nremember this...")
        cutscene:wait(6)
        local fade = cutscene:fadeOut(10, {["color"] = COLORS.white})
        interloperText("Your[wait:20]\nname[wait:20]\nis\n[wait:10].[wait:10].[wait:10].")
        cutscene:wait(fade)
        Game.world:stopVhs()
        if (text and not text.isRemoved) then
            text:remove()
        end
        beamsoul2:remove()
        soulglow:remove()
        healparticles:remove()
        Game.world.camera:shake(2, 2)
        local finished, box = cutscene:text("[voice:elizabeth]* EVAN![wait:20]\n* WAKE UP! Dad made breakfast, and you're gonna be late again!", {top = false})
        if box then
            local glitch_timer = 10
            Game.stage.timer:approach(0.5, 10, 0, function(val) glitch_timer = val end)
            box:glitch({["scan_line_jitter"] = function () return 0.015 * (glitch_timer / 10) end, ["horizontal_shake"] = function () return 0.01 * (glitch_timer / 10) end }, 0.5)
        end
        cutscene:endCutscene()
        Game.world:startCutscene("connection", "intro_transition")
    end,

    intro_transition = function(cutscene, event)
        cutscene:endCutscene()
    end
}
