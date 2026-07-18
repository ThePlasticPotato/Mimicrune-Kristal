---@class LightFlashBackdrop : Object
local LightFlashBackdrop, backdrop_super = Class(Object)

function LightFlashBackdrop:init(emitter, layer)
    backdrop_super.init(self, 0, 0, SCREEN_WIDTH, SCREEN_HEIGHT)

    self.emitter = emitter
    self.layer = layer
    self.parallax_x = 0
    self.parallax_y = 0
    self.debug_select = false
end

function LightFlashBackdrop:update()
    backdrop_super.update(self)

    if not self.emitter.stage then
        self:remove()
    end
end

function LightFlashBackdrop:draw()
    local emitter = self.emitter
    local strength = emitter:getVisualStrength()
    local alpha = MathUtils.clamp(strength * emitter.backdrop_alpha, 0, emitter.backdrop_max_alpha)
    if alpha <= 0 then return end

    love.graphics.push("all")
    love.graphics.origin()
    Draw.setColor(0, 0, 0, alpha)
    love.graphics.rectangle("fill", 0, 0, SCREEN_WIDTH, SCREEN_HEIGHT)
    love.graphics.pop()
end

---@class LightFlashOverlay : Object
local LightFlashOverlay, overlay_super = Class(Object)

function LightFlashOverlay:init(emitter, layer)
    overlay_super.init(self, 0, 0, SCREEN_WIDTH, SCREEN_HEIGHT)

    self.emitter = emitter
    self.layer = layer
    self.parallax_x = 0
    self.parallax_y = 0
    self.debug_select = false
end

function LightFlashOverlay:update()
    overlay_super.update(self)

    if not self.emitter.stage then
        self:remove()
    end
end

function LightFlashOverlay:draw()
    local emitter = self.emitter
    local strength = emitter:getVisualStrength()
    if strength <= 0 then return end

    local color = emitter.color
    local color_alpha = color[4] or 1
    local source_x, source_y = emitter:getScreenPosition()

    emitter:drawOccludedPass(function()
        local wash_alpha = MathUtils.clamp(strength * emitter.wash_alpha * color_alpha, 0, 0.85)
        if wash_alpha > 0 then
            love.graphics.setBlendMode("alpha")
            Draw.setColor(color[1], color[2], color[3], wash_alpha)
            love.graphics.rectangle("fill", 0, 0, SCREEN_WIDTH, SCREEN_HEIGHT)
        end

        local glow_alpha = MathUtils.clamp(strength * emitter.overlay_glow_alpha * color_alpha, 0, 1)
        if glow_alpha > 0 then
            love.graphics.setBlendMode("add")
            Draw.setColor(color[1], color[2], color[3], glow_alpha)
            love.graphics.draw(emitter.glow_mesh, emitter:snapToPixel(source_x), emitter:snapToPixel(source_y), 0,
                emitter:snapToPixel(emitter.overlay_glow_radius), emitter:snapToPixel(emitter.overlay_glow_radius))
        end
    end)
end

local function createGlowMesh(segments)
    local rings = {
        {0,    0.12, 1},
        {0.12, 0.28, 0.58},
        {0.28, 0.5,  0.3},
        {0.5,  0.75, 0.14},
        {0.75, 1,    0.05}
    }
    local vertices = {}

    local function vertex(radius, angle, alpha)
        local x = math.cos(angle) * radius
        local y = math.sin(angle) * radius
        return {x, y, (x + 1) / 2, (y + 1) / 2, 1, 1, 1, alpha}
    end

    for _, ring in ipairs(rings) do
        for index = 0, segments - 1 do
            local angle_1 = (index / segments) * math.pi * 2
            local angle_2 = ((index + 1) / segments) * math.pi * 2

            table.insert(vertices, vertex(ring[1], angle_1, ring[3]))
            table.insert(vertices, vertex(ring[2], angle_1, ring[3]))
            table.insert(vertices, vertex(ring[2], angle_2, ring[3]))

            table.insert(vertices, vertex(ring[1], angle_1, ring[3]))
            table.insert(vertices, vertex(ring[2], angle_2, ring[3]))
            table.insert(vertices, vertex(ring[1], angle_2, ring[3]))
        end
    end

    return love.graphics.newMesh(vertices, "triangles", "static")
