# PixelRope

![PixelRope Banner](https://img.shields.io/badge/Godot-4.4-blue) ![License](https://img.shields.io/badge/license-GPL--3.0-green) ![Version](https://img.shields.io/badge/version-1.0.0-orange)

A high-performance, pixel-perfect rope simulation plugin for Godot 4.4, featuring realistic physics, customizable rendering, and interactive anchors.

<p align="center">
  <img src="docs/preview.gif" alt="PixelRope Demo" width="600"/>
</p>

## 🚀 For Godot Developers

**PixelRope** brings authentic retro-style rope physics to your Godot 4.4 projects with minimal setup. Whether you're creating a pixel-art platformer, a physics puzzle, or a retro-themed adventure, PixelRope offers a complete solution with:

- 📐 **Pixel-perfect rendering** using multiple line algorithms (Bresenham and DDA)
- 🧵 **Realistic physics** with verlet integration and customizable properties
- 🔌 **Entity Component System (ECS) friendly** design for optimal performance
- 🎮 **Full interaction** support with grabbing, breaking, and dynamic anchors
- 🎨 **Visual customization** with adjustable pixel size, spacing, and colors

```gdscript
# Adding a rope is as simple as:
var rope = PixelRope.new()
rope.segment_count = 20
rope.pixel_size = 4
rope.rope_color = Color(0.8, 0.6, 0.2)
add_child(rope)
```

## 📥 Installation

1. Download the plugin from the [GitHub repository](https://github.com/Lost-Rabbit-Digital/pixelated_rope_simulation)
2. Extract the `addons/pixel_rope` folder into your project's `addons` directory
3. Enable the plugin in Project Settings > Plugins
4. Add a `PixelRope` node to your scene and configure its properties

## 🔧 Basic Usage

### Creating a Rope

1. Add a `PixelRope` node to your scene
2. Configure the start and end positions or adjust the existing anchor nodes
3. Customize the rope properties (segment count, pixel size, etc.)
4. Run your scene to see the physics in action

### Rope Properties

| Property | Description |
|----------|-------------|
| `segment_count` | Number of segments in the rope (affects resolution) |
| `segment_length` | Length of each segment (affects total rope length) |
| `pixel_size` | Size of each rendered pixel |
| `pixel_spacing` | Optional spacing between pixels for dotted line effect |
| `rope_color` | Color of the rope |
| `line_algorithm` | Bresenham (faster) or DDA (smoother) |

### Physics Properties

| Property | Description |
|----------|-------------|
| `gravity` | Force applied to rope segments |
| `damping` | Velocity dampening (lower = more bouncy) |
| `iterations` | Physics iteration count (higher = more stable) |
| `max_stretch_factor` | Maximum stretch before rope breaks |

### Anchor Options

| Property | Description |
|----------|-------------|
| `dynamic_start_anchor` | Makes start anchor react to physics |
| `dynamic_end_anchor` | Makes end anchor react to physics |
| `anchor_mass` | How heavily anchors are affected by forces |
| `anchor_jitter` | Adds random movement to dynamic anchors |

## 📚 API Reference

### Signals

- `rope_broken`: Emitted when the rope breaks due to excessive stretching
- `rope_grabbed(segment_index)`: Emitted when a rope segment is grabbed
- `rope_released`: Emitted when a grabbed rope segment is released

### Methods

- `break_rope()`: Manually breaks the rope
- `reset_rope()`: Resets a broken rope to its original state
- `get_state()`: Returns the current rope state (NORMAL, STRETCHED, BROKEN)

## 🔬 Technical Implementation

### System Architecture

PixelRope is built using a modular architecture that cleanly separates its core components:

1. **Core Simulation** (`rope_node.gd`): Implements verlet integration physics and constraint solving
2. **Rendering System** (`line_algorithms.gd`): Handles pixel-perfect line drawing with multiple algorithms
3. **Interaction System**: Manages grabbing, dragging, and breaking mechanics
4. **Editor Integration** (`pixel_rope.gd`): Provides seamless editor tools and live preview

### Verlet Integration Physics

The rope simulation uses verlet integration for robust, stable physics without requiring complex differential equations:

```gdscript
# For each segment in the rope
for i in range(_segments.size()):
    var segment = _segments[i]
    if segment.is_locked or segment.is_grabbed:
        continue
        
    var temp = segment.position
    var velocity = segment.position - segment.old_position
    
    # Apply forces with mass factoring
    segment.position += velocity * damping + gravity * delta * delta / segment.mass
    segment.old_position = temp
```

After position updates, the system applies iterative constraint solving to maintain segment lengths:

```gdscript
for i in range(iterations):
    for j in range(segment_count):
        var segment1 = _segments[j]
        var segment2 = _segments[j + 1]
        
        var current_vec = segment2.position - segment1.position
        var current_dist = current_vec.length()
        
        # Apply position correction based on constraint
        var difference = segment_length - current_dist
        var percent = difference / current_dist
        var correction = current_vec * percent
        
        # Weight by mass for realistic movement
        if not segment1.is_locked:
            segment1.position -= correction * (segment2.mass / (segment1.mass + segment2.mass))
            
        if not segment2.is_locked:
            segment2.position += correction * (segment1.mass / (segment1.mass + segment2.mass))
```

### Pixel-Perfect Line Rendering

The rendering system implements two classic line-drawing algorithms optimized for pixelated graphics:

1. **Bresenham's Line Algorithm**: An integer-based approach that's computationally efficient and produces perfectly aligned pixel patterns:

```gdscript
static func _bresenham_line(from: Vector2, to: Vector2, pixel_size: int, spacing: int = 0) -> Array[Vector2]:
    var points: Array[Vector2] = []
    
    var x0 = int(from.x / pixel_size)
    var y0 = int(from.y / pixel_size)
    var x1 = int(to.x / pixel_size)
    var y1 = int(to.y / pixel_size)
    
    var dx = abs(x1 - x0)
    var dy = -abs(y1 - y0)
    var sx = 1 if x0 < x1 else -1
    var sy = 1 if y0 < y1 else -1
    var err = dx + dy
    
    # Algorithm implementation with optional spacing
    while true:
        if spacing == 0 or pixel_count % (spacing + 1) == 0:
            points.append(Vector2(x0 * pixel_size, y0 * pixel_size))
        
        if x0 == x1 and y0 == y1:
            break
            
        var e2 = 2 * err
        if e2 >= dy:
            if x0 == x1:
                break
            err += dy
            x0 += sx
        
        if e2 <= dx:
            if y0 == y1:
                break
            err += dx
            y0 += sy
    
    return points
```

2. **Digital Differential Analyzer (DDA)**: A floating-point algorithm that produces smoother results for diagonal lines:

```gdscript
static func _dda_line(from: Vector2, to: Vector2, pixel_size: int, spacing: int = 0) -> Array[Vector2]:
    var points: Array[Vector2] = []
    
    var x0 = from.x / pixel_size
    var y0 = from.y / pixel_size
    var x1 = to.x / pixel_size
    var y1 = to.y / pixel_size
    
    var dx = x1 - x0
    var dy = y1 - y0
    var steps = max(abs(dx), abs(dy))
    
    var x_inc = dx / steps
    var y_inc = dy / steps
    
    var x = x0
    var y = y0
    
    for i in range(steps + 1):
        if spacing == 0 or i % (spacing + 1) == 0:
            points.append(Vector2(round(x) * pixel_size, round(y) * pixel_size))
        
        x += x_inc
        y += y_inc
    
    return points
```

### ECS Compatibility Design

The plugin uses a component-based design that aligns with Entity Component System principles:

1. **Rope Entity** (`PixelRope`): The main node that coordinates the overall system
2. **Anchor Components** (`RopeAnchor`): Modular attachment points with physics properties
3. **Segment Data**: Stored as dictionary components with position, velocity, and constraint data
4. **Physics System**: Processes all segments through verlet integration and constraints
5. **Rendering System**: Handles the visual representation independently of physics

This approach enables high performance even with complex rope systems, as updates are processed in batches with minimal overhead.

### Performance Optimizations

1. **Customizable Iteration Count**: Allows balancing between physics accuracy and performance
2. **Adaptive Segment Count**: Automatically adjusts based on rope length for optimal resolution
3. **Efficient Line Algorithms**: Uses integer-based Bresenham by default for maximum performance
4. **Area2D Pooling**: Minimizes node creation for interaction areas
5. **Editor-Only Updates**: Disables expensive operations when in the Godot editor

## 🤝 Contributing

Contributions are welcome! Check the [GitHub repository](https://github.com/Lost-Rabbit-Digital/pixelated_rope_simulation) for issues or submit pull requests.

## 📜 License

This project is licensed under the [GNU General Public License v3.0](LICENSE).

## 📞 Contact

- BlueSky: https://bsky.app/profile/bodengamedev.bsky.social
- GitHub: https://github.com/Lost-Rabbit-Digital