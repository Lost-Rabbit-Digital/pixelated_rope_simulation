# PixelRope Documentation

![PixelRope Banner](https://img.shields.io/badge/Godot-4.4-blue) ![License](https://img.shields.io/badge/license-MPL--2.0-green) ![Version](https://img.shields.io/badge/version-1.0.0-orange)

## Table of Contents

1. [Introduction](#introduction)
2. [Getting Started](#getting-started)
    - [Installation](#installation)
    - [Quick Setup](#quick-setup)
    - [Basic Usage](#basic-usage)
3. [Core Components](#core-components)
    - [PixelRope Node](#pixelrope-node)
    - [RopeAnchor Component](#ropeanchor-component)
    - [LineAlgorithms](#linealgorithms)
4. [Configuration](#configuration)
    - [Rope Properties](#rope-properties)
    - [Pixelation Properties](#pixelation-properties)
    - [Physics Properties](#physics-properties)
    - [Anchor Properties](#anchor-properties)
    - [Dynamic Anchor Settings](#dynamic-anchor-settings)
    - [Collision Properties](#collision-properties)
    - [Interaction Properties](#interaction-properties)
5. [API Reference](#api-reference)
    - [Signals](#signals)
    - [Methods](#methods)
    - [Enums](#enums)
6. [Advanced Usage](#advanced-usage)
    - [Physics Simulation](#physics-simulation)
    - [Interaction System](#interaction-system)
    - [Custom Line Rendering](#custom-line-rendering)
    - [Collision Detection](#collision-detection)
7. [Common Patterns](#common-patterns)
    - [Grappling Hook](#grappling-hook)
    - [Dynamic Bridge](#dynamic-bridge)
    - [Pulleys and Winches](#pulleys-and-winches)
    - [Dynamic Lighting](#dynamic-lighting)
8. [Performance Optimization](#performance-optimization)
9. [Extending PixelRope](#extending-pixelrope)
10. [Troubleshooting](#troubleshooting)
11. [Contributing](#contributing)
12. [License](#license)
13. [Attributions](#attributions)

## Introduction

PixelRope is a high-performance, pixel-perfect rope simulation plugin for Godot 4.4. It provides a complete solution for creating physically simulated ropes with authentic pixelated rendering, making it ideal for retro-style games, platformers, puzzles, and any project requiring interactive rope mechanics.

Key features include:
- Pixel-perfect rendering with multiple line algorithms (Bresenham and DDA)
- Realistic physics with verlet integration and customizable properties
- Entity Component System (ECS) friendly design for optimal performance
- Full interaction support with grabbing, breaking, and dynamic anchors
- Visual customization with adjustable pixel size, spacing, and colors
- Collision detection with environment objects

## Getting Started

### Installation

#### Method 1: Godot AssetLib (Recommended)

1. Open your Godot project
2. Navigate to AssetLib tab in the top center of the editor
3. Search for "PixelRope"
4. Click on the plugin and press "Download"
5. In the installation dialog, click "Install"
6. Enable the plugin in Project Settings > Plugins

#### Method 2: Manual Installation

1. Download the plugin from the [GitHub repository](https://github.com/Lost-Rabbit-Digital/pixelated_rope_simulation)
2. Extract the `addons/pixel_rope` folder into your project's `addons` directory
3. Enable the plugin in Project Settings > Plugins

### Quick Setup

After installation, you can add a `PixelRope` node to your scene through the editor:

1. Right-click in the Scene panel and select "Add Child Node"
2. Search for "PixelRope" and select it
3. The rope will appear with default anchors that you can position
4. Adjust properties in the Inspector panel

Or create one through code:

```gdscript
# Adding a rope is as simple as:
var rope = PixelRope.new()
rope.segment_count = 20
rope.pixel_size = 4
rope.rope_color = Color(0.8, 0.6, 0.2)
add_child(rope)
```

### Basic Usage

Once you have added a PixelRope node to your scene, you'll need to:

1. Position the start and end anchors (either in the editor or through code)
2. Configure the rope properties according to your needs
3. Run the scene to see the physics in action

A minimal setup through code looks like:

```gdscript
# Create a new rope
var rope = PixelRope.new()

# Configure basic properties
rope.segment_count = 50
rope.segment_length = 5.0
rope.pixel_size = 4
rope.rope_color = Color(0.8, 0.6, 0.2)

# Add to scene
add_child(rope)

# Position the anchors
rope.start_position = Vector2(100, 100)
rope.end_position = Vector2(300, 300)
```

## Core Components

### PixelRope Node

The `PixelRope` node is the main component that handles all rope functionality. It combines physics simulation, rendering, and interaction capabilities in a single node. Each rope manages its own internal state, physics calculations, and pixel rendering.

### RopeAnchor Component

The `RopeAnchor` is a specialized Node2D that serves as an attachment point for the rope. Each rope has a start and end anchor by default. These anchors can be:
- Static (fixed in place)
- Dynamic (affected by physics and forces)
- Interactive (can be dragged by the player)

### LineAlgorithms

The `LineAlgorithms` class provides utility functions for rendering pixel-perfect lines. It implements two core algorithms:

1. **Bresenham's Algorithm**: An integer-based approach that's computationally efficient and produces perfectly aligned pixel patterns.
2. **DDA (Digital Differential Analyzer)**: A floating-point algorithm that produces smoother results for diagonal lines.

## Configuration

### Rope Properties

| Property | Type | Description |
|----------|------|-------------|
| `segment_count` | int | Number of segments in the rope (affects resolution) |
| `segment_length` | float | Length of each segment (affects total rope length) |
| `rope_color` | Color | Color of the rope |

### Pixelation Properties

| Property | Type | Description |
|----------|------|-------------|
| `pixel_size` | int | Size of each rendered pixel |
| `pixel_spacing` | int | Optional spacing between pixels for dotted line effect |
| `line_algorithm` | enum | Rendering algorithm (Bresenham or DDA) |

### Physics Properties

| Property | Type | Description |
|----------|------|-------------|
| `gravity` | Vector2 | Force applied to rope segments |
| `damping` | float | Velocity dampening (lower = more bouncy) |
| `iterations` | int | Physics iteration count (higher = more stable) |
| `max_stretch_factor` | float | Maximum stretch before rope breaks |

### Anchor Properties

| Property | Type | Description |
|----------|------|-------------|
| `start_position` | Vector2 | Position of the starting anchor |
| `end_position` | Vector2 | Position of the ending anchor |
| `anchor_radius` | float | Size of the anchor's collision area |
| `anchor_debug_color` | Color | Color for visualizing anchors in editor |
| `show_anchor_debug` | bool | Whether to display anchor visualization |

### Dynamic Anchor Settings

| Property | Type | Description |
|----------|------|-------------|
| `dynamic_start_anchor` | bool | Makes start anchor react to physics |
| `dynamic_end_anchor` | bool | Makes end anchor react to physics |
| `anchor_mass` | float | How heavily anchors are affected by forces |
| `anchor_jitter` | float | Adds random movement to dynamic anchors |
| `anchor_gravity` | Vector2 | Optional custom gravity for anchors |

### Collision Properties

| Property | Type | Description |
|----------|------|-------------|
| `enable_collisions` | bool | Enable collisions with environment |
| `collision_mask` | int (mask) | Physics layers to collide with |
| `collision_bounce` | float | Bounce factor when colliding (0-1) |
| `collision_friction` | float | Friction factor when sliding (0-1) |
| `collision_radius` | float | Size of collision detection area |
| `show_collision_debug` | bool | Visualize collision areas |

### Interaction Properties

| Property | Type | Description |
|----------|------|-------------|
| `interaction_mode` | enum | How the rope can be interacted with |
| `interaction_width` | float | Width of the interaction area |
| `grab_strength` | float | How strongly grabbed points are pulled |
| `end_anchor_draggable` | bool | Whether end anchor can be dragged |

## API Reference

### Signals

| Signal | Parameters | Description |
|--------|------------|-------------|
| `rope_broken` | none | Emitted when the rope breaks due to excessive stretching |
| `rope_grabbed` | segment_index: int | Emitted when a rope segment is grabbed |
| `rope_released` | none | Emitted when a grabbed rope segment is released |

### Methods

| Method | Parameters | Return Type | Description |
|--------|------------|-------------|-------------|
| `break_rope()` | none | void | Manually breaks the rope |
| `reset_rope()` | none | void | Resets a broken rope to its original state |
| `get_state()` | none | RopeState enum | Returns the current rope state |

### Enums

#### RopeState

```gdscript
enum RopeState {
    NORMAL,    # Rope is in normal state
    STRETCHED, # Rope is stretched (over 80% of break threshold)
    BROKEN     # Rope is broken
}
```

#### GrabMode

```gdscript
enum GrabMode {
    NONE,         # No interaction with rope
    ANCHORS_ONLY, # Only anchor points can be interacted with
    ANY_POINT     # Any point along the rope can be interacted with
}
```

#### LineAlgorithmType

```gdscript
enum LineAlgorithmType {
    BRESENHAM, # Integer-based line drawing, computationally efficient
    DDA        # Floating-point based line drawing, visually smoother
}
```

## Advanced Usage

### Physics Simulation

PixelRope uses verlet integration for physics simulation, which provides stable and realistic movement without requiring complex differential equations.

The core physics loop consists of:
1. Velocity calculation and position updates
2. Constraint solving to maintain segment lengths
3. Collision detection and response

You can fine-tune the physics with:

```gdscript
# For a more elastic rope
rope.damping = 0.99
rope.max_stretch_factor = 1.5

# For a stiffer, more stable rope
rope.iterations = 20
rope.damping = 0.8
```

### Interaction System

The interaction system allows players to grab and manipulate ropes. To configure rope interaction:

```gdscript
# Allow grabbing anywhere on the rope
rope.interaction_mode = PixelRope.GrabMode.ANY_POINT
rope.interaction_width = 20.0
rope.grab_strength = 0.8

# Connect to interaction signals
rope.rope_grabbed.connect(_on_rope_grabbed)
rope.rope_released.connect(_on_rope_released)
```

### Custom Line Rendering

PixelRope supports two line drawing algorithms that you can choose between:

```gdscript
# For maximum performance
rope.line_algorithm = LineAlgorithms.LineAlgorithmType.BRESENHAM

# For smoother visual appearance
rope.line_algorithm = LineAlgorithms.LineAlgorithmType.DDA
```

You can also customize the pixel appearance:

```gdscript
# Large, spaced-out pixels
rope.pixel_size = 8
rope.pixel_spacing = 2
```

### Collision Detection

To enable rope collision with the environment:

```gdscript
# Basic collision setup
rope.enable_collisions = true
rope.collision_mask = 1  # Collide with layer 1
rope.collision_radius = 5.0

# Customize collision response
rope.collision_bounce = 0.5  # Medium bounce
rope.collision_friction = 0.7  # High friction
```

## Common Patterns

### Grappling Hook

To create a grappling hook using PixelRope:

```gdscript
# Set up a rope for grappling
var grapple_rope = PixelRope.new()
grapple_rope.segment_count = 30
grapple_rope.dynamic_start_anchor = false  # Attached to player
grapple_rope.dynamic_end_anchor = true     # Free-moving hook end
grapple_rope.anchor_mass = 2.0             # Heavier hook
grapple_rope.enable_collisions = true      # Collide with environment
add_child(grapple_rope)

# Fire the grapple
func fire_grapple(direction: Vector2):
    grapple_rope.start_position = player.global_position
    grapple_rope.end_position = player.global_position + direction * 300
    grapple_rope.reset_rope()
```

### Dynamic Bridge

Creating a bridge that reacts to the player's weight:

```gdscript
# Set up a bridge rope
var bridge = PixelRope.new()
bridge.segment_count = 20
bridge.segment_length = 30
bridge.dynamic_start_anchor = false  # Fixed left side
bridge.dynamic_end_anchor = false    # Fixed right side
bridge.iterations = 20               # More stable
bridge.damping = 0.7                 # Less bouncy
bridge.enable_collisions = true      # Player can stand on it
add_child(bridge)

# Position the bridge
bridge.start_position = Vector2(100, 300)
bridge.end_position = Vector2(700, 300)
```

### Pulleys and Winches

Creating a winch mechanism:

```gdscript
# Create a winch rope
var winch_rope = PixelRope.new()
winch_rope.dynamic_start_anchor = false
winch_rope.dynamic_end_anchor = true
winch_rope.rope_color = Color(0.7, 0.5, 0.3)
add_child(winch_rope)

# Connect the winch to an object
winch_rope.start_position = winch_position
winch_rope.end_position = object_position

# Winch retraction function
func retract_winch(delta: float):
    var segment_count = winch_rope.segment_count
    if segment_count > 5:  # Don't make the rope too short
        winch_rope.segment_count -= 1
```

### Dynamic Lighting

Using rope as a light source (like a string of lights):

```gdscript
# Create a rope with lights
var light_rope = PixelRope.new()
light_rope.dynamic_start_anchor = false
light_rope.dynamic_end_anchor = false
add_child(light_rope)

# Add point lights along the rope
func add_lights():
    for i in range(0, light_rope.segment_count, 5):
        var light = PointLight2D.new()
        light.texture = preload("res://light_texture.png")
        light.energy = 0.8
        light.color = Color(1.0, 0.9, 0.7)
        add_child(light)
        
        # Create a function that updates light positions
        # during _process or _physics_process
```

## Performance Optimization

To ensure optimal performance with PixelRope, consider the following tips:

1. **Segment Count**: Use the minimum number of segments required for your visual needs. Higher segment counts increase physics calculations.

```gdscript
# For short ropes with simple behavior
rope.segment_count = 10

# For longer ropes needing more detail
rope.segment_count = 50
```

2. **Physics Iterations**: Balance between stability and performance.

```gdscript
# Lower iterations for background ropes
rope.iterations = 5

# Higher iterations for gameplay-critical ropes
rope.iterations = 15
```

3. **Line Algorithm**: Choose the appropriate algorithm.

```gdscript
# Bresenham is faster
rope.line_algorithm = LineAlgorithms.LineAlgorithmType.BRESENHAM

# DDA looks smoother but is more expensive
rope.line_algorithm = LineAlgorithms.LineAlgorithmType.DDA
```

4. **Collision Optimization**: Only enable collisions when necessary.

```gdscript
# For decorative ropes
rope.enable_collisions = false

# For interactive ropes
rope.enable_collisions = true
rope.collision_mask = collision_layer  # Only collide with relevant layers
```

5. **Visibility Culling**: Disable ropes when off-screen.

```gdscript
# In your game's visibility system
func _on_rope_exited_screen(rope):
    rope.process_mode = Node.PROCESS_MODE_DISABLED

func _on_rope_entered_screen(rope):
    rope.process_mode = Node.PROCESS_MODE_INHERIT
```

## Extending PixelRope

PixelRope is designed to be extensible through Godot's inheritance system. You can create custom rope types by extending the base classes:

```gdscript
# Create a custom rope type
class_name ElectricRope
extends PixelRope

# Add custom properties
var voltage: float = 100.0
var shock_damage: float = 10.0

func _ready():
    super._ready()
    # Custom initialization
    rope_color = Color(0.2, 0.7, 1.0)
    
func _process(delta):
    super._process(delta)
    # Add electricity visual effects
    if not _broken:
        _create_electricity_particles()
        
func shock_entity(entity):
    if entity.has_method("take_damage"):
        entity.take_damage(shock_damage)
```

## Troubleshooting

### Common Issues

#### Rope Appears Stretched or Broken

**Symptoms:** Rope immediately breaks or appears overly stretched when the scene starts.

**Solution:** Check the distance between anchor points relative to segment count and length.

```gdscript
# Recommended fix
var distance = start_position.distance_to(end_position)
rope.segment_count = int(distance / 20.0)  # Adjust divisor as needed
rope.segment_length = distance / rope.segment_count
```

#### Physics Instability

**Symptoms:** Rope jitters, oscillates uncontrollably, or segments pass through each other.

**Solution:** Increase iteration count and reduce damping.

```gdscript
rope.iterations = 20    # More stable physics
rope.damping = 0.9      # Less bouncy
```

#### Collision Detection Issues

**Symptoms:** Rope passes through objects that should block it.

**Solution:** Verify collision mask settings and check physics initialization.

```gdscript
# Ensure physics is properly initialized
rope.enable_collisions = true
rope.collision_mask = 1  # Check this matches your environment's layer
print(rope._physics_direct_state != null)  # Should print true during gameplay
```

#### Poor Performance

**Symptoms:** Frame rate drops when multiple ropes are present.

**Solution:** Optimize segment count and physics iterations.

```gdscript
# Performance optimization
rope.segment_count = max(10, int(rope_length / 30.0))  # Fewer segments
rope.iterations = 5  # Fewer physics iterations
rope.line_algorithm = LineAlgorithms.LineAlgorithmType.BRESENHAM  # Faster rendering
```

### Debugging Tips

1. Enable debug visualization for collision and anchors:

```gdscript
rope.show_collision_debug = true
rope.show_anchor_debug = true
```

2. Monitor rope state for stretched/broken conditions:

```gdscript
func _process(delta):
    var state = rope.get_state()
    match state:
        PixelRope.RopeState.NORMAL:
            print("Rope is normal")
        PixelRope.RopeState.STRETCHED:
            print("Rope is stretched")
        PixelRope.RopeState.BROKEN:
            print("Rope is broken")
```

3. Use `LineAlgorithms.benchmark_algorithms()` to compare performance between rendering methods.

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

### Development Setup

1. Clone the repository:
```
git clone https://github.com/Lost-Rabbit-Digital/pixelated_rope_simulation.git
```

2. Open the project in Godot 4.4.

3. Make your changes following these guidelines:
   - Follow the existing code style and naming conventions
   - Add/update tests for any changes
   - Update documentation for any modified APIs
   - Add example usage for new features

### Submitting Changes

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin feature/my-new-feature`)
5. Create a new Pull Request

## License

This project is licensed under the [Mozilla Public License Version 2.0](LICENSE.md).

## Attributions

### Project Team
**Lost Rabbit Digital LLC**  
- [Boden McHale](https://www.bodenmchale.com/) - Programming and Design

### Community Contributors
Thank you to those who requested features, pointed out bugs, and helped to motivate the development of this plugin.

#### Feature Requests
- **Tangle System** - [@smitner.studio](https://bsky.app/profile/smitner.studio/post/3ljiul5ioqc2o)
- **Collision System** - [@atropos148.bsky.social](https://bsky.app/profile/atropos148.bsky.social/post/3ljhccxiiyc2g)
- **Elastic System** - [@brinegame.bsky.social](https://bsky.app/profile/brinegame.bsky.social/post/3ljgyh6d5lc2x)

For more information, see [attributions.md](godot_project/addons/pixel_rope/information/ATTRIBUTIONS.md).