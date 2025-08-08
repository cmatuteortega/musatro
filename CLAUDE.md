# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a Spanish deck card game built with LÖVE2D (Love2D) framework in Lua, inspired by Balatro. The game features turn-based combat against an AI opponent using traditional Spanish deck mechanics (40 cards: 4 suits with values 1-7, 11-Sota, 12-Caballo, 13-Rey). Players battle through progressive rounds with RPG-style HP systems, card purchases, and a shop between rounds.

## Development Commands

- **Run the game**: `love .` (requires LÖVE2D framework)
- **Check Lua syntax**: `luac -p *.lua` (use -p flag for syntax check only)
- **Debug output**: The game outputs debug info to console when run via `love .`

## Project Structure

```
/
├── main.lua             # Entry point and LÖVE2D callbacks
├── card.lua             # Card representation, deck management, Liga/Pokemon cards, and visual rendering
├── game_state.lua       # Game state management and core logic
├── ui.lua               # User interface components, tooltips, and button handling
├── scoring.lua          # Spanish card game scoring system (grandes, pequeñas, pares, juego)
├── scoring_animation.lua # Animated breakdown of scoring phases with visual effects
├── ai.lua               # AI opponent logic and "cuñao" personality system
├── combat.lua           # Turn-based combat system with phased animations
├── amarracos.lua        # Prize/artifact system with 20 different game-modifying items
├── animation.lua        # Card movement and visual effects framework
├── transition.lua       # Screen transitions and fade effects
├── menu.lua             # Menu state management (victory, shop, card selection)
├── shop.lua             # Card purchase system and pesetas economy
├── stickers.lua         # Sticker (Pegatinas) system with permanent card attachments
├── pokemon_abilities.lua # Pokemon card effects system with 40+ unique abilities
├── poke_abilities.rtf   # Spanish specifications for Pokemon abilities (source of truth)
├── canvas.lua           # High-resolution canvas system with iPhone scaling (1656x2944 internal, 414x736 window)
├── conf.lua             # LÖVE2D configuration (414x736 window, iPhone aspect ratio)
├── Minecraft.ttf        # Primary font for all UI text
└── sprites/             # PNG sprites for cards, amarracos, Liga teams, and UI
    ├── amarracos/       # 45x45px amarraco sprites with pixel-perfect scaling
    ├── liga/            # Liga team cards (12 teams) + back.png
    ├── poke/            # Pokemon card variants with team sprites
    └── ui/              # UI sprites (deck.png, play_hand.png, discard_hand.png)
```

## Architecture

The game uses a modular architecture with separate concerns:

### card.lua
- **Card Creation**: `create()`, `create_deck()` - Spanish deck with suit colors (Oros=gold, Copas=red, Espadas=blue, Bastos=green)
- **Liga Cards**: `create_liga(team)`, `get_liga_choices()` - Special Liga cards (all Aces, 12 teams)
- **Pokemon Cards**: `create_pokemon(value, pokemon)`, `get_pokemon_choices()` - Alternative card type with Pokemon themes
- **UI Sprites**: `get_deck_sprite()`, `get_play_hand_sprite()`, `get_discard_hand_sprite()` - UI element sprites
- **Deck Operations**: `shuffle_deck()`, `draw_cards()` - Fisher-Yates shuffling and card drawing
- **Visual Rendering**: `draw_card()`, `calculate_positions()` - Sprite rendering with fallback rectangles
- **Hit Detection**: `point_in_card()` - Mouse click detection for card selection
- **Selection Logic**: `toggle_selection()`, `get_selected_indices()`, `clear_selections()`
- **Sprite Management**: Loads card sprites, Liga team sprites, Pokemon sprites, and UI sprites with pixel-perfect filtering

### game_state.lua  
- **State Management**: Centralizes deck, hand, score, discards_remaining, game_over status
- **Card Purchase System**: `purchased_cards` array persists between rounds, resets on game restart
- **Game Logic**: `discard_cards()`, `play_cards()` - Core mechanics with validation and scoring
- **Input Handling**: `select_card_by_index()`, `select_card_by_position()` - Card selection via keyboard/mouse
- **Shop Integration**: Purchase flow for regular cards and Liga cards
- **AI Hand Persistence**: Shows AI's final hand face-up when player is defeated
- **Sticker Persistence**: `sticker_registry` system maintains sticker attachments across rounds and deck recreations

