# API Reference

This document provides a complete reference for all classes, properties, methods, signals, and enums in the PixelRope plugin.

## Table of Contents

- [PixelRope](#pixelrope)
  - [Properties](#properties)
  - [Methods](#methods)
  - [Signals](#signals)
  - [Enums](#enums)
- [RopeAnchor](#ropeanchor)
  - [Properties](#ropeanchor-properties)
  - [Signals](#ropeanchor-signals)
- [LineAlgorithms](#linealgorithms)
  - [Methods](#linealgorithms-methods)
  - [Enums](#linealgorithms-enums)

## PixelRope

`PixelRope` is the main class that implements rope physics and rendering. It inherits from `Node2D`.

### Properties

#### Rope Properties

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `segment_count` | int | 100 | Number of segments in the rope |
| `segment_length` | float | 5.0 | Length of each segment in pixels |
| `rope_color` | Color | Color(0.8, 0.6, 0.2) | Color of the rope |

#### Pixelation Properties

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `pixel_size` | int | 4 | Size of each rendered pixel |
| `pixel_spacing` | int | 0 | Spacing between pixels (0 = solid line) |
| `line_algorithm` | LineAlgorithmType | BRESENHAM | Algorithm used for drawing lines |

#### Physics Properties

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `gravity` | Vector2 | Vector2(0, 980) | Force applied to rope segments |
| `damping` | float | 0.98 | Velocity dampening (0-1) |
| `iterations` | int | 10 | Physics iteration count for stability |
| `max_stretch_factor` | float | 2.0 | Maximum stretch before rope breaks |

#### Anchor Properties

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `start_position` | Vector2 | Vector2(-100, 0) | Position of the start anchor |
| `end_position` | Vector2 | Vector2(100, 0) | Position of the end anchor |
| `anchor_radius` | float | 8.0 | Radius of anchor collision shapes |
| `anchor_debug_color` | Color | Color(0, 0.698, 0.885, 0.5) | Color for anchor visualization |
| `show_anchor_debug` | bool | true | Whether to show anchor debug shapes |

#### Dynamic Anchor Properties

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `dynamic_start_anchor` | bool | false | Makes start anchor physics-driven |
| `dynamic_end_anchor` | bool | true | Makes end anchor physics-driven |
| `anchor_mass` | float | 1.0 | Mass factor for anchors (0.1-10.0) |
| `anchor_jitter` | float | 0.0 | Random movement applied to anchors |
| `anchor_gravity` | Vector2 | Vector2.ZERO | Override gravity for anchors |

#### Collision Properties

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `enable_collisions` | bool | true | Enable rope collision with environment |
| `collision_mask` | int | 1 | Physics layers to collide with |
| `collision_bounce` | float | 0.3 | Bounciness of collisions (0-1) |
| `collision_friction` | float | 0.7 | Friction during collisions (0-1) |
| `collision_radius` | float | 4.0 | Radius of segment collision shapes |
| `show_collision_debug` | bool | false | Visualize collision shapes |

#### Interaction Properties

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `interaction_mode` | GrabMode | ANY_POINT | How rope can be interacted with |
| `interaction_width` | float | 20.0 | Width of interaction area |
| `grab_strength` | float | 0.8 | Pull strength for grabbed segments |
| `end_anchor_draggable` | bool | true | Allow dragging the end anchor |

### Methods

| Method | Parameters | Return Type | Description |
|--------|------------|-------------|-------------|
| `break_rope()` | none | void | Manually breaks the rope |
| `reset_rope()` | none | void | Resets a broken rope to its original state |
| `get_state()` | none | RopeState | Returns the current rope state (NORMAL, STRETCHED, BROKEN) |

### Signals

| Signal | Parameters | Description |
|--------|------------|-------------|
| `rope_broken` | none | Emitted when the rope breaks due to excessive stretching |
| `rope_grabbed` | segment_index: int | Emitted when a rope segment is grabbed |
| `rope_released` | none | Emitted when a grabbed rope segment is released |

### Enums

#### RopeState

```gdscript
enum RopeState {
    NORMAL,     # Rope is in normal state
    STRETCHED,  # Rope is stretched (over 80% of break threshold)
    BROKEN      # Rope is broken
}
```

#### GrabMode

```gdscript
enum GrabMode {
    NONE,          # No interaction with rope
    ANCHORS_ONLY,  # Only anchor points can be interacted with
    ANY_POINT      # Any point along the rope can be interacted with
}
```

## RopeAnchor

`RopeAnchor` is a component for PixelRope that represents an attachment point. It inherits from `Node2D`.

### RopeAnchor Properties

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `radius` | float | 8.0 | Radius of the anchor's collision detection area |
| `debug_color` | Color | Color(0.7, 0.7, 1.0, 0.5) | Color of the debug visualization |
| `show_debug_shape` | bool | true | Whether to show the collision debug shape |

### RopeAnchor Signals

| Signal | Parameters | Description |
|--------|------------|-------------|
| `position_changed` | none | Emitted when the anchor position changes in the editor |

## LineAlgorithms

`LineAlgorithms` is a utility class that provides line drawing algorithms for pixel-perfect rendering.

### LineAlgorithms Methods

| Method | Parameters | Return Type | Description |
|--------|------------|-------------|-------------|
| `get_line_points` | from_point: Vector2, to_point: Vector2, pixel_size: int, algorithm_type: LineAlgorithmType = BRESENHAM, pixel_spacing: int = 0 | Array[Vector2] | Returns points along a line using the specified algorithm |
| `benchmark_algorithms` | from_point: Vector2, to_point: Vector2, pixel_size: int, iterations: int = 1000 | Dictionary | Compares performance between algorithms |

### LineAlgorithms Enums

#### LineAlgorithmType

```gdscript
enum LineAlgorithmType {
    BRESENHAM,  # Integer-based line drawing, computationally efficient
    DDA         # Floating-point based line drawing, visually smoother
}
```

## Usage Examples

### Basic Rope Creation

```gdscript
# Create a basic rope
var rope = PixelRope.new()
rope.segment_count = 30
rope.segment_length = 5.0
rope.start_position = Vector2(100, 100)
rope.end_position = Vector2(300, 100)
add_child(rope)
```

### Monitoring Rope State

```gdscript
# Connect to signals
rope.rope_broken.connect(_on_rope_broken)
rope.rope_grabbed.connect(_on_rope_grabbed)
rope.rope_released.connect(_on_rope_released)

# Check rope state
func _process(delta):
    var state = rope.get_state()
    if state == PixelRope.RopeState.STRETCHED:
        print("Warning: Rope is stretched")
```

### Manually Breaking and Resetting

```gdscript
# Break the rope
func _break_rope_button_pressed():
    rope.break_rope()
    
# Reset the rope
func _reset_rope_button_pressed():
    rope.reset_rope()
```

### Configuring Line Drawing

```gdscript
# Use smoother algorithm for diagonal lines
rope.line_algorithm = LineAlgorithms.LineAlgorithmType.DDA
rope.pixel_size = 4
rope.pixel_spacing = 1  # Creates dotted line effect
```

For more examples and practical implementations, see the [Examples](examples.md) document.