local TestAnimatronic, super = Class(ShiftAnimatronic)

function TestAnimatronic:init()
    super.init(self)

    self.name = "Placeholder Mimic"
    self.jumpscare = "mimic"
    self.starting_camera = "test_stage"
    self.ai_level = 8
    self.movement_interval = 2.5
end

function TestAnimatronic:onMove(camera, old)
    if old and camera then
        Assets.playSound("step/animatronic1", 0.35)
    end
end

return TestAnimatronic
