-- Card module for Spanish Deck Card Game
local card = {}

-- Card dimensions and styling (scaled from 45x58px sprites for iPhone high-res canvas with 7x scaling)
card.CARD_WIDTH = 315   -- 45px * 7.0 scale (7x scaling for visibility on 4x canvas)
card.CARD_HEIGHT = 406  -- 58px * 7.0 scale (7x scaling for visibility on 4x canvas)
card.CARD_SPACING = 21   -- Proportionally scaled spacing (7 * 3)
card.CARD_BORDER = 7    -- Proportionally scaled border (7 * 1)
card.POP_OUT_OFFSET = 35  -- Proportionally scaled pop-out effect (7 * 5)

-- Sprite storage
local card_sprites = {}
local card_back_sprite = nil
local liga_sprites = {}
local liga_back_sprite = nil
local poke_sprites = {}
local poke_back_sprite = nil

-- UI sprites for deck, play area, and discard area
local deck_sprite = nil
local play_hand_sprite = nil
local discard_hand_sprite = nil

-- Suit colors (Spanish deck traditional colors)
card.SUIT_COLORS = {
    Oros = {1, 0.8, 0},      -- Gold/Yellow
    Copas = {0.8, 0.2, 0.2}, -- Red
    Espadas = {0.2, 0.2, 0.8}, -- Blue  
    Bastos = {0.2, 0.6, 0.2}  -- Green
}

-- Load card sprites
function card.load_sprites()
    -- Set pixel-perfect filtering for crisp sprites
    love.graphics.setDefaultFilter("nearest", "nearest")
    
    -- Load card back
    if love.filesystem.getInfo("sprites/back.png") then
        card_back_sprite = love.graphics.newImage("sprites/back.png")
        card_back_sprite:setFilter("nearest", "nearest")  -- Pixel-perfect scaling
    end
    
    -- Load Liga card back
    if love.filesystem.getInfo("sprites/liga/back.png") then
        liga_back_sprite = love.graphics.newImage("sprites/liga/back.png")
        liga_back_sprite:setFilter("nearest", "nearest")
    end
    
    -- Load Pokemon card back
    if love.filesystem.getInfo("sprites/poke/back.png") then
        poke_back_sprite = love.graphics.newImage("sprites/poke/back.png")
        poke_back_sprite:setFilter("nearest", "nearest")
    end
    
    -- Load card face sprites
    local suits = {"oros", "copas", "espadas", "bastos"}
    local values = {1, 2, 3, 4, 5, 6, 7, 11, 12, 13}  -- Spanish deck values
    
    for _, suit in ipairs(suits) do
        for _, value in ipairs(values) do
            local filename = string.format("sprites/%d_%s.png", value, suit)
            if love.filesystem.getInfo(filename) then
                local sprite_key = string.format("%d_%s", value, suit)
                local sprite = love.graphics.newImage(filename)
                sprite:setFilter("nearest", "nearest")  -- Pixel-perfect scaling
                card_sprites[sprite_key] = sprite
            end
        end
    end
    
    -- Load Liga card sprites (all are Aces with team names)
    local liga_teams = {"athletic", "atleti", "barca", "betis", "espanyol", "madrid", "racing", "real", "rsociedad", "sevilla", "valencia", "zaragoza"}
    
    for _, team in ipairs(liga_teams) do
        local filename = string.format("sprites/liga/1_%s.png", team)
        if love.filesystem.getInfo(filename) then
            local sprite_key = string.format("1_%s", team)
            local sprite = love.graphics.newImage(filename)
            sprite:setFilter("nearest", "nearest")
            liga_sprites[sprite_key] = sprite
        end
    end
    
    -- Load Pokemon card sprites (values 1-7, 11-13)
    local poke_values = {1, 2, 3, 4, 5, 6, 7, 11, 12, 13}
    local poke_names = {
        -- Value 1 Pokemon
        ["1"] = {"Articuno", "Deino", "Mew", "Unown"},
        -- Value 2 Pokemon  
        ["2"] = {"Doduo", "Doublade", "Weezing", "Zapdos"},
        -- Value 3 Pokemon
        ["3"] = {"Combee", "Dugtrio", "Magneton", "Moltres"},
        -- Value 4 Pokemon
        ["4"] = {"Cofrarigus", "Golbat", "Machamp", "Metagross"},
        -- Value 5 Pokemon
        ["5"] = {"Chandelure", "Cinccino_", "Staryu", "Victini_"},
        -- Value 6 Pokemon
        ["6"] = {"Eggxecute", "Seismitoad", "Volcarona_", "Vulpix"},
        -- Value 7 Pokemon
        ["7"] = {"Chansey", "Gholdengo", "Jirachi", "Togekiss"},
        -- Value 11 Pokemon
        ["11"] = {"Gardevoir", "Hitmonchan", "Lucario", "MrMime"},
        -- Value 12 Pokemon
        ["12"] = {"Horsea", "Jirafarig", "Mudsdale", "Rapidash"},
        -- Value 13 Pokemon
        ["13"] = {"Kingler", "Nidoking", "Slacking", "Slowking"}
    }
    
    for _, value in ipairs(poke_values) do
        for _, pokemon in ipairs(poke_names[tostring(value)]) do
            local filename = string.format("sprites/poke/%d_%s.png", value, pokemon)
            if love.filesystem.getInfo(filename) then
                local sprite_key = string.format("%d_%s", value, pokemon)
                local sprite = love.graphics.newImage(filename)
                sprite:setFilter("nearest", "nearest")
                poke_sprites[sprite_key] = sprite
            end
        end
    end
    
    -- Load UI sprites
    if love.filesystem.getInfo("sprites/ui/deck.png") then
        deck_sprite = love.graphics.newImage("sprites/ui/deck.png")
        deck_sprite:setFilter("nearest", "nearest")
    end
    
    if love.filesystem.getInfo("sprites/ui/play_hand.png") then
        play_hand_sprite = love.graphics.newImage("sprites/ui/play_hand.png")
        play_hand_sprite:setFilter("nearest", "nearest")
    end
    
    if love.filesystem.getInfo("sprites/ui/discard_hand.png") then
        discard_hand_sprite = love.graphics.newImage("sprites/ui/discard_hand.png")
        discard_hand_sprite:setFilter("nearest", "nearest")
    end
