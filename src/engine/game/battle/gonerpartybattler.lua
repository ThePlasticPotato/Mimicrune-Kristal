---@class GonerPartyBattler : PartyBattler
---@overload fun(chara:PartyMember, x?:number, y?:number) : GonerPartyBattler
local GonerPartyBattler, super = Class(PartyBattler)

function GonerPartyBattler:createSprite(use_overlay)
    super.createSprite(self, use_overlay)

    self.sprite.animation_namespace = "gonerbattle"
    self.sprite.use_texture_size = true
    self.sprite:setOrigin(0.25, 1)

    if self.overlay_sprite then
        self.overlay_sprite.animation_namespace = "gonerbattle"
        self.overlay_sprite.use_texture_size = true
        self.overlay_sprite:setOrigin(0.25, 1)
    end
end

function GonerPartyBattler:init(chara, x, y)
    super.init(self, chara, x, y)

    self:setOrigin(0, 0)
    self:setScale(2)
end

return GonerPartyBattler
