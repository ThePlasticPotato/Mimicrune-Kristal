---@class ActorSprite
local ActorSprite, super = HookSystem.hookScript(ActorSprite)

function ActorSprite:draw()
    super.draw(self)

    local texture = (type(self.texture) == "string") and
        Assets.getTexture(self.texture)
    or
        self.texture

    -- if Atmosphere:getCurrentTime() == "dawn" then
    --     texture = self.texture
    -- elseif Atmosphere:getCurrentTime() == "evening" then
    --     local path = self.actor:getEveningShadow(sprite)
    --     local frames = path and Assets.getFrames(path)
    --     texture = path and (Assets.getTexture(path) or
    --         (frames and frames[sprite.frame])) or sprite.texture
    -- end

    if not texture then
        return
    end

    local color
    local alpha

    --- temporarily disabling this for now
    if false and Atmosphere:getCurrentTime() == "dawn" then
        color = {13 / 255, 5 / 255, 56 / 255}
        alpha = 0.3
    elseif false and Atmosphere:getCurrentTime() == "evening" then
        color = {35 / 255, 0, 35 / 255}
        alpha = 0.5
    else
        return
    end

    local old_r, old_g, old_b, old_a = love.graphics.getColor()

    Draw.setColor(self:getDrawColor())
    Draw.pushShader("palettes/shadowblend", {
        shadow_color = color,
        shadow_alpha = alpha,
    })
    Draw.draw(texture)
    Draw.popShader()

    Draw.setColor(old_r, old_g, old_b, old_a)
end

return ActorSprite