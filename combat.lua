-- Combat system for Spanish Deck Card Game
local scoring = require("scoring")
local amarracos = require("amarracos")
local pokemon_abilities = require("pokemon_abilities")

local combat = {}

-- Combat phases
combat.PHASE_AI_REVEAL = "ai_reveal"
combat.PHASE_DAMAGE_DISPLAY = "damage_display"
combat.PHASE_SCORING_ANIMATION = "scoring_animation"
combat.PHASE_PLAYER_ATTACK = "player_attack"
combat.PHASE_AI_DEFEAT_CHECK = "ai_defeat_check"
combat.PHASE_AI_ATTACK = "ai_attack"
combat.PHASE_PLAYER_DEFEAT_CHECK = "player_defeat_check"
combat.PHASE_COMPLETE = "complete"

-- Combat state
local combat_state = {
    phase = combat.PHASE_COMPLETE,
    phase_timer = 0,
    phase_duration = 0.6,  -- Duration of each phase in seconds (slowed down)
    player_breakdown = nil,
    ai_breakdown = nil,
    damage_to_ai = 0,
    damage_to_player = 0,
    ai_cards_revealed = false,
    scoring_animation_complete = false,  -- Track when scoring animation finishes
    ai_will_be_defeated = false,
    player_will_be_defeated = false,
    player_hits = false,
    ai_hits = false,
    combat_result = nil,  -- Will store final result of combat
    player_damage_applied = false,  -- Track if damage was applied this combat
    ai_damage_applied = false,
    just_entered_phase = false,  -- Track if we just entered a new phase
    ai_actually_defeated = false,  -- Track if AI was actually defeated by HP check
    player_actually_defeated = false  -- Track if player was actually defeated by HP check
}

-- Callback function for when scoring animation completes
local function on_scoring_animation_complete()
    combat_state.scoring_animation_complete = true
end

