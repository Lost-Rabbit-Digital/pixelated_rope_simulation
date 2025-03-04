@tool
## A high-performance pixel-perfect rope simulation node
## 
## Implements rope physics using multiple line drawing algorithms for accurate
## pixel rendering. Features include configurable tension, gravity effects,
## collision detection, and anchoring points. Ideal for platformers, puzzle
## games, and any project requiring interactive rope mechanics.
extends EditorPlugin

# Register custom node types
const rope_node_script = preload("res://addons/pixel_rope/scripts/components/rope_node.gd")
const rope_anchor_script = preload("res://addons/pixel_rope/scripts/components/rope_anchor.gd")
const line_algorithms = preload("res://addons/pixel_rope/scripts/utils/line_algorithms.gd")

# Preload components and systems
const rope_segment_script = preload("res://addons/pixel_rope/scripts/components/rope_segment.gd")
const rope_collision_script = preload("res://addons/pixel_rope/scripts/components/rope_collision.gd")
const verlet_system_script = preload("res://addons/pixel_rope/scripts/systems/physics/verlet_system.gd")
const constraint_system_script = preload("res://addons/pixel_rope/scripts/systems/physics/constraint_system.gd")
const collision_system_script = preload("res://addons/pixel_rope/scripts/systems/physics/collision_system.gd")
const line_renderer_script = preload("res://addons/pixel_rope/scripts/systems/rendering/line_renderer.gd")
const debug_renderer_script = preload("res://addons/pixel_rope/scripts/systems/rendering/debug_renderer.gd")
const anchor_interaction_script = preload("res://addons/pixel_rope/scripts/systems/interaction/anchor_interaction.gd")
const rope_interaction_script = preload("res://addons/pixel_rope/scripts/systems/interaction/rope_interaction.gd")
const signal_manager_script = preload("res://addons/pixel_rope/scripts/utils/signal_manager.gd")

# ... rest of the plugin code
