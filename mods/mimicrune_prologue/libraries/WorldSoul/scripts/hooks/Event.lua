---@class Event : Object
---@field soul_only boolean
local Event, super = HookSystem.hookScript(Event)

function Event:init(x, y, width, height)
    super.init(self, x, y, width, height)
    if type(x) == "table" then
        local data = x
        self.soul_only = data and data.properties and data.properties["soul_only"] or false
    end
end

--- The below callbacks are set back to `nil` to ensure collision checks are 
--- only run on objects that define collision code

--- *(Override)* Called whenever the soul interacts with this event
---@param soul    WorldSoul  The interacting `WorldSoul`
---@return boolean blocking Whether this interaction should prevent other events in the interaction region activating with this frame
function Event:onSoulInteract(soul)
    -- Do stuff when the soul interacts with this object (CONFIRM key)
    return false
end

Event.onSoulInteract = nil

--- *(Override)* Called every frame the soul and event are colliding with each other
---@param soul    WorldSoul
---@param DT        number
function Event:onSoulCollide(soul, DT)
    -- Do stuff every frame the soul collides with the object
end

Event.onSoulCollide = nil

--- *(Override)* Called whenever the soul enters this event // todo, not implemented cause world is weird
---@param soul WorldSoul
function Event:onSoulEnter(soul)
    -- Do stuff when the soul enters this object
end

Event.onSoulEnter = nil

--- *(Override)* Called whenever the soul leaves this event // todo, not implemented cause world is weird
---@param soul WorldSoul
function Event:onSoulExit(soul)
    -- Do stuff when the soul leaves this object
end

Event.onSoulExit = nil

return Event