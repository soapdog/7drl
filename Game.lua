Game = class('Game')

Game:include(Drawing)

function Game.static.setup()
    Game.images = {}

    Game.images.chars = love.graphics.newImage("art/characters-32x32.png")
    Game.images.walls = love.graphics.newImage("art/wall-tiles-40x40.png")
    Game.images.floors = love.graphics.newImage("art/floor-tiles-20x20.png")
    Game.images.equipment = love.graphics.newImage("art/equipment-32x32.png")
    Game.images.extras = love.graphics.newImage("art/extras-32x32.png")
    Game.images.decoration = love.graphics.newImage("art/decoration-20x20-40x40.png")

    Game.quads = {
        player = love.graphics.newQuad(0, 0, 32, 32, 320, 32),
        floor = love.graphics.newQuad(340, 0, 20, 20, 400, 260),
        hall_floor = love.graphics.newQuad(160, 80, 20, 20, 400, 260),
        door = love.graphics.newQuad(40, 200, 40, 40, 120, 260),
        open_door = love.graphics.newQuad(80, 200, 40, 40, 120, 260),
    }

    Game.quads.walls = {
        se = love.graphics.newQuad(20, 20, 20, 20, 520, 160),
        sw = love.graphics.newQuad(80, 20, 20, 20, 520, 160),
        ne = love.graphics.newQuad(20, 80, 20, 20, 520, 160),
        nw = love.graphics.newQuad(80, 80, 20, 20, 520, 160),

        s = love.graphics.newQuad(40, 20, 40, 20, 520, 160),
        n = love.graphics.newQuad(40, 80, 40, 20, 520, 160),
        e = love.graphics.newQuad(20, 40, 20, 40, 520, 160),
        w = love.graphics.newQuad(80, 40, 20, 40, 520, 160),

        se_inner = love.graphics.newQuad(420, 20, 20, 20, 520, 160),
        sw_inner = love.graphics.newQuad(440, 20, 20, 20, 520, 160),
        ne_inner = love.graphics.newQuad(420, 40, 20, 20, 520, 160),
        nw_inner = love.graphics.newQuad(440, 40, 20, 20, 520, 160),
    }
end

-- Add start-of-game items, etc
function Game.static.start(game)
    local clothes = Clothes()
    clothes:activate(game)
    game:add_item(clothes)

    local dagger = Dagger()
    dagger:activate(game)
    game:add_item(dagger)

    -- Remove me before release!
    local wand = DevWand()
    game:add_item(wand)

    for n = 1, 2 do -- Start with two pots
        local potion = HealthPotion()
        game:add_item(potion)
    end

    game.health = 20
    game.max_health = 20
    game.armor = 0
    game.level = 1
    game.score = 0

    game:log("Welcome to the dungeon!")
end

--------------------------------------------------

function Game:initialize(strs)
    self.sidebar = Sidebar(self)
    self.generator = MapGenerator()
    self.inventory = List{}

    self.map = self.generator.map

    self.visibility = Map(self.map.width, self.map.height)
    self.map_items = SparseMap(self.map.width, self.map.height)
    self.decoration = SparseMap(self.map.width, self.map.height)
    self.visibility:clear(false)

    self.player_loc = self.map:find_value('@'):shift()
    self.map:at(self.player_loc, '.')
    self:reveal(self.player_loc)

    self.bg_effect = {value=255}
    self.key_repeat_clock = nil
    self.freeze = false

    self.health = 0
    self.max_health = 0
    self.armor = 0
    self.level = 0
    self.score = 0
end

function Game:reveal(pt)
    local v = self.map:at(pt)
    local hidden = self.map:connected_value(pt, v)
    hidden:each(function(pt)
                    self.visibility:at(pt, true)
                    -- Also reveal all the neighbors, so we get to see
                    -- pretty walls
                    self.map:neighbors(pt, nil, true):each(
                        function(pt)
                            self.visibility:at(pt, true)
                        end)
                end)

    return hidden
end

function Game:add_item(item)
    self.inventory:push(item)
    self.sidebar:add_item(item)
end

function Game:remove_item(item)
    self.inventory = self.inventory:select(function(i) return i ~= item end)
    self.sidebar:remove_item(item)
end

-- Move an item in self.map_items
function Game:move_item(old, new)
    local sm = self.map_items
    assert(new ~= old)
    assert(sm(old) ~= nil)
    assert(sm(new) == nil)
    self.map_items:at(new, self.map_items:at(old))
    self.map_items:delete(old)
end

-- Return the active item (if any) for the given category
function Game:active_item(category)
    return self.inventory:select(function(i)
                                     return i.active and i.category == category
                                 end):shift()
end

