local OverworldActionBox, super = Utils.hookScript(OverworldActionBox)

function OverworldActionBox:update(...)
  super.update(self, ...)
  if self.name_sprite and self.chara.name == "Cassidy" then
    self.name_sprite.x = 51 - 8
  end
end

return OverworldActionBox