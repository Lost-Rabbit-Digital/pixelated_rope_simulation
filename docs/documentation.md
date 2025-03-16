# PixelRope Documentation

![PixelRope Banner](https://img.shields.io/badge/Godot-4.4-blue) ![License](https://img.shields.io/badge/license-MPL--2.0-green) ![Version](https://img.shields.io/badge/version-1.0.0-orange)

## Table of Contents

1. [Introduction](#introduction)
2. [Documentation Structure](#documentation-structure)
3. [Core Components](#core-components)
4. [Next Steps](#next-steps)
5. [License](#license)
6. [Attributions](#attributions)

## Introduction

PixelRope is a high-performance, pixel-perfect rope simulation plugin for Godot 4.4. It provides a complete solution for creating physically simulated ropes with authentic pixelated rendering, making it ideal for retro-style games, platformers, puzzles, and any project requiring interactive rope mechanics.

Key features include:
- Pixel-perfect rendering with multiple line algorithms (Bresenham and DDA)
- Realistic physics with verlet integration and customizable properties
- Entity Component System (ECS) friendly design for optimal performance
- Full interaction support with grabbing, breaking, and dynamic anchors
- Visual customization with adjustable pixel size, spacing, and colors
- Collision detection with environment objects

## Documentation Structure

The PixelRope documentation is organized into the following specialized documents:

* [Getting Started](getting_started.md) - Installation and basic setup guide
* [API Reference](api_reference.md) - Complete reference for all classes, methods, signals, and enums
* [Configuration](configuration.md) - Detailed explanation of all configurable properties
* [Advanced Usage](advanced_usage.md) - Deep dives into the physics system, interaction, and rendering
* [Examples](examples.md) - Implementation examples and common use cases
* [Performance](performance.md) - Optimization tips and best practices
* [Troubleshooting](troubleshooting.md) - Solutions to common issues and debugging techniques

## Core Components

PixelRope is built around three primary components:

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

See the [API Reference](api_reference.md) for complete details on these components.

## Next Steps

* If you're new to PixelRope, start with the [Getting Started](getting_started.md) guide
* For property configuration options, check the [Configuration](configuration.md) document
* To implement common patterns like grappling hooks or bridges, see the [Examples](examples.md) document
* For troubleshooting help, refer to the [Troubleshooting](troubleshooting.md) guide
* To maximize performance, review the [Performance](performance.md) document

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

For more information, see [attributions.md](../information/ATTRIBUTIONS.md).