end

local function createRayMesh()
    local bands = {
        {0.02, 0.12, 0.35},
        {0.12, 0.32, 1},
        {0.32, 0.58, 0.72},
        {0.58, 0.8,  0.42},
        {0.8,  1,    0.18}
    }
    local vertices = {}

    local function vertex(x, side, alpha)
        local width = 0.08 + (x * 0.92)
        local y = side * width * 0.5
        return {x, y, x, y + 0.5, 1, 1, 1, alpha}
    end

    for _, band in ipairs(bands) do
        table.insert(vertices, vertex(band[1], -1, band[3]))
        table.insert(vertices, vertex(band[2], -1, band[3]))
        table.insert(vertices, vertex(band[2], 1, band[3]))

        table.insert(vertices, vertex(band[1], -1, band[3]))
        table.insert(vertices, vertex(band[2], 1, band[3]))
        table.insert(vertices, vertex(band[1], 1, band[3]))
    end

    return love.graphics.newMesh(vertices, "triangles", "static")
end

---@class LightFlash : Object
---@overload fun(x?: number, y?: number, options?: table) : LightFlash
local LightFlash, super = Class(Object)

-- A receiver can belong to more than one light. Keep one shared state per
-- receiver so an inactive emitter cannot overwrite an active emitter.
local receiver_light_states = setmetatable({}, {__mode = "k"})

---@param x? number Screen-space light source x coordinate.
---@param y? number Screen-space light source y coordinate.
---@param options? table
function LightFlash:init(x, y, options)
    options = options or {}
    super.init(self, x or SCREEN_WIDTH / 2, y or SCREEN_HEIGHT / 2)

    self.parallax_x = 0
    self.parallax_y = 0
    self.debug_select = false

    self.color = options.color or {1, 1, 1, 1}
    self.strength = math.max(0, options.strength or options.resting_strength or 0)
    self.resting_strength = math.max(0, options.resting_strength or 0)

    self.direction = options.direction or math.pi / 2
    self.spread = options.spread or math.pi * 0.8
    self.ray_count = math.max(1, math.floor(options.ray_count or 9))
    self.ray_length = options.ray_length or math.max(SCREEN_WIDTH, SCREEN_HEIGHT) * 1.75
    self.ray_width = options.ray_width or 110
    self.ray_alpha = options.ray_alpha or 0.16
    self.ray_drift = options.ray_drift or 0.025

    self.pixel_size = math.max(1, math.floor(options.pixel_size or 3))
    self.intensity_steps = math.max(1, math.floor(options.intensity_steps or 6))
    self.motion_fps = math.max(1, options.motion_fps or 12)
    self.angle_step = math.rad(options.angle_step or 1.5)

    self.glow_radius = options.glow_radius or 150
    self.glow_alpha = options.glow_alpha or 0.3
    self.core_radius = math.max(0, options.core_radius or 0)
    self.core_alpha = math.max(0, options.core_alpha or 1)
    self.overlay_glow_radius = options.overlay_glow_radius or self.glow_radius * 0.65
    self.overlay_glow_alpha = options.overlay_glow_alpha or 0.16
    self.wash_alpha = options.wash_alpha or 0.22
    self.backdrop_alpha = options.backdrop_alpha or 0
    self.backdrop_max_alpha = options.backdrop_max_alpha or 0.8

    self.layer = options.ray_layer or WORLD_LAYERS["above_events"]
    self.backdrop_layer = options.backdrop_layer or self.layer - 0.01
    self.overlay_layer = options.overlay_layer or WORLD_LAYERS["below_ui"]

    self.ray_mesh = createRayMesh()
    self.glow_mesh = createGlowMesh(math.max(6, math.floor(options.glow_segments or 16)))
    self.light_canvas = love.graphics.newCanvas(SCREEN_WIDTH, SCREEN_HEIGHT)
    self.rays = {}
    self.receivers = {}
    self.occluders = {}
    self.shadow_length = options.shadow_length or math.max(SCREEN_WIDTH, SCREEN_HEIGHT) * 4
    self.runtime = 0
    self.burst_state = nil
    self.follow_target = nil
    self.follow_local_x = 0
    self.follow_local_y = 0

    local full_circle = self.spread >= (math.pi * 2) - 0.0001
    for index = 1, self.ray_count do
        local position
        if self.ray_count == 1 then
            position = 0
        elseif full_circle then
            position = ((index - 1) / self.ray_count) - 0.5
        else
            position = ((index - 1) / (self.ray_count - 1)) - 0.5
        end
        table.insert(self.rays, {
            position = position,
            jitter = MathUtils.random(-0.3, 0.3),
            length = MathUtils.random(0.8, 1.2),
            width = MathUtils.random(0.65, 1.35),
            alpha = MathUtils.random(0.65, 1),
            phase = MathUtils.random(0, math.pi * 2),
            speed = MathUtils.random(0.35, 0.8)
        })
    end

    self.backdrop = LightFlashBackdrop(self, self.backdrop_layer)
    self.overlay = LightFlashOverlay(self, self.overlay_layer)
