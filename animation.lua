-- Animation system for Spanish Deck Card Game
local card = require("card")

local animation = {}

-- Animation types
animation.TYPE_DRAW = "draw"
animation.TYPE_DISCARD = "discard"
animation.TYPE_FLIP = "flip"

-- Animation state
local animation_state = {
    active_animations = {},
    next_id = 1
}

-- Create a new card animation
function animation.create_card_animation(type, start_x, start_y, end_x, end_y, card_data, duration, callback)
    local anim = {
        id = animation_state.next_id,
        type = type,
        start_x = start_x,
        start_y = start_y,
        end_x = end_x,
        end_y = end_y,
        current_x = start_x,
        current_y = start_y,
        card_data = card_data,
        duration = duration or 0.5,
        elapsed = 0,
        callback = callback,
        completed = false
    }
    
    animation_state.next_id = animation_state.next_id + 1
    table.insert(animation_state.active_animations, anim)
    
    return anim.id
end

-- Create a card flip animation (for face-down to face-up reveal)
function animation.create_flip_animation(x, y, card_data, duration, callback)
    local anim = {
        id = animation_state.next_id,
        type = animation.TYPE_FLIP,
        start_x = x,
        start_y = y,
        end_x = x,  -- Same position
        end_y = y,
        current_x = x,
        current_y = y,
        card_data = card_data,
        duration = duration or 0.6,
        elapsed = 0,
        callback = callback,
        completed = false,
        flip_progress = 0  -- 0 = face down, 1 = face up
    }
    
    animation_state.next_id = animation_state.next_id + 1
    table.insert(animation_state.active_animations, anim)
    
    return anim.id
end

-- Update all animations
function animation.update(dt)
    -- Safety check to prevent excessive delta times
    if dt > 0.1 then
        dt = 0.1
    end
    
    for i = #animation_state.active_animations, 1, -1 do
        local anim = animation_state.active_animations[i]
        
        if not anim.completed then
            -- Handle delayed start animations
            if anim.delayed_start and anim.start_delay and anim.start_delay > 0 then
                anim.start_delay = anim.start_delay - dt
                -- Don't update the animation until delay is over, but still initialize values
                if anim.start_delay > 0 then
                    -- Make sure flip animation has proper initial values
                    if anim.type == animation.TYPE_FLIP then
                        anim.flip_progress = anim.flip_progress or 0
                    end
                    goto continue_loop
                end
            end
            
            anim.elapsed = anim.elapsed + dt
            local progress = math.min(anim.elapsed / math.max(0.1, anim.duration or 0.5), 1.0)  -- Prevent division by zero
            
            if anim.type == animation.TYPE_FLIP then
                -- Simplified flip animation using progress directly
                anim.flip_progress = progress  -- 0 to 1 over animation duration
            else
                -- Easing function (ease-out) for regular animations
                local eased_progress = 1 - (1 - progress) * (1 - progress)
                
                -- Update position
                anim.current_x = anim.start_x + (anim.end_x - anim.start_x) * eased_progress
                anim.current_y = anim.start_y + (anim.end_y - anim.start_y) * eased_progress
            end
            
            -- Check if animation is complete
            if progress >= 1.0 then
                anim.completed = true
                
                -- Execute callback if provided (with error protection)
                if anim.callback then
                    local success, err = pcall(anim.callback)
                    if not success then
                        print("Animation callback error:", err)
                    end
                end
            end
        end
        
        ::continue_loop::
        
        -- Remove completed animations after a short delay
        if anim.completed and anim.elapsed > anim.duration + 0.1 then
            table.remove(animation_state.active_animations, i)
        end
    end
end

