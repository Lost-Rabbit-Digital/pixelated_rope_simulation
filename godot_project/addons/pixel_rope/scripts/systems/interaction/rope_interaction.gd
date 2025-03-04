@tool
class_name RopeInteraction
extends RefCounted

# Interaction state
var _is_dragging: bool = false
var _hover_segment_index: int = -1
var _grabbed_segment_index: int = -1
var _grab_offset: Vector2 = Vector2.ZERO
var _segment_areas: Array[Area2D] = []

# Process rope segment interaction
func process_segment_interaction(
	event: InputEvent,
	segments: Array[RopeSegment],
	grab_strength: float
) -> Dictionary:
	var result = {
		"interaction_occurred": false,
		"segment_grabbed": -1,
		"segment_released": false
	}
	
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			# Start dragging a segment
			if _hover_segment_index >= 0:
				_is_dragging = true
				_grabbed_segment_index = _hover_segment_index
				segments[_grabbed_segment_index].grab()
				
				# Calculate grab offset
				var mouse_pos = _get_global_mouse_position()
				_grab_offset = segments[_grabbed_segment_index].position - mouse_pos
				
				result.interaction_occurred = true
				result.segment_grabbed = _grabbed_segment_index
		else:
			# Stop dragging
			if _is_dragging:
				_is_dragging = false
				
				# Reset grab state
				if _grabbed_segment_index >= 0 and _grabbed_segment_index < segments.size():
					segments[_grabbed_segment_index].release()
					_grabbed_segment_index = -1
					
					result.interaction_occurred = true
					result.segment_released = true
	
	if event is InputEventMouseMotion and _is_dragging:
		# Update dragged segment position
		if _grabbed_segment_index >= 0 and _grabbed_segment_index < segments.size():
			var target_pos = _get_global_mouse_position() + _grab_offset
			
			# Apply grab strength to make dragging feel more responsive
			segments[_grabbed_segment_index].position = segments[_grabbed_segment_index].position.lerp(
				target_pos, grab_strength
			)
			segments[_grabbed_segment_index].old_position = segments[_grabbed_segment_index].position
			
			result.interaction_occurred = true
	
	return result

# Helper to get global mouse position
func _get_global_mouse_position() -> Vector2:
	return DisplayServer.mouse_get_position()

# Set up interaction areas for rope segments
func setup_interaction_areas(
	parent: Node2D,
	segments: Array[RopeSegment],
	interaction_width: float
) -> void:
	# Clean up existing areas
	for area in _segment_areas:
		if area:
			area.queue_free()
	_segment_areas.clear()
	
	# We'll create one area for each segment
	for i in range(segments.size() - 1):
		var area = Area2D.new()
		area.name = "SegmentArea_" + str(i)
		
		# Store segment index as metadata
		area.set_meta("segment_index", i)
		
		# Create the collision shape
		var collision = CollisionShape2D.new()
		collision.name = "CollisionShape2D"
		
		# Create a capsule shape for the segment
		var shape = CapsuleShape2D.new()
		shape.radius = interaction_width / 2.0
		
		# Update the shape size and position
		_update_segment_area_shape(i, segments, shape, collision, parent)
		
		collision.shape = shape
		
		area.add_child.call_deferred(collision)
		parent.add_child.call_deferred(area)
		
		# Connect mouse signals
		area.mouse_entered.connect(_on_segment_mouse_entered.bind(i))
		area.mouse_exited.connect(_on_segment_mouse_exited.bind(i))
		
		_segment_areas.append(area)

# Update interaction area shapes
func update_interaction_areas(
	segments: Array[RopeSegment],
	parent: Node2D,
	interaction_width: float
) -> void:
	if segments.is_empty() or _segment_areas.is_empty():
		return
	
	for i in range(_segment_areas.size()):
		var area = _segment_areas[i]
		var collision = area.get_node_or_null("CollisionShape2D")
		
		if collision and collision.shape is CapsuleShape2D:
			var shape = collision.shape as CapsuleShape2D
			shape.radius = interaction_width / 2.0
			_update_segment_area_shape(i, segments, shape, collision, parent)

# Update a single segment area shape and position
func _update_segment_area_shape(
	segment_index: int,
	segments: Array[RopeSegment],
	shape: CapsuleShape2D,
	collision: CollisionShape2D,
	parent: Node2D
) -> void:
	if segment_index >= segments.size() - 1:
		return
	
	# Get the segment points in local coordinates
	var start_pos = parent.to_local(segments[segment_index].position)
	var end_pos = parent.to_local(segments[segment_index + 1].position)
	
	# Calculate the length and angle of the segment
	var segment_vec = end_pos - start_pos
	var segment_length = segment_vec.length()
	var segment_angle = segment_vec.angle()
	
	# Update the capsule height
	shape.height = max(segment_length, 0.1)  # Prevent zero height
	
	# Position and rotate the collision shape
	collision.position = (start_pos + end_pos) / 2.0
	collision.rotation = segment_angle

# Signal handlers
func _on_segment_mouse_entered(segment_index: int) -> void:
	_hover_segment_index = segment_index
	Input.set_default_cursor_shape(Input.CURSOR_POINTING_HAND)

func _on_segment_mouse_exited(segment_index: int) -> void:
	if _hover_segment_index == segment_index:
		_hover_segment_index = -1
		Input.set_default_cursor_shape(Input.CURSOR_ARROW)