end

function LightFlash:onAdd(parent)
    if not self.backdrop.parent then
        parent:addChild(self.backdrop)
    end
    if not self.overlay.parent then
        parent:addChild(self.overlay)
    end
end

function LightFlash:onRemoveFromStage(stage)
    if self.backdrop.parent then
        self.backdrop:remove()
    end
    if self.overlay.parent then
        self.overlay:remove()
    end

    for index = #self.receivers, 1, -1 do
        local entry = self.receivers[index]
        if entry.occludes then self:removeOccluder(entry.receiver) end
        self:detachReceiverEntry(entry, true)
        table.remove(self.receivers, index)
    end
end

function LightFlash:setPosition(x, y)
    self.x = x or self.x
    self.y = y or self.y
end

--- Makes this light use a point on another object as its screen-space origin.
---@param target Object
---@param local_x? number|fun(target: Object): number
---@param local_y? number|fun(target: Object): number
function LightFlash:setFollowTarget(target, local_x, local_y)
    self.follow_target = target
    self.follow_local_x = local_x or 0
    self.follow_local_y = local_y or 0
end

function LightFlash:clearFollowTarget()
    local screen_x, screen_y = self:getScreenPosition()
    self.follow_target = nil
    self:setPosition(screen_x, screen_y)
end

function LightFlash:getScreenPosition()
    if self.follow_target and not self.follow_target:isRemoved() then
        local local_x = type(self.follow_local_x) == "function"
            and self.follow_local_x(self.follow_target) or self.follow_local_x
        local local_y = type(self.follow_local_y) == "function"
            and self.follow_local_y(self.follow_target) or self.follow_local_y
        return self.follow_target:localToScreenPos(local_x, local_y)
    end
    return self:localToScreenPos(0, 0)
end

function LightFlash:snapToPixel(value)
    return math.floor((value / self.pixel_size) + 0.5) * self.pixel_size
end

function LightFlash:getVisualStrength(strength)
    strength = math.max(0, strength or self.strength)
    return math.floor((strength * self.intensity_steps) + 0.5) / self.intensity_steps
end

function LightFlash:getOccluderPoints(entry)
    local object = entry.object
    if object.getLightOccluderPoints then
        return object:getLightOccluderPoints(self)
    end

    local rect = object:getDebugRectangle() or {0, 0, object.width, object.height}
    local padding = entry.padding or 0
    local left = rect[1] - padding
    local top = rect[2] - padding
    local right = rect[1] + rect[3] + padding
    local bottom = rect[2] + rect[4] + padding
    local points = {
        {object:localToScreenPos(left, top)},
        {object:localToScreenPos(right, top)},
        {object:localToScreenPos(right, bottom)},
        {object:localToScreenPos(left, bottom)}
    }

    local source_x, source_y = self:getScreenPosition()
    local local_x, local_y = object:screenToLocalPos(source_x, source_y)
    if local_x >= left and local_x <= right and local_y >= top and local_y <= bottom then
        return nil
    end
    return points
