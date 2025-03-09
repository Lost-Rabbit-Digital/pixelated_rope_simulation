@tool
class_name RopeCollision
extends Resource

# Collision properties
var collision_mask: int = 1
var collision_bounce: float = 0.3
var collision_friction: float = 0.7
var collision_radius: float = 4.0
var show_collision_debug: bool = false

# Collision state
var collision_shapes: Array[CircleShape2D] = []
var collision_query: PhysicsShapeQueryParameters2D
var last_collisions: Dictionary = {}

func _init(radius: float = 4.0, mask: int = 1) -> void:
	collision_radius = radius
	collision_mask = mask
	
	# Initialize physics query parameters
	collision_query = PhysicsShapeQueryParameters2D.new()
	collision_query.collision_mask = collision_mask
	collision_query.margin = 2.0

func create_shapes_for_segments(segment_count: int) -> void:
	collision_shapes.clear()
	
	for i in range(segment_count):
		var shape = CircleShape2D.new()
		shape.radius = collision_radius
		collision_shapes.append(shape)

func update_all_shapes() -> void:
	for shape in collision_shapes:
		shape.radius = collision_radius
