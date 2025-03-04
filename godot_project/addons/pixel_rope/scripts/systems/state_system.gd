# addons/pixel_rope/scripts/systems/state_system.gd
@tool
class_name RopeStateSystem
extends RefCounted

## Rope state enums
enum RopeState {
	NORMAL,
	STRETCHED,
	BROKEN
}

## Check and update the rope state
## Returns a tuple of [current_state, is_broken, state_changed]
static func check_rope_state(rope_data: RopeData, max_stretch_factor: float, 
							current_state: int, is_broken: bool) -> Array:
	var total_length = rope_data.calculate_total_length()
	var ideal_length = rope_data.get_ideal_length()
	
	var stretch_factor: float = total_length / ideal_length
	var new_state = current_state
	var new_broken = is_broken
	var state_changed = false
	
	if stretch_factor >= max_stretch_factor:
		new_state = RopeState.BROKEN
		new_broken = true
		state_changed = new_state != current_state
	elif stretch_factor >= max_stretch_factor * 0.8:
		new_state = RopeState.STRETCHED
		state_changed = new_state != current_state
	else:
		new_state = RopeState.NORMAL
		state_changed = new_state != current_state
		
	return [new_state, new_broken, state_changed]

## Forcibly break the rope
static func break_rope() -> Array:
	return [RopeState.BROKEN, true, true]

## Reset the rope state
static func reset_state() -> Array:
	return [RopeState.NORMAL, false, true]
