class_name RopePropertyManager
extends RefCounted

# Update anchor properties
static func update_anchor_properties(
	start_anchor: Node2D, 
	end_anchor: Node2D,
	radius: float,
	color: Color
) -> void:
	if start_anchor and start_anchor is RopeAnchor:
		start_anchor.radius = radius
		start_anchor.debug_color = color
	
	if end_anchor and end_anchor is RopeAnchor:
		end_anchor.radius = radius
		end_anchor.debug_color = color

# Update anchor visibility
static func update_anchor_visibility(
	start_anchor: Node2D, 
	end_anchor: Node2D,
	show_debug: bool
) -> void:
	if start_anchor and start_anchor is RopeAnchor:
		start_anchor.show_debug_shape = show_debug
	
	if end_anchor and end_anchor is RopeAnchor:
		end_anchor.show_debug_shape = show_debug

# Update segment lock states based on dynamic anchor settings
static func update_segment_lock_states(
	segments: Array[RopeSegment],
	segment_count: int,
	dynamic_start: bool,
	dynamic_end: bool
) -> void:
	if segments.is_empty():
		return
	
	# Update start anchor
	if segments.size() > 0:
		segments[0].is_locked = not dynamic_start
	
	# Update end anchor
	if segments.size() > segment_count:
		segments[segment_count].is_locked = not dynamic_end
