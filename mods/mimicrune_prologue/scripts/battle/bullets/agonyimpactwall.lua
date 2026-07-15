local AgonyImpactWall, super = Class(Bullet)

function AgonyImpactWall:init(
    x,
    y,
    direction,
    speed,
    axis_length,
    gap_offset,
    gap_size,
    contact_coordinate,
    exit_coordinate,
    side_x,
    side_y,
    slam_index
)
    super.init(self, x, y)

    self:setOrigin(0, 0)
    self:setScale(1)

    self.physics.direction = direction
    self.physics.speed = 0
    self.target_speed = speed
    self.horizontal_travel = math.abs(math.cos(direction)) > 0.5
    self.travel_sign = self.horizontal_travel
        and (math.cos(direction) >= 0 and 1 or -1)
        or (math.sin(direction) >= 0 and 1 or -1)
    self.contact_coordinate = contact_coordinate
    self.exit_coordinate = exit_coordinate
    self.side_x = side_x
    self.side_y = side_y
    self.slam_index = slam_index

    self.age = 0
    self.spawn_age = 0
    self.spawn_duration = 8
    self.launched = false
    self.launch_age = 0
    self.contacted = false
    self.impact_age = nil
    self.dissolve_progress = nil
    self.dissolve_duration = 10
    self.destroy_on_hit = false
    self.remove_offscreen = false
    self.collidable = false

    self.pieces = {}
    self.collider = ColliderGroup(self)

    local cell_spacing = 12
    local axis_cells = math.ceil(axis_length / cell_spacing)
    for axis_index = 1, axis_cells do
        local axis_position = (axis_index - (axis_cells + 1) / 2) * cell_spacing
        if math.abs(axis_position - gap_offset) >= gap_size / 2 + 9 then
            local depth_cells = 3 + ((axis_index + slam_index) % 2)
            for depth_index = 1, depth_cells do
                local depth_position = (depth_index - (depth_cells + 1) / 2) * cell_spacing
                local axis_jitter = MathUtils.random(-1.8, 1.8)
                local depth_jitter = MathUtils.random(-2.4, 2.4)
                local piece_x, piece_y

                if self.horizontal_travel then
                    piece_x = depth_position + depth_jitter
                    piece_y = axis_position + axis_jitter
                else
                    piece_x = axis_position + axis_jitter
                    piece_y = depth_position + depth_jitter
                end

                local size = MathUtils.random(14, 18)
                local piece = {
                    x = piece_x,
                    y = piece_y,
                    size = size,
                    rotation = MathUtils.random(-0.28, 0.28),
                    spin = MathUtils.random(-0.025, 0.025),
                    phase = MathUtils.random(0, math.pi * 2),
                }
                table.insert(self.pieces, piece)
                table.insert(
                    self.collider.colliders,
                    CircleCollider(self, piece_x, piece_y, size * 0.38)
                )
            end
        end
    end
end

function AgonyImpactWall:hasReached(coordinate)
    local position = self.horizontal_travel and self.x or self.y
    if self.travel_sign > 0 then
        return position >= coordinate
    end
    return position <= coordinate
end

function AgonyImpactWall:beginDissolve()
    if self.dissolve_progress then return end
    self.dissolve_progress = 0
    self.collidable = false
    self.can_graze = false
end

function AgonyImpactWall:launch()
    if self.launched then return end
    self.launched = true
    self.launch_age = 0
    self.physics.speed = self.target_speed
    self.collidable = true
    if self.wave and self.wave.onImpactWallLaunch then
        self.wave:onImpactWallLaunch(self)
    end
end

function AgonyImpactWall:update()
    self.age = self.age + DTMULT
    if not self.launched then
        self.spawn_age = self.spawn_age + DTMULT
    else
        self.launch_age = self.launch_age + DTMULT
    end
    if self.impact_age then
        self.impact_age = self.impact_age + DTMULT
    end
    for _, piece in ipairs(self.pieces) do
        piece.rotation = piece.rotation + piece.spin * DTMULT
    end

    super.update(self)

    if not self.launched then
        if self.spawn_age >= self.spawn_duration then
            self:launch()
        end
        return
    end

    if not self.contacted and self:hasReached(self.contact_coordinate) then
        self.contacted = true
        self.impact_age = 0
        if self.wave and self.wave.onImpactWallContact then
            self.wave:onImpactWallContact(self)
        end
    end

    if not self.dissolve_progress and self:hasReached(self.exit_coordinate) then
        self:beginDissolve()
    end

    if self.dissolve_progress then
        self.dissolve_progress = self.dissolve_progress + DTMULT / self.dissolve_duration
        if self.dissolve_progress >= 1 then
            self:remove()
        end
    end
