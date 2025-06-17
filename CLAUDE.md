# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a 2D action game called "Sideskate" built with Godot 4.4. The game uses a faked Y-axis system to simulate depth while remaining purely 2D, which is a common technique in 2.5D games.

## Key Architecture

### Scene Structure
- **Main.tscn**: Root 2D scene containing the player, enemies, and environment
- **Player.tscn**: Player character with Sprite2D, CollisionShape2D, and Camera2D
- **Enemy.tscn**: Basic enemy character using 2D nodes (expandable for AI)

### Faked Y-Axis System
The game simulates depth using a clever 2D technique:
- **Horizontal movement**: Real X-axis movement for left/right
- **Depth movement**: Real Y-axis movement for up/down (simulating depth)
- **Jump/height**: Faked using `fake_y` variable that offsets the sprite position
- **Visual depth sorting**: Uses `z_index` based on Y position (lower = in front)

### Movement System
- Player moves horizontally (X) and in depth (Y position)
- Jumping is simulated by modifying `fake_y` and subtracting from position.y
- Gravity affects `fake_y` for realistic jump physics
- Camera follows player using Camera2D

### Input Mapping
Defined in project.godot:
- Movement: WASD keys + Arrow keys
- Jump: Spacebar
- Uses `Input.get_axis()` for horizontal and depth input

### Physics
- Uses CharacterBody2D with move_and_slide() for horizontal movement only
- Custom gravity system for faked Y-axis jumping (980.0 pixels/sec²)
- Depth boundaries clamped between Y positions 50-400
- Z-index sorting for proper visual layering

## Development Commands

Since this is a Godot project, development is primarily done through the Godot Editor.

### Running the Game
Open the project in Godot Editor and press F5 or use the play button.

### Code Structure
- **Player.gd**: Handles 2D movement with faked Y-axis for jumping and depth
- **Enemy.gd**: Basic 2D enemy class with faked Y-axis support
- Scripts use @export variables for easy tweaking in the Godot Editor
- PlaceholderTexture2D used for simple colored rectangles as sprites

## File Naming Conventions
- Scene files: PascalCase.tscn (Player.tscn, Enemy.tscn)
- Script files: PascalCase.gd (Player.gd, Enemy.gd)
- Main scene: Main.tscn (set as main scene in project settings)
