-- Menu system for Spanish Deck Card Game
local shop = require("shop")
local card = require("card")

local menu = {}

-- Menu states
menu.STATE_NONE = "none"
menu.STATE_ROUND_VICTORY = "round_victory"
menu.STATE_SHOP = "shop"
menu.STATE_CARD_CHOICE = "card_choice"
menu.STATE_BOOSTER = "booster"

local menu_state = {
    current_state = menu.STATE_NONE,
    pesetas_earned = 0,
    card_choices = {},
    selected_card_index = 1,
    shop_scroll = 0,
    max_items_visible = 5,  -- Updated to show all 5 new shop items
    booster_cards = {},
    pesetas = 0,
    next_round = 1,
    current_upgrades = {}
}

-- Show round victory menu
function menu.show_round_victory(pesetas_earned, round, max_score)
    menu_state.current_state = menu.STATE_ROUND_VICTORY
    menu_state.pesetas_earned = pesetas_earned
    menu_state.round = round
    menu_state.max_score = max_score
end

-- Show shop menu
function menu.show_shop(pesetas, next_round, max_score, upgrades)
    menu_state.current_state = menu.STATE_SHOP
    menu_state.shop_scroll = 0
    menu_state.pesetas = pesetas or 0
    menu_state.next_round = next_round or 1
    menu_state.max_score = max_score or 0
    menu_state.current_upgrades = upgrades or {}
end

-- Show card choice menu
function menu.show_card_choice()
    menu_state.current_state = menu.STATE_CARD_CHOICE
    menu_state.card_choices = shop.get_card_choices()
    menu_state.selected_card_index = 1
end

-- Show booster pack menu
function menu.show_booster()
    menu_state.current_state = menu.STATE_BOOSTER
    menu_state.booster_cards = shop.get_booster_pack()
    menu_state.selected_card_index = 1
end

-- Hide all menus
function menu.hide()
    menu_state.current_state = menu.STATE_NONE
end

-- Get current menu state
function menu.get_state()
    return menu_state.current_state
end

-- Handle menu input
function menu.handle_input(key, game_state_obj)
    if menu_state.current_state == menu.STATE_ROUND_VICTORY then
        if key == "p" then
            menu.hide()
            return "continue"
        elseif key == "d" then
            menu.show_shop()
            return "shop"
        end
        
    elseif menu_state.current_state == menu.STATE_SHOP then
        if key == "escape" or key == "q" then
            menu.hide()
            return "continue"
        -- No scrolling needed for 3 items
        else
            -- Number keys for purchasing
            local num = tonumber(key)
            if num and num >= 1 and num <= menu_state.max_items_visible then
                local item_index = menu_state.shop_scroll + num
                if item_index <= #shop.ITEMS then
                    local item = shop.ITEMS[item_index]
                    local state = game_state_obj.get()
                    local cost = shop.get_item_cost(item.id, state.upgrades)
                    
                    if state.pesetas >= cost then
                        -- Purchase item
                        local result = shop.apply_upgrade(item.id, state, state.upgrades)
                        state.pesetas = state.pesetas - cost
                        
                        if result == "choose_card" then
                            menu.show_card_choice()
                            return "card_choice"
                        end
                        return "purchased"
                    else
                        return "insufficient_funds"
                    end
                end
            end
        end
        
    elseif menu_state.current_state == menu.STATE_CARD_CHOICE then
        if key == "1" then
            menu_state.selected_card_index = 1
        elseif key == "2" then
            menu_state.selected_card_index = 2
        elseif key == "3" then
            menu_state.selected_card_index = 3
        elseif key == "return" or key == "space" then
            local chosen_card = menu_state.card_choices[menu_state.selected_card_index]
            menu.show_shop()  -- Return to shop after card selection
            return "card_chosen", chosen_card
        end
    end
    
    return nil
end