### stickers.lua
- **Sticker Definitions**: `STICKERS` table with id, name, description, cost, effect_type, and color
- **Shop Integration**: `get_shop_stickers()` provides 3 random stickers per shop visit (1 peseta each)
- **Visual Rendering**: `draw_sticker()` creates placeholder squares with colored backgrounds and letters
- **Attachment System**: `attach_sticker_to_card()`, `can_attach_sticker()` - One sticker per card maximum
- **Combat Effects**: `apply_card_sticker_effects()` calculates damage bonuses during combat (red sticker: +5 damage if card is Grande)
- **Card Integration**: `draw_card_sticker()` renders attached stickers in top-right corner of cards
- **Persistence Architecture**: Works with game_state registry system for permanent attachment across rounds
- **Effect Types**: Extensible system supports multiple sticker effects (currently "grande_damage_bonus")

### ui.lua
- **Interface Rendering**: `draw_title_and_scores()`, `draw_hand()`, `draw_buttons()`, `draw_shop()`, `draw_amarracos()`
- **Tooltip System**: Click-based tooltips for amarracos and shop items with 3-second auto-hide
- **Button System**: Sprite-based buttons for play/discard actions using UI sprites (33x33px at 8x scale = 264px)
- **Layout Management**: `update_button_positions()` - Responsive button placement with proper spacing
- **Pixel-Perfect Scaling**: Amarracos display at 45px (1x) in-game, 90px (2x) in shop
- **Horizontal Layouts**: Amarracos display horizontally above AI cards with effect subtitles
- **Sticker Item Area**: Bottom-right corner displays owned stickers during preview and combat phases
- **Drag-and-Drop System**: `handle_sticker_mouse_press()`, `handle_sticker_mouse_release()` - Full mouse interaction for sticker attachment
- **Shop Stickers**: Purple "PEGATINAS" section in shop with 3 purchasable stickers per visit
- **Combat Animation Colors**: Dark color scheme for better visibility over UI sprites

### scoring.lua
- **Spanish Scoring System**: `calculate_juego()`, `calculate_grandes()`, `calculate_pequenas()`, `calculate_pares()`
- **Game Mechanics**: Damage (grandes × pares multiplier), defense (10 - pequeñas), accuracy (juego/31 × 100%)
- **Special Rules**: Perfect juego (sum = 31) triples final score, face cards (Sota/Caballo/Rey) = 10 points
- **Scoring Breakdown**: Comprehensive analysis with pair detection and combat stats

### main.lua
- **LÖVE2D Integration**: `love.load()`, `love.draw()`, `love.keypressed()`, `love.mousepressed()`, `love.resize()`
- **Canvas System Integration**: Routes all rendering through high-resolution canvas system
- **Module Coordination**: Orchestrates game_state, card, scoring, ui, and animation modules
- **Mouse Coordinate Transformation**: Converts window coordinates to canvas coordinates for accurate input
- **Tooltip Integration**: Handles amarraco sprite clicks for detailed information
- **Font Management**: Loads Minecraft.ttf in three sizes (scaled 4x for iPhone canvas: 56px, 72px, 96px) and distributes to modules

### canvas.lua
- **High-Resolution Rendering**: Internal 1242x2208 resolution (iPhone aspect ratio) rendered to fixed 414x736 window
- **Fixed Scaling**: 4x integer scaling ratio (1656→414, 2944→736) for pixel-perfect iPhone-like experience
- **Mouse Coordinate Transformation**: `transform_mouse_position()` converts window clicks to canvas space
- **iPhone Aspect Ratio**: 9:16 aspect ratio optimized for mobile-style gameplay
- **Performance Optimization**: Linear filtering for smooth scaling, efficient canvas operations

### scoring_animation.lua
- **Animated Scoring**: Phased breakdown of scoring calculations with visual feedback
- **Animation Phases**: REVEAL → GRANDES → PEQUENAS → PARES → JUEGO → COMPLETE
- **Visual Effects**: Floating text animations with color coding for different score components
- **Card Highlighting**: Highlights specific cards during their scoring phase
- **Integration**: Works with combat.lua to provide smooth scoring transitions

