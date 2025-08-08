-- Amarracos (Prizes) system for Spanish Deck Card Game
local card = require("card")

local amarracos = {}

-- Amarracos sprite storage
local amarracos_sprites = {}

-- Prize definitions
amarracos.PRIZES = {
    {
        id = "euro",
        name = "Euro",
        description = "+5 pesetas cada ronda",
        cost = 1,
        effect_type = "round_bonus"
    },
    {
        id = "dos_euro",
        name = "Dos Euro",
        description = "Dobla pesetas obtenidas",
        cost = 1,
        effect_type = "pesetas_multiplier"
    },
    {
        id = "tres_euro",
        name = "Tres Euro", 
        description = "Descuento en tienda",
        cost = 1,
        effect_type = "shop_discount"
    },
    {
        id = "colgante_perro",
        name = "Colgante Perro",
        description = "Sin descartes, doble manos",
        cost = 1,
        effect_type = "hand_modifier"
    },
    {
        id = "pin",
        name = "Pin",
        description = "Sin defensa, defensa→daño",
        cost = 1,
        effect_type = "defense_to_damage"
    },
    {
        id = "token",
        name = "Token",
        description = "Menor accuracy = más daño",
        cost = 1,
        effect_type = "accuracy_inverse"
    },
    {
        id = "boton",
        name = "Botón",
        description = "Potencia cartas pares",
        cost = 1,
        effect_type = "even_boost"
    },
    {
        id = "hebilla",
        name = "Hebilla",
        description = "Potencia cartas impares",
        cost = 1,
        effect_type = "odd_boost"
    },
    {
        id = "reliquia",
        name = "Reliquia",
        description = "Oros → pesetas",
        cost = 1,
        effect_type = "oros_pesetas"
    },
    {
        id = "posavasos",
        name = "Posavasos",
        description = "Copas → HP",
        cost = 1,
        effect_type = "copas_hp"
    },
    {
        id = "afilar",
        name = "Afilar",
        description = "Espadas → daño",
        cost = 1,
        effect_type = "espadas_damage"
    },
    {
        id = "madera",
        name = "Madera",
        description = "Bastos → defensa",
        cost = 1,
        effect_type = "bastos_defense"
    },
    {
        id = "single_peseta",
        name = "1 Peseta",
        description = "x2 mult si ganas pequeña",
        cost = 1,
        effect_type = "pequena_win_mult"
    },
    {
        id = "cien_peseta",
        name = "100 Pesetas",
        description = "x2 mult si ganas grande",
        cost = 1,
        effect_type = "grande_win_mult"
    },
    {
        id = "duro",
        name = "Duro",
        description = "x2 mult si ganas pares",
        cost = 1,
        effect_type = "pares_win_mult"
    },
    {
        id = "venticinco_peseta",
        name = "25 Pesetas",
        description = "x2 mult si ganas juego",
        cost = 1,
        effect_type = "juego_win_mult"
    },
    {
        id = "poker",
        name = "Poker",
        description = "Gasta pesetas por descartes",
        cost = 1,
        effect_type = "pesetas_for_discards"
    },
    {
        id = "bola_billar",
        name = "Bola Billar",
        description = "7s cuentan como 10",
        cost = 1,
        effect_type = "sevens_as_tens"
    },
    {
        id = "chapa",
        name = "Chapa",
        description = "Juego → daño si ganas",
        cost = 1,
        effect_type = "juego_to_damage"
    },
    {
        id = "tenis",
        name = "Tenis",
        description = "100% accuracy, sin x3",
        cost = 1,
        effect_type = "perfect_accuracy"
    },
    {
        id = "canica",
        name = "Canica",
        description = "x3 mult si todos los palos",
        cost = 1,
        effect_type = "all_suits_mult"
    }
}

