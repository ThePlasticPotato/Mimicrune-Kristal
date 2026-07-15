local DialogueText, super = HookSystem.hookScript(DialogueText)

function DialogueText:resetState()
    super.resetState(self)
    self.state["temp_shake"] = 0
    self.state["last_temp_shake"] = self.timer
end

return DialogueText