class_name RopeSegment
extends Resource

# Core properties
var position: Vector2
var old_position: Vector2
var velocity: Vector2 = Vector2.ZERO

# Physics properties
var mass: float = 1.0
var is_locked: bool = false
var is_grabbed: bool = false
var index: int = -1

# Create as a data container for more efficient ECS processing
func _init(pos: Vector2 = Vector2.ZERO, idx: int = -1, locked: bool = false, segment_mass: float = 1.0) -> void:
	position = pos
	old_position = pos
	index = idx
	is_locked = locked
	mass = segment_mass

func lock() -> void:
	is_locked = true

func unlock() -> void:
	is_locked = false

func grab() -> void:
	is_grabbed = true

func release() -> void:
	is_grabbed = false
