return {
    ---@param cutscene WorldCutscene
    ---@param soul WorldSoul
    arrival = function(cutscene, soul)
        soul = soul or Game.world.world_soul
        assert(soul, "The Wastes arrival cutscene requires a WorldSoul")

        soul.can_move = false
        soul.is_active = false

        local camera = Game.world.camera
        local previous_keep_in_bounds = camera.keep_in_bounds
        local resting_hover = soul.arrival_hover_height or 7
        local target_x, target_y = camera:getTargetPosition()
        camera.keep_in_bounds = false
        cutscene:detachCamera()
        camera:setPosition(target_x, target_y - SCREEN_HEIGHT * 2)

        cutscene:wait(0.75)
        cutscene:wait(cutscene:panTo(target_x, target_y, 5, "in-out-sine"))
        cutscene:wait(1.25)

        local hover_done = false
        Game.world.timer:tween(1.75, soul, {
            hover_height = resting_hover
        }, "in-out-sine", function()
            hover_done = true
        end)
        cutscene:wait(function() return hover_done end)
        soul.hover_bob = soul.arrival_hover_bob or 1
        cutscene:wait(0.75)

        camera.keep_in_bounds = previous_keep_in_bounds
        camera:keepInBounds()
        cutscene:wait(cutscene:attachCamera(0.6))

        Mod:releaseWastesCageBack()
        Mod:releaseWastesCageFront()
        Mod:releaseWastesSoul(soul)
        soul.can_move = true
        soul.is_active = true
        Game:setFlag("plot", Game:getFlag("plot", PLOT.intro_boot) + 1)
    end
}
