local ChapterTransitionEffect, super = Class(Object)

---@param chapter ChapterSelect.Chapter
---@param texture love.Drawable
function ChapterTransitionEffect:init(chapter, texture)
    super.init(self,  SCREEN_WIDTH, 0, SCREEN_WIDTH, SCREEN_HEIGHT)
    self:setOrigin(0.5, 0)
    self.chapter = chapter
    self.texture = texture
    self.clock = 0
end

function ChapterTransitionEffect:update()
    super.update(self)
    self.clock = self.clock + (DT * 0.7)
    if self.clock > 1 then
        self:remove()
        Game.state = "EXIT"
        Game.fader:fadeOut(function()
            Gamestate.switch({})
            -- Clear the mod
            Kristal.clearModState()

            -- Reload mods and return to memu
            Kristal.loadAssets("", "mods", "", function ()
                Kristal.loadMod(self.chapter.mod)
            end)

            Kristal.DebugSystem:refresh()
            -- End input if it's open
            if not Kristal.Console.is_open then
                TextInput.endInput()
            end
        end, {speed = 1})
    end
end

function ChapterTransitionEffect:onAdd(parent)
    super.onAdd(self, parent)
    Assets.playSound(self.chapter.sound or "ui_spooky_action")
end

function ChapterTransitionEffect:draw()
    super.draw(self)
    if self.clock > 1 then return end
    Draw.setColor(1,1,1,1-self.clock)
    love.graphics.scale(1-self.clock, 1-(self.clock / 3))
    Draw.draw(self.texture, -SCREEN_WIDTH/2, 0)
end

return ChapterTransitionEffect