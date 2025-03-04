@tool
class_name RopeFactory
extends RefCounted

# Create a full set of rope segments
static func create_segments(
	start_pos: Vector2,
	end_pos: Vector2,
	segment_count: int,
	segment_length: float,
	dynamic_start: bool,
	dynamic_end: bool,
	anchor_mass: float
) -> Array[RopeSegment]:
	var segments: Array[RopeSegment] = []
	
	# Calculate segment length if not specified
	if segment_length <= 0:
		segment_length = start_pos.distance_to(end_pos) / float(segment_count)
	
	# Create segments
	var step_vector: Vector2 = (end_pos - start_pos) / float(segment_count)
	
	for i in range(segment_count + 1):
		var pos: Vector2 = start_pos + step_vector * float(i)
		
		# Determine if segment is locked based on dynamic anchor settings
		var is_locked = false
		if i == 0:  # Start anchor
			is_locked = not dynamic_start
		elif i == segment_count:  # End anchor
			is_locked = not dynamic_end
		
		var segment_mass = 1.0 if (i > 0 and i < segment_count) else anchor_mass
		
		var segment = RopeSegment.new(pos, i, is_locked, segment_mass)
		segments.append(segment)
	
	return segments

# Create an anchor node
static func create_anchor_node(
	node_name: String,
	position: Vector2,
	radius: float,
	debug_color: Color,
	show_debug: bool,
	position_changed_callback: Callable,
	parent: Node2D
) -> RopeAnchor:
	var anchor = RopeAnchor.new()
	anchor.name = node_name
	anchor.position = position
	
	# Set properties
	anchor.radius = radius
	anchor.debug_color = debug_color
	anchor.show_debug_shape = show_debug
	
	# Connect position change signal
	anchor.position_changed.connect(position_changed_callback.bind(anchor))
	
	parent.add_child.call_deferred(anchor)
	
	# Set ownership in editor
	if Engine.is_editor_hint() and parent.get_tree().edited_scene_root:
		anchor.owner = parent.get_tree().edited_scene_root
	
	return anchor

# Configure collision data
static func setup_collision_data(
	collision_data: RopeCollision,
	radius: float,
	mask: int,
	bounce: float,
	friction: float,
	debug: bool
) -> void:
	collision_data.collision_radius = radius
	collision_data.collision_mask = mask
	collision_data.collision_bounce = bounce
	collision_data.collision_friction = friction
	collision_data.show_collision_debug = debug
