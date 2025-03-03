@tool
extends EditorPlugin

# Use direct script references instead of preloads
func _enter_tree() -> void:
	# Register custom node
	var script = load("res://addons/pixel_rope/scripts/nodes/rope_node.gd")
	var icon = load("res://addons/pixel_rope/icons/debug_yellow.png")
	
	if script != null and icon != null:
		add_custom_type("PixelRope", "Node2D", script, icon)
		print("PixelRope plugin initialized")
	else:
		push_error("PixelRope plugin: Could not load required resources")

func _exit_tree() -> void:
	# Clean-up
	remove_custom_type("PixelRope")
	print("PixelRope plugin disabled")
