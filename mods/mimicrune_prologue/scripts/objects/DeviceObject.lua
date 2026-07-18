---@class DeviceObject : Object
local DeviceObject, super = Class(Object)

local light_occluder_hull_cache = {}

local function cross(origin, a, b)
    return (a[1] - origin[1]) * (b[2] - origin[2])
        - (a[2] - origin[2]) * (b[1] - origin[1])
end

local function buildLightOccluderHull(front_sprite, back_sprite, width, height)
    local cache_key = front_sprite .. "\0" .. back_sprite
    if light_occluder_hull_cache[cache_key] then
        return light_occluder_hull_cache[cache_key]
    end

    local image_data = {
        Assets.getTextureData(front_sprite),
        Assets.getTextureData(back_sprite)
    }
    local points = {}
    local seen = {}

    local function addPoint(x, y)
        local key = x .. ":" .. y
        if not seen[key] then
            seen[key] = true
            table.insert(points, {x, y})
        end
    end

    for y = 0, height - 1 do
        for x = 0, width - 1 do
            local opaque = false
            for _, data in ipairs(image_data) do
                local _, _, _, alpha = data:getPixel(x, y)
                if alpha > 0 then
                    opaque = true
                    break
                end
            end
            if opaque then
                addPoint(x, y)
                addPoint(x + 1, y)
                addPoint(x + 1, y + 1)
                addPoint(x, y + 1)
            end
        end
    end

    table.sort(points, function(a, b)
        return a[1] == b[1] and a[2] < b[2] or a[1] < b[1]
    end)

    if #points <= 2 then
        light_occluder_hull_cache[cache_key] = points
        return points
    end

    local lower = {}
    for _, point in ipairs(points) do
        while #lower >= 2 and cross(lower[#lower - 1], lower[#lower], point) <= 0 do
            table.remove(lower)
        end
        table.insert(lower, point)
    end

    local upper = {}
    for index = #points, 1, -1 do
        local point = points[index]
        while #upper >= 2 and cross(upper[#upper - 1], upper[#upper], point) <= 0 do
            table.remove(upper)
        end
        table.insert(upper, point)
    end

    table.remove(lower)
    table.remove(upper)
    for _, point in ipairs(upper) do table.insert(lower, point) end

    light_occluder_hull_cache[cache_key] = lower
    return lower
end

function DeviceObject:init(x, y, scale_x, scale_y, front_sprite, back_sprite, front_color, tile_x, tile_y)
    local width, height = Assets.getTexture(front_sprite):getDimensions()
    super.init(self, x, y, width, height)
    self.sprite_front = self:addChild(Sprite(front_sprite))
    self.sprite_front.inherit_color = true
    self.sprite_back = self:addChild(Sprite(back_sprite))
    self.sprite_back.inherit_color = true
    self.sprite_back:setLayer(-1)
    self:setScale(scale_x, scale_y)
    self.sprite_front:setWrap(tile_x, tile_y)
    self.sprite_back:setWrap(tile_x, tile_y)

    self.light_occluder_hull = buildLightOccluderHull(front_sprite, back_sprite, width, height)

    self.front_color = front_color or {0.1, 0.1, 0.1, 1.0}
    self.outline_front = self.sprite_front:addFX(HighlightFX(0.75, self.front_color), "frontoutline")
    self.outline_back = self.sprite_back:addFX(HighlightFX(0.75, self.front_color), "backoutline")
    self.sprite_front:setColor(self.front_color)
end

function DeviceObject:showOutline(time, value)
    Game.world.timer:tween((time or 1), self.outline_front, {alpha = (value or 0.75)}, "linear")
    Game.world.timer:tween((time or 1), self.outline_back, {alpha = (value or 0.75)}, "linear")
end

function DeviceObject:hideOutline(time)
    Game.world.timer:tween((time or 1), self.outline_front, {alpha = 0.0}, "linear")
    Game.world.timer:tween((time or 1), self.outline_back, {alpha = 0.0}, "linear")
end

