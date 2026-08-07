---A door, either of an actual door or a vent or whatever. Drains power only when closed.
---@class OfficeDoor : Object, PowerDrainer
local OfficeDoor, super = Class(Object)

---@alias DoorState
---| "OPENING"
---| "OPEN"
---| "CLOSING"
---| "CLOSED"

return OfficeDoor