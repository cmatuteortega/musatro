-- Animated scoring system for Spanish Deck Card Game
-- Provides step-by-step breakdown of scoring with visual animations

local scoring = require("scoring")

local scoring_animation = {}

-- Animation phases
scoring_animation.PHASE_REVEAL = "reveal"
scoring_animation.PHASE_GRANDES = "grandes" 
scoring_animation.PHASE_PEQUENAS = "pequenas"
scoring_animation.PHASE_PARES = "pares"
scoring_animation.PHASE_JUEGO = "juego"
scoring_animation.PHASE_AMARRACOS_FINAL = "amarracos_final"
scoring_animation.PHASE_COMPLETE = "complete"

-- Animation state
local animation_state = {
    active = false,
    phase = nil,
    timer = 0,
    phase_duration = 1.5,  -- Time for each phase in seconds
    player_hand = {},
    ai_hand = {},
    player_breakdown = {},
    ai_breakdown = {},
    amarraco_effects = {},
    owned_amarracos = {},
    
    -- Amarraco highlighting
    highlighted_amarracos = {},
    
    -- Card highlighting
    highlighted_cards = {},
    
    -- Animated text effects
    floating_texts = {},  -- {text, x, y, timer, type}
    
    -- Formula highlighting
    formula_highlight = {
        grandes = false,
        pequenas = false, 
        pares = false,
        juego = false
    },
    
    -- Completion callback
    completion_callback = nil
}

-- Helper function to calculate individual amarraco effects and return sprite data
local function get_amarraco_effects_for_phase(bonus_type)
    if not animation_state.owned_amarracos or not animation_state.player_hand then return {} end
    
    local amarracos = require("amarracos")
    local scoring = require("scoring")
    local effects_data = {}
    
    -- Get baseline scoring for comparison
    local baseline_breakdown = scoring.get_full_breakdown(animation_state.player_hand, {})
    local baseline_effects = amarracos.apply_effects(baseline_breakdown, animation_state.player_hand, {}, nil)
    
    -- Test each amarraco individually to see its contribution
    for i, amarraco in ipairs(animation_state.owned_amarracos) do
        local single_amarraco_effects = amarracos.apply_effects(baseline_breakdown, animation_state.player_hand, {amarraco}, nil)
        local contribution = nil
        local effect_text = ""
        
        if bonus_type == "damage" and single_amarraco_effects.damage_bonus > baseline_effects.damage_bonus then
            contribution = single_amarraco_effects.damage_bonus - baseline_effects.damage_bonus
            effect_text = "+" .. contribution
        elseif bonus_type == "defense" and single_amarraco_effects.defense_bonus > baseline_effects.defense_bonus then
            contribution = single_amarraco_effects.defense_bonus - baseline_effects.defense_bonus
            effect_text = "+" .. contribution
        elseif bonus_type == "multiplier" and single_amarraco_effects.multiplier_bonus > baseline_effects.multiplier_bonus then
            contribution = single_amarraco_effects.multiplier_bonus / baseline_effects.multiplier_bonus
            effect_text = "x" .. contribution
        elseif bonus_type == "accuracy" and single_amarraco_effects.accuracy_override then
            contribution = single_amarraco_effects.accuracy_override
            effect_text = contribution .. "%"
        end
        
        if contribution then
            table.insert(effects_data, {
                index = i,
                amarraco = amarraco,
                contribution = contribution,
                effect_text = effect_text
            })
        end
    end
    
    return effects_data
end

-- Helper function to calculate amarraco sprite positions (matches current ui.lua combat layout)
local function get_amarraco_sprite_position(index)
    if not animation_state.owned_amarracos or index > #animation_state.owned_amarracos then
        return 828, 500  -- Default center position using canvas coordinates
    end
    
    -- Calculate positions matching current ui.lua draw_amarracos combat layout
    local canvas = require("canvas")
    local screen_width, _ = canvas.get_internal_dimensions()  -- Use canvas dimensions
    local base_sprite_size = 45
    local display_scale = 5.0  -- Match current combat display scale (5x)
    local final_sprite_size = base_sprite_size * display_scale
    local sprite_spacing = 15  -- Match current combat spacing
    local total_width = #animation_state.owned_amarracos * final_sprite_size + (#animation_state.owned_amarracos - 1) * sprite_spacing
    local start_x = (screen_width - total_width) / 2
    local sprite_y = 500  -- Match current combat amarraco Y position
    
    local x = start_x + (index - 1) * (final_sprite_size + sprite_spacing)
    return x + final_sprite_size / 2, sprite_y  -- Center of sprite
