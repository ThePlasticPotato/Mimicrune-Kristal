--- The `World` Object manages everything relating to the overworld in Kristal. \
--- A globally available instance of `World` is stored in [`Game.world`](lua://Game.world).
---
---@class World : Object, StateManagedClass
---
---@field state             string                          The current state that this `World` is in - should never be set manually, see [`World:setState()`](lua://World.setState) instead
---@field state_manager     StateManager                    An object that manages the state of this `World`
---
---@field music             Music                           The `Music` instance that controls audio playback for this `World`
---@field additional_music  Music                           The `Music` instance that controls overlay audio playback for this `World`, like Cassidy's Humming
---
---@field map               Map                             The currently loaded map instance
---
---@field camera            Camera                          The camera object used to display the world
---
---@field player            Player                          The player character
---@field soul              OverworldSoul                   The soul of the player
---
---@field battle_borders    table                           *(unused? See [`Map.battle_borders`](lua://Map.battle_borders))*
---
---@field encountering_enemy    boolean
---@field transition_fade   number                          *(unused?)*
---
---@field in_battle         boolean                         Whether the player is currently in a world battle set through [`World:setBattle()](lua://World.setBattle) (affects the visibility of world battle content)
---@field in_battle_area    boolean                         Whether the player is currently standing inside a battlearea of the map (affects the visibility of world battle content)
---@field battle_alpha      number                          The current alpha value of world battle content
---
---@field bullets           WorldBullet[]                   A table of currently active bullets
---@field followers         Follower[]                      A table of all followers currently present in the world
---
---@field cutscene          WorldCutscene?                  The `WorldCutscene` object of the currently active cutscene, if present
---
---@field conroller_parent  Object                          The object that all controllers are parented to
---
---@field fader             Fader
---
---@field timer             Timer
---
---@field can_open_menu     boolean                         Whether the player can open their menu
---
---@field menu              LightMenu|DarkMenu|Component?   The Menu object of the menu, if it is open
---@field current_selecting number
---
---@field calls             table<[string, string]>   A list of calls available on the cell phone in the Light World CELL menu
---
---@field door_delay        number                          *(Used internally)* Timer variable for door transition sounds
---
---@field healthbar         HealthBar
---
---@field limited_interaction boolean
---
---@overload fun(map?: string) : World
local World, super = Class(Object)

---@param map? string    The optional name of a map to initially load with the world
function World:init(map)
    super.init(self)

    -- states: GAMEPLAY, FADING, MENU
    self.state = "" -- Make warnings shut up, TODO: fix this
    self.state_manager = StateManager("GAMEPLAY", self, true)
    self.state_manager:addState("GAMEPLAY")
    self.state_manager:addState("FADING")
    self.state_manager:addState("MENU")

    self.music = Music()
    self.additional_music = Music()

    self.map = Map(self)

    self.width = self.map.width * self.map.tile_width
    self.height = self.map.height * self.map.tile_height

    self.camera = Camera(self, 0, 0, SCREEN_WIDTH, SCREEN_HEIGHT, true)
    self.camera.target_getter = function()
        return self:getCameraTarget()
    end

    self.player = nil
    self.soul = nil

    self.battle_borders = {}

    self.transition_fade = 0

    self.in_battle = false
    self.in_battle_area = false
    self.battle_alpha = 0

    self.bullets = {}
    self.followers = {}

    self.cutscene = nil

    self.controller_parent = Object()
    self.controller_parent.layer = WORLD_LAYERS["bottom"] - 1
    self.controller_parent.persistent = true
    self.controller_parent.world = self
    self:addChild(self.controller_parent)

    self.fader = Fader()
    self.fader.layer = WORLD_LAYERS["above_ui"]
    self.fader.persistent = true
    self:addChild(self.fader)

    self.timer = Timer()
    self.timer.persistent = true
    self:addChild(self.timer)

    self.can_open_menu = true

    self.menu = nil

    self.debug_select = false

    self.calls = {}

    self.door_delay = 0

    self.limited_interaction = false

    self.humming = false
    self.should_hum = false
    self.hum_timer = 0

    if map then
        self:loadMap(map)
    end
end

--- Heals a member of the party
---@param target    string|PartyMember  The party member to heal
---@param amount    number              The amount of HP to restore
---@param text?     string              An optional text to display when HP is resotred in the Light World, before the HP restoration message
function World:heal(target, amount, text)
    if type(target) == "string" then
        target = Game:getPartyMember(target)
    end

    local maxed = target:heal(amount)

    if Game:isLight() then
        local message
        if maxed then
            message = "* Your HP was maxed out."
        else
            message = "* You recovered " .. amount .. " HP!"
        end
        if text then
            message = text .. " \n" .. message
        end
        Game.world:showText(message)
    elseif self.healthbar then
        for _, actionbox in ipairs(self.healthbar.action_boxes) do
            if actionbox.chara.id == target.id then
                local text = HPText("+" .. amount, self.healthbar.x + actionbox.x + 69, self.healthbar.y + actionbox.y + 15)
                text.layer = WORLD_LAYERS["ui"] + 1
                Game.world:addChild(text)
                return
            end
        end
    end
end

--- Gets the `Player` and `Follower` characters
---@return (Player|Follower)[]
function World:getPlayerAndFollowers()
    local characters = TableUtils.copy(self.followers)
    if self.player then
        table.insert(characters, 1, self.player)
    end
    return characters
end

--- Gets the `Follower` or `Player` of a character that's currently the soul party member
---@return Player|Follower?
function World:getSoulPartyCharacter()
    return self:getPartyCharacterInParty(Game:getSoulPartyMember())
end

--- Hurts the party member `battler` by `amount`, or hurts the whole party for `amount`
---@overload fun(self: World, amount: number)
---@param battler Character|string|integer|"ALL"? The Character to hurt
---@param amount number The amount of damage to deal
---@return boolean killed Whether all targetted characters were knocked out by this damage
function World:hurtParty(battler, amount)
    Assets.playSound("hurt")

    self:shakeCamera()
    self:showHealthBars()

    if amount == nil then
        amount = battler --[[@as number]]
        battler = nil
    end

    if battler == "ALL" then
        battler = nil
    end

    local any_killed = false
    local any_alive = false
    for index, party in ipairs(Game.party) do
        local current_amount = amount

        for _, item in ipairs(party:getEquipment()) do
            current_amount = item:onWorldDamage(current_amount) or current_amount
        end

        if not battler or battler == party.id or battler == party or battler == index then
            local current_health = party:getHealth()
            party:setHealth(party:getHealth() - current_amount)
            if party:getHealth() <= 0 then
                party:setHealth(1)
                any_killed = true
            else
                any_alive = true
            end

            local dealt_amount = current_health - party:getHealth()

            for _, char in ipairs(self.stage:getObjects(Character)) do
                if char.actor and (char.actor.id == party:getActor().id) and dealt_amount > 0 then
                    if char.alpha > 0 then
                        char:statusMessage("damage", dealt_amount)
                    end
                end
            end
        elseif party:getHealth() > current_amount then
            any_alive = true
        end
    end

    if self.player then
        self.player.hurt_timer = 7
    end

    if any_killed and not any_alive then
        if not self.map:onGameOver() then
            Game:gameOver(self.soul:getScreenPos())
        end
        return true
    elseif battler then
        return any_killed
    end

    return false
end

--- Changes the state of the world
---@param state string
function World:setState(state)
    self.state_manager:setState(state)
end

--- Opens the main overworld menu. Make sure to check [`World:canOpenMenu()`](lua://World.canOpenMenu) before calling this function.
---@param menu?     Object  An optional menu instance to open
---@param layer?    number  The layer to create the menu on (defaults to `WORLD_LAYERS["ui"]` or `600`)
---@return Object?
function World:openMenu(menu, layer)

    if self.menu then
        self.menu:remove()
        self.menu = nil
    end

    if not menu then
        menu = self:createMenu()
    end

    self.menu = menu
    if self.menu then
        self.menu.layer = layer and self:parseLayer(layer) or WORLD_LAYERS["ui"]

        if self.menu:includes(AbstractMenuComponent) then
            self.menu.close_callback = function()
                self:afterMenuClosed()
            end
        elseif self.menu:includes(Component) then
            -- Sigh... traverse the children to find the menu component
            for _, child in ipairs(self.menu:getComponents()) do
                if child:includes(AbstractMenuComponent) then ---@cast child AbstractMenuComponent
                    child.close_callback = function()
                        self:afterMenuClosed()
                    end
                    break
                end
            end
        end

        self:addChild(self.menu)
        self:setState("MENU")
    end
    return self.menu
end

--- Creates the main overworld menu if it does not exist \
--- *The [event](lua://KRISTAL_EVENT) `createMenu` is called by this function, which can return a custom menu to use instead of the default Light/Dark menu*
---@return LightMenu|DarkMenu|GonerMenu
function World:createMenu()
    local menu = Kristal.callEvent(KRISTAL_EVENT.createMenu)
    if menu then return menu end
    if Game:getConfig("worldMenu") == "goner" then
        menu = GonerMenu()
    elseif Game:isLight() then
        menu = LightMenu()
    else
        menu = DarkMenu()
    end
    return menu
end

--- Closes the menu
function World:closeMenu()
    if self.menu then
        if not self.menu.animate_out and self.menu.transitionOut then
            self.menu:transitionOut()
        elseif (not self.menu.transitionOut) and self.menu.close then
            self.menu:close()
        end
    end
    self:afterMenuClosed()
end

--- Runs whenever the menu is closed
function World:afterMenuClosed()
    self:hideHealthBars()
    self.menu = nil
    self:setState("GAMEPLAY")
end

--- Sets the value of a cell flag (a special flag which normally starts at -1 and increments by 1 at the start of every call, named after the call cutscene)
---@param name  string  The name of the flag to set
---@param value integer The value to set the flag to
function World:setCellFlag(name, value)
    Game:setFlag("lightmenu#cell:" .. name, value)
end

--- Gets the value of a cell flag (a special flag which normally starts at -1 and increments by 1 at the start of every call, named after the call cutscene)
---@param name      string
---@param default?  integer
---@return integer
function World:getCellFlag(name, default)
    return Game:getFlag("lightmenu#cell:" .. name, default)
end

--- Registers a phone call in the Light World CELL menu
---@param name  string          The name of the call as it will show in the CELL menu
---@param scene string          The cutscene to play when the call is selected
function World:registerCall(name, scene)
    table.insert(self.calls, { name, scene })
end

--- Replaces a phone call in the Light World CELL menu with another
---@param name  string          The name of the call as it will show in the CELL menu
---@param index integer         The index of the call to replace
---@param scene string          The cutscene to play when the call is selected
function World:replaceCall(name, index, scene)
    self.calls[index] = { name, scene }
end

function World:startHumming()
    local cassidy = Game:hasPartyMember("cassidy")
    if cassidy then
        local worldcassidy = self:getPartyCharacterInParty("cassidy")
        if not worldcassidy then return end
        if not (self.humming and self.map.keep_music) then
            self.additional_music:stop()
            self.additional_music.volume = 0
            self.additional_music:play(self.map.data.properties.hum_track)
            self.humming = true
            if worldcassidy.state_manager.state == "WALK" then worldcassidy:setWalkSprite("walk_hum") end
            worldcassidy.humming = true
            self.additional_music:seek(self.music:tell())
            self.additional_music:setLooping(true)
            self.additional_music:fade(1.2, 0.5)
        else
            if worldcassidy and (self.humming and not worldcassidy.humming) then
                if worldcassidy.state_manager.state == "WALK" then worldcassidy:setWalkSprite("walk_hum") end
                worldcassidy.humming = true
            end
        end
        
    end
end

--- Shows party member health bars
function World:showHealthBars()
    if Game:isLight() then return end

    if self.healthbar then
        self.healthbar:transitionIn()
    else
        self.healthbar = HealthBar()
        self.healthbar.layer = WORLD_LAYERS["ui"] + 1
        self:addChild(self.healthbar)
    end
end

--- Hides party member health bars
function World:hideHealthBars()
    if self.healthbar then
        if not self.healthbar.animate_out then
            self.healthbar:transitionOut()
        end
    end
end

--- Whether or not the player should be able to interact with things.
---
---@return boolean interact_allowed
function World:canInteract()
    if self.player == nil then
        return false
    end

    if self:hasCutscene() and not self.limited_interaction then
        return false
    end

    if self.player:isClimbing() then
        return false
    end

    return true
end

--- Whether or not the player should be able to open the menu.
---
---@return boolean menu_allowed
function World:canOpenMenu()
    if self:hasCutscene() then
        return false
    end

    if self:inBattle() then
        return false
    end

    if self.player and self.player:isClimbing() then
        return false
    end

    if not self.can_open_menu then
        return false
    end

    return true
end

--- Called whenever the state of the world changes
---@param old string
---@param new string
function World:onStateChange(old, new)
end

---Todo: actually implement this but im lazy
---@return boolean
function World:hasTalkCutscene()
    return true or self.map and self.map.data and self.map.data.properties and self.map.data.properties["has_talk"]
end

---@param key string
function World:onKeyPressed(key)
    if Kristal.isDevMode() and Input.ctrl() then
        if key == "m" then
            if self.music then
                if self.music:isPlaying() then
                    self.music:pause()
                else
                    self.music:resume()
                end
            end
        end
        if key == "s" then
            local save_pos = nil
            if Input.shift() and self.player then
                save_pos = { self.player.x, self.player.y, self.player.z }
            end
            if Game:getConfig("smallSaveMenu") then
                self:openMenu(SimpleSaveMenu(Game.save_id, save_pos))
            elseif Game:isLight() then
                self:openMenu(LightSaveMenu(save_pos))
            else
                self:openMenu(SaveMenu(save_pos))
            end
        end
        if key == "h" then
            for _, party in ipairs(Game.party) do
                party:heal(math.huge)
            end
        end
        if key == "b" then
            Game.world:hurtParty(math.huge)
        end
        if key == "k" then
            Game:setTension(Game:getMaxTension())
            Assets.playSound("cardrive", 0.8, 1.4)
        end
        if key == "n" then
            NOCLIP = not NOCLIP
            if NOCLIP then
                Assets.playSound("petrify")
            else
                Assets.playSound("bump")
            end
        end
        if key == "i" then
            INVINCIBILITY = not INVINCIBILITY
            if INVINCIBILITY then
                Assets.playSound("sparkle_glock")
            else
                Assets.playSound("bump")
            end
        end
    end

    if Game.lock_movement then return end

    if self.state == "GAMEPLAY" then
        if Input.isJump(key) and self.player and self.player:canJump() then
            if self.player:jump() then
                Input.clear("jump")
                Input.clear("dash")
            end
        elseif Input.isConfirm(key) and self:canInteract() then
            if self.player:interact() then
                Input.clear("confirm")
            end
        elseif Input.isAttack(key) and self:canInteract() then
            if (self.player:attack()) then
                Input.clear("attack")
            end
        elseif Input.isDash(key) and self:canInteract() then
            if (self.player:canDash()) then
                self.player:setState("DASH")
                Input.clear("dash")
            end
        elseif Input.isMenu(key) and self:canOpenMenu() then
            self:openMenu(nil, WORLD_LAYERS["ui"] + 1)
            Input.clear("menu")
        end
    elseif self.state == "MENU" then
        if self.menu and self.menu.onKeyPressed then
            self.menu:onKeyPressed(key)
        end
    end
end

--- Checks whether there is currently a textbox open
---@return boolean
function World:isTextboxOpen()
    return self:hasCutscene() and self.cutscene.textbox and self.cutscene.textbox.stage ~= nil
end

--- Gets the collision map for the world
---@param enemy_check?  boolean     Whether to include the enemy collision map (defaults to `false`)
---@return Collider[]
function World:getCollision(enemy_check)
    local col = {}
    for _, collider in ipairs(self.map.collision) do
        table.insert(col, collider)
    end
    if enemy_check then
        for _, collider in ipairs(self.map.enemy_collision) do
            table.insert(col, collider)
        end
    end
    for _, child in ipairs(self.children) do
        if child.collider and child.solid then
            table.insert(col, child.collider)
        end
    end
    return col
end

--- Checks whether the input `collider` is colliding with anything in the world
---@param collider      Collider    The collider to check collision for
---@param enemy_check?  boolean     Whether to include the enemy collision map in the check
---@return boolean  collided    Whether a collision was found
---@return Object?  with        The object that was collided with
function World:checkCollision(collider, enemy_check)
    Object.startCache()
    for _,other in ipairs(self:getCollision(enemy_check)) do
        if collider:collidesWith(other) and collider ~= other then
            Object.endCache()
            return true, other.parent
        end
    end
    Object.endCache()
    return false
end

--- Returns all the inputs `collider` is currently colliding with in the world
---@param collider      Collider    The collider to check collisions for
---@param enemy_check?  boolean     Whether to include the enemy collision map in the check
---@return boolean  collided    Whether a collision was found
---@return Object[] collisions The objects that were collided with
function World:checkCollisions(collider, enemy_check)
    local collided_with = {}
    Object.startCache()
    for _, other in ipairs(self:getCollision(enemy_check)) do
        if collider:collidesWith(other) and collider ~= other then
            table.insert(collided_with, other.parent)
        end
    end
    Object.endCache()
    return #collided_with > 0, collided_with
end

local function isIgnoredCollision(collider, ignored)
    return collider == ignored or type(ignored) == "table" and ignored[collider] == true
end

--- Checks whether the input collider overlaps anything in both XY and Z.
---@param collider Collider
---@param enemy_check? boolean
---@param ignored? Collider A single collider to omit from this check
---@return boolean collided
---@return Object? with
function World:checkCollision3D(collider, enemy_check, ignored)
    Object.startCache()
    for _, other in ipairs(self:getCollision(enemy_check)) do
        local collider_bottom = collider:getZBounds()
        local other_top = self:getSupportHeightAt(other, collider)
        local standing_on_surface = other.supports and math.abs(collider_bottom - other_top) < 0.001
        local collider_parent = collider.parent
        local grounded = collider_parent and collider_parent.isGrounded
            and collider_parent:isGrounded()
        local traversing_slope = other.slope and other.supports
            and collider:collidesWith(other)
            and collider_bottom >= other_top
                - (grounded and other:getSlopeStepHeight() or 0)
        local slope_connection = self:isSlopeConnection(collider, other)
        if not isIgnoredCollision(other, ignored)
            and not other.one_way and not standing_on_surface
            and not traversing_slope and not slope_connection
            and collider:collidesWith3D(other) and collider ~= other then
            Object.endCache()
            return true, other.parent
        end
    end
    Object.endCache()
    return false
end

--- Checks horizontal character movement in 3D.
---@param collider Collider
---@param enemy_check? boolean
---@param ignored? Collider|table<Collider, boolean>
---@param movement_z? number Lowest foot Z reached during this movement frame
---@return boolean collided
---@return Object? with
function World:checkMovementCollision3D(collider, enemy_check, ignored, movement_z)
    local collided, with = self:checkCollision3D(collider, enemy_check, ignored)
    if collided then return true, with end

    local collider_bottom, collider_top = collider:getZBounds()
    local movement_bottom = math.min(collider_bottom, movement_z or collider_bottom)
    Object.startCache()
    for _, other in ipairs(self:getCollision(enemy_check)) do
        local other_bottom = other:getZBounds()
        local other_top = self:getSupportHeightAt(other, collider)
        local collider_parent = collider.parent
        local grounded = collider_parent and collider_parent.isGrounded
            and collider_parent:isGrounded()
        local traversing_slope = other.slope
            and movement_bottom >= other_top
                - (grounded and other:getSlopeStepHeight() or 0)
        local slope_connection = self:isSlopeConnection(collider, other)
        if not isIgnoredCollision(other, ignored)
            and other.supports and other_top > movement_bottom + 0.001
            and other_bottom < collider_top - 0.001
            and not traversing_slope and not slope_connection
            and collider:collidesWith(other)
            and collider ~= other then
            Object.endCache()
            return true, other.parent
        end
    end
    Object.endCache()
    return false
end

--- Returns all world collisions that overlap the input collider in XY and Z.
---@param collider Collider
---@param enemy_check? boolean
---@param ignored? Collider A single collider to omit from this check
---@return boolean collided
---@return Object[] collisions
function World:checkCollisions3D(collider, enemy_check, ignored)
    local collided_with = {}
    Object.startCache()
    for _, other in ipairs(self:getCollision(enemy_check)) do
        local collider_bottom = collider:getZBounds()
        local other_top = self:getSupportHeightAt(other, collider)
        local standing_on_surface = other.supports and math.abs(collider_bottom - other_top) < 0.001
        local collider_parent = collider.parent
        local grounded = collider_parent and collider_parent.isGrounded
            and collider_parent:isGrounded()
        local traversing_slope = other.slope and other.supports
            and collider:collidesWith(other)
            and collider_bottom >= other_top
                - (grounded and other:getSlopeStepHeight() or 0)
        local slope_connection = self:isSlopeConnection(collider, other)
        if not isIgnoredCollision(other, ignored)
            and not other.one_way and not standing_on_surface
            and not traversing_slope and not slope_connection
            and collider:collidesWith3D(other) and collider ~= other then
            table.insert(collided_with, other.parent)
        end
    end
    Object.endCache()
    return #collided_with > 0, collided_with
end

local function getSupportProbe(collider)
    if collider:includes(ColliderGroup) and collider.colliders[1] then
        return getSupportProbe(collider.colliders[1])
    elseif collider:includes(Hitbox) then
        return PointCollider(collider.parent,
            collider.x + collider.width / 2, collider.y + collider.height / 2)
    elseif collider:includes(CircleCollider) or collider:includes(PointCollider) then
        return PointCollider(collider.parent, collider.x, collider.y)
    elseif collider:includes(LineCollider) then
        return PointCollider(collider.parent,
            (collider.x + collider.x2) / 2, (collider.y + collider.y2) / 2)
    elseif collider:includes(PolygonCollider) and #collider.points > 0 then
        local x, y = 0, 0
        for _, point in ipairs(collider.points) do
            x, y = x + point[1], y + point[2]
        end
        return PointCollider(collider.parent, x / #collider.points, y / #collider.points)
    end
    return collider
end

local function getSupportWorldPosition(collider)
    local parent = collider and collider.parent
    if parent and parent.support_collider and collider ~= parent.support_collider then
        collider = parent.support_collider
    end
    local probe = getSupportProbe(collider)
    local x, y = probe.x, probe.y
    if probe.parent then
        x, y = probe.parent:getFullTransform():transformPoint(x, y)
    end
    return x, y
end

--- Samples a support collider's walkable height beneath a footprint.
---@param surface Collider
---@param collider Collider
---@return number height
function World:getSupportHeightAt(surface, collider)
    if not surface.slope then
        local _, top = surface:getZBounds()
        return top
    end
    local x, y = getSupportWorldPosition(collider)
    return surface:getSupportHeightAt(x, y)
end

--- Whether a grounded ramp terminates at the top of an overlapping platform.
--- This prevents the actor's body width from hitting that platform's vertical
--- face before the foot probe reaches the ramp's high endpoint.
function World:isSlopeConnection(collider, surface)
    local parent = collider and collider.parent
    local ground = parent and parent.ground_collider
    if not ground or not ground.slope or not surface.supports then return false end
    if self:collidersShareHeightSurface(ground, surface) then return true end
    local _, ramp_top = ground:getZBounds()
    local surface_top = self:getSupportHeightAt(surface, collider)
    return math.abs(ramp_top - surface_top) <= 0.001
end

--- Finds a slope reachable from the actor's current foot height.
---@param collider Collider
---@param z number
---@param ignored? Collider|table<Collider, boolean>
---@return number? height
---@return Collider? slope
---@return table? height_surface
function World:getTraversableSlopeAt(collider, z, ignored)
    local best_z, best_slope
    Object.startCache()
    for _, surface in ipairs(self:getCollision(false)) do
        if not isIgnoredCollision(surface, ignored)
            and surface.slope and surface.supports and collider:collidesWith(surface) then
            local top = self:getSupportHeightAt(surface, collider)
            if math.abs(top - z) <= surface:getSlopeStepHeight()
                and (not best_z or top > best_z) then
                best_z, best_slope = top, surface
            end
        end
    end
    Object.endCache()
    return best_z, best_slope, self:getHeightSurfaceForCollider(best_slope)
end

---@param collider Collider
---@param surface Collider
---@return boolean
function World:isSupportOver(collider, surface)
    return collider:collidesWith(surface)
end

---@param collider Collider?
---@return table? surface
function World:getHeightSurfaceForCollider(collider)
    return self.map and self.map.getSurfaceForCollider
        and self.map:getSurfaceForCollider(collider) or nil
end

--- Whether two collider pieces belong to the same authored height surface.
---@param first Collider?
---@param second Collider?
---@return boolean
function World:collidersShareHeightSurface(first, second)
    if not first or not second then return false end
    if first == second then return true end
    if first.surface_id ~= nil and second.surface_id ~= nil
        and tostring(first.surface_id) == tostring(second.surface_id) then
        return true
    end
    local first_surface = self:getHeightSurfaceForCollider(first)
    local second_surface = self:getHeightSurfaceForCollider(second)
    if not first_surface or not second_surface then return false end
    if first_surface == second_surface then return true end
    return first_surface.id ~= nil and second_surface.id ~= nil
        and tostring(first_surface.id) == tostring(second_surface.id)
end

---@param candidate Collider?
---@param departed Collider?
---@param probe Collider
---@return boolean matches
function World:matchesDepartedHeight(candidate, departed, probe)
    if not candidate or not departed then return false end
    if self:collidersShareHeightSurface(candidate, departed) then return true end
    local candidate_top = self:getSupportHeightAt(candidate, probe)
    local departed_top = self:getSupportHeightAt(departed, probe)
    return math.abs(candidate_top - departed_top) <= 0.001
end

---@param subject Object
---@param departed Collider?
---@return number x
---@return number y
function World:getHeightDepartureDirection(subject, departed)
    local move_x = MathUtils.sign(subject.moving_x or 0)
    local move_y = MathUtils.sign(subject.moving_y or 0)
    if move_x ~= 0 or move_y ~= 0 then return move_x, move_y end

    local surface = self:getHeightSurfaceForCollider(departed)
    local bounds = surface and (surface.support_bounds or surface.bounds)
        or departed and departed.map_bounds
    if bounds and subject.support_collider then
        local x, y = getSupportWorldPosition(subject.support_collider)
        local outside_left = math.max(bounds.min_x - x, 0)
        local outside_right = math.max(x - bounds.max_x, 0)
        local outside_up = math.max(bounds.min_y - y, 0)
        local outside_down = math.max(y - bounds.max_y, 0)
        local horizontal = math.max(outside_left, outside_right)
        local vertical = math.max(outside_up, outside_down)
        if horizontal > 0 or vertical > 0 then
            return horizontal > 0 and (outside_left > outside_right and -1 or 1) or 0,
                vertical > 0 and (outside_up > outside_down and -1 or 1) or 0
        end
    end

    return 0, 1
end

---@return table? surface
function World:getImplicitHeightSurface()
    return self.map and self.map.getImplicitSurface
        and self.map:getImplicitSurface() or nil
end

--- Whether the support probe is currently above a non-empty ground tile.
---@param collider Collider
---@return boolean
function World:hasGroundTileAt(collider)
    local map = self.map
    if not map then return false end
    local probe = getSupportProbe(collider)
    local world_x, world_y = probe.x, probe.y
    if probe.parent then
        world_x, world_y = probe.parent:getFullTransform():transformPoint(world_x, world_y)
    end
    for _, layer in ipairs(map.tile_layers or {}) do
        if layer.provides_ground ~= false and math.abs(layer.z or 0) < 0.001 then
            local local_x, local_y = layer:getFullTransform():inverseTransformPoint(world_x, world_y)
            local tile_x = math.floor(local_x / map.tile_width)
            local tile_y = math.floor(local_y / map.tile_height)
            if tile_x >= 0 and tile_y >= 0
                and tile_x < layer.map_width and tile_y < layer.map_height then
                local index = tile_x + tile_y * layer.map_width + 1
                local packed = layer.tile_data and layer.tile_data[index]
                local gid = packed and map:decodeTileData(packed)
                if gid and gid ~= 0 then return true end
            end
        end
    end
    return false
end

--- Whether an XY footprint is currently over an explicit pit region.
---@param collider Collider
---@return boolean
function World:isOverPit(collider)
    if not self.map or not self.map.pits then return false end
    local probe = getSupportProbe(collider)
    Object.startCache()
    for _, pit in ipairs(self.map.pits) do
        if probe:collidesWith(pit) then
            Object.endCache()
            return true
        end
    end
    Object.endCache()
    return false
end

--- Whether a supporting solid rises from the requested elevation in this column.
--- Fully raised platforms leave the implicit floor beneath them intact.
---@param collider Collider
---@param z? number
---@param ignored? Collider|table<Collider, boolean>
---@return boolean
function World:hasElevatedSupportAt(collider, z, ignored)
    z = z or 0
    Object.startCache()
    for _, surface in ipairs(self:getCollision(false)) do
        local bottom = surface:getZBounds()
        local top = self:getSupportHeightAt(surface, collider)
        if surface.supports and top > z + 0.001
            and bottom <= z + 0.001
            and not isIgnoredCollision(surface, ignored)
            and collider:collidesWith(surface) then
            Object.endCache()
            return true
        end
    end
    Object.endCache()
    return false
end

--- Whether the implicit z=0 ground exists beneath an XY footprint.
---@param collider Collider
---@param z? number
---@param ignored? Collider|table<Collider, boolean>
---@return boolean
function World:hasImplicitGroundAt(collider, z, ignored)
    if self:isOverPit(collider) then return false end
    if self:hasElevatedSupportAt(collider, z or 0, ignored) then return false end
    if self.map and self.map.empty_tile_pit then
        return self:hasGroundTileAt(collider)
    end
    return true
end

--- Whether falling at this footprint should invoke pit recovery.
---@param collider Collider
---@return boolean
function World:isPitFallAt(collider)
    if self:isOverPit(collider) then return true end
    return self.map and self.map.empty_tile_pit and not self:hasGroundTileAt(collider) or false
end

--- Whether a body can occupy a requested Z without intersecting a solid wall.
---@param collider Collider
---@param z number
---@param ignored? Collider
---@param also_ignored? Collider
---@return boolean
function World:isHeightClear(collider, z, ignored, also_ignored)
    local collider_depth = math.max(collider.depth or 0, 0)
    Object.startCache()
    for _, other in ipairs(self:getCollision(false)) do
        if not isIgnoredCollision(other, ignored)
            and not isIgnoredCollision(other, also_ignored)
            and not other.one_way and collider:collidesWith(other) then
            local other_bottom = other:getZBounds()
            local other_top = self:getSupportHeightAt(other, collider)
            local overlaps
            if collider_depth == 0 and other.depth == 0 then
                overlaps = z == other_bottom
            elseif collider_depth == 0 then
                overlaps = z >= other_bottom and z < other_top
            elseif other.depth == 0 then
                overlaps = other_bottom > z + 0.001
                    and other_bottom < z + collider_depth
            else
                overlaps = math.max(z, other_bottom) < math.min(z + collider_depth, other_top)
            end
            if overlaps then
                Object.endCache()
                return false
            end
        end
    end
    Object.endCache()
    return true
end

--- Finds a supporting surface at a specific elevation.
---@param collider Collider XY grounded footprint
---@param z number Desired surface elevation
---@param tolerance? number
---@param ignored? Collider|table<Collider, boolean>
---@return number? surface_z
---@return Collider? surface
---@return table? height_surface
function World:getSupportAt(collider, z, tolerance, ignored)
    tolerance = tolerance or 0.5
    local best_z, best_surface

    Object.startCache()
    for _, surface in ipairs(self:getCollision(false)) do
        if not isIgnoredCollision(surface, ignored)
            and surface.supports and collider:collidesWith(surface) then
            local top = self:getSupportHeightAt(surface, collider)
            if math.abs(top - z) <= tolerance and (not best_z or top > best_z) then
                best_z, best_surface = top, surface
            end
        end
    end
    Object.endCache()

    if math.abs(z) <= tolerance and self:hasImplicitGroundAt(collider, z, ignored) then
        if not best_z or best_z < 0 then
            return 0, nil, self:getImplicitHeightSurface()
        end
    end

    return best_z, best_surface, self:getHeightSurfaceForCollider(best_surface)
end

--- Finds the highest support surface crossed during a downward Z sweep.
---@param collider Collider XY grounded footprint
---@param old_z number
---@param new_z number
---@param body_collider? Collider Full body used to reject landings inside walls
---@param ignored_collider? Collider Departed platform side that may still overlap the body
---@param departed_surface? Collider Surface just walked off, to reject an equality snap-back
---@return number? surface_z
---@return Collider? surface
---@return table? height_surface
function World:getLandingSurface(collider, old_z, new_z, body_collider,
    ignored_collider, departed_surface)
    if new_z > old_z then return nil end

    local best_z, best_surface
    Object.startCache()
    for _, surface in ipairs(self:getCollision(false)) do
        if not isIgnoredCollision(surface, ignored_collider)
            and surface.supports and collider:collidesWith(surface) then
            local top = self:getSupportHeightAt(surface, collider)
            local previous_top = surface.slope and top or surface.previous_top or top
            local snapping_back =
                self:matchesDepartedHeight(surface, departed_surface, collider)
                and old_z <= previous_top + 0.001
            local crossed_surface = old_z >= previous_top - 0.001
                and new_z <= top + 0.001
            local base_floor_catchup = math.abs(top) < 0.001 and new_z <= top
                and not self:isOverPit(collider)
            if not snapping_back and (crossed_surface or base_floor_catchup)
                and (not body_collider
                    or self:isHeightClear(body_collider, top, surface, ignored_collider))
                and (not best_z or top > best_z) then
                best_z, best_surface = top, surface
            end
        end
    end
    Object.endCache()

    -- Recheck z=0 even after it has been crossed. This lets a player who fell
    -- past the floor while overlapping a wall land once they clear that wall.
    if new_z <= 0 and self:hasImplicitGroundAt(collider, 0, ignored_collider)
        and (not body_collider
            or self:isHeightClear(body_collider, 0, ignored_collider)) then
        if not best_z or best_z < 0 then
            return 0, nil, self:getImplicitHeightSurface()
        end
    end

    return best_z, best_surface, self:getHeightSurfaceForCollider(best_surface)
end

---@param subject Object
---@param old_z number
---@param new_z number
---@param ceiling_z? number Highest surface this fall may reach
---@param departed? Collider Surface that initiated the fall
---@param ignored? Collider|table<Collider, boolean>
---@param explicit_only? boolean Skip implicit z=0 ground
---@return number? landing_z
---@return Collider? surface
---@return table? height_surface
function World:tryProjectedLanding(subject, old_z, new_z, ceiling_z,
    departed, ignored, explicit_only)
    if new_z >= old_z then return nil end

    local original_x, original_y = subject.x, subject.y
    ceiling_z = math.max(old_z, ceiling_z or old_z)
    local direction_x = subject.height_departure_x
    local direction_y = subject.height_departure_y
    if direction_x == nil or direction_y == nil then
        direction_x, direction_y = self:getHeightDepartureDirection(subject, departed)
    end
    if direction_x == 0 and direction_y == 0 then direction_y = 1 end

    local function setOffset(offset)
        subject.x = original_x + direction_x * offset
        subject.y = original_y + direction_y * offset
        Object.uncache(subject)
    end

    local function visitOffsets(maximum, callback)
        maximum = math.max(0, math.ceil(maximum))
        if direction_x == 0 and direction_y > 0 then
            for offset = maximum, 0, -1 do
                setOffset(offset)
                local z, surface, height_surface = callback(offset)
                if z ~= nil then return z, surface, height_surface end
            end
        else
            for offset = 0, maximum do
                setOffset(offset)
                local z, surface, height_surface = callback(offset)
                if z ~= nil then return z, surface, height_surface end
            end
        end
        return nil
    end

    local candidates = {}
    for _, surface in ipairs(self:getCollision(false)) do
        if surface.supports and not isIgnoredCollision(surface, ignored)
            and not self:matchesDepartedHeight(
                surface, departed, subject.support_collider) then
            local _, maximum_top = surface:getZBounds()
            if maximum_top >= new_z - 0.001
                and maximum_top <= ceiling_z + 0.001 then
                table.insert(candidates, { surface = surface, top = maximum_top })
            end
        end
    end
    table.stable_sort(candidates, function(a, b) return a.top > b.top end)

    for _, candidate in ipairs(candidates) do
        local landing_z, landing, height_surface = visitOffsets(
            candidate.top - new_z,
            function(offset)
                local surface = candidate.surface
                if not subject.support_collider:collidesWith(surface) then return nil end
                local top = self:getSupportHeightAt(surface, subject.support_collider)
                if top < new_z - 0.001 or top > ceiling_z + 0.001
                    or offset > top - new_z + 0.001 then return nil end
                if not self:isHeightClear(
                    subject.collider, top, surface, ignored) then return nil end
                return top, surface, self:getHeightSurfaceForCollider(surface)
            end)
        if landing_z ~= nil then return landing_z, landing, height_surface end
    end

    if not explicit_only and new_z < 0 then
        local landing_z, landing, height_surface = visitOffsets(-new_z,
            function()
                local ground_z, ground, ground_surface = self:getGroundZAt(
                    subject.support_collider, 0, subject.collider, ignored)
                if ground_z == nil or math.abs(ground_z) > 0.001
                    or self:matchesDepartedHeight(
                        ground, departed, subject.support_collider) then
                    return nil
                end
                return 0, ground, ground_surface
            end)
        if landing_z ~= nil then return landing_z, landing, height_surface end
    end

    subject.x, subject.y = original_x, original_y
    Object.uncache(subject)
    return nil
end

--- Finds the lowest solid underside crossed during an upward Z sweep.
---@param collider Collider XY body footprint
---@param old_top number
---@param new_top number
---@return number? ceiling_z
---@return Collider? surface
function World:getCeilingSurface(collider, old_top, new_top)
    if new_top < old_top then return nil end

    local best_z, best_surface
    Object.startCache()
    for _, surface in ipairs(self:getCollision(false)) do
        if not surface.one_way and collider:collidesWith(surface) then
            local bottom, top = surface:getZBounds()
            if surface.depth > 0 and bottom >= old_top and bottom <= new_top
                and (not best_z or bottom < best_z) then
                best_z, best_surface = bottom, surface
            end
        end
    end
    Object.endCache()
    return best_z, best_surface
end

--- Finds the highest ground at or below a requested elevation.
---@param collider Collider XY grounded footprint
---@param maximum_z number
---@param body_collider? Collider Full body used to reject ground inside walls
---@param ignored_collider? Collider Departed platform side that may still overlap the body
---@return number? surface_z
---@return Collider? surface
---@return table? height_surface
function World:getGroundZAt(collider, maximum_z, body_collider, ignored_collider)
    local best_z, best_surface
    Object.startCache()
    for _, surface in ipairs(self:getCollision(false)) do
        if not isIgnoredCollision(surface, ignored_collider)
            and surface.supports and collider:collidesWith(surface) then
            local top = self:getSupportHeightAt(surface, collider)
            if top <= maximum_z
                and (not body_collider
                    or self:isHeightClear(body_collider, top, surface, ignored_collider))
                and (not best_z or top > best_z) then
                best_z, best_surface = top, surface
            end
        end
    end
    Object.endCache()

    if maximum_z >= 0 and self:hasImplicitGroundAt(collider, 0, ignored_collider)
        and (not body_collider or self:isHeightClear(body_collider, 0, ignored_collider))
        and (not best_z or best_z < 0) then
        return 0, nil, self:getImplicitHeightSurface()
    end
    return best_z, best_surface, self:getHeightSurfaceForCollider(best_surface)
end

--- Whether the world has a currently active cutscene
---@return boolean?
function World:hasCutscene()
    return self.cutscene and not self.cutscene.ended
end

--- Starts a cutscene in the world
---@overload fun(self: World, id: string, ...)
---@overload fun(self: World, func: WorldCutsceneFunc, ...)
---@param group string  The name of the group the cutscene is a part of
---@param id    string  The id of the cutscene
---@param ...   any     Additional arguments that will be passed to the cutscene function
---@return WorldCutscene?   The cutscene object that was created
function World:startCutscene(group, id, ...)
    if self.cutscene and not self.cutscene.ended then
        local cutscene_name = ""
        if type(group) == "string" then
            cutscene_name = group
            if type(id) == "string" then
                cutscene_name = group .. "." .. id
            end
        elseif type(group) == "function" then
            cutscene_name = "<function>"
        end
        error("Attempt to start a cutscene " .. cutscene_name .. " while already in cutscene " .. self.cutscene.id)
    end
    if Kristal.Console.is_open then
        Kristal.Console:close()
    end
    self.cutscene = WorldCutscene(self, group, id, ...)
    return self.cutscene
end

--- Stops the current cutscene \
--- An error will be thrown when trying to stop a cutscene if none are active
function World:stopCutscene()
    if not self.cutscene then
        error("Attempt to stop a cutscene while none are active.")
    end
    self.cutscene:onEnd()
    coroutine.yield(self.cutscene)
    self.cutscene = nil
end

--- Shows a textbox with the input `text`
---@param text      string|string[]|string[][]
---@param after?    WorldCutsceneFunc        A callback to run when the textbox is closed, receiving the cutscene instance used to display the text
function World:showText(text, after)
    if type(text) ~= "table" then
        text = { text }
    end
    self:startCutscene(function(cutscene)
        for _, line in ipairs(text) do
            cutscene:text(line)
        end
        if after then
            after(cutscene)
        end
    end)
end

--- Spawns the player into the world
---@overload fun(self: World, x: number, y: number, chara: string|Actor, party?: string, z?: number)
---@overload fun(self: World, marker: string, chara: string|Actor, party?: string)
---@param ... unknown   Arguments detailing how the player spawns
---|"x, y, chara"   # The coordinates of the player spawn and the Actor (instance or id) to use for the player
---|"marker, chara" # The marker name to spawn the player at and the Actor (instance or id) to use for the player
---@param party? string The party member ID associated with the player
function World:spawnPlayer(...)
    local args = { ... }

    local x, y, z = 0, 0, 0
    local state = "WALK"
    local chara = self.player and self.player.actor
    local party
    if #args > 0 then
        if type(args[1]) == "number" then
            x, y = args[1], args[2]
            chara = args[3] or chara
            party = args[4]
            z = args[5] or 0
        elseif type(args[1]) == "string" or type(args[1]) == "table" then
            local data
            x, y, data = self.map:getMarker(args[1])
            chara = args[2] or chara
            party = args[3]

            if data ~= nil then
                state = data.player_state or "WALK"
                z = self.map:getMarkerZ(args[1]) or 0
            end
        end
    end

    if type(chara) == "string" then
        chara = Registry.createActor(chara)
    end

    local facing = "down"

    if self.player then
        facing = self.player:getFacing()
        self:removeChild(self.player)
    end

    self.player = Player(chara, x, y)
    self.player.z = z
    self.player.last_safe_z = z
    MapUtils.addLayerOffset(self.player, self.map.object_layer)
    self.player:setFacing(facing)
    self.player:setState(state)
    self:addChild(self.player)
    self.player:setPlatformingEnabled(self.map.platforming)

    if party then
        self.player.party = party
    end

    if self.camera.attached_x then
        self.camera:setPosition(self.player.x, self.camera.y)
    end
    if self.camera.attached_y then
        self.camera:setPosition(
            self.camera.x,
            self.player.y - (self.player.height * 2) / 2
                - (self.player.camera_z or 0)
        )
    end
end

--- Spawns the soul into the world
---@param x? number
---@param y? number
function World:spawnSoul(x, y)
    if self.soul then
        self:removeChild(self.soul)
    end
    self.soul = OverworldSoul(x, y)
    self:addChild(self.soul)
end

--- Gets the `Character` in the world of a party member
---@param party string|PartyMember  The party member to get the character for
---@return Character?
function World:getPartyCharacter(party)
    if type(party) == "string" then
        party = Game:getPartyMember(party)
    end
    local char_to_return
    for _, char in ipairs(Game.stage:getObjects(Character)) do
        -- Immediately break the loop and return if we find an explicit party match
        if char.party and char.party.id == party.id then
            return char
        end
        -- Store the first actor match, do not break loop as the match is not explicit
        if char.actor and char.actor.id == party:getActor().id then
            char_to_return = char_to_return or char
        end
    end
    return char_to_return
end

--- Gets the `Follower` or `Player` of a character currently in the party
---@param party string|PartyMember  The party member to get the character for
---@return Player|Follower?
function World:getPartyCharacterInParty(party)
    if type(party) == "string" then
        party = Game:getPartyMember(party)
    end
    if self.player and Game:hasPartyMember(self.player:getPartyMember()) and party == self.player:getPartyMember() then
        return self.player
    else
        for _, follower in ipairs(self.followers) do
            if Game:hasPartyMember(follower:getPartyMember()) and party == follower:getPartyMember() then
                return follower
            end
        end
    end
end

--- Removes a follower
---@param chara string|Follower The `Follower` or the follower's actor id to remove
---@return Follower? follower The follower that was removed
function World:removeFollower(chara)
    local follower_arg = isClass(chara) and chara:includes(Follower)
    for i, follower in ipairs(self.followers) do
        if (follower_arg and follower == chara) or (not follower_arg and follower.actor.id == chara) then
            table.remove(self.followers, i)
            for j, temp in ipairs(Game.temp_followers) do
                if temp == follower.actor.id or (type(temp) == "table" and temp[1] == follower.actor.id) then
                    table.remove(Game.temp_followers, j)
                    break
                end
            end
            return follower
        end
    end
end

--- Spawns a follower into the world
---@param chara     Follower|string|Actor   The character to spawn as a follower
---@param options?  table                 A table defining additional properties to control the new follower
---|"x"         # The position of the follower
---|"y"         # The position of the follower
---|"index"     # The index of the follower in the list of followers
---|"temp"      # Whether the follower is temporary and disappears when the current map is exited (defaults to `true`)
---|"party"     # The id of the party member associated with this follower
---@return Follower
function World:spawnFollower(chara, options)
    if type(chara) == "string" then
        chara = Registry.createActor(chara)
    end
    options = options or {}
    local follower
    if isClass(chara) and chara:includes(Follower) then
        follower = chara
    else
        local x = 0
        local y = 0
        if self.player then
            x = self.player.x
            y = self.player.y
        end
        follower = Follower(chara, x, y)
        follower.z = self.player and self.player.z or 0
        MapUtils.addLayerOffset(follower, self.map.object_layer)
        if self.player then
            follower:setFacing(self.player:getFacing())
        end
    end
    if options["x"] or options["y"] then
        follower:setPosition(options["x"] or follower.x, options["y"] or follower.y)
    end
    if options["z"] ~= nil then follower.z = options["z"] end
    if options["index"] then
        table.insert(self.followers, options["index"], follower)
    else
        table.insert(self.followers, follower)
    end
    if options["temp"] == false then
        if options["index"] then
            table.insert(Game.temp_followers, { follower.actor.id, options["index"] })
        else
            table.insert(Game.temp_followers, follower.actor.id)
        end
    end
    if options["party"] then
        follower.party = options["party"]
    end
    self:addChild(follower)
    follower:updateIndex()
    return follower
end

--- Spawns characters in the world for the current party
---@param marker?   string|KristalObjectRef|Position                            The marker or coordinates to spawn the player at
---@param party?    (PartyMember|string)[]                                      A table of party members to spawn (Defaults to [`Game.party`](lua://Game.party))
---@param extra?    (Follower|Actor|string|[Follower|Actor|string,integer])[]   Additional followers to add that are not in the party (defaults to [`Game.temp_followers`](lua://Game.temp_followers))
---@param facing?   FacingDirection                                             The direction the party should be facing when they spawn
function World:spawnParty(marker, party, extra, facing)
    party = party or Game.party or { "kris" }
    if #party > 0 then
        for i, chara in ipairs(party) do
            if type(chara) == "string" then
                party[i] = Game:getPartyMember(chara)
            end
        end

        if type(marker) == "table" and marker[1] ~= nil and marker[2] ~= nil then
            -- It's a position table...
            self:spawnPlayer(marker[1], marker[2], party[1]:getActor(), party[1].id, marker[3])
        else
            if not self.map:hasMarker(marker) then
                marker = "spawn"
            end

            self:spawnPlayer(marker, party[1]:getActor(), party[1].id)
        end

        if facing then
            self.player:setFacing(facing)
        end

        for i = 2, #party do
            local follower = self:spawnFollower(party[i]:getActor(), { party = party[i].id })
            follower:setFacing(facing or self.player:getFacing())
        end
        for _, actor in ipairs(extra or Game.temp_followers or {}) do
            if type(actor) == "table" then
                local follower = self:spawnFollower(actor[1], { index = actor[2] })
                follower:setFacing(facing or self.player:getFacing())
            else
                local follower = self:spawnFollower(actor)
                follower:setFacing(facing or self.player:getFacing())
            end
        end
        self:spawnSoul()
    end
end

--- Spawns a new `WorldBullet` to the world
---@overload fun(self: World, bullet: WorldBullet)
---@param bullet?   string  The bullet to add to the world, if left unspecified, spawns the basic `WorldBullet`
---@param ...       any     Additional arguments to pass to the bullet's init() function
---@return WorldBullet bullet The newly created bullet
function World:spawnBullet(bullet, ...)
    ---@diagnostic disable param-type-mismatch
    local new_bullet
    if isClass(bullet) and bullet:includes(WorldBullet) then
        new_bullet = bullet
    elseif Registry.getWorldBullet(bullet) then
        new_bullet = Registry.createWorldBullet(bullet, ...)
    else
        local x, y = ...
        table.remove(arg, 1)
        table.remove(arg, 1)
        new_bullet = WorldBullet(x, y, bullet, unpack(arg))
    end
    new_bullet.layer = WORLD_LAYERS["bullets"]
    new_bullet.world = self
    table.insert(self.bullets, new_bullet)
    if not new_bullet.parent then
        self:addChild(new_bullet)
    end
    return new_bullet
    ---@diagnostic enable param-type-mismatch
end

--- Spawns a new NPC object in the world
---@param actor         string|Actor    The actor to use for the new NPC, either an id string or an actor object
---@param x             number          The x-coordinate to place the NPC at
---@param y             number          The y-coordinate to place the NPC at
---@param properties?   table           A table of additional properties for the new NPC. Supports all the same values as an `npc` map event
---@return NPC npc The newly created npc.
function World:spawnNPC(actor, x, y, properties)
    return self:spawnObject(NPC(actor, x, y, properties))
end

--- Spawns an object to the world
---@generic T : Object
---@param obj T                 The object to add to the world
---@param layer? string|number  The layer to place the object on
---@return T
function World:spawnObject(obj, layer)
    if type(layer) == "number" or WORLD_LAYERS[layer] ~= nil then
        obj.layer = self:parseLayer(layer)
    else
        MapUtils.addLayerOffset(obj, self.map.layers[layer] or self.map.object_layer)
    end
    self:addChild(obj)
    return obj
end

--- Gets a specific character currently present in the world
---@param id        string  The actor id of the character to search for
---@param index?    number  The character's index, if they have multiple instances in the world. (Defaults to `1`)
---@return Character? chara The character instance, or `nil` if it was not found
function World:getCharacter(id, index)
    local party_member = Game:getPartyMember(id)
    local i = 0
    for _, chara in ipairs(Game.stage:getObjects(Character)) do
        if chara.actor.id == id or (party_member and chara.party and chara.party == party_member.id) then
            i = i + 1
            if not index or index == i then
                return chara
            end
        end
    end
end

--- Gets the action box instance for a member of the party
---@param party_member string|PartyMember
---@return OverworldActionBox?
function World:getActionBox(party_member)
    if not self.healthbar then return nil end
    if type(party_member) == "string" then
        party_member = Game:getPartyMember(party_member)
    end
    for _, box in ipairs(self.healthbar.action_boxes) do
        if box.chara == party_member then
            return box
        end
    end
    return nil
end

--- Creates a reaction text on a party member's healthbar (usually used for equipment and items)
---@param party_member  string|PartyMember  The party member who will react
---@param text          string              The text to display for the reaction
---@param display_time? number              The display time, in seconds, of the reaction (defaults to 5/3 seconds)
function World:partyReact(party_member, text, display_time)
    local action_box = self:getActionBox(party_member)
    if action_box then
        action_box:react(text, display_time)
    end
end

--- Gets a specific event present in the current map.
---
--- If multiple objects are found (if you pass in a name), only the first will be returned. Use `Map:getEvents` to get all of them.
---@param id string|number|TiledObjectRef The id of the event to search for, either as a string or a number
---@return Event event The name of the event, the unique numerical ID, or a Tiled object reference.
function World:getEvent(id)
    return self.map:getEvent(id)
end

--- Gets all instances of an event present in the current map.
---@param name? string The text id of the event to search for. If left unspecified, all events will be returned.
---@return Event[] events A table containing every instance of the event in the current map
function World:getEvents(name)
    return self.map:getEvents(name)
end

--- Disables following for all of the player's current followers
function World:detachFollowers()
    for _, follower in ipairs(self.followers) do
        follower.following = false
    end
end

--- Enables following for all of the player's current followers and causes them to walk to their positions
---@param return_speed? number The walking speed of the followers while they return to the player
function World:attachFollowers(return_speed)
    for _, follower in ipairs(self.followers) do
        follower:updateIndex()
        follower:returnToFollowing(return_speed)
    end
end
--- Enables following for all of the player's current followers, and immediately teleports them to their positions
function World:attachFollowersImmediate()
    for _, follower in ipairs(self.followers) do
        follower.following = true

        follower:updateIndex()
        follower:moveToTarget()
    end
end

--- Parses a variable-type layer specification into a recognised layer
---@param layer?    number|string
---@return number
function World:parseLayer(layer)
    return (type(layer) == "number" and layer)
        or WORLD_LAYERS[layer]
        or self.map.layers[layer]
        or self.map.object_layer
end

--- Sets up several variables for a new map
---@param map? Map|string|table The Map object, name, or data to load
---@param ... unknown           Additional arguments that will be passed forward into Map:onEnter()
function World:setupMap(map, ...)
    for _, child in ipairs(self.children) do
        if not child.persistent then
            self:removeChild(child)
        end
    end
    for _, child in ipairs(self.controller_parent.children) do
        if not child.persistent then
            self.controller_parent:removeChild(child)
        end
    end

    self:updateChildList()

    self.healthbar = nil
    self.followers = {}

    self.camera:resetModifiers(true)
    self.camera:setAttached(true)

    if isClass(map) then
        self.map = map
    elseif type(map) == "string" then
        self.map = Registry.createMap(map, self, ...)
    elseif type(map) == "table" then
        self.map = Map(self, map, ...)
    else
        self.map = Map(self, nil, ...)
    end

    self.map:load()

    local dark_transitioned = self.map.light ~= Game:isLight()

    Game:setLight(self.map.light)

    self.width = self.map.width * self.map.tile_width
    self.height = self.map.height * self.map.tile_height

    --self.camera:setBounds(0, 0, self.map.width * self.map.tile_width, self.map.height * self.map.tile_height)

    self.battle_fader = Rectangle(0, 0, SCREEN_WIDTH, SCREEN_HEIGHT)
    self.battle_fader:setParallax(0, 0)
    self.battle_fader:setColor(0, 0, 0)
    self.battle_fader.alpha = 0
    self.battle_fader.layer = self.map.battle_fader_layer
    self.battle_fader.debug_select = false
    self:addChild(self.battle_fader)

    self.in_battle = false
    self.in_battle_area = false
    self.battle_alpha = 0

    local map_border = self.map:getBorder(dark_transitioned)
    if map_border then
        Game:setBorder(Kristal.callEvent(KRISTAL_EVENT.onMapBorder, self.map, map_border) or map_border)
    end

    if not self.map.keep_music then
        self:transitionMusic(Kristal.callEvent(KRISTAL_EVENT.onMapMusic, self.map, self.map.music) or self.map.music)
        self.additional_music:stop()

        if (self.map.can_hum) then
            self.hum_timer = self.map.data.properties.hum_delay * 60
        end
    end
end

--- Loads into a new map file.
---@overload fun(self: World, map: string, x: number, y: number, facing?: string, callback?: string, ...: any)
---@overload fun(self: World, map: string, marker?: string, facing?: string, callback?: string, ...: any)
---@param map       string      The name of the map file to load
---@param x         number      The x-coordinate the player will spawn at in the new map
---@param y         number      The y-coordinate the player will spawn at in the new map
---@param marker?   string      The name of the marker the player will spawn at in the new map (Defaults to `"spawn"`)
---@param facing?   string      The direction the party should be facing when they spawn in the new map
---@param callback? fun()       A callback to run once the map has finished loading (Post Map:onEnter())
---@param ... unknown           Additional arguments that will be passed forward into Map:onEnter()
function World:loadMap(...)
    local args = { ... }
    -- x, y, facing, callback
    local map = table.remove(args, 1)
    local marker, x, y, z, facing, callback
    if type(args[1]) == "string" or type(args[1]) == "table" then
        marker = table.remove(args, 1)
    elseif type(args[1]) == "number" then
        x = table.remove(args, 1)
        y = table.remove(args, 1)
        if type(args[1]) == "number" then
            z = table.remove(args, 1)
        end
    else
        marker = "spawn"
    end
    if args[1] then
        facing = table.remove(args, 1)
    end
    if args[1] then
        callback = table.remove(args, 1)
    end

    local previous_movement_state = self.pending_transition_movement_state
    self.pending_transition_movement_state = nil
    self.pending_transition_run_state = nil
    if not previous_movement_state then
        previous_movement_state = self:captureTransitionMovementState()
    end

    if self.map then
        self.map:onExit()
    end

    self:setupMap(map, unpack(args))

    local spawn = self.map.player_spawn or self.map.markers["spawn"]
    if spawn then
        self.camera:setPosition(spawn.center_x, spawn.center_y)
    end

    local marker_has_player_state
    if marker then
        local _, _, data = self.map:getMarker(marker)
        marker_has_player_state = data and data.has_player_state
    end

    if marker then
        self:spawnParty(marker, nil, nil, facing)
    else
        self:spawnParty({ x, y, z }, nil, nil, facing)
    end

    self:setState("GAMEPLAY")

    if self.player then
        self.player:onMapLoad()
    end

    for _, event in ipairs(self.map.events) do
        if event.postLoad then
            event:postLoad()
        end
    end

    self.map:onEnter()

    if callback then
        callback(self.map)
    end

    if previous_movement_state and not marker_has_player_state and self.player then
        self.player:restoreTransitionMovementState(previous_movement_state)

        for _, follower in ipairs(self.followers) do
            if follower.following then
                follower.state_manager:setState(previous_movement_state.state)
                if previous_movement_state.state == "DASH" then
                    follower.dash_timer = previous_movement_state.dash_timer
                    follower.dash_afterimages = previous_movement_state.dash_afterimages
                end
            end
        end
    end
end

--- Transitions the music from the current track to the `next`
---@overload fun(self: World, music: string)
---@param music     string                                              The name of the file to play next
---@param next      {music?: string, volume?: number, pitch?: number}   The filename, volume, and pitch of the next track
---@param fade_out? boolean                                             Whether to fade out the currently playing track before playing the next track
function World:transitionMusic(next, fade_out)
    -- Compatibility with older versions of transitionMusic which have "next" as the music
    local music = ""
    local volume = 1
    local pitch = 1
    if type(next) == "table" then
        music = next[1]
        volume = next[2]
        pitch = next[3]
    else
        music = next
    end
    --
    if music and music ~= "" then
        if self.music.current ~= music then
            if self.music:isPlaying() and fade_out then
                self.music:fade(0, 10 / 30, function() self.music:stop() end)
            elseif not fade_out then
                self.music:play(music, volume, pitch)
            end
        else
            if not self.music:isPlaying() then
                if not fade_out then
                    self.music:play(music, volume, pitch)
                end
            else
                self.music:fade(volume)
            end
        end
    else
        if self.music:isPlaying() then
            if fade_out then
                self.music:fade(0, 10 / 30, function() self.music:stop() end)
            else
                self.music:stop()
            end
        end
    end
end

--- Transitions the music from the current track to the `next` while keeping the same playback position
---@overload fun(self: World, music: string)
---@param music     string                                              The name of the file to play next
---@param next      {music?: string, volume?: number, pitch?: number}   The filename, volume, and pitch of the next track
---@param fade_out? boolean                                             Whether to fade out the currently playing track before playing the next track
function World:transitionMusicTimed(next, fade_out)
    -- Compatibility with older versions of transitionMusic which have "next" as the music
    local music = ""
    local volume = 1
    local pitch = 1
    if type(next) == "table" then
        music = next[1]
        volume = next[2]
        pitch = next[3]
    else
        music = next
    end
    --
    local playback_position = 0
    if music and music ~= "" then
        if self.music.current ~= music then
            if self.music:isPlaying() and fade_out then
                self.music:fade(0, 10 / 30, function() playback_position = self.music:tell(); self.music:stop(); self.music:play(music, volume, pitch); self.music:seek(playback_position) end)
            elseif not fade_out then
                playback_position = self.music:tell()
                self.music:play(music, volume, pitch)
                self.music:seek(playback_position)
            end
        else
            if not self.music:isPlaying() then
                if not fade_out then
                    self.music:play(music, volume, pitch)
                end
            else
                self.music:fade(volume)
            end
        end
    else
        if self.music:isPlaying() then
            if fade_out then
                self.music:fade(0, 10 / 30, function() self.music:stop() end)
            else
                self.music:stop()
            end
        end
    end
end

--[[
    Possible argument formats:
        - Target table
            e.g. ({map = "mapid", marker = "markerid", facing = "down"})
        - Map id, [ spawn X, spawn Y, [facing] ]
            e.g. ("mapid")
                 ("mapid", 20, 5)
                 ("mapid", 30, 40, "down")
        - Map id, [ marker, [facing] ]
            e.g. ("mapid", "markerid")
                 ("mapid", "markerid", "up")
]]
local function parseTransitionTargetArgs(...)
    local args = {...}
    if #args == 0 then return {} end
    if type(args[1]) ~= "table" or isClass(args[1]) then
        local target = {map = args[1]}
        if type(args[2]) == "number" and type(args[3]) == "number" then
            target.x = args[2]
            target.y = args[3]
            if type(args[4]) == "string" then
                target.facing = args[4]
            end
        elseif type(args[2]) == "string"
            or type(args[2]) == "table" and (args[2].object_id ~= nil or args[2].object ~= nil) then
            target.marker = args[2]
            if type(args[3]) == "string" then
                target.facing = args[3]
            end
        end
        return target
    else
        return args[1]
    end
end

--- Transitions from the world into a shop
---@param shop      string|Shop The shop to enter
---@param options?  table       An optional table of [`leave_options`](lua://Shop.leave_options) for exiting the shop
function World:shopTransition(shop, options)
    self:fadeInto(function()
        Game:enterShop(shop, options)
    end)
end

function World:captureTransitionMovementState()
    if not self.player then
        return nil
    end

    if self.player.state_manager.state == "DASH" then
        return {
            state = "DASH",
            dash_timer = self.player.dash_timer,
            dash_momentum = { self.player.dash_momentum[1], self.player.dash_momentum[2] },
            dash_magnitude = { self.player.dash_magnitude[1], self.player.dash_magnitude[2] },
            dash_afterimages = self.player.dash_afterimages,
            was_running = self.player.was_running
        }
    end

    local momentum_x = self.player.run_momentum[1]
    local momentum_y = self.player.run_momentum[2]
    local has_run_momentum = math.abs(momentum_x) > 0.05 or math.abs(momentum_y) > 0.05
    local was_running = self.player.state_manager.state == "RUN" or self.player.run_timer > 0 or has_run_momentum
    if not was_running then
        return nil
    end

    return {
        state = "RUN",
        run_timer = math.max(self.player.run_timer, 31),
        run_timer_grace = self.player.run_timer_grace,
        run_momentum = { momentum_x, momentum_y },
        temp_boost_x = self.player.temp_boost_x,
        temp_boost_y = self.player.temp_boost_y,
        run_transition_grace = math.max(self.player.run_transition_grace or 0, 0.5)
    }
end

--- Loads a new map and starts the transition effects for world music, borders, and the screen as a whole
---@overload fun(self: World, map: string, ...: any)
---@param ... any   Additional arguments that will be passed into World:loadMap()
---@see World - World:loadMap()
function World:mapTransition(...)
    local args = { ... }
    self.pending_transition_movement_state = self:captureTransitionMovementState()
    local map = args[1]
    local changing_bucket = type(map) == "string" and Assets.mapBucketsChanged(map)
    if type(map) == "string" and not changing_bucket then
        local map = Registry.createMap(map)
        if not map.keep_music then
            self:transitionMusic(Kristal.callEvent(KRISTAL_EVENT.onMapMusic, self.map, self.map.music) or map.music, true)
            self.additional_music:stop()
        end
        local dark_transition = map.light ~= Game:isLight()
        local map_border = map:getBorder(dark_transition)
        if map_border then
            Game:setBorder(Kristal.callEvent(KRISTAL_EVENT.onMapBorder, self.map, map_border) or map_border, 1)
        end
    end
    if changing_bucket then
        self:setState("FADING")
        Assets.prepareMapBucket(map, function(commit)
            self:fadeInto(function()
                commit(function() self:loadMap(TableUtils.unpack(args)) end)
            end)
        end)
    else
        self:fadeInto(function()
            self:loadMap(TableUtils.unpack(args))
        end)
    end
end

--- Fades the world out and into another piece of content
---@param callback fun()    The callback that is run in the middle of the fade (fully faded out) to load the next piece of content
function World:fadeInto(callback)
    self:setState("FADING")
    Game.fader:transition(callback)
end

--- Gets the object that the camera is currently targetting
---@return Object?
function World:getCameraTarget()
    if self.camera.target and self.camera.target.stage then
        return self.camera.target
    else
        return self.player
    end
end

--- Sets the object the camera should target
---@param target Object?
function World:setCameraTarget(target)
    self.camera.target = target
end

--- Sets whether the camera should be attached to its target for each axis
---@param attached_x? boolean   Whether the camera's x-axis position should follow its target
---@param attached_y? boolean   Whether the camera's y-axis position should follow its target
function World:setCameraAttached(attached_x, attached_y)
    self.camera:setAttached(attached_x, attached_y)
end

--- Sets whether the camera should follow its target on the x-axis
---@param attached? boolean
function World:setCameraAttachedX(attached) self:setCameraAttached(attached, self.camera.attached_x) end
--- Sets whether the camera should follow its target on the y-axis
---@param attached? boolean
function World:setCameraAttachedY(attached) self:setCameraAttached(self.camera.attached_y, attached) end

---@param x? number
---@param y? number
---@param friction? number
function World:shakeCamera(x, y, friction)
    self.camera:shake(x, y, friction)
end

---@param a Object
---@param b Object
---@param positions table<Object, {x: number, y: number}>
---@param player Object?
---@return boolean
local function compareWorldChildren(a, b, positions, player)
    if a == b then return false end
    local a_pos, b_pos = positions[a], positions[b]
    local ay, by = a_pos.y, b_pos.y
    local a_map_layer, b_map_layer = a.map_layer == true, b.map_layer == true
    if a.layer == b.layer and a_map_layer ~= b_map_layer then
        return a_map_layer
    end
    if a.layer == b.layer and a_map_layer and b_map_layer then
        local a_id = a.map_layer_sort_id or ""
        local b_id = b.map_layer_sort_id or ""
        if a_id ~= b_id then return a_id < b_id end
        return false
    end
    if a.layer == b.layer and a.height_occlusion_proxy and b.height_occlusion_proxy
        and math.floor(ay) == math.floor(by) then
        local a_source_layer = a.source_draw_layer or 0
        local b_source_layer = b.source_draw_layer or 0
        if a_source_layer ~= b_source_layer then
            return a_source_layer < b_source_layer
        end
        local a_id = a.occlusion_sort_id or ""
        local b_id = b.occlusion_sort_id or ""
        if a_id ~= b_id then return a_id < b_id end
    end
    return a.layer < b.layer or
        (a.layer == b.layer and (math.floor(ay) < math.floor(by) or
            (math.floor(ay) == math.floor(by) and (b == player or
                (a:includes(Follower) and b:includes(Follower) and b.index < a.index)))))
end

function World:sortChildren()
    Object.startCache()
    local positions = {}
    for _, child in ipairs(self.children) do
        local x, y = child:getSortPosition()
        if child.height_occluder and not child.height_occlusion_proxy then
            local direction = child.height_face_direction or "front"
            local face_y = child.height_face_y
            if not face_y and self.map and child.surface_id then
                local surface = self.map:getSurface(child.surface_id)
                local bounds = surface
                    and (surface.support_bounds or surface.bounds)
                if bounds then
                    if direction == "front" then
                        face_y = bounds.max_y
                    elseif direction == "back" then
                        face_y = bounds.min_y
                    end
                end
            end
            y = (face_y or y) + (child.height_occlusion_sort_y_offset or 0)
        end
        positions[child] = { x = x, y = y }
    end
    local player = self.player
    table.stable_sort(self.children, function(a, b)
        return compareWorldChildren(a, b, positions, player)
    end)
    Object.endCache()
end

---@param parent Object
function World:onRemove(parent)
    super.onRemove(self, parent)

    self.music:remove()
end

--- Sets whether the player is currently in battle - cannot override being inside a battle area
---@param value boolean
function World:setBattle(value)
    self.in_battle = value
end

--- Whether the player is currently in a "world battle".
---@return boolean
function World:inBattle()
    if self.player and self.player:isClimbing() then
        return false
    end

    return self.in_battle or self.in_battle_area
end

--- Whether WorldBullets should hurt the player.
---@return boolean
function World:shouldBulletsHurt()
    if self.player and self.player:isClimbing() then
        return true
    end

    return self:inBattle()
end

--- Whether the world should decrease the invulnerability timer.
---
--- By default, this redirects to [`Player:shouldDecreaseInvuln()`](lua://Player.shouldDecreaseInvuln) if the player exists.
---@return boolean? decrease_invuln # `true` if the invulnerability timer should decrease.
function World:shouldDecreaseInvuln()
    return self.player ~= nil and self.player:shouldDecreaseInvuln()
end

function World:shouldCharacterCollide(char)
    if char.is_player and char:isClimbing() then
        return false
    end

    return true
end

function World:update()
    -- Moving height surfaces publish their new transform before characters run.
    -- This makes rider carrying and relative vertical sweeps deterministic and
    -- independent of the world's visual child sort order.
    if self.state == "GAMEPLAY" then
        for _, object in ipairs(self.children) do
            if object.is_moving_platform and object.active and object.preUpdateMotion then
                object:preUpdateMotion(DT)
            end
        end
    end

    if self.state == "GAMEPLAY" then
        -- Object collision
        local collided = {}
        local exited = {}
        Object.startCache()
        for _, obj in ipairs(self.children) do
            if not obj.solid and (obj.onCollide or obj.onEnter or obj.onExit) then
                for _, char in ipairs(self.stage:getObjects(Character)) do
                    local height_collision = obj.height_sensitive and char.use_3d_collision
                    local is_colliding
                    if height_collision then
                        is_colliding = obj:collidesWith3D(char)
                    else
                        is_colliding = obj:collidesWith(char)
                    end
                    if is_colliding and self:shouldCharacterCollide(char) then
                        if not obj:includes(OverworldSoul) then
                            table.insert(collided, { obj, char })
                        end
                    elseif obj.current_colliding and obj.current_colliding[char] then
                        table.insert(exited, { obj, char })
                    end
                end
            end
        end
        Object.endCache()
        for _, v in ipairs(collided) do
            if v[1].onCollide then
                v[1]:onCollide(v[2])
            end
            if not v[1].current_colliding then
                v[1].current_colliding = {}
            end
            if not v[1].current_colliding[v[2]] then
                if v[1].onEnter then
                    v[1]:onEnter(v[2])
                end
                v[1].current_colliding[v[2]] = true
            end
        end
        for _, v in ipairs(exited) do
            if v[1].onExit then
                v[1]:onExit(v[2])
            end
            v[1].current_colliding[v[2]] = nil
        end

        if (self.hum_timer > 0) then
            self.hum_timer = MathUtils.approach(self.hum_timer, 0, DT)
            if (self.hum_timer == 0) then
                self:startHumming()
            end
        end
    end

    if self:inBattle() then
        self.battle_alpha = math.min(self.battle_alpha + (0.08 * DTMULT), 1)
    else
        self.battle_alpha = math.max(self.battle_alpha - (0.08 * DTMULT), 0)
    end

    local half_alpha = self.battle_alpha * 0.52

    for _, v in ipairs(self.followers) do
        v.sprite:setColor(1 - half_alpha, 1 - half_alpha, 1 - half_alpha)
    end

    for _, battle_border in ipairs(self.map.battle_borders) do
        battle_border.alpha = self.battle_alpha
    end
    if self.battle_fader then
        self.battle_fader:setColor(0, 0, 0, half_alpha)
    end

    if (self.door_delay > 0) then
        self.door_delay = math.max(self.door_delay - DT, 0)
    end

    self.map:update()

    -- Always sort
    self.update_child_list = true
    super.update(self)

    -- Update cutscene after updating objects
    if self.cutscene then
        if not self.cutscene.ended then
            self.cutscene:update()
            if self.stage == nil then
                return
            end
        else
            self.cutscene = nil
        end
    end

    local height_occluders = self.map and self.map.height_occluders
    if height_occluders and height_occluders[1]
        and height_occluders[1].updateSharedCutoutAnimation then
        height_occluders[1]:updateSharedCutoutAnimation(DT)
    end
end

--- Whether this map should use the depth buffer
---@return boolean
function World:usesHeightDepthRenderer()
    return self.map and self.map.platforming
        and Kristal.Shaders and Kristal.Shaders["HeightDepth"] ~= nil
        and love.graphics.setDepthMode ~= nil
end

---@param child Object
---@return boolean
function World:isHeightDepthChild(child)
    if child.height_occlusion_proxy then
        return (child.face_direction or "front") == "front"
    end
    return child.height_sort_subject == true
        and (child.use_3d_collision == true or child.height_depth_subject == true)
end

---@param child Object
---@return boolean
function World:isHeightDepthTransparent(child)
    if child.height_depth_transparent then return true end
    if child.blend_mode and child.blend_mode ~= "normal"
        and child.blend_mode ~= "alpha" then return true end
    local _, _, _, alpha = child:getDrawColor()
    if alpha < 0.999 then return true end
    if child.height_occlusion_proxy and child.resolveSourceLayer then
        local source = child:resolveSourceLayer()
        if source then
            local _, _, _, source_alpha = source:getDrawColor()
            if source_alpha < 0.999 then return true end
        end
    end
    return false
end

---@param child Object
---@param mode? "opaque"|"cutout"
---@return love.Canvas
function World:captureHeightDepthChild(child, mode)
    local old_r, old_g, old_b, old_a = love.graphics.getColor()
    local old_blend, old_alpha_mode = love.graphics.getBlendMode()
    love.graphics.setBlendMode("alpha", "alphamultiply")
    local canvas = Draw.pushCanvas(SCREEN_WIDTH, SCREEN_HEIGHT, {
        keep_transform = true
    })
    local old_capturing = self._capturing_height_depth
    local old_mode = self._height_depth_capture_mode
    self._capturing_height_depth = true
    self._height_depth_capture_mode = mode or "opaque"
    child:fullDraw()
    self._capturing_height_depth = old_capturing
    self._height_depth_capture_mode = old_mode
    Draw.popCanvas(true)
    love.graphics.setBlendMode(old_blend, old_alpha_mode)
    love.graphics.setColor(old_r, old_g, old_b, old_a)
    return canvas
end

--- Builds screenspace uniforms for the depth shader.
---@param child Object
---@return table parameters
function World:getHeightDepthParameters(child)
    local sort_x, sort_y = child:getSortPosition()
    local depth_offset = tonumber(child.height_depth_offset) or 0
    local transform =
        HeightTransform.fromLoveTransform(love.graphics.getTransform())
    local function applySortOffset(parameters)
        parameters.sort_depth = parameters.sort_depth
            + (tonumber(child.height_depth_sort_offset) or 0)
        return parameters
    end
    if child.height_depth_plane then
        return applySortOffset(transform:getDepthParameters({
            anchor_x = sort_x,
            anchor_y = sort_y,
            horizontal_z = child:getFullHeightTransform():getZ(),
            depth_offset = depth_offset
        }))
    end
    if child.height_occlusion_proxy and child.getOcclusionZBounds then
        local _, top = child:getOcclusionZBounds()
        local face_y = child.face_position or sort_y
        local face_x = child.sort_x or sort_x
        return applySortOffset(transform:getDepthParameters({
            anchor_x = sort_x,
            anchor_y = sort_y,
            depth_offset = depth_offset,
            face_x = face_x,
            face_y = face_y,
            face_top_z = top
        }))
    end
    return applySortOffset(transform:getDepthParameters({
        anchor_x = sort_x,
        anchor_y = sort_y,
        z = child:getFullHeightTransform():getZ(),
        depth_offset = depth_offset
    }))
end

---@param canvas love.Canvas
---@param parameters table
---@param write_depth boolean
function World:compositeHeightDepthCanvas(canvas, parameters, write_depth)
    local old_comparison, old_write = love.graphics.getDepthMode()
    local old_blend, old_alpha_mode = love.graphics.getBlendMode()
    local old_r, old_g, old_b, old_a = love.graphics.getColor()
    love.graphics.setDepthMode("gequal", write_depth)
    love.graphics.setBlendMode("alpha", "alphamultiply")
    love.graphics.push()
    love.graphics.origin()
    Draw.setColor(1, 1, 1)
    Draw.pushShader("HeightDepth", {
        depth_mode = parameters.depth_mode,
        anchor_y = parameters.anchor_y,
        face_ground_y = parameters.face_ground_y,
        face_top_y = parameters.face_top_y,
        height_pixels = parameters.height_pixels,
        depth_scale = parameters.depth_scale,
        depth_bias = parameters.depth_bias,
        alpha_threshold = parameters.alpha_threshold
    })
    Draw.drawCanvas(canvas)
    Draw.popShader()
    love.graphics.pop()
    love.graphics.setColor(old_r, old_g, old_b, old_a)
    love.graphics.setBlendMode(old_blend, old_alpha_mode)
    if old_comparison then
        love.graphics.setDepthMode(old_comparison, old_write)
    else
        love.graphics.setDepthMode()
    end
end

---@param child Object
function World:drawOrdinaryChild(child)
    local old_blend, old_alpha_mode
    if child.blend_mode and child.blend_mode ~= "normal" then
        old_blend, old_alpha_mode = love.graphics.getBlendMode()
        love.graphics.setBlendMode(child.blend_mode)
    end
    child:fullDraw()
    if old_blend then
        love.graphics.setBlendMode(old_blend, old_alpha_mode)
    end
end

--- Draws height-managed sprites and terrain through the depth buffer
function World:drawHeightDepthChildren(min_layer, max_layer)
    love.graphics.setDepthMode()
    love.graphics.clear(false, false, 0)
    self._height_depth_renderer_active = true
    local transparent = {}
    local last_depth_index
    for index, child in ipairs(self.children) do
        if child.visible
            and (not min_layer or child.layer >= min_layer)
            and (not max_layer or child.layer < max_layer)
            and self:isHeightDepthChild(child) then
            last_depth_index = index
        end
    end

    local function drawTransparent()
        table.stable_sort(transparent, function(a, b)
            return a.parameters.sort_depth < b.parameters.sort_depth
        end)
        for _, item in ipairs(transparent) do
            self:compositeHeightDepthCanvas(item.canvas, item.parameters, false)
            Draw.unlockCanvas(item.canvas)
        end
        transparent = {}
    end

    for index, child in ipairs(self.children) do
        if child.visible
            and (not min_layer or child.layer >= min_layer)
            and (not max_layer or child.layer < max_layer) then
            if self:isHeightDepthChild(child) then
                local parameters = self:getHeightDepthParameters(child)
                local canvas = self:captureHeightDepthChild(child, "opaque")
                if self:isHeightDepthTransparent(child) then
                    table.insert(transparent, {
                        canvas = canvas,
                        parameters = parameters
                    })
                else
                    self:compositeHeightDepthCanvas(canvas, parameters, true)
                    Draw.unlockCanvas(canvas)
                end

                if child.height_occlusion_proxy
                    and child.hasCharacterDepthCutout
                    and child:hasCharacterDepthCutout() then
                    local cutout = self:captureHeightDepthChild(child, "cutout")
                    table.insert(transparent, {
                        canvas = cutout,
                        parameters = parameters
                    })
                end
            else
                self:drawOrdinaryChild(child)
            end
        end
        if index == last_depth_index then drawTransparent() end
    end

    if #transparent > 0 then drawTransparent() end
    love.graphics.setDepthMode()
    self._height_depth_renderer_active = false
end

function World:drawChildren(min_layer, max_layer)
    if not self:usesHeightDepthRenderer() then
        return super.drawChildren(self, min_layer, max_layer)
    end
    if self.update_child_list then
        self:updateChildList()
        self.update_child_list = false
    end
    if self._dont_draw_children then return end

    local old_r, old_g, old_b, old_a = love.graphics.getColor()
    self:drawHeightDepthChildren(min_layer, max_layer)
    love.graphics.setColor(old_r, old_g, old_b, old_a)
end

function World:draw()
    self.height_occlusion_draw_frame = (self.height_occlusion_draw_frame or 0) + 1

    if self.update_child_list then
        self:updateChildList()
        self.update_child_list = false
    else
        self:sortChildren()
    end

    -- Draw background
    Draw.setColor(self.map.bg_color or { 0, 0, 0, 0 })
    love.graphics.rectangle("fill", 0, 0, self.map.width * self.map.tile_width, self.map.height * self.map.tile_height)
    Draw.setColor(1, 1, 1)

    super.draw(self)

    self.map:draw()

    self:drawPitRecoveryOverlay()

    if DEBUG_RENDER then
        for _, collision in ipairs(self.map.collision) do
            collision:draw(0, 0, 1, 0.5)
        end
        for _, collision in ipairs(self.map.enemy_collision) do
            collision:draw(0, 1, 1, 0.5)
        end
        for _, pit in ipairs(self.map.pits or {}) do
            pit:draw(1, 0.25, 0.25, 0.65)
        end
    end
end

---i love that i have to do this
function World:drawPitRecoveryOverlay()
    local player = self.player
    if not player or not player.isPitRecovering or not player:isPitRecovering() then
        return
    end

    local old_r, old_g, old_b, old_a = love.graphics.getColor()
    local old_blend, old_alpha_mode = love.graphics.getBlendMode()
    local old_depth_comparison, old_depth_write = love.graphics.getDepthMode()

    love.graphics.push()
    love.graphics.origin()
    love.graphics.setDepthMode()
    love.graphics.setBlendMode("alpha", "alphamultiply")
    Draw.setColor(1, 1, 1, 1)
    Draw.pushShader("goner_bleed_cover", {
        progress = MathUtils.clamp(player.pit_recovery_progress or 0, 0, 1),
        time = Kristal.getTime(),
        screen_size = { SCREEN_WIDTH, SCREEN_HEIGHT }
    })
    love.graphics.rectangle("fill", 0, 0, SCREEN_WIDTH, SCREEN_HEIGHT)
    Draw.popShader()
    love.graphics.pop()

    if old_depth_comparison then
        love.graphics.setDepthMode(old_depth_comparison, old_depth_write)
    else
        love.graphics.setDepthMode()
    end
    love.graphics.setBlendMode(old_blend, old_alpha_mode)
    love.graphics.setColor(old_r, old_g, old_b, old_a)
end

function World:canDeepCopy()
    return false
end

return World
