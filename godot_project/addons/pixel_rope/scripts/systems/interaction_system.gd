# addons/pixel_rope/scripts/systems/interaction_system.gd
@tool
class_name RopeInteractionSystem
extends RefCounted

## Interaction modes
enum GrabMode {
	NONE,        ## No interaction with rope
	ANCHORS_ONLY, ## Only anchor points can be interacted with
	ANY_POINT    ## Any point along the rope can be interacted with
}

## InteractionState class to maintain interaction state
class InteractionState:
	var segment_areas: Array[Area2D] = []
	var is_dragging: bool = false
	var mouse_over_end: bool = false
	var grabbed_segment_index: int = -1
	var hover_segment_index: int = -1
	var grab_offset: Vector2 = Vector2.ZERO
	
	func _init() -> void:
		pass

## Set up interaction areas for rope segments
static func setup_interaction_areas(
	rope_node: Node2D, rope_data: RopeData, 
	interaction_state: InteractionState,
	interaction_mode: int, interaction_width: float,
	show_interaction_areas: bool
) -> void:
	# Clean up existing areas
	for area in interaction_state.segment_areas:
		if area:
			area.queue_free()
	interaction_state.segment_areas.clear()
	
	# If we're not in "any point" interaction mode, stop here
	if interaction_mode != GrabMode.ANY_POINT or rope_data.segments.is_empty():
		return
	
	# We'll create one area for each segment
	for i in range(rope_data.segments.size() - 1):
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
		update_segment_area_shape(
			rope_node, rope_data, i, shape, collision
		)
		
		collision.shape = shape
		
		# Set debug color if needed
		if show_interaction_areas:
			collision.debug_color = Color(0.2, 0.8, 0.2, 0.3)  # Light green, very transparent
		else:
			collision.debug_color = Color(0, 0, 0, 0)  # Fully transparent
		
		area.add_child(collision)
		rope_node.add_child(area)
		
		# Store index in a way we can retrieve it
		area.set_meta("segment_index", i)
		
		interaction_state.segment_areas.append(area)

## Update a single segment area's shape and position
static func update_segment_area_shape(
	rope_node: Node2D, rope_data: RopeData,
	segment_index: int, shape: CapsuleShape2D, collision: CollisionShape2D
) -> void:
	if segment_index >= rope_data.segments.size() - 1:
		return
	
	# Get the segment points in local coordinates
	var start_pos = rope_node.to_local(rope_data.segments[segment_index].position)
	var end_pos = rope_node.to_local(rope_data.segments[segment_index + 1].position)
	
	# Calculate the length and angle of the segment
	var segment_vec = end_pos - start_pos
	var segment_length = segment_vec.length()
	var segment_angle = segment_vec.angle()
	
	# Update the capsule height (needs to account for the rounded ends)
	shape.height = max(segment_length, 0.1)  # Prevent zero height
	
	# Position the collision shape at the midpoint of the segment
	collision.position = (start_pos + end_pos) / 2.0
	
	# Rotate the collision shape to match the segment angle
	collision.rotation = segment_angle

## Update the shapes of all segment areas
static func update_interaction_areas(
	rope_node: Node2D, rope_data: RopeData,
	interaction_state: InteractionState,
	interaction_width: float, show_interaction_areas: bool
) -> void:
	if rope_data.segments.is_empty() or interaction_state.segment_areas.is_empty():
		return
	
	for i in range(interaction_state.segment_areas.size()):
		var area = interaction_state.segment_areas[i]
		var collision = area.get_node_or_null("CollisionShape2D")
		
		if collision and collision.shape is CapsuleShape2D:
			var shape = collision.shape as CapsuleShape2D
			shape.radius = interaction_width / 2.0
			update_segment_area_shape(
				rope_node, rope_data, i, shape, collision
			)
			
			# Update debug color
			if show_interaction_areas:
				collision.debug_color = Color(0.2, 0.8, 0.2, 0.3)
			else:
				collision.debug_color = Color(0, 0, 0, 0)

## Update visibility of interaction areas
static func update_interaction_areas_visibility(
	interaction_state: InteractionState,
	show_interaction_areas: bool
) -> void:
	for area in interaction_state.segment_areas:
		var collision = area.get_node_or_null("CollisionShape2D")
		if collision:
			if show_interaction_areas:
				collision.debug_color = Color(0.2, 0.8, 0.2, 0.3)
			else:
				collision.debug_color = Color(0, 0, 0, 0)

## Process dragging logic
static func process_dragging(
	rope_node: Node2D, rope_data: RopeData,
	interaction_state: InteractionState,
	end_node: Node2D, end_node_dynamic: bool,
	grab_strength: float
) -> void:
	if not interaction_state.is_dragging:
		return
		
	if interaction_state.grabbed_segment_index >= 0 and interaction_state.grabbed_segment_index < rope_data.segments.size():
		# Dragging a rope segment
		var target_pos = rope_node.get_global_mouse_position() + interaction_state.grab_offset
		
		# Apply grab strength to make dragging feel more responsive
		RopePhysicsSystem.update_grab_position(
			rope_data, 
			interaction_state.grabbed_segment_index, 
			target_pos, 
			grab_strength
		)
	elif interaction_state.mouse_over_end and not end_node_dynamic:
		# Dragging the end anchor
		end_node.global_position = rope_node.get_global_mouse_position()
		if rope_data.segments.size() > 0:
			rope_data.segments[rope_data.segment_count].position = end_node.global_position

## Set up the end node for dragging
static func setup_draggable_node(end_node: Node2D) -> void:
	# Use Area2D for mouse interaction
	var area: Area2D
	
	# Check if the node already has an Area2D child
	for child in end_node.get_children():
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
		area.add_child(collision)
		end_node.add_child(area)
