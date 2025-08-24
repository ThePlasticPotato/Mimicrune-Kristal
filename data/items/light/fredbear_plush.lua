local item, super = Class(Item, "fredbear_plush")

function item:init()
    super.init(self)

    -- Display name
    self.name = "Fredbear Plush"
    -- Name displayed when used in battle (optional)
    self.use_name = nil

    -- Item type (item, key, weapon, armor)
    self.type = "key"
    -- Item icon (for equipment)
    self.icon = "ui/menu/icon/armor"
    -- Whether this item is for the light world
    self.light = true

    -- Light world check text
    self.check = "Fredbear! A trusty companion\nof fabric and cotton."

    -- Default shop price (sell price is halved)
    self.price = 0
    -- Whether the item can be sold
    self.can_sell = false

    -- Consumable target mode (ally, party, enemy, enemies, or none)
    self.target = "none"
    -- Where this item can be used (world, battle, all, or none)
    self.usable_in = "world"
end

function item:onToss()
    Game.world:startCutscene(function(cutscene)
        cutscene:setSpeaker("evan")
        cutscene:text("* Why[wait:5] would I do[wait:5] that?", "disapproval")
    end)
    return false
end

function item:onWorldUse(target)
    Assets.playSound("honk")
end

return item