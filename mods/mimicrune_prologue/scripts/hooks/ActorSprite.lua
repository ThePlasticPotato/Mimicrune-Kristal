---@class ActorSprite
local ActorSprite, super = HookSystem.hookScript(ActorSprite)

-- function ActorSprite:init(...)
--     super.init(...)
--     self.current_default = nil
--     if (self.actor) then self.current_default = self.actor:getDefault() end
-- end

function ActorSprite:resetSprite(ignore_actor_callback)
    if not ignore_actor_callback and self.actor:preResetSprite(self) then
        return
    end
    if self.actor:getDefaultAnim() then
        self:setAnimation(self.actor:getDefaultAnim())
    elseif self.actor:getDefaultSprite() then
        self:setSprite(self.actor:getDefaultSprite())
    else
        self.current_default = self.actor:getDefault()
        self:set(self.actor:getDefault())
    end
    self.actor:onResetSprite(self)
end

function ActorSprite:update()
    if self.actor:preSpriteUpdate(self) then
        return
    end

    local flip_dir
    for _,sprite in ipairs(self.sprite_options) do
        flip_dir = self.actor:getFlipDirection(sprite)
        if flip_dir then break end
    end

    if flip_dir then
        if not self.directional then
            local opposite = flip_dir == "right" and "left" or "right"
            if self.facing == flip_dir then
                self.flip_x = true
            elseif self.facing == opposite then
                self.flip_x = false
            end
        else
            self.flip_x = false
        end
        self.last_flippable = true
    elseif self.last_flippable then
        self.last_flippable = false
        self.flip_x = false
    end

    if not self.playing then
        local floored_frame = math.floor(self.walk_frame)
        if floored_frame ~= self.walk_frame or ((self.directional or self.walk_override) and self.walking) then
            self.walk_frame = MathUtils.approach(self.walk_frame, floored_frame + 1, DT * (self.walk_speed > 0 and self.walk_speed or 1))
            local last_frame = self.frame
            local reference = self.actor:getDefault() == "run" and 3 or 2
            self:setFrame(floored_frame)
            if self.frame ~= last_frame and self.on_footstep and self.frame % reference == 0 then
                self.on_footstep(self, math.floor(self.frame/reference))
            end
        elseif (self.directional or self.walk_override) and self.frames and not self.walking then
            self:setFrame(1)
        end

        self:updateDirection()
    end

    if self.aura then
        self.aura_siner = self.aura_siner + 0.25 * DTMULT
    end

    if self.run_away then
        self.run_away_timer = self.run_away_timer + DTMULT
    end

    super.super.update(self)

    self.actor:onSpriteUpdate(self)
end

return ActorSprite