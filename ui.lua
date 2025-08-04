-- UI module for Spanish Deck Card Game
local card = require("card")
local scoring = require("scoring")
local combat = require("combat")
local animation = require("animation")
local shop = require("shop")
local amarracos = require("amarracos")

local ui = {}

-- Button dimensions and positions (scaled for iPhone high-res canvas with 4x integer scaling)
ui.BUTTON_WIDTH = 240  -- 4x scale for iPhone resolution
ui.BUTTON_HEIGHT = 70  -- 4x scale for iPhone resolution  
-- Sprite button dimensions (33x33 base size at 10x scale for better visibility)
ui.SPRITE_BUTTON_SIZE = 330  -- 33 * 10 = 330 (10x scaling for better visibility)
ui.BUTTON_SPACING = 30  -- 4x scale for iPhone resolution

-- Tooltip system
local tooltip = {
    active = false,
    amarraco = nil,
    card = nil,
    tooltip_type = nil,  -- "amarraco" or "card"
    x = 0,
    y = 0,
    timer = 0
}

-- Click state tracking for amarracos
local clicked_amarraco = {
    active = false,
    index = nil,  -- Which amarraco is being clicked
    x = 0,
    y = 0
}

-- Fonts
local fonts = {}

-- Button structure
local buttons = {
    discard = { x = 0, y = 0, width = ui.BUTTON_WIDTH, height = ui.BUTTON_HEIGHT, text = "DISCARD", color = {0.7, 0.7, 1} },
    play = { x = 0, y = 0, width = ui.BUTTON_WIDTH, height = ui.BUTTON_HEIGHT, text = "PLAY", color = {1, 0.7, 0.7} },
}

function ui.set_fonts(font_table)
    fonts = font_table
end

-- Helper function to get screen dimensions (uses canvas when available)
function ui.get_screen_dimensions()
    local canvas = require("canvas")
    return canvas.get_internal_dimensions()
end

-- Tooltip functions
function ui.show_amarraco_tooltip(amarraco, x, y)
    tooltip.active = true
    tooltip.amarraco = amarraco
    tooltip.card = nil
    tooltip.tooltip_type = "amarraco"
    tooltip.x = x
    tooltip.y = y
    tooltip.timer = 3.0  -- Show for 3 seconds
end

function ui.show_game_card_tooltip(game_card, x, y)
    tooltip.active = true
    tooltip.amarraco = nil
    tooltip.card = game_card
    tooltip.tooltip_type = "card"
    tooltip.x = x
    tooltip.y = y
    tooltip.timer = 3.0  -- Show for 3 seconds
end

function ui.show_card_tooltip(card_item, x, y)
    tooltip.active = true
    tooltip.amarraco = card_item  -- Reuse the same tooltip structure for shop items
    tooltip.card = nil
    tooltip.tooltip_type = "amarraco"
    tooltip.x = x
    tooltip.y = y
    tooltip.timer = 3.0  -- Show for 3 seconds
end

function ui.hide_tooltip()
    tooltip.active = false
    tooltip.amarraco = nil
    tooltip.card = nil
    tooltip.tooltip_type = nil
    tooltip.timer = 0
end

function ui.get_tooltip_state()
    return tooltip
end

-- Clear sprite bounds and hide tooltips (call when exiting shop)
function ui.clear_sprite_bounds()
    -- Hide any active tooltip
    ui.hide_tooltip()
end

function ui.update_tooltip(dt)
    if tooltip.active then
        tooltip.timer = tooltip.timer - dt
        if tooltip.timer <= 0 then
            ui.hide_tooltip()
        end
    end
end

