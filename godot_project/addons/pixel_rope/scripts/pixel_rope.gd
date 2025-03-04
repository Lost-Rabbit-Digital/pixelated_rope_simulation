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
const line_algorithms = preload("res://addons/pixel_rope/scripts/utils/line_algorithms.gd")

# Inspector plugin for handling property changes
var inspector_plugin

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
	
	# Create and add the inspector plugin
	inspector_plugin = RopeInspectorPlugin.new()
	add_inspector_plugin(inspector_plugin)
	
	print("PixelRope plugin initialized")

func _exit_tree() -> void:
	# Clean-up
	remove_custom_type("PixelRope")
	remove_custom_type("RopeAnchor")
	
	# Remove the inspector plugin
	remove_inspector_plugin(inspector_plugin)
	
	print("PixelRope plugin disabled")

# Handle selection changes in the editor
func _edit(object) -> void:
	if object is PixelRope:
		# Force a redraw when selected
		object.queue_redraw()

# Custom inspector plugin to catch property changes
class RopeInspectorPlugin extends EditorInspectorPlugin:
	func _can_handle(object) -> bool:
		return object is PixelRope or object is RopeAnchor
	
	func _parse_property(object, type, name, hint_type, hint_string, usage_flags, wide) -> bool:
		# Add a callback for rope-related properties
		if object is PixelRope:
			var rope_properties = ["start_position", "end_position", "pixel_size", "pixel_spacing", 
								  "segment_count", "segment_length", "rope_color", "line_algorithm"]
			if rope_properties.has(name):
				# Connect to property signals the standard way
				var property = object.get_property_list().filter(func(p): return p.name == name)[0]
				property.connect("changed", Callable(object, "queue_redraw"))
		
		# Also handle anchor properties
		if object is RopeAnchor:
			var anchor_properties = ["position"]
			if anchor_properties.has(name):
				# Instead of using the callback, we'll connect to signals directly
				if object.is_connected("position_changed", Callable(object, "_notify_parent_of_movement")):
					pass
				else:
					object.connect("position_changed", Callable(object, "_notify_parent_of_movement"))
		
		# Return false to let the default inspector handle the property
		return false

# Property change callback for PixelRope
static func _on_property_changed(property, value, object, _edited_property) -> void:
	# Queue a redraw to update the rope
	object.queue_redraw()

# Position change callback for RopeAnchor
static func _on_position_changed(property, value, object, _edited_property) -> void:
	# Find the parent PixelRope and force a redraw
	var parent = object.get_parent()
	if parent is PixelRope:
		parent.queue_redraw()
