-- Game state module for Spanish Deck Card Game with AI battles, shop system
local card = require("card")
local scoring = require("scoring")
local ai = require("ai")
local combat = require("combat")
local menu = require("menu")
local shop = require("shop")
local transition = require("transition")
local animation = require("animation")
local amarracos = require("amarracos")
local stickers = require("stickers")
local ui = require("ui")

local game_state = {}

-- Initialize game state
local state = {
    -- Player state
    deck = {},
    hand = {},
    discards_remaining = 3,
    score = 0,
    player_hp = 20,
    base_player_hp = 20,
    
    -- AI state
    ai_deck = {},
    ai_hand = {},
    ai_hp = 25,
    ai_discards_remaining = 3,
    
    -- Game state
    game_over = false,
    fonts = nil,
    round = 1,
    hands_remaining = 3,
    max_score = 1,
    last_hand_breakdown = nil,
    
    -- Combat state
    in_combat = false,
    ai_played_cards = {},
    player_played_cards = {},
    show_ai_cards = false,  -- Whether to show AI cards face-up
    
    -- Shop state
    in_shop = false,
    shop_items = {},
    selected_shop_item = 1,
    in_card_selection = false,
    card_selection_cards = {},
    selected_card_index = 0,  -- Initialize with no selection for click-to-select
    card_selection_type = "",  -- "card_choice" or "booster"
    
    -- Shop and upgrade system
    pesetas = 0,
    upgrades = {},
    round_discards_used = 0,
    round_hands_used = 0,
    purchased_cards = {},  -- Cards to add to deck permanently
    
    -- Amarracos (prizes) system
    owned_amarracos = {},  -- List of owned prizes
    shop_amarracos = {},   -- Current shop prizes available
    
    -- Stickers (pegatinas) system
    owned_stickers = {},   -- List of owned stickers
    shop_stickers = {},    -- Current shop stickers available
    dragging_sticker = nil,  -- Currently dragged sticker data
    drag_offset_x = 0,     -- Mouse offset from sticker center
    drag_offset_y = 0,     -- Mouse offset from sticker center
    sticker_registry = {}, -- Persistent sticker attachments by card identity
    permanently_removed_cards = {}, -- Cards permanently removed from base deck
    
    -- Animation state
    waiting_for_draw_animation = false,
    pending_draw_data = nil,
    draw_delay_timer = 0,
    draw_delay_duration = 0.5,
    clearing_cards = false,  -- Flag to hide normal card rendering during clear animation
    shop_delay_timer = 0,
    waiting_for_shop = false,
    new_hand_delay_timer = 0,
    waiting_for_new_hand = false,
    scoring_animation_completed = false,  -- Track when scoring animation ends and damage is applied
    ai_defeated_by_animation = false,  -- Flag when AI is defeated during animation callback
    player_defeated_by_animation = false,  -- Flag when player is defeated during animation callback
    damage_handled_by_animation = false,  -- Flag to skip combat phase damage application
    damage_sequence_active = false,  -- Flag for sequential damage application
    damage_sequence_timer = 0,  -- Timer for damage sequence delay
    damage_sequence_combat_result = nil,  -- Store combat result for sequence
    
    -- Hit/Miss animation state
    player_hit_animation = { active = false, text = "", timer = 0, duration = 1.5 },
    ai_hit_animation = { active = false, text = "", timer = 0, duration = 1.5 },
    
    -- Win condition animations (grande, pequeña, pares, juego)
    win_animations = {}
}

function game_state.init()
    -- Reset all progression on game restart
    state.purchased_cards = {}
    state.owned_amarracos = {}
    state.owned_stickers = {}
    state.sticker_registry = {}  -- Clear sticker attachments on game restart
    state.permanently_removed_cards = {}  -- Clear permanent removals on game restart
    state.dragging_sticker = nil
    state.drag_offset_x = 0
    state.drag_offset_y = 0
    state.upgrades = {}
    
    -- Initialize player with fresh base deck (excluding permanently removed cards)
    state.deck = game_state.create_filtered_deck()
    game_state.restore_deck_stickers(state.deck)  -- Restore sticker attachments
    card.shuffle_deck(state.deck)
    state.hand = card.draw_cards(state.deck, 4)
    state.discards_remaining = 3
    state.score = 0
    state.player_hp = 20
    state.base_player_hp = 20
    
    -- Initialize AI with completely separate deck
    state.ai_deck = card.create_deck()
    card.shuffle_deck(state.ai_deck)
    state.ai_hand = card.draw_cards(state.ai_deck, 4)
    state.ai_discards_remaining = 3
    state.ai_hp = ai.calculate_hp(1)
    
    
    -- Initialize game
    state.round = 1
    state.hands_remaining = 3
    state.max_score = 1
    state.game_over = false
    state.in_combat = false
    state.show_ai_cards = false
    state.pesetas = 0
    state.upgrades = {}
    state.round_discards_used = 0
    state.round_hands_used = 0
    state.purchased_cards = {}
    state.waiting_for_draw_animation = false
    state.pending_draw_data = nil
    state.draw_delay_timer = 0
    state.clearing_cards = false
    state.shop_delay_timer = 0
    state.waiting_for_shop = false
    state.new_hand_delay_timer = 0
    state.waiting_for_new_hand = false
    state.scoring_animation_completed = false
    state.ai_defeated_by_animation = false
    state.player_defeated_by_animation = false
    state.damage_handled_by_animation = false
    state.damage_sequence_active = false
    state.damage_sequence_timer = 0
    state.damage_sequence_combat_result = nil
    state.player_hit_animation = { active = false, text = "", timer = 0, duration = 1.5 }
    state.ai_hit_animation = { active = false, text = "", timer = 0, duration = 1.5 }
    state.win_animations = {}
    state.in_card_selection = false
    state.card_selection_cards = {}
    state.selected_card_index = 0  -- Initialize with no selection for click-to-select
    state.card_selection_type = ""
    -- Don't reset owned_amarracos and owned_stickers - they should persist between rounds
    state.shop_amarracos = {}
    state.shop_stickers = {}
    state.dragging_sticker = nil
    state.drag_offset_x = 0
    state.drag_offset_y = 0
    card.clear_selections(state.hand)
    combat.reset()
    menu.hide()
    
    -- Start with MUS animation instead of transition
    ui.start_mus_animation(1)
    
    -- Position cards in hand
    local canvas = require("canvas")
    local screen_width, _ = canvas.get_internal_dimensions()
    local hand_y = ui.get_hand_y_position()
    card.calculate_positions(state.hand, screen_width / 2, hand_y)
