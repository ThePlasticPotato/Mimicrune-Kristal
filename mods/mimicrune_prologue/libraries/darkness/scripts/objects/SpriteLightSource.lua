local SpriteLightSource, super = Class(Object)

function SpriteLightSource:init(x, y, sprite, scale_x, scale_y, color)
    super.init(self, x, y)
    self.sprite = sprite
    self.scale_x = scale_x
    self.scale_y = scale_y
    self.color = color or {1,1,1}
    self.alpha = 1
    self.inherit_color = false
    self.style = Kristal.getLibConfig("darkness", "style")
    -- don't allow debug selecting
    self.debug_select = false
end

---@return love.Image
function SpriteLightSource:getSprite()
    if type(self.sprite) == "string" then
        return Assets.getTexture(self.sprite)
    else
        return self.sprite
    end
end

return SpriteLightSource