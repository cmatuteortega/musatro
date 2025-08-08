-- Shop system for Spanish Deck Card Game
local card = require("card")

local shop = {}

-- Card purchase options
shop.CARD_ITEMS = {
    {
        id = "regular_cards",
        name = "Regular Cards",
        description = "Pick 1 from 3 regular Spanish cards",
        base_cost = 1,
        effect = "card_choice",
        card_type = "regular"
    },
    {
        id = "liga_cards",
        name = "Liga Cards",
        description = "Pick 1 from 3 Liga cards (all Aces)",
        base_cost = 1,
        effect = "liga_choice",
        card_type = "liga"
    },
    {
        id = "pokemon_cards",
        name = "Pokemon Cards",
        description = "Pick 1 from 3 Pokemon cards (values 1-7, 11-13)",
        base_cost = 1,
        effect = "pokemon_choice",
        card_type = "pokemon"
    },
    {
        id = "sticker_bundle",
        name = "Sticker Bundle",
        description = "Pick 1 from 3 random stickers",
        base_cost = 1,
        effect = "sticker_choice",
        card_type = "sticker"
    }
}

-- Generate shop items including amarracos and stickers
function shop.generate_shop_items(owned_amarracos, owned_stickers)
    local amarracos = require("amarracos")
    local stickers = require("stickers")
    local items = {}
    
    -- Add card purchase options
    for _, item in ipairs(shop.CARD_ITEMS) do
        table.insert(items, item)
    end
    
    -- Add 3 random available amarracos
    local available_amarracos = amarracos.get_shop_prizes(owned_amarracos)
    for _, amarraco in ipairs(available_amarracos) do
        table.insert(items, {
            id = amarraco.id,
            name = amarraco.name,
            description = amarraco.description,
            base_cost = amarraco.cost,
            cost_increase = 0,  -- Amarracos don't increase in price
            effect = "amarraco_" .. amarraco.id,
            amarraco_data = amarraco
        })
    end
    
    -- Stickers are now purchased through sticker bundle (card-sized option)
    
    return items
end

-- Calculate pesetas earned from round performance
function shop.calculate_pesetas(discards_remaining, hands_remaining, hp_remaining)
    local pesetas = 0
    
    -- 2 pesetas per unused discard
    pesetas = pesetas + (discards_remaining * 2)
    
    -- 3 pesetas per unused hand
    pesetas = pesetas + (hands_remaining * 3)
    
    -- Half HP as pesetas
    pesetas = pesetas + math.floor(hp_remaining / 2)
    
    return pesetas
end

-- Get current cost of an item based on how many times it's been bought
function shop.get_item_cost(item_id, upgrades)
    -- Check card items first
    for _, item in ipairs(shop.CARD_ITEMS) do
        if item.id == item_id then
            return item.base_cost  -- Card items have fixed cost
        end
    end
    return 999  -- Item not found
end

-- Get three random cards for the "card choice" shop option
function shop.get_card_choices()
    local suits = {"Oros", "Espadas", "Bastos", "Copas"}
    local values = {1, 2, 3, 4, 5, 6, 7, 11, 12, 13}
    
    local choices = {}
    for i = 1, 3 do
        local suit = suits[math.random(#suits)]
        local value = values[math.random(#values)]
        table.insert(choices, card.create(value, suit))
    end
    
    return choices
end

-- Get Liga card choices (3 random Liga cards)
function shop.get_liga_choices()
    return card.get_liga_choices()
end

-- Get Pokemon card choices (3 random Pokemon cards)
function shop.get_pokemon_choices()
    return card.get_pokemon_choices()
end

-- Get 3 random sticker choices for sticker bundle
function shop.get_sticker_choices()
    local stickers = require("stickers")
    local all_stickers = stickers.STICKERS
    local choices = {}
    
    -- Get 3 random stickers from all available stickers
    local sticker_indices = {}
    for i = 1, #all_stickers do
        table.insert(sticker_indices, i)
    end
    
    -- Shuffle indices and pick first 3
    for i = #sticker_indices, 2, -1 do
        local j = math.random(i)
        sticker_indices[i], sticker_indices[j] = sticker_indices[j], sticker_indices[i]
    end
    
    for i = 1, math.min(3, #all_stickers) do
        table.insert(choices, all_stickers[sticker_indices[i]])
    end
    
    return choices
end

-- Apply upgrade effect to game state
function shop.apply_upgrade(item_id, game_state, upgrades)
    local item = nil
    for _, shop_item in ipairs(shop.CARD_ITEMS) do
        if shop_item.id == item_id then
            item = shop_item
            break
        end
    end
    
    if not item then
        return false
    end
    
    -- Apply immediate effects
    if item.effect == "card_choice" then
        -- Will trigger regular card selection menu
        return "card_choice"
    elseif item.effect == "liga_choice" then
        -- Will trigger Liga card selection menu
        return "liga_choice"
    elseif item.effect == "pokemon_choice" then
        -- Will trigger Pokemon card selection menu
        return "pokemon_choice"
    elseif item.effect == "sticker_choice" then
        -- Will trigger sticker selection menu
        return "sticker_choice"
    end
    
    return true
end

-- Get card purchase stats for display
function shop.get_card_stats(upgrades)
    local stats = {
        regular_cards = upgrades.regular_cards or 0,
        liga_cards = upgrades.liga_cards or 0,
        pokemon_cards = upgrades.pokemon_cards or 0
    }
    
    return stats
end

-- Format card purchase description for UI
function shop.format_card_text(upgrades)
    local stats = shop.get_card_stats(upgrades)
    local text_parts = {}
    
    if stats.regular_cards > 0 then
        table.insert(text_parts, stats.regular_cards .. " regular cards")
    end
    if stats.liga_cards > 0 then
        table.insert(text_parts, stats.liga_cards .. " Liga cards")
    end
    if stats.pokemon_cards > 0 then
        table.insert(text_parts, stats.pokemon_cards .. " Pokemon cards")
    end
    
    if #text_parts == 0 then
        return "No cards purchased"
    else
        return table.concat(text_parts, ", ")
    end
end

return shop