-- Initialize combat between player and AI hands
function combat.start_combat(player_hand, ai_hand, player_bonuses, owned_amarracos, game_state)
    player_bonuses = player_bonuses or {}
    owned_amarracos = owned_amarracos or {}
    
    -- Calculate scoring for both hands
    combat_state.player_breakdown = scoring.get_full_breakdown(player_hand, player_bonuses)
    combat_state.ai_breakdown = scoring.get_full_breakdown(ai_hand)
    
    -- Apply amarracos effects to player's breakdown
    local amarracos_effects = amarracos.apply_effects(combat_state.player_breakdown, player_hand, owned_amarracos, game_state)
    
    -- Apply Pokemon abilities effects to player's breakdown
    local pokemon_effects = pokemon_abilities.apply_effects(combat_state.player_breakdown, player_hand, ai_hand, game_state)
    
    -- Apply sticker effects to player's breakdown
    local stickers = require("stickers")
    local sticker_effects = {
        damage_bonus = 0,
        multiplier_bonus = 1
    }
    
    -- Calculate sticker bonuses for each card
    for _, card in ipairs(player_hand) do
        if card.attached_sticker then
            -- Check if this card is the "grande" or "pequeña"
            local is_grande = (card.value == combat_state.player_breakdown.grandes)
            local is_pequena = (card.value == combat_state.player_breakdown.pequenas)
            local card_effects = stickers.apply_card_sticker_effects(card, is_grande, is_pequena)
            sticker_effects.damage_bonus = sticker_effects.damage_bonus + card_effects.damage_bonus
            sticker_effects.multiplier_bonus = sticker_effects.multiplier_bonus + card_effects.multiplier_bonus
            
            -- Debug info for sticker effects (store in combat state for UI display)
            if not combat_state.sticker_debug then
                combat_state.sticker_debug = {}
            end
            
            local sticker = stickers.get_sticker_by_id(card.attached_sticker)
            table.insert(combat_state.sticker_debug, {
                card_value = card.value,
                sticker_name = sticker and sticker.name or "Unknown",
                is_grande = is_grande,
                is_pequena = is_pequena,
                damage_bonus = card_effects.damage_bonus,
                multiplier_bonus = card_effects.multiplier_bonus,
                pequenas_value = combat_state.player_breakdown.pequenas,
                grandes_value = combat_state.player_breakdown.grandes
            })
        end
    end
    
    -- Store effects for scoring animation
    combat_state.amarracos_effects = amarracos_effects
    combat_state.owned_amarracos = owned_amarracos
    combat_state.pokemon_effects = pokemon_effects
    combat_state.sticker_effects = sticker_effects
    
    -- Update breakdown with amarracos and Pokemon effects - proper order: sum first, then multiply, perfect juego last
    
    -- 1. Add damage bonus to base damage (grandes) before multipliers (amarracos, Pokemon, and stickers)
    local original_grandes = combat_state.player_breakdown.grandes
    combat_state.player_breakdown.grandes = combat_state.player_breakdown.grandes + amarracos_effects.damage_bonus + pokemon_effects.damage_bonus + sticker_effects.damage_bonus
    
    -- Debug: Store damage bonus breakdown
    combat_state.damage_debug = {
        original_grandes = original_grandes,
        amarracos_bonus = amarracos_effects.damage_bonus,
        pokemon_bonus = pokemon_effects.damage_bonus,
        sticker_bonus = sticker_effects.damage_bonus,
        final_grandes = combat_state.player_breakdown.grandes
    }
    
    -- 2. Apply multiplier bonuses to the base multiplier (amarracos, Pokemon, and stickers)
    local base_multiplier = combat_state.player_breakdown.multiplier * amarracos_effects.multiplier_bonus * pokemon_effects.multiplier_bonus * sticker_effects.multiplier_bonus
    
    -- 3. Apply perfect juego multiplier (if not disabled and applicable)
    local final_multiplier = base_multiplier
    if combat_state.player_breakdown.is_perfect_juego and not amarracos_effects.disable_perfect_juego then
        final_multiplier = base_multiplier * 3
    end
    
    -- 4. Calculate final damage
    combat_state.player_breakdown.damage = combat_state.player_breakdown.grandes * final_multiplier
    combat_state.player_breakdown.total_multiplier = final_multiplier
    
    -- 5. Apply accuracy override if present (amarracos or Pokemon)
    if amarracos_effects.accuracy_override then
        combat_state.player_breakdown.accuracy = amarracos_effects.accuracy_override
    elseif pokemon_effects.accuracy_override then
        combat_state.player_breakdown.accuracy = pokemon_effects.accuracy_override
    end
    
    -- 6. Apply defense bonus (both amarracos and Pokemon)
    combat_state.player_breakdown.defense = math.max(0, combat_state.player_breakdown.defense + amarracos_effects.defense_bonus + pokemon_effects.defense_bonus)
    
    -- Apply other effects (amarracos and Pokemon)
    if amarracos_effects.hp_bonus > 0 and game_state then
        game_state.player_hp = math.min(game_state.base_player_hp, game_state.player_hp + amarracos_effects.hp_bonus)
    end
    if pokemon_effects.hp_bonus > 0 and game_state then
        game_state.player_hp = math.min(game_state.base_player_hp, game_state.player_hp + pokemon_effects.hp_bonus)
    end
    if amarracos_effects.pesetas_bonus > 0 and game_state then
        local final_pesetas_bonus = amarracos_effects.pesetas_bonus * amarracos_effects.pesetas_multiplier
        game_state.pesetas = game_state.pesetas + final_pesetas_bonus
    end
    if pokemon_effects.pesetas_bonus > 0 and game_state then
        game_state.pesetas = game_state.pesetas + pokemon_effects.pesetas_bonus
    end
    
    -- Check hit/miss for both attacks
    combat_state.player_hits = scoring.check_hit(combat_state.player_breakdown.accuracy)
    combat_state.ai_hits = scoring.check_hit(combat_state.ai_breakdown.accuracy)
    
    -- Calculate damage (only if attack hits)
    local player_final_score = 0
    if combat_state.player_hits then
        player_final_score = combat_state.player_breakdown.damage
        if combat_state.player_breakdown.is_perfect_juego then
            player_final_score = player_final_score * 3
        end
    end
    
    local ai_final_score = 0
    if combat_state.ai_hits then
        ai_final_score = combat_state.ai_breakdown.damage
        -- AI does not get perfect juego x3 multiplier to prevent one-shotting players
    end
    
    combat_state.damage_to_ai = player_final_score
    
    -- Apply minimum damage from Pokemon abilities (like Staryu)
    if pokemon_effects.minimum_damage > 0 and combat_state.player_hits then
        combat_state.damage_to_ai = math.max(combat_state.damage_to_ai, pokemon_effects.minimum_damage)
    end
    
    -- Apply enemy damage reduction from Pokemon abilities (like Cinccino)
    local adjusted_ai_damage = ai_final_score * pokemon_effects.enemy_damage_multiplier
    combat_state.damage_to_player = math.max(0, adjusted_ai_damage - combat_state.player_breakdown.defense)
    
    -- Pre-calculate combat outcomes
    combat_state.ai_will_be_defeated = (player_final_score > 0 and combat_state.damage_to_ai >= 999) -- Will set properly below
    combat_state.player_will_be_defeated = (ai_final_score > 0 and combat_state.damage_to_player >= 999) -- Will set properly below
    
    -- Start combat sequence with AI reveal
    combat_state.phase = combat.PHASE_AI_REVEAL
    combat_state.phase_timer = 0
    combat_state.ai_cards_revealed = false
    combat_state.scoring_animation_complete = false
    combat_state.combat_result = nil
    combat_state.player_damage_applied = false
    combat_state.ai_damage_applied = false
    combat_state.just_entered_phase = true  -- Start with first phase
    combat_state.ai_actually_defeated = false
    combat_state.player_actually_defeated = false
    
    -- Trigger win condition animations
    if game_state then
        local game_state_module = require("game_state")
        if game_state_module.trigger_win_animations then
            game_state_module.trigger_win_animations(combat_state.player_breakdown, combat_state.ai_breakdown, player_hand, ai_hand)
        end
    end
    
    return {
        player_damage = combat_state.damage_to_ai,
        ai_damage = combat_state.damage_to_player,
        player_breakdown = combat_state.player_breakdown,
        ai_breakdown = combat_state.ai_breakdown,
        player_hits = combat_state.player_hits,
        ai_hits = combat_state.ai_hits,
        amarracos_effects = combat_state.amarracos_effects,
        owned_amarracos = combat_state.owned_amarracos,
        pokemon_effects = combat_state.pokemon_effects
    }
