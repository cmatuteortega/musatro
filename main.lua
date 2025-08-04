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
    
    -- Create Minecraft fonts (scaled for iPhone high-res canvas with 4x integer scaling)
    local regular_font = love.graphics.newFont("Minecraft.ttf", 56)  -- 14 * 4 for iPhone resolution
    local pixel_font_small = love.graphics.newFont("Minecraft.ttf", 72)  -- 18 * 4
    local pixel_font_big = love.graphics.newFont("Minecraft.ttf", 96)  -- 24 * 4
    
    -- Set default font
    love.graphics.setFont(regular_font)
    
    -- Pass fonts to modules
    game_state.set_fonts({
        regular = regular_font,
        pixel_small = pixel_font_small,
        pixel_big = pixel_font_big
    })
    ui.set_fonts({
        regular = regular_font,
        pixel_small = pixel_font_small,
        pixel_big = pixel_font_big
    })
    
    game_state.init()
    ui.update_button_positions()
end

function love.update(dt)
    game_state.update(dt)
    ui.update_tooltip(dt)
    scoring_animation.update(dt)
    
    -- Check for card hover for tooltips
    check_card_hover()
end

function love.mousemoved(x, y)
    -- Transform mouse coordinates to canvas space
    mouse_x, mouse_y = canvas.transform_mouse_position(x, y)
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
    
    -- No card hovered, hide tooltip if it was a card tooltip
    local tooltip_state = ui.get_tooltip_state()
    if tooltip_state and tooltip_state.tooltip_type == "card" then
        ui.hide_tooltip()
    end
end

function check_card_selection_hover(state)
    if state.card_selection_type == "amarracos" then
        return  -- Skip amarraco selection
    end
    
    -- Calculate card positions (same logic as in ui.draw_card_selection)
    local screen_width = love.graphics.getWidth()
    local card_spacing = 20
    local total_width = #state.card_selection_cards * (card.CARD_WIDTH + card_spacing) - card_spacing
    local start_x = (screen_width - total_width) / 2
    local card_y = 150
    
    for i, selection_card in ipairs(state.card_selection_cards) do
        local x = start_x + (i - 1) * (card.CARD_WIDTH + card_spacing)
        
        -- Check if mouse is over this card
        if mouse_x >= x and mouse_x <= x + card.CARD_WIDTH and
           mouse_y >= card_y and mouse_y <= card_y + card.CARD_HEIGHT then
            ui.show_game_card_tooltip(selection_card, mouse_x, mouse_y)
            return
        end
    end
    
    -- No card hovered, hide tooltip if it was a card tooltip
    local tooltip_state = ui.get_tooltip_state()
    if tooltip_state and tooltip_state.tooltip_type == "card" then
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
    
    -- Draw tooltip on top of everything
    ui.draw_tooltip()
    
    -- End canvas drawing and render to screen with scaling
    canvas.end_draw()
end

function love.keypressed(key)
    local state = game_state.get()
    
    -- Don't handle input during transitions
    if transition.is_active() then
        return
    end
    
    -- Handle card selection input first
    if state.in_card_selection then
        if key == "left" or key == "a" then
            game_state.navigate_card_selection("left")
        elseif key == "right" or key == "d" then
            game_state.navigate_card_selection("right")
        elseif key == "return" or key == "space" then
            game_state.confirm_card_selection()
        elseif key == "escape" then
            game_state.cancel_card_selection()
        end
        return
    end
    
    -- Handle shop input
    if state.in_shop then
        if key == "up" or key == "w" then
            game_state.navigate_shop("up")
        elseif key == "down" or key == "s" then
            game_state.navigate_shop("down")
        elseif key == "return" or key == "space" then
            game_state.purchase_shop_item()
        elseif key == "escape" or key == "q" then
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
        -- Transform mouse coordinates to canvas space
        local canvas_x, canvas_y = canvas.transform_mouse_position(x, y)
        
        local state = game_state.get()
        
        -- Check if clicking on an amarraco sprite for dynamic scaling and tooltip (works in shop too)
        if ui.handle_amarraco_mouse_press(canvas_x, canvas_y, state) then
            return
        end
        
        -- Hide tooltip on any other click
        ui.hide_tooltip()
        
        -- Don't process card/button clicks when in shop or card selection
        if state.in_shop or state.in_card_selection then
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