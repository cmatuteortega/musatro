-- Spanish Deck Card Game (LÖVE2D version)
-- Modular structure with visual card representations

local game_state = require("game_state")
local ui = require("ui")
local card = require("card")
local menu = require("menu")
local shop = require("shop")
local transition = require("transition")
local animation = require("animation")
local amarracos = require("amarracos")
local scoring_animation = require("scoring_animation")
local canvas = require("canvas")

-- Mouse position tracking
local mouse_x = 0
local mouse_y = 0

-- LÖVE2D callbacks
function love.load()
    -- Initialize canvas system for high-resolution rendering
    canvas.init()
    
    -- Initialize random seed once at startup
    math.randomseed(os.time())
    
    -- Ensure proper alpha blending is enabled
    love.graphics.setBlendMode("alpha")
    
    -- Load card sprites
    card.load_sprites()
    
    -- Load amarracos sprites
    amarracos.load_sprites()
    
    -- Load sticker sprites
    local stickers = require("stickers")
    stickers.load_sprites()
    
    -- Create Minecraft fonts (scaled for iPhone high-res canvas with 4x integer scaling)
    local regular_font = love.graphics.newFont("Minecraft.ttf", 56)  -- 14 * 4 for iPhone resolution
    local pixel_font_small = love.graphics.newFont("Minecraft.ttf", 72)  -- 18 * 4
    local pixel_font_big = love.graphics.newFont("Minecraft.ttf", 96)  -- 24 * 4
    local pixel_font_huge = love.graphics.newFont("Minecraft.ttf", 250)  -- Extra large for AI HP
    
    -- Set default font
    love.graphics.setFont(regular_font)
    
    -- Pass fonts to modules
    game_state.set_fonts({
        regular = regular_font,
        pixel_small = pixel_font_small,
        pixel_big = pixel_font_big,
        pixel_huge = pixel_font_huge
    })
    ui.set_fonts({
        regular = regular_font,
        pixel_small = pixel_font_small,
        pixel_big = pixel_font_big,
        pixel_huge = pixel_font_huge
    })
    
    game_state.init()
    ui.update_button_positions()
end

function love.update(dt)
    game_state.update(dt)
    ui.update_tooltip(dt)
    ui.update_mus_animation(dt)  -- Update MUS animation
    scoring_animation.update(dt)
    
    -- Check for card hover for tooltips
    check_card_hover()
end

function love.mousemoved(x, y)
    -- Transform mouse coordinates to canvas space
    mouse_x, mouse_y = canvas.transform_mouse_position(x, y)
    
    -- Check for shop item hover tooltips
    check_shop_hover()
end

function check_shop_hover()
    local state = game_state.get()
    
    -- Only show shop tooltips when in shop
    if not state.in_shop then
        return
    end
    
    -- Check if mouse is hovering over any shop item
    for _, item in ipairs(state.shop_items or {}) do
        local bounds = nil
        
        -- Get sprite bounds based on item type
        if item.amarraco_data and item.amarraco_data._sprite_bounds then
            bounds = item.amarraco_data._sprite_bounds
        elseif item.sticker_data and item.sticker_data._sprite_bounds then
            bounds = item.sticker_data._sprite_bounds
        elseif item._sprite_bounds then  -- Card items
            bounds = item._sprite_bounds
        end
        
        if bounds and mouse_x >= bounds.x and mouse_x <= bounds.x + bounds.width and
           mouse_y >= bounds.y and mouse_y <= bounds.y + bounds.height then
            
            if item.amarraco_data then
                -- Show amarraco tooltip
                ui.show_amarraco_tooltip(item.amarraco_data, mouse_x, mouse_y)
            elseif item.sticker_data then
                -- Show sticker tooltip
                ui.show_amarraco_tooltip(item.sticker_data, mouse_x, mouse_y)
            elseif item.card_type then
                -- Show card tooltip
                ui.show_card_tooltip(item, mouse_x, mouse_y)
            end
            return  -- Only show one tooltip at a time
        end
    end
    
    -- If no shop item is hovered, hide tooltip if it was a shop tooltip
    local tooltip_state = ui.get_tooltip_state()
    if tooltip_state and tooltip_state.active then
        -- Hide tooltip to allow for responsive hover behavior
        ui.hide_tooltip()
    end
end

