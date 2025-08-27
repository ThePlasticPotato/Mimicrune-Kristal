local spell, super = Class(Spell, "psyball")

function spell:init()
    super.init(self)

    -- Display name
    self.name = "Psyball"
    -- Name displayed when cast (optional)
    self.cast_name = nil

    -- Battle description
    self.effect = "Psychic\nBall"

    -- Menu description
    self.description = "Sends a  ball of psychic power bouncing between foes."

    -- TP cost
    self.cost = 0
    self.pcost = 30
    self.pheat = 15

    -- Target mode (ally, party, enemy, enemies, or none)
    self.target = "enemy"

    self.psychic = true

    -- Tags that apply to this spell
    self.tags = {"psy", "damage"}

    --self.cast_anim = "psywave"
end

function spell:getCastMessage(user, target)
    return "* "..user.chara:getName().." used "..self:getCastName().."!"
end

function spell:getNPCost(chara)
    local cost = super.getNPCost(self, chara)
    if chara and chara:checkWeapon("promisering") then
        cost = cost - 15
    end
    return cost
end

function spell:onCast(user, target)
    local buster_finished = false
    local anim_finished = false
    local function finishAnim()
        anim_finished = true
        if buster_finished then
            Game.battle:finishAction()
        end
    end
    if not user:setAnimation("battle/spell", finishAnim) then
        anim_finished = false
    end
    Game.battle.timer:after(15/30, function()
        Assets.playSound("psywave")
        local x, y = user:getRelativePos(user.width, user.height/2, Game.battle)
        local tx, ty = target:getRelativePos(target.width/2, target.height/2, Game.battle)
        local blast = PsyBallBall(false, x, y, tx, ty, function(pressed)
            local damage = self:getDamage(user, target, pressed)
            if pressed then
                Assets.playSound("scytheburst")
            end
            
            target:flash()
            target:hurt(damage, user)
            buster_finished = true
            if anim_finished then
                user.chara.neural_power = user.chara.neural_power - self:getNPCost(user.chara)
                user.chara.heat = user.chara.heat + self:getNHeat(user.chara)
                Game.battle:finishAction()
            end
        end)
        blast.layer = BATTLE_LAYERS["above_ui"]
        Game.battle:addChild(blast)
    end)
    return false
end

function spell:getDamage(user, target, pressed)
    local damage = math.ceil((user.chara:getStat("magic") * 4) + (user.chara:getStat("attack") * 7) - (target.defense * 3))
    if pressed then
        damage = damage + 30
    end
    return damage
end

return spell