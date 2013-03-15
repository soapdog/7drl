Level = class('Level')

function Level:initialize(opts)
    -- Possible enemies to spawn and possible chest items
    self.enemies = opts.enemies ; assert(self.enemies and self.enemies:length() > 0)
    self.chest_items = opts.chest_items ; assert(self.chest_items and self.chest_items:length() > 0)

    -- If an enemy rate is 0.1, then we draw an enemy every 10 cells
    -- There's a separate rate for halls and rooms
    self.hall_enemy_rate = opts.hall_enemy_rate ; assert(self.hall_enemy_rate)
    self.room_enemy_rate = opts.room_enemy_rate ; assert(self.room_enemy_rate)

    -- Odds that we'll put a chest in a room, from 0 to 1
    self.chest_chance = opts.chest_chance ; assert(self.chest_chance)

    -- Never place a chest in rooms with fewer than this many enemies
    self.chest_guards = opts.chest_guards or 0

    -- Min and max for gold pile sizes
    self.gold_range = opts.gold_range ; assert(type(self.gold_range) == 'table' and #self.gold_range == 2)
end

-- Returns a randomly-filled chest
function Level:chest()
    local c1 = self.chest_items:random()
    local c2 = self.chest_items:random()

    -- Make sure we give 'em a choice...
    if c1 == c2 then return self:chest() end

    -- Most items don't take any args, but gold takes an amount
    local i1 = c1(math.random(unpack(self.gold_range)))
    local i2 = c2(math.random(unpack(self.gold_range)))

    return Chest(i1, i2)
end

--------------------------------------------------

local HP = HealthPotion ; local G = Gold

Level.static.LEVELS = {
    -- 1 --------------------
    Level{
        enemies = List{Orc},
        chest_items = List{HP, HP, G, ShortSword, Hammer},
        -- chest_items = List{ShortSword, Hammer, Spear, Longsword, Mace},
        gold_range = {10, 20},
        hall_enemy_rate = 0,
        room_enemy_rate = 0.1,
        chest_chance = 0.5,
        chest_guards = 0,
    },

    -- 2 --------------------
    Level{
        enemies = List{Orc, Skeleton},
        chest_items = List{HP, HP, G, Axe, Longsword},
        gold_range = {50, 120},
        hall_enemy_rate = 0,
        room_enemy_rate = 0.15,
        chest_chance = 0.5,
        chest_guards = 1,
    },

    -- 3 --------------------
    Level{
        enemies = List{Orc, Skeleton, Skeleton},
        chest_items = List{HP, G, Axe, Longsword},
        gold_range = {90, 200},
        hall_enemy_rate = 0.1,
        room_enemy_rate = 0.2,
        chest_chance = 0.5,
        chest_guards = 2,
    },

    -- 4 --------------------
    Level{
        enemies = List{Orc, Skeleton, Skeleton, Troll},
        chest_items = List{HP, G, Spear, Mace, },
        gold_range = {150, 300},
        hall_enemy_rate = 0.1,
        room_enemy_rate = 0.2,
        chest_chance = 0.5,
        chest_guards = 2,
    },

    -- 5 --------------------
    Level{
        enemies = List{Skeleton, Skeleton, Troll},
        chest_items = List{HP, G, G,},
        gold_range = {250, 500},
        hall_enemy_rate = 0.15,
        room_enemy_rate = 0.2,
        chest_chance = 0.5,
        chest_guards = 2,
    },

    -- 6 --------------------
    Level{
        enemies = List{Skeleton, Troll},
        chest_items = List{HP, G, G,},
        gold_range = {300, 800},
        hall_enemy_rate = 0.15,
        room_enemy_rate = 0.2,
        chest_chance = 0.5,
        chest_guards = 2,
    },
}

--------------------------------------------------

return Level