### pokemon_abilities.lua
- **Effect Processing**: `apply_effects(breakdown, player_hand, ai_hand, game_state)` - Central function that processes all Pokemon abilities
- **Effect Types**: 25+ distinct effect types including damage bonuses, multipliers, accuracy overrides, defensive boosts
- **Conditional Logic**: Many abilities have complex conditions (highest/lowest card, suit requirements, value ranges)
- **Combat Integration**: Effects calculated during combat setup and applied to scoring breakdown
- **Post-Victory Effects**: `apply_post_victory_effects()` handles healing and round-end abilities
- **Ability Storage**: Pokemon abilities embedded in card objects with `effect_type` and descriptive text

## Stickers System (Pegatinas)

The sticker system allows players to permanently modify cards with attachable effects that persist across all future rounds.

### **Core Mechanics**
- **Purchase Cost**: 1 peseta per sticker (affordable for strategic choices)
- **Shop Availability**: 3 random stickers per shop visit
- **Attachment Limit**: One sticker per card maximum
- **Permanence**: Stickers remain attached to specific cards across all future draws
- **Consumable**: Stickers are removed from inventory when attached to cards

### **User Interface**
- **Item Area**: Bottom-right corner displays owned stickers during preview and combat phases
- **Drag-and-Drop**: Click and drag stickers from item area onto cards
- **Visual Integration**: Attached stickers appear in top-right corner of cards (20px scaled)
- **Shop Section**: Purple "PEGATINAS" section with colored placeholder squares

### **Persistence Architecture**
```lua
-- Sticker registry system maintains attachments across rounds
sticker_registry = {
    ["regular_7_Oros"] = "red_sticker",     -- Spanish cards
    ["liga_1_barca"] = "red_sticker",       -- Liga cards  
    ["pokemon_7_Jirachi"] = "red_sticker"   -- Pokemon cards
}
```

### **Current Sticker Types**
- **Red Sticker (Pegatina Roja)**: +5 damage bonus when attached card is "Grande" in combat
- **Effect Integration**: Processed during combat calculation alongside amarracos and Pokemon effects
- **Extensible Design**: System supports additional sticker types with different effect_type values

### **Technical Implementation**
- **Card Identity Keys**: Unique strings identify cards across deck recreations (`get_card_key()`)
- **Registry Functions**: `register_sticker_attachment()`, `restore_sticker_attachments()`
- **Deck Integration**: All deck creation and card drawing functions restore sticker attachments
- **Combat Integration**: Sticker effects calculated in combat.lua damage bonus system

### **Strategic Gameplay**
- **Permanent Investment**: Stickers provide lasting value throughout entire run
- **Card Selection**: Players must choose which cards deserve sticker enhancement
- **Economic Balance**: 1 peseta cost creates meaningful but accessible strategic choices
- **Visual Feedback**: Players always see their sticker investments on cards

## Shop System Architecture

### Card-Focused Economy
The shop has been redesigned to focus on card purchases rather than stat upgrades:

#### **Card Purchase Options**
- **Regular Cards**: Pick 1 from 3 random Spanish cards (8 pesetas)
- **Liga Cards**: Pick 1 from 3 random Liga team cards (12 pesetas)
- **Visual Display**: Card backs shown side-by-side with cost subtitles
- **Tooltip Support**: Click card backs for detailed purchase information

#### **Shop Layout**
```
┌─────────────────────────────────┐
│            CARTAS:              │
│  [Regular Back]  [Liga Back]    │
│      8p            12p          │
├─────────────────────────────────┤
│          AMARRACOS:             │
│  🎯  💰  ⚔️  (horizontal)      │
└─────────────────────────────────┘
```

### Liga Card System
- **12 Team Cards**: Athletic, Atleti, Barca, Betis, Espanyol, Madrid, Racing, Real, R.Sociedad, Sevilla, Valencia, Zaragoza
- **Card Properties**: All Liga cards are Aces (value = 1) with special "Liga" suit
- **Sprite Integration**: Uses team-specific sprites from `/sprites/liga/1_TEAM.png`
- **Deck Integration**: Liga cards mix with regular Spanish cards in player deck
- **Permanent Addition**: Purchased cards persist across rounds until game reset