end

-- Start animated scoring sequence
function scoring_animation.start(player_hand, ai_hand, player_breakdown, ai_breakdown, amarraco_effects, owned_amarracos, completion_callback)
    animation_state.active = true
    animation_state.phase = scoring_animation.PHASE_REVEAL
    animation_state.timer = 0
    animation_state.player_hand = player_hand
    animation_state.ai_hand = ai_hand
    animation_state.player_breakdown = player_breakdown
    animation_state.ai_breakdown = ai_breakdown
    animation_state.amarraco_effects = amarraco_effects or {}
    animation_state.owned_amarracos = owned_amarracos or {}
    animation_state.completion_callback = completion_callback or nil  -- Optional callback
    
    -- Clear previous state
    animation_state.highlighted_cards = {}
    animation_state.highlighted_amarracos = {}
    animation_state.floating_texts = {}
    animation_state.formula_highlight = {
        grandes = false,
        pequenas = false,
        pares = false,
        juego = false
    }
end

-- Update animation state
function scoring_animation.update(dt)
    if not animation_state.active then
        return
    end
    
    animation_state.timer = animation_state.timer + dt
    
    -- Timer debug removed to reduce clutter
    
    -- Update floating text animations
    for i = #animation_state.floating_texts, 1, -1 do
        local text = animation_state.floating_texts[i]
        text.timer = text.timer - dt
        text.y = text.y - 30 * dt  -- Float upward
        
        if text.timer <= 0 then
            table.remove(animation_state.floating_texts, i)
        end
    end
    
    -- Phase transitions
    if animation_state.timer >= animation_state.phase_duration then
        advance_phase()
    end
end

-- Advance to next animation phase
function advance_phase()
    animation_state.timer = 0
    
    if animation_state.phase == scoring_animation.PHASE_REVEAL then
        start_grandes_phase()
    elseif animation_state.phase == scoring_animation.PHASE_GRANDES then
        start_pequenas_phase()
    elseif animation_state.phase == scoring_animation.PHASE_PEQUENAS then
        start_pares_phase()
    elseif animation_state.phase == scoring_animation.PHASE_PARES then
        start_juego_phase()
    elseif animation_state.phase == scoring_animation.PHASE_JUEGO then
        start_amarracos_final_phase()
    elseif animation_state.phase == scoring_animation.PHASE_AMARRACOS_FINAL then
        complete_animation()
    end
end

-- Start grandes (damage) animation phase
function start_grandes_phase()
    animation_state.phase = scoring_animation.PHASE_GRANDES
    animation_state.formula_highlight.grandes = true
    
    -- Find highest actual card value (not scoring value)
    local highest_value = 0
    for _, card in ipairs(animation_state.player_hand) do
        if card.value > highest_value then
            highest_value = card.value
        end
    end
    
    -- Highlight highest value cards and create floating text
    animation_state.highlighted_cards = {}
    for i, card in ipairs(animation_state.player_hand) do
        if card.value == highest_value then
            table.insert(animation_state.highlighted_cards, {index = i, type = "grandes"})
            
            -- Add floating text from card position (show actual card value)
            table.insert(animation_state.floating_texts, {
                text = "+" .. card.value,
                x = card.x + 20,
                y = card.y - 10,
                timer = 2.0,
                type = "damage"
            })
        end
    end
    
    -- Clear amarraco highlighting (effects now shown only in final phase)
    animation_state.highlighted_amarracos = {}
end

-- Start pequeñas (defense) animation phase  
function start_pequenas_phase()
    animation_state.phase = scoring_animation.PHASE_PEQUENAS
    animation_state.formula_highlight.grandes = false
    animation_state.formula_highlight.pequenas = true
    
    -- Find lowest value cards in player hand
    local lowest_value = 10
    for _, card in ipairs(animation_state.player_hand) do
        local card_value = (card.value >= 11) and 10 or card.value
        if card_value < lowest_value then
            lowest_value = card_value
        end
    end
    
    -- Highlight lowest cards and create floating text
    animation_state.highlighted_cards = {}
    for i, card in ipairs(animation_state.player_hand) do
        local card_value = (card.value >= 11) and 10 or card.value
        if card_value == lowest_value then
            table.insert(animation_state.highlighted_cards, {index = i, type = "pequenas"})
            
            -- Add floating text from card position  
            local defense_value = 10 - card_value
            table.insert(animation_state.floating_texts, {
                text = "+" .. defense_value,
                x = card.x + 20,
                y = card.y - 10,
                timer = 2.0,
                type = "defense"
            })
        end
    end
    
    -- Clear amarraco highlighting (effects now shown only in final phase)
    animation_state.highlighted_amarracos = {}
