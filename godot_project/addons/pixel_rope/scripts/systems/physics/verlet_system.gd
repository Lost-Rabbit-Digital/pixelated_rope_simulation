class_name VerletSystem
extends RefCounted

# Apply verlet integration to a collection of segments
func process_segments(
	segments: Array[RopeSegment], 
	gravity: Vector2, 
	damping: float, 
	delta: float,
	anchor_gravity: Vector2 = Vector2.ZERO,
	anchor_jitter: float = 0.0,
	segment_count: int = 0
) -> void:
	for i in range(segments.size()):
		var segment = segments[i]
		
		# Skip locked or grabbed segments
		if segment.is_locked or segment.is_grabbed:
			continue
		
		var temp = segment.position
		var velocity = segment.position - segment.old_position
		
		# Apply different forces to anchors if needed
		var segment_gravity = gravity
		
		# Use custom gravity for anchors if provided
		if (i == 0 or i == segment_count) and anchor_gravity != Vector2.ZERO:
			segment_gravity = anchor_gravity
		
		# Apply random jitter to dynamic anchors
		if anchor_jitter > 0 and (i == 0 or i == segment_count):
			velocity += Vector2(
				randf_range(-anchor_jitter, anchor_jitter),
				randf_range(-anchor_jitter, anchor_jitter)
			)
		
		# Apply forces with mass factoring
		segment.position += velocity * damping + segment_gravity * delta * delta / segment.mass
		segment.old_position = temp
