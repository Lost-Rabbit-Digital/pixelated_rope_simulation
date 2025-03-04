class_name SignalManager
extends RefCounted

# Centralized signal handling
signal rope_broken
signal rope_grabbed(segment_index: int)
signal rope_released
signal state_changed(new_state: int)

# Tracked state
var _current_state: int = 0
var _broken: bool = false

# Emit signals based on rope state
func check_rope_state(
	segments: Array[RopeSegment],
	segment_length: float,
	segment_count: int,
	max_stretch_factor: float
) -> Dictionary:
	var total_length: float = 0.0
	var ideal_length: float = segment_length * segment_count
	
	for i in range(segment_count):
		var dist: float = segments[i].position.distance_to(segments[i + 1].position)
		total_length += dist
	
	var stretch_factor: float = total_length / ideal_length
	var old_state = _current_state
	
	if stretch_factor >= max_stretch_factor:
		_current_state = 2  # BROKEN
		if not _broken:
			_broken = true
			rope_broken.emit()
	elif stretch_factor >= max_stretch_factor * 0.8:
		_current_state = 1  # STRETCHED
	else:
		_current_state = 0  # NORMAL
	
	# Emit state change if needed
	if old_state != _current_state:
		state_changed.emit(_current_state)
	
	return {
		"state": _current_state,
		"broken": _broken,
		"stretch_factor": stretch_factor
	}

# Reset the rope state
func reset_state() -> void:
	_broken = false
	_current_state = 0
	state_changed.emit(_current_state)
