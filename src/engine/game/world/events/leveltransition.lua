--- Transition between map 'levels' (floors)
---@class LevelTransition : Event
---@overload fun(x:number, y:number, shape:table, properties:table): LevelTransition
local LevelTransition, super = Class(Event)

function LevelTransition:init(x, y, shape, properties)
    super.init(self, x, y, shape)
    properties = properties or {}
    self.target_level = tostring(properties.target_level or "")
    self.require_grounded = properties.require_grounded ~= false
    self.snap_camera = properties.snap_camera == true
    self.height_sensitive = properties.height_sensitive ~= false
end

function LevelTransition:activate(subject)
    if self.target_level == "" or not self.world or not self.world.map then return end
    if self.require_grounded and subject.isGrounded and not subject:isGrounded() then return end
    if not self.world.map:getLevel(self.target_level) then
        if not self.warned_missing_level then
            self.warned_missing_level = true
            Kristal.Console:warn(string.format(
                "Level transition '%s' targets unknown level '%s'",
                tostring(self.object_id or self.name or "?"), self.target_level))
        end
        return
    end
    subject.level_override_id = self.target_level
    self.world.map:setCurrentLevel(self.target_level, self.snap_camera)
end

function LevelTransition:onEnter(character)
    if character.is_player then self:activate(character) end
end

function LevelTransition:onSoulEnter(soul)
    self:activate(soul)
end

return LevelTransition