### Pokemon Card System
- **Card Values**: Pokemon cards available for all Spanish deck values (1-7, 11-13) 
- **40+ Unique Abilities**: Each Pokemon has specific gameplay effects defined in `poke_abilities.rtf`
- **Effect Categories**: Damage bonuses, multiplier effects, accuracy modifications, defensive abilities, economic effects
- **Implementation**: `pokemon_abilities.lua` processes all Pokemon effects during combat resolution
- **Sprite Integration**: Uses Pokemon-specific sprites from `/sprites/poke/{value}_{pokemon}.png`
- **Card Creation**: `card.create_pokemon(value, pokemon)` with embedded ability data
- **Shop Integration**: Pokemon cards purchasable via card selection menu

## Amarracos System

The core progression system featuring 20 unique items that modify gameplay:

### Economy Amarracos
- **Euro**: +5 pesetas per round survived
- **Dos Euro**: x2 pesetas multiplier  
- **Tres Euro**: 20% shop discount

### Combat Modifiers
- **Pin**: Defense value added to damage (no defense)
- **Token**: Inverted accuracy formula for damage bonus
- **Colgante Perro**: No discards allowed, but double hands per round

### Card Type Bonuses
- **Boton**: +1 damage per even-valued card
- **Hebilla**: +1 damage per odd-valued card
- **Suit-specific bonuses**: Oros→pesetas, Copas→HP restoration, Espadas→damage, Bastos→defense

### Win Condition Multipliers
Various items provide x2 final score when winning specific categories (grandes, pequeñas, pares, juego)

### Special Mechanics
- **Bola Billar**: All 7s count as 10 points
- **Tenis**: Perfect 100% accuracy, disables x3 juego multiplier
- **Canica**: x3 multiplier if hand contains all 4 suits

### Visual System
- **Sprite Display**: 45x45px sprites scaled with pixel-perfect filtering
- **Horizontal Layout**: In-game and shop display amarracos in rows
- **Effect Subtitles**: Short effect descriptions below sprites
- **Tooltip Details**: Click sprites for full name, description, and cost

## Combat System Architecture

### Phased Combat Flow
```
AI_REVEAL → DAMAGE_DISPLAY → PLAYER_ATTACK → AI_DEFEAT_CHECK → AI_ATTACK → PLAYER_DEFEAT_CHECK → COMPLETE
```

- **Phase Duration**: 0.6 seconds per phase (slowed for better visibility)
- **State Transitions**: Automatic progression with visual feedback
- **Damage Application**: Occurs at specific phase boundaries
- **Early Termination**: Combat ends immediately on defeat
- **Amarracos Integration**: Effects calculated during combat setup
- **AI Hand Persistence**: AI cards remain face-up when player is defeated

### Win Condition Animations
Visual feedback system that displays "¡GRANDE!", "¡CHICA!", "¡PARES!", "¡JUEGO!" when player wins each category against AI:
- **Bounce Animation**: Sine wave movement for visual appeal
- **Color Coding**: Different colors for each win type
- **Duration**: 2-second display with bouncing text
- **Positioning**: Arranged around player hand area

## Animation Framework

### Core Animation Types
- **Card Draw**: Smooth movement from deck to hand positions
- **Card Discard**: Animated removal to designated discard area  
- **Combat Reveals**: AI cards flip/reveal with staggered timing
- **Round Transitions**: All cards clear off-screen with wave effects

### Technical Implementation
- **Easing Functions**: Smooth movement with ease-out curves
- **Animation Queuing**: Multiple simultaneous animations with callbacks
- **State Synchronization**: UI elements hide/show based on animation state
- **Performance**: Delta time handling and animation culling
- **Liga Card Support**: Animations properly pass `card_type` and `team` properties

## AI Opponent System

### "Cuñao" Personality
Spanish-themed AI with contextual phrases:
- **Victory phrases**: Boastful Spanish expressions
- **Defeat phrases**: Frustrated reactions
- **Playing phrases**: Confident declarations
- **Discarding phrases**: Tactical comments

### Strategic Behavior
- **Card Priority**: Prefers keeping pairs and high cards
- **Smart Discarding**: Removes low singles while maintaining hand strength
- **Difficulty Scaling**: HP and damage multipliers increase each round

