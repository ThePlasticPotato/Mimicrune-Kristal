local status, super = Class(Status, "test_status")

function status:init()
    super.init(self)

    --The display name
    self.name = "TEST"
    self.icon = nil
    self.type_icon = nil
    -- The color(s) the status will display as
    self.color = COLORS.white
    -- Tags that apply to this status
    self.tags = {}

    self.positive = true
    self.curable = true

    self.max = 0
    self.duration = 1
    self.decay = false
    self.decay_rate = 1
    self.tick_type = "TURN_START"
end

return status