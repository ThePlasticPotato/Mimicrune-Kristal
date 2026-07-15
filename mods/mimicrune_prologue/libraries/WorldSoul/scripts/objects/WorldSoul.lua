---@class WorldSoul : Soul
---@field is_active boolean
local WorldSoul, super = Class(Soul)

function WorldSoul:init(x, y, color)
    super.init(self, x, y, color)
    Game.world.world_soul = self
    self.interact_buffer = 0
    self:setColor(color or {Game:getSoulColor()})

    self.sprite:set("player/heart")
    local hx, hy, hw, hh = self.collider.x - self.collider.radius, self.collider.y - self.collider.radius, self.collider.x + self.collider.radius, self.collider.y + self.collider.radius

    self.interact_collider = Hitbox(self, hx, hy, hw, hh)

    self.persistent = true
    self.noclip = false
    self.speed = 2
    self.is_active = true
end

---@param parent Object
function WorldSoul:onRemove(parent)
    super.onRemove(self, parent)

    if parent == Game.world and Game.world.world_soul == self then
        Game.world.world_soul = nil
    end
end

function WorldSoul:onCollide(bullet)
end

--- Shatters the soul into several shards \
--- The position of the shards are controlled by [`shard_x_table`](lua://Soul.shard_x_table) and [`shard_y_table`](lua://Soul.shard_y_table)
---@param count integer The number of shards that the soul should shatter into.
function WorldSoul:shatter(count)
    Assets.playSound("break2")

    local shard_count = count or 6

    self.shards = {}
    for i = 1, shard_count do
        local x_pos = self.shard_x_table[((i - 1) % #self.shard_x_table) + 1]
        local y_pos = self.shard_y_table[((i - 1) % #self.shard_y_table) + 1]
        local shard = Sprite("player/heart_shard", self.x + x_pos, self.y + y_pos)
        shard:setColor(self:getColor())
        shard.physics.direction = math.rad(MathUtils.random(360))
        shard.physics.speed = 7
        shard.physics.gravity = 0.2
        shard.layer = self.layer
        shard:play(5/30)
        table.insert(self.shards, shard)
        self.stage:addChild(shard)
    end

    self:remove()
    Game.world.world_soul = nil
end

function WorldSoul:update()
    if self.transitioning then
        self.is_active = false
        if self.timer >= 7 then
            Input.clear("cancel")
            self.timer = 0
            if self.transition_destroy then
                Game.world:addChild(HeartBurst(self.target_x, self.target_y, {Game:getSoulColor()}))
                self:remove()
            else
                self.transitioning = false
                self.is_active = true
                self:setExactPosition(self.target_x, self.target_y)
            end
        else
            self:setExactPosition(
                MathUtils.lerp(self.original_x, self.target_x, self.timer / 7),
                MathUtils.lerp(self.original_y, self.target_y, self.timer / 7)
            )
            self.alpha = MathUtils.lerp(0, self.target_alpha or 1, self.timer / 3)
            self.sprite:setColor(self.color[1], self.color[2], self.color[3], self.alpha)
            self.timer = self.timer + (1 * DTMULT)
        end
        return
    end

    -- Input movement
    if self.can_move and self.is_active then
        self:doMovement()
    end

    -- Bullet collision !!! Yay
    if self.inv_timer > 0 then
        self.inv_timer = MathUtils.approach(self.inv_timer, 0, DT)
    end

    local collided_bullets = {}
    Object.startCache()
    for _,bullet in ipairs(Game.stage:getObjects(Bullet)) do
        if bullet:collidesWith(self.collider) then
            -- Store collided bullets to a table before calling onCollide
            -- to avoid issues with cacheing inside onCollide
            table.insert(collided_bullets, bullet)
        end
        if self.inv_timer == 0 then
            if bullet:canGraze() and bullet:collidesWith(self.graze_collider) then
                local old_graze = bullet.grazed
                if bullet.grazed then
                    Game:giveTension(bullet:getGrazeTension() * DT * self.graze_tp_factor)
                    if self.graze_sprite.timer < 0.1 then
                        self.graze_sprite.timer = 0.1
                    end
                    bullet:onGraze(false)
                else
                    Assets.playSound("graze")
                    Game:giveTension(bullet:getGrazeTension() * self.graze_tp_factor)
                    self.graze_sprite.timer = 1 / 3
                    bullet.grazed = true
                    bullet:onGraze(true)
                end
                self:onGraze(bullet, old_graze)
            end
        end
    end
    Object.endCache()
    for _,bullet in ipairs(collided_bullets) do
        self:onCollide(bullet)
    end

    if self.inv_timer > 0 then
        self.inv_flash_timer = self.inv_flash_timer + DT
        local amt = math.floor(self.inv_flash_timer / (4/30))
        if (amt % 2) == 1 then
            self.sprite:setColor(0.5, 0.5, 0.5)
        else
            self.sprite:setColor(1, 1, 1)
        end
    else
        self.inv_flash_timer = 0
        self.sprite:setColor(1, 1, 1)
    end

    super.update(self)
end

--- *(Used internally)* Performs collision abiding movement of the soul on the x-axis
---@param amount number
---@param move_y number
---@return boolean
---@return Object|nil
function WorldSoul:moveXExact(amount, move_y)
    local sign = MathUtils.sign(amount)
    for i = sign, amount, sign do
        local last_x = self.x
        local last_y = self.y

        self.x = self.x + sign

        if not self.noclip then
            Object.uncache(self)
            Object.startCache()
            local collided, target = Game.world:checkSoulCollision(self)
            if self.slope_correction then
                if collided and not (move_y > 0) then
                    for j = 1, 2 do
                        Object.uncache(self)
                        self.y = self.y - 1
                        collided, target = Game.world:checkSoulCollision(self)
                        if not collided then break end
                    end
                end
                if collided and not (move_y < 0) then
                    self.y = last_y
                    for j = 1, 2 do
                        Object.uncache(self)
                        self.y = self.y + 1
                        collided, target = Game.world:checkSoulCollision(self)
                        if not collided then break end
                    end
                end
            end
            Object.endCache()

            if collided then
                self.x = last_x
                self.y = last_y

                if target and target.onSoulCollide then
                    target:onSoulCollide(self)
                end

                self.last_collided_x = sign
                return false, target
            end
        end
    end
    self.last_collided_x = 0
    return true
end

--- *(Used internally)* Performs collision abiding movment of the soul on the y-axis
---@param amount number
---@param move_x number
---@return boolean
---@return Object|nil
function WorldSoul:moveYExact(amount, move_x)
    local sign = MathUtils.sign(amount)
    for i = sign, amount, sign do
        local last_x = self.x
        local last_y = self.y

        self.y = self.y + sign

        if not self.noclip then
            Object.uncache(self)
            Object.startCache()
            local collided, target = Game.world:checkSoulCollision(self)
            if self.slope_correction then
                if collided and not (move_x > 0) then
                    for j = 1, 2 do
                        Object.uncache(self)
                        self.x = self.x - 1
                        collided, target = Game.world:checkSoulCollision(self)
                        if not collided then break end
                    end
                end
                if collided and not (move_x < 0) then
                    self.x = last_x
                    for j = 1, 2 do
                        Object.uncache(self)
                        self.x = self.x + 1
                        collided, target = Game.world:checkSoulCollision(self)
                        if not collided then break end
                    end
                end
            end
            Object.endCache()

            if collided then
                self.x = last_x
                self.y = last_y

                if target and target.onSoulCollide then
                    target:onSoulCollide(self)
                end

                self.last_collided_y = sign
                return i ~= sign, target
            end
        end
    end
    self.last_collided_y = 0
    return true
end

function WorldSoul:update()
    super.update(self)
end

function WorldSoul:interact()
    if self.interact_buffer > 0 then
        return true
    end

    local col = self.interact_collider

    local interactables = {}
    for _, obj in ipairs(Game.world.children) do
        if obj.onSoulInteract and obj:collidesWith(col) then
            local rx, ry = obj:getRelativePos(obj.width / 2, obj.height / 2, self.parent)
            table.insert(interactables, { obj = obj, dist = MathUtils.dist(self.x, self.y, rx, ry) })
        end
    end
    table.sort(interactables, function (a, b) return a.dist < b.dist end)
    for _, v in ipairs(interactables) do
        if v.obj:onSoulInteract(self) then
            self.interact_buffer = v.obj.interact_buffer or 0
            return true
        end
    end

    return false
end


return WorldSoul