## Game Mechanics

### Core Gameplay
- **Round System**: Exponential scoring targets starting at 50 points (target *= 1.5 each round)
- **Hand Limit**: 3 hands per round to reach the target score
- **Card Layout**: 4 cards arranged in horizontal row for touch/mouse interaction
- **Selection Effects**: Selected cards "pop out" with visual offset upward
- **Deck Management**: Game ends when deck has insufficient cards (< 4) or target not reached

### Controls
- **Touch/Click**: Tap cards to select/deselect, click sprites for tooltips
- **Keyboard**: Number keys (1-4), A=select all, D=discard, P=play, R=restart
- **Shop Navigation**: Arrow keys to navigate, Enter/Space to purchase, Escape to exit
- **Visual Feedback**: Yellow highlighting and pop-out animation for selected cards

### Scoring System (Spanish Card Game)
- **Juego**: Sum of card values (face cards = 10), displayed prominently
- **Grandes**: Highest card value (base damage)
- **Pequeñas**: Lowest card value (defense = 10 - pequeñas)
- **Pares**: Pair multipliers (4x = four of a kind, 3x = three of a kind, 2x = pair/two pair)
- **Final Score**: grandes × pares multiplier (tripled if juego = 31)
- **Perfect Juego**: Achieving exactly 31 points triggers special effects and messaging

### Progression
- **Card Collection**: Purchase regular Spanish cards and Liga team cards
- **Amarracos**: Acquire up to 5 game-modifying artifacts
- **Deck Evolution**: Purchased cards permanently added to 40-card base deck
- **Round Progression**: Face increasingly difficult AI opponents
- **Game Reset**: R key or restart button clears all progression, returns to base deck

## Sprite Asset Management

### Card Sprites
- **Base Cards**: `/sprites/{value}_{suit}.png` (45x58px)
- **Liga Cards**: `/sprites/liga/1_{team}.png` (45x58px)
- **Card Backs**: `/sprites/back.png` and `/sprites/liga/back.png`
- **Scaling**: 7.0x scale for iPhone canvas display (315x406px)

### Amarraco Sprites
- **Location**: `/sprites/amarracos/{name}.png`
- **Base Size**: 45x45px native resolution
- **Filtering**: `"nearest", "nearest"` for pixel-perfect scaling
- **Display Sizes**: 225px (5x) in-game, 450px (10x) in shop, 450px (10x) when clicked (all integer scaled for 4x iPhone canvas)
- **Fallback**: Colored rectangles with first letter if sprite missing

### UI Sprites  
- **Location**: `/sprites/ui/{name}.png`
- **Button Sprites**: 33x33px base size, scaled 4x to 132px for iPhone canvas
- **Deck Sprite**: Replaces stacked card back representation
- **Action Sprites**: play_hand.png and discard_hand.png for player actions

### Technical Requirements
- **Pixel-Perfect Scaling**: Always use integer scale ratios (1x, 2x, 3x, etc.)
- **Consistent Filtering**: All sprites use nearest-neighbor filtering
- **Sprite Bounds**: Click detection areas stored as `_sprite_bounds` properties

## UI Layout and Positioning

The game uses a strategically arranged layout on the 4x scaled canvas (1656x2944):
1. **Top-Left Corner**: Round counter (y=80) and Player/AI HP bars (y=280-730)
2. **Top-Right Corner**: Combat formula (y=80) and shield display (y=180) - indented from right edge
3. **Center Vertical Area**: 
   - **AI Cards**: y=850 (moved up 50px from 900, better centered between amarracos and deck, face-down until revealed, then face-up)
   - **Amarracos Display**: y=500 (horizontal layout, 4x scaled sprites)
   - **Player Cards**: y=1350 (moved up 50px from 1400, better centered between amarracos and deck, interactive selection with pop-out effect)
4. **Bottom Area**: y=2600 (deck centered, play/discard buttons on sides)

### Critical Position Management
- All card positions must use `ui.get_hand_y_position()` instead of hardcoded values
- AI cards positioned at consistent y=850 across all game states
- Proper spacing maintained between UI sections with 4x scaled gaps

## Font Management