end

-- Update combat animation
function combat.update(dt)
    if combat_state.phase == combat.PHASE_COMPLETE then
        return false, combat_state.combat_result
    end
    
    combat_state.phase_timer = combat_state.phase_timer + dt
    
    -- Special handling for scoring animation phase - wait for completion
    if combat_state.phase == combat.PHASE_SCORING_ANIMATION then
        if combat_state.scoring_animation_complete then
            combat_state.phase = combat.PHASE_PLAYER_ATTACK
            combat_state.phase_timer = 0
            combat_state.scoring_animation_complete = false
            combat_state.just_entered_phase = true  -- Ensure flag is set for next phase
        end
        return true, nil  -- Still in combat, don't advance normally
    end
    
    if combat_state.phase_timer >= combat_state.phase_duration then
        -- Move to next phase
        if combat_state.phase == combat.PHASE_AI_REVEAL then
            -- Reveal AI cards
            combat_state.ai_cards_revealed = true
            combat_state.phase = combat.PHASE_DAMAGE_DISPLAY
            
        elseif combat_state.phase == combat.PHASE_DAMAGE_DISPLAY then
            -- Show damage calculations, then wait for scoring animation
            combat_state.phase = combat.PHASE_SCORING_ANIMATION
            
        elseif combat_state.phase == combat.PHASE_PLAYER_ATTACK then
            -- Player damage already calculated, move to check AI defeat
            combat_state.phase = combat.PHASE_AI_DEFEAT_CHECK
            
        elseif combat_state.phase == combat.PHASE_AI_DEFEAT_CHECK then
            -- Default to continuing - game_state will override if AI is defeated
            combat_state.phase = combat.PHASE_AI_ATTACK
            
        elseif combat_state.phase == combat.PHASE_AI_ATTACK then
            -- AI damage applied, check player defeat
            combat_state.phase = combat.PHASE_PLAYER_DEFEAT_CHECK
            
        elseif combat_state.phase == combat.PHASE_PLAYER_DEFEAT_CHECK then
            -- Default to both survive - game_state will override if player is defeated
            combat_state.combat_result = "both_survive"
            combat_state.phase = combat.PHASE_COMPLETE
            return true, combat_state.combat_result
        end
        
        combat_state.phase_timer = 0
        combat_state.just_entered_phase = true
    else
        combat_state.just_entered_phase = false
    end
    
    return false, nil  -- Combat still in progress
end

-- Get current combat state for UI display
function combat.get_state()
    return {
        phase = combat_state.phase,
        phase_timer = combat_state.phase_timer,
        phase_duration = combat_state.phase_duration,
        player_breakdown = combat_state.player_breakdown,
        ai_breakdown = combat_state.ai_breakdown,
        damage_to_ai = combat_state.damage_to_ai,
        damage_to_player = combat_state.damage_to_player,
        ai_cards_revealed = combat_state.ai_cards_revealed,
        is_active = combat_state.phase ~= combat.PHASE_COMPLETE,
        player_hits = combat_state.player_hits,
        ai_hits = combat_state.ai_hits,
        just_entered_phase = combat_state.just_entered_phase
    }
end

