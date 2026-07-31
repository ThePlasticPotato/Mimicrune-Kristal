WorldSoul = {}

function WorldSoul:init()
end

local function soulCollisionLoader(method)
    return function(map, layer)
        map[method](map, layer)
        map:loadShapes(layer)
    end
end

function WorldSoul:onRegisterLayerTypes(registry)
    registry:register("soulcollision", {
        name = "Soul Collision",
        kind = "object",
        icon = "editor/ui/layer/collision",
        color = { 1, 0.2, 0.65, 1 },
        collision_layer = true,
        load = soulCollisionLoader("loadSoulCollision")
    })
    registry:register("soulpushablecollision", {
        name = "Soul Pushable Collision",
        kind = "object",
        icon = "editor/ui/layer/blockcollision",
        color = { 1, 0.65, 0.2, 1 },
        collision_layer = true,
        load = soulCollisionLoader("loadPushableCollision")
    })
end

function WorldSoul:getConfig(name)
    return Kristal.getLibConfig("worldsoul", name)
end

return WorldSoul
