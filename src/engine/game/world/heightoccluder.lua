--- Re-renders a clipped region of a map tile/image layer at object depth.
---@class HeightOccluder : Object
---@field map Map
---@field mask_points number[][]
---@field source_layer_name string
---@field occlusion_z number
---@field occlusion_depth number
---@field surface_id string?
---@field face_direction "front"|"back"|"left"|"right"|"always"|"never"
---@field face_position number?
---@field face_bounds table?
---@field sort_x number
---@field sort_y number
---@field mask_sort_y number
---@field cutout_visibility number
---@field cutout_grow_time number
---@field cutout_shrink_time number
---@field cutout_wobble number
---@field cutout_wobble_speed number
---@overload fun(map: Map, data: table, layer: table, properties: table): HeightOccluder
local HeightOccluder, super = Class(Object)

local function transformPoint(x, y, origin_x, origin_y, cosine, sine)
    return origin_x + x * cosine - y * sine,
        origin_y + x * sine + y * cosine
end

local function getShapePoints(data, offset_x, offset_y)
    local shape = data.shape or "rectangle"
    local width, height = tonumber(data.width) or 0, tonumber(data.height) or 0
    local origin_x = (tonumber(data.x) or 0) + offset_x
    local origin_y = (tonumber(data.y) or 0) + offset_y
    local rotation = math.rad((tonumber(data.rotation) or 0) % 360)
    local cosine, sine = math.cos(rotation), math.sin(rotation)
    local source = {}

    if shape == "polygon" then
        source = data.polygon or data.shape_data and data.shape_data.points or {}
    elseif shape == "ellipse" then
        local radius_x, radius_y = width / 2, height / 2
        for index = 0, 31 do
            local angle = index / 32 * math.pi * 2
            table.insert(source, {
                radius_x + math.cos(angle) * radius_x,
                radius_y + math.sin(angle) * radius_y
            })
        end
    elseif shape == "rectangle" then
        source = {
            { 0, 0 }, { width, 0 }, { width, height }, { 0, height }
        }
    end

    local points = {}
    for _, point in ipairs(source) do
        local x, y = MapUtils.getPointCoordinates(point)
        x, y = transformPoint(x, y, origin_x, origin_y, cosine, sine)
        table.insert(points, { x, y })
    end
    return points
end

