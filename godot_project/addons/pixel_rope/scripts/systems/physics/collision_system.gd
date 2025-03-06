@tool
class_name CollisionSystem
extends RefCounted

# Process collisions for rope segments
func process_collisions(
	segments: Array[RopeSegment],
	collision_data: RopeCollision,
	physics_state: PhysicsDirectSpaceState2D
) -> void:
	# Clear last frame's collisions
	collision_data.last_collisions.clear()
	
	# Early return checks
	if not physics_state or segments.is_empty() or collision_data.collision_shapes.is_empty():
		return
	
	# Check collisions for each segment
	for i in range(min(segments.size(), collision_data.collision_shapes.size())):
		var segment = segments[i]
		
		# Skip locked or grabbed segments
		if segment.is_locked or segment.is_grabbed:
			continue
			
		# Set up query for this segment
		collision_data.collision_query.shape = collision_data.collision_shapes[i]
		collision_data.collision_query.transform = Transform2D(0, segment.position)
		
		# Get collision data
		var rest_info = physics_state.get_rest_info(collision_data.collision_query)
		
		# Check if we have any collision data
		if rest_info.is_empty() or not rest_info.has("point") or not rest_info.has("normal"):
			continue
		
		# Extract collision information
		var collision_point = rest_info["point"]
		var collision_normal = rest_info["normal"]
		
		# Store collision data for debugging
		collision_data.last_collisions[i] = {
			"position": collision_point,
			"normal": collision_normal
		}
		
		# Calculate response
		var penetration_depth = collision_data.collision_radius - (segment.position - collision_point).length()
		if penetration_depth > 0:
			# Movement vector
			var movement_vec = segment.position - segment.old_position
			
			# Calculate reflection vector
			var reflection = movement_vec.bounce(collision_normal)
			
			# Apply bounce and friction
			var velocity = reflection * collision_data.collision_bounce
			
			# Calculate friction
			var normal_component = collision_normal * velocity.dot(collision_normal)
			var tangent_component = velocity - normal_component
			tangent_component *= (1.0 - collision_data.collision_friction)
			
			# Final velocity
			velocity = normal_component + tangent_component
			
			# Move segment out of collision
			segment.position = collision_point + (collision_normal * (collision_data.collision_radius + 0.1))
			
			# Update old position to reflect bounce
			segment.old_position = segment.position - velocity