end

function LightFlash:drawOccluderShadow(entry, draw_origin_x, draw_origin_y)
    local points = self:getOccluderPoints(entry)
    if not points or #points < 2 then return end
    local source_x, source_y = self:getScreenPosition()

    local center_x, center_y = 0, 0
    for _, point in ipairs(points) do
        center_x = center_x + point[1]
        center_y = center_y + point[2]
    end
    center_x = center_x / #points
    center_y = center_y / #points

    local center_angle = MathUtils.angle(source_x, source_y, center_x, center_y)
    local minimum_delta = math.huge
    local maximum_delta = -math.huge
    local minimum_point
    local maximum_point

    for _, point in ipairs(points) do
        local angle = MathUtils.angle(source_x, source_y, point[1], point[2])
        local delta = MathUtils.angleDiff(angle, center_angle)
        if delta < minimum_delta then
            minimum_delta = delta
            minimum_point = point
        end
        if delta > maximum_delta then
            maximum_delta = delta
            maximum_point = point
        end
    end

    if not minimum_point or not maximum_point then return end

    local shadow_dx = center_x - source_x
    local shadow_dy = center_y - source_y
    local shadow_distance = math.sqrt((shadow_dx * shadow_dx) + (shadow_dy * shadow_dy))
    if shadow_distance <= 0 then return end
    shadow_dx = (shadow_dx / shadow_distance) * self.shadow_length
    shadow_dy = (shadow_dy / shadow_distance) * self.shadow_length

    local edge_dx = maximum_point[1] - minimum_point[1]
    local edge_dy = maximum_point[2] - minimum_point[2]
    if edge_dx * shadow_dy - edge_dy * shadow_dx < 0 then
        minimum_point, maximum_point = maximum_point, minimum_point
    end

    local far_min_x = minimum_point[1] + shadow_dx
    local far_min_y = minimum_point[2] + shadow_dy
    local far_max_x = maximum_point[1] + shadow_dx
    local far_max_y = maximum_point[2] + shadow_dy
    local function x(value) return self:snapToPixel(value) - draw_origin_x end
    local function y(value) return self:snapToPixel(value) - draw_origin_y end

    -- Sprite-aware occluders draw their real alpha mask. Generic objects
    -- continue to use the polygon supplied by getOccluderPoints.
    if entry.object.drawLightOccluderMask then
        entry.object:drawLightOccluderMask(self, draw_origin_x, draw_origin_y)
    else
        local silhouette = {}
        for _, point in ipairs(points) do
            table.insert(silhouette, x(point[1]))
            table.insert(silhouette, y(point[2]))
        end
        love.graphics.polygon("fill", silhouette)
    end

    love.graphics.polygon("fill",
        x(minimum_point[1]), y(minimum_point[2]),
        x(maximum_point[1]), y(maximum_point[2]),
        x(far_max_x), y(far_max_y),
        x(far_min_x), y(far_min_y))
end

function LightFlash:hasActiveOccluders()
    for _, entry in ipairs(self.occluders) do
        if entry.object.stage then return true end
    end
    return false
end

--- Draws a bright pass into a transparent canvas, subtracts every shadow
--- volume from it, then composites only the remaining light onto the scene.
function LightFlash:drawOccludedPass(draw_light)
    love.graphics.push("all")
    Draw.pushCanvas(self.light_canvas, {clear = true})

    love.graphics.setBlendMode("alpha")
    draw_light()

    if self:hasActiveOccluders() then
        love.graphics.setBlendMode("subtract")
        Draw.setColor(1, 1, 1, 1)
        for _, entry in ipairs(self.occluders) do
            if entry.object.stage then
                self:drawOccluderShadow(entry, 0, 0)
            end
        end
    end

    Draw.popCanvas(true)

    love.graphics.origin()
    love.graphics.setBlendMode("add")
    Draw.setColor(1, 1, 1, 1)
    Draw.drawCanvas(self.light_canvas)
    Draw.unlockCanvas(self.light_canvas)
    love.graphics.pop()
end

