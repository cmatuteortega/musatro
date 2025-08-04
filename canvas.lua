-- Canvas-based resolution scaling system
-- Allows high internal resolution with manageable window sizes

local canvas = {}

-- Canvas configuration for iPhone aspect ratio with 4x integer scaling
local INTERNAL_WIDTH = 1656    -- iPhone aspect ratio at 4x scale for integer scaling (828 * 2)
local INTERNAL_HEIGHT = 2944   -- iPhone aspect ratio (9:16) at 4x scale (1472 * 2)
local WINDOW_WIDTH = 414       -- iPhone-sized window (integer 4x scale)
local WINDOW_HEIGHT = 736      -- iPhone aspect ratio

-- Canvas objects
local game_canvas = nil
local canvas_shader = nil

-- Scaling variables
local scale_x = 1
local scale_y = 1
local offset_x = 0
local offset_y = 0

function canvas.init()
    -- Create the main game canvas at internal resolution
    game_canvas = love.graphics.newCanvas(INTERNAL_WIDTH, INTERNAL_HEIGHT)
    game_canvas:setFilter("linear", "linear") -- Smooth scaling
    
    -- Calculate scaling and centering for the canvas
    canvas.update_scale()
    
    print(string.format("Canvas initialized: Internal %dx%d, Window %dx%d", 
          INTERNAL_WIDTH, INTERNAL_HEIGHT, WINDOW_WIDTH, WINDOW_HEIGHT))
end

function canvas.update_scale()
    -- Fixed integer scaling for iPhone aspect ratio (4x scale: 1656x2944 -> 414x736)
    scale_x = 0.25  -- Integer scaling: 1656 * 0.25 = 414
    scale_y = 0.25  -- Integer scaling: 2944 * 0.25 = 736
    
    -- No offset needed since window matches aspect ratio exactly
    offset_x = 0
    offset_y = 0
end

function canvas.begin_draw()
    -- Set render target to the high-resolution canvas
    love.graphics.setCanvas(game_canvas)
    love.graphics.clear(0.1, 0.4, 0.1, 1) -- Dark green background
    
    -- Reset transformation for canvas rendering
    love.graphics.push()
    love.graphics.origin()
end

function canvas.end_draw()
    -- Restore previous state
    love.graphics.pop()
    love.graphics.setCanvas()
    
    -- Draw the canvas to the screen with scaling
    love.graphics.setColor(1, 1, 1, 1) -- White tint (no color modification)
    love.graphics.draw(game_canvas, offset_x, offset_y, 0, scale_x, scale_y)
end

-- Get internal resolution for UI calculations
function canvas.get_internal_dimensions()
    return INTERNAL_WIDTH, INTERNAL_HEIGHT
end

-- Get window dimensions
function canvas.get_window_dimensions()
    return WINDOW_WIDTH, WINDOW_HEIGHT
end

-- Convert mouse coordinates from window space to canvas space
function canvas.transform_mouse_position(x, y)
    -- Adjust for canvas offset and scaling
    local canvas_x = (x - offset_x) / scale_x
    local canvas_y = (y - offset_y) / scale_y
    
    -- Clamp to canvas bounds
    canvas_x = math.max(0, math.min(INTERNAL_WIDTH, canvas_x))
    canvas_y = math.max(0, math.min(INTERNAL_HEIGHT, canvas_y))
    
    return canvas_x, canvas_y
end

-- Check if mouse is within canvas bounds
function canvas.is_mouse_in_canvas(x, y)
    local canvas_x, canvas_y = canvas.transform_mouse_position(x, y)
    return canvas_x >= 0 and canvas_x <= INTERNAL_WIDTH and 
           canvas_y >= 0 and canvas_y <= INTERNAL_HEIGHT
end

-- Window resize handler
function canvas.on_resize(w, h)
    canvas.update_scale()
    print(string.format("Canvas scale updated: %.2fx%.2f, offset: %.1f,%.1f", 
          scale_x, scale_y, offset_x, offset_y))
end

-- Get scale factors for external use
function canvas.get_scale()
    return scale_x, scale_y
end

-- Get offsets for external use  
function canvas.get_offset()
    return offset_x, offset_y
end

return canvas