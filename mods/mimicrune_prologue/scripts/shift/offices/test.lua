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

local DoorLever, door_lever_super = Class(OfficeDoorLever)

---@param office Office
---@param door OfficeDoor
function DoorLever:init(office, door)
    door_lever_super.init(self, office, door, 0, 0, 48, 30)
end

function DoorLever:onLeverActivated(endpoint, door, changed)
    if changed then
        Assets.playSound(endpoint == "start" and "doorlever_release" or "doorlever_shut", 0.55)
    end
end

function DoorLever:draw()
    self.sprite:setColor(1, 1, 1, self.hovered and 1 or 0.85)
    door_lever_super.draw(self)
end

local TestOffice, super = Class(Office)

function TestOffice:init()
    super.init(self)
    self.pan_speed = 1200

    local stage = Registry.createShiftCamera("test", "test_stage", "CAM 01 - STAGE", { 0.65, 0.45, 0.45 })
    local hall = Registry.createShiftCamera("test", "test_hall", "CAM 02 - HALL", { 0.45, 0.65, 0.5 })
    local storage = Registry.createShiftCamera("test", "test_storage", "CAM 03 - STORAGE", { 0.45, 0.5, 0.7 })

    local left_door = OfficeDoor()
    left_door.id = "left_office_door"
    self:addDoor(left_door)

    local right_door = OfficeDoor()
    right_door.id = "right_office_door"
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
    self:addInteractable(DoorLever(self, left_door), "left_door_lever")
    self:addInteractable(DoorLever(self, right_door), "right_door_lever")
    self:addStaticInteractable(CameraToggle(self), "camera_toggle")
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
