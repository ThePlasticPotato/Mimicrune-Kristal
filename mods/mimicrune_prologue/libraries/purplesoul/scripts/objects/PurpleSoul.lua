---@class PurpleSoul : Soul
local PurpleSoul, super = Class(Soul)

function PurpleSoul:init(x, y, color)
    super.init(self, x, y, color)

    --set the soul's color to purple
    self.color = { 252/255, 0, 1 }

    --create CircleColliders at the left and right of the soul to check if its on a string
    self.leftStringCollider = CircleCollider(self, -14, 0, 5)
    self.rightStringCollider = CircleCollider(self, 14, 0, 5)

    --create LineColliders going up and down from the soul to search for possible strings it can move to(used in PurpleSoul:handleStringMovement())
    self.upCollider = LineCollider(self, 0, -4, 0, -480)
    self.downCollider = LineCollider(self, 0, 4, 0, 480)

    --the current string the soul is on
    self.currentString = nil
    --the string it should move to when moving strings
    self.targetString = nil
    --movement variable for moving left and right, -1 tells it it should move left if it can and 1 is right, left and right colliders do need to be on the current string for their respective directions to work
    self.movement = 0
    --the progress of the soul on its current string, the progress is a range between the string's bounds going from 0(left bound) to 1(right bound)
    self.progress = 0.15
    --the speed the soul moves at
    self.movement_speed = 40
    --the soul's state, used for logic stuff
    self.state = "ON_STRING" -- used states: ON_STRING, OUTSIDE_STRING, MOVING

    --these variables are set when the soul moves to another string, they're used to lerp the soul from their last position on a string to their new position on a string
    self.old_y = 0
    self.old_x = 0
    --the new progress the player should be at on the new string when they move a string, idk why I called it percentage
    self.newStringPercentage = 0.5
    --variable used as the alpha for the lerp moving the soul from one string to the other
    self.stringLerp = 0
    --the direction the soul moves when moving a string, decided by the input the player uses, -1 is up and 1 is down
    self.dir = -1
    --this is used later when the soul tries to find a suitable string to move to, it will try 3 times(3 frames in a row) before giving up
    self.tries = 3

    --functions used to interchange the directions the player needs to press to move, if correctControlsForRotation is on the controls will change depending on the string's rotation
    self.downEquivalentInput = function ()
        return Input.keyDown("down")
    end
    self.upEquivalentInput = function ()
        return Input.keyDown("up")
    end
    self.leftEquivalentInput = function ()
        return Input.keyDown("left")
    end
    self.rightEquivalentInput = function ()
        return Input.keyDown("right")
    end
end

