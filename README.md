# Sideskate

A 2D skateboarding game built with Godot 4.4 featuring an innovative "faked Y-axis" system that simulates 2.5D depth movement for realistic skateboarding mechanics. Perform tricks on obstacles in a dynamically generated skate world.

## 🛹 Game Concept

Sideskate delivers an authentic skateboarding experience using clever 2D techniques that feel three-dimensional. Skate through infinite environments, hit obstacles, and perform tricks while the world dynamically generates around you.

## 🔧 Core Innovation: Faked Y-Axis System

The game's distinctive feature enables realistic skateboarding physics in 2D:

### How It Works
- **Horizontal Movement**: Traditional X-axis for skating left/right
- **Depth Movement**: Y-axis position represents depth (toward/away from camera)
- **Height/Air Time**: Simulated using `fake_y` variable for ollies, jumps, and air tricks
- **Visual Depth Sorting**: Automatic z-index based on Y-position creates proper layering

### Skateboarding Benefits
- Realistic trick physics without 3D complexity
- Multiple skaters can occupy different "lanes" of depth
- Obstacles can be approached from various angles
- Air tricks maintain proper visual perspective

## 🛹 Skateboarding Mechanics

### Movement System
- **WASD/Arrow Keys**: Full 4-directional skating
  - **A/D**: Skate left/right along the street
  - **W/S**: Change depth lanes (toward/away from camera)
- **Spacebar**: Ollie (jump for tricks and obstacle clearing)
- **Physics**: Smooth skating with momentum and realistic stopping
- **Boundaries**: Stay within skatable areas defined by current street section

### Skater Character
- **Skating Speed**: 200 units/second horizontal
- **Lane Changes**: 150 units/second depth movement
- **Ollie Height**: 300 units with realistic gravity (-800)
- **Camera**: Dynamic following with optimal skateboarding viewpoint
- **Visual**: Clean skater representation ready for sprite replacement

### Obstacle Interaction
- **Approach Angles**: Use depth movement to line up with obstacles
- **Trick Timing**: Air time affects available trick windows
- **Landing Zones**: Precise positioning for successful landings
- **Dynamic Placement**: Obstacles spawn in logical skateable configurations

## 🏗️ Architecture

### Scene Structure
```
Skate Level (Level_1.tscn)
├── Skater (Player.tscn)
│   ├── Sprite2D (Skater representation)
│   ├── CollisionShape2D (Board/body collision)
│   └── Camera2D (Skating-optimized view)
├── GroundController (Street management)
└── Street Sections (auto-generated)
    ├── Background (Street surface)
    ├── Obstacles (Rails, ramps, etc.)
    └── AreaDetector (Section boundaries)
```

### Class Hierarchy
```
CharacterBody2D
└── DepthBoundedCharacter (street boundary management)
    └── Skater (skating physics, tricks, obstacle interaction)
```

### Key Scripts
- **Player.gd**: Core skating mechanics and faked Y-axis physics
- **GroundController.gd**: Infinite street generation and section management
- **GroundSection.gd**: Individual street section with obstacle placement
- **DepthBoundedCharacter.gd**: Base class for street boundary constraints

## 🛹 Skateboarding Features

### Trick System (Planned)
- **Ollies**: Basic air time for obstacle clearing
- **Grinds**: Rail and ledge interactions
- **Air Tricks**: Combos during flight time
- **Landing**: Skill-based successful completions
- **Scoring**: Points for trick difficulty and style

### Obstacle Types (Planned)
- **Rails**: Grindable surfaces at various heights
- **Ramps**: Launch points for air tricks
- **Stairs**: Technical skating challenges
- **Ledges**: Grind and slide opportunities
- **Gaps**: Distance challenges requiring speed and timing

### Street Generation
- **Auto-Tiling**: Infinite street sections that flow naturally
- **Obstacle Placement**: Logical positioning for skateable lines
- **Difficulty Progression**: Increasingly challenging obstacle layouts
- **Visual Variety**: Different street section themes and styles

## 🎨 Visual Design

### Skateboarding Aesthetic
- Clean, readable obstacle silhouettes
- High contrast for trick timing clarity
- Street-inspired color palette
- Focus on skateable surfaces and lines

### Placeholder Design
- **Skater**: Blue rectangle (ready for sprite replacement)
- **Street Sections**: Colored areas representing different street types
- **Obstacles**: Distinct colors for different obstacle types
- **Scalable**: Easy asset pipeline for final artwork

## 🚀 Getting Started

### Requirements
- Godot 4.4 or later
- No additional dependencies

### Controls
- **WASD** or **Arrow Keys**: Skate and change lanes
- **Spacebar**: Ollie (jump)
- **Camera**: Automatically follows skating action

### Running the Game
1. Open project in Godot Editor
2. Press **F5** or click Play button
3. Start skating and explore the infinite street

## 🔮 Technical Highlights

### Skateboarding-Specific Optimizations
- Momentum-based movement physics
- Precise trick timing windows
- Smooth lane transitions
- Obstacle approach angle calculations

### Innovative Features
- **Faked Y-Axis**: Perfect for skateboarding depth perception
- **Infinite Streets**: Endless skating with dynamic obstacle generation
- **Multi-Lane System**: Strategic depth positioning for obstacle lines
- **Trick Physics**: Realistic air time and landing mechanics

## 🎯 Development Philosophy

Sideskate proves that innovative skateboarding mechanics don't require complex 3D systems. By working within 2D constraints, the game achieves:

1. **Authentic Feel**: Real skateboarding physics and flow
2. **Performance**: Smooth 60fps skating action
3. **Accessibility**: Easy to learn, hard to master
4. **Expandability**: Foundation for complex trick systems

## 🛹 Expansion Roadmap

The modular architecture is designed for skateboarding feature expansion:

### Immediate Additions
- **Trick System**: Ollie variations and basic air tricks
- **Obstacle Library**: Rails, ramps, stairs, ledges
- **Scoring System**: Points for successful tricks
- **Landing Mechanics**: Success/failure feedback

### Advanced Features
- **Combo System**: Linking tricks for higher scores
- **Grind Physics**: Rail and ledge interaction
- **Street Variety**: Different environments and obstacle layouts
- **Customization**: Skater and board personalization
- **Challenges**: Specific trick objectives and goals

### Polish Phase
- **Skateboarding Sprites**: Authentic skater animations
- **Street Art**: Realistic urban environments
- **Sound Design**: Board sounds, ambient street audio
- **Particle Effects**: Sparks, dust, and impact feedback

## 📝 Contributing

This project demonstrates innovative 2.5D techniques specifically applied to skateboarding gameplay. The codebase prioritizes clear skateboarding mechanics and expandable trick systems.

### Focus Areas
- Trick system implementation
- Obstacle interaction physics
- Street generation algorithms
- Skateboarding feel and flow

## 🏷️ Technical Specifications

- **Engine**: Godot 4.4
- **Language**: GDScript
- **Architecture**: 2D with faked 3D depth for skateboarding
- **Physics**: Custom skating momentum and trick mechanics
- **Rendering**: 2D sprites with skateboarding-optimized camera
- **Input**: Responsive controls for precise trick timing
- **Generation**: Dynamic infinite street creation

---

*Sideskate delivers authentic skateboarding gameplay through innovative 2D techniques, proving that creative technical solutions can capture the essence of street skating without the complexity of full 3D engines.*