end

-- Get UI sprites
function card.get_deck_sprite()
    return deck_sprite
end

function card.get_play_hand_sprite()
    return play_hand_sprite
end

function card.get_discard_hand_sprite()
    return discard_hand_sprite
end

-- Get sprite for a card
function card.get_sprite(value, suit, team, pokemon)
    if suit == "Liga" and team then
        -- Liga card sprite
        local sprite_key = string.format("%d_%s", value, team)
        return liga_sprites[sprite_key]
    elseif suit == "Pokemon" and pokemon then
        -- Pokemon card sprite
        local sprite_key = string.format("%d_%s", value, pokemon)
        return poke_sprites[sprite_key]
    else
        -- Regular card sprite
        local sprite_key = string.format("%d_%s", value, string.lower(suit))
        return card_sprites[sprite_key]
    end
end

-- Get card back sprite
function card.get_back_sprite()
    return card_back_sprite
end

-- Get Liga card back sprite
function card.get_liga_back_sprite()
    return liga_back_sprite
end

-- Get Pokemon card back sprite
function card.get_poke_back_sprite()
    return poke_back_sprite
end

-- Card representation
function card.create(value, suit)
    return {
        value = value,
        suit = suit,
        display_value = value == 11 and "J" or value == 12 and "Q" or value == 13 and "K" or tostring(value),
        selected = false,
        x = 0,
        y = 0,
        card_type = "regular"
    }
end

-- Create a Liga card (always value 1/Ace)
function card.create_liga(team)
    return {
        value = 1,
        suit = "Liga",  -- Special suit for Liga cards
        display_value = "A",
        selected = false,
        x = 0,
        y = 0,
        card_type = "liga",
        team = team  -- Store team name for sprite lookup
    }
