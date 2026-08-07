local CameraToggle, toggle_super = Class(OfficeInteractable)

---@param office Office
function CameraToggle:init(office)
    toggle_super.init(self, 220, SCREEN_HEIGHT - 34, 200, 28)
    self.office = office
    self.swipe_cooldown = 0.35
    self.last_swipe = -math.huge
end

function CameraToggle:onMouseEnter(x, y)
    local shift = self.office.shift
    local panel = shift and shift.night.camera_panel
    local now = Kristal.getTime()
    if panel
        and (panel.state == "OPEN" or panel.state == "CLOSED")
        and now - self.last_swipe >= self.swipe_cooldown
        and panel:toggle()
    then
        self.last_swipe = now
    end
end

function CameraToggle:draw()
    Draw.setColor(0, 0, 0, self.hovered and 0.9 or 0.65)
    love.graphics.rectangle("fill", 0, 0, self.width, self.height)
    Draw.setColor(1, 1, 1, 1)
    love.graphics.rectangle("line", 0, 0, self.width, self.height)
    love.graphics.setFont(Assets.getFont("main", 16))
    love.graphics.printf("CAMERAS", 0, 5, self.width, "center")
    toggle_super.draw(self)
end

local DoorToggle, door_toggle_super = Class(OfficeInteractable)

---@param office Office
---@param door OfficeDoor
---@param label string
---@param x number
function DoorToggle:init(office, door, label, x)
    door_toggle_super.init(self, x, 190, 74, 48)
    self.office = office
    self.door = door
    self.label = label
end

function DoorToggle:onClick(button, x, y, presses)
    if self.door:toggle() then
        Assets.playSound("ui_select", 0.45)
    end
end

function DoorToggle:draw()
    Draw.setColor(0, 0, 0, self.hovered and 0.9 or 0.65)
    love.graphics.rectangle("fill", 0, 0, self.width, self.height)
    Draw.setColor(1, 1, 1, 1)
    love.graphics.rectangle("line", 0, 0, self.width, self.height)
    love.graphics.setFont(Assets.getFont("main", 10))
    love.graphics.printf(self.label, 0, 7, self.width, "center")
    local state = self.door.jammed and "JAMMED" or self.door.state
    love.graphics.printf(state, 0, 25, self.width, "center")
    door_toggle_super.draw(self)
end

local TestOffice, super = Class(Office)

function TestOffice:init()
    super.init(self)

    self.background = Sprite("shifts/factory_office")
    self.pan_range = { 0, math.max(0, self.background.width - SCREEN_WIDTH) }
    self.pan_speed = 1200
    self:setPan(self.pan_range[2] / 2, true)

    local stage = Registry.createShiftCamera("test", "test_stage", "CAM 01 - STAGE", { 0.65, 0.45, 0.45 })
    local hall = Registry.createShiftCamera("test", "test_hall", "CAM 02 - HALL", { 0.45, 0.65, 0.5 })
    local storage = Registry.createShiftCamera("test", "test_storage", "CAM 03 - STORAGE", { 0.45, 0.5, 0.7 })

    local left_door = OfficeDoor()
    left_door.id = "test_left_door"
    self:addDoor(left_door)

    local right_door = OfficeDoor()
    right_door.id = "test_right_door"
    self:addDoor(right_door)

    stage:addMoveTarget("test_hall")
    hall:addMoveTarget("test_stage")
    hall:addMoveTarget("test_storage")
    hall:addMoveTarget(left_door)
    storage:addMoveTarget("test_hall")
    storage:addMoveTarget(right_door)

    self:addCamera(stage)
    self:addCamera(hall)
    self:addCamera(storage)
    self:addStaticInteractable(DoorToggle(self, left_door, "LEFT", 12))
    self:addStaticInteractable(DoorToggle(self, right_door, "RIGHT", SCREEN_WIDTH - 86))
    self:addStaticInteractable(CameraToggle(self))
end

function TestOffice:onPan(pan, old)
    self.background.x = -pan
end

function TestOffice:update()
    local shift = self.shift
    if shift and shift.state == "GAMEPLAY" and not shift.panel then
        local mouse_x = Input.getCurrentCursorPosition()
        if mouse_x then
            local edge_margin = 64
            local pan_area = SCREEN_WIDTH - (edge_margin * 2)
            local pan_ratio = MathUtils.clamp((mouse_x - edge_margin) / pan_area, 0, 1)
            self:setPan(self.pan_range[1] + (pan_ratio * (self.pan_range[2] - self.pan_range[1])))
        end
    end
    super.update(self)
end

return TestOffice