The game uses Minecraft.ttf font with three sizes:
- **fonts.regular**: 14px for UI text and descriptions
- **fonts.pixel_small**: 18px for labels and small headings
- **fonts.pixel_big**: 24px for titles and emphasis

Font consistency is maintained by explicitly setting `love.graphics.setFont()` before each text rendering operation to prevent interference between UI elements.

## Important Implementation Notes

### Random Number Generation
- **Single Seed**: `math.randomseed(os.time())` called once in `main.lua` at startup
- **Deck Shuffling**: `card.shuffle_deck()` does NOT reseed to ensure AI and player get different hands
- **Separate Decks**: Player and AI use completely independent deck instances

### State Management Patterns
- **Modular Effects**: Amarracos use additive → multiplicative → special effect order
- **Animation-Driven UI**: Interface elements synchronize with animation states
- **Phase-Based Logic**: Combat uses deterministic state machine pattern
- **Input Isolation**: Mouse/keyboard input properly isolated between game states
- **Progression Separation**: Run progression (cards persist) vs game reset (everything clears)

### Visual Polish Requirements
- **Pixel-Perfect Graphics**: All sprites must use integer scaling ratios
- **Smooth Animations**: 60fps target with delta time interpolation
- **State Feedback**: Clear visual indicators for all interactive elements
- **Interactive Tooltips**: Click-and-hold amarracos to scale 2x and show tooltips (implemented in ui.lua)
- **Tooltip Consistency**: 3-second auto-hide for regular tooltips, persistent for click-and-hold
- **Responsive Layout**: UI adapts to 450x800 mobile-portrait aspect ratio

## Critical Development Patterns

### Pokemon Abilities Implementation
- **Source of Truth**: Always refer to `poke_abilities.rtf` for Pokemon ability specifications - never invent abilities
- **Effect Types**: Use descriptive `effect_type` strings in ability data for processing in `pokemon_abilities.lua`
- **Conditional Abilities**: Many abilities have complex conditions - test thoroughly with different hand compositions
- **Integration Points**: Pokemon effects integrate with combat system, scoring breakdown, and shop purchases

### Interactive UI System
- **Click-and-Hold Tooltips**: Amarracos use `ui.handle_amarraco_mouse_press()` and `ui.handle_amarraco_mouse_release()`
- **Scaling Logic**: Uses `clicked_amarraco` state tracking with integer positioning (`math.floor()` required)
- **Shop vs Combat**: Shop amarracos maintain fixed 2x scale, combat amarracos use dynamic 1x/2x scaling
- **Sprite Bounds**: All interactive sprites must store `_sprite_bounds` for accurate click detection

### Stickers System Implementation
- **Persistence Registry**: `sticker_registry` in game_state tracks attachments by unique card keys
- **Card Identity**: Uses `get_card_key(game_card)` to generate unique identifiers across card types
- **Restoration Points**: All deck creation, card drawing, and animation completion points must call `restore_sticker_attachments()`
- **Registration Requirement**: Every sticker attachment must call `register_sticker_attachment()` for persistence
- **Drag-and-Drop Integration**: Mouse handling must transform coordinates via canvas system
- **Combat Integration**: Sticker effects calculated in combat.lua alongside amarracos and Pokemon effects
- **Visual Rendering**: Attached stickers drawn in `card.draw_card()` using `stickers.draw_card_sticker()`

### Canvas System Architecture
- **Coordinate Transformation**: All mouse input must be transformed via `canvas.transform_mouse_position(x, y)`
- **Dimension Usage**: UI code should use `canvas.get_internal_dimensions()` not `love.graphics.getWidth/Height()`
- **Rendering Flow**: All drawing must occur between `canvas.begin_draw()` and `canvas.end_draw()`
- **Scaling Consistency**: UI elements and fonts scaled for 1656x2944 internal resolution (iPhone aspect ratio, 4x integer scaling), but card sprites use 7x scaling for visibility
- **Fixed Window Size**: Game window locked to 414x736 (iPhone aspect ratio) for consistent experience

### State Management Integrity  
- **Input Isolation**: Mouse/touch input properly gated by game state (shop, card selection, combat)
- **Animation Synchronization**: UI elements must sync with animation states to prevent visual conflicts
- **Card Type Persistence**: Ensure `card_type`, `team`, and `pokemon` properties preserved through all operations