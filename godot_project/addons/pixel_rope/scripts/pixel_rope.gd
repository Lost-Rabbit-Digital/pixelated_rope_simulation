# addons/pixel_rope/scripts/pixel_rope.gd
@tool
## A high-performance pixel-perfect rope simulation node
## 
## Implements rope physics using multiple line drawing algorithms for accurate
## pixel rendering. Features include configurable tension, gravity effects,
## collision detection, and anchoring points. Ideal for platformers, puzzle
## games, and any project requiring interactive rope mechanics.
extends EditorPlugin

# Register custom node types
const rope_node_script = preload("res://addons/pixel_rope/scripts/nodes/rope_node.gd")
const rope_anchor_script = preload("res://addons/pixel_rope/scripts/nodes/rope_anchor.gd")

func _enter_tree() -> void:
	# Add custom types with icons
	add_custom_type(
		"PixelRope", 
		"Node2D", 
		rope_node_script, 
		preload("res://addons/pixel_rope/icons/Curve2D.svg")
	)
	
	add_custom_type(
		"RopeAnchor", 
		"Node2D", 
		rope_anchor_script, 
		preload("res://addons/pixel_rope/icons/CircleShape2D.svg")
	)
	
	print("PixelRope plugin initialized with ECS architecture")

func _exit_tree() -> void:
	# Clean-up
	remove_custom_type("PixelRope")
	remove_custom_type("RopeAnchor")
	
	print("PixelRope plugin disabled")

# Handle selection changes in the editor
func _edit(object) -> void:
	if object is PixelRope:
		# Force a redraw when selected
		object.queue_redraw()
