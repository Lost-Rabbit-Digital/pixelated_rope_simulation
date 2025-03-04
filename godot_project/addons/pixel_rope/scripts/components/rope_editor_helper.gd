@tool
class_name RopeEditorHelper
extends RefCounted

var _last_start_pos: Vector2
var _last_end_pos: Vector2
var _editor_timer: SceneTreeTimer

# Initialize with anchor positions
func _init(start_pos: Vector2, end_pos: Vector2) -> void:
	_last_start_pos = start_pos
	_last_end_pos = end_pos

# Set up a timer for editor updates
func setup_editor_updates(parent: Node, callback: Callable) -> void:
	# Cancel existing timer
	if _editor_timer and not _editor_timer.is_queued_for_deletion():
		if _editor_timer.timeout.is_connected(callback):
			_editor_timer.timeout.disconnect(callback)
		
	# Create new timer
	_editor_timer = parent.get_tree().create_timer(0.05) # 50ms
	_editor_timer.timeout.connect(callback)

# Check if anchors have moved and need update
func check_anchor_movement(
	start_node: Node2D,
	end_node: Node2D
) -> Dictionary:
	var result = {
		"changed": false,
		"start_pos": Vector2.ZERO,
		"end_pos": Vector2.ZERO
	}
	
	if start_node and end_node:
		if start_node.position != _last_start_pos or end_node.position != _last_end_pos:
			# Update stored positions
			_last_start_pos = start_node.position
			_last_end_pos = end_node.position
			
			result.changed = true
			result.start_pos = _last_start_pos
			result.end_pos = _last_end_pos
	
	return result

# Update stored positions
func update_positions(start_pos: Vector2, end_pos: Vector2) -> void:
	_last_start_pos = start_pos
	_last_end_pos = end_pos