--function that changes the controls depending on the string's rotation and whether diagonalControls and directionalJumps are on
function PurpleSoul:getMovementKeys()
    if Kristal.getLibConfig("purplesoulskerchv2", "diagonalControls") and Kristal.getLibConfig("purplesoulskerchv2", "directionalJumps")  then
        if self.currentString.rot%(math.pi*2) >= math.rad(-45/2) and self.currentString.rot%(math.pi*2) <= math.rad(45/2) then
            self.downEquivalentInput = function ()
                return Input.keyDown("down")
            end
            self.upEquivalentInput = function ()
                return Input.keyDown("up")
            end
            self.leftEquivalentInput = function ()
                return Input.keyDown("left")
            end
            self.rightEquivalentInput = function ()
                return Input.keyDown("right")
            end
        elseif self.currentString.rot%(math.pi*2) >= math.rad(45-45/2) and self.currentString.rot%(math.pi*2) <= math.rad(45+45/2) then
            self.downEquivalentInput = function ()
                return Input.keyDown("down") and Input.keyDown("left")
            end
            self.upEquivalentInput = function ()
                return Input.keyDown("up") and Input.keyDown("right")
            end
            self.leftEquivalentInput = function ()
                return Input.keyDown("left") and Input.keyDown("up")
            end
            self.rightEquivalentInput = function ()
                return Input.keyDown("right") and Input.keyDown("down")
            end
        elseif self.currentString.rot%(math.pi*2) >= math.rad(90-45/2) and self.currentString.rot%(math.pi*2) <= math.rad(90+45/2) then
            self.downEquivalentInput = function ()
                return Input.keyDown("left")
            end
            self.upEquivalentInput = function ()
                return Input.keyDown("right")
            end
            self.leftEquivalentInput = function ()
                return Input.keyDown("up")
            end
            self.rightEquivalentInput = function ()
                return Input.keyDown("down")
            end
        elseif self.currentString.rot%(math.pi*2) >= math.rad(135-45/2) and self.currentString.rot%(math.pi*2) <= math.rad(135+45/2) then
            self.downEquivalentInput = function ()
                return Input.keyDown("up") and Input.keyDown("left")
            end
            self.upEquivalentInput = function ()
                return Input.keyDown("down") and Input.keyDown("right")
            end
            self.leftEquivalentInput = function ()
                return Input.keyDown("left") and Input.keyDown("down")
            end
            self.rightEquivalentInput = function ()
                return Input.keyDown("right") and Input.keyDown("up")
            end
        elseif self.currentString.rot%(math.pi*2) >= math.rad(180-45/2) and self.currentString.rot%(math.pi*2) <= math.rad(180+45/2) then
            self.downEquivalentInput = function ()
                return Input.keyDown("up")
            end
            self.upEquivalentInput = function ()
                return Input.keyDown("down")
            end
            self.leftEquivalentInput = function ()
                return Input.keyDown("right")
            end
            self.rightEquivalentInput = function ()
                return Input.keyDown("left")
            end
        elseif self.currentString.rot%(math.pi*2) >= math.rad(225-45/2) and self.currentString.rot%(math.pi*2) <= math.rad(225+45/2) then
            self.downEquivalentInput = function ()
                return Input.keyDown("up") and Input.keyDown("right")
            end
            self.upEquivalentInput = function ()
                return Input.keyDown("down") and Input.keyDown("left")
            end
            self.leftEquivalentInput = function ()
                return Input.keyDown("right") and Input.keyDown("down")
            end
            self.rightEquivalentInput = function ()
                return Input.keyDown("left") and Input.keyDown("up")
            end
        elseif self.currentString.rot%(math.pi*2) >= math.rad(270-45/2) and self.currentString.rot%(math.pi*2) <= math.rad(270+45/2) then
            self.downEquivalentInput = function ()
                return Input.keyDown("right")
            end
            self.upEquivalentInput = function ()
                return Input.keyDown("left")
            end
            self.leftEquivalentInput = function ()
                return Input.keyDown("down")
            end
            self.rightEquivalentInput = function ()
                return Input.keyDown("up")
            end
        elseif self.currentString.rot%(math.pi*2) >= math.rad(315-45/2) and self.currentString.rot%(math.pi*2) <= math.rad(315+45/2) then
            self.downEquivalentInput = function ()
                return Input.keyDown("down") and Input.keyDown("right")
            end
            self.upEquivalentInput = function ()
                return Input.keyDown("up") and Input.keyDown("left")
            end
            self.leftEquivalentInput = function ()
                return Input.keyDown("left") and Input.keyDown("down")
            end
            self.rightEquivalentInput = function ()
                return Input.keyDown("right") and Input.keyDown("up")
            end
        end
    else
        if self.currentString.rot%(math.pi*2) >= math.rad(-45/2) and self.currentString.rot%(math.pi*2) <= math.rad(45/2) then
            self.downEquivalentInput = function ()
                return Input.keyDown("down")
            end
            self.upEquivalentInput = function ()
                return Input.keyDown("up")
            end
            self.leftEquivalentInput = function ()
                return Input.keyDown("left")
            end
            self.rightEquivalentInput = function ()
                return Input.keyDown("right")
            end
        elseif self.currentString.rot%(math.pi*2) >= math.rad(45-45/2) and self.currentString.rot%(math.pi*2) <= math.rad(45+45/2) then
            self.downEquivalentInput = function ()
                return Input.keyDown("down")
            end
            self.upEquivalentInput = function ()
                return Input.keyDown("up")
            end
            self.leftEquivalentInput = function ()
                return Input.keyDown("left")
            end
            self.rightEquivalentInput = function ()
                return Input.keyDown("right")
            end
        elseif self.currentString.rot%(math.pi*2) >= math.rad(90-45/2) and self.currentString.rot%(math.pi*2) <= math.rad(90+45/2) then
            self.downEquivalentInput = function ()
                return Input.keyDown("left")
            end
            self.upEquivalentInput = function ()
                return Input.keyDown("right")
            end
            self.leftEquivalentInput = function ()
                return Input.keyDown("up")
            end
            self.rightEquivalentInput = function ()
                return Input.keyDown("down")
            end
        elseif self.currentString.rot%(math.pi*2) >= math.rad(135-45/2) and self.currentString.rot%(math.pi*2) <= math.rad(135+45/2) then
            if Kristal.getLibConfig("purplesoulskerchv2", "directionalJumps") then
                self.downEquivalentInput = function ()
                    return Input.keyDown("up")
                end
                self.upEquivalentInput = function ()
                    return Input.keyDown("down")
                end
            else
                self.downEquivalentInput = function ()
                    return Input.keyDown("down")
                end
                self.upEquivalentInput = function ()
                    return Input.keyDown("up")
                end
            end
            self.leftEquivalentInput = function ()
                return Input.keyDown("right")
            end
            self.rightEquivalentInput = function ()
                return Input.keyDown("left")
            end
        elseif self.currentString.rot%(math.pi*2) >= math.rad(180-45/2) and self.currentString.rot%(math.pi*2) <= math.rad(180+45/2) then
            if Kristal.getLibConfig("purplesoulskerchv2", "directionalJumps") then
                self.downEquivalentInput = function ()
                    return Input.keyDown("up")
                end
                self.upEquivalentInput = function ()
                    return Input.keyDown("down")
                end
            else
                self.downEquivalentInput = function ()
                    return Input.keyDown("down")
                end
                self.upEquivalentInput = function ()
                    return Input.keyDown("up")
                end
            end
            self.leftEquivalentInput = function ()
                return Input.keyDown("right")
            end
            self.rightEquivalentInput = function ()
                return Input.keyDown("left")
            end
        elseif self.currentString.rot%(math.pi*2) >= math.rad(225-45/2) and self.currentString.rot%(math.pi*2) <= math.rad(225+45/2) then
            if Kristal.getLibConfig("purplesoulskerchv2", "directionalJumps") then
                self.downEquivalentInput = function ()
                    return Input.keyDown("up")
                end
                self.upEquivalentInput = function ()
                    return Input.keyDown("down")
                end
            else
                self.downEquivalentInput = function ()
                    return Input.keyDown("down")
                end
                self.upEquivalentInput = function ()
                    return Input.keyDown("up")
                end
            end
            self.leftEquivalentInput = function ()
                return Input.keyDown("right")
            end
            self.rightEquivalentInput = function ()
                return Input.keyDown("left")
            end
        elseif self.currentString.rot%(math.pi*2) >= math.rad(270-45/2) and self.currentString.rot%(math.pi*2) <= math.rad(270+45/2) then
            self.downEquivalentInput = function ()
                return Input.keyDown("right")
            end
            self.upEquivalentInput = function ()
                return Input.keyDown("left")
            end
            self.leftEquivalentInput = function ()
                return Input.keyDown("down")
            end
            self.rightEquivalentInput = function ()
                return Input.keyDown("up")
            end
        elseif self.currentString.rot%(math.pi*2) >= math.rad(315-45/2) and self.currentString.rot%(math.pi*2) <= math.rad(315+45/2) then
            self.downEquivalentInput = function ()
                return Input.keyDown("down")
            end
            self.upEquivalentInput = function ()
                return Input.keyDown("up")
            end
            self.leftEquivalentInput = function ()
                return Input.keyDown("left")
            end
            self.rightEquivalentInput = function ()
                return Input.keyDown("right")
            end
        end
    end