end

-- Start pares (pairs) animation phase
function start_pares_phase()
    animation_state.phase = scoring_animation.PHASE_PARES
    animation_state.formula_highlight.pequenas = false
    animation_state.formula_highlight.pares = true
    
    -- Find pairs and highlight them (use actual card values, not scoring values)
    local value_counts = {}
    for _, card in ipairs(animation_state.player_hand) do
        local card_value = card.value  -- Use actual card value for pair detection
        value_counts[card_value] = (value_counts[card_value] or 0) + 1
    end
    
    -- Find the best pair/group
    local best_count = 0
    local best_value = 0
    for value, count in pairs(value_counts) do
        if count > 1 and count > best_count then
            best_count = count
            best_value = value
        end
    end
    
    animation_state.highlighted_cards = {}
    if best_count > 1 then
        -- Highlight cards that form pairs (compare actual values)
        for i, card in ipairs(animation_state.player_hand) do
            if card.value == best_value then
                table.insert(animation_state.highlighted_cards, {index = i, type = "pares"})
            end
        end
        
        -- Add multiplier text
        local multiplier_text = "x" .. best_count
        if best_count == 4 then multiplier_text = "x4!"
        elseif best_count == 3 then multiplier_text = "x3!"
        elseif best_count == 2 then multiplier_text = "x2"
        end
        
        -- Add floating text near the center of paired cards
        if #animation_state.highlighted_cards > 0 then
            local avg_x = 0
            for _, highlight in ipairs(animation_state.highlighted_cards) do
                avg_x = avg_x + animation_state.player_hand[highlight.index].x
            end
            avg_x = avg_x / #animation_state.highlighted_cards
            
            table.insert(animation_state.floating_texts, {
                text = multiplier_text,
                x = avg_x + 20,
                y = animation_state.player_hand[1].y - 10,
                timer = 2.0,
                type = "multiplier"
            })
        end
    end
    
    -- Clear amarraco highlighting (effects now shown only in final phase)
    animation_state.highlighted_amarracos = {}
end

-- Start juego (accuracy) animation phase
function start_juego_phase()
    animation_state.phase = scoring_animation.PHASE_JUEGO
    animation_state.formula_highlight.pares = false
    animation_state.formula_highlight.juego = true
    
    -- Highlight all cards as they contribute to juego
    animation_state.highlighted_cards = {}
    local total_juego = 0
    
    for i, card in ipairs(animation_state.player_hand) do
        table.insert(animation_state.highlighted_cards, {index = i, type = "juego"})
        
        local card_value = (card.value >= 11) and 10 or card.value
        total_juego = total_juego + card_value
        
        -- Add floating text from each card (staggered timing)
        table.insert(animation_state.floating_texts, {
            text = "+" .. card_value,
            x = card.x + 20,
            y = card.y - 10,
            timer = 2.0 + (i * 0.2),  -- Stagger the timing
            type = "juego"
        })
    end
    
    -- Add total juego floating text
    table.insert(animation_state.floating_texts, {
        text = "=" .. total_juego,
        x = 225,  -- Center of screen
        y = 300,
        timer = 2.5,
        type = "juego_total"
    })
    
    -- Add accuracy percentage
    local accuracy = math.floor((total_juego / 31) * 100)
    table.insert(animation_state.floating_texts, {
        text = accuracy .. "%",
        x = 225,
        y = 320,
        timer = 2.5,
        type = "accuracy"
    })
    
    -- Clear amarraco highlighting (effects now shown only in final phase)
    animation_state.highlighted_amarracos = {}
end

