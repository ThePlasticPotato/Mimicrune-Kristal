local ActionBox, super = Utils.hookScript(ActionBox)

function ActionBox:update(...)
  super.update(self, ...)
  if self.name_sprite and self.battler.chara.name == "Cassidy" then
    self.name_sprite.x = 51 - 8
  end
end

return ActionBox