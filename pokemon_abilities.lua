-- Pokemon abilities system for Spanish Deck Card Game
local scoring = require("scoring")

local pokemon_abilities = {}

-- Apply Pokemon abilities to scoring breakdown and hand
function pokemon_abilities.apply_effects(breakdown, player_hand, ai_hand, game_state)
    local effects = {
        damage_bonus = 0,
        defense_bonus = 0,
        multiplier_bonus = 1,
        pesetas_bonus = 0,
        accuracy_override = nil,
        hp_bonus = 0,
        minimum_damage = 0,
        enemy_damage_multiplier = 1.0
    }
    
    -- Check each card in player hand for Pokemon abilities
    for _, card in ipairs(player_hand) do
        if card.card_type == "pokemon" and card.ability then
            local ability = card.ability
            
            -- Apply ability effects based on effect_type
            if ability.effect_type == "flat_damage" then
                -- Moltres - Cuerpo Llama: +10 daño al jugarse
                if card.pokemon == "Moltres" then
                    effects.damage_bonus = effects.damage_bonus + 10
                end
                
            elseif ability.effect_type == "mult_per_low_card" then
                -- Combee - Enjambre: +1 mult por cada carta de valor 3 o menos en tu mano
                if card.pokemon == "Combee" then
                    local low_cards = 0
                    for _, hand_card in ipairs(player_hand) do
                        if hand_card.value <= 3 then
                            low_cards = low_cards + 1
                        end
                    end
                    effects.multiplier_bonus = effects.multiplier_bonus + low_cards
                end
                
            elseif ability.effect_type == "trio_multiplier" then
                -- Dugtrio - Triple Amenaza: Si tus pares son un trío, x3 al mult
                if card.pokemon == "Dugtrio" then
                    -- Check if player has three of a kind
                    local value_counts = {}
                    for _, hand_card in ipairs(player_hand) do
                        local card_value = hand_card.value
                        value_counts[card_value] = (value_counts[card_value] or 0) + 1
                    end
                    
                    -- Check for three of a kind
                    for _, count in pairs(value_counts) do
                        if count == 3 then
                            effects.multiplier_bonus = effects.multiplier_bonus * 3
                            break
                        end
                    end
                end
                
            elseif ability.effect_type == "steal_oros" then
                -- Magneton - Imán: Suma la mitad de los oros de la mano enemiga a tus pesetas
                if card.pokemon == "Magneton" and ai_hand then
                    local ai_oros_value = 0
                    for _, ai_card in ipairs(ai_hand) do
                        if ai_card.suit == "Oros" or (ai_card.attached_sticker == "arcoiris") then
                            local card_value = (ai_card.value >= 11) and 10 or ai_card.value
                            ai_oros_value = ai_oros_value + card_value
                        end
                    end
                    effects.pesetas_bonus = effects.pesetas_bonus + math.floor(ai_oros_value / 2)
                end
                
            -- VALUE 2 ABILITIES
            elseif ability.effect_type == "lowest_card_mult" then
                -- Doduo - Doble Golpe: Si es tu carta más baja, +2 mult
                if card.pokemon == "Doduo" then
                    local lowest_value = 99
                    for _, hand_card in ipairs(player_hand) do
                        if hand_card.value < lowest_value then
                            lowest_value = hand_card.value
                        end
                    end
                    if card.value == lowest_value then
                        effects.multiplier_bonus = effects.multiplier_bonus + 2
                    end
                end
                
            elseif ability.effect_type == "mult_per_espadas" then
                -- Doublade - Danza Espada: +1 mult por cada carta de espadas en mano
                if card.pokemon == "Doublade" then
                    local espadas_count = 0
                    for _, hand_card in ipairs(player_hand) do
                        if hand_card.suit == "Espadas" or (hand_card.attached_sticker == "arcoiris") then
                            espadas_count = espadas_count + 1
                        end
                    end
                    effects.multiplier_bonus = effects.multiplier_bonus + espadas_count
                end
                
            elseif ability.effect_type == "pairs_multiplier" then
                -- Weezing - Gas Venenoso: si puntas en pares, x2 mult
                if card.pokemon == "Weezing" then
                    -- Check if player has any pairs
                    local value_counts = {}
                    for _, hand_card in ipairs(player_hand) do
                        local card_value = hand_card.value
                        value_counts[card_value] = (value_counts[card_value] or 0) + 1
                    end
                    
                    for _, count in pairs(value_counts) do
                        if count >= 2 then  -- Has pairs
                            effects.multiplier_bonus = effects.multiplier_bonus * 2
                            break
                        end
                    end
                end
                
            elseif ability.effect_type == "perfect_accuracy" then
                -- Zapdos - Trueno: Precisión perfecta (100%) al jugarse
                if card.pokemon == "Zapdos" then
                    effects.accuracy_override = 100
                end
                
            -- VALUE 4 ABILITIES
            elseif ability.effect_type == "enemy_accuracy_debuff" then
                -- Cofrarigus - Momia: -10% de precisión al enemigo al jugarse
                -- Note: This affects enemy accuracy but current system doesn't support AI accuracy modification
                -- For now, this ability is not fully implemented
                if card.pokemon == "Cofrarigus" then
                    -- TODO: Implement enemy accuracy reduction system
                end
                  
            elseif ability.effect_type == "damage_per_enemy_face" then
                -- Machamp - No Guard: +10 de daño por cada figura del oponente
                if card.pokemon == "Machamp" and ai_hand then
                    local enemy_faces = 0
                    for _, ai_card in ipairs(ai_hand) do
                        if ai_card.value >= 11 then  -- Figures (11, 12, 13)
                            enemy_faces = enemy_faces + 1
                        end
                    end
                    effects.damage_bonus = effects.damage_bonus + (enemy_faces * 10)
                end
                
            elseif ability.effect_type == "damage_no_faces" then
                -- Metagross - Cuerpo Puro: +20 si no tienes figuras en la mano
                if card.pokemon == "Metagross" then
                    local has_faces = false
                    for _, hand_card in ipairs(player_hand) do
                        if hand_card.value >= 11 then
                            has_faces = true
                            break
                        end
                    end
                    if not has_faces then
                        effects.damage_bonus = effects.damage_bonus + 20
                    end
                end
                
            -- VALUE 5 ABILITIES
            elseif ability.effect_type == "mult_per_odd_card" then
                -- Chandelure - Llamarada: +1 mult por carta de valor impar
                if card.pokemon == "Chandelure" then
                    local odd_cards = 0
                    for _, hand_card in ipairs(player_hand) do
                        if hand_card.value % 2 == 1 then  -- Odd values
                            odd_cards = odd_cards + 1
                        end
                    end
                    effects.multiplier_bonus = effects.multiplier_bonus + odd_cards
                end
                
            elseif ability.effect_type == "enemy_damage_reduction" then
                -- Cinccino - Encanto: Reduce el daño del enemigo al 50%
                if card.pokemon == "Cinccino_" then
                    effects.enemy_damage_multiplier = effects.enemy_damage_multiplier * 0.5
                end
                
            elseif ability.effect_type == "minimum_damage" then
                -- Staryu - Rapidez: Siempre impacta al menos 10 daño directo, incluso con 0% precisión (nunca falla)
                if card.pokemon == "Staryu" then
                    effects.minimum_damage = math.max(effects.minimum_damage, 10)
                    effects.accuracy_override = 100  -- Never fails
                end
                
            elseif ability.effect_type == "juego_25_multiplier" then
                -- Victini - Llama V: Si juego = exactamente 25, x5
                if card.pokemon == "Victini_" and breakdown.juego == 25 then
                    effects.multiplier_bonus = effects.multiplier_bonus * 5
                end
                
            -- VALUE 6 ABILITIES
            elseif ability.effect_type == "four_suits_multiplier" then
                -- Exeggcute - Bomba Germen: x2 mult si tienes 4 palos diferentes
                if card.pokemon == "Eggxecute" then
                    local suits = {}
                    for _, hand_card in ipairs(player_hand) do
                        suits[hand_card.suit] = true
                    end
                    local suit_count = 0
                    for _ in pairs(suits) do
                        suit_count = suit_count + 1
                    end
                    if suit_count == 4 then
                        effects.multiplier_bonus = effects.multiplier_bonus * 2
                    end
                end
                
            elseif ability.effect_type == "mult_per_figure" then
                -- Seismitoad - Telúrico: +1 mult por cada figura (11,12,13) en la mano
                if card.pokemon == "Seismitoad" then
                    local figure_count = 0
                    for _, hand_card in ipairs(player_hand) do
                        if hand_card.value >= 11 then
                            figure_count = figure_count + 1
                        end
                    end
                    effects.multiplier_bonus = effects.multiplier_bonus + figure_count
                end
                
            elseif ability.effect_type == "next_round_value_boost" then
                -- Volcarona - Danza Aleteo: Próxima ronda, tu mano obtiene +3 a todos los valores
                if card.pokemon == "Volcarona_" and game_state then
                    -- This effect should be applied to next round's hand
                    game_state.volcarona_boost = true
                end
                
            elseif ability.effect_type == "damage_only_even_card" then
                -- Vulpix - Fuego Fatuo: +15 de daño si es la única carta par
                if card.pokemon == "Vulpix" then
                    local even_count = 0
                    for _, hand_card in ipairs(player_hand) do
                        if hand_card.value % 2 == 0 then
                            even_count = even_count + 1
                        end
                    end
                    if even_count == 1 then  -- Only one even card
                        effects.damage_bonus = effects.damage_bonus + 15
                    end
                end
                
            -- VALUE 7 ABILITIES
            elseif ability.effect_type == "damage_reduction_on_loss" then
                -- Chansey - Amortiguador: Si pierdes recibes el 50% del daño
                if card.pokemon == "Chansey" then
                    effects.enemy_damage_multiplier = effects.enemy_damage_multiplier * 0.5
                end
                
            elseif ability.effect_type == "pesetas_on_play" then
                -- Gholdengo - Lluvia Oro: Ganas 5 pesetas al jugarse
                if card.pokemon == "Gholdengo" then
                    effects.pesetas_bonus = effects.pesetas_bonus + 5
                end
                
            elseif ability.effect_type == "perfect_accuracy_highest_card" then
                -- Jirachi - Deseo: Si es tu carta más alta, tu precisión es del 100%
                if card.pokemon == "Jirachi" then
                    local highest_value = 0
                    for _, hand_card in ipairs(player_hand) do
                        if hand_card.value > highest_value then
                            highest_value = hand_card.value
                        end
                    end
                    if card.value == highest_value then
                        effects.accuracy_override = 100
                    end
                end
                
            elseif ability.effect_type == "double_pokemon_effects" then
                -- Togekiss - Don Natural: Duplica todos los efectos positivos de otros Pokémon esta ronda
                if card.pokemon == "Togekiss" then
                    -- This would require complex interaction with other pokemon effects
                    -- For now, just provide a general bonus
                    effects.multiplier_bonus = effects.multiplier_bonus + 2
                end
                
            -- VALUE 11 ABILITIES
            elseif ability.effect_type == "reveal_enemy_hand" then
                -- Gardevoir - Psíquico: Predice la mano del enemigo - ve sus cartas antes de jugar
                if card.pokemon == "Gardevoir" then
                    -- This is more of a UI effect - for now just provide a small bonus
                    effects.damage_bonus = effects.damage_bonus + 10
                end
                
            elseif ability.effect_type == "mult_if_highest_card" then
                -- Hitmonchan - A Bocajarro: x2 mult si es carta alta
                if card.pokemon == "Hitmonchan" then
                    local highest_value = 0
                    for _, hand_card in ipairs(player_hand) do
                        if hand_card.value > highest_value then
                            highest_value = hand_card.value
                        end
                    end
                    if card.value == highest_value then
                        effects.multiplier_bonus = effects.multiplier_bonus * 2
                    end
                end
                
            elseif ability.effect_type == "mult_no_pairs" then
                -- Lucario - Esfera Aural: x2 mult sin pares
                if card.pokemon == "Lucario" then
                    local value_counts = {}
                    for _, hand_card in ipairs(player_hand) do
                        local card_value = hand_card.value
                        value_counts[card_value] = (value_counts[card_value] or 0) + 1
                    end
                    
                    local has_pairs = false
                    for _, count in pairs(value_counts) do
                        if count >= 2 then
                            has_pairs = true
                            break
                        end
                    end
                    
                    if not has_pairs then
                        effects.multiplier_bonus = effects.multiplier_bonus * 2
                    end
                end
                
            elseif ability.effect_type == "double_defense_highest_card" then
                -- Mr. Mime - Barrera: x2 escudo si es carta alta
                if card.pokemon == "MrMime" then
                    local highest_value = 0
                    for _, hand_card in ipairs(player_hand) do
                        if hand_card.value > highest_value then
                            highest_value = hand_card.value
                        end
                    end
                    if card.value == highest_value then
                        effects.defense_bonus = effects.defense_bonus + breakdown.defense
                    end
                end
                
            -- VALUE 12 ABILITIES
            elseif ability.effect_type == "damage_per_hp" then
                -- Horsea - Danza Dragón: +1 daño por cada HP
                if card.pokemon == "Horsea" and game_state then
                    effects.damage_bonus = effects.damage_bonus + game_state.player_hp
                end
                
            elseif ability.effect_type == "mult_if_highest_card_3" then
                -- Girafarig - Premonición: Si es tu carta más alta +3 mult
                if card.pokemon == "Jirafarig" then
                    local highest_value = 0
                    for _, hand_card in ipairs(player_hand) do
                        if hand_card.value > highest_value then
                            highest_value = hand_card.value
                        end
                    end
                    if card.value == highest_value then
                        effects.multiplier_bonus = effects.multiplier_bonus + 3
                    end
                end
                
            elseif ability.effect_type == "mult_per_deck_card" then
                -- Mudsdale - Aguante: +0.1 mult por cada carta restante en la baraja
                if card.pokemon == "Mudsdale" and game_state then
                    local deck_count = #game_state.deck
                    effects.multiplier_bonus = effects.multiplier_bonus + (deck_count * 0.1)
                end
                
            elseif ability.effect_type == "extra_hand_if_highest" then
                -- Rapidash - Agilidad: Añade una mano extra si es carta alta
                if card.pokemon == "Rapidash" and game_state then
                    local highest_value = 0
                    for _, hand_card in ipairs(player_hand) do
                        if hand_card.value > highest_value then
                            highest_value = hand_card.value
                        end
                    end
                    if card.value == highest_value then
                        -- Grant extra hand for this round
                        game_state.extra_hands = (game_state.extra_hands or 0) + 1
                    end
                end
                
            -- VALUE 13 ABILITIES
            elseif ability.effect_type == "instant_win_chance" then
                -- Kingler - Guillotina: 10% probabilidad de ganar instantáneamente la ronda
                if card.pokemon == "Kingler" then
                    if math.random() <= 0.1 then  -- 10% chance
                        effects.instant_win = true
                    end
                end
                
            elseif ability.effect_type == "enemy_damage_on_win" then
                -- Nidoking - Punto Tóxico: El enemigo recibe 20% daño si gana el juego
                if card.pokemon == "Nidoking" and game_state then
                    -- This effect applies when enemy wins - handled in combat resolution
                    game_state.nidoking_toxic = true
                end
                
            elseif ability.effect_type == "massive_damage_no_defense" then
                -- Slakking - Pereza: +50 daño masivo, pero tu defensa es 0
                if card.pokemon == "Slacking" then
                    effects.damage_bonus = effects.damage_bonus + 50
                    effects.defense_bonus = -breakdown.defense  -- Set defense to 0
                end
                
            elseif ability.effect_type == "mult_only_figure" then
                -- Slowking - Ritmo Propio: Si es la única figura de tu mano, x3 mult
                if card.pokemon == "Slowking" then
                    local figure_count = 0
                    for _, hand_card in ipairs(player_hand) do
                        if hand_card.value >= 11 then
                            figure_count = figure_count + 1
                        end
                    end
                    if figure_count == 1 then  -- Only one figure
                        effects.multiplier_bonus = effects.multiplier_bonus * 3
                    end
                end
                
            -- VALUE 1 ABILITIES
            elseif ability.effect_type == "defense_boost" then
                -- Articuno - Ventisca: Defensa +5 al jugarse
                if card.pokemon == "Articuno" then
                    effects.defense_bonus = effects.defense_bonus + 5
                end
                
            elseif ability.effect_type == "damage_no_pairs" then
                -- Deino - Furia Ciega: +20 daño si no tienes pares
                if card.pokemon == "Deino" then
                    local value_counts = {}
                    for _, hand_card in ipairs(player_hand) do
                        local card_value = hand_card.value
                        value_counts[card_value] = (value_counts[card_value] or 0) + 1
                    end
                    
                    local has_pairs = false
                    for _, count in pairs(value_counts) do
                        if count >= 2 then
                            has_pairs = true
                            break
                        end
                    end
                    
                    if not has_pairs then
                        effects.damage_bonus = effects.damage_bonus + 20
                    end
                end
                
            elseif ability.effect_type == "copy_highest_card_ability" then
                -- Mew - Transformación: Copia la carta de mayor valor en tu mano con su habilidad
                if card.pokemon == "Mew" then
                    -- Find highest value card that's not Mew
                    local highest_value = 0
                    local highest_card = nil
                    for _, hand_card in ipairs(player_hand) do
                        if hand_card.value > highest_value and hand_card.pokemon ~= "Mew" then
                            highest_value = hand_card.value
                            highest_card = hand_card
                        end
                    end
                    -- For now, just provide a generic bonus based on highest card
                    if highest_card then
                        effects.damage_bonus = effects.damage_bonus + highest_value
                    end
                end
                
            elseif ability.effect_type == "mult_all_different_values" then
                -- Unown - Poder Oculto: +2 mult si todas las cartas tienen valores diferentes
                if card.pokemon == "Unown" then
                    local values = {}
                    local all_different = true
                    for _, hand_card in ipairs(player_hand) do
                        if values[hand_card.value] then
                            all_different = false
                            break
                        end
                        values[hand_card.value] = true
                    end
                    
                    if all_different then
                        effects.multiplier_bonus = effects.multiplier_bonus + 2
                    end
                end
            end
        end
    end
    
    return effects
end

-- Apply post-victory effects (like healing)
function pokemon_abilities.apply_post_victory_effects(player_hand, game_state)
    if not game_state then return end
    
    for _, card in ipairs(player_hand) do
        if card.card_type == "pokemon" and card.ability then
            local ability = card.ability
            
            if ability.effect_type == "heal_on_victory" then
                -- Golbat - Chupavidas: Curas 50% PV al ganar la ronda
                if card.pokemon == "Golbat" then
                    local heal_amount = math.floor(game_state.base_player_hp * 0.5)
                    game_state.player_hp = math.min(game_state.base_player_hp, game_state.player_hp + heal_amount)
                end
            end
        end
    end
end

-- Get Pokemon ability description for tooltip
function pokemon_abilities.get_ability_description(card)
    if card.card_type == "pokemon" and card.ability then
        return string.format("%s (%s): %s", 
            card.ability.name, 
            card.ability.type, 
            card.ability.ability)
    end
    return nil
end

return pokemon_abilities