end

-- Pokemon abilities database
local pokemon_abilities = {
    -- Value 2 Pokemon abilities
    ["2"] = {
        ["Doduo"] = {
            name = "Doduo",
            type = "Normal/Flying",
            ability = "Doble Golpe: Si es tu carta más baja, +2 mult",
            effect_type = "lowest_card_mult"
        },
        ["Doublade"] = {
            name = "Doublade",
            type = "Steel/Ghost",
            ability = "Danza Espada: +1 mult por cada carta de espadas en mano",
            effect_type = "mult_per_espadas"
        },
        ["Weezing"] = {
            name = "Weezing",
            type = "Poison",
            ability = "Gas Venenoso: si puntas en pares, x2 mult",
            effect_type = "pairs_multiplier"
        },
        ["Zapdos"] = {
            name = "Zapdos",
            type = "Electric/Flying",
            ability = "Trueno: Precisión perfecta (100%) al jugarse",
            effect_type = "perfect_accuracy"
        }
    },
    -- Value 3 Pokemon abilities
    ["3"] = {
        ["Combee"] = {
            name = "Combee",
            type = "Bug/Flying",
            ability = "Enjambre: +1 mult por cada carta de valor 3 o menos en tu mano",
            effect_type = "mult_per_low_card"
        },
        ["Dugtrio"] = {
            name = "Dugtrio", 
            type = "Ground",
            ability = "Triple Amenaza: Si tus pares son un trío, x3 al mult",
            effect_type = "trio_multiplier"
        },
        ["Magneton"] = {
            name = "Magneton",
            type = "Electric/Steel", 
            ability = "Imán: Suma la mitad de los oros de la mano enemiga a tus pesetas",
            effect_type = "steal_oros"
        },
        ["Moltres"] = {
            name = "Moltres",
            type = "Fire/Flying",
            ability = "Cuerpo Llama: +10 daño al jugarse", 
            effect_type = "flat_damage"
        }
    },
    -- Value 4 Pokemon abilities
    ["4"] = {
        ["Cofrarigus"] = {
            name = "Cofrarigus",
            type = "Ghost",
            ability = "Momia: -10% de precisión al enemigo al jugarse",
            effect_type = "enemy_accuracy_debuff"
        },
        ["Golbat"] = {
            name = "Golbat",
            type = "Poison/Flying",
            ability = "Chupavidas: Curas 50% PV al ganar la ronda",
            effect_type = "heal_on_victory"
        },
        ["Machamp"] = {
            name = "Machamp",
            type = "Fighting",
            ability = "No Guard: +10 de daño por cada figura del oponente",
            effect_type = "damage_per_enemy_face"
        },
        ["Metagross"] = {
            name = "Metagross",
            type = "Steel/Psychic",
            ability = "Cuerpo Puro: +20 si no tienes figuras en la mano",
            effect_type = "damage_no_faces"
        }
    },
    -- Value 5 Pokemon abilities
    ["5"] = {
        ["Chandelure"] = {
            name = "Chandelure",
            type = "Ghost/Fire",
            ability = "Llamarada: +1 mult por carta de valor impar (fuego fantasma)",
            effect_type = "mult_per_odd_card"
        },
        ["Cinccino_"] = {
            name = "Cinccino",
            type = "Normal",
            ability = "Encanto: Reduce el daño del enemigo al 50%",
            effect_type = "enemy_damage_reduction"
        },
        ["Staryu"] = {
            name = "Staryu",
            type = "Water",
            ability = "Rapidez: Siempre impacta al menos 10 daño directo, incluso con 0% precisión (nunca falla)",
            effect_type = "minimum_damage"
        },
        ["Victini_"] = {
            name = "Victini",
            type = "Psychic/Fire",
            ability = "Llama V: Si juego = exactamente 25, x5 (Pokémon victoria)",
            effect_type = "juego_25_multiplier"
        }
    },
    -- Value 6 Pokemon abilities
    ["6"] = {
        ["Eggxecute"] = {
            name = "Exeggcute",
            type = "Grass/Psychic",
            ability = "Bomba Germen: x2 mult si tienes 4 palos diferentes (diversidad planta)",
            effect_type = "four_suits_multiplier"
        },
        ["Seismitoad"] = {
            name = "Seismitoad",
            type = "Water/Ground",
            ability = "Telúrico: +1 mult por cada figura (11,12,13) en la mano (tipo tierra)",
            effect_type = "mult_per_figure"
        },
        ["Volcarona_"] = {
            name = "Volcarona",
            type = "Bug/Fire",
            ability = "Danza Aleteo: Próxima ronda, tu mano obtiene +3 a todos los valores (danza bicho/fuego)",
            effect_type = "next_round_value_boost"
        },
        ["Vulpix"] = {
            name = "Vulpix",
            type = "Fire",
            ability = "Fuego Fatuo: +15 de daño si es la única carta par",
            effect_type = "damage_only_even_card"
        }
    },
    -- Value 7 Pokemon abilities
    ["7"] = {
        ["Chansey"] = {
            name = "Chansey",
            type = "Normal",
            ability = "Amortiguador: Si pierdes recibes el 50% del daño",
            effect_type = "damage_reduction_on_loss"
        },
        ["Gholdengo"] = {
            name = "Gholdengo",
            type = "Steel/Ghost",
            ability = "Lluvia Oro: Ganas 5 pesetas al jugarse",
            effect_type = "pesetas_on_play"
        },
        ["Jirachi"] = {
            name = "Jirachi",
            type = "Steel/Psychic",
            ability = "Deseo: Si es tu carta más alta, tu precisión es del 100%",
            effect_type = "perfect_accuracy_highest_card"
        },
        ["Togekiss"] = {
            name = "Togekiss",
            type = "Fairy/Flying",
            ability = "Don Natural: Duplica todos los efectos positivos de otros Pokémon esta ronda",
            effect_type = "double_pokemon_effects"
        }
    },
    -- Value 11 Pokemon abilities (Sota equivalents)
    ["11"] = {
        ["Gardevoir"] = {
            name = "Gardevoir",
            type = "Psychic/Fairy",
            ability = "Psíquico: Predice la mano del enemigo - ve sus cartas antes de jugar (tipo psíquico)",
            effect_type = "reveal_enemy_hand"
        },
        ["Hitmonchan"] = {
            name = "Hitmonchan",
            type = "Fighting",
            ability = "A Bocajarro: x2 mult si es carta alta",
            effect_type = "mult_if_highest_card"
        },
        ["Lucario"] = {
            name = "Lucario",
            type = "Fighting/Steel",
            ability = "Esfera Aural: x2 mult sin pares",
            effect_type = "mult_no_pairs"
        },
        ["MrMime"] = {
            name = "Mr. Mime",
            type = "Psychic/Fairy",
            ability = "Barrera: x2 escudo si es carta alta",
            effect_type = "double_defense_highest_card"
        }
    },
    -- Value 12 Pokemon abilities (Caballo equivalents)
    ["12"] = {
        ["Horsea"] = {
            name = "Horsea",
            type = "Water",
            ability = "Danza Dragón: +1 daño por cada HP",
            effect_type = "damage_per_hp"
        },
        ["Jirafarig"] = {
            name = "Girafarig",
            type = "Normal/Psychic",
            ability = "Premonición: Si es tu carta más alta +3 mult",
            effect_type = "mult_if_highest_card_3"
        },
        ["Mudsdale"] = {
            name = "Mudsdale",
            type = "Ground",
            ability = "Aguante: +0.1 mult por cada carta restante en la baraja",
            effect_type = "mult_per_deck_card"
        },
        ["Rapidash"] = {
            name = "Rapidash",
            type = "Fire",
            ability = "Agilidad: Añade una mano extra si es carta alta",
            effect_type = "extra_hand_if_highest"
        }
    },
    -- Value 13 Pokemon abilities (Rey equivalents)
    ["13"] = {
        ["Kingler"] = {
            name = "Kingler",
            type = "Water",
            ability = "Guillotina: 10% probabilidad de ganar instantáneamente la ronda (pinza cangrejo)",
            effect_type = "instant_win_chance"
        },
        ["Nidoking"] = {
            name = "Nidoking",
            type = "Poison/Ground",
            ability = "Punto Tóxico: El enemigo recibe 20% daño si gana el juego",
            effect_type = "enemy_damage_on_win"
        },
        ["Slacking"] = {
            name = "Slakking",
            type = "Normal",
            ability = "Pereza: +50 daño masivo, pero tu defensa es 0",
            effect_type = "massive_damage_no_defense"
        },
        ["Slowking"] = {
            name = "Slowking",
            type = "Water/Psychic",
            ability = "Ritmo Propio: Si es la única figura de tu mano, x3 mult",
            effect_type = "mult_only_figure"
        }
    },
    -- Value 1 Pokemon abilities (Ace equivalents)
    ["1"] = {
        ["Articuno"] = {
            name = "Articuno",
            type = "Ice/Flying",
            ability = "Ventisca: Defensa +5 al jugarse",
            effect_type = "defense_boost"
        },
        ["Deino"] = {
            name = "Deino",
            type = "Dark/Dragon",
            ability = "Furia Ciega: +20 daño si no tienes pares",
            effect_type = "damage_no_pairs"
        },
        ["Mew"] = {
            name = "Mew",
            type = "Psychic",
            ability = "Transformación: Copia la carta de mayor valor en tu mano con su habilidad",
            effect_type = "copy_highest_card_ability"
        },
        ["Unown"] = {
            name = "Unown",
            type = "Psychic",
            ability = "Poder Oculto: +2 mult si todas las cartas tienen valores diferentes",
            effect_type = "mult_all_different_values"
        }
    }
}