end
--this is a long one huh

--movement logic
function PurpleSoul:doMovement()
    --if the soul is on the string
    if self.state == "ON_STRING" then
        --if the soul's collider detects it's on the current string
        if self.collider:collidesWith(self.currentString.collider) then
            --movement stuff
            if self.rightStringCollider:collidesWith(self.currentString,collider) and self.movement == 1 then
                self.progress = self.progress + self.movement_speed/self.currentString.len*DTMULT
                self.movement = 0
            end
            if self.leftStringCollider:collidesWith(self.currentString,collider) and self.movement == -1 then
                self.progress = self.progress - self.movement_speed/self.currentString.len*DTMULT
                self.movement = 0
            end
        end
    --if the soul is moving to another string
    elseif self.state == "MOVING" and self.targetString then
        --movement stuff
        if self.progress < 1 and self.progress > 0 then
            self.newStringPercentage = math.max(0.05, math.min(0.95, self.newStringPercentage + self.movement_speed/self.targetString.len*self.movement*DTMULT))
            self.movement = 0
        end
    end
end

--input logic
function PurpleSoul:handleInputs()
    --if the correctControlsForRotation config is on call the getMovementKeys function
    if Kristal.getLibConfig("purplesoulskerchv2", "correctControlsForRotation") then
        self:getMovementKeys()
    end

    --if the soul is on a string
    if self.state == "ON_STRING" then
        --left and right equivalent inputs(moving in a string)
        if self.rightEquivalentInput() then
            self.movement = 1
        elseif self.leftEquivalentInput() then
            self.movement = -1
        end

        --up and down equivalent inputs(moving between strings)
        if self.upEquivalentInput() then
            self.state = "MOVING"
            self.dir = -1
            self.movement = 0
            if Kristal.getLibConfig("purplesoulskerchv2", "directionalJumps") then
                self.rotation = self.currentString.rot
            else
                if not Kristal.getLibConfig("purplesoulskerchv2", "visuallyRotateSoul") then
                    self.sprite.rotation = self.currentString.rot
                end
            end
        elseif self.downEquivalentInput() then
            self.state = "MOVING"
            self.dir = 1
            self.movement = 0
            if Kristal.getLibConfig("purplesoulskerchv2", "directionalJumps") then
                self.rotation = self.currentString.rot
            else
                if not Kristal.getLibConfig("purplesoulskerchv2", "visuallyRotateSoul") then
                    self.sprite.rotation = self.currentString.rot
                end
            end
        end
    --if the soul is moving to another string and it found a string to move to(the MOVING state is also used for 1-3 frames while it's searching for a new string)
    elseif self.state == "MOVING" and self.targetString then
        --being able to move a bit left and right while moving strings
        if self.rightEquivalentInput() then
            self.movement = 1
        elseif self.leftEquivalentInput() then
            self.movement = -1
        end
    end
end

function PurpleSoul:update()
    super.update(self)

    --call the functions that should go every frame
    self:handleInputs()
    self:handleStringMovement()

    --if the soul is on a string and it has a current string(somehow doesn't happen sometimes?)
    if self.currentString and self.state == "ON_STRING" then
        --sets the soul's position and rotation/sprite rotation/no rotation(depending on the config) to match the current string's
        local x, y = self.currentString:getPositionBetweenBounds(self.progress)
        self:setPosition(self.currentString.x+x, self.currentString.y+y)
        if Kristal.getLibConfig("purplesoulskerchv2", "directionalJumps") then
            self.rotation = self.currentString.rot
        else
            if not Kristal.getLibConfig("purplesoulskerchv2", "visuallyRotateSoul") then
                self.sprite.rotation = self.currentString.rot
            end
        end
    end

    --if the soul doesn't have a string or is not on a string while not moving strings set its state to OUTSIDE_STRING
    if not self.currentString or ((not self.collider:collidesWith(self.currentString.collider)) and not self.state == "MOVING") then
        self.state = "OUTSIDE_STRING"
    end

    --if visuallyRotateSoul is off then change its sprite's rotation to match the soul's rotation to make it look like it's not rotating 
    if not Kristal.getLibConfig("purplesoulskerchv2", "visuallyRotateSoul") then
        self.sprite.rotation = -self.rotation
    end

    --if directionalJumps is off then rotate the string colliders to make up for how it's meant to be rotated usualy(turning off directionalJumps mostly stops the soul from rotating to match the string)
    if not Kristal.getLibConfig("purplesoulskerchv2", "directionalJumps") then
        self.leftStringCollider.x = self:lengthDirX(0, 14, math.pi+self.currentString.rot)
        self.leftStringCollider.y = self:lengthDirY(0, 14, math.pi+self.currentString.rot)
        self.rightStringCollider.x = self:lengthDirX(0, 14, self.currentString.rot)
        self.rightStringCollider.y = self:lengthDirY(0, 14, self.currentString.rot)
    end
end

--get the the X location of a point on the end of a line that's l away from x in the direction of r
function PurpleSoul:lengthDirX(x, l, r)
    return x+l*math.cos(r)
end

--get the the Y location of a point on the end of a line that's l away from y in the direction of r
function PurpleSoul:lengthDirY(y, l, r)
    return y+l*math.sin(r)
end

--oh boy this is a long one, this function handles the string movment, finding the closest string to the soul in the direction it's moving and then moving it to the correct spot on the string
function PurpleSoul:handleStringMovement()
    --if the state is MOVING but it hasn't found a suitable string to move to yet
    if self.state == "MOVING" and not self.targetString then
        --set the soul's position to the correct position just in case
        local x, y = self.currentString:getPositionBetweenBounds(self.progress)
        self:setPosition(self.currentString.x+x, self.currentString.y+y)

        --set the soul's rotation/whatever to the correct rotation just in case
        if Kristal.getLibConfig("purplesoulskerchv2", "directionalJumps") then
            self.rotation = self.currentString.rot
        else
            if not Kristal.getLibConfig("purplesoulskerchv2", "visuallyRotateSoul") then
                self.sprite.rotation = self.currentString.rot
            end
        end

        --setting up some local variables/functions for the longest collision check I've ever seen and made
        local potentialTargets = {}
        local intersectionPoints = {}
        local closestTargetIndex = 0
        local closestTargetDistance = math.huge
        local simplify = function (num)
            return Utils.round(num*1000)/1000
        end

        --this check looks at all the strings and if they collide with the correct direction's collider(and aren't the current string) it checks where they collide with 
        --it(or more like a line equivalent to it) and stores them and their intersection points in two tables
        for _, obj in ipairs(Game.battle.children) do
            if obj:includes(PurpleString) then
                if ((self.upCollider:collidesWith(obj.collider) and self.dir == -1) or (self.downCollider:collidesWith(obj.collider) and self.dir == 1)) and obj ~= self.currentString then
                    local a = (math.rad(270)+self.rotation)+((self.dir == 1 and math.pi) or 0)
                    local intersection_x, intersection_y = self:getLineIntersect(
                        simplify(self:lengthDirX(self.x, 4, a)), simplify(self:lengthDirY(self.y, 4, a)), simplify(self:lengthDirX(self.x, 480, a)), simplify(self:lengthDirY(self.y, 480, a)),
                        simplify(obj.x+obj.leftBound.x), simplify(obj.y+obj.leftBound.y), simplify(obj.x+obj.rightBound.x), simplify(obj.y+obj.rightBound.y),
                        false, true
                    )
                    if type(intersection_x) ~= "boolean" then
                        table.insert(potentialTargets, obj)
                        table.insert(intersectionPoints, {intersection_x, intersection_y})
                    end
                end
            end
        end

        --if there were no potential target strings found then try again the next frame until tries run out
        local continue = true

        if #potentialTargets <= 0 then
            if self.tries <= 0 then
                self.state = "ON_STRING"
                return true
            else
                self.tries = self.tries - DTMULT
                continue = false
            end
        end

        --if it did find at least one potential target then check the closest intersection point and put the string that matches to it as the target string, 
        --as well as calculating the soul's new location based on it
        if continue then
            for k, intersection in ipairs(intersectionPoints) do
                if Utils.dist(self.x, self.y, intersection[1], intersection[2]) < closestTargetDistance then
                    closestTargetIndex = k
                    closestTargetDistance = Utils.dist(self.x, self.y, intersection[1], intersection[2])
                end
            end

            self.targetString = potentialTargets[closestTargetIndex]
            self.newStringPercentage = self.targetString:getProgressFromLocation(intersectionPoints[closestTargetIndex][1], intersectionPoints[closestTargetIndex][2])
            self.old_x = self.x
            self.old_y = self.y 
        end
    end
    --if the state is MOVING and it does have a target(if it found one earlier)
    if self.state == "MOVING" and self.targetString then
        --execute a lerp moving the player from their old position to the new position calculated from the new position set from the intersection point
        if self.stringLerp < 1 then
            local x, y = self.targetString:getPositionBetweenBounds(self.newStringPercentage)
            self.x = Utils.lerp(self.old_x, self.targetString.x+x, self.stringLerp)
            self.y = Utils.lerp(self.old_y, self.targetString.y+y, self.stringLerp)
            self.stringLerp = math.min(1, self.stringLerp+DTMULT/4)
        else
            self.currentString = self.targetString
            self.targetString = nil
            self.stringLerp = 0
            self.progress = self.newStringPercentage
            self.state = "ON_STRING"
        end
    end
end

--finds the intersection point of two lines based on four points(if there is an intersection point)
--seg1 and 2 make it treat lines 1 and 2 respectively as segments going from one point to another instead of endless lines
--wont be necessary if my PR is accepted.
function PurpleSoul:getLineIntersect(x1, y1, x2, y2, x3, y3, x4, y4, seg1, seg2)
    -- Get the slopes of the lines
    local m1 = (y1-y2)/(x1-x2)
    local m2 = (y3-y4)/(x3-x4)

    -- Get the offsets of the lines
    local b1 = -(m1*x1-y1) or y1
    local b2 = -(m2*x3-y3) or y3

    -- Make x and y variables
    local x = nil
    local y = nil

    -- Check whether any of the lines are vertical
    if (x1-x2) == 0 then
        -- Find x and y
        x = x1
        y = m2*x+b2
    elseif (x3-x4) == 0 then
        -- Find x and y
        x = x3
        y = m1*x+b1
    else
        -- Find x and y
        x = (b2-b1)/(m1-m2)
        y = m1*x+b1
    end
 
    -- Check if the lines are parallel or the same
    if m1 == m2 and b1 ~= b2 then
        return false, "The lines are parallel."
    elseif m1 == m2 and b1 == b2 then
        return false, "The lines are the same."
    end

    -- Check if x and y are out of the segment bounds
    if seg1 or seg2 then
        local min,max = math.min, math.max
        if seg1 and (x<min(x1, x2) or x>max(x1, x2) or y<min(y1, y2) or y>max(y1, y2)) then
            return false, "The lines don't intersect." 
        end
        if seg2 and (x<min(x3, x4) or x>max(x3, x4) or y<min(y3, y4) or y>max(y3, y4)) then
            return false, "The lines don't intersect." 
        end
    end
    
    return x, y
end

--draw debug stuff
function PurpleSoul:draw()

    super.draw(self)
    
    if DEBUG_RENDER then
        self.collider:draw(0, 1, 0)
        self.graze_collider:draw(1, 1, 1, 0.33)
        self.leftStringCollider:draw(1, 0, 1)
        self.rightStringCollider:draw(1, 0, 1)
    end
end


return PurpleSoul