-- Draw round victory menu
function menu.draw_round_victory(fonts, pesetas, max_score)
    local screen_width = love.graphics.getWidth()
    local screen_height = love.graphics.getHeight()
    
    -- Background overlay
    love.graphics.setColor(0, 0, 0, 0.8)
    love.graphics.rectangle("fill", 0, 0, screen_width, screen_height)
    
    -- Menu content
    love.graphics.setColor(1, 1, 1)
    love.graphics.setFont(fonts.pixel_big)
    
    local y_offset = 150
    
    -- Title
    local title = "ROUND COMPLETE!"
    local title_width = fonts.pixel_big:getWidth(title)
    love.graphics.print(title, (screen_width - title_width) / 2, y_offset)
    
    -- Stats
    love.graphics.setFont(fonts.pixel_small)
    y_offset = y_offset + 60
    
    local pesetas_text = "PESETAS EARNED: " .. menu_state.pesetas_earned
    local pesetas_width = fonts.pixel_small:getWidth(pesetas_text)
    love.graphics.print(pesetas_text, (screen_width - pesetas_width) / 2, y_offset)
    
    y_offset = y_offset + 40
    local total_text = "TOTAL PESETAS: " .. pesetas
    local total_width = fonts.pixel_small:getWidth(total_text)
    love.graphics.print(total_text, (screen_width - total_width) / 2, y_offset)
    
    y_offset = y_offset + 40
    local round_text = "NEXT ROUND: " .. menu_state.round
    local round_width = fonts.pixel_small:getWidth(round_text)
    love.graphics.print(round_text, (screen_width - round_width) / 2, y_offset)
    
    y_offset = y_offset + 40
    local max_text = "MAX ROUND: " .. max_score
    local max_width = fonts.pixel_small:getWidth(max_text)
    love.graphics.print(max_text, (screen_width - max_width) / 2, y_offset)
    
    -- Options
    y_offset = y_offset + 80
    love.graphics.setColor(0.7, 1, 0.7)
    local continue_text = "P - CONTINUE TO NEXT ROUND"
    local continue_width = fonts.pixel_small:getWidth(continue_text)
    love.graphics.print(continue_text, (screen_width - continue_width) / 2, y_offset)
    
    y_offset = y_offset + 40
    love.graphics.setColor(1, 1, 0.7)
    local shop_text = "D - VISIT SHOP"
    local shop_width = fonts.pixel_small:getWidth(shop_text)
    love.graphics.print(shop_text, (screen_width - shop_width) / 2, y_offset)
end

-- Draw shop menu
function menu.draw_shop(fonts, pesetas, upgrades)
    local screen_width = love.graphics.getWidth()
    local screen_height = love.graphics.getHeight()
    
    -- Background overlay
    love.graphics.setColor(0, 0, 0, 0.9)
    love.graphics.rectangle("fill", 0, 0, screen_width, screen_height)
    
    -- Title
    love.graphics.setColor(1, 1, 1)
    love.graphics.setFont(fonts.pixel_big)
    local title = "SHOP"
    local title_width = fonts.pixel_big:getWidth(title)
    love.graphics.print(title, (screen_width - title_width) / 2, 20)
    
    -- Pesetas
    love.graphics.setFont(fonts.pixel_small)
    local pesetas_text = "PESETAS: " .. pesetas
    local pesetas_width = fonts.pixel_small:getWidth(pesetas_text)
    love.graphics.print(pesetas_text, (screen_width - pesetas_width) / 2, 60)
    
    -- Shop items
    love.graphics.setFont(fonts.regular)
    local y_start = 120
    local item_height = 80
    
    for i = 1, #shop.ITEMS do
        local item = shop.ITEMS[i]
        local cost = shop.get_item_cost(item.id, upgrades)
        local can_afford = pesetas >= cost
        local times_bought = upgrades[item.id] or 0
        
        local y_pos = y_start + (i - 1) * item_height
        
        -- Item background
        if can_afford then
            love.graphics.setColor(0.2, 0.4, 0.2)
        else
            love.graphics.setColor(0.4, 0.2, 0.2)
        end
        love.graphics.rectangle("fill", 20, y_pos, screen_width - 40, item_height - 5)
        
        -- Item text
        if can_afford then
            love.graphics.setColor(1, 1, 1)
        else
            love.graphics.setColor(0.6, 0.6, 0.6)
        end
        
        local item_text = string.format("%d. %s - %d pesetas", i, item.name, cost)
        love.graphics.print(item_text, 30, y_pos + 5)
        
        local desc_text = item.description
        love.graphics.print(desc_text, 30, y_pos + 25)
        
        -- Show how many times bought
        if times_bought > 0 then
            love.graphics.setColor(1, 1, 0)
            local owned_text = string.format("Owned: %d", times_bought)
            love.graphics.print(owned_text, 30, y_pos + 45)
        end
    end
    
    -- Instructions
    love.graphics.setColor(0.8, 0.8, 0.8)
    love.graphics.print("Use numbers 1-3 to buy, Q to exit", 20, screen_height - 60)
    
    -- Current upgrades
    local upgrade_text = shop.format_upgrade_text(upgrades)
    love.graphics.setColor(1, 1, 0.7)
    love.graphics.print("Active: " .. upgrade_text, 20, screen_height - 40)