--- Registers an object whose bounds cast a shadow away from this light.
function LightFlash:addOccluder(object, padding)
    assert(object.localToScreenPos and object.screenToLocalPos,
        "LightFlash occluder must be an Object with screen-space transforms")

    for _, entry in ipairs(self.occluders) do
        if entry.object == object then
            entry.padding = padding or entry.padding
            return object
        end
    end

    table.insert(self.occluders, {object = object, padding = padding or 0})
    return object
end

function LightFlash:removeOccluder(object)
    for index = #self.occluders, 1, -1 do
        if self.occluders[index].object == object then
            table.remove(self.occluders, index)
        end
    end
end

function LightFlash:setStrength(strength)
    self.strength = math.max(0, strength or 0)
    self.burst_state = nil
    self:updateReceivers()
end

function LightFlash:setRestingStrength(strength, apply_immediately)
    self.resting_strength = math.max(0, strength or 0)
    if apply_immediately then
        self:setStrength(self.resting_strength)
    end
end

--- Keeps the complete lighting effect active until stopGlow is called.
---@param strength? number
---@param fade_time? number
function LightFlash:startGlow(strength, fade_time)
    local target = math.max(0, strength or 1)
    self.resting_strength = target

    if fade_time and fade_time > 0 then
        self:burst({
            strength = target,
            attack = fade_time,
            hold = 0,
            decay = 0,
            resting_strength = target
        })
    else
        self:setStrength(target)
    end
end

--- Turns off a persistent glow, optionally fading every lighting component together.
---@param fade_time? number
function LightFlash:stopGlow(fade_time)
    self.resting_strength = 0

    if fade_time and fade_time > 0 then
        self:burst({
            strength = 0,
            attack = fade_time,
            hold = 0,
            decay = 0,
            resting_strength = 0
        })
    else
        self:setStrength(0)
    end
end

function LightFlash:setReceiverStrength(receiver, value)
    if receiver.setOutlineLightStrength then
        receiver:setOutlineLightStrength(value)
    else
        receiver:setLightStrength(value)
    end
end

function LightFlash:getReceiverLightState(receiver)
    if receiver.getOutlineLightState then
        return receiver:getOutlineLightState()
    end

    local source = receiver.getLightSource and receiver:getLightSource() or nil
    local direction = receiver.getConfiguredLightDirection
        and receiver:getConfiguredLightDirection() or -math.pi / 2
    return source, direction
end

function LightFlash:setReceiverLightSource(receiver, source, direction)
    if source then
        if receiver.setOutlineLightSource then
            receiver:setOutlineLightSource(source)
        else
            receiver:setLightSource(source)
        end
    elseif receiver.setOutlineLightDirection then
        receiver:setOutlineLightDirection(direction)
    else
        receiver:setLightDirection(direction)
    end
end

function LightFlash:getReceiverColor(receiver)
    if receiver.getOutlineColor then
        return {receiver:getOutlineColor()}
    elseif receiver.getHighlight then
        return {receiver:getHighlight()}
    end

    return {1, 1, 1, 1}
end

function LightFlash:setReceiverColor(receiver, color)
    if receiver.setOutlineColor then
        receiver:setOutlineColor(color)
    elseif receiver.setHighlight then
        receiver:setHighlight(unpack(color))
    end
end

