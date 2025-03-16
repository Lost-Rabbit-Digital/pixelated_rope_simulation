# Configuration Guide

This document covers all the configuration options available for PixelRope, along with recommended settings for common scenarios.

## Table of Contents

- [Basic Appearance](#basic-appearance)
- [Physics Behavior](#physics-behavior)
- [Anchor Settings](#anchor-settings)
- [Collision Configuration](#collision-configuration)
- [Interaction Settings](#interaction-settings)
- [Common Configurations](#common-configurations)
  - [Grappling Hook](#grappling-hook-configuration)
  - [Hanging Bridge](#hanging-bridge-configuration)
  - [Decorative Rope](#decorative-rope-configuration)
  - [Electric Wire](#electric-wire-configuration)
  - [Towing Cable](#towing-cable-configuration)

## Basic Appearance

### Rope Properties

These properties control the basic appearance and structure of the rope:

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `segment_count` | int | 100 | Number of segments in the rope. Higher values create a more detailed rope with smoother physics, but increase CPU usage. |
| `segment_length` | float | 5.0 | Length of each segment in pixels. This affects the total length of the rope (`segment_count × segment_length`). |
| `rope_color` | Color | Color(0.8, 0.6, 0.2) | Color of the rope. Can be any Godot Color value. |

Example:
```gdscript
# Configure basic rope appearance
rope.segment_count = 50
rope.segment_length = 6.0
rope.rope_color = Color(0.7, 0.2, 0.2)  # Reddish color
```

### Pixelation Settings

These properties control how the rope is rendered at the pixel level:

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `pixel_size` | int | 4 | Size of each rendered pixel. Higher values create a more "chunky" pixelated look. |
| `pixel_spacing` | int | 0 | Spacing between pixels (0 = solid line, higher values create a dotted effect). |
| `line_algorithm` | LineAlgorithmType | BRESENHAM | Algorithm used for drawing pixel lines. BRESENHAM is faster, DDA looks smoother on diagonals. |

Example:
```gdscript
# Configure pixelated appearance
rope.pixel_size = 5
rope.pixel_spacing = 2  # Creates a dotted line effect
rope.line_algorithm = LineAlgorithms.LineAlgorithmType.DDA  # Smoother diagonals
```

## Physics Behavior

These properties control how the rope moves and responds to forces:

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `gravity` | Vector2 | Vector2(0, 980) | Force applied to rope segments. Default is standard downward gravity. |
| `damping` | float | 0.98 | Velocity dampening (0-1). Higher values make the rope less bouncy/more rigid. |
| `iterations` | int | 10 | Physics iteration count for stability. Higher values increase stability but cost CPU. |
| `max_stretch_factor` | float | 2.0 | Maximum stretch before rope breaks (as a multiplier of normal length). |

Example:
```gdscript
# Configure physics behavior
rope.gravity = Vector2(0, 490)  # Half-strength gravity
rope.damping = 0.95  # Slightly bouncier
rope.iterations = 15  # More stable physics
rope.max_stretch_factor = 1.5  # Breaks more easily when stretched
```

## Anchor Settings

These properties control the rope's anchors and how they behave:

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `start_position` | Vector2 | Vector2(-100, 0) | Position of the start anchor. |
| `end_position` | Vector2 | Vector2(100, 0) | Position of the end anchor. |
| `anchor_radius` | float | 8.0 | Radius of anchor collision shapes. |
| `anchor_debug_color` | Color | Color(0, 0.698, 0.885, 0.5) | Color for anchor visualization in the editor. |
| `show_anchor_debug` | bool | true | Whether to show anchor debug shapes in the editor. |
| `dynamic_start_anchor` | bool | false | Makes start anchor affected by physics. |
| `dynamic_end_anchor` | bool | true | Makes end anchor affected by physics. |
| `anchor_mass` | float | 1.0 | Mass factor for anchors (0.1-10.0). Higher values make anchors more resistant to movement. |
| `anchor_jitter` | float | 0.0 | Adds random movement to dynamic anchors for more natural motion. |
| `anchor_gravity` | Vector2 | Vector2.ZERO | Override gravity specifically for anchors. If set to zero, uses the main gravity. |

Example:
```gdscript
# Configure anchors
rope.start_position = Vector2(100, 100)
rope.end_position = Vector2(500, 300)
rope.dynamic_start_anchor = false  # Start is fixed
rope.dynamic_end_anchor = true     # End moves with physics
rope.anchor_mass = 2.0             # End anchor is heavier
rope.anchor_jitter = 0.5           # Slight random movement
```

## Collision Configuration

These properties control how the rope interacts with the environment:

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `enable_collisions` | bool | true | Enable rope collision with environment. |
| `collision_mask` | int | 1 | Physics layers to collide with (bitmask). |
| `collision_bounce` | float | 0.3 | Bounciness of collisions (0-1). |
| `collision_friction` | float | 0.7 | Friction during collisions (0-1). |
| `collision_radius` | float | 4.0 | Radius of segment collision shapes. |
| `show_collision_debug` | bool | false | Visualize collision shapes (useful for debugging). |

Example:
```gdscript
# Configure collision behavior
rope.enable_collisions = true
rope.collision_mask = 3  # Collide with layers 1 and 2
rope.collision_bounce = 0.5  # Medium bounce
rope.collision_friction = 0.8  # High friction
rope.collision_radius = 5.0  # Larger collision area
```

## Interaction Settings

These properties control how the rope can be interacted with:

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `interaction_mode` | GrabMode | ANY_POINT | How the rope can be interacted with (NONE, ANCHORS_ONLY, ANY_POINT). |
| `interaction_width` | float | 20.0 | Width of the interaction area around rope segments. |
| `grab_strength` | float | 0.8 | How strongly grabbed segments are pulled toward the interaction point. |
| `end_anchor_draggable` | bool | true | Whether the end anchor can be dragged by the player. |

Example:
```gdscript
# Configure interaction
rope.interaction_mode = PixelRope.GrabMode.ANY_POINT
rope.interaction_width = 25.0  # Larger interaction area
rope.grab_strength = 0.9  # Stronger grab response
rope.end_anchor_draggable = false  # Can't drag the end anchor
```

## Common Configurations

Here are some pre-configured setups for common use cases:

### Grappling Hook Configuration

```gdscript
# Grappling hook configuration
func configure_grappling_hook(rope):
    # Appearance
    rope.segment_count = 30
    rope.segment_length = 10.0
    rope.rope_color = Color(0.6, 0.6, 0.6)
    rope.pixel_size = 3
    
    # Physics
    rope.gravity = Vector2(0, 50)  # Very light gravity
    rope.damping = 0.9
    rope.iterations = 15  # More stable
    rope.max_stretch_factor = 1.2  # Breaks if stretched too much
    
    # Anchors
    rope.dynamic_start_anchor = false  # Start fixed to player
    rope.dynamic_end_anchor = true     # End moves with physics
    rope.anchor_mass = 2.0             # Heavy hook
    
    # Collision
    rope.enable_collisions = true
    rope.collision_bounce = 0.1  # Limited bounce
    rope.collision_friction = 0.95  # High friction for wrapping
    
    # Interaction
    rope.interaction_mode = PixelRope.GrabMode.NONE  # No direct rope interaction
    rope.end_anchor_draggable = false  # Hook not draggable when deployed
```

### Hanging Bridge Configuration

```gdscript
# Hanging bridge configuration
func configure_bridge(rope):
    # Appearance
    rope.segment_count = 40
    rope.segment_length = 20.0  # Wider spacing for a bridge
    rope.rope_color = Color(0.6, 0.4, 0.2)  # Brown
    rope.pixel_size = 5
    
    # Physics
    rope.gravity = Vector2(0, 980)
    rope.damping = 0.7  # Less bouncy
    rope.iterations = 25  # Very stable
    rope.max_stretch_factor = 1.3
    
    # Anchors
    rope.dynamic_start_anchor = false  # Fixed left side
    rope.dynamic_end_anchor = false    # Fixed right side
    
    # Collision
    rope.enable_collisions = true      # Characters can stand on it
    rope.collision_bounce = 0.0        # No bounce
    rope.collision_friction = 0.9      # High friction
    rope.collision_radius = 8.0        # Larger collision area
    
    # Interaction
    rope.interaction_mode = PixelRope.GrabMode.ANY_POINT  # Entire bridge is interactive
    rope.grab_strength = 0.4  # Limited response when grabbed
```

### Decorative Rope Configuration

```gdscript
# Decorative background rope configuration
func configure_decorative_rope(rope):
    # Appearance
    rope.segment_count = 60
    rope.segment_length = 5.0
    rope.rope_color = Color(0.3, 0.3, 0.3, 0.7)  # Dark gray, semi-transparent
    rope.pixel_size = 2  # Smaller pixels
    rope.pixel_spacing = 1  # Slightly dotted
    
    # Physics
    rope.gravity = Vector2(0, 100)  # Very light gravity
    rope.damping = 0.999  # Almost no bounce
    rope.iterations = 5  # Lower CPU usage
    
    # Anchors
    rope.dynamic_start_anchor = false
    rope.dynamic_end_anchor = false
    rope.show_anchor_debug = false  # Hide debug visuals
    
    # Collision & Interaction
    rope.enable_collisions = false  # No collisions for background elements
    rope.interaction_mode = PixelRope.GrabMode.NONE  # Not interactive
```

### Electric Wire Configuration

```gdscript
# Electric wire/cable configuration
func configure_electric_wire(rope):
    # Appearance
    rope.segment_count = 35
    rope.segment_length = 6.0
    rope.rope_color = Color(0.9, 0.9, 0.2)  # Yellow
    rope.pixel_size = 3
    
    # Physics
    rope.gravity = Vector2(0, 490)  # Half gravity for gentle sag
    rope.damping = 0.95
    rope.iterations = 10
    rope.max_stretch_factor = 1.1  # Breaks easily
    
    # Anchors
    rope.dynamic_start_anchor = false
    rope.dynamic_end_anchor = false
    
    # Collision
    rope.enable_collisions = true
    rope.collision_bounce = 0.2
    rope.collision_friction = 0.3  # Slippery
    
    # Interaction
    rope.interaction_mode = PixelRope.GrabMode.ANY_POINT
    rope.grab_strength = 0.7
```

### Towing Cable Configuration

```gdscript
# Towing cable for vehicles/objects
func configure_towing_cable(rope):
    # Appearance
    rope.segment_count = 25
    rope.segment_length = 8.0
    rope.rope_color = Color(0.2, 0.2, 0.2)  # Dark gray/black
    rope.pixel_size = 4
    
    # Physics
    rope.gravity = Vector2(0, 200)  # Reduced gravity
    rope.damping = 0.8  # Some bounce for realism
    rope.iterations = 20  # Very stable for towing
    rope.max_stretch_factor = 1.8  # Strong cable
    
    # Anchors
    rope.dynamic_start_anchor = true  # Both ends attached to moving objects
    rope.dynamic_end_anchor = true
    rope.anchor_mass = 5.0  # Heavy connection points
    
    # Collision
    rope.enable_collisions = true
    rope.collision_bounce = 0.1
    rope.collision_friction = 0.6
    
    # Interaction
    rope.interaction_mode = PixelRope.GrabMode.NONE  # No interaction during towing
```

## Optimizing Your Configuration

When configuring your rope, keep these optimization principles in mind:

1. **Segment Count**: Only use as many segments as needed. Lower segment counts perform much better.

2. **Physics Iterations**: Balance between stability and performance. 5-10 iterations work for most cases.

3. **Collision Detection**: Disable collisions for ropes that don't need to interact with the environment.

4. **Rendering Algorithm**: Use Bresenham's algorithm (default) for performance, only switch to DDA when needed for visual quality.

5. **Dynamic vs. Static Anchors**: Use static anchors where possible as they require less physics calculation.

## Saving and Loading Configurations

To save your configuration for reuse:

```gdscript
# Save a configuration to a dictionary
func save_rope_config(rope) -> Dictionary:
    return {
        # Basic properties
        "segment_count": rope.segment_count,
        "segment_length": rope.segment_length,
        "rope_color": rope.rope_color,
        
        # Pixelation
        "pixel_size": rope.pixel_size,
        "pixel_spacing": rope.pixel_spacing,
        "line_algorithm": rope.line_algorithm,
        
        # Physics
        "gravity": rope.gravity,
        "damping": rope.damping,
        "iterations": rope.iterations,
        "max_stretch_factor": rope.max_stretch_factor,
        
        # Anchors
        "dynamic_start_anchor": rope.dynamic_start_anchor,
        "dynamic_end_anchor": rope.dynamic_end_anchor,
        "anchor_mass": rope.anchor_mass,
        
        # Collision
        "enable_collisions": rope.enable_collisions,
        "collision_bounce": rope.collision_bounce,
        "collision_friction": rope.collision_friction,
        
        # Interaction
        "interaction_mode": rope.interaction_mode,
        "grab_strength": rope.grab_strength
    }

# Apply a saved configuration
func apply_rope_config(rope, config: Dictionary) -> void:
    for key in config:
        if rope.get(key) != null:
            rope.set(key, config[key])
```

## Configuration Troubleshooting

If your rope isn't behaving as expected, check these common configuration issues:

1. **Rope is too stretchy**: Increase `iterations` and/or decrease `max_stretch_factor`
2. **Rope is unstable/jittery**: Increase `iterations` and/or `damping`
3. **Rope doesn't collide properly**: Check `collision_mask` matches your environment layers
4. **Rope is too rigid**: Decrease `iterations` and/or increase `damping`
5. **Anchors behave strangely**: Try adjusting `anchor_mass` or disable `dynamic_start_anchor`/`dynamic_end_anchor`

For more specific troubleshooting, see the [Troubleshooting](troubleshooting.md) guide.