local function clipPointsToBoundary(points, coordinate, boundary, keep_less)
    if #points < 3 then return {} end
    local function isInside(value)
        if keep_less then return value <= boundary end
        return value >= boundary
    end
    local result = {}
    local previous = points[#points]
    local previous_value = previous[coordinate]
    local previous_inside = isInside(previous_value)
    for _, current in ipairs(points) do
        local current_value = current[coordinate]
        local current_inside = isInside(current_value)
        if current_inside ~= previous_inside then
            local denominator = current_value - previous_value
            local amount = denominator == 0 and 0
                or (boundary - previous_value) / denominator
            table.insert(result, {
                previous[1] + (current[1] - previous[1]) * amount,
                previous[2] + (current[2] - previous[2]) * amount
            })
        end
        if current_inside then table.insert(result, { current[1], current[2] }) end
        previous = current
        previous_value = current_value
        previous_inside = current_inside
    end
    return result
end

---@param map Map
---@param data table
---@param layer table
---@param properties table
function HeightOccluder:init(map, data, layer, properties)
    local points = getShapePoints(data, layer.offsetx or 0, layer.offsety or 0)
    super.init(self)

    self.map = map
    self.data = data
    self.mask_points = points
    self.source_layer_name = tostring(properties.source_layer or properties.visual_layer or "")
    local surface_id = properties.surface_id or properties.structure_id
    self.surface_id = surface_id ~= nil and tostring(surface_id) or nil
    local face_direction = tostring(properties.face_direction or properties.face or "front"):lower()
    if face_direction == "auto" then face_direction = "front" end
    if face_direction ~= "front" and face_direction ~= "back"
        and face_direction ~= "left" and face_direction ~= "right"
        and face_direction ~= "always" and face_direction ~= "never" then
        face_direction = "front"
    end
    self.face_direction = face_direction
    self.explicit_occlusion_z = properties.z ~= nil or properties.occlusion_z ~= nil
    self.explicit_occlusion_depth = properties.depth ~= nil
        or properties.occlusion_depth ~= nil
    self.occlusion_z = tonumber(properties.z or properties.occlusion_z) or 0
    self.occlusion_depth = math.max(
        tonumber(properties.depth or properties.occlusion_depth) or 0, 0
    )
    self.cutout_enabled = properties.cutout_enabled ~= false
        and properties.character_cutout ~= false
    self.cutout_radius = math.max(
        tonumber(properties.cutout_radius or properties.character_cutout_radius) or 32, 0
    )
    self.cutout_alpha = MathUtils.clamp(
        tonumber(properties.cutout_alpha or properties.character_cutout_alpha) or 0.3, 0, 1
    )
    self.cutout_feather = math.max(
        tonumber(properties.cutout_feather or properties.character_cutout_feather) or 6, 0
    )
    self.cutout_grow_time = math.max(
        tonumber(properties.cutout_grow_time) or 0.18, 0
    )
    self.cutout_shrink_time = math.max(
        tonumber(properties.cutout_shrink_time) or 0.22, 0
    )
    self.cutout_wobble = math.max(
        tonumber(properties.cutout_wobble) or 2, 0
    )
    self.cutout_wobble_speed =
        tonumber(properties.cutout_wobble_speed) or 2.5
    self.cutout_visibility = 0
    self.cutout_tween_start = 0
    self.cutout_tween_target = 0
    self.cutout_tween_timer = 0
    self.cutout_tween_duration = 0
    self.cutout_center_x = nil
    self.cutout_center_y = nil
    local cutout_seed_source = tostring(data.id or data.name or "")
    self.cutout_wobble_seed = 0
    for index = 1, #cutout_seed_source do
        self.cutout_wobble_seed = self.cutout_wobble_seed
            + cutout_seed_source:byte(index) * index
    end
    self.cutout_wobble_seed = self.cutout_wobble_seed * 0.137
    self.height_occluder = true
    self.height_occlusion_proxy = true
    self.debug_select = false
    self.source_layer = nil
    self.source_draw_layer = 0
    self.occlusion_sort_id = tostring(data.id or data.name or "")
    self.source_warning_shown = false
    self.surface_warning_shown = false
    self.linked_surface = nil
    self.occlusion_mask_points = nil
    self.face_position = nil
    self.face_bounds = nil
    self.explicit_face_position = false
    if face_direction == "front" or face_direction == "back" then
        if properties.face_y ~= nil or properties.depth_y ~= nil then
            self.face_position = tonumber(properties.face_y or properties.depth_y)
            self.explicit_face_position = self.face_position ~= nil
        end
    elseif face_direction == "left" or face_direction == "right" then
        if properties.face_x ~= nil or properties.depth_x ~= nil then
            self.face_position = tonumber(properties.face_x or properties.depth_x)
            self.explicit_face_position = self.face_position ~= nil
        end
    end
    self.sort_y_offset = tonumber(properties.sort_y_offset or properties.sort_offset_y) or 0

    local min_x, max_x, max_y = math.huge, -math.huge, -math.huge
    for _, point in ipairs(points) do
        min_x = math.min(min_x, point[1])
        max_x = math.max(max_x, point[1])
        max_y = math.max(max_y, point[2])
    end
    self.sort_x = #points > 0 and (min_x + max_x) / 2 or 0
    self.mask_sort_y = #points > 0 and max_y or 0
    self.sort_y = self.mask_sort_y + self.sort_y_offset
end

function HeightOccluder:getSortPosition()
    self:resolveSurface()
    return self.sort_x, self.sort_y
end

function HeightOccluder:getOcclusionZBounds()
    self:resolveSurface()
    return self.occlusion_z, self.occlusion_z + self.occlusion_depth
end

---@return table? surface
function HeightOccluder:resolveSurface()
    if self.linked_surface then return self.linked_surface end
    if not self.surface_id or self.surface_id == "" then return nil end
    local surface = self.map:getSurface(self.surface_id)
    if not surface then
        if not self.surface_warning_shown then
            self.surface_warning_shown = true
            Kristal.Console:warn(string.format(
                "Height occluder '%s' could not find surface '%s' on map '%s'",
                tostring(self.data.name or self.data.id or "?"),
                self.surface_id,
                tostring(self.map.id or self.map.name or "?")
            ))
        end
        return nil
    end

    self.linked_surface = surface
    if not self.explicit_occlusion_z then self.occlusion_z = surface.bottom end
    if not self.explicit_occlusion_depth then
        self.occlusion_depth = math.max(surface.top - surface.bottom, 0)
    end
    local face_bounds = surface.support_bounds or surface.bounds
    self.face_bounds = face_bounds
    if not self.explicit_face_position and face_bounds then
        if self.face_direction == "front" then
            self.face_position = face_bounds.max_y
        elseif self.face_direction == "back" then
            self.face_position = face_bounds.min_y
        elseif self.face_direction == "left" then
            self.face_position = face_bounds.min_x
        elseif self.face_direction == "right" then
            self.face_position = face_bounds.max_x
        end
    end
    if (self.face_direction == "front" or self.face_direction == "back")
        and self.face_position then
        self.sort_y = self.face_position + self.sort_y_offset
    end
    return surface
end

---@return number[][] points
function HeightOccluder:getOcclusionMaskPoints()
    self:resolveSurface()
    if self.occlusion_mask_points then return self.occlusion_mask_points end
    local points = self.mask_points
    local boundary = self.face_position
    if boundary then
        if self.face_direction == "front" then
            points = clipPointsToBoundary(points, 2, boundary, true)
        elseif self.face_direction == "back" then
            points = clipPointsToBoundary(points, 2, boundary, false)
        elseif self.face_direction == "left" then
            points = clipPointsToBoundary(points, 1, boundary, false)
        elseif self.face_direction == "right" then
            points = clipPointsToBoundary(points, 1, boundary, true)
        end
    end
    self.occlusion_mask_points = points
    return points
end

function HeightOccluder:resolveSourceLayer()
    if self.source_layer then return self.source_layer end
    local source = self.map:getDrawableLayer(self.source_layer_name)
    if source then
        self.source_layer = source
        self.source_draw_layer = source.layer or 0
        source:addHeightOcclusionMask(self)
        return source
    end
    if not self.source_warning_shown and self.source_layer_name ~= "" then
        self.source_warning_shown = true
        Kristal.Console:warn(string.format(
            "Height occluder '%s' could not find tile/image layer '%s' on map '%s'",
            tostring(self.data.name or self.data.id or "?"),
            self.source_layer_name,
            tostring(self.map.id or self.map.name or "?")
        ))
    end
end

---@param relative_to Object
---@param points? number[][]
function HeightOccluder:getMaskCoordinates(relative_to, points)
    local parent_transform = self.parent and self.parent:getFullHeightTransform()
        or HeightTransform()
    local target_transform = relative_to:getFullHeightTransform()
    local coordinates = {}
    for _, point in ipairs(points or self:getOcclusionMaskPoints()) do
        local world_x, world_y =
            parent_transform:transformVisualPoint(point[1], point[2])
        local local_x, local_y =
            target_transform:inverseTransformVisualPoint(world_x, world_y)
        table.insert(coordinates, local_x)
        table.insert(coordinates, local_y)
    end
    return coordinates
end

---@param transform love.Transform
---@param center_x number
---@param center_y number
---@param radius number
---@param time? number
---@param wobble? number
---@return number[] coordinates
function HeightOccluder:getCutoutBoundaryCoordinates(
    transform, center_x, center_y, radius, time, wobble)
    local coordinates = {}
    local segments = 48
    local phase = (time or Kristal.getTime())
            * self.cutout_wobble_speed
        + self.cutout_wobble_seed
    local amplitude = math.min(wobble or self.cutout_wobble, radius * 0.25)
    for index = 0, segments - 1 do
        local angle = index / segments * math.pi * 2
        local wave = math.sin(angle * 6 + phase) * 0.65
            + math.sin(angle * 9 - phase * 0.73 + 1.9) * 0.35
        local point_radius = math.max(radius + wave * amplitude, 0)
        local screen_x = center_x + math.cos(angle) * point_radius
        local screen_y = center_y + math.sin(angle) * point_radius
        local local_x, local_y = transform:inverseTransformPoint(screen_x, screen_y)
        table.insert(coordinates, local_x)
        table.insert(coordinates, local_y)
    end
    return coordinates
end

---@return Object? player
function HeightOccluder:getCharacterCutoutTarget()
    if not self.cutout_enabled or self.cutout_radius <= 0 then return nil end
    local world = self.map.world
    local player = world and world.player
    if not player or not player.visible or not player.height_sort_subject
        or not player.use_3d_collision then return nil end
    local _, occlusion_top = self:getOcclusionZBounds()
    if player:getFullZ() >= occlusion_top - 0.001
        or not self:isCoveringCharacter(player) then return nil end
    local gpu_managed = world._height_depth_renderer_active
        and self.face_direction == "front"
    if not gpu_managed and not self:isDrawnAfterCharacter(player) then
        return nil
    end
    return player
end

---@param player Object
function HeightOccluder:captureCharacterCutoutCenter(player)
    local player_transform = player:getFullHeightTransform()
    local screen_x, screen_y = player_transform:transformVisualPoint(
        player.width / 2, player.height / 2
    )
    local parent_transform = self.parent and self.parent:getFullHeightTransform()
        or HeightTransform()
    self.cutout_center_x, self.cutout_center_y =
        parent_transform:inverseTransformVisualPoint(screen_x, screen_y)
end

---@param target number
function HeightOccluder:setCutoutTweenTarget(target)
    target = MathUtils.clamp(target or 0, 0, 1)
    if math.abs(target - self.cutout_tween_target) <= 0.001 then return end
    self.cutout_tween_start = self.cutout_visibility
    self.cutout_tween_target = target
    self.cutout_tween_timer = 0
    self.cutout_tween_duration =
        target > self.cutout_visibility
            and self.cutout_grow_time or self.cutout_shrink_time
    if self.cutout_tween_duration <= 0 then
        self.cutout_visibility = target
    end
end

---@param dt? number
function HeightOccluder:updateCutoutAnimation(dt)
    local player = self:getCharacterCutoutTarget()
    if player then self:captureCharacterCutoutCenter(player) end
    self:setCutoutTweenTarget(player and 1 or 0)

    local duration = self.cutout_tween_duration
    if duration <= 0 then return end
    self.cutout_tween_timer =
        MathUtils.approach(self.cutout_tween_timer, duration, dt or DT)
    local progress =
        MathUtils.clamp(self.cutout_tween_timer / duration, 0, 1)
    local easing = self.cutout_tween_target > self.cutout_tween_start
        and "out-cubic" or "in-out-cubic"
    self.cutout_visibility = Utils.ease(
        self.cutout_tween_start,
        self.cutout_tween_target,
        progress,
        easing
    )
    if progress >= 1 then
        self.cutout_visibility = self.cutout_tween_target
        self.cutout_tween_duration = 0
    end
end

function HeightOccluder:update()
    self:updateCutoutAnimation()
    super.update(self)
end

--- Whether the character is on the far side of this directed depth face.
---@param player Object
---@return boolean
function HeightOccluder:isCharacterBehindFace(player)
    if not player then return false end
    self:resolveSurface()
    if self.face_direction == "always" then return true end
    if self.face_direction == "never" then return false end
    if not self.face_position then
        self.face_position = self.sort_y - self.sort_y_offset
    end
    local x, y = player:getSortPosition()
    local epsilon = 0.001
    local bounds = self.face_bounds
    if bounds then
        if (self.face_direction == "front" or self.face_direction == "back")
            and (x <= bounds.min_x + epsilon or x >= bounds.max_x - epsilon) then
            return false
        elseif (self.face_direction == "left" or self.face_direction == "right")
            and (y <= bounds.min_y + epsilon or y >= bounds.max_y - epsilon) then
            return false
        end
    end
    if self.face_direction == "front" then
        return y < self.face_position - epsilon
    elseif self.face_direction == "back" then
        return y > self.face_position + epsilon
    elseif self.face_direction == "left" then
        return x > self.face_position + epsilon
    elseif self.face_direction == "right" then
        return x < self.face_position - epsilon
    end
    return false
end

--- Returns this proxy and character's unmodified sibling positions.
---@param player Object
---@return number? player_index
---@return number? occluder_index
function HeightOccluder:getCharacterDrawIndices(player)
    if not self.parent or player.parent ~= self.parent then return nil, nil end
    local player_index, occluder_index
    for index, child in ipairs(self.parent.children) do
        if child == player then player_index = index end
        if child == self then occluder_index = index end
        if player_index and occluder_index then break end
    end
    return player_index, occluder_index
end

--- Whether ordinary Y sorting scheduled this proxy after the character.
---@param player Object
---@return boolean
function HeightOccluder:isDrawnAfterCharacter(player)
    local player_index, occluder_index = self:getCharacterDrawIndices(player)
    return player_index ~= nil and occluder_index ~= nil
        and player_index < occluder_index
end

--- Returns which side wins the face/character depth test.
---@param player Object
---@return "terrain"|"character"
function HeightOccluder:getCharacterDepthResult(player)
    local _, top = self:getOcclusionZBounds()
    local surface = self:resolveSurface()
    local character_surface = player.ground_surface
    if surface and character_surface and character_surface.id == surface.id then
        return "character"
    end
    if player:getFullZ() >= top - 0.001 then return "character" end
    return self:isCharacterBehindFace(player) and "terrain" or "character"
end

--- Whether the authored face is spatially in front of the character.
---@param player Object
---@return boolean
function HeightOccluder:isCoveringCharacter(player)
    return self:getCharacterDepthResult(player) == "terrain"
end

---@param source Object
---@return number[]? outer
---@return number[]? inner
function HeightOccluder:getCharacterCutout(source)
    if not self.cutout_enabled or self.cutout_visibility <= 0.001
        or self.cutout_center_x == nil then return nil end
    local player = self:getCharacterCutoutTarget()
    if player then self:captureCharacterCutoutCenter(player) end
    local parent_transform = self.parent and self.parent:getFullHeightTransform()
        or HeightTransform()
    local center_x, center_y = parent_transform:transformVisualPoint(
        self.cutout_center_x, self.cutout_center_y
    )
    local min_x, min_y, max_x, max_y = math.huge, math.huge, -math.huge, -math.huge
    for _, point in ipairs(self:getOcclusionMaskPoints()) do
        local x, y = parent_transform:transformVisualPoint(point[1], point[2])
        min_x, min_y = math.min(min_x, x), math.min(min_y, y)
        max_x, max_y = math.max(max_x, x), math.max(max_y, y)
    end
    local radius = self.cutout_radius * self.cutout_visibility
    if center_x + radius < min_x or center_x - radius > max_x
        or center_y + radius < min_y or center_y - radius > max_y then
        return nil
    end

    local source_transform = source:getFullHeightTransform():getVisualTransform()
    local time = Kristal.getTime()
    local wobble = math.min(
        self.cutout_wobble * self.cutout_visibility,
        radius * 0.25
    )
    local outer = self:getCutoutBoundaryCoordinates(
        source_transform, center_x, center_y, radius, time, wobble)
    local inner_radius = math.max(
        radius - self.cutout_feather * self.cutout_visibility, 0)
    local inner = inner_radius > 0
        and self:getCutoutBoundaryCoordinates(
            source_transform, center_x, center_y, inner_radius, time, wobble)
        or nil
    return outer, inner
end

---@return boolean
function HeightOccluder:hasCharacterDepthCutout()
    local source = self:resolveSourceLayer()
    return source ~= nil and self:getCharacterCutout(source) ~= nil
end

---@return Object? character
function HeightOccluder:getCharacterReveal()
    local player = self.map.world and self.map.world.player
    if not player or not player.visible or not player.height_sort_subject
        or not player.use_3d_collision
        or not player.drawHeightOcclusionMask then return nil end
    local player_index, occluder_index = self:getCharacterDrawIndices(player)
    if not player_index or not occluder_index
        or player_index >= occluder_index then return nil end
    return self:getCharacterDepthResult(player) == "character" and player or nil
end

---@return Object[] subjects
function HeightOccluder:getHeightReveals()
    local subjects = {}
    if not self.parent then return subjects end
    for _, subject in ipairs(self.parent.children) do
        if subject == self then break end
        if subject.visible and subject.height_sort_subject
            and subject.use_3d_collision
            and subject.drawHeightOcclusionMask
            and subject.getHeightOcclusionMaskCanvas
            and self:getCharacterDepthResult(subject) == "character" then
            table.insert(subjects, subject)
        end
    end
    return subjects
end

---@param relative_to Object
function HeightOccluder:drawMaskRelativeTo(relative_to)
    local points = self:getOcclusionMaskPoints()
    if #points < 3 then return end
    local coordinates = self:getMaskCoordinates(relative_to, points)
    love.graphics.polygon("fill", coordinates)
end

---@param mode "opaque"|"cutout"
function HeightOccluder:drawHeightDepthSource(mode)
    local source = self:resolveSourceLayer()
    local points = self:getOcclusionMaskPoints()
    if not source or not source.visible or #points < 3 then return end

    local coordinates = self:getMaskCoordinates(source, points)
    local cutout_outer, cutout_inner = self:getCharacterCutout(source)
    if mode == "cutout" and not cutout_outer then return end

    local previous_comparison, previous_value = love.graphics.getStencilTest()
    love.graphics.push()
    local transform = love.graphics.getTransformRef()
    source:applyVisualTransformTo(transform, 1 / CURRENT_SCALE_X, 1 / CURRENT_SCALE_Y)
    love.graphics.replaceTransform(transform)

    love.graphics.stencil(function()
        love.graphics.polygon("fill", coordinates)
    end, "replace", 1)

    if cutout_outer then
        love.graphics.setStencilTest("equal", 1)
        love.graphics.stencil(function()
            love.graphics.polygon("fill", cutout_outer)
        end, "replace", mode == "opaque" and 0 or 2, true)
        if mode == "cutout" and cutout_inner then
            love.graphics.setStencilTest("equal", 2)
            love.graphics.stencil(function()
                love.graphics.polygon("fill", cutout_inner)
            end, "replace", 3, true)
        end
    end

    source._drawing_height_occlusion_source = true
    local source_alpha = source.alpha or 1
    local function drawSource(stencil_value, alpha)
        love.graphics.setStencilTest("equal", stencil_value)
        source.alpha = source_alpha * alpha
        source:fullDraw(true, true)
    end
    if mode == "opaque" then
        drawSource(1, 1)
    else
        local feather_alpha = cutout_inner
            and MathUtils.lerp(self.cutout_alpha, 1, 0.55)
            or self.cutout_alpha
        drawSource(2, feather_alpha)
        if cutout_inner then drawSource(3, self.cutout_alpha) end
    end
    source.alpha = source_alpha
    source._drawing_height_occlusion_source = false

    if previous_comparison then
        love.graphics.setStencilTest(previous_comparison, previous_value)
    else
        love.graphics.setStencilTest()
    end
    love.graphics.pop()
end

function HeightOccluder:draw()
    local world = self.map.world
    if world and world._capturing_height_depth then
        self:drawHeightDepthSource(world._height_depth_capture_mode or "opaque")
        return
    end

    local source = self:resolveSourceLayer()
    local points = self:getOcclusionMaskPoints()
    if not source or not source.visible or #points < 3 then return end

    local coordinates = self:getMaskCoordinates(source, points)
    local cutout_outer, cutout_inner = self:getCharacterCutout(source)
    local reveal_canvases = {}
    for _, subject in ipairs(self:getHeightReveals()) do
        local canvas = subject:getHeightOcclusionMaskCanvas()
        if canvas then table.insert(reveal_canvases, canvas) end
    end
    local previous_comparison, previous_value = love.graphics.getStencilTest()
    love.graphics.push()
    local transform = love.graphics.getTransformRef()
    source:applyVisualTransformTo(transform, 1 / CURRENT_SCALE_X, 1 / CURRENT_SCALE_Y)
    love.graphics.replaceTransform(transform)
    love.graphics.stencil(function()
        love.graphics.polygon("fill", coordinates)
    end, "replace", 1)
    if cutout_outer then
        love.graphics.setStencilTest("equal", 1)
        love.graphics.stencil(function()
            love.graphics.polygon("fill", cutout_outer)
        end, "replace", 2, true)
        if cutout_inner then
            love.graphics.setStencilTest("equal", 2)
            love.graphics.stencil(function()
                love.graphics.polygon("fill", cutout_inner)
            end, "replace", 3, true)
        end
    end

    source._drawing_height_occlusion_source = true
    local source_alpha = source.alpha or 1
    local function drawSource(stencil_value, alpha)
        love.graphics.setStencilTest("equal", stencil_value)
        source.alpha = source_alpha * alpha
        source:fullDraw(true, true)
    end
    drawSource(1, 1)
    if cutout_outer then
        local feather_alpha = cutout_inner
            and MathUtils.lerp(self.cutout_alpha, 1, 0.55)
            or self.cutout_alpha
        drawSource(2, feather_alpha)
        if cutout_inner then drawSource(3, self.cutout_alpha) end
    end
    source.alpha = source_alpha
    source._drawing_height_occlusion_source = false
    if #reveal_canvases > 0 then
        love.graphics.setStencilTest()
        love.graphics.stencil(function()
            love.graphics.polygon("fill", coordinates)
        end, "replace", 7, true)
        love.graphics.setStencilTest("equal", 7)
        love.graphics.push()
        love.graphics.origin()
        local reveal_r, reveal_g, reveal_b, reveal_a = love.graphics.getColor()
        Draw.setColor(1, 1, 1)
        for _, reveal_canvas in ipairs(reveal_canvases) do
            Draw.drawCanvas(reveal_canvas)
        end
        love.graphics.setColor(reveal_r, reveal_g, reveal_b, reveal_a)
        love.graphics.pop()
    end
    if previous_comparison then
        love.graphics.setStencilTest(previous_comparison, previous_value)
    else
        love.graphics.setStencilTest()
    end
    love.graphics.pop()
end

function HeightOccluder:onRemove(parent)
    if self.source_layer then self.source_layer:removeHeightOcclusionMask(self) end
    super.onRemove(self, parent)
end

return HeightOccluder
