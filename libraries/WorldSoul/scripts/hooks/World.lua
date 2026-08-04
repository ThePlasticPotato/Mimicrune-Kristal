---@class World
---@field world_soul WorldSoul
local World, super = HookSystem.hookScript(World)

function World:init(map)
    self.world_soul = nil
    super.init(self, map)
end

local function captureSoulDestination(...)
    local args = { ... }
    table.remove(args, 1)
    if type(args[1]) == "string" or type(args[1]) == "table" then
        return { marker = args[1] }
    elseif type(args[1]) == "number" then
        return {
            x = args[1],
            y = args[2],
            z = type(args[3]) == "number" and args[3] or nil
        }
    end
    return { marker = "spawn" }
end

function World:loadMap(...)
    local soul = self.world_soul
    if soul and soul.parent == self then
        self.pending_world_soul_destination = captureSoulDestination(...)
        self._skip_world_soul_transition_party_spawn = self.player == nil
    end

    local results = { super.loadMap(self, ...) }
    self._skip_world_soul_transition_party_spawn = false
    return unpack(results)
end

function World:setupMap(...)
    super.setupMap(self, ...)

    local soul = self.world_soul
    local destination = self.pending_world_soul_destination
    self.pending_world_soul_destination = nil
    if not soul or soul.parent ~= self or not destination then return end

    local x, y, z = destination.x, destination.y, destination.z
    if destination.marker then
        local marker = destination.marker
        if not self.map:hasMarker(marker) then marker = "spawn" end
        local marker_data
        x, y, marker_data = self.map:getMarker(marker)
        z = self.map:getMarkerZ(marker)
        soul.spawn_level_id = marker_data and marker_data.level_id
    end
    soul:enterMap(x, y, z)
    self.map:syncLevelFromSubject(soul, true)
end

function World:spawnParty(...)
    if self._skip_world_soul_transition_party_spawn then
        self._skip_world_soul_transition_party_spawn = false
        return
    end
    return super.spawnParty(self, ...)
end

function World:getCameraTarget()
    return super.getCameraTarget(self) or self.world_soul
end

--- Gets the collision map for the world
---@return Collider[]
function World:getSoulCollision()
    local col = {}
    for _,collider in ipairs(self.map.soul_collision or {}) do
        table.insert(col, collider)
    end
    for _,child in ipairs(self.children) do
        if child.collider and child.solid then
            table.insert(col, child.collider)
        end
    end
    return col
end

---@param collider Collider
---@param ignored? Collider|table<Collider, boolean>
---@param movement_z? number
---@return boolean collided
---@return Object? with
function World:checkSoulMovementCollision(collider, ignored, movement_z)
    local soul = collider and collider.parent
    if not (self.map and self.map.platforming)
        or soul and soul.platforming_enabled == false then
        return self:checkSoulCollision(collider)
    end

    Object.startCache()
    for _, other in ipairs(self.map.soul_collision or {}) do
        local is_ignored = other == ignored
            or type(ignored) == "table" and ignored[other] == true
        if not is_ignored and collider ~= other
            and collider:collidesWith3D(other) then
            Object.endCache()
            return true, other.parent
        end
    end
    Object.endCache()

    return self:checkMovementCollision3D(
        collider, false, ignored, movement_z)
end

--- Checks whether the input `collider` is colliding with anything in the world
---@param collider      Collider    The collider to check collision for
---@return boolean  collided    Whether a collision was found
---@return Object?  with        The object that was collided with
function World:checkSoulCollision(collider)
    Object.startCache()
    for _,other in ipairs(self:getSoulCollision()) do
        if collider:collidesWith(other) and collider ~= other then
            Object.endCache()
            return true, other.parent
        end
    end
    Object.endCache()
    return false
end

function World:onKeyPressed(key)
    super.onKeyPressed(self, key)
    if self.state == "GAMEPLAY" then
        if Input.isConfirm(key) and self.world_soul and self.world_soul.is_active then
            if self.world_soul:interact() then
                Input.clear("confirm")
            end
        end
    end
end

function World:update()
    super.update(self)
    if self.state == "GAMEPLAY" and self.world_soul then
        local collided = {}
        local exited = {}
        Object.startCache()
        for _,obj in ipairs(self.children) do
            if self:isObjectLevelActive(obj) and not obj.solid
                and (obj.onSoulCollide or obj.onSoulEnter or obj.onSoulExit) then
                local colliding
                if self.map.platforming and obj.height_sensitive then
                    colliding = obj:collidesWith3D(self.world_soul.collider)
                else
                    colliding = obj:collidesWith(self.world_soul.collider)
                end
                if colliding then
                    if not obj:includes(WorldSoul) then
                        table.insert(collided, {obj, self.world_soul})
                    end
                elseif obj.current_colliding and obj.current_colliding[self.world_soul] then
                    table.insert(exited, {obj, self.world_soul})
                end
            end
        end
        Object.endCache()
        for _,v in ipairs(collided) do
            if not v[1].current_colliding then
                v[1].current_colliding = {}
            end
            if not v[1].current_colliding[v[2]] then
                if v[1].onSoulEnter then
                    v[1]:onSoulEnter(v[2])
                end
                v[1].current_colliding[v[2]] = true
            end
        end
        for _,v in ipairs(exited) do
            if v[1].onSoulExit then
                v[1]:onSoulExit(v[2])
            end
            v[1].current_colliding[v[2]] = nil
        end
    end
end

return World
