---@class GonerDescriptionPanel : Object
---@overload fun() : GonerDescriptionPanel
local GonerDescriptionPanel, super = Class(Object)

function GonerDescriptionPanel:init()
    super.init(self, 0, 0)

    self.operable = false
    self.opening = false
    self.closing = false
    self.closed = true
    self.visible = false
end

function GonerDescriptionPanel:open()
    self.operable = true
    self.opening = false
    self.closing = false
    self.closed = false
end

function GonerDescriptionPanel:close()
    self.operable = false
    self.opening = false
    self.closing = false
    self.closed = true
end

return GonerDescriptionPanel
