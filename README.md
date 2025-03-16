# PixelRope

![PixelRope Banner](https://img.shields.io/badge/Godot-4.4-blue) ![License](https://img.shields.io/badge/license-MPL--2.0-green) ![Version](https://img.shields.io/badge/version-1.0.0-orange)

A high-performance, pixel-perfect rope simulation plugin for Godot 4.4, featuring realistic physics, customizable rendering, and interactive anchors.

<p align="center">
  <img src="docs/preview.gif" alt="PixelRope Demo" width="600"/>
</p>

## Features

- 📐 **Pixel-perfect rendering** with multiple line algorithms (Bresenham and DDA)
- 🧵 **Realistic physics** with verlet integration
- 🔌 **ECS-friendly** design for optimal performance
- 🎮 **Interactive ropes** with grabbing, breaking, and dynamic anchors
- 🎨 **Visual customization** with adjustable pixel size, spacing, and colors
- 💥 **Collision detection** with environment objects

## Documentation

Comprehensive documentation is available:

- [Getting Started](docs/getting_started.md) - Installation and basic setup
- [API Reference](docs/api_reference.md) - Complete reference for all classes, methods, and properties
- [Configuration Guide](docs/configuration.md) - Detailed configuration options
- [Advanced Usage](docs/advanced_usage.md) - In-depth technical details
- [Example Implementations](docs/examples.md) - Common use case implementations
- [Performance Optimization](docs/performance.md) - Tips for maximum performance
- [Troubleshooting Guide](docs/troubleshooting.md) - Solutions for common issues

## Quick Start

### Installation

#### Method 1: Godot AssetLib (Recommended)

1. Open your Godot project
2. Navigate to AssetLib tab in the top center of the editor
3. Search for "PixelRope"
4. Click on the plugin and press "Download"
5. In the installation dialog, click "Install"
6. Enable the plugin in Project Settings > Plugins

#### Method 2: Manual Installation

1. Download the plugin from this repository
2. Extract the `addons/pixel_rope` folder into your project's `addons` directory
3. Enable the plugin in Project Settings > Plugins

### Basic Usage

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

## Example Scenes

The plugin includes several example scenes demonstrating different use cases:

- Basic rope configuration
- Dynamic bridges
- Grappling hooks
- Pulley systems
- Towing mechanics
- Dynamic lighting

## License

This project is licensed under the [Mozilla Public License Version 2.0](LICENSE.md).

## Contributing

Contributions are welcome! Check the [GitHub issues](https://github.com/Lost-Rabbit-Digital/pixelated_rope_simulation/issues) or submit pull requests.

## Attributions

**Lost Rabbit Digital LLC**  
- [Boden McHale](https://www.bodenmchale.com/) - Programming and Design

### Feature Requests
- **Tangle System** - [@smitner.studio](https://bsky.app/profile/smitner.studio/post/3ljiul5ioqc2o)
- **Collision System** - [@atropos148.bsky.social](https://bsky.app/profile/atropos148.bsky.social/post/3ljhccxiiyc2g)
- **Elastic System** - [@brinegame.bsky.social](https://bsky.app/profile/brinegame.bsky.social/post/3ljgyh6d5lc2x)

## Contact

- BlueSky: https://bsky.app/profile/bodengamedev.bsky.social
- GitHub: https://github.com/Lost-Rabbit-Digital