function Game:keypressed(key)
    if self.freeze then return end -- Ignore all input, loveframes has the show

    local pt = Point[key]
    if pt then
        local new_loc = pt + self.player_loc
        if self.map:inside(new_loc) and self.map:at(new_loc) ~= '#' then
            if self.map:at(new_loc) == '+' then -- Open door
                self:open_door(new_loc)
                self:tick()
            elseif self.map_items:at(new_loc) then
                self:attack(new_loc)
                self:tick()
                self:make_noise()
            else
                self.player_loc = new_loc
                self:tick()
                self:make_noise()
            end
        else
            self.bg_effect = Tween(140, 255, 0.5)
        end

        if not self.key_repeat_clock then
            -- First, make a clock to delay a second
            self.key_repeat_clock =
                Clock.oneoff(0.6,
                             function()
                                 -- Then, after a second, start repeating 0.1 secs
                                 self.key_repeat_clock =
                                     Clock(0.1, self.keypressed, self, key)
                             end)
        end
    elseif key == 'escape' then
        self.sidebar:exit_dialog()
    elseif key == 'm' then
        self.sidebar:toggle_map()
    elseif key == 'l' then
        self.sidebar:toggle_log()
    end
end

-- returns a List of all points containing awake map items,
-- sorted by ascending distance from player
function Game:awake_items()
    local all_awake = {}
    for pt in self.map_items:each() do
        local it = self.map_items:at(pt)
        if it.awake then
            table.insert(all_awake, {pt, it})
        end
    end

    local p = self.player_loc
    table.sort(all_awake, function(a, b)
                              local da = p:dist(a[1])
                              return da < p:dist(b[1])
                          end)

    for n, i in ipairs(all_awake) do all_awake[n] = i[1] end
    return List(all_awake)
end

-- Do everything that needs doing every time the player takes a turn.
-- Client code (like Item.on_use) should call this!
-- (meaning, it's important it not need any parameters)
function Game:tick()
    self:log("Tick", {0, 0, 255})

    local points = self:awake_items()
    local items = points:map(function(p) return self.map_items:at(p) end)

    for n = 1, points:length() do
        local p = points:at(n)
        items:at(n):tick(self, p)
    end
end

-- Call this when the player does something that might make noise, like walking.
-- It should be called AFTER tick, so that things can't move as soon as they awaken.
function Game:make_noise()
    for pt in self.map_items:each(self.player_loc-Point(3, 3), 7, 7) do
        if self.player_loc:dist(pt, 3) then
            self.map_items:at(pt):hear(self, pt)
        end
    end
end

function Game:open_door(pt)
    self.map:at(pt, '_')

    local hidden = self.map:neighbors(pt, nil, true)

    hidden:each(function(p)
                    if not self.visibility:at(p) then
                        self.visibility:at(p, true)

                        local v = self.map:at(p)
                        if v == '.' or v == ',' then
                            local revealed = self:reveal(p)
                            self:reveal_items(revealed, v == ',')
                        end
                    end
                end)

    self.sidebar:redraw_minimap() -- This is a great candidate for pubsub
end

function Game:attack(pt)
    local enemy = self.map_items:at(pt)
    assert(enemy)
    local weapon = self:active_item('weapon') or Fist()
    local dmg = weapon:calculate_damage()

    if dmg == 0 then
        self:log("You flail wildly, missing the " .. enemy.name .. " completely.",
                 {255, 0, 0})
    else
        self:log("You " .. weapon.verb
                 .. ' the ' .. enemy.name
                 .. ' with your ' .. string.lower(weapon.name)
                 .. ', dealing ' .. dmg .. ' damage.',
         {0, 255, 0})

        enemy.health = enemy.health - dmg
        if enemy.health <= 0 then
            self.map_items:delete(pt)
            self.decoration:at(pt, Decoration.corpse)
            self:log("You have killed the " .. enemy.name)
        end
    end
end

function Game:reveal_items(revealed, hallway)
    -- Drop the places, if any, that there's already an item.
    revealed = revealed:select(function(p) return not self.map_items:at(p) end)

    -- In the future, sometimes there will be chests
    local num_enemies = 0
    if hallway then
        num_enemies = math.floor(revealed:length() / 10)
    else
        num_enemies = math.floor(revealed:length() / 5)
    end

    -- Pull a random point out
    local function get_point()
        local i = math.random(#(revealed.items))
        return table.remove(revealed.items, i)
    end

    for n = 1, num_enemies do
        local p = get_point()
        local orc = Orc()
        self.map_items:at(p, orc)
    end
end

function Game:log(str, color)
    self.sidebar:add_log_message(str, color)
end

function Game:keyreleased()
    if self.key_repeat_clock then
        self.key_repeat_clock:stop()
        self.key_repeat_clock = nil
    end
end

function Game:set_freeze(f)
    self.freeze = f
    if f then self:keyreleased() end
end