-- Load amarracos sprites
function amarracos.load_sprites()
    -- Set pixel-perfect filtering for crisp sprites
    love.graphics.setDefaultFilter("nearest", "nearest")
    
    -- Sprite filename mapping for inconsistent names
    local sprite_mappings = {
        posavasos = "PosaVasos_",  -- Different case/underscore
        bola_billar = "poker",     -- No bola_billar sprite, use poker as placeholder
        tenis = "token",           -- No tenis sprite, use token as placeholder  
        canica = "chapa"           -- No canica sprite, use chapa as placeholder
    }
    
    -- Load sprites for each amarraco
    for _, prize in ipairs(amarracos.PRIZES) do
        local sprite_name = sprite_mappings[prize.id] or prize.id
        local filename = string.format("sprites/amarracos/%s.png", sprite_name)
        if love.filesystem.getInfo(filename) then
            local sprite = love.graphics.newImage(filename)
            sprite:setFilter("nearest", "nearest")
            amarracos_sprites[prize.id] = sprite
        end
    end
end

-- Get sprite for an amarraco
function amarracos.get_sprite(amarraco_id)
    return amarracos_sprites[amarraco_id]
end

-- Draw amarraco with placeholder if sprite missing (45x45px base, displayed at 2x = 90px)
function amarracos.draw_amarraco(amarraco_id, x, y, additional_scale)
    additional_scale = additional_scale or 1.0  -- Additional scaling on top of base 2x
    local base_size = 45  -- Amarracos are 45x45px
    local base_display_scale = 2  -- Always display at 2x size (whole number to prevent jaggy pixels)
    local final_scale = base_display_scale * additional_scale
    local final_size = base_size * final_scale
    local sprite = amarracos.get_sprite(amarraco_id)
    
    if sprite then
        -- Draw actual sprite (45x45px scaled to 2x = 90px, plus any additional scaling)
        love.graphics.draw(sprite, x, y, 0, final_scale, final_scale)
    else
        -- Draw placeholder rectangle at final scaled size
        love.graphics.setColor(0.4, 0.4, 0.4)
        love.graphics.rectangle("fill", x, y, final_size, final_size)
        love.graphics.setColor(1, 1, 1)
        love.graphics.rectangle("line", x, y, final_size, final_size)
        
        -- Draw first letter of amarraco name
        local prize = amarracos.get_prize_by_id(amarraco_id)
        if prize then
            local letter = string.upper(string.sub(prize.name, 1, 1))
            local font = love.graphics.getFont()
            local text_width = font:getWidth(letter)
            local text_height = font:getHeight()
            love.graphics.setColor(1, 1, 1)
            love.graphics.print(letter, x + (final_size - text_width) / 2, y + (final_size - text_height) / 2)
        end
    end
end

-- Helper to get prize data by ID
function amarracos.get_prize_by_id(id)
    for _, prize in ipairs(amarracos.PRIZES) do
        if prize.id == id then
            return prize
        end
    end
    return nil
end

