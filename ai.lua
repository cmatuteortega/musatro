-- AI opponent module for Spanish Deck Card Game
local card = require("card")
local scoring = require("scoring")

local ai = {}

-- Cuñao phrases for different situations
local cunao_phrases = {
    victory = {
        "¡Así se juega al mus, chaval!",
        "¡Te he dado una lección de mus!",
        "¡Esto es lo que pasa cuando juegas con un veterano!",
        "¡En mis tiempos esto no habría pasado!",
        "¡Menos Netflix y más mus, que se nota!"
    },
    discard = {
        "Voy a descartar, pero no te creas que voy mal...",
        "Estos naipes no me convencen, pero tú lo tienes peor",
        "A ver si con estas nuevas cartas te doy el paseíllo",
        "Cambio cartas, pero el resultado va a ser el mismo",
        "Estas cartas no me gustan, pero tampoco las necesito"
    },
    playing = {
        "¡A ver qué tal se te da esto, zagal!",
        "¡Prepárate para una sorpresa!",
        "¡Esto va a dolerte más a ti que a mí!",
        "¡Te voy a enseñar cómo se juega de verdad!",
        "¡Espero que tengas algo bueno, porque yo vengo cargado!"
    },
    defeat = {
        "¡Bah! Ha sido suerte del principiante...",
        "¡En el próximo asalto no tendrás tanta suerte!",
        "¡Esto ha sido un calentamiento nada más!",
        "¡Has tenido más suerte que habilidad!",
        "¡La próxima vez no te lo pongo tan fácil!"
    }
}

-- AI strategy for card selection
function ai.select_cards(hand)
    -- Strategy: Prioritize pairs, then high cards, then good juego potential
    local counts = {}
    
    -- Count occurrences of each card value
    for _, game_card in ipairs(hand) do
        counts[game_card.value] = (counts[game_card.value] or 0) + 1
    end
    
    -- Find cards that form pairs or better
    local paired_values = {}
    for value, count in pairs(counts) do
        if count >= 2 then
            table.insert(paired_values, {value = value, count = count})
        end
    end
    
    -- Sort pairs by count (quadruples > triples > pairs)
    table.sort(paired_values, function(a, b) return a.count > b.count end)
    
    local selected_hand = {}
    
    -- First, add all cards that form the best pairs
    if #paired_values > 0 then
        local best_pair_value = paired_values[1].value
        for _, game_card in ipairs(hand) do
            if game_card.value == best_pair_value and #selected_hand < 4 then
                table.insert(selected_hand, game_card)
            end
        end
        
        -- If we have room and there's a second pair, add it
        if #selected_hand < 4 and #paired_values > 1 then
            local second_pair_value = paired_values[2].value
            for _, game_card in ipairs(hand) do
                if game_card.value == second_pair_value and #selected_hand < 4 then
                    table.insert(selected_hand, game_card)
                end
            end
        end
    end
    
    -- Fill remaining slots with highest value cards that aren't already selected
    if #selected_hand < 4 then
        local remaining_cards = {}
        for _, game_card in ipairs(hand) do
            local already_selected = false
            for _, selected_card in ipairs(selected_hand) do
                if game_card == selected_card then
                    already_selected = true
                    break
                end
            end
            if not already_selected then
                table.insert(remaining_cards, game_card)
            end
        end
        
        -- Sort remaining cards by value (descending)
        table.sort(remaining_cards, function(a, b) return a.value > b.value end)
        
        -- Add highest value cards to fill hand
        for i = 1, 4 - #selected_hand do
            if remaining_cards[i] then
                table.insert(selected_hand, remaining_cards[i])
            end
        end
    end
    
    return selected_hand
end

-- AI decision making for discarding
function ai.wants_to_discard(hand)
    -- Simple strategy: discard if hand strength is below threshold
    local breakdown = scoring.get_full_breakdown(hand)
    
    -- Calculate hand strength score
    local strength = 0
    strength = strength + breakdown.multiplier * 10  -- Pairs are valuable
    strength = strength + breakdown.grandes         -- High cards are good
    strength = strength + (breakdown.juego / 31) * 20  -- Juego progress is important
    
    -- AI discards if strength is below 25 (out of ~50 max)
    return strength < 25
end

-- AI discarding strategy
function ai.select_cards_to_discard(hand)
    -- Strategy: Keep pairs and high cards, discard low singles
    local counts = {}
    
    -- Count occurrences of each card value
    for _, game_card in ipairs(hand) do
        counts[game_card.value] = (counts[game_card.value] or 0) + 1
    end
    
    local cards_to_discard = {}
    
    -- Look for low value cards that aren't part of pairs
    for _, game_card in ipairs(hand) do
        local is_paired = counts[game_card.value] >= 2
        local is_low_value = game_card.value <= 4
        
        -- Discard low singles, but keep pairs and high cards
        if not is_paired and is_low_value and #cards_to_discard < 2 then
            table.insert(cards_to_discard, game_card)
        end
    end
    
    -- If we didn't find enough low cards to discard, add more based on value
    if #cards_to_discard < 2 then
        local non_paired_cards = {}
        for _, game_card in ipairs(hand) do
            if counts[game_card.value] == 1 then
                table.insert(non_paired_cards, game_card)
            end
        end
        
        -- Sort by value (ascending) to discard lowest first
        table.sort(non_paired_cards, function(a, b) return a.value < b.value end)
        
        for _, game_card in ipairs(non_paired_cards) do
            local already_discarding = false
            for _, discard_card in ipairs(cards_to_discard) do
                if game_card == discard_card then
                    already_discarding = true
                    break
                end
            end
            
            if not already_discarding and #cards_to_discard < 2 then
                table.insert(cards_to_discard, game_card)
            end
        end
    end
    
    return cards_to_discard
end

-- Remove cards from AI hand
function ai.remove_cards_from_hand(hand, cards_to_remove)
    local new_hand = {}
    for _, game_card in ipairs(hand) do
        local should_remove = false
        for _, remove_card in ipairs(cards_to_remove) do
            if game_card == remove_card then
                should_remove = true
                break
            end
        end
        if not should_remove then
            table.insert(new_hand, game_card)
        end
    end
    return new_hand
end

-- Get AI difficulty scaling
function ai.get_difficulty_multiplier(round)
    -- AI gets slightly stronger each round
    return 1 + (round - 1) * 0.1
end

-- Calculate AI starting HP for the round
function ai.calculate_hp(round)
    local base_hp = 25
    local hp_increase = math.floor((round - 1) * 15)  -- +15 HP per round
    return base_hp + hp_increase
end

-- Get random cuñao phrase for specific situation
function ai.get_cunao_phrase(situation)
    local phrases = cunao_phrases[situation]
    if phrases and #phrases > 0 then
        return phrases[math.random(1, #phrases)]
    end
    return ""
end

-- Get phrase when AI is about to play
function ai.get_playing_phrase()
    return ai.get_cunao_phrase("playing")
end

-- Get phrase when AI discards
function ai.get_discard_phrase()
    return ai.get_cunao_phrase("discard")
end

-- Get phrase when AI wins
function ai.get_victory_phrase()
    return ai.get_cunao_phrase("victory")
end

-- Get phrase when AI loses
function ai.get_defeat_phrase()
    return ai.get_cunao_phrase("defeat")
end

return ai