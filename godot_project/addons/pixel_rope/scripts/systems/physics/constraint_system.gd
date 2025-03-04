class_name ConstraintSystem
extends RefCounted

# Apply distance constraints between segments
func apply_constraints(
	segments: Array[RopeSegment], 
	segment_length: float, 
	iterations: int
) -> void:
	for _i in range(iterations):
		for i in range(segments.size() - 1):
			var segment1 = segments[i]
			var segment2 = segments[i + 1]
			
			var current_vec = segment2.position - segment1.position
			var current_dist = current_vec.length()
			
			if current_dist < 0.01:  # Prevent division by zero
				current_dist = 0.01
				
			var difference = segment_length - current_dist
			var percent = difference / current_dist
			var correction = current_vec * percent
			
			# Mass factors for more realistic movement
			var mass_ratio1 = segment2.mass / (segment1.mass + segment2.mass)
			var mass_ratio2 = segment1.mass / (segment1.mass + segment2.mass)
			
			if not segment1.is_locked:
				segment1.position -= correction * mass_ratio1
				
			if not segment2.is_locked:
				segment2.position += correction * mass_ratio2