-- Create a Pokemon card (any value from 1-7, 11-13)
function card.create_pokemon(value, pokemon)
    local ability_data = nil
    if pokemon_abilities[tostring(value)] and pokemon_abilities[tostring(value)][pokemon] then
        ability_data = pokemon_abilities[tostring(value)][pokemon]
    end
    
    return {
        value = value,
        suit = "Pokemon",  -- Special suit for Pokemon cards
        display_value = value == 11 and "J" or value == 12 and "Q" or value == 13 and "K" or tostring(value),
        selected = false,
        x = 0,
        y = 0,
        card_type = "pokemon",
        pokemon = pokemon,  -- Store pokemon name for sprite lookup
        ability = ability_data  -- Store complete ability information
    }
end

-- Create Spanish deck
function card.create_deck()
    local deck = {}
    local suits = {"Oros", "Espadas", "Bastos", "Copas"}
    local values = {1, 2, 3, 4, 5, 6, 7, 11, 12, 13}
    
    for _, suit in ipairs(suits) do
        for _, value in ipairs(values) do
            table.insert(deck, card.create(value, suit))
        end
    end
    
    return deck
end

-- Get three random Liga cards for selection
function card.get_liga_choices()
    local liga_teams = {"athletic", "atleti", "barca", "betis", "espanyol", "madrid", "racing", "real", "rsociedad", "sevilla", "valencia", "zaragoza"}
    
    local choices = {}
    local used_teams = {}
    
    -- Pick 3 unique teams
    for i = 1, 3 do
        local team
        repeat
            team = liga_teams[math.random(#liga_teams)]
        until not used_teams[team]
        
        used_teams[team] = true
        table.insert(choices, card.create_liga(team))
    end
    
    return choices
end

-- Get three random Pokemon cards for selection
function card.get_pokemon_choices()
    local poke_values = {1, 2, 3, 4, 5, 6, 7, 11, 12, 13}
    local poke_names = {
        ["1"] = {"Articuno", "Deino", "Mew", "Unown"},
        ["2"] = {"Doduo", "Doublade", "Weezing", "Zapdos"},
        ["3"] = {"Combee", "Dugtrio", "Magneton", "Moltres"},
        ["4"] = {"Cofrarigus", "Golbat", "Machamp", "Metagross"},
        ["5"] = {"Chandelure", "Cinccino_", "Staryu", "Victini_"},
        ["6"] = {"Eggxecute", "Seismitoad", "Volcarona_", "Vulpix"},
        ["7"] = {"Chansey", "Gholdengo", "Jirachi", "Togekiss"},
        ["11"] = {"Gardevoir", "Hitmonchan", "Lucario", "MrMime"},
        ["12"] = {"Horsea", "Jirafarig", "Mudsdale", "Rapidash"},
        ["13"] = {"Kingler", "Nidoking", "Slacking", "Slowking"}
    }
    
    local choices = {}
    local used_combinations = {}
    
    -- Pick 3 unique Pokemon cards
    for i = 1, 3 do
        local value, pokemon
        repeat
            value = poke_values[math.random(#poke_values)]
            local pokemon_list = poke_names[tostring(value)]
            pokemon = pokemon_list[math.random(#pokemon_list)]
            local combo_key = value .. "_" .. pokemon
        until not used_combinations[combo_key]
        
        used_combinations[value .. "_" .. pokemon] = true
        table.insert(choices, card.create_pokemon(value, pokemon))
    end
    
    return choices
end

-- Get display name for a card
function card.get_card_name(game_card)
    if game_card.card_type == "liga" then
        -- Liga cards: "Escudo del [Team]"
        local team_name = game_card.team or "Unknown"
        -- Capitalize first letter
        team_name = team_name:sub(1,1):upper() .. team_name:sub(2)
        return "Escudo del " .. team_name
    elseif game_card.card_type == "pokemon" then
        -- Pokemon cards: just the pokemon name
        return game_card.pokemon or "Unknown Pokemon"
    else
        -- Spanish cards: proper Spanish names
        local value_names = {
            [1] = "As",
            [2] = "Dos", 
            [3] = "Tres",
            [4] = "Cuatro",
            [5] = "Cinco",
            [6] = "Seis",
            [7] = "Siete",
            [11] = "Sota",
            [12] = "Caballo", 
            [13] = "Rey"
        }
        
        local value_name = value_names[game_card.value] or tostring(game_card.value)
        return value_name .. " de " .. game_card.suit
    end
end

-- Get category for a card
function card.get_card_category(game_card)
    if game_card.card_type == "liga" then
        return "La Liga"
    elseif game_card.card_type == "pokemon" then
        if game_card.ability then
            return string.format("Pokemus (%s): %s", game_card.ability.type, game_card.ability.ability)
        else
            return "Pokemus"
        end
    else
        return "Baraja española"
    end
end

-- Shuffle deck using Fisher-Yates algorithm
function card.shuffle_deck(deck)
    -- Don't reseed - let main.lua handle seeding once at startup
    for i = #deck, 2, -1 do
        local j = math.random(i)
        deck[i], deck[j] = deck[j], deck[i]
    end
end

-- Draw cards from deck
function card.draw_cards(deck, count)
    local drawn = {}
    for i = 1, count do
        if #deck > 0 then
            table.insert(drawn, table.remove(deck))
        end
    end
    return drawn
end

-- Calculate hand layout positions (horizontal row)
function card.calculate_positions(hand, start_x, start_y)
    local total_width = (#hand - 1) * (card.CARD_WIDTH + card.CARD_SPACING) + card.CARD_WIDTH
    local offset_x = start_x - total_width / 2
    
    for i, game_card in ipairs(hand) do
        game_card.base_x = offset_x + (i - 1) * (card.CARD_WIDTH + card.CARD_SPACING)
        game_card.base_y = start_y
        
        -- Apply pop-out effect if selected
        if game_card.selected then
            game_card.x = game_card.base_x
            game_card.y = game_card.base_y - card.POP_OUT_OFFSET
        else
            game_card.x = game_card.base_x
            game_card.y = game_card.base_y
        end
    end
end

-- Draw a single card
function card.draw_card(game_card, font)
    local x, y = game_card.x, game_card.y
    
    -- Try to use sprite first
    local sprite = card.get_sprite(game_card.value, game_card.suit, game_card.team, game_card.pokemon)
    
    if sprite then
        -- Draw sprite with 7.0x scale - PNG transparency should work automatically
        love.graphics.setColor(1, 1, 1, 1)  -- Full white (no tint)
        love.graphics.draw(sprite, x, y, 0, 7.0, 7.0)  -- 7.0x scale for 45x58 -> 315x406
        
        -- Add selection highlight if selected
        if game_card.selected then
            love.graphics.setColor(1, 1, 0, 0.3) -- Yellow highlight with transparency
            love.graphics.rectangle("fill", x, y, card.CARD_WIDTH, card.CARD_HEIGHT)
        end
    else
        -- Fallback to original drawing method if sprite not available
        -- Card background
        if game_card.selected then
            love.graphics.setColor(1, 1, 0.3) -- Yellow highlight for selected
        else
            love.graphics.setColor(0.9, 0.9, 0.9) -- Light gray background
        end
        love.graphics.rectangle("fill", x, y, card.CARD_WIDTH, card.CARD_HEIGHT)
        
        -- Card border
        love.graphics.setColor(0.2, 0.2, 0.2)
        love.graphics.setLineWidth(card.CARD_BORDER)
        love.graphics.rectangle("line", x, y, card.CARD_WIDTH, card.CARD_HEIGHT)
        
        -- Suit color strip at top
        local suit_color = card.SUIT_COLORS[game_card.suit] or {0.5, 0.5, 0.5}
        love.graphics.setColor(suit_color)
        love.graphics.rectangle("fill", x + 2, y + 2, card.CARD_WIDTH - 4, 15)
        
        -- Card value (large, center)
        love.graphics.setColor(0.1, 0.1, 0.1)
        local value_font = love.graphics.newFont(24)
        love.graphics.setFont(value_font)
        local text_width = value_font:getWidth(game_card.display_value)
        local text_height = value_font:getHeight()
        love.graphics.print(game_card.display_value, 
                           x + (card.CARD_WIDTH - text_width) / 2, 
                           y + (card.CARD_HEIGHT - text_height) / 2)
        
        -- Suit name (small, bottom)
        love.graphics.setFont(font)
        local suit_width = font:getWidth(game_card.suit)
        love.graphics.print(game_card.suit, 
                           x + (card.CARD_WIDTH - suit_width) / 2, 
                           y + card.CARD_HEIGHT - 20)
        
        -- Card points (small, top right)
        local points = tostring(game_card.value) .. "pt"
        local points_width = font:getWidth(points)
        love.graphics.print(points, x + card.CARD_WIDTH - points_width - 5, y + 20)
    end
end

-- Check if point is inside card bounds
function card.point_in_card(game_card, x, y)
    return x >= game_card.x and x <= game_card.x + card.CARD_WIDTH and
           y >= game_card.y and y <= game_card.y + card.CARD_HEIGHT
end

-- Toggle card selection with pop-out effect
function card.toggle_selection(game_card)
    game_card.selected = not game_card.selected
    
    -- Update position based on selection
    if game_card.selected then
        game_card.y = game_card.base_y - card.POP_OUT_OFFSET
    else
        game_card.y = game_card.base_y
    end
end

-- Clear all selections in hand
function card.clear_selections(hand)
    for _, game_card in ipairs(hand) do
        game_card.selected = false
    end
end

-- Get selected card indices
function card.get_selected_indices(hand)
    local selected = {}
    for i, game_card in ipairs(hand) do
        if game_card.selected then
            table.insert(selected, i)
        end
    end
    return selected
end

-- Calculate score for cards
function card.calculate_score(cards)
    local total = 0
    for _, game_card in ipairs(cards) do
        total = total + game_card.value
    end
    return total
end

-- Draw deck representation
function card.draw_deck(x, y, remaining_count, total_count, font)
    -- Draw deck background sprite first if available
    if deck_sprite then
        love.graphics.setColor(1, 1, 1, 1)  -- Full white
        love.graphics.draw(deck_sprite, x, y, 0, 7.0, 7.0)  -- 7.0x scale, properly centered
        
        -- Draw simple remaining/total text under the deck sprite
        love.graphics.setColor(1, 1, 1)  -- White text
        love.graphics.setFont(font)
        local count_text = string.format("%d/%d", remaining_count, total_count)
        local text_width = font:getWidth(count_text)
        love.graphics.print(count_text, 
                           x + (card.CARD_WIDTH - text_width) / 2, 
                           y + card.CARD_HEIGHT + 50)  -- Position 50 pixels under the sprite
    else
        -- Fallback: use card back sprite if available, otherwise colored rectangle
        local back_sprite = card.get_back_sprite()
        
        if back_sprite then
            -- Draw single card back sprite
            love.graphics.setColor(1, 1, 1, 1)  -- Full white
            love.graphics.draw(back_sprite, x, y, 0, 7.0, 7.0)  -- 7.0x scale
        else
            -- Ultimate fallback: colored rectangle
            love.graphics.setColor(0.5, 0.3, 0.1)  -- Brown
            love.graphics.rectangle("fill", x, y, card.CARD_WIDTH, card.CARD_HEIGHT)
            love.graphics.setColor(1, 1, 1)
            love.graphics.rectangle("line", x, y, card.CARD_WIDTH, card.CARD_HEIGHT)
        end
        
        -- Draw card count in remaining/total format below the sprite/rectangle
        love.graphics.setColor(1, 1, 1)
        love.graphics.setFont(font)
        local count_text = string.format("%d/%d", remaining_count, total_count)
        local text_width = font:getWidth(count_text)
        love.graphics.print(count_text, 
                           x + (card.CARD_WIDTH - text_width) / 2, 
                           y + card.CARD_HEIGHT + 50)  -- Position 50 pixels under the sprite
    end
end

-- Draw face-down card
function card.draw_face_down(x, y, font)
    -- Try to use back sprite first
    local back_sprite = card.get_back_sprite()
    
    if back_sprite then
        -- Draw back sprite with 7.0x scale - PNG transparency should work automatically
        love.graphics.setColor(1, 1, 1, 1)  -- Full white (no tint)
        love.graphics.draw(back_sprite, x, y, 0, 7.0, 7.0)  -- 7.0x scale for 45x58 -> 315x406
    else
        -- Fallback to original drawing method if sprite not available
        -- Card background (darker)
        love.graphics.setColor(0.3, 0.3, 0.4)
        love.graphics.rectangle("fill", x, y, card.CARD_WIDTH, card.CARD_HEIGHT)
        
        -- Card border
        love.graphics.setColor(0.1, 0.1, 0.1)
        love.graphics.setLineWidth(card.CARD_BORDER)
        love.graphics.rectangle("line", x, y, card.CARD_WIDTH, card.CARD_HEIGHT)
        
        -- Card back pattern (simple cross pattern)
        love.graphics.setColor(0.5, 0.5, 0.6)
        love.graphics.setLineWidth(3)
        local margin = 10
        love.graphics.line(x + margin, y + margin, x + card.CARD_WIDTH - margin, y + card.CARD_HEIGHT - margin)
        love.graphics.line(x + card.CARD_WIDTH - margin, y + margin, x + margin, y + card.CARD_HEIGHT - margin)
        
        -- "?" text in center for hidden cards
        love.graphics.setColor(0.7, 0.7, 0.8)
        love.graphics.setFont(font)
        local hidden_text = "?"
        local text_width = font:getWidth(hidden_text)
        local text_height = font:getHeight()
        love.graphics.print(hidden_text, 
                           x + (card.CARD_WIDTH - text_width) / 2, 
                           y + (card.CARD_HEIGHT - text_height) / 2)
    end
end

return card