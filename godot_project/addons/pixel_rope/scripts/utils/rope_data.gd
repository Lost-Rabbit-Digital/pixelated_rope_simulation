@tool
class_name RopeData
extends RefCounted

## Data structure for rope segment information
class RopeSegment:
	var position: Vector2
	var old_position: Vector2
	var is_locked: bool = false
	var velocity: Vector2 = Vector2.ZERO
	var mass: float = 1.0
	var is_grabbed: bool = false
	
	func _init(pos: Vector2, locked: bool = false, seg_mass: float = 1.0) -> void:
		position = pos
		old_position = pos
		is_locked = locked
		mass = seg_mass

## Rope segment storage
var segments: Array[RopeSegment] = []
var segment_length: float = 25.0
var segment_count: int = 30

## Initialize rope segments between two points
func initialize(start_pos: Vector2, end_pos: Vector2, count: int, length: float,
				dynamic_start: bool = false, dynamic_end: bool = false,
				anchor_mass: float = 1.0) -> void:
	segment_count = count
	segment_length = length
	segments.clear()
	
	# Calculate initial segment distribution
	var step_vector: Vector2 = (end_pos - start_pos) / float(count)
	
	for i in range(count + 1):
		var pos: Vector2 = start_pos + step_vector * float(i)
		
		# Determine if segment is locked based on dynamic anchor settings
		var is_locked = false
		if i == 0:  # Start anchor
			is_locked = not dynamic_start
		elif i == count:  # End anchor
			is_locked = not dynamic_end
		
		# Different mass for anchor points
		var mass = 1.0
		if i == 0 or i == count:
			mass = anchor_mass
			
		var segment = RopeSegment.new(pos, is_locked, mass)
		segments.append(segment)
		
	return self

## Get a copy of the segment positions for rendering
func get_positions() -> Array[Vector2]:
	var positions: Array[Vector2] = []
	for segment in segments:
		positions.append(segment.position)
	return positions

## Update segment lock states
func update_lock_states(dynamic_start: bool, dynamic_end: bool) -> void:
	if segments.is_empty():
		return
		
	segments[0].is_locked = not dynamic_start
	segments[segment_count].is_locked = not dynamic_end
	
## Calculate the total length of the rope
func calculate_total_length() -> float:
	var total_length: float = 0.0
	
	for i in range(segment_count):
		var dist: float = segments[i].position.distance_to(segments[i+1].position)
		total_length += dist
		
	return total_length

## Get the ideal length based on segment length and count
func get_ideal_length() -> float:
	return segment_length * segment_count
