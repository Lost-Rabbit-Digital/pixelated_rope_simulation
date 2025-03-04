class_name AnchorInteraction
extends RefCounted

# Interaction state
var _is_dragging: bool = false
var _mouse_over_end: bool = false
var _grab_offset: Vector2 = Vector2.ZERO

# Handle anchor dragging
func process_anchor_interaction(
	event: InputEvent,
	end_anchor: Node2D,
	dynamic_end_anchor: bool,
	segments: Array[RopeSegment],
	segment_count: int
) -> bool:
	var interaction_occurred = false
	
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			# Start dragging end anchor
			if _mouse_over_end and not dynamic_end_anchor:
				_is_dragging = true
				_grab_offset = end_anchor.global_position - _get_global_mouse_position()
				interaction_occurred = true
		else:
			# Stop dragging
			if _is_dragging:
				_is_dragging = false
				interaction_occurred = true
	
	if event is InputEventMouseMotion and _is_dragging:
		# Update position while dragging
		if not dynamic_end_anchor:
			end_anchor.global_position = _get_global_mouse_position() + _grab_offset
			if segment_count < segments.size():
				segments[segment_count].position = end_anchor.global_position
			interaction_occurred = true
	
	return interaction_occurred

# Setup anchor for dragging
func setup_draggable_anchor(node: Node2D) -> void:
	# Use Area2D for mouse interaction
	var area: Area2D
	
	# Check if the node already has an Area2D child
	for child in node.get_children():
		if child is Area2D:
			area = child
			break
	
	# If no Area2D exists, create one
	if not area:
		area = Area2D.new()
		var collision = CollisionShape2D.new()
		var shape = CircleShape2D.new()
		shape.radius = 15.0  # Larger hitbox
		collision.shape = shape
		area.add_child.call_deferred(collision)
		node.add_child.call_deferred(area)
	
	# Connect signals to the Area2D
	if not area.mouse_entered.is_connected(_on_anchor_mouse_entered):
		area.mouse_entered.connect(_on_anchor_mouse_entered)
	if not area.mouse_exited.is_connected(_on_anchor_mouse_exited):
		area.mouse_exited.connect(_on_anchor_mouse_exited)

# Helper to get global mouse position
func _get_global_mouse_position() -> Vector2:
	return DisplayServer.mouse_get_position()

# Signal handlers
func _on_anchor_mouse_entered() -> void:
	_mouse_over_end = true
	Input.set_default_cursor_shape(Input.CURSOR_POINTING_HAND)

func _on_anchor_mouse_exited() -> void:
	_mouse_over_end = false
	Input.set_default_cursor_shape(Input.CURSOR_ARROW)