function LightFlash:updateSharedReceiver(entry, strength)
    -- Receiver highlights fade continuously even though the large rays use
    -- deliberately stepped intensity for their pixel-art look.
    entry.visual_strength = math.max(0, strength or self.strength) * entry.multiplier

    local state = entry.shared_state
    local receiver = entry.receiver
    local primary
    local total_strength = 0
    local light_r, light_g, light_b, light_a = 0, 0, 0, 0

    for candidate in pairs(state.entries) do
        local candidate_strength = candidate.visual_strength or 0
        if candidate_strength > 0 then
            local color = candidate.emitter.color
            total_strength = total_strength + candidate_strength
            light_r = light_r + color[1] * candidate_strength
            light_g = light_g + color[2] * candidate_strength
            light_b = light_b + color[3] * candidate_strength
            light_a = light_a + (color[4] or 1) * candidate_strength

            if not primary or candidate_strength > primary.visual_strength then
                primary = candidate
            end
        end
    end

    if not primary then
        self:setReceiverLightSource(receiver, state.base_light_source, state.base_light_direction)
        self:setReceiverColor(receiver, state.base_color)
        self:setReceiverStrength(receiver, 0)
        return
    end

    self:setReceiverLightSource(receiver, primary.emitter)

    local amount = MathUtils.clamp(total_strength, 0, 1)
    local base = state.base_color
    local color = {
        MathUtils.lerp(base[1], light_r / total_strength, amount),
        MathUtils.lerp(base[2], light_g / total_strength, amount),
        MathUtils.lerp(base[3], light_b / total_strength, amount),
        MathUtils.lerp(base[4] or 1, light_a / total_strength, amount)
    }
    self:setReceiverColor(receiver, color)
    self:setReceiverStrength(receiver, total_strength)
end

function LightFlash:detachReceiverEntry(entry, restore)
    local state = entry.shared_state
    state.entries[entry] = nil

    if restore ~= false then
        entry.visual_strength = 0
        self:updateSharedReceiver(entry, 0)
    end

    if not next(state.entries) then
        receiver_light_states[entry.receiver] = nil
    end
end

function LightFlash:setLightColor(r, g, b, a)
    if type(r) == "table" then
        self.color = r
    else
        self.color = {r, g, b, a or 1}
    end

    for _, entry in ipairs(self.receivers) do
        self:updateSharedReceiver(entry, self.strength)
    end
end

function LightFlash:updateReceivers()
    for index = #self.receivers, 1, -1 do
        local entry = self.receivers[index]
        local receiver = entry.receiver

        if receiver.isRemoved and receiver:isRemoved() then
            self:detachReceiverEntry(entry, false)
            table.remove(self.receivers, index)
        else
            self:updateSharedReceiver(entry, self.strength)
        end
    end
end

--- Registers a DeviceObject or HighlightFX to follow this light's position and strength.
function LightFlash:addReceiver(receiver, multiplier, occludes)
    assert(receiver.setOutlineLightSource or receiver.setLightSource,
        "LightFlash receiver must provide setOutlineLightSource or setLightSource")
    assert(receiver.setOutlineLightStrength or receiver.setLightStrength,
        "LightFlash receiver must provide setOutlineLightStrength or setLightStrength")

    for _, entry in ipairs(self.receivers) do
        if entry.receiver == receiver then
            entry.multiplier = multiplier or 1
            local should_occlude = occludes == true and receiver.localToScreenPos ~= nil
            if should_occlude and not entry.occludes then
                self:addOccluder(receiver)
            elseif entry.occludes and not should_occlude then
                self:removeOccluder(receiver)
            end
            entry.occludes = should_occlude
            self:updateSharedReceiver(entry, self.strength)
            return receiver
        end
    end

    local shared_state = receiver_light_states[receiver]
    if not shared_state then
        local base_light_source, base_light_direction = self:getReceiverLightState(receiver)
        shared_state = {
            base_color = self:getReceiverColor(receiver),
            base_light_source = base_light_source,
            base_light_direction = base_light_direction,
            entries = {}
        }
        receiver_light_states[receiver] = shared_state
    end

    local entry = {
        receiver = receiver,
        emitter = self,
        multiplier = multiplier or 1,
        shared_state = shared_state,
        visual_strength = 0,
        occludes = occludes == true and receiver.localToScreenPos ~= nil
    }
    shared_state.entries[entry] = true
    table.insert(self.receivers, entry)
    if entry.occludes then self:addOccluder(receiver) end
    self:updateSharedReceiver(entry, self.strength)
    return receiver
end

function LightFlash:removeReceiver(receiver, reset_strength)
    for index = #self.receivers, 1, -1 do
        local entry = self.receivers[index]
        if entry.receiver == receiver then
            if entry.occludes then self:removeOccluder(receiver) end
            self:detachReceiverEntry(entry, reset_strength)
            table.remove(self.receivers, index)
        end
    end
end