-- Start final amarracos animation phase - shows each amarraco's total contribution
function start_amarracos_final_phase()
    animation_state.phase = scoring_animation.PHASE_AMARRACOS_FINAL
    animation_state.formula_highlight.juego = false
    animation_state.highlighted_cards = {}
    
    -- Skip if no amarracos
    if not animation_state.owned_amarracos or #animation_state.owned_amarracos == 0 then
        complete_animation()
        return
    end
    
    -- Calculate each amarraco's individual total contribution
    local amarracos = require("amarracos")
    local scoring = require("scoring")
    animation_state.highlighted_amarracos = {}
    
    -- Create a proper state object for amarraco effect calculations
    local mock_state = {
        ai_played_cards = animation_state.ai_hand
    }
    
    -- Get baseline effects (no amarracos)
    local baseline_breakdown = scoring.get_full_breakdown(animation_state.player_hand, {})
    local baseline_effects = amarracos.apply_effects(baseline_breakdown, animation_state.player_hand, {}, mock_state)
    
    -- Test each amarraco individually to get its total contribution
    for i, amarraco in ipairs(animation_state.owned_amarracos) do
        local single_amarraco_effects = amarracos.apply_effects(baseline_breakdown, animation_state.player_hand, {amarraco}, mock_state)
        
        -- Calculate total effect for this amarraco
        local total_damage = single_amarraco_effects.damage_bonus - baseline_effects.damage_bonus
        local total_defense = single_amarraco_effects.defense_bonus - baseline_effects.defense_bonus
        local total_multiplier = single_amarraco_effects.multiplier_bonus / baseline_effects.multiplier_bonus
        local accuracy_override = single_amarraco_effects.accuracy_override
        
        -- Show floating text for any significant effects
        local has_effect = false
        local sprite_x, sprite_y = get_amarraco_sprite_position(i)
        
        
        if total_damage > 0 then
            table.insert(animation_state.floating_texts, {
                text = "+" .. total_damage,
                x = sprite_x,
                y = sprite_y - 30,
                timer = 2.5,
                type = "damage"
            })
            has_effect = true
        end
        
        if total_defense > 0 then
            table.insert(animation_state.floating_texts, {
                text = "+" .. total_defense,
                x = sprite_x,
                y = sprite_y - 10,  -- Stagger below damage text
                timer = 2.5,
                type = "defense"
            })
            has_effect = true
        end
        
        if total_multiplier > 1.01 then  -- Use small epsilon to handle floating point precision
            table.insert(animation_state.floating_texts, {
                text = "x" .. string.format("%.1f", total_multiplier),
                x = sprite_x,
                y = sprite_y - 20,  -- Between damage and defense
                timer = 2.5,
                type = "multiplier"
            })
            has_effect = true
        end
        
        if accuracy_override then
            table.insert(animation_state.floating_texts, {
                text = accuracy_override .. "%",
                x = sprite_x,
                y = sprite_y - 25,
                timer = 2.5,
                type = "accuracy"
            })
            has_effect = true
        end
        
        -- Highlight amarraco if it has any effects
        if has_effect then
            table.insert(animation_state.highlighted_amarracos, i)
        end
    end
    
    -- If no amarracos have effects, skip to completion
    if #animation_state.highlighted_amarracos == 0 then
        complete_animation()
    end
end

-- Function moved above to fix scope issue

-- Complete the animation sequence
function complete_animation()
    
    animation_state.phase = scoring_animation.PHASE_COMPLETE
    animation_state.formula_highlight.juego = false
    animation_state.highlighted_cards = {}
    animation_state.highlighted_amarracos = {}
    animation_state.active = false
    
    -- Call completion callback if provided
    if animation_state.completion_callback then
        animation_state.completion_callback()
        animation_state.completion_callback = nil
    end
end

-- Check if animation is active
function scoring_animation.is_active()
    return animation_state.active
end

-- Get current phase
function scoring_animation.get_phase()
    return animation_state.phase
end

-- Get highlighted cards for rendering
function scoring_animation.get_highlighted_cards()
    return animation_state.highlighted_cards
end

-- Get highlighted amarracos for rendering
function scoring_animation.get_highlighted_amarracos()
    return animation_state.highlighted_amarracos
end

-- Get floating texts for rendering
function scoring_animation.get_floating_texts()
    return animation_state.floating_texts
end

-- Get formula highlighting state
function scoring_animation.get_formula_highlights()
    return animation_state.formula_highlight
end



-- Force stop animation
function scoring_animation.stop()
    
    animation_state.active = false
    animation_state.highlighted_cards = {}
    animation_state.highlighted_amarracos = {}
    animation_state.floating_texts = {}
    animation_state.completion_callback = nil
    animation_state.formula_highlight = {
        grandes = false,
        pequenas = false,
        pares = false,
        juego = false
    }
end

return scoring_animation