-- Draw all active animations
function animation.draw(fonts)
    for _, anim in ipairs(animation_state.active_animations) do
        if not anim.completed then
            if anim.type == animation.TYPE_FLIP then
                -- Draw flip animation using alpha blending instead of scaling
                if anim.card_data and anim.flip_progress ~= nil then
                    local x = anim.current_x or anim.start_x or 0
                    local y = anim.current_y or anim.start_y or 0
                    
                    if anim.flip_progress < 0.5 then
                        -- First half: show face down with fading alpha
                        local alpha = 1 - (anim.flip_progress * 2)  -- 1 to 0
                        love.graphics.push()
                        love.graphics.setColor(1, 1, 1, alpha)
                        card.draw_face_down(x, y, fonts.regular)
                        love.graphics.pop()
                    else
                        -- Second half: show face up with increasing alpha
                        local alpha = (anim.flip_progress - 0.5) * 2  -- 0 to 1
                        if anim.card_data.value and anim.card_data.suit then
                            local display_card = {
                                x = x,
                                y = y,
                                value = anim.card_data.value,
                                suit = anim.card_data.suit,
                                display_value = anim.card_data.display_value or tostring(anim.card_data.value),
                                selected = false,
                                card_type = anim.card_data.card_type,
                                team = anim.card_data.team,
                                pokemon = anim.card_data.pokemon
                            }
                            love.graphics.push()
                            love.graphics.setColor(1, 1, 1, alpha)
                            card.draw_card(display_card, fonts.regular)
                            love.graphics.pop()
                        else
                            -- Fallback to face down if data is invalid
                            love.graphics.push()
                            love.graphics.setColor(1, 1, 1, alpha)
                            card.draw_face_down(x, y, fonts.regular)
                            love.graphics.pop()
                        end
                    end
                    
                    -- Reset color after drawing
                    love.graphics.setColor(1, 1, 1, 1)
                end
            else
                -- Regular animations
                if anim.card_data then
                    -- Draw the animated card
                    local display_card = {
                        x = anim.current_x,
                        y = anim.current_y,
                        value = anim.card_data.value,
                        suit = anim.card_data.suit,
                        display_value = anim.card_data.display_value,
                        selected = false,
                        card_type = anim.card_data.card_type,
                        team = anim.card_data.team,
                        pokemon = anim.card_data.pokemon
                    }
                    
                    card.draw_card(display_card, fonts.regular)
                else
                    -- For deck animations, use deck sprite or back card sprite
                    if anim.card_data and anim.card_data.suit == "Deck" then
                        -- This is the deck clearing animation - use deck sprite or back sprite
                        local deck_sprite = card.get_deck_sprite()
                        local back_sprite = card.get_back_sprite()
                        
                        if deck_sprite then
                            love.graphics.setColor(1, 1, 1, 1)
                            love.graphics.draw(deck_sprite, anim.current_x, anim.current_y, 0, 2.0, 2.0)
                        elseif back_sprite then
                            love.graphics.setColor(1, 1, 1, 1)
                            love.graphics.draw(back_sprite, anim.current_x, anim.current_y, 0, 2.0, 2.0)
                        else
                            -- Ultimate fallback
                            card.draw_face_down(anim.current_x, anim.current_y, fonts.regular)
                        end
                    else
                        -- Regular card back for other animations
                        card.draw_face_down(anim.current_x, anim.current_y, fonts.regular)
                    end
                end
            end
        end
    end
end

-- Animate drawing cards from deck to hand
function animation.animate_draw_cards(deck_x, deck_y, hand_positions, cards, callback)
    local animations_completed = 0
    local total_animations = #cards
    
    -- If no cards to animate, call callback immediately
    if total_animations == 0 and callback then
        callback()
        return
    end
    
    for i, card_data in ipairs(cards) do
        local target_pos = hand_positions[i]
        if target_pos then
            animation.create_card_animation(
                animation.TYPE_DRAW,
                deck_x, deck_y,
                target_pos.x, target_pos.y,
                card_data,
                0.6,
                function()
                    animations_completed = animations_completed + 1
                    if animations_completed >= total_animations and callback then
                        callback()
                    end
                end
            )
        end
    end
end

