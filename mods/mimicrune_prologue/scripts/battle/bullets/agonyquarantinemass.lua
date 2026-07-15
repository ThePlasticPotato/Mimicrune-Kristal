local AgonyQuarantineMass, super = Class(Bullet)

function AgonyQuarantineMass:init(x, y, direction, speed, axis_length, depth, exit_coordinate)
    super.init(self, x, y)

    self:setOrigin(0, 0)
    self:setScale(1)

    self.physics.direction = direction
    self.physics.speed = speed
    self.exit_coordinate = exit_coordinate
    self.horizontal_travel = math.abs(math.cos(direction)) > 0.5
    self.travel_sign = self.horizontal_travel
        and (math.cos(direction) >= 0 and 1 or -1)
        or (math.sin(direction) >= 0 and 1 or -1)
    self.age = 0

    self.destroy_on_hit = false
    self.remove_offscreen = false
    self.pieces = {}
    self.collider = ColliderGroup(self)

    local cell_spacing = 13
    local axis_cells = math.max(3, math.ceil(axis_length / cell_spacing))
    local maximum_depth_cells = math.max(4, math.ceil(depth / cell_spacing))
    for axis_index = 1, axis_cells do
        local axis_position = (axis_index - (axis_cells + 1) / 2) * cell_spacing
        local axis_normal = math.abs((axis_index - (axis_cells + 1) / 2) / (axis_cells / 2))
        local profile = 0.5 + math.cos(MathUtils.clamp(axis_normal, 0, 1) * math.pi / 2) * 0.5
        local depth_cells = math.max(
            3,
            math.floor(maximum_depth_cells * profile + ((axis_index * 5) % 2))
        )
        local depth_wave = math.sin(axis_index * 1.73) * 3.5

        for depth_index = 1, depth_cells do
            local depth_position = (depth_index - (depth_cells + 1) / 2) * cell_spacing + depth_wave
            local jitter_axis = MathUtils.random(-2.2, 2.2)
            local jitter_depth = MathUtils.random(-2.5, 2.5)
            local piece_x, piece_y

            if self.horizontal_travel then
                piece_x = depth_position + jitter_depth
                piece_y = axis_position + jitter_axis
            else
                piece_x = axis_position + jitter_axis
                piece_y = depth_position + jitter_depth
            end

            local size = MathUtils.random(17, 22)
            local piece = {
                x = piece_x,
                y = piece_y,
                size = size,
                rotation = MathUtils.random(-0.35, 0.35),
                spin = MathUtils.random(-0.018, 0.018),
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

function AgonyQuarantineMass:hasPassedExit()
    local coordinate = self.horizontal_travel and self.x or self.y
    if self.travel_sign > 0 then
        return coordinate >= self.exit_coordinate
    end
    return coordinate <= self.exit_coordinate
end

function AgonyQuarantineMass:update()
    self.age = self.age + DTMULT
    for _, piece in ipairs(self.pieces) do
        piece.rotation = piece.rotation + piece.spin * DTMULT
    end

    super.update(self)
    if self:hasPassedExit() then
        self:remove()
    end
end

function AgonyQuarantineMass:drawPiece(mode, piece, size, offset_x, offset_y)
    love.graphics.push()
    love.graphics.translate(piece.x + (offset_x or 0), piece.y + (offset_y or 0))
    love.graphics.rotate(piece.rotation)
    love.graphics.rectangle(mode, -size / 2, -size / 2, size, size)
    love.graphics.pop()
end

function AgonyQuarantineMass:draw()
    local move_x = self.horizontal_travel and self.travel_sign or 0
    local move_y = self.horizontal_travel and 0 or self.travel_sign

    Draw.setColor(0.35, 0, 0, 0.55)
    love.graphics.setLineWidth(2)
    for index, piece in ipairs(self.pieces) do
        if index % 2 == 0 then
            local streak = 18 + (index % 4) * 7
            love.graphics.line(
                piece.x - move_x * streak,
                piece.y - move_y * streak,
                piece.x,
                piece.y
            )
        end
    end

    Draw.setColor(1, 0, 0, 1)
    love.graphics.setLineWidth(2)
    for _, piece in ipairs(self.pieces) do
        local pulse = 1 + math.sin(self.age / 3.5 + piece.phase) * 0.06
        self:drawPiece("line", piece, piece.size * pulse)
    end

    Draw.setColor(0, 0, 0, 1)
    for _, piece in ipairs(self.pieces) do
        local pulse = 1 + math.sin(self.age / 3.5 + piece.phase) * 0.06
        self:drawPiece("fill", piece, math.max(2, piece.size * pulse - 3))
    end

    Draw.setColor(1, 1, 1, 1)
end

return AgonyQuarantineMass