end

function game_state.get()
    return state
end

function game_state.set_fonts(fonts)
    state.fonts = fonts
end

-- Apply upgrades to current state (no longer used)
local function apply_upgrades()
    -- No upgrades to apply anymore
end

-- Get upgrade bonuses for scoring
function game_state.get_upgrade_bonuses()
    return {}  -- No longer using upgrade bonuses
end

-- Update function for combat animations and transitions
function game_state.update(dt)
    -- Update transitions first
    local transition_finished = transition.update(dt)
    
    -- Update card animations
    animation.update(dt)
    
    -- Handle shop delay after card clearing animation
    if state.waiting_for_shop and state.shop_delay_timer > 0 then
        state.shop_delay_timer = state.shop_delay_timer - dt
        if state.shop_delay_timer <= 0 then
            -- Show shop and allow normal UI drawing again
            state.waiting_for_shop = false
            state.clearing_cards = false  -- Now it's safe to show UI again
            state.in_shop = true
            state.shop_items = shop.generate_shop_items(state.owned_amarracos, state.owned_stickers)
            state.selected_shop_item = 0  -- No item selected initially (click to select)
            -- Store generated amarracos for consistency (no longer needed as separate list)
            state.shop_amarracos = {}
        end
    end
    
    -- Handle damage sequence timing
    if state.damage_sequence_active and state.damage_sequence_timer > 0 then
        state.damage_sequence_timer = state.damage_sequence_timer - dt
        if state.damage_sequence_timer <= 0 then
            -- Time to apply AI damage
            game_state.apply_ai_damage_sequence()
        end
    end
    
    -- Handle new hand delay after combat damage
    if state.waiting_for_new_hand and state.new_hand_delay_timer > 0 then
        state.new_hand_delay_timer = state.new_hand_delay_timer - dt
        if state.new_hand_delay_timer <= 0 then
            -- Now draw new hands after damage has been shown
            state.waiting_for_new_hand = false
            
            -- Draw new hands
            state.hand = card.draw_cards(state.deck, 4)
            -- Restore stickers to newly drawn cards
            for _, game_card in ipairs(state.hand) do
                game_state.restore_sticker_attachments(game_card)
            end
            -- Use different random seed for AI to ensure different draws
            math.randomseed(os.time() + math.random(1000, 9999))
            state.ai_hand = card.draw_cards(state.ai_deck, 4)
            
            -- Reset discards (no bonuses)
            state.discards_remaining = 3
            state.ai_discards_remaining = 3
            state.round_discards_used = 0
            
            -- Hide AI cards after new hands are drawn
            state.show_ai_cards = false
            
            -- Clear selections and reposition
            card.clear_selections(state.hand)
            local canvas = require("canvas")
            local screen_width, _ = canvas.get_internal_dimensions()
            local hand_y = ui.get_hand_y_position()
            card.calculate_positions(state.hand, screen_width / 2, hand_y)
        end
    end
    
    -- Update hit/miss animations
    if state.player_hit_animation.active then
        state.player_hit_animation.timer = state.player_hit_animation.timer - dt
        if state.player_hit_animation.timer <= 0 then
            state.player_hit_animation.active = false
        end
    end
    
    if state.ai_hit_animation.active then
        state.ai_hit_animation.timer = state.ai_hit_animation.timer - dt
        if state.ai_hit_animation.timer <= 0 then
            state.ai_hit_animation.active = false
        end
    end
    
    -- Update win condition animations
    for i = #state.win_animations, 1, -1 do
        local anim = state.win_animations[i]
        anim.timer = anim.timer - dt
        anim.bounce_offset = math.sin(anim.timer * 8) * 10  -- Bouncy movement
        if anim.timer <= 0 then
            table.remove(state.win_animations, i)
        end
    end
    
    -- Handle draw delay after discard animations
    if state.waiting_for_draw_animation and state.draw_delay_timer > 0 then
        state.draw_delay_timer = state.draw_delay_timer - dt
        if state.draw_delay_timer <= 0 then
            -- Start draw animation
            local canvas = require("canvas")
            local screen_width, _ = canvas.get_internal_dimensions()
            local deck_x = (screen_width - card.CARD_WIDTH) / 2
            local deck_y = 1906  -- Match the current deck position from ui.lua
            
            -- Calculate hand positions for new cards
            local temp_hand = {}
            for _, existing_card in ipairs(state.hand) do
                table.insert(temp_hand, existing_card)
            end
            for _, new_card in ipairs(state.pending_draw_data.new_cards) do
                table.insert(temp_hand, new_card)
            end
            
            local hand_y = ui.get_hand_y_position()
            card.calculate_positions(temp_hand, screen_width / 2, hand_y)
            
            -- Get positions for just the new cards
            local new_card_positions = {}
            for i = #state.hand + 1, #temp_hand do
                table.insert(new_card_positions, {x = temp_hand[i].x, y = temp_hand[i].y})
            end
            
            -- Start draw animation
            animation.animate_draw_cards(deck_x, deck_y, new_card_positions, state.pending_draw_data.new_cards, 
                function()
                    -- Animation complete, add cards to hand and finish
                    for _, new_card in ipairs(state.pending_draw_data.new_cards) do
                        -- Restore stickers before adding to hand
                        game_state.restore_sticker_attachments(new_card)
                        table.insert(state.hand, new_card)
                    end
                    
                    -- Final positioning
                    local canvas = require("canvas")
            local screen_width, _ = canvas.get_internal_dimensions()
                    local hand_y = ui.get_hand_y_position()
                    card.calculate_positions(state.hand, screen_width / 2, hand_y)
                    
                    -- Final message removed
                    
                    -- Clear animation state
                    state.waiting_for_draw_animation = false
                    state.pending_draw_data = nil
                end)
        end
    end
    
    if state.in_combat then
        local combat_finished, combat_result = combat.update(dt)
        local combat_state_data = combat.get_state()
        
        -- Apply damage/checks only when we just entered a phase
        if combat_state_data.just_entered_phase and not combat_finished then
            if combat_state_data.phase == combat.PHASE_AI_REVEAL then
                -- Simply reveal AI cards without animation
                if not state.show_ai_cards and #state.ai_played_cards > 0 then
                    state.show_ai_cards = true
                end
            elseif combat_state_data.phase == combat.PHASE_PLAYER_ATTACK then
                -- Skip damage application if already handled by animation callback
                if not state.damage_handled_by_animation then
                    -- Apply player damage to AI and trigger hit animation
                    local damage = combat.apply_player_damage()
                    local combat_state = combat.get_state()
                    game_state.trigger_player_hit_animation(combat_state.player_hits)
                    if damage > 0 then
                        state.ai_hp = math.max(0, state.ai_hp - damage)
                    end
                end
            elseif combat_state_data.phase == combat.PHASE_AI_DEFEAT_CHECK then
                -- Check if AI is defeated and end combat early if so
                if state.ai_hp <= 0 then
                    combat.end_with_ai_defeat()
                    combat_finished, combat_result = true, "ai_defeated"
                end
            elseif combat_state_data.phase == combat.PHASE_AI_ATTACK then
                -- Skip damage application if already handled by animation callback
                if not state.damage_handled_by_animation then
                    -- Apply AI damage to player (only if AI wasn't defeated)
                    if state.ai_hp > 0 then
                        local damage = combat.apply_ai_damage()
                        local combat_state = combat.get_state()
                        game_state.trigger_ai_hit_animation(combat_state.ai_hits)
                        if damage > 0 then
                            state.player_hp = math.max(0, state.player_hp - damage)
                        end
                    end
                end
            elseif combat_state_data.phase == combat.PHASE_PLAYER_DEFEAT_CHECK then
                -- Check if player is defeated and end combat early if so
                if state.player_hp <= 0 then
                    combat.end_with_player_defeat()
                    combat_finished, combat_result = true, "player_defeated"
                end
            end
        end
        
        -- Handle combat completion - but only after scoring animation completes
        if (combat_finished and state.scoring_animation_completed) or state.ai_defeated_by_animation or state.player_defeated_by_animation then
            state.in_combat = false
            state.show_ai_cards = false  -- Hide AI cards when combat ends (will be overridden if player defeated)
            state.hands_remaining = state.hands_remaining - 1
            state.round_hands_used = state.round_hands_used + 1
            
            -- Store flags before resetting them
            local ai_was_defeated = (combat_result == "ai_defeated" or state.ai_defeated_by_animation)
            local player_was_defeated = (combat_result == "player_defeated" or state.player_defeated_by_animation)
            
            -- Reset animation flags
            state.scoring_animation_completed = false
            state.ai_defeated_by_animation = false
            state.player_defeated_by_animation = false
            state.damage_handled_by_animation = false
            state.damage_sequence_active = false
            state.damage_sequence_timer = 0
            state.damage_sequence_combat_result = nil
            
            
            if ai_was_defeated then
                -- AI was defeated - round victory
                local unused_discards = state.discards_remaining
                local unused_hands = state.hands_remaining  -- Don't subtract 1 since we already did above
                local remaining_hp = state.player_hp
                local pesetas_earned = shop.calculate_pesetas(unused_discards, unused_hands, remaining_hp)
                
                state.pesetas = state.pesetas + pesetas_earned
                
                -- Apply Pokemon post-victory effects (like Golbat healing)
                local pokemon_abilities = require("pokemon_abilities")
                pokemon_abilities.apply_post_victory_effects(state.player_hand, state)
                
                -- Update max score
                if state.round > state.max_score then
                    state.max_score = state.round
                end
                
                -- Animate all cards off screen, then show shop
                state.clearing_cards = true  -- Hide normal card rendering
                local canvas = require("canvas")
            local screen_width, _ = canvas.get_internal_dimensions()
                local deck_x = (screen_width - card.CARD_WIDTH) / 2
                local deck_y = 1906  -- Match the current deck position from ui.lua
                
                -- Ensure AI cards have positions set for animation
                if #state.ai_played_cards > 0 then
                    local total_width = (#state.ai_played_cards - 1) * (card.CARD_WIDTH + card.CARD_SPACING) + card.CARD_WIDTH
                    local offset_x = (screen_width - total_width) / 2
                    local ai_y = 230
                    
                    for i, ai_card in ipairs(state.ai_played_cards) do
                        local x = offset_x + (i - 1) * (card.CARD_WIDTH + card.CARD_SPACING)
                        ai_card.x = x
                        ai_card.y = ai_y
                    end
                end
                
                -- Animate player hand cards away
                local player_positions = {}
                for i, player_card in ipairs(state.hand) do
                    player_positions[i] = {x = player_card.x, y = player_card.y}
                end
                
                -- Animate AI cards away  
                local ai_positions = {}
                for i, ai_card in ipairs(state.ai_played_cards) do
                    ai_positions[i] = {x = ai_card.x, y = ai_card.y}
                end
                
                local animations_completed = 0
                local total_animations = 2  -- Player cards + AI cards
                
                local function complete_animation()
                    animations_completed = animations_completed + 1
                    if animations_completed >= total_animations then
                        -- After cards are cleared, start timer for shop delay
                        -- DON'T set clearing_cards = false yet - keep cards hidden until shop appears
                        state.waiting_for_shop = true
                        state.shop_delay_timer = 1.0  -- Three second pause to let players see AI hand better
                    end
                end
                
                -- Animate both hands out
                animation.animate_discard_cards(player_positions, state.hand, complete_animation)
                animation.animate_discard_cards(ai_positions, state.ai_played_cards, complete_animation)
                
                local ai_defeat_phrase = ai.get_defeat_phrase()
                return
                
            elseif player_was_defeated then
                -- Player was defeated - game over
                local ai_victory_phrase = ai.get_victory_phrase()
                state.game_over = true
                state.show_ai_cards = true  -- Keep AI cards visible so player can see what killed them
                return
                
            else
                -- Both survive or other result
                if state.player_hp <= 0 then
                    -- Player defeated (backup check)
                    local ai_victory_phrase = ai.get_victory_phrase()
                    state.game_over = true
                    state.show_ai_cards = true  -- Keep AI cards visible so player can see what killed them
                    return
                elseif state.hands_remaining <= 0 then
                    -- Out of hands, player loses
                    local ai_victory_phrase = ai.get_victory_phrase()
                    state.game_over = true
                    state.show_ai_cards = true  -- Keep AI cards visible so player can see what killed them
                    return
                else
                    -- Continue with new hands after a delay to show damage results
                    
                    -- Check if decks have enough cards
                    if #state.deck < 4 or #state.ai_deck < 4 then
                        state.game_over = true
                        state.show_ai_cards = true  -- Keep AI cards visible so player can see final hand
                        return
                    end
                    
                    -- Set up delay before drawing new hands
                    state.waiting_for_new_hand = true
                    state.new_hand_delay_timer = 0.5  -- 0.5 second delay to show damage results
                    
                    -- Don't draw new hands immediately - wait for timer
                end
            end
        end
    end
end

-- Start next round after menu choice
function game_state.start_next_round()
    -- Advance to next round
    state.round = state.round + 1
    
    -- Reset player HP (no bonuses)
    state.base_player_hp = 20
    state.player_hp = state.base_player_hp
    
    -- Reset AI
    state.ai_hp = ai.calculate_hp(state.round)
    
    -- Reset hands (no bonuses)
    state.hands_remaining = 3
    
    -- Apply colgante_perro effect (double hands, no discards)
    if amarracos.has_prize(state.owned_amarracos, "colgante_perro") then
        state.hands_remaining = state.hands_remaining * 2
    end
    
    state.round_discards_used = 0
    state.round_hands_used = 0
    state.show_ai_cards = false
    
    -- Refill both decks completely (excluding permanently removed cards)
    state.deck = game_state.create_filtered_deck()
    
    -- Add all purchased cards to player deck
    for _, purchased_card in ipairs(state.purchased_cards) do
        table.insert(state.deck, purchased_card)
    end
    
    -- Restore sticker attachments to all cards
    game_state.restore_deck_stickers(state.deck)
    
    card.shuffle_deck(state.deck)
    
    -- AI gets standard deck
    state.ai_deck = card.create_deck()
    -- Use different random seed for AI deck shuffle
    math.randomseed(os.time() + math.random(1000, 9999))
    card.shuffle_deck(state.ai_deck)
    
    -- Reset both players for new round
    state.hand = card.draw_cards(state.deck, 4)
    -- Restore stickers to newly drawn cards
    for _, game_card in ipairs(state.hand) do
        game_state.restore_sticker_attachments(game_card)
    end
    -- Ensure different random state for AI draw
    math.randomseed(os.time() + math.random(1000, 9999))
    state.ai_hand = card.draw_cards(state.ai_deck, 4)
    state.discards_remaining = 3  -- No bonuses anymore
    state.ai_discards_remaining = 3
    
    -- Apply colgante_perro effect (no discards)
    if amarracos.has_prize(state.owned_amarracos, "colgante_perro") then
        state.discards_remaining = 0
    end
    
    
    -- Clear selections and reposition
    card.clear_selections(state.hand)
    local canvas = require("canvas")
    local screen_width, _ = canvas.get_internal_dimensions()
    local hand_y = ui.get_hand_y_position()
    card.calculate_positions(state.hand, screen_width / 2, hand_y)
    
    apply_upgrades()
    
    -- Apply amarracos round effects
    amarracos.apply_round_effects(state.owned_amarracos, state)
    
    -- Start MUS animation instead of transition
    ui.start_mus_animation(state.round)
end

-- Add card to player deck permanently
function game_state.add_card_to_deck(new_card)
    -- Add to purchased cards list for future rounds
    table.insert(state.purchased_cards, new_card)
    
    -- Also add to current deck
    table.insert(state.deck, new_card)
    card.shuffle_deck(state.deck)
end

-- Remove selected cards from hand
local function remove_cards_from_hand(hand, selected_indices)
    table.sort(selected_indices, function(a, b) return a > b end)
    
    local removed_cards = {}
    for _, index in ipairs(selected_indices) do
        table.insert(removed_cards, table.remove(hand, index))
    end
    
    return removed_cards
end

-- Discard functionality
function game_state.discard_cards()
    if state.in_combat or state.in_shop or state.in_card_selection or menu.get_state() ~= menu.STATE_NONE or state.waiting_for_draw_animation then
        return false
    end
    
    local selected_indices = card.get_selected_indices(state.hand)
    
    if state.discards_remaining <= 0 then
        return false
    end
    
    if #selected_indices == 0 then
        return false
    end
    
    -- Create discard animation positions and data
    local discarded_positions = {}
    local discarded_cards = {}
    for _, index in ipairs(selected_indices) do
        table.insert(discarded_positions, {x = state.hand[index].x, y = state.hand[index].y})
        table.insert(discarded_cards, state.hand[index])
    end
    
    -- Remove discarded cards from hand immediately
    local discarded = remove_cards_from_hand(state.hand, selected_indices)
    state.discards_remaining = state.discards_remaining - 1
    state.round_discards_used = state.round_discards_used + 1
    
    -- Clear selections
    card.clear_selections(state.hand)
    
    -- Prepare new cards to draw
    local new_cards = card.draw_cards(state.deck, #discarded)
    -- Restore stickers to newly drawn cards
    for _, game_card in ipairs(new_cards) do
        game_state.restore_sticker_attachments(game_card)
    end
    
    -- AI discarding logic
    local ai_discarded_count = 0
    local ai_new_cards = {}
    if state.ai_discards_remaining > 0 and ai.wants_to_discard(state.ai_hand) then
        local ai_discard_cards = ai.select_cards_to_discard(state.ai_hand)
        state.ai_hand = ai.remove_cards_from_hand(state.ai_hand, ai_discard_cards)
        ai_discarded_count = #ai_discard_cards
        
        -- AI draws new cards
        ai_new_cards = card.draw_cards(state.ai_deck, ai_discarded_count)
        for _, new_card in ipairs(ai_new_cards) do
            table.insert(state.ai_hand, new_card)
        end
        
        state.ai_discards_remaining = state.ai_discards_remaining - 1
    end
    
    -- Set up animation state
    state.waiting_for_draw_animation = true
    state.pending_draw_data = {
        new_cards = new_cards,
    }
    
    -- Start discard animation with callback to start delay timer
    animation.animate_discard_cards(discarded_positions, discarded_cards, 
        function()
            -- Start delay timer for draw animation
            state.draw_delay_timer = state.draw_delay_duration
        end)
    
    return true
end

-- Callback function to start sequential damage when scoring animation completes
local function apply_damage_after_animation(combat_result)
    -- Mark that damage is handled by animation to skip combat phase damage
    state.damage_handled_by_animation = true
    
    -- Start sequential damage application
    state.damage_sequence_active = true
    state.damage_sequence_timer = 0
    state.damage_sequence_combat_result = combat_result
    
    -- Apply player damage immediately
    game_state.apply_player_damage_sequence()
end

-- Apply player damage in the sequence
function game_state.apply_player_damage_sequence()
    local combat_result = state.damage_sequence_combat_result
    
    -- Apply player damage to AI and trigger hit animation
    game_state.trigger_player_hit_animation(combat_result.player_hits)
    if combat_result.player_hits and combat_result.player_damage > 0 then
        state.ai_hp = math.max(0, state.ai_hp - combat_result.player_damage)
        -- Player hit for damage
    else
        -- Player attack failed
    end
    
    -- Check if AI is defeated
    if state.ai_hp <= 0 then
        -- AI defeated - trigger victory sequence immediately
        state.scoring_animation_completed = true
        state.ai_defeated_by_animation = true
        state.in_combat = false
        state.damage_sequence_active = false
        state.hands_remaining = state.hands_remaining - 1
        state.round_hands_used = state.round_hands_used + 1
        
        -- Round victory logic
        local unused_discards = state.discards_remaining
        local unused_hands = state.hands_remaining
        local remaining_hp = state.player_hp
        local pesetas_earned = shop.calculate_pesetas(unused_discards, unused_hands, remaining_hp)
        
        state.pesetas = state.pesetas + pesetas_earned
        
        -- Update max score
        if state.round > state.max_score then
            state.max_score = state.round
        end
        
        -- Animate all cards off screen, then show shop
        state.clearing_cards = true
        local canvas = require("canvas")
    local screen_width, _ = canvas.get_internal_dimensions()
        local deck_x = (screen_width - card.CARD_WIDTH) / 2
        local deck_y = 1906  -- Match the current deck position from ui.lua
        
        -- Ensure AI cards have positions for animation
        if #state.ai_played_cards > 0 then
            local total_width = (#state.ai_played_cards - 1) * (card.CARD_WIDTH + card.CARD_SPACING) + card.CARD_WIDTH
            local offset_x = (screen_width - total_width) / 2
            local ai_y = 180
            
            for i, ai_card in ipairs(state.ai_played_cards) do
                local x = offset_x + (i - 1) * (card.CARD_WIDTH + card.CARD_SPACING)
                ai_card.x = x
                ai_card.y = ai_y
            end
        end
        
        -- Animate player hand cards away
        local player_positions = {}
        for i, player_card in ipairs(state.hand) do
            player_positions[i] = {x = player_card.x, y = player_card.y}
        end
        
        -- Animate AI cards away  
        local ai_positions = {}
        for i, ai_card in ipairs(state.ai_played_cards) do
            ai_positions[i] = {x = ai_card.x, y = ai_card.y}
        end
        
        local animations_completed = 0
        local total_animations = 2  -- Player cards + AI cards
        
        local function complete_animation()
            animations_completed = animations_completed + 1
            if animations_completed >= total_animations then
                state.waiting_for_shop = true
                state.shop_delay_timer = 1.0
            end
        end
        
        -- Animate both hands out
        animation.animate_discard_cards(player_positions, state.hand, complete_animation)
        animation.animate_discard_cards(ai_positions, state.ai_played_cards, complete_animation)
        
        local ai_defeat_phrase = ai.get_defeat_phrase()
        return
    end
    
    -- AI survived, start timer for AI damage phase
    state.damage_sequence_timer = 1.5  -- 1.5 second delay before AI attacks
end

-- Apply AI damage in the sequence
function game_state.apply_ai_damage_sequence()
    local combat_result = state.damage_sequence_combat_result
    
    -- Apply AI damage to player and trigger hit animation
    game_state.trigger_ai_hit_animation(combat_result.ai_hits)
    if combat_result.ai_hits and combat_result.ai_damage > 0 then
        state.player_hp = math.max(0, state.player_hp - combat_result.ai_damage)
        -- AI hit player for damage
    else
        -- AI attack failed
    end
    
    -- Check if player is defeated
    if state.player_hp <= 0 then
        -- Player defeated - trigger game over immediately
        state.scoring_animation_completed = true
        state.player_defeated_by_animation = true
        state.in_combat = false
        state.damage_sequence_active = false
        
        local ai_victory_phrase = ai.get_victory_phrase()
        state.game_over = true
        state.show_ai_cards = true  -- Keep AI cards visible so player can see what killed them
        return
    end
    
    -- Both survived - end sequence and prepare for new hand
    state.scoring_animation_completed = true
    state.in_combat = false
    state.damage_sequence_active = false
    
    -- Set up delay for new hand drawing
    state.waiting_for_new_hand = true
    state.new_hand_delay_timer = 0.5  -- 0.5 second delay to show damage results
end

-- Play selected cards and start combat
function game_state.play_cards()
    if state.in_combat or state.in_shop or state.in_card_selection or menu.get_state() ~= menu.STATE_NONE or state.waiting_for_draw_animation then
        return false
    end
    
    -- Reset animation flags for new hand
    state.scoring_animation_completed = false
    state.ai_defeated_by_animation = false
    state.player_defeated_by_animation = false
    state.damage_handled_by_animation = false
    state.damage_sequence_active = false
    state.damage_sequence_timer = 0
    state.damage_sequence_combat_result = nil
    
    local selected_indices = card.get_selected_indices(state.hand)
    
    if #selected_indices == 0 then
        return false
    end
    
    -- Get player's played cards
    local played_cards = {}
    for _, index in ipairs(selected_indices) do
        table.insert(played_cards, state.hand[index])
    end
    
    -- Check for corazon stickers and mark cards for permanent removal
    for _, game_card in ipairs(played_cards) do
        if game_card.attached_sticker then
            local stickers = require("stickers")
            local sticker = stickers.get_sticker_by_id(game_card.attached_sticker)
            if sticker and sticker.effect_type == "permanent_removal" then
                -- Mark this card for permanent removal from deck
                game_card._marked_for_removal = true
            end
        end
    end
    
    -- AI selects cards to play
    local ai_played_cards = ai.select_cards(state.ai_hand)
    local ai_phrase = ai.get_playing_phrase()
    
    
    -- Store played cards for display
    state.player_played_cards = played_cards
    state.ai_played_cards = ai_played_cards
    state.show_ai_cards = false  -- Don't show AI cards initially
    
    -- AI phrase shown
    
    -- Start combat with amarracos (no upgrade bonuses)
    local combat_result = combat.start_combat(played_cards, ai_played_cards, {}, state.owned_amarracos, state)
    state.in_combat = true
    state.show_ai_cards = true  -- Reveal AI cards immediately when combat starts
    state.last_hand_breakdown = combat_result.player_breakdown
    
    -- Process permanent removal of corazón sticker cards immediately after combat starts
    game_state.process_permanent_card_removal()
    
    -- Fixed: combat_result now properly includes amarracos data
    
    -- Start animated scoring breakdown with direct damage callback
    local scoring_animation = require("scoring_animation")
    local damage_callback = function()
        apply_damage_after_animation(combat_result)
    end
    scoring_animation.start(played_cards, ai_played_cards, combat_result.player_breakdown, combat_result.ai_breakdown, combat_result.amarracos_effects, combat_result.owned_amarracos, damage_callback)
    
    -- Update score
    local final_score = combat_result.player_damage
    state.score = state.score + final_score
    
    return true
end

-- Handle card selection by index
function game_state.select_card_by_index(index)
    if state.in_combat or menu.get_state() ~= menu.STATE_NONE then
        return false
    end
    
    if index >= 1 and index <= #state.hand then
        card.toggle_selection(state.hand[index])
        return true
    end
    return false
end

-- Handle card selection by mouse position
function game_state.select_card_by_position(x, y)
    if state.in_combat or state.in_shop or state.in_card_selection or menu.get_state() ~= menu.STATE_NONE then
        return false
    end
    
    for i, game_card in ipairs(state.hand) do
        if card.point_in_card(game_card, x, y) then
            card.toggle_selection(game_card)
            return true
        end
    end
    return false
end

-- Handle shop navigation
-- Navigate shop items (removed - now using click-to-select)

-- Purchase shop item
function game_state.purchase_shop_item()
    if not state.in_shop or state.selected_shop_item < 1 or state.selected_shop_item > #state.shop_items then
        return false
    end
    
    local item = state.shop_items[state.selected_shop_item]
    
    -- Special handling for amarracos - direct purchase
    if item.amarraco_data then
        local cost = item.base_cost
        if state.pesetas < cost then
            return false
        end
        if #state.owned_amarracos >= 5 then
            return false
        end
        
        -- Purchase amarraco directly
        state.pesetas = state.pesetas - cost
        table.insert(state.owned_amarracos, item.amarraco_data)
        
        -- Remove purchased amarraco from shop items
        table.remove(state.shop_items, state.selected_shop_item)
        
        -- Adjust selection if needed
        if state.selected_shop_item > #state.shop_items then
            state.selected_shop_item = #state.shop_items
        end
        
        return true
    elseif item.sticker_data then
        -- Purchase sticker directly
        local cost = item.sticker_data.cost
        if state.pesetas < cost then
            return false
        end
        
        state.pesetas = state.pesetas - cost
        table.insert(state.owned_stickers, item.sticker_data)
        
        -- Remove purchased sticker from shop items
        table.remove(state.shop_items, state.selected_shop_item)
        
        -- Adjust selection if needed
        if state.selected_shop_item > #state.shop_items then
            state.selected_shop_item = #state.shop_items
        end
        
        return true
    end
    
    -- Normal items - calculate cost and deduct
    local cost = shop.get_item_cost(item.id, state.upgrades)
    
    if state.pesetas < cost then
        return false
    end
    
    -- Deduct cost
    state.pesetas = state.pesetas - cost
    
    -- Apply upgrade
    local result = shop.apply_upgrade(item.id, state, state.upgrades)
    
    -- Update purchase count for tracking
    state.upgrades[item.id] = (state.upgrades[item.id] or 0) + 1
    
    if result == "card_choice" then
        -- Enter card selection mode for regular cards
        local choices = shop.get_card_choices()
        state.in_shop = false  -- Temporarily exit shop for clean interface
        state.in_card_selection = true
        state.card_selection_cards = choices
        state.selected_card_index = 0  -- No selection initially for click-to-select
        state.card_selection_type = "card_choice"
        return true
    elseif result == "liga_choice" then
        -- Enter card selection mode for Liga cards
        local liga_choices = shop.get_liga_choices()
        state.in_shop = false  -- Temporarily exit shop for clean interface
        state.in_card_selection = true
        state.card_selection_cards = liga_choices
        state.selected_card_index = 0  -- No selection initially for click-to-select
        state.card_selection_type = "liga_choice"
        return true
    elseif result == "pokemon_choice" then
        -- Enter card selection mode for Pokemon cards
        local pokemon_choices = shop.get_pokemon_choices()
        state.in_shop = false  -- Temporarily exit shop for clean interface
        state.in_card_selection = true
        state.card_selection_cards = pokemon_choices
        state.selected_card_index = 0  -- No selection initially for click-to-select
        state.card_selection_type = "pokemon_choice"
        return true
    elseif result == "sticker_choice" then
        -- Enter card selection mode for stickers
        local sticker_choices = shop.get_sticker_choices()
        state.in_shop = false  -- Temporarily exit shop for clean interface
        state.in_card_selection = true
        state.card_selection_cards = sticker_choices
        state.selected_card_index = 0  -- No selection initially for click-to-select
        state.card_selection_type = "sticker_choice"
        return true
    elseif result == "booster" then
        -- This is no longer used but keeping for compatibility
        state.in_card_selection = true
        state.card_selection_cards = booster_cards
        state.selected_card_index = 0  -- Initialize with no selection for click-to-select
        state.card_selection_type = "booster"
        return true
    else
        -- Item purchased
    end
    
    return true
end

-- Trigger hit/miss animation for player attack
function game_state.trigger_player_hit_animation(hit)
    state.ai_hit_animation.active = true
    state.ai_hit_animation.text = hit and "HIT!" or "MISS!"
    state.ai_hit_animation.timer = state.ai_hit_animation.duration
end

-- Trigger hit/miss animation for AI attack
function game_state.trigger_ai_hit_animation(hit)
    state.player_hit_animation.active = true
    state.player_hit_animation.text = hit and "HIT!" or "MISS!"
    state.player_hit_animation.timer = state.player_hit_animation.duration
end

-- Trigger win condition animations
function game_state.trigger_win_animations(player_breakdown, ai_breakdown, player_hand, ai_hand)
    local canvas = require("canvas")
    local screen_width, _ = canvas.get_internal_dimensions()
    local hand_y = ui.get_hand_y_position()  -- Player hand Y position
    
    -- Clear existing animations
    state.win_animations = {}
    
    -- Get fresh breakdowns for comparison (before amarracos modifications)
    local scoring = require("scoring")
    local fresh_player_breakdown = scoring.get_full_breakdown(player_hand, {})
    local fresh_ai_breakdown = scoring.get_full_breakdown(ai_hand, {})
    
    
    -- Check each win condition using fresh breakdowns
    if fresh_player_breakdown.grandes > fresh_ai_breakdown.grandes then
        table.insert(state.win_animations, {
            text = "¡GRANDE!",
            timer = 2.0,
            x = screen_width / 2 - 80,
            y = hand_y - 40,
            bounce_offset = 0
        })
    end
    
    if fresh_player_breakdown.pequenas < fresh_ai_breakdown.pequenas then
        table.insert(state.win_animations, {
            text = "¡CHICA!",
            timer = 2.0,
            x = screen_width / 2 + 80,
            y = hand_y - 40,
            bounce_offset = 0
        })
    end
    
    if fresh_player_breakdown.multiplier > fresh_ai_breakdown.multiplier then
        table.insert(state.win_animations, {
            text = "¡PARES!",
            timer = 2.0,
            x = screen_width / 2 - 80,
            y = hand_y + 120,
            bounce_offset = 0
        })
    end
    
    if fresh_player_breakdown.juego > fresh_ai_breakdown.juego then
        table.insert(state.win_animations, {
            text = "¡JUEGO!",
            timer = 2.0,
            x = screen_width / 2 + 80,
            y = hand_y + 120,
            bounce_offset = 0
        })
    end
end

-- Navigate card selection (removed - now using click-to-select for all types)

-- Confirm card selection
function game_state.confirm_card_selection()
    if not state.in_card_selection or state.selected_card_index < 1 or state.selected_card_index > #state.card_selection_cards then
        return false
    end
    
    local selected_item = state.card_selection_cards[state.selected_card_index]
    
    if state.card_selection_type == "amarracos" then
        -- Handle amarraco purchase
        if state.pesetas >= selected_item.cost and #state.owned_amarracos < 5 then
            state.pesetas = state.pesetas - selected_item.cost
            table.insert(state.owned_amarracos, selected_item)
            
            -- Return to shop
            state.in_card_selection = false
            state.card_selection_cards = {}
            state.selected_card_index = 0  -- Initialize with no selection for click-to-select
            state.card_selection_type = ""
            state.in_shop = true  -- Return to shop interface
            
            -- Regenerate shop amarracos
            state.shop_amarracos = amarracos.get_shop_prizes(state.owned_amarracos)
            return true
        else
            -- Cannot purchase amarraco
            return false
        end
    elseif state.card_selection_type == "card_choice" or state.card_selection_type == "liga_choice" or state.card_selection_type == "pokemon_choice" then
        -- Handle card selection (regular or Liga)
        local selected_card = selected_item
        game_state.add_card_to_deck(selected_card)
        
        -- Return to shop
        state.in_card_selection = false
        state.card_selection_cards = {}
        state.selected_card_index = 0  -- Initialize with no selection for click-to-select
        state.card_selection_type = ""
        state.in_shop = true  -- Return to shop interface
        
        -- Card added to deck
        
        return true
    elseif state.card_selection_type == "sticker_choice" then
        -- Handle sticker selection
        local selected_sticker = selected_item
        table.insert(state.owned_stickers, selected_sticker)
        
        -- Return to shop
        state.in_card_selection = false
        state.card_selection_cards = {}
        state.selected_card_index = 0  -- Initialize with no selection for click-to-select
        state.card_selection_type = ""
        state.in_shop = true  -- Return to shop interface
        
        -- Sticker added to inventory
        
        return true
    end
end

-- Cancel card selection and return to shop
function game_state.cancel_card_selection()
    if not state.in_card_selection then
        return false
    end
    
    state.in_card_selection = false
    state.card_selection_cards = {}
    state.selected_card_index = 0  -- Initialize with no selection for click-to-select
    state.card_selection_type = ""
    state.in_shop = true  -- Return to shop interface
    
    return true
end

-- Reroll shop options (costs 1 peseta)
function game_state.reroll_shop()
    if not state.in_shop or state.pesetas < 1 then
        return false
    end
    
    -- Cost 1 peseta to reroll
    state.pesetas = state.pesetas - 1
    
    -- Regenerate shop items
    local shop = require("shop")
    state.shop_items = shop.generate_shop_items(state.owned_amarracos, state.owned_stickers)
    
    -- Reset selection
    state.selected_shop_item = 0
    
    return true
end

-- Exit shop and continue to next round
function game_state.exit_shop()
    if not state.in_shop then
        return false
    end
    
    state.in_shop = false
    
    -- Clear shop amarraco sprite bounds to prevent stale tooltip areas
    local ui = require("ui")
    ui.clear_sprite_bounds()
    
    game_state.start_next_round()
    return true
end

-- Select all cards in hand
function game_state.select_all_cards()
    if state.in_combat or state.in_shop or state.in_card_selection or menu.get_state() ~= menu.STATE_NONE then
        return false
    end
    
    local all_selected = true
    
    -- Check if all cards are already selected
    for _, game_card in ipairs(state.hand) do
        if not game_card.selected then
            all_selected = false
            break
        end
    end
    
    -- Toggle all cards (select all if any unselected, deselect all if all selected)
    for _, game_card in ipairs(state.hand) do
        if all_selected then
            game_card.selected = false
            game_card.y = game_card.base_y
        else
            game_card.selected = true
            game_card.y = game_card.base_y - card.POP_OUT_OFFSET
        end
    end
    
    -- All cards selection toggled
end

-- Sticker persistence functions
-- Generate unique key for a card to track sticker attachments
local function get_card_key(game_card)
    if game_card.card_type == "liga" then
        return string.format("liga_%d_%s", game_card.value, game_card.team or "unknown")
    elseif game_card.card_type == "pokemon" then
        return string.format("pokemon_%d_%s", game_card.value, game_card.pokemon or "unknown")
    else
        return string.format("regular_%d_%s", game_card.value, game_card.suit)
    end
end

-- Register a sticker attachment
function game_state.register_sticker_attachment(game_card, sticker_id)
    local key = get_card_key(game_card)
    state.sticker_registry[key] = sticker_id
end

-- Remove a sticker attachment from registry
function game_state.unregister_sticker_attachment(game_card)
    local key = get_card_key(game_card)
    state.sticker_registry[key] = nil
end

-- Restore sticker attachments to a card based on registry
function game_state.restore_sticker_attachments(game_card)
    local key = get_card_key(game_card)
    local sticker_id = state.sticker_registry[key]
    if sticker_id then
        game_card.attached_sticker = sticker_id
    end
end

-- Apply sticker attachments to all cards in a deck
function game_state.restore_deck_stickers(deck)
    for _, game_card in ipairs(deck) do
        game_state.restore_sticker_attachments(game_card)
    end
end

-- Create deck with permanent exclusions applied
function game_state.create_filtered_deck()
    local full_deck = card.create_deck()
    local filtered_deck = {}
    
    -- Only include cards that haven't been permanently removed
    for _, game_card in ipairs(full_deck) do
        local card_key = get_card_key(game_card)
        if not state.permanently_removed_cards[card_key] then
            table.insert(filtered_deck, game_card)
        end
    end
    
    return filtered_deck
end

-- Process permanent removal of cards with corazon stickers after combat
function game_state.process_permanent_card_removal()
    -- Check played cards for removal markers
    local cards_to_remove = {}
    
    -- Check player played cards
    if state.player_played_cards then
        for _, game_card in ipairs(state.player_played_cards) do
            if game_card._marked_for_removal then
                table.insert(cards_to_remove, game_card)
            end
        end
    end
    
    -- Remove marked cards from the deck permanently
    for _, card_to_remove in ipairs(cards_to_remove) do
        game_state.remove_card_from_deck_permanently(card_to_remove)
    end
    
    -- Clear the removal markers
    if state.player_played_cards then
        for _, game_card in ipairs(state.player_played_cards) do
            game_card._marked_for_removal = nil
        end
    end
end

-- Remove a specific card from the deck permanently (including purchased cards)
function game_state.remove_card_from_deck_permanently(card_to_remove)
    local card_key = get_card_key(card_to_remove)
    
    -- Add to permanently removed cards list (prevents recreation in future rounds)
    state.permanently_removed_cards[card_key] = true
    
    -- Remove from current deck
    for i = #state.deck, 1, -1 do
        local deck_card = state.deck[i]
        if get_card_key(deck_card) == card_key then
            table.remove(state.deck, i)
            break  -- Only remove one instance
        end
    end
    
    -- Remove from purchased cards (so it won't be added back in future rounds)
    for i = #state.purchased_cards, 1, -1 do
        local purchased_card = state.purchased_cards[i]
        if get_card_key(purchased_card) == card_key then
            table.remove(state.purchased_cards, i)
            break  -- Only remove one instance
        end
    end
    
    -- Also remove the sticker attachment from registry since card is gone
    game_state.unregister_sticker_attachment(card_to_remove)
end

-- Get permanently removed cards (for debug display)
function game_state.get_permanently_removed_cards()
    return state.permanently_removed_cards
end

return game_state