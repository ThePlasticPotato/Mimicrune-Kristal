Pathfinder = {}

function Pathfinder:init()
end

function Pathfinder:getConfig(name)
    return Kristal.getLibConfig("pathfinder", name)
end

return Pathfinder