function ui.draw_tooltip()
    if not tooltip.active or (not tooltip.amarraco and not tooltip.card) then
        return
    end
    
    local screen_width, screen_height = ui.get_screen_dimensions()
    
    -- Base tooltip dimensions for high-resolution canvas
    local tooltip_width = 600   -- Fixed width for consistent layout
    local margin = 20           -- Screen edge margin
    local padding = 15          -- Internal padding
    local line_height = 50      -- Height per text line
    local base_height = 100     -- Base height for title and padding
    
    -- Helper function to wrap text to fit within tooltip width
    local function wrap_text(text, font, max_width)
        local lines = {}
        local words = {}
        for word in text:gmatch("%S+") do
            table.insert(words, word)
        end
        
        local current_line = ""
        love.graphics.setFont(font)
        
        for _, word in ipairs(words) do
            local test_line = (current_line == "") and word or (current_line .. " " .. word)
            local text_width = font:getWidth(test_line)
            
            if text_width <= max_width then
                current_line = test_line
            else
                if current_line ~= "" then
                    table.insert(lines, current_line)
                    current_line = word
                else
                    -- Single word is too long, break it
                    table.insert(lines, word)
                end
            end
        end
        
        if current_line ~= "" then
            table.insert(lines, current_line)
        end
        
        return lines
    end
    
    -- Calculate content based on tooltip type
    local available_width = tooltip_width - (padding * 2)
    local content_lines = {}  -- Initialize the content_lines table
    local total_content_height = 0  -- Initialize the height counter
    
    if tooltip.tooltip_type == "card" then
        local card_module = require("card")
        local card_name = card_module.get_card_name(tooltip.card)
        local card_category = card_module.get_card_category(tooltip.card)
        
        -- Title line (card name)
        content_lines.title = card_name
        total_content_height = total_content_height + line_height
        
        -- Category lines (wrapped)
        local category_lines = wrap_text(card_category, fonts.regular, available_width)
        content_lines.category = category_lines
        total_content_height = total_content_height + (#category_lines * line_height)
        
        -- Value line if available
        if tooltip.card.value then
            content_lines.value = "Value: " .. tooltip.card.value
            total_content_height = total_content_height + line_height
        end
    else
        -- Amarraco tooltip
        local name = tooltip.amarraco.name or "Unknown"
        local desc = tooltip.amarraco.description or ""
        
        -- Title line (amarraco name)
        content_lines.title = name
        total_content_height = total_content_height + line_height
        
        -- Description lines (wrapped)
        local desc_lines = wrap_text(desc, fonts.regular, available_width)
        content_lines.description = desc_lines
        total_content_height = total_content_height + (#desc_lines * line_height)
        
        -- Cost line if available
        if tooltip.amarraco.cost or tooltip.amarraco.base_cost then
            local cost = tooltip.amarraco.cost or tooltip.amarraco.base_cost
            content_lines.cost = "Cost: " .. cost .. " pesetas"
            total_content_height = total_content_height + line_height
        end
    end
    
    -- Calculate final tooltip height
    local tooltip_height = base_height + total_content_height + padding
    
    -- Advanced positioning with screen bounds checking
    local tooltip_x = tooltip.x - tooltip_width / 2  -- Center horizontally on cursor
    local tooltip_y = tooltip.y + 60  -- Position below sprite with more spacing
    
    -- Horizontal bounds checking with margin
    if tooltip_x < margin then
        tooltip_x = margin
    elseif tooltip_x + tooltip_width > screen_width - margin then
        tooltip_x = screen_width - tooltip_width - margin
    end
    
    -- Vertical bounds checking - position above sprite if tooltip goes off bottom
    if tooltip_y + tooltip_height > screen_height - margin then
        tooltip_y = tooltip.y - tooltip_height - 60  -- Position above sprite
        -- If still off-screen at top, clamp to top margin
        if tooltip_y < margin then
            tooltip_y = margin
        end
    end
    
    -- Draw tooltip background with border (scaled)
    love.graphics.setColor(0, 0, 0, 0.9)  -- Slightly more opaque for better readability
    love.graphics.rectangle("fill", tooltip_x, tooltip_y, tooltip_width, tooltip_height)
    love.graphics.setColor(1, 1, 1, 0.9)  -- White border
    love.graphics.setLineWidth(3)  -- Thicker border for high-res display
    love.graphics.rectangle("line", tooltip_x, tooltip_y, tooltip_width, tooltip_height)
    
    -- Draw content using the dynamically calculated layout
    local current_y = tooltip_y + padding
    
    if tooltip.tooltip_type == "card" then
        -- Draw card tooltip with dynamic content
        
        -- Draw title (card name)
        love.graphics.setColor(1, 1, 1)
        love.graphics.setFont(fonts.pixel_small)  -- Larger font (72px)
        love.graphics.print(content_lines.title, tooltip_x + padding, current_y)
        current_y = current_y + line_height
        
        -- Draw category lines (wrapped)
        love.graphics.setColor(0.8, 0.8, 1)
        love.graphics.setFont(fonts.regular)  -- Medium font (56px)
        for _, line in ipairs(content_lines.category) do
            love.graphics.print(line, tooltip_x + padding, current_y)
            current_y = current_y + line_height
        end
        
        -- Draw value if available
        if content_lines.value then
            love.graphics.setColor(1, 1, 0.8)
            love.graphics.setFont(fonts.regular)
            love.graphics.print(content_lines.value, tooltip_x + padding, current_y)
        end
    else
        -- Draw amarraco tooltip with dynamic content
        
        -- Draw title (amarraco name)
        love.graphics.setColor(1, 1, 1)
        love.graphics.setFont(fonts.pixel_small)  -- Larger font (72px)
        love.graphics.print(content_lines.title, tooltip_x + padding, current_y)
        current_y = current_y + line_height
        
        -- Draw description lines (wrapped)
        love.graphics.setColor(0.9, 0.9, 0.9)
        love.graphics.setFont(fonts.regular)  -- Medium font (56px)
        for _, line in ipairs(content_lines.description) do
            love.graphics.print(line, tooltip_x + padding, current_y)
            current_y = current_y + line_height
        end
        
        -- Draw cost if available
        if content_lines.cost then
            love.graphics.setColor(1, 1, 0)  -- Yellow for cost
            love.graphics.setFont(fonts.regular)
            love.graphics.print(content_lines.cost, tooltip_x + padding, current_y)
        end
    end
end

-- Draw HP bar
function ui.draw_hp_bar(x, y, width, height, current_hp, max_hp, fill_color, bg_color)
    -- Background (empty bar)
    love.graphics.setColor(bg_color)
    love.graphics.rectangle("fill", x, y, width, height)
    
    -- Fill (current HP)
    if current_hp > 0 and max_hp > 0 then
        local fill_width = (current_hp / max_hp) * width
        love.graphics.setColor(fill_color)
        love.graphics.rectangle("fill", x, y, fill_width, height)
    end
    
    -- Border
    love.graphics.setColor(1, 1, 1, 0.6)
    love.graphics.rectangle("line", x, y, width, height)
end

function ui.update_button_positions()
    -- Use canvas dimensions for internal UI calculations
    local canvas = require("canvas")
    local screen_width, screen_height = canvas.get_internal_dimensions()
    
    -- Position sprite buttons around the deck with equal spacing and horizontal alignment
    local deck_x = (screen_width - card.CARD_WIDTH) / 2
    local deck_y = 1906  -- Positioned 100px below player cards (player cards bottom at y=1806)
    local deck_center_y = deck_y + card.CARD_HEIGHT / 2 - ui.SPRITE_BUTTON_SIZE / 2  -- Center sprite buttons vertically with deck
    local button_spacing = 60  -- Equal space between deck and each button (scaled for iPhone canvas)
    
    -- Discard sprite button on the left of deck (equally spaced)
    buttons.discard.x = deck_x - ui.SPRITE_BUTTON_SIZE - button_spacing
    buttons.discard.y = deck_center_y
    buttons.discard.width = ui.SPRITE_BUTTON_SIZE  -- Update for click detection
    buttons.discard.height = ui.SPRITE_BUTTON_SIZE
    
    -- Play sprite button on the right of deck (equally spaced)
    buttons.play.x = deck_x + card.CARD_WIDTH + button_spacing
    buttons.play.y = deck_center_y
    buttons.play.width = ui.SPRITE_BUTTON_SIZE  -- Update for click detection
    buttons.play.height = ui.SPRITE_BUTTON_SIZE
    
end

function ui.get_hand_y_position()
    return 1400  -- Player hand positioned below AI cards with extra separation
end

function ui.draw_title_and_scores(state)
    love.graphics.setFont(fonts.pixel_small)
    love.graphics.setColor(1, 1, 1)
    
    local screen_width, _ = ui.get_screen_dimensions()
    
    -- Round number (top right corner, indented)
    local round_text = "ROUND " .. state.round
    local round_width = fonts.pixel_small:getWidth(round_text)
    love.graphics.print(round_text, screen_width - round_width - 80, 80)
    
    -- Player HP (bottom left corner, indented)
    love.graphics.setFont(fonts.regular)
    love.graphics.setColor(0.2, 1, 0.2)  -- Green for player
    local player_hp_text = "PLAYER: " .. state.player_hp .. " HP"
    love.graphics.print(player_hp_text, 80, 2500)
    
    -- Player HP bar (bottom left corner, indented)
    ui.draw_hp_bar(80, 2600, 480, 32, state.player_hp, state.base_player_hp, {0.2, 1, 0.2}, {0.2, 0.4, 0.2})
    
    -- Player hit/miss animation under player HP bar
    if state.player_hit_animation.active then
        love.graphics.setColor(state.player_hit_animation.text == "HIT!" and {0, 1, 0} or {1, 0, 0})
        love.graphics.setFont(fonts.regular)
        local text_width = fonts.regular:getWidth(state.player_hit_animation.text)
        love.graphics.print(state.player_hit_animation.text, 80 + (480 - text_width) / 2, 2650)
    end
    
    -- Pesetas (bottom left corner, below player HP, indented)
    love.graphics.setFont(fonts.regular)
    love.graphics.setColor(1, 1, 0)  -- Yellow for pesetas
    local pesetas_text = "PESETAS: " .. state.pesetas
    local pesetas_width = fonts.regular:getWidth(pesetas_text)
    love.graphics.print(pesetas_text, 80, 2750)
    
    -- AI HP (top right corner, below round, indented)
    love.graphics.setFont(fonts.regular)
    love.graphics.setColor(1, 0.2, 0.2)  -- Red for AI
    local ai_hp_text = "AI: " .. state.ai_hp .. " HP"
    local ai_hp_width = fonts.regular:getWidth(ai_hp_text)
    love.graphics.print(ai_hp_text, screen_width - ai_hp_width - 80, 180)
    
    -- AI HP bar (need to calculate AI max HP)
    local ai_max_hp = 25 + math.floor((state.round - 1) * 15)  -- Same calculation as ai.calculate_hp()
    ui.draw_hp_bar(screen_width - 480 - 80, 280, 480, 32, state.ai_hp, ai_max_hp, {1, 0.2, 0.2}, {0.4, 0.2, 0.2})
    
    -- AI hit/miss animation under AI HP bar
    if state.ai_hit_animation.active then
        love.graphics.setColor(state.ai_hit_animation.text == "HIT!" and {0, 1, 0} or {1, 0, 0})
        love.graphics.setFont(fonts.regular)
        local text_width = fonts.regular:getWidth(state.ai_hit_animation.text)
        love.graphics.print(state.ai_hit_animation.text, screen_width - 480 - 80 + (480 - text_width) / 2, 330)
    end
    
    if state.in_combat then
        -- During combat, show player's played cards breakdown
        if state.last_hand_breakdown then
            local breakdown = state.last_hand_breakdown
            
            -- Damage calculation display (fourth row) with dynamic highlighting
            local scoring_animation = require("scoring_animation")
            local formula_highlights = scoring_animation.get_formula_highlights()
            
            love.graphics.setFont(fonts.pixel_small)
            local calc_text = string.format("%d x %d = %d (%.0f%%)", 
                                           breakdown.grandes, breakdown.total_multiplier, breakdown.damage, breakdown.accuracy)
            local calc_width = fonts.pixel_small:getWidth(calc_text)
            local calc_x = 80  -- Top-left corner with indent
            
            -- Draw each component with potential highlighting
            local x_offset = 0
            
            -- Grandes (damage) component
            local grandes_text = tostring(breakdown.grandes)
            local color = formula_highlights.grandes and {1, 0.3, 0.3} or {1, 1, 1}
            love.graphics.setColor(color)
            love.graphics.print(grandes_text, calc_x + x_offset, 80)
            x_offset = x_offset + fonts.pixel_small:getWidth(grandes_text)
            
            -- " x " separator
            love.graphics.setColor(1, 1, 1)
            love.graphics.print(" x ", calc_x + x_offset, 80)
            x_offset = x_offset + fonts.pixel_small:getWidth(" x ")
            
            -- Multiplier component
            local mult_text = tostring(breakdown.total_multiplier)
            color = formula_highlights.pares and {1, 0.3, 1} or {1, 1, 1}
            love.graphics.setColor(color)
            love.graphics.print(mult_text, calc_x + x_offset, 80)
            x_offset = x_offset + fonts.pixel_small:getWidth(mult_text)
            
            -- " = " separator
            love.graphics.setColor(1, 1, 1)
            love.graphics.print(" = ", calc_x + x_offset, 80)
            x_offset = x_offset + fonts.pixel_small:getWidth(" = ")
            
            -- Damage result
            local damage_text = tostring(breakdown.damage)
            love.graphics.setColor(1, 1, 1)
            love.graphics.print(damage_text, calc_x + x_offset, 80)
            x_offset = x_offset + fonts.pixel_small:getWidth(damage_text)
            
            -- Accuracy component
            local acc_text = string.format(" (%.0f%%)", breakdown.accuracy)
            color = formula_highlights.juego and {0.3, 1, 1} or {1, 1, 1}
            love.graphics.setColor(color)
            love.graphics.print(acc_text, calc_x + x_offset, 80)
            
            -- Shield display (fifth row)
            love.graphics.setColor(0.8, 0.8, 1)  -- Light blue for shield
            love.graphics.setFont(fonts.regular)
            local shield_text = breakdown.shield_text
            local shield_width = fonts.regular:getWidth(shield_text)
            love.graphics.print(shield_text, 80, 180)
        end
    else
        -- Show current hand scoring preview if hand exists
        if #state.hand > 0 and not state.game_over then
            -- Get scoring breakdown (no upgrades bonuses anymore)
            local breakdown = scoring.get_full_breakdown(state.hand, {})
            
            -- Apply amarracos effects
            local effects = amarracos.apply_effects(breakdown, state.hand, state.owned_amarracos, state)
            
            -- Apply effects in correct order: sum first, then multiply, perfect juego last
            local final_grandes = breakdown.grandes + effects.damage_bonus
            local base_multiplier = breakdown.multiplier * effects.multiplier_bonus
            local final_multiplier = base_multiplier
            if breakdown.is_perfect_juego and not effects.disable_perfect_juego then
                final_multiplier = base_multiplier * 3
            end
            local final_damage = final_grandes * final_multiplier
            local final_accuracy = effects.accuracy_override or breakdown.accuracy
            local final_defense = math.max(0, breakdown.defense + effects.defense_bonus)
            
            -- Damage calculation display (fourth row) - DAMAGE x MULT = FINAL_DAMAGE (accuracy %)
            love.graphics.setColor(1, 1, 1)  -- White for the full calculation
            love.graphics.setFont(fonts.pixel_small)
            local calc_text = string.format("%d x %d = %d (%.0f%%)", 
                                           final_grandes, final_multiplier, final_damage, final_accuracy)
            local calc_width = fonts.pixel_small:getWidth(calc_text)
            love.graphics.print(calc_text, 80, 80)
            
            -- Shield display (now at consistent position since amarracos summary removed)
            love.graphics.setColor(0.8, 0.8, 1)  -- Light blue for shield
            love.graphics.setFont(fonts.regular)
            local shield_text = string.format("SHIELD: %d", final_defense)
            local shield_width = fonts.regular:getWidth(shield_text)
            love.graphics.print(shield_text, 80, 180)
        end
    end
end

function ui.draw_hand_label()
    -- No label for player hand - function kept empty to avoid breaking calls
end

function ui.draw_hand(hand)
    local scoring_animation = require("scoring_animation")
    local highlighted_cards = scoring_animation.get_highlighted_cards()
    
    for i, game_card in ipairs(hand) do
        -- Check if this card should be highlighted
        local is_highlighted = false
        local highlight_type = nil
        
        for _, highlight in ipairs(highlighted_cards) do
            if highlight.index == i then
                is_highlighted = true
                highlight_type = highlight.type
                break
            end
        end
        
        -- Draw highlight effect behind card
        if is_highlighted then
            local highlight_color = {1, 1, 0.3, 0.6}  -- Default yellow
            if highlight_type == "grandes" then
                highlight_color = {1, 0.3, 0.3, 0.6}  -- Red for damage
            elseif highlight_type == "pequenas" then
                highlight_color = {0.3, 0.3, 1, 0.6}  -- Blue for defense
            elseif highlight_type == "pares" then
                highlight_color = {0.8, 0.3, 1, 0.6}  -- Purple for pairs
            elseif highlight_type == "juego" then
                highlight_color = {0.3, 1, 0.3, 0.6}  -- Green for juego
            end
            
            love.graphics.setColor(highlight_color)
            -- Draw pulsing highlight effect
            local pulse = 1.0 + 0.3 * math.sin(love.timer.getTime() * 4)
            local expand = 8 * pulse
            love.graphics.rectangle("fill", 
                game_card.x - expand/2, 
                game_card.y - expand/2, 
                card.CARD_WIDTH + expand, 
                card.CARD_HEIGHT + expand)
        end
        
        card.draw_card(game_card, fonts.regular)
    end
end

function ui.draw_scoring_animations()
    local scoring_animation = require("scoring_animation")
    
    if not scoring_animation.is_active() then
        return
    end
    
    -- DEBUG: Show current animation phase and status
    local current_phase = scoring_animation.get_phase()
    local highlighted_amarracos = scoring_animation.get_highlighted_amarracos()
    
    love.graphics.setColor(1, 1, 1, 1)
    
    local floating_texts = scoring_animation.get_floating_texts()
    
    for _, text_anim in ipairs(floating_texts) do
        local alpha = math.min(1.0, text_anim.timer / 0.5)  -- Fade in/out
        
        -- Color based on type - darker colors for better visibility over UI sprites
        local color = {0.9, 0.9, 0.9, alpha}  -- Default light gray
        if text_anim.type == "damage" then
            color = {0.8, 0.1, 0.1, alpha}  -- Dark red
        elseif text_anim.type == "defense" then
            color = {0.1, 0.1, 0.8, alpha}  -- Dark blue
        elseif text_anim.type == "multiplier" then
            color = {0.7, 0.1, 0.7, alpha}  -- Dark magenta
        elseif text_anim.type == "juego" then
            color = {0.1, 0.7, 0.1, alpha}  -- Dark green
        elseif text_anim.type == "juego_total" then
            color = {0.8, 0.8, 0.1, alpha}  -- Dark yellow
        elseif text_anim.type == "accuracy" then
            color = {0.1, 0.7, 0.7, alpha}  -- Dark cyan
        end
        
        love.graphics.setColor(color)
        love.graphics.setFont(fonts.pixel_small)
        
        -- Add slight bounce effect
        local bounce = math.sin(text_anim.timer * 8) * 2
        love.graphics.print(text_anim.text, text_anim.x, text_anim.y + bounce)
    end
end

function ui.draw_discard_area()
    -- Draw discard area sprite on the left side of screen
    local discard_sprite = card.get_discard_hand_sprite()
    if discard_sprite then
        love.graphics.setColor(1, 1, 1, 1)  -- Full white
        local _, screen_height = ui.get_screen_dimensions()
        local discard_x = -card.CARD_WIDTH - 20  -- Off screen to the left, same as animation
        local discard_y = screen_height / 2 - card.CARD_HEIGHT / 2  -- Center vertically
        -- Adjust position to show the sprite better (more visible)
        love.graphics.draw(discard_sprite, discard_x + 30, discard_y - 10, 0, 2, 2)  -- 2x scale (pixel-perfect)
    end
end

function ui.draw_deck(state)
    local screen_width, _ = ui.get_screen_dimensions()
    local deck_x = (screen_width - card.CARD_WIDTH) / 2
    local deck_y = 1906  -- Positioned 100px below player cards (player cards bottom at y=1806)
    
    -- Calculate total deck size (remaining + in hand)
    local total_deck_size = #state.deck + #state.hand
    
    -- Draw deck with simple remaining/total format
    card.draw_deck(deck_x, deck_y, #state.deck, total_deck_size, fonts.regular)
    
end

function ui.draw_amarracos(state)
    -- Show owned amarracos above AI cards area - horizontal layout with sprites and effect subtitles
    if #state.owned_amarracos > 0 then
        local screen_width, _ = ui.get_screen_dimensions()
        
        
        -- Calculate horizontal layout with pixel-perfect scaling for iPhone canvas
        local base_sprite_size = 45  -- Amarracos base size (actual sprite size)
        local display_scale = 5.0  -- 5.0x scale = 225px (bigger sprites on 4x iPhone canvas)
        local final_sprite_size = base_sprite_size * display_scale
        local sprite_spacing = 15  -- Proportionally scaled spacing for 4x canvas
        local total_width = #state.owned_amarracos * final_sprite_size + (#state.owned_amarracos - 1) * sprite_spacing
        local start_x = (screen_width - total_width) / 2
        local sprite_y = 500  -- Positioned above AI cards with more spacing
        
        local amarracos = require("amarracos")
        
        -- Get highlighted amarracos from scoring animation
        local scoring_animation = require("scoring_animation")
        local highlighted_amarracos = scoring_animation.get_highlighted_amarracos()
        
        -- Draw amarracos horizontally with dynamic scaling based on click state
        for i, amarraco in ipairs(state.owned_amarracos) do
            local x = start_x + (i - 1) * (final_sprite_size + sprite_spacing)
            
            -- Check if this amarraco is being clicked
            local is_clicked = clicked_amarraco.active and clicked_amarraco.index == i
            local current_scale = is_clicked and 5 or display_scale  -- 5x when clicked, 5x normally (integer scaling for pixel-perfect rendering)
            local current_size = base_sprite_size * current_scale
            
            -- Adjust position for centered scaling when clicked (ensure integer positioning)
            local draw_x = is_clicked and math.floor(x - (current_size - final_sprite_size) / 2) or x
            local draw_y = is_clicked and math.floor(sprite_y - (current_size - final_sprite_size) / 2) or sprite_y
            
            -- Check if this amarraco should be highlighted
            local is_highlighted = false
            for _, highlight_index in ipairs(highlighted_amarracos) do
                if highlight_index == i then
                    is_highlighted = true
                    break
                end
            end
            
            -- Draw highlight effect behind amarraco if highlighted
            if is_highlighted then
                love.graphics.setColor(1, 1, 0.3, 0.6)  -- Yellow highlight
                -- Draw pulsing highlight effect
                local pulse = 1.0 + 0.3 * math.sin(love.timer.getTime() * 4)
                local expand = 8 * pulse
                love.graphics.rectangle("fill", 
                    draw_x - expand/2, 
                    draw_y - expand/2, 
                    current_size + expand, 
                    current_size + expand)
            end
            
            -- Draw amarraco sprite with dynamic scaling
            love.graphics.setColor(1, 1, 1)
            
            local sprite = amarracos.get_sprite(amarraco.id)
            if sprite then
                love.graphics.draw(sprite, draw_x, draw_y, 0, current_scale, current_scale)
            else
                -- Fallback rectangle
                love.graphics.setColor(0.4, 0.4, 0.4)
                love.graphics.rectangle("fill", draw_x, draw_y, current_size, current_size)
                love.graphics.setColor(1, 1, 1)
                love.graphics.print(string.sub(amarraco.id, 1, 1), draw_x + 2, draw_y + 2)
            end
            
            -- Store sprite bounds for click detection (always use original size for hit detection)
            amarraco._sprite_bounds = {x = x, y = sprite_y, width = final_sprite_size, height = final_sprite_size}
            
            -- Effect subtitles removed - players can use tooltips to check amarraco effects
        end
    end
end

-- Handle mouse press on amarracos
function ui.handle_amarraco_mouse_press(x, y, state)
    if not state then return false end
    
    -- Check owned amarracos in game view (only when not in shop)
    if not state.in_shop and state.owned_amarracos and #state.owned_amarracos > 0 then
        for i, amarraco in ipairs(state.owned_amarracos) do
            if amarraco._sprite_bounds then
                local bounds = amarraco._sprite_bounds
                if x >= bounds.x and x <= bounds.x + bounds.width and
                   y >= bounds.y and y <= bounds.y + bounds.height then
                    -- Start clicking this amarraco
                    clicked_amarraco.active = true
                    clicked_amarraco.index = i
                    clicked_amarraco.x = x
                    clicked_amarraco.y = y
                    
                    -- Show tooltip immediately when clicking
                    tooltip.active = true
                    tooltip.amarraco = amarraco
                    tooltip.tooltip_type = "amarraco"
                    tooltip.x = x
                    tooltip.y = y
                    tooltip.timer = 999  -- Keep tooltip visible while clicking
                    
                    return true  -- Consumed the click
                end
            end
        end
    end
    
    -- Check shop items (only when in shop)
    if state.in_shop and state.shop_items then
        for i, item in ipairs(state.shop_items) do
            -- Check amarraco items
            if item.amarraco_data and item.amarraco_data._sprite_bounds then
                local bounds = item.amarraco_data._sprite_bounds
                if x >= bounds.x and x <= bounds.x + bounds.width and
                   y >= bounds.y and y <= bounds.y + bounds.height then
                    -- Start clicking this shop amarraco
                    clicked_amarraco.active = true
                    clicked_amarraco.index = i
                    clicked_amarraco.x = x
                    clicked_amarraco.y = y
                    
                    -- Show tooltip immediately when clicking
                    tooltip.active = true
                    tooltip.amarraco = item.amarraco_data
                    tooltip.tooltip_type = "amarraco"
                    tooltip.x = x
                    tooltip.y = y
                    tooltip.timer = 999  -- Keep tooltip visible while clicking
                    
                    return true  -- Consumed the click
                end
            end
            -- Check card items
            if item._sprite_bounds and item.card_type then
                local bounds = item._sprite_bounds
                if x >= bounds.x and x <= bounds.x + bounds.width and
                   y >= bounds.y and y <= bounds.y + bounds.height then
                    -- Start clicking this shop card
                    clicked_amarraco.active = true
                    clicked_amarraco.index = i
                    clicked_amarraco.x = x
                    clicked_amarraco.y = y
                    
                    -- Show card tooltip immediately when clicking
                    tooltip.active = true
                    tooltip.amarraco = item  -- For shop cards, use the item itself
                    tooltip.tooltip_type = "amarraco"
                    tooltip.x = x
                    tooltip.y = y
                    tooltip.timer = 999  -- Keep tooltip visible while clicking
                    
                    return true  -- Consumed the click
                end
            end
        end
    end
    
    return false  -- Click not on any amarraco or shop item
end

-- Handle mouse release 
function ui.handle_amarraco_mouse_release()
    if clicked_amarraco.active then
        -- Stop clicking and hide tooltip
        clicked_amarraco.active = false
        clicked_amarraco.index = nil
        tooltip.active = false
        tooltip.amarraco = nil
        tooltip.tooltip_type = nil
        return true  -- Was handling a click
    end
    return false  -- Wasn't handling a click
end

function ui.draw_sprite_button(sprite, x, y, enabled, scale)
    scale = scale or 10.0  -- Default to 10.0x scale for 33x33 sprites (10x scaling for better visibility)
    enabled = enabled == nil and true or enabled
    
    if sprite then
        if enabled then
            love.graphics.setColor(1, 1, 1, 1)  -- Full white when enabled
        else
            love.graphics.setColor(0.5, 0.5, 0.5, 1)  -- Grayed out when disabled
        end
        love.graphics.draw(sprite, x, y, 0, scale, scale)
    end
end

function ui.draw_button(button, enabled)
    enabled = enabled == nil and true or enabled
    
    -- Button background
    if enabled then
        love.graphics.setColor(button.color)
    else
        love.graphics.setColor(0.4, 0.4, 0.4)
    end
    love.graphics.rectangle("fill", button.x, button.y, button.width, button.height)
    
    -- Button border
    love.graphics.setColor(0.2, 0.2, 0.2)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", button.x, button.y, button.width, button.height)
    
    -- Button text
    love.graphics.setColor(0, 0, 0)
    love.graphics.setFont(fonts.regular)
    local text_width = fonts.regular:getWidth(button.text)
    local text_height = fonts.regular:getHeight()
    love.graphics.print(button.text, 
                       button.x + (button.width - text_width) / 2,
                       button.y + (button.height - text_height) / 2)
end

function ui.draw_counters(state)
    love.graphics.setFont(fonts.pixel_big)
    love.graphics.setColor(0, 0, 0)
    
    -- Draw discards remaining under discard sprite button
    local discards_text = state.discards_remaining
    local discards_width = fonts.pixel_big:getWidth(discards_text)
    love.graphics.print(discards_text, 
                       buttons.discard.x + (ui.SPRITE_BUTTON_SIZE - discards_width) / 2, 
                       buttons.discard.y + ui.SPRITE_BUTTON_SIZE + 5)
    
    -- Draw hands remaining under play sprite button
    local hands_text = state.hands_remaining
    local hands_width = fonts.pixel_big:getWidth(hands_text)
    love.graphics.print(hands_text, 
                       buttons.play.x + (ui.SPRITE_BUTTON_SIZE - hands_width) / 2, 
                       buttons.play.y + ui.SPRITE_BUTTON_SIZE + 5)
end

-- Draw AI cards (face-down during gameplay, revealed during combat)
function ui.draw_ai_cards(state)
    -- Always show AI cards during gameplay
    love.graphics.setFont(fonts.regular)
    love.graphics.setColor(1, 1, 1)
    local screen_width, _ = ui.get_screen_dimensions()
    
    if state.in_combat or (state.game_over and #state.ai_played_cards > 0) then
        local combat_state = combat.get_state()
        
        if #state.ai_played_cards > 0 then
            -- Show AI cards during combat (no label)
            local ai_cards = state.ai_played_cards
            local total_width = (#ai_cards - 1) * (card.CARD_WIDTH + card.CARD_SPACING) + card.CARD_WIDTH
            local offset_x = (screen_width - total_width) / 2
            local ai_y = 900  -- AI hand in upper area of screen
            
            
            -- Set card positions for animations
            for i, ai_card in ipairs(ai_cards) do
                local x = offset_x + (i - 1) * (card.CARD_WIDTH + card.CARD_SPACING)
                ai_card.x = x
                ai_card.y = ai_y
            end
            
            -- Draw AI cards based on reveal state
            for i, ai_card in ipairs(ai_cards) do
                local x = offset_x + (i - 1) * (card.CARD_WIDTH + card.CARD_SPACING)
                
                if state.show_ai_cards or state.game_over then
                    -- Show face up
                    local display_value = ai_card.display_value
                    if not display_value then
                        -- Generate display value if missing
                        display_value = ai_card.value == 11 and "J" or ai_card.value == 12 and "Q" or ai_card.value == 13 and "K" or tostring(ai_card.value)
                    end
                    
                    local display_card = {
                        x = x,
                        y = ai_y,
                        value = ai_card.value,
                        suit = ai_card.suit,
                        display_value = display_value,
                        selected = false,
                        card_type = ai_card.card_type,
                        team = ai_card.team,
                        pokemon = ai_card.pokemon
                    }
                    card.draw_card(display_card, fonts.regular)
                else
                    -- Show face down
                    card.draw_face_down(x, ai_y, fonts.regular)
                end
            end
        end
    else
        -- Show face-down AI cards during normal gameplay
        if #state.ai_hand > 0 then
            -- No label for AI hand
            local total_width = (4 - 1) * (card.CARD_WIDTH + card.CARD_SPACING) + card.CARD_WIDTH
            local offset_x = (screen_width - total_width) / 2
            local ai_y = 900  -- AI hand in upper area of screen
            
            for i = 1, 4 do
                local x = offset_x + (i - 1) * (card.CARD_WIDTH + card.CARD_SPACING)
                card.draw_face_down(x, ai_y, fonts.regular)
            end
        end
    end
end

function ui.draw_buttons(state)
    if not state.game_over then
        -- Draw sprite buttons for discard and play
        local discard_sprite = card.get_discard_hand_sprite()
        local play_sprite = card.get_play_hand_sprite()
        
        ui.draw_sprite_button(discard_sprite, buttons.discard.x, buttons.discard.y, state.discards_remaining > 0)
        ui.draw_sprite_button(play_sprite, buttons.play.x, buttons.play.y, true)
        
        ui.draw_counters(state)
    else
        love.graphics.setColor(1, 1, 0)
        love.graphics.setFont(fonts.pixel_big)
        local game_over_text = "GAME OVER!"
        local screen_width, _ = ui.get_screen_dimensions()
        local text_width = fonts.pixel_big:getWidth(game_over_text)
        love.graphics.print(game_over_text, (screen_width - text_width) / 2, buttons.discard.y)
        
    end
end


function ui.draw_win_animations(state)
    if not state.win_animations then return end
    
    love.graphics.setFont(fonts.regular)
    
    for _, anim in ipairs(state.win_animations) do
        -- Color based on win type
        if string.find(anim.text, "GRANDE") then
            love.graphics.setColor(1, 0.8, 0)  -- Gold for grande
        elseif string.find(anim.text, "CHICA") then
            love.graphics.setColor(0.3, 1, 0.3)  -- Green for chica
        elseif string.find(anim.text, "PARES") then
            love.graphics.setColor(1, 0.3, 1)  -- Magenta for pares
        elseif string.find(anim.text, "JUEGO") then
            love.graphics.setColor(0.3, 0.8, 1)  -- Cyan for juego
        elseif string.find(anim.text, "TEST") then
            love.graphics.setColor(1, 1, 1)  -- White for test
        else
            love.graphics.setColor(1, 1, 1)  -- Default white
        end
        
        -- Draw with bounce effect
        local final_y = anim.y + anim.bounce_offset
        local text_width = fonts.regular:getWidth(anim.text)
        love.graphics.print(anim.text, anim.x - text_width / 2, final_y)
    end
end

function ui.draw_instructions()
    love.graphics.setColor(0.7, 0.7, 0.7)
    love.graphics.setFont(fonts.regular)
    local screen_height = love.graphics.getHeight()
    local screen_width, _ = ui.get_screen_dimensions()
    
    local instruction_text = "TAP CARDS • A=ALL • D=DISCARD • P=PLAY"
    local text_width = fonts.regular:getWidth(instruction_text)
    love.graphics.print(instruction_text, (screen_width - text_width) / 2, screen_height - 20)
end

function ui.draw_card_selection(state)
    local screen_width, screen_height = ui.get_screen_dimensions()
    
    -- Title
    love.graphics.setFont(fonts.pixel_big)
    love.graphics.setColor(1, 1, 1)
    local title = ""
    if state.card_selection_type == "card_choice" then
        title = "ELIGE CARTA"
    elseif state.card_selection_type == "liga_choice" then
        title = "ELIGE CARTA LIGA"
    elseif state.card_selection_type == "pokemon_choice" then
        title = "ELIGE CARTA POKEMON"
    elseif state.card_selection_type == "booster" then
        title = "BOOSTER PACK"
    elseif state.card_selection_type == "amarracos" then
        title = "AMARRACOS"
    end
    local title_width = fonts.pixel_big:getWidth(title)
    love.graphics.print(title, (screen_width - title_width) / 2, 400)
    
    if state.card_selection_type == "amarracos" then
        -- Draw amarracos as text boxes instead of cards
        local item_height = 80
        local start_y = 600
        
        for i, amarraco in ipairs(state.card_selection_cards) do
            local y = start_y + (i - 1) * item_height
            
            -- Background for selected item
            if i == state.selected_card_index then
                love.graphics.setColor(0.3, 0.5, 0.8, 0.4)  -- Blue highlight
                love.graphics.rectangle("fill", 20, y - 5, screen_width - 40, item_height - 10)
            end
            
            -- Item name
            love.graphics.setFont(fonts.pixel_small)
            love.graphics.setColor(1, 1, 1)
            love.graphics.print(amarraco.name, 40, y)
            
            -- Item description
            love.graphics.setFont(fonts.regular)
            love.graphics.setColor(0.8, 0.8, 0.8)
            love.graphics.print(amarraco.description, 40, y + 20)
            
            -- Cost
            love.graphics.setFont(fonts.pixel_small)
            local affordable = state.pesetas >= amarraco.cost
            if affordable then
                love.graphics.setColor(1, 1, 0)  -- Yellow for affordable
            else
                love.graphics.setColor(1, 0.5, 0.5)  -- Red for unaffordable
            end
            local cost_text = amarraco.cost .. " pesetas"
            local cost_width = fonts.pixel_small:getWidth(cost_text)
            love.graphics.print(cost_text, screen_width - cost_width - 40, y + 25)
        end
    else
        -- Draw cards horizontally (existing logic)
        local card_spacing = 20
        local total_width = #state.card_selection_cards * (card.CARD_WIDTH + card_spacing) - card_spacing
        local start_x = (screen_width - total_width) / 2
        local card_y = 600
        
        for i, selection_card in ipairs(state.card_selection_cards) do
            local x = start_x + (i - 1) * (card.CARD_WIDTH + card_spacing)
            
            -- Highlight selected card
            if i == state.selected_card_index then
                love.graphics.setColor(1, 1, 0, 0.3)  -- Yellow highlight
                love.graphics.rectangle("fill", x - 5, card_y - 5, card.CARD_WIDTH + 10, card.CARD_HEIGHT + 10)
            end
            
            -- Draw card
            local display_card = {
                x = x,
                y = card_y,
                value = selection_card.value,
                suit = selection_card.suit,
                display_value = selection_card.display_value,
                selected = false,
                card_type = selection_card.card_type,
                team = selection_card.team,  -- For Liga cards
                pokemon = selection_card.pokemon  -- For Pokemon cards
            }
            card.draw_card(display_card, fonts.regular)
        end
    end
    
    -- Instructions
    love.graphics.setFont(fonts.regular)
    love.graphics.setColor(0.7, 0.7, 0.7)
    local instructions = "←→ Navegar • ENTER/SPACE Seleccionar • ESC Cancelar"
    local inst_width = fonts.regular:getWidth(instructions)
    love.graphics.print(instructions, (screen_width - inst_width) / 2, screen_height - 40)
end

function ui.draw_shop(state)
    local screen_width, screen_height = ui.get_screen_dimensions()
    
    -- Shop title
    love.graphics.setFont(fonts.pixel_big)
    love.graphics.setColor(1, 1, 1)
    local title = "QUIOSCO"
    local title_width = fonts.pixel_big:getWidth(title)
    love.graphics.print(title, (screen_width - title_width) / 2, 400)
    
    -- Pesetas display
    love.graphics.setFont(fonts.pixel_small)
    local pesetas_text = "Pesetas: " .. state.pesetas
    local pesetas_width = fonts.pixel_small:getWidth(pesetas_text)
    love.graphics.print(pesetas_text, (screen_width - pesetas_width) / 2, 450)
    
    -- Shop items - separate card items from amarracos
    local item_start_y = 520
    local current_y = item_start_y
    
    -- Separate card items from amarracos
    local card_items = {}
    local amarraco_items = {}
    
    for i, item in ipairs(state.shop_items) do
        if item.amarraco_data then
            table.insert(amarraco_items, {item = item, index = i})
        elseif item.card_type then
            table.insert(card_items, {item = item, index = i})
        end
    end
    
    -- Draw card items section (side by side)
    if #card_items > 0 then
        love.graphics.setFont(fonts.pixel_small)
        love.graphics.setColor(0.8, 1, 0.8)  -- Light green for cards
        love.graphics.print("CARTAS:", 25, current_y - 20)
        
        -- Calculate side-by-side layout using 7x scaled card dimensions (matching game cards)
        local card_width = 45 * 7   -- 315px (7x scale to match game cards)
        local card_height = 58 * 7  -- 406px (7x scale to match game cards)
        local card_spacing = 60  -- Increased spacing for larger 7x scaled cards
        local total_width = #card_items * card_width + (#card_items - 1) * card_spacing
        local start_x = (screen_width - total_width) / 2
        local card_y = current_y
        
        local card = require("card")
        
        -- Draw card items horizontally
        for idx, item_data in ipairs(card_items) do
            local item = item_data.item
            local i = item_data.index
            local x = start_x + (idx - 1) * (card_width + card_spacing)
            local cost = shop.get_item_cost(item.id, state.upgrades or {})
            local affordable = state.pesetas >= cost
            
            -- Background for selected item
            if i == state.selected_shop_item then
                love.graphics.setColor(0.5, 0.8, 0.5, 0.4)  -- Green highlight
                love.graphics.rectangle("fill", x - 5, card_y - 5, card_width + 10, card_height + 35)
            end
            
            -- Draw card back sprite with 2.0x integer scaling
            love.graphics.setColor(affordable and 1 or 0.5, affordable and 1 or 0.5, affordable and 1 or 0.5)
            local back_sprite
            if item.card_type == "liga" then
                back_sprite = card.get_liga_back_sprite()
            elseif item.card_type == "pokemon" then
                back_sprite = card.get_poke_back_sprite()
            else
                back_sprite = card.get_back_sprite()
            end
            
            if back_sprite then
                -- Use 7.0x integer scaling to match game cards
                love.graphics.draw(back_sprite, x, card_y, 0, 7.0, 7.0)  -- 7x scaling to match game cards
            else
                -- Fallback rectangle using card dimensions
                love.graphics.rectangle("fill", x, card_y, card_width, card_height)
                love.graphics.setColor(1, 1, 1)
                love.graphics.rectangle("line", x, card_y, card_width, card_height)
            end
            
            -- Store sprite bounds for tooltip click detection
            item._sprite_bounds = {x = x, y = card_y, width = card_width, height = card_height}
            
            -- Draw cost subtitle below card
            love.graphics.setFont(fonts.regular)
            local cost_color = affordable and {1, 1, 0} or {1, 0.5, 0.5}
            love.graphics.setColor(cost_color)
            local cost_text = cost .. "p"
            local text_width = fonts.regular:getWidth(cost_text)
            love.graphics.print(cost_text, x + (card_width - text_width) / 2, card_y + card_height + 3)
        end
        
        current_y = current_y + card_height + 80  -- Account for larger card height + subtitle with extra spacing
    end
    
    -- Draw amarracos section - horizontal layout with sprites and cost subtitles
    if #amarraco_items > 0 then
        love.graphics.setFont(fonts.pixel_small)
        love.graphics.setColor(1, 0.8, 0.3)  -- Gold color for amarracos
        love.graphics.print("AMARRACOS:", 25, current_y - 20)
        
        -- Calculate horizontal layout for amarracos with pixel-perfect scaling for iPhone canvas
        local base_sprite_size = 45  -- Amarracos base size
        local display_scale = 5.0  -- 5.0x scale = 225px (matching combat screen size)
        local final_sprite_size = base_sprite_size * display_scale
        local sprite_spacing = 35  -- Increased spacing for better layout with larger items
        local total_width = #amarraco_items * final_sprite_size + (#amarraco_items - 1) * sprite_spacing
        local start_x = (screen_width - total_width) / 2
        local sprite_y = current_y
        
        local amarracos = require("amarracos")
        
        -- Draw amarracos horizontally with fixed 3.5x scaling for iPhone canvas
        for idx, item_data in ipairs(amarraco_items) do
            local item = item_data.item
            local i = item_data.index
            local x = start_x + (idx - 1) * (final_sprite_size + sprite_spacing)
            local cost = item.base_cost
            local affordable = state.pesetas >= cost
            
            -- Background for selected item
            if i == state.selected_shop_item then
                love.graphics.setColor(0.8, 0.5, 0.2, 0.4)  -- Gold highlight
                love.graphics.rectangle("fill", x - 5, sprite_y - 5, final_sprite_size + 10, final_sprite_size + 35)
            end
            
            -- Draw amarraco sprite with integer scaling for pixel-perfect rendering
            love.graphics.setColor(affordable and 1 or 0.5, affordable and 1 or 0.5, affordable and 1 or 0.5)
            
            local sprite = amarracos.get_sprite(item.amarraco_data.id)
            if sprite then
                love.graphics.draw(sprite, x, sprite_y, 0, display_scale, display_scale)  -- Integer scaling for pixel-perfect rendering
            else
                -- Fallback rectangle
                love.graphics.setColor(0.4, 0.4, 0.4)
                love.graphics.rectangle("fill", x, sprite_y, final_sprite_size, final_sprite_size)
                love.graphics.setColor(affordable and 1 or 0.5, affordable and 1 or 0.5, affordable and 1 or 0.5)
                love.graphics.print(string.sub(item.amarraco_data.id, 1, 1), x + 2, sprite_y + 2)
            end
            
            -- Store sprite bounds for tooltip click detection
            item.amarraco_data._sprite_bounds = {x = x, y = sprite_y, width = final_sprite_size, height = final_sprite_size}
            
            -- Draw cost subtitle below sprite
            love.graphics.setFont(fonts.regular)
            local cost_color = affordable and {1, 1, 0} or {1, 0.5, 0.5}
            love.graphics.setColor(cost_color)
            local cost_text = cost .. "p"
            local text_width = fonts.regular:getWidth(cost_text)
            love.graphics.print(cost_text, x + (final_sprite_size - text_width) / 2, sprite_y + final_sprite_size + 3)
        end
        
        current_y = current_y + final_sprite_size + 60  -- Account for sprite height + subtitle with extra spacing
    end
    
    -- Instructions
    love.graphics.setFont(fonts.regular)
    love.graphics.setColor(0.7, 0.7, 0.7)
    local instructions = "↑↓ Navegar • ENTER/SPACE Comprar • ESC/Q Salir"
    local inst_width = fonts.regular:getWidth(instructions)
    love.graphics.print(instructions, (screen_width - inst_width) / 2, screen_height - 40)
    
    -- Current card purchases
    if state.upgrades and next(state.upgrades) then
        love.graphics.setFont(fonts.regular)
        love.graphics.setColor(0.5, 0.8, 0.5)
        local cards_text = "Cartas: " .. shop.format_card_text(state.upgrades)
        love.graphics.print(cards_text, 20, screen_height - 80)
    end
end

function ui.check_button_click(x, y, state)
    if state.game_over then
        return nil
    end
    
    if x >= buttons.discard.x and x <= buttons.discard.x + buttons.discard.width and
       y >= buttons.discard.y and y <= buttons.discard.y + buttons.discard.height and
       state.discards_remaining > 0 then
        return "discard"
    end
    
    if x >= buttons.play.x and x <= buttons.play.x + buttons.play.width and
       y >= buttons.play.y and y <= buttons.play.y + buttons.play.height then
        return "play"
    end
    
    
    return nil
end

-- Check if click is on an amarraco sprite for tooltip
function ui.check_amarraco_click(x, y, state)
    -- Check owned amarracos in game view (only when not in shop)
    if not state.in_shop and state.owned_amarracos and #state.owned_amarracos > 0 then
        for _, amarraco in ipairs(state.owned_amarracos) do
            if amarraco._sprite_bounds then
                local bounds = amarraco._sprite_bounds
                if x >= bounds.x and x <= bounds.x + bounds.width and
                   y >= bounds.y and y <= bounds.y + bounds.height then
                    ui.show_amarraco_tooltip(amarraco, x, y)
                    return true
                end
            end
        end
    end
    
    -- Check shop items (only when in shop)
    if state.in_shop and state.shop_items then
        for _, item in ipairs(state.shop_items) do
            -- Check amarraco items
            if item.amarraco_data and item.amarraco_data._sprite_bounds then
                local bounds = item.amarraco_data._sprite_bounds
                if x >= bounds.x and x <= bounds.x + bounds.width and
                   y >= bounds.y and y <= bounds.y + bounds.height then
                    ui.show_amarraco_tooltip(item.amarraco_data, x, y)
                    return true
                end
            end
            -- Check card items
            if item._sprite_bounds and item.card_type then
                local bounds = item._sprite_bounds
                if x >= bounds.x and x <= bounds.x + bounds.width and
                   y >= bounds.y and y <= bounds.y + bounds.height then
                    ui.show_card_tooltip(item, x, y)
                    return true
                end
            end
        end
    end
    
    return false
end

-- Get compact effect subtitle for amarraco display
function ui.get_amarraco_effect_subtitle(amarraco, hand, state)
    if not hand or #hand == 0 then
        return amarraco.description or ""
    end
    
    -- Return short effect descriptions for horizontal display
    if amarraco.id == "euro" then
        return "+5p/round"
    elseif amarraco.id == "dos_euro" then
        return "x2 pesetas"
    elseif amarraco.id == "tres_euro" then
        return "20% disc"
    elseif amarraco.id == "colgante_perro" then
        return "x2 hands"
    elseif amarraco.id == "pin" then
        local breakdown = scoring.get_full_breakdown(hand, {})
        return "+" .. breakdown.defense .. " dmg"
    elseif amarraco.id == "token" then
        local breakdown = scoring.get_full_breakdown(hand, {})
        local accuracy_penalty = (100 - breakdown.accuracy) / 100
        local bonus = math.floor(breakdown.grandes * accuracy_penalty * 2)
        return "+" .. bonus .. " dmg"
    elseif amarraco.id == "boton" then
        local bonus = 0
        for _, game_card in ipairs(hand) do
            if game_card.value % 2 == 0 and game_card.value <= 12 then
                bonus = bonus + game_card.value
            end
        end
        return bonus > 0 and "+" .. bonus .. " dmg" or "evens"
    elseif amarraco.id == "hebilla" then
        local bonus = 0
        for _, game_card in ipairs(hand) do
            if game_card.value % 2 == 1 and game_card.value <= 11 then
                bonus = bonus + game_card.value
            end
        end
        return bonus > 0 and "+" .. bonus .. " dmg" or "odds"
    elseif amarraco.id == "reliquia" then
        local bonus = 0
        for _, game_card in ipairs(hand) do
            if game_card.suit == "Oros" then
                local value = game_card.value > 10 and 10 or game_card.value
                bonus = bonus + value
            end
        end
        local multiplier = 1
        for _, owned in ipairs(state.owned_amarracos or {}) do
            if owned.id == "dos_euro" then
                multiplier = 2
                break
            end
        end
        return bonus > 0 and "+" .. (bonus * multiplier) .. "p" or "oros→p"
    elseif amarraco.id == "posavasos" then
        local bonus = 0
        for _, game_card in ipairs(hand) do
            if game_card.suit == "Copas" then
                local value = game_card.value > 10 and 10 or game_card.value
                bonus = bonus + value
            end
        end
        return bonus > 0 and "+" .. bonus .. " HP" or "copas→HP"
    elseif amarraco.id == "afilar" then
        local bonus = 0
        for _, game_card in ipairs(hand) do
            if game_card.suit == "Espadas" then
                local value = game_card.value > 10 and 10 or game_card.value
                bonus = bonus + value
            end
        end
        return bonus > 0 and "+" .. bonus .. " dmg" or "espadas→dmg"
    elseif amarraco.id == "madera" then
        local bonus = 0
        for _, game_card in ipairs(hand) do
            if game_card.suit == "Bastos" then
                local value = game_card.value > 10 and 10 or game_card.value
                bonus = bonus + value
            end
        end
        return bonus > 0 and "+" .. bonus .. " def" or "bastos→def"
    elseif amarraco.id == "single_peseta" then
        return "pequeña x2"
    elseif amarraco.id == "cien_peseta" then
        return "grande x2"
    elseif amarraco.id == "duro" then
        return "pares x2"
    elseif amarraco.id == "venticinco_peseta" then
        return "juego x2"
    elseif amarraco.id == "poker" then
        return "p→discards"
    elseif amarraco.id == "bola_billar" then
        local sevens_count = 0
        for _, game_card in ipairs(hand) do
            if game_card.value == 7 then
                sevens_count = sevens_count + 1
            end
        end
        return sevens_count > 0 and sevens_count .. "x 7→10" or "7s→10"
    elseif amarraco.id == "chapa" then
        return "juego→dmg"
    elseif amarraco.id == "tenis" then
        return "100% acc"
    elseif amarraco.id == "canica" then
        local suits = {}
        for _, game_card in ipairs(hand) do
            suits[game_card.suit] = true
        end
        local has_all = (suits["Oros"] and suits["Copas"] and suits["Espadas"] and suits["Bastos"])
        return has_all and "x3 mult" or "4 suits"
    end
    
    return amarraco.description or ""
end

-- Calculate individual amarraco bonus for display
function ui.get_individual_amarraco_bonus(amarraco, hand, state)
    if not hand or #hand == 0 then
        return ""
    end
    
    if amarraco.id == "euro" then
        return "+5 pesetas/round"
    elseif amarraco.id == "dos_euro" then
        return "x2 pesetas"
    elseif amarraco.id == "tres_euro" then
        return "20% shop discount"
    elseif amarraco.id == "colgante_perro" then
        return "no discards, x2 hands"
    elseif amarraco.id == "pin" then
        -- Defense becomes damage
        local breakdown = scoring.get_full_breakdown(hand, {})
        return "+" .. breakdown.defense .. " dmg"
    elseif amarraco.id == "token" then
        -- Lower accuracy = more damage - buffed formula
        local breakdown = scoring.get_full_breakdown(hand, {})
        local accuracy_penalty = (100 - breakdown.accuracy) / 100
        local bonus = math.floor(breakdown.grandes * accuracy_penalty * 2)
        return "+" .. bonus .. " dmg"
    elseif amarraco.id == "boton" then
        -- Even cards damage bonus
        local bonus = 0
        for _, game_card in ipairs(hand) do
            if game_card.value % 2 == 0 and game_card.value <= 12 then
                bonus = bonus + game_card.value
            end
        end
        return bonus > 0 and "+" .. bonus .. " dmg" or "no even cards"
    elseif amarraco.id == "hebilla" then
        -- Odd cards damage bonus
        local bonus = 0
        for _, game_card in ipairs(hand) do
            if game_card.value % 2 == 1 and game_card.value <= 11 then
                bonus = bonus + game_card.value
            end
        end
        return bonus > 0 and "+" .. bonus .. " dmg" or "no odd cards"
    elseif amarraco.id == "reliquia" then
        -- Oros cards pesetas bonus
        local bonus = 0
        for _, game_card in ipairs(hand) do
            if game_card.suit == "Oros" then
                local value = game_card.value > 10 and 10 or game_card.value
                bonus = bonus + value
            end
        end
        local multiplier = 1
        -- Check if dos_euro is owned for multiplier
        for _, owned in ipairs(state.owned_amarracos or {}) do
            if owned.id == "dos_euro" then
                multiplier = 2
                break
            end
        end
        return bonus > 0 and "+" .. (bonus * multiplier) .. " pesetas" or "no oros"
    elseif amarraco.id == "posavasos" then
        -- Copas cards HP bonus
        local bonus = 0
        for _, game_card in ipairs(hand) do
            if game_card.suit == "Copas" then
                local value = game_card.value > 10 and 10 or game_card.value
                bonus = bonus + value
            end
        end
        return bonus > 0 and "+" .. bonus .. " HP" or "no copas"
    elseif amarraco.id == "afilar" then
        -- Espadas cards damage bonus
        local bonus = 0
        for _, game_card in ipairs(hand) do
            if game_card.suit == "Espadas" then
                local value = game_card.value > 10 and 10 or game_card.value
                bonus = bonus + value
            end
        end
        return bonus > 0 and "+" .. bonus .. " dmg" or "no espadas"
    elseif amarraco.id == "madera" then
        -- Bastos cards defense bonus
        local bonus = 0
        for _, game_card in ipairs(hand) do
            if game_card.suit == "Bastos" then
                local value = game_card.value > 10 and 10 or game_card.value
                bonus = bonus + value
            end
        end
        return bonus > 0 and "+" .. bonus .. " def" or "no bastos"
    elseif amarraco.id == "single_peseta" then
        return "x2 mult (if win pequeña)"
    elseif amarraco.id == "cien_peseta" then
        return "x2 mult (if win grande)"
    elseif amarraco.id == "duro" then
        return "x2 mult (if win pares)"
    elseif amarraco.id == "venticinco_peseta" then
        return "x2 mult (if win juego)"
    elseif amarraco.id == "poker" then
        return "spend pesetas for discards"
    elseif amarraco.id == "bola_billar" then
        local sevens_count = 0
        for _, game_card in ipairs(hand) do
            if game_card.value == 7 then
                sevens_count = sevens_count + 1
            end
        end
        return sevens_count > 0 and sevens_count .. " sevens → 10" or "no sevens"
    elseif amarraco.id == "chapa" then
        return "juego → damage (if win)"
    elseif amarraco.id == "tenis" then
        return "100% accuracy, no x3"
    elseif amarraco.id == "canica" then
        local suits = {}
        for _, game_card in ipairs(hand) do
            suits[game_card.suit] = true
        end
        local has_all = (suits["Oros"] and suits["Copas"] and suits["Espadas"] and suits["Bastos"])
        return has_all and "x3 mult (all suits)" or "need all suits"
    end
    
    return ""
end

return ui