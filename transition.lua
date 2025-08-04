-- Transition system for Spanish Deck Card Game
local transition = {}

-- Transition types
transition.TYPE_NONE = "none"
transition.TYPE_ROUND_START = "round_start"
transition.TYPE_SHOP_ENTER = "shop_enter"
transition.TYPE_SHOP_EXIT = "shop_exit"
transition.TYPE_VICTORY = "victory"

-- Transition state
local transition_state = {
    active = false,
    type = transition.TYPE_NONE,
    timer = 0,
    duration = 2.0,
    text = "",
    subtext = "",
    callback = nil
}

-- Start a transition
function transition.start(type, text, subtext, duration, callback)
    transition_state.active = true
    transition_state.type = type
    transition_state.timer = 0
    transition_state.duration = duration or 2.0
    transition_state.text = text or ""
    transition_state.subtext = subtext or ""
    transition_state.callback = callback
end

-- Update transition
function transition.update(dt)
    if not transition_state.active then
        return false
    end
    
    transition_state.timer = transition_state.timer + dt
    
    if transition_state.timer >= transition_state.duration then
        transition_state.active = false
        
        -- Execute callback if provided
        if transition_state.callback then
            transition_state.callback()
        end
        
        return true  -- Transition finished
    end
    
    return false  -- Still transitioning
end

-- Draw transition overlay
function transition.draw(fonts)
    if not transition_state.active then
        return
    end
    
    local screen_width = love.graphics.getWidth()
    local screen_height = love.graphics.getHeight()
    
    -- Calculate fade effect
    local progress = transition_state.timer / transition_state.duration
    local alpha = 1.0
    
    if progress < 0.2 then
        -- Fade in
        alpha = progress / 0.2
    elseif progress > 0.8 then
        -- Fade out
        alpha = (1.0 - progress) / 0.2
    end
    
    -- Background overlay
    love.graphics.setColor(0, 0, 0, alpha * 0.8)
    love.graphics.rectangle("fill", 0, 0, screen_width, screen_height)
    
    -- Text content
    love.graphics.setColor(1, 1, 1, alpha)
    
    -- Main text
    if transition_state.text ~= "" then
        love.graphics.setFont(fonts.pixel_big)
        local text_width = fonts.pixel_big:getWidth(transition_state.text)
        love.graphics.print(transition_state.text, (screen_width - text_width) / 2, screen_height / 2 - 40)
    end
    
    -- Subtext
    if transition_state.subtext ~= "" then
        love.graphics.setFont(fonts.pixel_small)
        local subtext_width = fonts.pixel_small:getWidth(transition_state.subtext)
        love.graphics.print(transition_state.subtext, (screen_width - subtext_width) / 2, screen_height / 2 + 20)
    end
    
    -- Special effects based on transition type
    if transition_state.type == transition.TYPE_VICTORY then
        -- Add some victory sparkle effect
        love.graphics.setColor(1, 1, 0, alpha * 0.5)
        for i = 1, 10 do
            local x = math.random(50, screen_width - 50)
            local y = math.random(100, screen_height - 100)
            local size = math.random(2, 6)
            love.graphics.circle("fill", x, y, size)
        end
    end
end

-- Check if transition is active
function transition.is_active()
    return transition_state.active
end

-- Get transition data
function transition.get_state()
    return transition_state
end

return transition