# PixelRope

A high-performance, pixel-perfect rope simulation plugin for Godot 4.4, featuring realistic physics, customizable rendering, and interactive anchors.

**Requires Godot 4.4+**

[![Godot Asset Library](https://img.shields.io/badge/Godot%20Asset%20Library-PixelRope-478CBF?style=for-the-badge&logo=godotengine&logoColor=white)](https://godotengine.org/asset-library/asset)
[![Discord](https://img.shields.io/badge/Discord-Join%20Server-5865F2?style=for-the-badge&logo=discord&logoColor=white)](https://discord.gg/Y7caBf7gBj)

<p align="center">
  <img src="docs/preview.gif" alt="PixelRope Demo" width="600"/>
</p>

---

## Features

- **Pixel-perfect rendering** with multiple line algorithms (Bresenham and DDA)
- **Realistic physics** with verlet integration
- **ECS-friendly** design for optimal performance
- **Interactive ropes** with grabbing, breaking, and dynamic anchors
- **Visual customization** with adjustable pixel size, spacing, and colors
- **Collision detection** with environment objects

---

## Install

### Asset Library (recommended)

1. Open your project → **AssetLib** → search **"PixelRope"**
2. **Download** → **Install**
3. **Project → Project Settings → Plugins** → enable **PixelRope**

### Manual

1. Copy `addons/pixel_rope/` into your project:
   ```
   your_project/
   └── addons/
       └── pixel_rope/
   ```
2. **Project → Project Settings → Plugins** → enable **PixelRope**

---

## Usage

```gdscript
# Create a rope
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

---

## Example Scenes

The plugin includes several example scenes demonstrating different use cases:

| Scene | Description |
|---|---|
| Basic rope | Simple rope configuration |
| Dynamic bridges | Bridge construction with rope physics |
| Grappling hooks | Hook and swing mechanics |
| Pulley systems | Rope-based pulley setups |
| Towing mechanics | Attach and tow objects |
| Dynamic lighting | Ropes with lighting effects |

---

## Documentation

Comprehensive documentation is available:

- [Getting Started](docs/getting_started.md) - Installation and basic setup
- [API Reference](docs/api_reference.md) - Complete reference for all classes, methods, and properties
- [Configuration Guide](docs/configuration.md) - Detailed configuration options
- [Advanced Usage](docs/advanced_usage.md) - In-depth technical details
- [Example Implementations](docs/examples.md) - Common use case implementations
- [Performance Optimization](docs/performance.md) - Tips for maximum performance
- [Troubleshooting Guide](docs/troubleshooting.md) - Solutions for common issues

---

## Contributing

Contributions are welcome! Check the [GitHub issues](https://github.com/Lost-Rabbit-Digital/pixelated_rope_simulation/issues) or submit pull requests.

---

## Credits

Made by [Lost Rabbit Digital](https://github.com/Lost-Rabbit-Digital) · [Discord](https://discord.gg/Y7caBf7gBj)

- [Boden McHale](https://www.bodenmchale.com/) - Programming and Design

### Feature Requests

- **Tangle System** - [@smitner.studio](https://bsky.app/profile/smitner.studio/post/3ljiul5ioqc2o)
- **Collision System** - [@atropos148.bsky.social](https://bsky.app/profile/atropos148.bsky.social/post/3ljhccxiiyc2g)
- **Elastic System** - [@brinegame.bsky.social](https://bsky.app/profile/brinegame.bsky.social/post/3ljgyh6d5lc2x)

MPL-2.0 — see [LICENSE](LICENSE.md)
