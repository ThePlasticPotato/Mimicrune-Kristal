---@class World
---@field world_soul WorldSoul
local World, super = HookSystem.hookScript(World)

function World:init(map)
    super.init(self, map)
    self.world_soul = nil
end

--- Gets the collision map for the world
---@return Collider[]
function World:getSoulCollision()
    local col = {}
    for _,collider in ipairs(self.map.soul_collision) do
        table.insert(col, collider)
    end
    for _,child in ipairs(self.children) do
        if child.collider and child.solid then
            table.insert(col, child.collider)
        end
    end
    return col
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
            if not obj.solid and (obj.onSoulCollide or obj.onSoulEnter or obj.onSoulExit) then
                if (obj:collidesWith(self.world_soul)) then
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