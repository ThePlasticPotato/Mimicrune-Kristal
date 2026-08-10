---@class UnderwaterUnderlay : Object
---@field map Map
---@field mesh love.Mesh?
---@overload fun(map: Map): UnderwaterUnderlay
local UnderwaterUnderlay, super = Class(Object)

local DEFAULT_SHALLOW_COLOR = { 0.043, 0.086, 0.176 }
local DEFAULT_DEEP_COLOR = { 0.012, 0.027, 0.067 }

local function makeVertices(left, top, right, bottom, map_width, map_height)
    local left_u = left / map_width
    local right_u = right / map_width
    local top_v = top / map_height
    local bottom_v = bottom / map_height
    return {
        { left,  top,    left_u,  top_v,    1, 1, 1, 1 },
        { right, top,    right_u, top_v,    1, 1, 1, 1 },
        { right, bottom, right_u, bottom_v, 1, 1, 1, 1 },
        { left,  top,    left_u,  top_v,    1, 1, 1, 1 },
        { right, bottom, right_u, bottom_v, 1, 1, 1, 1 },
        { left,  bottom, left_u,  bottom_v, 1, 1, 1, 1 }
    }
end

local function getColorCanvas(target)
    if type(target) == "userdata" then return target end
    if type(target) ~= "table" then return nil end

    local first = target[1]
    if type(first) == "userdata" then return first end
    if type(first) == "table" then
        if type(first[1]) == "userdata" then return first[1] end
        if type(first.canvas) == "userdata" then return first.canvas end
    end
    if type(target.canvas) == "userdata" then return target.canvas end
    return nil
end

local function readColor(value, fallback)
    if type(value) == "table" then
        return {
            tonumber(value[1]) or fallback[1],
            tonumber(value[2]) or fallback[2],
            tonumber(value[3]) or fallback[3]
        }
    end
    local color = ColorUtils.tryHexToRGB(tostring(value or ""))
    if color then return { color[1], color[2], color[3] } end
    return TableUtils.copy(fallback)
end

---@param map Map
function UnderwaterUnderlay:init(map)
    self.map = map
    self.map_width = math.max(map.width * map.tile_width, 1)
    self.map_height = math.max(map.height * map.tile_height, 1)
    self.opacity = MathUtils.clamp(
        tonumber(map.underwater_underlay_opacity) or 0.68, 0, 1)
    self.void_strength = MathUtils.clamp(
        tonumber(map.underwater_underlay_void_strength) or 1, 0, 1)
    self.speed = tonumber(map.underwater_underlay_speed) or 1
    self.pixel_size = math.max(
        math.floor(tonumber(map.underwater_underlay_pixel_size) or 2), 1)
    self.pattern_scale = math.max(
        tonumber(map.underwater_underlay_scale) or 1, 0.01)
    self.distortion = math.max(
        tonumber(map.underwater_underlay_distortion) or 6, 0)
    self.particle_strength = math.max(
        tonumber(map.underwater_underlay_particle_strength) or 0.35, 0)
    self.shallow_color = readColor(
        map.underwater_underlay_shallow_color, DEFAULT_SHALLOW_COLOR)
    self.deep_color = readColor(
        map.underwater_underlay_deep_color, DEFAULT_DEEP_COLOR)

    super.init(self, 0, 0, self.map_width, self.map_height)

    self.coverage_left = 0
    self.coverage_top = 0
    self.coverage_right = self.map_width
    self.coverage_bottom = self.map_height
    self.mesh = love.graphics.newMesh(makeVertices(
        self.coverage_left, self.coverage_top,
        self.coverage_right, self.coverage_bottom,
        self.map_width, self.map_height
    ), "triangles", "dynamic")
    self.debug_select = false
end

function UnderwaterUnderlay:updateCameraCoverage()
    local camera = self.map.world and self.map.world.camera
    if not camera then return end

    local x, y, width, height = camera:getRect()
    local margin = math.max(self.pixel_size, self.distortion) + 4
    local left = math.floor(x - margin)
    local top = math.floor(y - margin)
    local right = math.ceil(x + width + margin)
    local bottom = math.ceil(y + height + margin)

    local coverage_left = math.min(self.coverage_left, left)
    local coverage_top = math.min(self.coverage_top, top)
    local coverage_right = math.max(self.coverage_right, right)
    local coverage_bottom = math.max(self.coverage_bottom, bottom)
    if coverage_left == self.coverage_left
        and coverage_top == self.coverage_top
        and coverage_right == self.coverage_right
        and coverage_bottom == self.coverage_bottom then
        return
    end

    self.coverage_left = coverage_left
    self.coverage_top = coverage_top
    self.coverage_right = coverage_right
    self.coverage_bottom = coverage_bottom
    self.mesh:setVertices(makeVertices(
        coverage_left, coverage_top, coverage_right, coverage_bottom,
        self.map_width, self.map_height
    ))
end

function UnderwaterUnderlay:draw()
    if not self.mesh or not Kristal.Shaders["UnderwaterDepth"] then return end
    self:updateCameraCoverage()

    local source_canvas = getColorCanvas(love.graphics.getCanvas())
    if not source_canvas then return end
    local source_width, source_height = source_canvas:getDimensions()
    local background = Draw.pushCanvas(source_width, source_height)
    Draw.setColor(1, 1, 1, 1)
    Draw.drawCanvas(source_canvas)
    Draw.popCanvas(true)

    Draw.pushShader("UnderwaterDepth", {
        background_texture = background,
        screen_size = { source_width, source_height },
        map_size = { self.map_width, self.map_height },
        time = Kristal.getTime(),
        motion_speed = self.speed,
        opacity = self.opacity,
        void_strength = self.void_strength,
        pixel_size = self.pixel_size,
        pattern_scale = self.pattern_scale,
        distortion = self.distortion,
        particle_strength = self.particle_strength,
        shallow_color = self.shallow_color,
        deep_color = self.deep_color
    })
    Draw.setColor(1, 1, 1, 1)
    local old_blend, old_alpha_mode = love.graphics.getBlendMode()
    love.graphics.setBlendMode("replace")
    love.graphics.draw(self.mesh)
    love.graphics.setBlendMode(old_blend, old_alpha_mode)
    Draw.popShader()
    Draw.unlockCanvas(background)
end

function UnderwaterUnderlay:onRemove(parent)
    if self.mesh then
        self.mesh:release()
        self.mesh = nil
    end
    super.onRemove(self, parent)
end

return UnderwaterUnderlay