end

-- Draw card choice menu
function menu.draw_card_choice(fonts)
    local screen_width = love.graphics.getWidth()
    local screen_height = love.graphics.getHeight()
    
    -- Background overlay
    love.graphics.setColor(0, 0, 0, 0.8)
    love.graphics.rectangle("fill", 0, 0, screen_width, screen_height)
    
    -- Title
    love.graphics.setColor(1, 1, 1)
    love.graphics.setFont(fonts.pixel_big)
    local title = "CHOOSE A CARD"
    local title_width = fonts.pixel_big:getWidth(title)
    love.graphics.print(title, (screen_width - title_width) / 2, 100)
    
    -- Draw card choices
    local card_y = 180  -- Moved up slightly to accommodate taller cards
    local total_width = 3 * (card.CARD_WIDTH + 20) - 20
    local start_x = (screen_width - total_width) / 2
    
    for i, choice_card in ipairs(menu_state.card_choices) do
        local x = start_x + (i - 1) * (card.CARD_WIDTH + 20)
        
        -- Highlight selected card
        if i == menu_state.selected_card_index then
            love.graphics.setColor(1, 1, 0, 0.5)
            love.graphics.rectangle("fill", x - 5, card_y - 5, card.CARD_WIDTH + 10, card.CARD_HEIGHT + 10)
        end
        
        -- Draw card
        local display_card = {
            x = x,
            y = card_y,
            value = choice_card.value,
            suit = choice_card.suit,
            display_value = choice_card.display_value,
            selected = false,
            card_type = choice_card.card_type,
            team = choice_card.team,
            pokemon = choice_card.pokemon
        }
        
        card.draw_card(display_card, fonts.regular)
        
        -- Card number
        love.graphics.setColor(1, 1, 1)
        love.graphics.setFont(fonts.pixel_small)
        local num_text = tostring(i)
        local num_width = fonts.pixel_small:getWidth(num_text)
        love.graphics.print(num_text, x + (card.CARD_WIDTH - num_width) / 2, card_y + card.CARD_HEIGHT + 10)
    end
    
    -- Instructions
    love.graphics.setColor(0.8, 0.8, 0.8)
    love.graphics.setFont(fonts.regular)
    local inst_text = "Use 1-3 to select, ENTER to confirm"
    local inst_width = fonts.regular:getWidth(inst_text)
    love.graphics.print(inst_text, (screen_width - inst_width) / 2, card_y + card.CARD_HEIGHT + 50)
end

-- Get current menu data
function menu.get_data()
    return menu_state
end

return menu