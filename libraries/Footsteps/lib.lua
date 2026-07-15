local Footsteps = {}
Registry.registerGlobal("Footsteps", Footsteps)

function Footsteps:init()
end

function Footsteps:onInit()
    Game:setFlag("audible_footsteps", self:getConfig("footsteps_audible_by_default"))
end

function Footsteps:getConfig(name)
    return Kristal.getLibConfig("footsteps", name)
end

function Footsteps:getStepVolume(character)
    local speed = 4
    local follower = character:includes(Follower)

    if follower then
        local target = character:getTarget()
        if target and target.getCurrentSpeed then
            speed = target:getCurrentSpeed(target.state == "RUN")
        end
    elseif character:includes(Player) then
        speed = character:getCurrentSpeed(character.state == "RUN")
    end

    local volume = math.min(
        self:getConfig("step_volume") * (speed / 4),
        self:getConfig("step_volume_max")
    )
    if follower and self:getConfig("half_volume_followers") then
        volume = volume / 2
    end
    return volume
end

function Footsteps:onFootstep(character, num)
    local world = Game.world
    local water_depth = character.water_depth or 0
    if Game:getFlag("audible_footsteps", false) and world and world.map then
        local random_pitch = MathUtils.random(-0.15, 0.15)
        num = MathUtils.wrap(num, 1, 3)
        local sound, pitch = world:getStepSound(character.x, character.y, num, character.actor)
        if character.in_water then
            sound = "step/water_" .. ((water_depth < 3) and "shallow" or "deep") .. tostring(num)
        end
        Assets.stopAndPlaySound(sound, self:getStepVolume(character), pitch or (1 + random_pitch))
    end

    if character.in_water and world and world.map then
        ---@type SmallLake
        local lake = world.map:getEvent("smalllake")
        if lake
            and character.x <= lake.x + lake.width / 2
            and character.x >= lake.x - lake.width / 2
            and character.y <= lake.y + lake.height / 2
            and character.y >= lake.y - lake.height / 2
        then
            local screen_x, screen_y = lake:screenToLocalPos(character:localToScreenPos(
                character.width / 2, character.height - water_depth
            ))
            lake:spawnSplash(screen_x, screen_y, 20, 1.5, 1.5)
        end
    end
end

return Footsteps