end

function AgonyImpactWall:drawPiece(mode, piece, size, offset_x, offset_y)
    love.graphics.push()
    love.graphics.translate(piece.x + (offset_x or 0), piece.y + (offset_y or 0))
    love.graphics.rotate(piece.rotation)
    love.graphics.rectangle(mode, -size / 2, -size / 2, size, size)
    love.graphics.pop()
end

function AgonyImpactWall:draw()
    local dissolve = self.dissolve_progress or 0
    local impact_flash = self.impact_age and MathUtils.clamp(1 - self.impact_age / 5, 0, 1) or 0
    local move_x = self.horizontal_travel and self.travel_sign or 0
    local move_y = self.horizontal_travel and 0 or self.travel_sign
    local smear = MathUtils.lerp(38, 15, MathUtils.clamp(self.launch_age / 5, 0, 1))

    love.graphics.push()
    if not self.launched then
        local progress = MathUtils.clamp(self.spawn_age / self.spawn_duration, 0, 1)
        local tick = math.floor(self.spawn_age * 2)
        local jitter = (1 - progress) * 11
        love.graphics.translate(
            math.sin(tick * 12.9898) * jitter,
            math.sin(tick * 7.233) * jitter * 0.7
        )

        local cross_scale
        if progress < 0.2 then
            cross_scale = MathUtils.lerp(0.04, 2.5, progress / 0.2)
        elseif progress < 0.48 then
            cross_scale = MathUtils.lerp(2.5, 0.45, (progress - 0.2) / 0.28)
        else
            cross_scale = MathUtils.lerp(0.45, 1, (progress - 0.48) / 0.52)
        end
        local depth_scale = MathUtils.lerp(0.1, 1, progress)
        love.graphics.scale(
            self.horizontal_travel and depth_scale or cross_scale,
            self.horizontal_travel and cross_scale or depth_scale
        )
    end

    Draw.setColor(0.35, 0, 0, (1 - dissolve) * 0.65)
    love.graphics.setLineWidth(2)
    for _, piece in ipairs(self.pieces) do
        love.graphics.line(
            piece.x - move_x * smear,
            piece.y - move_y * smear,
            piece.x,
            piece.y
        )
    end

    -- As with the other connected agony masses, outlines are batched before
    -- interiors so overlapping cells merge instead of reading as a grid
    Draw.setColor(1, impact_flash * 0.55, impact_flash * 0.55, 1 - dissolve)
    love.graphics.setLineWidth(2 + impact_flash * 2)
    for index, piece in ipairs(self.pieces) do
        local peel = dissolve * (1 + (index % 4) * 0.18)
        local perpendicular = math.sin(piece.phase) * peel * 8
        local offset_x = self.horizontal_travel and 0 or perpendicular
        local offset_y = self.horizontal_travel and perpendicular or 0
        self:drawPiece("line", piece, piece.size * (1 - dissolve * 0.25), offset_x, offset_y)
    end

    Draw.setColor(0, 0, 0, 1 - dissolve)
    for index, piece in ipairs(self.pieces) do
        local peel = dissolve * (1 + (index % 4) * 0.18)
        local perpendicular = math.sin(piece.phase) * peel * 8
        local offset_x = (self.horizontal_travel and 0 or perpendicular) - move_x * dissolve * 7
        local offset_y = (self.horizontal_travel and perpendicular or 0) - move_y * dissolve * 7
        self:drawPiece(
            "fill",
            piece,
            math.max(2, piece.size - 3 - dissolve * 4),
            offset_x,
            offset_y
        )
    end

    if not self.launched then
        local progress = MathUtils.clamp(self.spawn_age / self.spawn_duration, 0, 1)
        Draw.setColor(1, 0, 0, (1 - progress) * 0.85)
        love.graphics.setLineWidth(2)
        if self.horizontal_travel then
            love.graphics.line(-54, 0, 54, 0)
        else
            love.graphics.line(0, -54, 0, 54)
        end
    end

    love.graphics.pop()
    Draw.setColor(1, 1, 1, 1)
end

return AgonyImpactWall
