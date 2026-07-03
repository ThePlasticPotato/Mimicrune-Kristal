---@class Bust : Object
local Bust, super = Class(Object)

function Bust:init(actor, body, face, x, y)
    super.init(self, x, y)

    body = body or (actor and "idle") or nil
    face = face or (actor and "neutral") or nil

    self.actor = nil
    self.body_name = nil
    self.face_name = nil
    self.face_offsets = {}

    self.body = Sprite(nil)
    self.body.layer = 0
    self:addChild(self.body)

    self.face = Sprite(nil)
    self.face.layer = 1
    self:addChild(self.face)

    local body_set_frame = self.body.setFrame
    self.body.setFrame = function(sprite, frame)
        body_set_frame(sprite, frame)
        self:updateFacePosition()
    end

    self.debug_select = false

    if actor then
        self:setActor(actor)
    end
    if body then
        self:setBody(body)
    end
    if face then
        self:setFace(face)
    end
end

function Bust:setActor(actor)
    if type(actor) == "string" then
        actor = Registry.createActor(actor)
    end

    self.actor = actor
    self.body.path = actor and actor:getBustPath() or ""
    self.face.path = actor and actor:getBustFacePath() or ""
end

function Bust:hasBody(body)
    return self.actor and body and self.actor:hasBust(body)
end

function Bust:setBody(body, speed)
    if not self:hasBody(body) then
        return false
    end

    local data = self.actor:getBust(body)
    local body_path = data[1]

    if not self.body:hasSprite(body_path) then
        return false
    end

    self.body_name = body
    self.face_offsets = data[2] or {}
    self.body:setSprite(body_path)
    self.body:play(speed or 0.2, true)
    self.width = self.body.width
    self.height = self.body.height
    self:updateFacePosition()

    return true
end

function Bust:setFace(face, speed)
    self.face_name = face
    if not face then
        self.face:setSprite(nil)
        self.face.visible = false
        return true
    end

    self.face.path = self.actor and self.actor:getBustFacePath() or ""
    if not self.face:hasSprite(face) and self.actor and self.actor:getPortraitPath() then
        self.face.path = self.actor:getPortraitPath()
    end

    if not self.face:hasSprite(face) then
        self.face:setSprite(nil)
        self.face.visible = false
        return false
    end

    self.face:setSprite(face)
    self.face:play(speed or (4 / 30))
    self:updateFacePosition()
    return true
end

function Bust:updateFacePosition()
    if not self.face_name or not self.face.texture then
        self.face.visible = false
        return
    end

    local offset = self.face_offsets[self.body.frame or 1]
    if offset then
        self.face:setPosition(offset[1] or 0, offset[2] or 0)
        self.face.visible = true
    else
        self.face.visible = false
    end
end

function Bust:stop(keep_frame)
    self.body:stop(keep_frame)
    self.face:stop(keep_frame)
end

return Bust
