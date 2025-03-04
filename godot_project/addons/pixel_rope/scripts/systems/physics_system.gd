# addons/pixel_rope/scripts/systems/physics_system.gd
@tool
class_name RopePhysicsSystem
extends RefCounted

## Apply verlet integration physics to rope segments
static func update_physics(rope_data: RopeData, delta: float, gravity: Vector2, 
						  damping: float, iterations: int, anchor_gravity: Vector2 = Vector2.ZERO,
						  anchor_jitter: float = 0.0) -> void:
	# Skip if no segments
	if rope_data.segments.is_empty():
		return
		
	# Apply verlet integration to each segment
	for i in range(rope_data.segments.size()):
		var segment = rope_data.segments[i]
		
		# Skip locked or grabbed segments
		if segment.is_locked or segment.is_grabbed:
			continue
			
		var temp: Vector2 = segment.position
		var velocity: Vector2 = segment.position - segment.old_position
		
		# Apply forces based on segment type
		var segment_gravity = gravity
		var segment_damping = damping
		
		# Use custom gravity for anchors if provided
		if (i == 0 or i == rope_data.segment_count) and anchor_gravity != Vector2.ZERO:
			segment_gravity = anchor_gravity
		
		# Apply random jitter to dynamic anchors
		if anchor_jitter > 0 and (i == 0 or i == rope_data.segment_count):
			velocity += Vector2(
				randf_range(-anchor_jitter, anchor_jitter),
				randf_range(-anchor_jitter, anchor_jitter)
			)
		
		# Apply forces with mass factoring
		segment.position += velocity * segment_damping + segment_gravity * delta * delta / segment.mass
		segment.old_position = temp
	
	# Apply constraints multiple times for stability
	for _i in range(iterations):
		_apply_constraints(rope_data)

## Apply distance constraints between segments
static func _apply_constraints(rope_data: RopeData) -> void:
	for i in range(rope_data.segment_count):
		var segment1 = rope_data.segments[i]
		var segment2 = rope_data.segments[i + 1]
		
		var current_vec: Vector2 = segment2.position - segment1.position
		var current_dist: float = current_vec.length()
		
		if current_dist < 2.0:
			current_dist = 2.0
		
		var difference: float = rope_data.segment_length - current_dist
		var percent: float = difference / current_dist
		var correction: Vector2 = current_vec * percent
		
		# Apply position correction - weight by mass for more realistic movement
		var mass_ratio1 = segment2.mass / (segment1.mass + segment2.mass)
		var mass_ratio2 = segment1.mass / (segment1.mass + segment2.mass)
		
		if not segment1.is_locked:
			segment1.position -= correction * mass_ratio1
			
		if not segment2.is_locked:
			segment2.position += correction * mass_ratio2

## Update segment grab position (when dragging segments)
static func update_grab_position(rope_data: RopeData, segment_index: int, 
							   target_pos: Vector2, grab_strength: float = 0.8) -> void:
	if segment_index < 0 or segment_index >= rope_data.segments.size():
		return
		
	var segment = rope_data.segments[segment_index]
	
	# Apply grab strength to make dragging feel more responsive
	segment.position = segment.position.lerp(target_pos, grab_strength)
	segment.old_position = segment.position