--- Starts a quick attack/hold/decay flash.
---@param options? table
function LightFlash:burst(options)
    options = options or {}

    local peak = math.max(0, options.strength or options.peak or 1)
    self.burst_state = {
        time = 0,
        start = self.strength,
        peak = peak,
        attack = math.max(0, options.attack or 0.04),
        hold = math.max(0, options.hold or 0.03),
        decay = math.max(0, options.decay or 0.3),
        resting = math.max(0, options.resting_strength or self.resting_strength),
        after = options.after
    }

    local shake = options.shake
    if shake and Game.world and Game.world.camera then
        if type(shake) == "table" then
            Game.world.camera:shake(shake.x or 2, shake.y or shake.x or 2, shake.friction or 1)
        else
            Game.world.camera:shake(shake, shake, options.shake_friction or 1)
        end
    end
end

function LightFlash:updateBurst()
    local burst = self.burst_state
    if not burst then return end

    burst.time = burst.time + DT
    local time = burst.time

    if burst.attack > 0 and time < burst.attack then
        local progress = time / burst.attack
        local eased = 1 - ((1 - progress) ^ 3)
        self.strength = MathUtils.lerp(burst.start, burst.peak, eased)
        return
    end

    time = time - burst.attack
    if time < burst.hold then
        self.strength = burst.peak
        return
    end

    time = time - burst.hold
    if burst.decay > 0 and time < burst.decay then
        local progress = time / burst.decay
        local eased = (1 - progress) ^ 2
        self.strength = MathUtils.lerp(burst.resting, burst.peak, eased)
        return
    end

    self.strength = burst.resting
    self.burst_state = nil
    if burst.after then burst.after(self) end
end

function LightFlash:update()
    super.update(self)

    self.runtime = self.runtime + DT
    self:updateBurst()
    self:updateReceivers()
end

function LightFlash:draw()
    local strength = self:getVisualStrength()
    if strength <= 0 then return end

    local color = self.color
    local color_alpha = color[4] or 1
    local source_x, source_y = self:getScreenPosition()
    local snapped_source_x = self:snapToPixel(source_x)
    local snapped_source_y = self:snapToPixel(source_y)

    local stepped_runtime = math.floor(self.runtime * self.motion_fps) / self.motion_fps

    self:drawOccludedPass(function()
        love.graphics.setBlendMode("add")

        for _, ray in ipairs(self.rays) do
            local flicker = 0.92 + (math.sin(stepped_runtime * ray.speed * math.pi * 2 + ray.phase) * 0.08)
            local angle = self.direction
                + (ray.position * self.spread)
                + (ray.jitter * self.spread / self.ray_count)
                + (math.sin(stepped_runtime * ray.speed + ray.phase) * self.ray_drift)
            angle = math.floor((angle / self.angle_step) + 0.5) * self.angle_step
            local alpha = MathUtils.clamp(strength * self.ray_alpha * ray.alpha * flicker * color_alpha, 0, 1)

            Draw.setColor(color[1], color[2], color[3], alpha)
            love.graphics.draw(self.ray_mesh, snapped_source_x, snapped_source_y, angle,
                self:snapToPixel(self.ray_length * ray.length), self:snapToPixel(self.ray_width * ray.width))
        end

        local glow_alpha = MathUtils.clamp(strength * self.glow_alpha * color_alpha, 0, 1)
        Draw.setColor(color[1], color[2], color[3], glow_alpha)
        love.graphics.draw(self.glow_mesh, snapped_source_x, snapped_source_y, 0,
            self:snapToPixel(self.glow_radius), self:snapToPixel(self.glow_radius))

        if self.core_radius > 0 then
            local core_radius = math.max(self.pixel_size, self:snapToPixel(self.core_radius))
            local core_alpha = MathUtils.clamp(strength * self.core_alpha * color_alpha, 0, 1)
            Draw.setColor(color[1], color[2], color[3], core_alpha)
            love.graphics.rectangle(
                "fill",
                snapped_source_x - core_radius,
                snapped_source_y - core_radius,
                core_radius * 2,
                core_radius * 2
            )
        end
    end)
end

return LightFlash