-- Animate clearing all cards and UI elements off screen (for round end)
function animation.animate_clear_all_cards(player_hand, ai_cards, deck_position, callback)
    local animations_completed = 0
    -- Count all elements: player hand + AI cards + deck + any visible UI cards
    local total_animations = #player_hand + #ai_cards + 1  -- +1 for deck
    
    -- If no animations, call callback immediately
    if total_animations <= 1 and callback then
        callback()
        return
    end
    
    local discard_x = -card.CARD_WIDTH - 50  -- Off screen to the left
    local canvas = require("canvas")
    local _, screen_height = canvas.get_internal_dimensions()
    local base_discard_y = screen_height / 2 - card.CARD_HEIGHT / 2
    local animation_delay = 0.1  -- Stagger the start times
    
    local function complete_animation()
        animations_completed = animations_completed + 1
        if animations_completed >= total_animations and callback then
            callback()
        end
    end
    
    -- Animate player hand out (with slight delay)
    for i, player_card in ipairs(player_hand) do
        if player_card.x and player_card.y then
            -- Add delay to create wave effect
            local delayed_anim = {
                start_delay = (i - 1) * animation_delay,
                original_callback = complete_animation
            }
            
            -- Create animation with delay
            local timer = love.timer.getTime() + delayed_anim.start_delay
            animation.create_card_animation(
                animation.TYPE_DISCARD,
                player_card.x, player_card.y,
                discard_x, base_discard_y + (i - 1) * 6,
                player_card,
                1.0,  -- Longer duration for dramatic effect
                complete_animation
            )
        else
            complete_animation()
        end
    end
    
    -- Animate AI cards out (with delay after player cards)
    for i, ai_card in ipairs(ai_cards) do
        if ai_card.x and ai_card.y then
            local delayed_start = #player_hand * animation_delay + (i - 1) * animation_delay
            animation.create_card_animation(
                animation.TYPE_DISCARD,
                ai_card.x, ai_card.y,
                discard_x, base_discard_y + (#player_hand + i - 1) * 6,
                ai_card,
                1.0,
                complete_animation
            )
        else
            -- If AI card doesn't have position, skip animation but still count completion
            complete_animation()
        end
    end
    
    -- Animate deck out (last)
    if deck_position then
        local deck_delay = (#player_hand + #ai_cards) * animation_delay
        local fake_deck_card = { value = 0, suit = "Deck", display_value = "DECK" }
        animation.create_card_animation(
            animation.TYPE_DISCARD,
            deck_position.x, deck_position.y,
            discard_x, base_discard_y + (#player_hand + #ai_cards) * 6,
            fake_deck_card,
            1.0,
            complete_animation
        )
    else
        complete_animation()
    end
end

-- Animate discarding cards to the left side
function animation.animate_discard_cards(hand_positions, cards, callback)
    local animations_completed = 0
    local total_animations = #cards
    
    -- If no cards to animate, call callback immediately
    if total_animations == 0 and callback then
        callback()
        return
    end
    
    local discard_x = -card.CARD_WIDTH - 20  -- Off screen to the left
    local canvas = require("canvas")
    local _, screen_height = canvas.get_internal_dimensions()
    local discard_y = screen_height / 2 - card.CARD_HEIGHT / 2
    
    for i, card_data in ipairs(cards) do
        local start_pos = hand_positions[i]
        if start_pos then
            animation.create_card_animation(
                animation.TYPE_DISCARD,
                start_pos.x, start_pos.y,
                discard_x, discard_y + (i - 1) * 5,  -- Stack discards slightly
                card_data,
                0.5,
                function()
                    animations_completed = animations_completed + 1
                    if animations_completed >= total_animations and callback then
                        callback()
                    end
                end
            )
        end
    end
end

-- Check if any animations are currently active
function animation.is_animating()
    return #animation_state.active_animations > 0
end

-- Clear all animations
function animation.clear_all()
    animation_state.active_animations = {}
end

-- Get active animation count
function animation.get_active_count()
    return #animation_state.active_animations
end

-- Get active animations (for checking animation types)
function animation.get_active_animations()
    return animation_state.active_animations
end

-- Animate AI cards flipping from face-down to face-up
function animation.animate_ai_card_reveal(ai_cards, callback)
    local animations_completed = 0
    local total_animations = #ai_cards
    
    -- If no cards to animate, call callback immediately
    if total_animations == 0 and callback then
        callback()
        return
    end
    
    -- Create flip animations for all cards immediately, but with staggered start times
    for i, ai_card in ipairs(ai_cards) do
        -- Validate card data before creating animation (be more lenient with positions)
        if ai_card and ai_card.value and ai_card.suit then
            -- Create flip animation with delay built into the animation itself
            -- Use card positions if available, otherwise use default positions
            local card_x = ai_card.x or (i * 80)  -- Fallback spacing
            local card_y = ai_card.y or 200       -- Fallback y position
            
            local flip_anim = {
                id = animation_state.next_id,
                type = animation.TYPE_FLIP,
                start_x = card_x,
                start_y = card_y,
                end_x = card_x,
                end_y = card_y,
                current_x = card_x,
                current_y = card_y,
                card_data = ai_card,
                duration = 0.6,
                elapsed = 0,
                start_delay = (i - 1) * 0.15,  -- Staggered start
                callback = function()
                    animations_completed = animations_completed + 1
                    if animations_completed >= total_animations and callback then
                        callback()
                    end
                end,
                completed = false,
                flip_progress = 0,
                delayed_start = true  -- Flag to indicate this has a start delay
            }
            
            animation_state.next_id = animation_state.next_id + 1
            table.insert(animation_state.active_animations, flip_anim)
        else
            -- Skip invalid card but still count it for completion
            animations_completed = animations_completed + 1
            if animations_completed >= total_animations and callback then
                callback()
            end
        end
    end
end

return animation