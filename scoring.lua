-- Spanish Card Game Scoring System
-- Based on traditional Spanish card game mechanics

local scoring = {}

-- Calculate juego (sum with face cards worth 10)
function scoring.calculate_juego(hand)
    local sum = 0
    local debug_info = {}  -- For tracking calculation
    
    for _, game_card in ipairs(hand) do
        local card_contribution = game_card.value
        local is_smiley = false
        
        -- Check if card has smiley sticker (counts as 10)
        if game_card.attached_sticker then
            local stickers = require("stickers")
            local sticker = stickers.get_sticker_by_id(game_card.attached_sticker)
            if sticker and sticker.effect_type == "face_card_juego" then
                card_contribution = 10  -- Smiley sticker: card counts as 10
                is_smiley = true
                sum = sum + 10
            elseif game_card.value > 10 then
                card_contribution = 10  -- Regular face cards: Sota, Caballo, Rey = 10
                sum = sum + 10
            else
                sum = sum + game_card.value  -- Regular cards: use actual value
            end
        elseif game_card.value > 10 then
            card_contribution = 10  -- Sota, Caballo, Rey = 10
            sum = sum + 10
        else 
            sum = sum + game_card.value
        end
        
        -- Store debug info
        table.insert(debug_info, {
            original_value = game_card.value,
            contribution = card_contribution,
            is_smiley = is_smiley,
            has_sticker = game_card.attached_sticker ~= nil
        })
    end
    
    -- Store debug info globally for access (temporary debugging)
    _G.juego_debug = {
        total = sum,
        cards = debug_info,
        calculation_time = os.time()
    }
    
    return sum
end

-- Calculate grandes (highest card value, used for damage)
function scoring.calculate_grandes(hand)
    local max_value = 0
    for _, game_card in ipairs(hand) do
        if game_card.value > max_value then
            max_value = game_card.value
        end
    end
    return max_value
end

-- Calculate pequeñas (lowest card value, used for defense)
function scoring.calculate_pequenas(hand)
    local min_value = 13  -- Start with max possible value
    for _, game_card in ipairs(hand) do
        if game_card.value < min_value then
            min_value = game_card.value
        end
    end
    return min_value
end

-- Calculate pares (pairs, triples, quadruples) and return multiplier
function scoring.calculate_pares(hand)
    local counts = {}
    
    -- Count occurrences of each card value
    for _, game_card in ipairs(hand) do
        counts[game_card.value] = (counts[game_card.value] or 0) + 1
    end
    
    -- Determine multiplier based on pairs
    local pair_counts = {}
    for value, count in pairs(counts) do
        if count >= 2 then
            table.insert(pair_counts, count)
        end
    end
    
    table.sort(pair_counts, function(a, b) return a > b end)
    
    if #pair_counts == 0 then
        return 1, "No pairs"
    elseif pair_counts[1] == 4 then
        return 5, "Four of a kind"  -- Four of a kind = x5
    elseif pair_counts[1] == 3 then
        return 3, "Three of a kind"
    elseif #pair_counts >= 2 and pair_counts[1] == 2 and pair_counts[2] == 2 then
        return 4, "Two pairs"  -- Double pair = x4
    elseif pair_counts[1] == 2 then
        return 2, "One pair"   -- Single pair = x2
    else
        return 1, "No pairs"
    end
end

-- Calculate damage based on grandes and pares multiplier
function scoring.calculate_damage(hand, bonuses)
    bonuses = bonuses or {}
    local grandes = scoring.calculate_grandes(hand)
    local multiplier, pair_description = scoring.calculate_pares(hand)
    local damage = grandes * multiplier
    
    return damage, grandes, multiplier, pair_description
end

-- Calculate defense based on pequeñas (inverted scale)
function scoring.calculate_defense(hand, bonuses)
    bonuses = bonuses or {}
    local pequenas = scoring.calculate_pequenas(hand)
    local defense = 10 - pequenas  -- Lower cards give better defense
    
    return math.max(0, defense), pequenas
end

-- Calculate accuracy based on juego (closer to 31 = better accuracy)
function scoring.calculate_accuracy(hand, bonuses)
    bonuses = bonuses or {}
    local juego = scoring.calculate_juego(hand)
    local accuracy
    
    if juego > 31 then
        accuracy = 100  -- Over 31 gives perfect accuracy
    else
        accuracy = (juego / 31) * 100
    end
    
    return accuracy, juego
end

-- Check if hand sums to exactly 31 (special condition)
function scoring.is_perfect_juego(hand)
    local juego = scoring.calculate_juego(hand)
    return juego == 31
end

-- Get comprehensive scoring breakdown
function scoring.get_full_breakdown(hand, bonuses)
    bonuses = bonuses or {}
    local damage, grandes, multiplier, pair_description = scoring.calculate_damage(hand, bonuses)
    local defense, pequenas = scoring.calculate_defense(hand, bonuses)
    local accuracy, juego = scoring.calculate_accuracy(hand, bonuses)
    local is_perfect = scoring.is_perfect_juego(hand)
    
    -- Calculate total multiplier including perfect juego bonus
    local total_multiplier = multiplier
    local mult_description = pair_description
    if is_perfect then
        total_multiplier = multiplier * 3
        mult_description = pair_description .. " + Perfect Juego (×3)"
    end
    
    -- Calculate final damage with all multipliers
    local final_damage = grandes * total_multiplier
    
    return {
        -- Main scores
        damage = final_damage,  -- Final damage with all multipliers
        base_damage = grandes,  -- Just the base damage from highest card
        defense = defense,
        accuracy = accuracy,
        juego = juego,
        
        -- Component breakdown
        grandes = grandes,
        pequenas = pequenas,
        multiplier = multiplier,  -- Just pairs multiplier
        total_multiplier = total_multiplier,  -- Pairs + juego multiplier
        pair_description = pair_description,
        mult_description = mult_description,
        
        -- Special conditions
        is_perfect_juego = is_perfect,
        
        -- Display strings
        shield_text = string.format("SHIELD: %d", defense),
        juego_text = is_perfect and string.format("PERFECT JUEGO! (%d)", juego) or string.format("Juego: %d", juego)
    }
end

-- Calculate final score for the round (combines all factors)
function scoring.calculate_final_score(hand, bonuses)
    bonuses = bonuses or {}
    local breakdown = scoring.get_full_breakdown(hand, bonuses)
    local base_score = breakdown.damage
    
    -- Triple score for perfect juego
    if breakdown.is_perfect_juego then
        base_score = base_score * 3
    end
    
    return base_score, breakdown
end

-- Check if an attack hits based on accuracy
function scoring.check_hit(accuracy)
    local roll = math.random() * 100  -- Random number 0-100
    return roll <= accuracy
end

return scoring