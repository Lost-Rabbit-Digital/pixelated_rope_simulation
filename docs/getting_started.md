# Getting Started with PixelRope

This guide will help you install PixelRope and set up your first rope simulation in Godot 4.4.

## Installation

### Method 1: Godot AssetLib (Recommended)

1. Open your Godot project
2. Navigate to AssetLib tab in the top center of the editor
3. Search for "PixelRope"
4. Click on the plugin and press "Download"
5. In the installation dialog, click "Install"
6. Enable the plugin in Project Settings > Plugins

### Method 2: Manual Installation

1. Download the plugin from the [GitHub repository](https://github.com/Lost-Rabbit-Digital/pixelated_rope_simulation)
2. Extract the `addons/pixel_rope` folder into your project's `addons` directory
3. Enable the plugin in Project Settings > Plugins

## Quick Setup

After installation, you can add a `PixelRope` node to your scene through the editor:

1. Right-click in the Scene panel and select "Add Child Node"
2. Search for "PixelRope" and select it
3. The rope will appear with default anchors that you can position
4. Adjust properties in the Inspector panel

## Basic Usage

### Adding a Rope Through the Editor

1. Create a new scene or open an existing one
2. Right-click in the Scene panel and select "Add Child Node"
3. Search for "PixelRope" and add it to your scene
4. By default, the rope comes with two anchor points: "StartAnchor" and "EndAnchor"
5. Select and position these anchors in your scene
6. Adjust the rope properties in the Inspector panel:
   - Set `segment_count` to control detail (higher values = more detailed physics)
   - Adjust `pixel_size` to match your game's visual style
   - Choose a `rope_color` to match your theme

### Creating a Rope in Code

```gdscript
# Create a basic rope
func create_rope():
    # Instantiate the rope
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
    
    return rope
```

### Making Ropes Interactive

To make your rope interactive (grabbable):

```gdscript
# Configure rope interaction
func setup_interactive_rope(rope):
    # Allow grabbing anywhere on the rope
    rope.interaction_mode = PixelRope.GrabMode.ANY_POINT
    rope.interaction_width = 20.0
    
    # Connect signals for interaction events
    rope.rope_grabbed.connect(_on_rope_grabbed)
    rope.rope_released.connect(_on_rope_released)
    
func _on_rope_grabbed(segment_index):
    print("Grabbed rope segment: ", segment_index)
    
func _on_rope_released():
    print("Released rope")
```

### Enabling Rope Physics

Configure how your rope behaves physically:

```gdscript
# Set up physics properties
func configure_rope_physics(rope):
    # Gravity direction and strength
    rope.gravity = Vector2(0, 980)  # Standard downward gravity
    
    # Damping controls how quickly the rope settles
    rope.damping = 0.98  # Higher = less bouncy
    
    # Iterations affect stability (higher = more stable but more CPU intensive)
    rope.iterations = 10
    
    # How much the rope can stretch before breaking
    rope.max_stretch_factor = 2.0  # 2x normal length
```

## Example: Complete Rope Setup

Here's a complete example that sets up a rope with all basic properties:

```gdscript
extends Node2D

func _ready():
    # Create and configure rope
    var rope = create_basic_rope()
    
    # Connect to signals
    rope.rope_broken.connect(_on_rope_broken)

func create_basic_rope() -> PixelRope:
    var rope = PixelRope.new()
    
    # Basic properties
    rope.segment_count = 40
    rope.segment_length = 5.0
    rope.pixel_size = 4
    rope.rope_color = Color(0.8, 0.6, 0.2)
    
    # Physics properties
    rope.gravity = Vector2(0, 980)
    rope.damping = 0.98
    rope.iterations = 10
    rope.max_stretch_factor = 2.0
    
    # Anchor properties
    rope.dynamic_start_anchor = false  # Fixed start point
    rope.dynamic_end_anchor = true     # End point affected by physics
    
    # Interaction
    rope.interaction_mode = PixelRope.GrabMode.ANY_POINT
    rope.interaction_width = 20.0
    
    # Add to scene
    add_child(rope)
    
    # Position
    rope.start_position = Vector2(100, 100)
    rope.end_position = Vector2(300, 300)
    
    return rope
    
func _on_rope_broken():
    print("Rope has broken!")
    # Optionally reset the rope after a delay
    await get_tree().create_timer(2.0).timeout
    get_children().filter(func(c): return c is PixelRope)[0].reset_rope()
```

## Next Steps

Now that you have a basic rope set up, you might want to:

* Explore advanced [configuration options](configuration.md)
* Add [collisions with the environment](advanced_usage.md#collision-detection)
* Create dynamic [bridges or grappling hooks](examples.md)
* Learn about [performance optimization](performance.md)

For a complete reference of all available properties and methods, see the [API Reference](api_reference.md).