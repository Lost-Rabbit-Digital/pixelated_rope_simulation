class_name DebugRenderer
extends RefCounted

# Draw collision debug visualization
func draw_collision_debug(
	canvas: CanvasItem,
	segments: Array[RopeSegment],
	collision_data: RopeCollision
) -> void:
	if not collision_data.show_collision_debug:
		return
		
	# Draw collision shapes for debugging
	var debug_color = Color(1.0, 0.3, 0.3, 0.4)
	
	for i in range(segments.size()):
		var segment = segments[i]
		var pos = canvas.to_local(segment.position)
		
		# Draw circle representing collision shape
		canvas.draw_circle(pos, collision_data.collision_radius, debug_color)
		
		# Draw contact points if any
		if collision_data.last_collisions.has(i):
			var collision_info = collision_data.last_collisions[i]
			
			# Draw contact point
			var contact_point = canvas.to_local(collision_info["position"])
			canvas.draw_circle(contact_point, 2.0, Color.RED)
			
			# Draw normal
			var normal = collision_info["normal"] * 10.0
			canvas.draw_line(contact_point, contact_point + normal, Color.GREEN, 1.0)