function check_sticker_item_hover(state)
    -- Only check when we have stickers and a hand (preview/combat phases)
    if not (state.hand and #state.hand > 0) or not state.owned_stickers or #state.owned_stickers == 0 then
        return false
    end
    
    -- Check if mouse is hovering over any sticker in the item area
    local max_stickers = 3
    local stickers_to_check = math.min(#state.owned_stickers, max_stickers)
    for i = 1, stickers_to_check do
        local sticker = state.owned_stickers[i]
        if sticker._item_area_bounds then
            local bounds = sticker._item_area_bounds
            if mouse_x >= bounds.x and mouse_x <= bounds.x + bounds.width and
               mouse_y >= bounds.y and mouse_y <= bounds.y + bounds.height then
                -- Show sticker tooltip
                ui.show_sticker_tooltip(sticker, mouse_x, mouse_y)
                return true
            end
        end
    end
    
    return false
end

function check_card_hover()
    local state = game_state.get()
    
    -- Check card selection menu first
    if state.in_card_selection and state.card_selection_cards then
        check_card_selection_hover(state)
        return
    end
    
    -- Check victory menu card choice
    if state.victory and state.card_choices then
        check_menu_card_hover(state)
        return
    end
    
    -- Skip card tooltips in shop
    if state.in_shop then
        return
    end
    
    -- Check sticker item area for hover (before checking cards)
    if check_sticker_item_hover(state) then
        return
    end
    
    -- Check player hand for hover
    for _, game_card in ipairs(state.hand) do
        if card.point_in_card(game_card, mouse_x, mouse_y) then
            ui.show_game_card_tooltip(game_card, mouse_x, mouse_y)
            return
        end
    end
    
    -- Check AI hand for hover (when visible)
    if state.show_ai_cards and state.ai_hand then
        for _, game_card in ipairs(state.ai_hand) do
            if card.point_in_card(game_card, mouse_x, mouse_y) then
                ui.show_game_card_tooltip(game_card, mouse_x, mouse_y)
                return
            end
        end
    end
    
    -- No card or sticker hovered, hide tooltip appropriately
    local tooltip_state = ui.get_tooltip_state()
    if tooltip_state and (tooltip_state.tooltip_type == "card" or tooltip_state.tooltip_type == "amarraco") then
        -- Only hide if it's not a persistent tooltip (like scoring instructions)
        if tooltip_state.timer and tooltip_state.timer < 4.0 then  -- Sticker tooltips have 3s timer, scoring has 5s
            ui.hide_tooltip()
        end
    end
end

function check_card_selection_hover(state)
    -- Use stored sprite bounds for all selection types
    for i, selection_item in ipairs(state.card_selection_cards) do
        local bounds = selection_item._sprite_bounds
        if bounds and mouse_x >= bounds.x and mouse_x <= bounds.x + bounds.width and
           mouse_y >= bounds.y and mouse_y <= bounds.y + bounds.height then
            
            -- Show appropriate tooltip based on selection type
            if state.card_selection_type == "sticker_choice" then
                ui.show_sticker_tooltip(selection_item, mouse_x, mouse_y)
            elseif state.card_selection_type == "amarracos" then
                ui.show_amarraco_tooltip(selection_item, mouse_x, mouse_y)
            else
                -- Cards (regular, liga, pokemon)
                ui.show_game_card_tooltip(selection_item, mouse_x, mouse_y)
            end
            return
        end
    end
    
    -- No item hovered, hide tooltip if it was from selection
    local tooltip_state = ui.get_tooltip_state()
    if tooltip_state and (tooltip_state.tooltip_type == "card" or tooltip_state.tooltip_type == "amarraco") then
        ui.hide_tooltip()
    end
end

function check_menu_card_hover(state)
    -- Calculate card positions (same logic as in menu.draw_card_choice)
    local screen_width = love.graphics.getWidth()
    local card_y = 180
    local total_width = 3 * (card.CARD_WIDTH + 20) - 20
    local start_x = (screen_width - total_width) / 2
    
    for i, choice_card in ipairs(state.card_choices) do
        local x = start_x + (i - 1) * (card.CARD_WIDTH + 20)
        
        -- Check if mouse is over this card
        if mouse_x >= x and mouse_x <= x + card.CARD_WIDTH and
           mouse_y >= card_y and mouse_y <= card_y + card.CARD_HEIGHT then
            ui.show_game_card_tooltip(choice_card, mouse_x, mouse_y)
            return
        end
    end
    
    -- No card hovered, hide tooltip if it was a card tooltip
    local tooltip_state = ui.get_tooltip_state()
    if tooltip_state and tooltip_state.tooltip_type == "card" then
        ui.hide_tooltip()
    end
end

function love.draw()
    -- Begin drawing to high-resolution canvas
    canvas.begin_draw()
    
    local state = game_state.get()
    
    -- Draw UI elements based on game state
    if state.in_card_selection then
        -- Draw card selection interface
        ui.draw_card_selection(state)
    elseif state.in_shop then
        -- Draw shop interface
        ui.draw_shop(state)
    else
        -- Draw normal game interface
        ui.draw_title_and_scores(state)
        ui.draw_amarracos(state)
        
        -- Only draw cards if not clearing them
        if not state.clearing_cards then
            ui.draw_ai_cards(state)
            ui.draw_hand_label()
            ui.draw_hand(state.hand)
            ui.draw_deck(state)
        end
        
        ui.draw_buttons(state)
        
        -- Draw win condition animations
        ui.draw_win_animations(state)
        
        -- Draw scoring animations
        ui.draw_scoring_animations()
    end
    
    -- Draw card animations
    animation.draw(state.fonts)
    
    -- Draw menus on top
    local menu_state = menu.get_state()
    if menu_state == menu.STATE_ROUND_VICTORY then
        menu.draw_round_victory(state.fonts, state.pesetas, state.max_score)
    elseif menu_state == menu.STATE_SHOP then
        menu.draw_shop(state.fonts, state.pesetas, state.upgrades)
    elseif menu_state == menu.STATE_CARD_CHOICE then
        menu.draw_card_choice(state.fonts)
    end
    
    -- Draw transitions on top of everything
    transition.draw(state.fonts)
    
    -- Draw dragging sticker on top of all other elements (but below tooltip)
    ui.draw_dragging_sticker(state)
    
    -- Draw MUS animation on top of everything (but below tooltip)
    ui.draw_mus_animation()
    
    -- Draw tooltip on top of everything
    ui.draw_tooltip()
    
    -- End canvas drawing and render to screen with scaling
    canvas.end_draw()
end

function love.keypressed(key)
    local state = game_state.get()
    
    -- Check if MUS animation is active and skip it on any key press
    if ui.is_mus_animation_active() then
        ui.skip_mus_animation()
        return
    end
    
    -- Don't handle input during transitions
    if transition.is_active() then
        return
    end
    
    -- Handle card selection input (click-to-select only)
    if state.in_card_selection then
        -- All card selection types now use click-to-select, only escape works
        if key == "escape" then
            game_state.cancel_card_selection()
        end
        return
    end
    
    -- Handle shop input (simplified - only escape to exit)
    if state.in_shop then
        if key == "escape" or key == "q" then
            game_state.exit_shop()
        end
        return
    end
    
    -- Handle menu input (legacy - can be removed later)
    local menu_result, extra_data = menu.handle_input(key, game_state)
    if menu_result then
        if menu_result == "continue" then
            -- Start transition to next round
            transition.start(transition.TYPE_SHOP_EXIT,
                            "PREPARANDO...",
                            "Comenzando siguiente ronda",
                            1.5,
                            function()
                                game_state.start_next_round()
                            end)
            menu.hide()
        elseif menu_result == "shop" then
            -- Start transition to shop
            transition.start(transition.TYPE_SHOP_ENTER,
                            "QUIOSCO",
                            "Elige tus mejoras",
                            1.5,
                            nil)
        elseif menu_result == "card_chosen" and extra_data then
            game_state.add_card_to_deck(extra_data)
        elseif menu_result == "purchased" then
        elseif menu_result == "insufficient_funds" then
        end
        return
    end
    
    if key == "r" then
        game_state.init()
        ui.update_button_positions()
        return
    end
    
    if state.game_over then
        return
    end
    
    -- Number keys to select cards
    local num = tonumber(key)
    if num and num >= 1 and num <= #state.hand then
        game_state.select_card_by_index(num)
        return
    end
    
    -- Action keys
    if key == "d" then
        game_state.discard_cards()
    elseif key == "p" then
        game_state.play_cards()
    elseif key == "a" then
        game_state.select_all_cards()
    end
end

function love.mousepressed(x, y, button)
    if button == 1 then -- Left mouse button
        -- Check if MUS animation is active and skip it on click
        if ui.is_mus_animation_active() then
            ui.skip_mus_animation()
            return
        end
        
        -- Transform mouse coordinates to canvas space
        local canvas_x, canvas_y = canvas.transform_mouse_position(x, y)
        
        local state = game_state.get()
        
        -- Handle shop item clicking first (before other mouse handling)
        if state.in_shop then
            -- Check if clicking on a shop item to select it
            local item_clicked = false
            for i, item in ipairs(state.shop_items) do
                local bounds = nil
                
                -- Get bounds for different item types
                if item.amarraco_data and item.amarraco_data._sprite_bounds then
                    bounds = item.amarraco_data._sprite_bounds
                elseif item._sprite_bounds then  -- Card items
                    bounds = item._sprite_bounds
                end
                
                if bounds and canvas_x >= bounds.x and canvas_x <= bounds.x + bounds.width and
                   canvas_y >= bounds.y and canvas_y <= bounds.y + bounds.height then
                    state.selected_shop_item = i
                    item_clicked = true
                    break
                end
            end
            
            -- If no item was clicked, check for button clicks
            if not item_clicked then
                local button_action = ui.check_button_click(canvas_x, canvas_y, state)
                if button_action == "shop_reroll" then
                    game_state.reroll_shop()
                elseif button_action == "shop_purchase" then
                    game_state.purchase_shop_item()
                else
                    -- Reset selection when clicking on background or non-interactive areas
                    state.selected_shop_item = 0
                end
            end
            
            -- Don't process other interactions in shop
            return
        end
        
        -- Check if clicking on an amarraco sprite for dynamic scaling and tooltip (combat only)
        if ui.handle_amarraco_mouse_press(canvas_x, canvas_y, state) then
            return
        end
        
        -- Check if clicking on a sticker to start dragging (during combat only)
        if ui.handle_sticker_mouse_press(canvas_x, canvas_y, state) then
            return
        end
        
        -- Check if clicking on scoring info button
        if state._scoring_info_bounds then
            local bounds = state._scoring_info_bounds
            if canvas_x >= bounds.x and canvas_x <= bounds.x + bounds.width and
               canvas_y >= bounds.y and canvas_y <= bounds.y + bounds.height then
                ui.show_scoring_tooltip(canvas_x, canvas_y)
                return
            end
        end
        
        -- Hide tooltip on any other click
        ui.hide_tooltip()
        
        -- Handle card selection clicking (all types now use click-to-select)
        if state.in_card_selection then
                
                -- Check for button clicks first
                local button_action = ui.check_button_click(canvas_x, canvas_y, state)
                if button_action == "card_selection_cancel" then
                    game_state.cancel_card_selection()
                    return
                elseif button_action == "card_selection_confirm" then
                    game_state.confirm_card_selection()
                    return
                end
                
                -- Check for card/sticker clicks using stored sprite bounds
                for i, selection_item in ipairs(state.card_selection_cards) do
                    local bounds = selection_item._sprite_bounds
                    if bounds and canvas_x >= bounds.x and canvas_x <= bounds.x + bounds.width and
                       canvas_y >= bounds.y and canvas_y <= bounds.y + bounds.height then
                        state.selected_card_index = i
                        return
                    end
                end
                
                -- Amarraco clicks are already handled above with sprite bounds
                -- No additional handling needed
                
            -- Skip other mouse handling during card selection
            return
        end
        
        -- Check if clicking on a card
        if game_state.select_card_by_position(canvas_x, canvas_y) then
            return
        end
        
        -- Check if clicking on a button
        local button_action = ui.check_button_click(canvas_x, canvas_y, state)
        if button_action == "discard" then
            game_state.discard_cards()
        elseif button_action == "play" then
            game_state.play_cards()
        end
    end
end

function love.mousereleased(x, y, button)
    if button == 1 then -- Left mouse button
        -- Transform mouse coordinates to canvas space
        local canvas_x, canvas_y = canvas.transform_mouse_position(x, y)
        local state = game_state.get()
        
        -- Handle sticker drop first (if dragging)
        if ui.handle_sticker_mouse_release(canvas_x, canvas_y, state) then
            return
        end
        
        -- Handle amarraco mouse release (stop scaling and hide tooltip)
        ui.handle_amarraco_mouse_release()
    end
end

function love.resize(w, h)
    -- Update canvas scaling for new window size
    canvas.on_resize(w, h)
    
    ui.update_button_positions()
    local state = game_state.get()
    local card = require("card")
    
    -- Use internal canvas dimensions for positioning
    local internal_w, internal_h = canvas.get_internal_dimensions()
    card.calculate_positions(state.hand, internal_w / 2, ui.get_hand_y_position())
end