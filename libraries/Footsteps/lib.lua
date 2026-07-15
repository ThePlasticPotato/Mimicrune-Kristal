Footsteps = {}

function Footsteps:init()
    Game:setFlag("audible-footsteps", Footsteps:getConfig("footsteps_audible_by_default"))
end

function Footsteps:getConfig(name)
    return Kristal.getLibConfig("footsteps", name)
end