-- Get 3 random available prizes for shop
function amarracos.get_shop_prizes(owned_prizes)
    local available = {}
    
    -- Filter out already owned prizes
    for _, prize in ipairs(amarracos.PRIZES) do
        local already_owned = false
        for _, owned in ipairs(owned_prizes) do
            if owned.id == prize.id then
                already_owned = true
                break
            end
        end
        if not already_owned then
            table.insert(available, prize)
        end
    end
    
    -- Shuffle and pick 3
    for i = #available, 2, -1 do
        local j = math.random(i)
        available[i], available[j] = available[j], available[i]
    end
    
    local shop_prizes = {}
    for i = 1, math.min(3, #available) do
        table.insert(shop_prizes, available[i])
    end
    
    return shop_prizes
end

-- Helper function to check if a card has all suits (via arcoiris sticker)
local function card_has_all_suits(card)
    return card.attached_sticker == "arcoiris"
end

-- Helper function to check if a card matches a specific suit (considering arcoiris sticker)
local function card_matches_suit(card, target_suit)
    return card.suit == target_suit or card_has_all_suits(card)
end

-- Helper function to compare hands for amarraco win conditions
local function compare_hands_for_amarracos(player_breakdown, ai_breakdown, player_hand)
    local results = {
        wins_pequena = player_breakdown.pequenas < ai_breakdown.pequenas,
        wins_grande = player_breakdown.grandes > ai_breakdown.grandes,
        wins_pares = player_breakdown.multiplier > ai_breakdown.multiplier,
        wins_juego = player_breakdown.juego > ai_breakdown.juego,
        has_all_suits = false
    }
    
    -- Check if player has all 4 suits (including arcoiris sticker effects)
    local suits = {}
    for _, card in ipairs(player_hand) do
        if card_has_all_suits(card) then
            -- Arcoiris sticker gives card all 4 suits
            suits["Oros"] = true
            suits["Copas"] = true
            suits["Espadas"] = true
            suits["Bastos"] = true
        else
            suits[card.suit] = true
        end
    end
    results.has_all_suits = (suits["Oros"] and suits["Copas"] and suits["Espadas"] and suits["Bastos"])
    
    return results
end

-- Apply prize effects to scoring breakdown
function amarracos.apply_effects(breakdown, hand, owned_prizes, state)
    local effects = {
        damage_bonus = 0,
        defense_bonus = 0,
        pesetas_bonus = 0,
        hp_bonus = 0,
        pesetas_multiplier = 1,
        shop_discount = 0,
        multiplier_bonus = 1,
        accuracy_override = nil,
        disable_perfect_juego = false,
        hand_modified = false,  -- Flag to indicate if hand values were modified
        modified_hand = {}  -- Copy of hand with modifications
    }
    
    -- Create modified hand copy for bola_billar effect
    local working_hand = {}
    for _, card in ipairs(hand) do
        table.insert(working_hand, {
            value = card.value,
            suit = card.suit,
            display_value = card.display_value,
            selected = card.selected
        })
    end
    
    -- Apply bola_billar first (modifies hand values)
    for _, prize in ipairs(owned_prizes) do
        if prize.id == "bola_billar" then
            for _, card in ipairs(working_hand) do
                if card.value == 7 then
                    card.value = 10
                end
            end
            effects.hand_modified = true
            effects.modified_hand = working_hand
        end
    end
    
    -- Get AI breakdown for comparisons (only if state provided)
    local ai_breakdown = nil
    local win_conditions = nil
    if state and state.ai_played_cards and #state.ai_played_cards > 0 then
        local scoring = require("scoring")
        ai_breakdown = scoring.get_full_breakdown(state.ai_played_cards)
        win_conditions = compare_hands_for_amarracos(breakdown, ai_breakdown, working_hand)
    end
    
    -- First pass: Apply all non-pin, non-multiplicative effects
    local has_pin = false
    for _, prize in ipairs(owned_prizes) do
        if prize.id == "pin" then
            has_pin = true
        elseif prize.id == "token" then
            -- Lower accuracy = more damage (inverse relationship) - buffed formula
            local accuracy_penalty = (100 - breakdown.accuracy) / 100
            local base_bonus = breakdown.grandes * accuracy_penalty * 2  -- Use base damage with 2x multiplier
            effects.damage_bonus = effects.damage_bonus + math.floor(base_bonus)
        elseif prize.id == "boton" then
            -- Boost even cards (2,4,6,8,10,12) - add their values to damage
            for _, game_card in ipairs(hand) do
                if game_card.value % 2 == 0 and game_card.value <= 12 then
                    effects.damage_bonus = effects.damage_bonus + game_card.value
                end
            end
        elseif prize.id == "hebilla" then
            -- Boost odd cards (1,3,5,7,11) - add their values to damage
            for _, game_card in ipairs(hand) do
                if (game_card.value % 2 == 1 and game_card.value <= 11) then
                    effects.damage_bonus = effects.damage_bonus + game_card.value
                end
            end
        elseif prize.id == "reliquia" then
            -- Oros cards add value to pesetas (including arcoiris sticker)
            for _, game_card in ipairs(hand) do
                if card_matches_suit(game_card, "Oros") then
                    local value = game_card.value > 10 and 10 or game_card.value
                    effects.pesetas_bonus = effects.pesetas_bonus + value
                end
            end
        elseif prize.id == "posavasos" then
            -- Copas cards add value to HP (including arcoiris sticker)
            for _, game_card in ipairs(hand) do
                if card_matches_suit(game_card, "Copas") then
                    local value = game_card.value > 10 and 10 or game_card.value
                    effects.hp_bonus = effects.hp_bonus + value
                end
            end
        elseif prize.id == "afilar" then
            -- Espadas cards add value to damage (including arcoiris sticker)
            for _, game_card in ipairs(hand) do
                if card_matches_suit(game_card, "Espadas") then
                    local value = game_card.value > 10 and 10 or game_card.value
                    effects.damage_bonus = effects.damage_bonus + value
                end
            end
        elseif prize.id == "madera" then
            -- Bastos cards add value to defense (including arcoiris sticker)
            for _, game_card in ipairs(hand) do
                if card_matches_suit(game_card, "Bastos") then
                    local value = game_card.value > 10 and 10 or game_card.value
                    effects.defense_bonus = effects.defense_bonus + value
                end
            end
        elseif prize.id == "dos_euro" then
            effects.pesetas_multiplier = effects.pesetas_multiplier * 2
        elseif prize.id == "tres_euro" then
            effects.shop_discount = effects.shop_discount + 20  -- 20% discount
        elseif prize.id == "tenis" then
            -- Always 100% accuracy, disable perfect juego multiplier
            effects.accuracy_override = 100
            effects.disable_perfect_juego = true
        elseif prize.id == "chapa" then
            -- Add juego to base damage if win juego vs AI
            if win_conditions and win_conditions.wins_juego then
                effects.damage_bonus = effects.damage_bonus + breakdown.juego
            end
        elseif prize.id == "bola_billar" then
            -- Already handled above (modifies hand values)
        end
    end
    
    -- Second pass: Apply pin effect if present (after all defense bonuses are calculated)
    if has_pin then
        local total_defense = breakdown.defense + effects.defense_bonus
        effects.damage_bonus = effects.damage_bonus + total_defense
        effects.defense_bonus = -total_defense  -- Zero out all defense (base + bonuses)
    end
    
    -- Third pass: Apply multiplicative effects (after additive effects)
    for _, prize in ipairs(owned_prizes) do
        if prize.id == "single_peseta" then
            -- x2 mult if win pequeña vs AI
            if win_conditions and win_conditions.wins_pequena then
                effects.multiplier_bonus = effects.multiplier_bonus * 2
            end
        elseif prize.id == "cien_peseta" then
            -- x2 mult if win grande vs AI
            if win_conditions and win_conditions.wins_grande then
                effects.multiplier_bonus = effects.multiplier_bonus * 2
            end
        elseif prize.id == "duro" then
            -- x2 mult if win pares vs AI
            if win_conditions and win_conditions.wins_pares then
                effects.multiplier_bonus = effects.multiplier_bonus * 2
            end
        elseif prize.id == "venticinco_peseta" then
            -- x2 mult if win juego vs AI
            if win_conditions and win_conditions.wins_juego then
                effects.multiplier_bonus = effects.multiplier_bonus * 2
            end
        elseif prize.id == "canica" then
            -- x3 mult if all suits in hand
            if win_conditions and win_conditions.has_all_suits then
                effects.multiplier_bonus = effects.multiplier_bonus * 3
            end
        end
    end
    
    return effects
end

-- Apply round-based effects
function amarracos.apply_round_effects(owned_prizes, state)
    for _, prize in ipairs(owned_prizes) do
        if prize.id == "euro" then
            state.pesetas = state.pesetas + 5
        end
    end
end

-- Check if player has specific prize
function amarracos.has_prize(owned_prizes, prize_id)
    for _, prize in ipairs(owned_prizes) do
        if prize.id == prize_id then
            return true
        end
    end
    return false
end

-- Get prize by ID
function amarracos.get_prize_by_id(prize_id)
    for _, prize in ipairs(amarracos.PRIZES) do
        if prize.id == prize_id then
            return prize
        end
    end
    return nil
end

return amarracos