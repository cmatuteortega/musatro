-- Stickers (Pegatinas) system for Spanish Deck Card Game
local stickers = {}

-- Sprite storage
local sticker_sprites = {}

-- Load sticker sprites
function stickers.load_sprites()
    -- Set pixel-perfect filtering for crisp sprites
    love.graphics.setDefaultFilter("nearest", "nearest")
    
    for _, sticker in ipairs(stickers.STICKERS) do
        local filepath = "sprites/stickers/" .. sticker.sprite_file
        if love.filesystem.getInfo(filepath) then
            local sprite = love.graphics.newImage(filepath)
            sprite:setFilter("nearest", "nearest")  -- Pixel-perfect scaling
            sticker_sprites[sticker.id] = sprite
        end
    end
end

-- Get sprite for a sticker
function stickers.get_sprite(sticker_id)
    return sticker_sprites[sticker_id]
end

-- Sticker definitions
stickers.STICKERS = {
    {
        id = "smiley",
        name = "Smiley",
        description = "Carta cuenta como figura en juego (+10)",
        cost = 1,
        effect_type = "face_card_juego",
        sprite_file = "smiley.png"
    },
    {
        id = "arcoiris",
        name = "Arcoíris",
        description = "Carta tiene los 4 palos a la vez",
        cost = 1,
        effect_type = "all_suits",
        sprite_file = "arcoiris.png"
    },
    {
        id = "tribal",
        name = "Tribal",
        description = "+1 mult si carta es Pequeña",
        cost = 1,
        effect_type = "pequena_mult_bonus",
        sprite_file = "tribal.png"
    },
    {
        id = "grefusa",
        name = "Grefusa",
        description = "+10 daño si carta es Grande",
        cost = 1,
        effect_type = "grande_damage_bonus",
        sprite_file = "grefusa.png"
    },
    {
        id = "corazon",
        name = "Corazón",
        description = "Carta se elimina permanentemente tras jugarse",
        cost = 1,
        effect_type = "permanent_removal",
        sprite_file = "corazon.png"
    }
}

-- Get sticker data by ID
function stickers.get_sticker_by_id(id)
    for _, sticker in ipairs(stickers.STICKERS) do
        if sticker.id == id then
            return sticker
        end
    end
    return nil
end

-- Get all 5 sticker types for shop (one of each for debugging)
function stickers.get_shop_stickers(owned_stickers)
    local shop_stickers = {}
    
    -- Add one of each sticker type for easy debugging
    for _, sticker_type in ipairs(stickers.STICKERS) do
        table.insert(shop_stickers, {
            id = sticker_type.id,
            name = sticker_type.name,
            description = sticker_type.description,
            cost = sticker_type.cost,
            effect_type = sticker_type.effect_type,
            sprite_file = sticker_type.sprite_file
        })
    end
    
    return shop_stickers
end

-- Draw sticker sprite (with fallback to placeholder)
function stickers.draw_sticker(sticker_id, x, y, scale)
    scale = scale or 1.0
    local sticker = stickers.get_sticker_by_id(sticker_id)
    if not sticker then 
        return 
    end
    
    -- Try to use sprite first
    local sprite = stickers.get_sprite(sticker_id)
    
    if sprite then
        -- Draw sprite with scaling - sprites are 20px base size
        love.graphics.setColor(1, 1, 1, 1)  -- Full white (no tint)
        love.graphics.draw(sprite, x, y, 0, scale, scale)
    else
        -- Fallback to placeholder square if sprite not available
        local size = 20 * scale  -- Base size 20px
        
        -- Draw colored square as fallback
        love.graphics.setColor(0.8, 0.8, 0.8)  -- Light gray
        love.graphics.rectangle("fill", x, y, size, size)
        
        -- Draw border
        love.graphics.setColor(1, 1, 1)
        love.graphics.rectangle("line", x, y, size, size)
        
        -- Draw first letter of name
        local letter = string.upper(string.sub(sticker.name, 1, 1))
        local font = love.graphics.getFont()
        local text_width = font:getWidth(letter)
        local text_height = font:getHeight()
        love.graphics.setColor(0, 0, 0)
        love.graphics.print(letter, x + (size - text_width) / 2, y + (size - text_height) / 2)
    end
end

-- Apply sticker effects to a card's combat contribution
function stickers.apply_card_sticker_effects(card, is_grande, is_pequena)
    local effects = {
        damage_bonus = 0,
        multiplier_bonus = 0
    }
    
    if card.attached_sticker then
        local sticker = stickers.get_sticker_by_id(card.attached_sticker)
        if sticker then
            if sticker.effect_type == "grande_damage_bonus" and is_grande then
                effects.damage_bonus = effects.damage_bonus + 10  -- Grefusa: +10 damage if card is Grande
            elseif sticker.effect_type == "pequena_mult_bonus" and is_pequena then
                effects.multiplier_bonus = effects.multiplier_bonus + 1  -- Tribal: +1 mult if card is Pequeña
            end
            -- Note: Other sticker effects will be handled in specific gameplay systems
            -- face_card_juego: handled in scoring calculation
            -- all_suits: handled in amarracos/suit counting
            -- grande_heal: handled in post-combat healing
        end
    end
    
    return effects
end

-- Check if a card can have a sticker attached (only one per card)
function stickers.can_attach_sticker(card)
    return not card.attached_sticker
end

-- Attach a sticker to a card permanently
function stickers.attach_sticker_to_card(card, sticker_id)
    if stickers.can_attach_sticker(card) then
        card.attached_sticker = sticker_id
        return true
    end
    return false
end

-- Draw sticker on card (if attached)
function stickers.draw_card_sticker(card, card_x, card_y, card_scale)
    if card.attached_sticker then
        -- Draw sticker at 1/3 height and 2/3 width from bottom-left corner
        local sticker_size = 20 * card_scale  -- Full size sticker (20px base)
        local card_width = 45 * card_scale
        local card_height = 58 * card_scale
        local sticker_x = card_x + (card_width * 2/3) - (sticker_size / 2)  -- 2/3 width, centered
        local sticker_y = card_y + (card_height * 2/3) - (sticker_size / 2)  -- 1/3 from bottom = 2/3 from top, centered
        
        stickers.draw_sticker(card.attached_sticker, sticker_x, sticker_y, card_scale)
    end
end

return stickers