-- Get phase display text
function combat.get_phase_text()
    if combat_state.phase == combat.PHASE_AI_REVEAL then
        return "AI reveals their hand..."
    elseif combat_state.phase == combat.PHASE_DAMAGE_DISPLAY then
        local player_dmg_text = string.format("Your damage: %d", combat_state.damage_to_ai)
        local player_def_text = string.format("Your defense: %d", combat_state.player_breakdown.defense)
        local ai_dmg_text = string.format("AI damage: %d", combat_state.damage_to_player > 0 and combat_state.damage_to_player or 0)
        return string.format("%s | %s | %s", player_dmg_text, player_def_text, ai_dmg_text)
    elseif combat_state.phase == combat.PHASE_PLAYER_ATTACK then
        local perfect_text = combat_state.player_breakdown and combat_state.player_breakdown.is_perfect_juego and " *** PERFECT JUEGO! ***" or ""
        if combat_state.player_hits then
            return string.format("Your attack hits: %d damage!%s", combat_state.damage_to_ai, perfect_text)
        else
            return string.format("Your attack misses! (%.1f%% accuracy)%s", combat_state.player_breakdown.accuracy, perfect_text)
        end
    elseif combat_state.phase == combat.PHASE_AI_DEFEAT_CHECK then
        if combat_state.ai_actually_defeated then
            return "AI is defeated!"
        else
            return "AI survives your attack..."
        end
    elseif combat_state.phase == combat.PHASE_AI_ATTACK then
        local ai_perfect_text = combat_state.ai_breakdown and combat_state.ai_breakdown.is_perfect_juego and " *** AI PERFECT JUEGO! ***" or ""
        if combat_state.ai_hits then
            if combat_state.damage_to_player > 0 then
                return string.format("AI attack hits: %d damage after defense!%s", combat_state.damage_to_player, ai_perfect_text)
            else
                return string.format("AI attack hits but blocked by defense!%s", ai_perfect_text)
            end
        else
            return string.format("AI attack misses! (%.1f%% accuracy)%s", combat_state.ai_breakdown.accuracy, ai_perfect_text)
        end
    elseif combat_state.phase == combat.PHASE_PLAYER_DEFEAT_CHECK then
        if combat_state.player_actually_defeated then
            return "You are defeated!"
        else
            return "You survive the AI's attack!"
        end
    else
        return ""
    end
end

-- Reset combat system
function combat.reset()
    combat_state.phase = combat.PHASE_COMPLETE
    combat_state.phase_timer = 0
    combat_state.player_breakdown = nil
    combat_state.ai_breakdown = nil
    combat_state.damage_to_ai = 0
    combat_state.damage_to_player = 0
    combat_state.ai_cards_revealed = false
    combat_state.ai_will_be_defeated = false
    combat_state.player_will_be_defeated = false
    combat_state.player_hits = false
    combat_state.ai_hits = false
    combat_state.combat_result = nil
    combat_state.player_damage_applied = false
    combat_state.ai_damage_applied = false
    combat_state.just_entered_phase = false
    combat_state.ai_actually_defeated = false
    combat_state.player_actually_defeated = false
end

-- Check if combat is active
function combat.is_active()
    return combat_state.phase ~= combat.PHASE_COMPLETE
end

-- Apply player damage to AI (called by game_state at the right moment)
function combat.apply_player_damage()
    if not combat_state.player_damage_applied and combat_state.player_hits and combat_state.damage_to_ai > 0 then
        combat_state.player_damage_applied = true
        return combat_state.damage_to_ai
    end
    return 0
end

-- Apply AI damage to player (called by game_state at the right moment)
function combat.apply_ai_damage()
    if not combat_state.ai_damage_applied and combat_state.ai_hits and combat_state.damage_to_player > 0 then
        combat_state.ai_damage_applied = true
        return combat_state.damage_to_player
    end
    return 0
end

-- Check if we need to apply AI defeat now
function combat.should_defeat_ai()
    local current_ai_hp = 999  -- This will be passed from game_state
    return combat_state.player_hits and combat_state.damage_to_ai > 0
end

-- Force combat to end with AI defeated (called by game_state)
function combat.end_with_ai_defeat()
    combat_state.combat_result = "ai_defeated"
    combat_state.ai_actually_defeated = true
    combat_state.phase = combat.PHASE_COMPLETE
end

-- Force combat to end with player defeated (called by game_state)
function combat.end_with_player_defeat()
    combat_state.combat_result = "player_defeated"
    combat_state.player_actually_defeated = true
    combat_state.phase = combat.PHASE_COMPLETE
end

-- Get combat state (for external access)
function combat.get_state()
    return combat_state
end

-- Get scoring animation completion callback
function combat.get_scoring_callback()
    return on_scoring_animation_complete
end

-- Get sticker debug info (for UI display)
function combat.get_sticker_debug()
    return combat_state.sticker_debug or {}
end

return combat