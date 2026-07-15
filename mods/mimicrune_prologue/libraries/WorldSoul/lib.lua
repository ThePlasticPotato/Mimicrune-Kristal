WorldSoul = {}

function WorldSoul:init()
end

function WorldSoul:getConfig(name)
    return Kristal.getLibConfig("worldsoul", name)
end

return WorldSoul