function DeviceObject:setOutlineColor(color)
    self.outline_front:setHighlight(unpack(color))
    self.outline_back:setHighlight(unpack(color))
end

function DeviceObject:approachFrontColor(time, color)
    local current_color = {unpack(self.front_color)}
    local target_color = color

    local spent = 0
    Game.world.timer:doWhile(function() return spent < time end,
    function()
        spent = spent + DT
        local currentColor = ColorUtils.mergeColor(current_color, target_color, spent / time)
        self.sprite_front:setColor(currentColor)
    end, function () self.sprite_front:setColor(color) end)
end

function DeviceObject:getOutlineColor()
    return self.outline_front:getHighlight()
end

function DeviceObject:setOutlineLightDirection(direction)
    self.outline_front:setLightDirection(direction)
    self.outline_back:setLightDirection(direction)
end

function DeviceObject:setOutlineLightSource(x, y)
    self.outline_front:setLightSource(x, y)
    self.outline_back:setLightSource(x, y)
end

function DeviceObject:getOutlineLightState()
    return self.outline_front:getLightSource(), self.outline_front:getConfiguredLightDirection()
end

function DeviceObject:setOutlineLightStrength(strength)
    self.outline_front:setLightStrength(strength)
    self.outline_back:setLightStrength(strength)
end

function DeviceObject:setSprite(sprite)
    self.sprite_front:setSprite(sprite)
    self.sprite_back:setSprite(sprite .. "_bg")
end

function DeviceObject:setAnimation(sprite, after)
    self.sprite_front:setFrames(Assets.getFrames(sprite))
    self.sprite_back:setFrames(Assets.getFrames(sprite .. "_bg"))
    self.sprite_front:play(1, false, after)
    self.sprite_back:play(1, false)
end

function DeviceObject:getLightOccluderPoints(light)
    local source_x, source_y = light:getScreenPosition()
    local source_local_x, source_local_y = self:screenToLocalPos(source_x, source_y)
    local screen_l, screen_u = self:screenToLocalPos(0, 0)
    local screen_r, screen_d = self:screenToLocalPos(SCREEN_WIDTH, SCREEN_HEIGHT)
    local minimum_x, maximum_x = math.min(screen_l, screen_r), math.max(screen_l, screen_r)
    local minimum_y, maximum_y = math.min(screen_u, screen_d), math.max(screen_u, screen_d)

    local function getOffsets(wrapped, minimum, maximum, size)
        if not wrapped then return {0} end

        local first = math.floor(minimum / size) * size
        local count = math.max(1, math.ceil((maximum - first) / size))
        local offsets = {}
        for index = 0, count - 1 do
            table.insert(offsets, first + index * size)
        end
        return offsets
    end

    local x_offsets = getOffsets(self.sprite_front.wrap_texture_x, minimum_x, maximum_x, self.width)
    local y_offsets = getOffsets(self.sprite_front.wrap_texture_y, minimum_y, maximum_y, self.height)
    local points = {}
    for _, offset_x in ipairs(x_offsets) do
        for _, offset_y in ipairs(y_offsets) do
            if source_local_x >= offset_x and source_local_x <= offset_x + self.width
                and source_local_y >= offset_y and source_local_y <= offset_y + self.height then
                return nil
            end

            for _, point in ipairs(self.light_occluder_hull) do
                table.insert(points, {
                    self:localToScreenPos(point[1] + offset_x, point[2] + offset_y)
                })
            end
        end
    end
    return points
end

function DeviceObject:drawLightOccluderMask(light, draw_origin_x, draw_origin_y)
    if self.alpha <= 0 then return end

    for _, sprite in ipairs({self.sprite_back, self.sprite_front}) do
        if sprite.visible and sprite.texture then
            love.graphics.push("all")
            love.graphics.origin()
            love.graphics.translate(-draw_origin_x, -draw_origin_y)
            love.graphics.applyTransform(sprite:getFullTransform())
            Draw.pushShader("Mask")
            sprite:draw()
            Draw.popShader()
            love.graphics.pop()
        end
    end
end

return DeviceObject
