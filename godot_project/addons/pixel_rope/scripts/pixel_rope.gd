@tool
extends EditorPlugin

# Register custom node
const rope_node = preload("res://addons/pixel_rope/scripts/nodes/rope_node.gd")

func _enter_tree() -> void:
	# Error handling when loading the script
	if rope_node != null:
		print("PixelRope plugin initialized")
	else:
		push_error("PixelRope plugin: Could not load required resources")

func _exit_tree() -> void:
	# Clean-up
	remove_custom_type("PixelRope")
	print("PixelRope plugin disabled")
