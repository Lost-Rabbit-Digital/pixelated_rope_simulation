@tool
@icon("res://addons/pixel_rope/icons/Curve2D.svg")
## A physically-simulated, pixel-perfect rope with multiple rendering algorithms
##
## Implements a complete rope physics system using verlet integration with
## configurable properties including segment count, length, gravity, and tension.
## Features pixelated rendering using either Bresenham or DDA line algorithms for
## authentic retro visuals. Supports dynamic interaction with breakable ropes,
## stretch detection, and drag-and-drop functionality along any point of the rope.
extends Node2D
class_name PixelRope

# Signals
signal rope_broken
signal rope_grabbed(segment_index: int)
signal rope_released

# Enums
enum RopeState {
	NORMAL,
	STRETCHED,
	BROKEN
}

enum GrabMode {
	NONE,        ## No interaction with rope
	ANCHORS_ONLY, ## Only anchor points can be interacted with
	ANY_POINT    ## Any point along the rope can be interacted with
}

# Export variables for inspector
@export_group("Rope Properties")
@export var segment_count: int = 30:
	set(value):
		segment_count = value
		if Engine.is_editor_hint():
			queue_redraw()

@export var segment_length: float = 25.0:
	set(value):
		segment_length = value
		if Engine.is_editor_hint():
			queue_redraw()

@export var rope_color: Color = Color(0.8, 0.6, 0.2):
	set(value):
		rope_color = value
		if Engine.is_editor_hint():
			queue_redraw()

@export_group("Pixelation Properties")
@export var pixel_size: int = 4:
	set(value):
		pixel_size = value
		if Engine.is_editor_hint():
			queue_redraw()

@export var pixel_spacing: int = 0:
	set(value):
		pixel_spacing = value
		if Engine.is_editor_hint():
			queue_redraw()

## Algorithm to use for drawing the rope line
@export var line_algorithm: LineAlgorithms.LineAlgorithmType = LineAlgorithms.LineAlgorithmType.BRESENHAM:
	set(value):
		line_algorithm = value
		if Engine.is_editor_hint():
			queue_redraw()

@export_group("Physics Properties")
@export var gravity: Vector2 = Vector2(0, 980)
@export var damping: float = 0.98
@export var iterations: int = 5
@export var max_stretch_factor: float = 1.5

@export_group("Anchor Properties")
@export var start_position: Vector2 = Vector2(-100, 0):
	set(value):
		start_position = value
		if _start_node:
			_start_node.position = value
		if Engine.is_editor_hint():
			queue_redraw()

@export var end_position: Vector2 = Vector2(100, 0):
	set(value):
		end_position = value
		if _end_node:
			_end_node.position = value
		if Engine.is_editor_hint():
			queue_redraw()

@export var anchor_radius: float = 8.0:
	set(value):
		anchor_radius = value
		_update_anchor_properties()
		if Engine.is_editor_hint():
			queue_redraw()

@export var anchor_debug_color: Color = Color(0.7, 0.7, 1.0, 0.5):
	set(value):
		anchor_debug_color = value
		_update_anchor_properties()
		if Engine.is_editor_hint():
			queue_redraw()

@export var show_anchor_debug: bool = true:
	set(value):
		show_anchor_debug = value
		_update_anchor_debug_visualization()

# New properties for dynamic anchors
@export_group("Dynamic Anchors")
## Makes the start anchor dynamic (affected by physics forces)
@export var dynamic_start_anchor: bool = false:
	set(value):
		dynamic_start_anchor = value
		_update_segment_lock_states()

## Makes the end anchor dynamic (affected by physics forces)
@export var dynamic_end_anchor: bool = false:
	set(value):
		dynamic_end_anchor = value
		_update_segment_lock_states()

## Mass factor for dynamic anchors (affects how strongly forces act on them)
@export_range(0.1, 10.0) var anchor_mass: float = 1.0

## Applies a small random force to dynamic anchors each frame for more natural movement
@export var anchor_jitter: float = 0.0

## Optional custom gravity for dynamic anchors that overrides the main gravity
@export var anchor_gravity: Vector2 = Vector2.ZERO

@export_group("Collision Properties")
## Enable collisions between rope segments and the environment
@export var enable_collisions: bool = false:
	set(value):
		enable_collisions = value
		_setup_collision_detection()

## Layers the rope will detect collisions with
@export_flags_2d_physics var collision_mask: int = 1

## Bounce factor when collision occurs (0 = no bounce, 1 = full bounce)
@export_range(0.0, 1.0) var collision_bounce: float = 0.3

## Friction factor when sliding along surfaces (0 = no friction, 1 = maximum friction)
@export_range(0.0, 1.0) var collision_friction: float = 0.7

## Radius of each rope segment for collision detection
@export_range(1.0, 20.0) var collision_radius: float = 4.0:
	set(value):
		collision_radius = value
		_update_collision_shapes()

## Enable debug visualization of collision shapes
@export var show_collision_debug: bool = true:
	set(value):
		show_collision_debug = value
		_update_collision_debug()

@export_group("Interaction Properties")
## Control how the rope can be interacted with
@export var interaction_mode: GrabMode = GrabMode.ANY_POINT:
	set(value):
		interaction_mode = value
		_setup_interaction_areas()

## Width of the interaction area around the rope (in pixels)
@export_range(5.0, 50.0) var interaction_width: float = 20.0:
	set(value):
		interaction_width = value
		_update_interaction_areas()

## How strongly the rope segment being held is pulled toward mouse position
@export_range(0.1, 1.0) var grab_strength: float = 0.8

## If true, end anchor can be dragged like before
@export var end_anchor_draggable: bool = true

# Private variables
var _start_node: Node2D
var _end_node: Node2D
var _segments: Array[Dictionary] = []
var _state: RopeState = RopeState.NORMAL
var _broken: bool = false
var _initialized: bool = false
var _last_start_pos: Vector2
var _last_end_pos: Vector2

# Collision detection variables
var _physics_direct_state: PhysicsDirectSpaceState2D = null
var _segment_collision_shapes: Array[CircleShape2D] = []
var _collision_query: PhysicsShapeQueryParameters2D = null
var _collision_debug_points: Array = []
var _last_collisions: Dictionary = {}  # Tracks last frame's collisions

# Interaction variables
var _segment_areas: Array[Area2D] = []
var _is_dragging: bool = false
var _mouse_over_end: bool = false
var _grabbed_segment_index: int = -1
var _hover_segment_index: int = -1
var _grab_offset: Vector2 = Vector2.ZERO

# Editor-specific variables
var _editor_mode: bool = false
var _editor_timer: SceneTreeTimer

func _setup_collision_detection() -> void:
	if Engine.is_editor_hint():
		return
		
	if not enable_collisions:
		return
	
	# Get the direct space state for collision queries
	_physics_direct_state = get_world_2d().direct_space_state
	
	# Create collision shapes for each segment
	_segment_collision_shapes.clear()
	for i in range(_segments.size()):
		var shape = CircleShape2D.new()
		shape.radius = collision_radius
		_segment_collision_shapes.append(shape)
	
	# Create physics query parameters
	_collision_query = PhysicsShapeQueryParameters2D.new()
	_collision_query.collision_mask = collision_mask
	_collision_query.margin = 2.0  # Small margin to improve collision detection
	
	print("PixelRope: Collision detection initialized")

# Called when the node enters the scene tree
func _ready() -> void:
	# Check if we're in the editor
	_editor_mode = Engine.is_editor_hint()
	
	# Create anchor nodes if they don't exist
	_ensure_anchor_nodes()
	
	# Save initial positions for change detection
	if _start_node and _end_node:
		_last_start_pos = _start_node.position
		_last_end_pos = _end_node.position
	
	# Set up editor update timer
	if _editor_mode:
		_setup_editor_updates()
		queue_redraw()
	else:
		# Initialize in game mode only
		await get_tree().process_frame
		
		# Set up interaction for the end anchor if needed
		if end_anchor_draggable and not dynamic_end_anchor:
			_setup_draggable_node(_end_node)
		
		# Initialize the rope
		_initialize_rope()
		
		# Set up collision detection
		if enable_collisions:
			_setup_collision_detection()
		
		_initialized = true
		
		# Set up segment interaction areas if enabled
		if interaction_mode == GrabMode.ANY_POINT:
			_setup_interaction_areas()

# Update collision shapes if radius changes
func _update_collision_shapes() -> void:
	if _segment_collision_shapes.is_empty():
		return
		
	for shape in _segment_collision_shapes:
		shape.radius = collision_radius

# Toggle debug visualization
func _update_collision_debug() -> void:
	if not enable_collisions:
		return
		
	if not show_collision_debug:
		_collision_debug_points.clear()
	
	# Force redraw to update debug visualization
	queue_redraw()

# Set up a timer for editor updates
func _setup_editor_updates() -> void:
	# Cancel any existing timer
	if _editor_timer and not _editor_timer.is_queued_for_deletion():
		_editor_timer.timeout.disconnect(_check_for_anchor_movement)
		
	# Create a new timer that fires frequently to check for changes
	_editor_timer = get_tree().create_timer(0.05) # 50ms
	_editor_timer.timeout.connect(_check_for_anchor_movement)

# Check if anchors have moved and trigger redraws
func _check_for_anchor_movement() -> void:
	if not _editor_mode:
		return
		
	if _start_node and _end_node:
		if _start_node.position != _last_start_pos or _end_node.position != _last_end_pos:
			# Update stored positions
			_last_start_pos = _start_node.position
			_last_end_pos = _end_node.position
			
			# Update export variables to match current positions
			start_position = _start_node.position
			end_position = _end_node.position
			
			# Redraw rope
			queue_redraw()
	
	# Set up next timer
	_setup_editor_updates()

func _ensure_anchor_nodes() -> void:
	# Handle start anchor
	_start_node = get_node_or_null("StartAnchor") 
	if not _start_node:
		_start_node = _create_anchor_node("StartAnchor", start_position)
	else:
		# Make sure existing node has correct position
		_start_node.position = start_position
		# Connect signal if not already connected
		if _start_node is RopeAnchor and not _start_node.position_changed.is_connected(_on_anchor_position_changed):
			_start_node.position_changed.connect(_on_anchor_position_changed.bind(_start_node))
	
	# Handle end anchor
	_end_node = get_node_or_null("EndAnchor")
	if not _end_node:
		_end_node = _create_anchor_node("EndAnchor", end_position)
	else:
		# Make sure existing node has correct position
		_end_node.position = end_position
		# Connect signal if not already connected
		if _end_node is RopeAnchor and not _end_node.position_changed.is_connected(_on_anchor_position_changed):
			_end_node.position_changed.connect(_on_anchor_position_changed.bind(_end_node))

# Create a new anchor node
func _create_anchor_node(node_name: String, position: Vector2) -> Node2D:
	var anchor = RopeAnchor.new()
	anchor.name = node_name
	anchor.position = position
	
	# Set properties
	anchor.radius = anchor_radius
	anchor.debug_color = anchor_debug_color
	anchor.show_debug_shape = show_anchor_debug
	
	# Connect position change signal
	anchor.position_changed.connect(_on_anchor_position_changed.bind(anchor))
	
	add_child(anchor)
	
	# If this is being run in the editor, ensure the node is properly set up
	if Engine.is_editor_hint() and get_tree().edited_scene_root:
		anchor.owner = get_tree().edited_scene_root
	
	return anchor

# Update anchor properties when changed
func _update_anchor_properties() -> void:
	if _start_node and _start_node is RopeAnchor:
		_start_node.radius = anchor_radius
		_start_node.debug_color = anchor_debug_color
	
	if _end_node and _end_node is RopeAnchor:
		_end_node.radius = anchor_radius
		_end_node.debug_color = anchor_debug_color

func _update_anchor_debug_visualization() -> void:
	if _start_node and _start_node is RopeAnchor:
		_start_node.show_debug_shape = show_anchor_debug
	
	if _end_node and _end_node is RopeAnchor:
		_end_node.show_debug_shape = show_anchor_debug

func _on_anchor_position_changed(anchor: RopeAnchor) -> void:
	if anchor.name == "StartAnchor":
		start_position = anchor.position
	elif anchor.name == "EndAnchor":
		end_position = anchor.position
	queue_redraw()

# Set up a node to be draggable
func _setup_draggable_node(node: Node2D) -> void:
	# Use Area2D for mouse interaction
	var area: Area2D
	
	# Check if the node already has an Area2D child
	for child in node.get_children():
		if child is Area2D:
			area = child
			break
	
	# If no Area2D exists, create one
	if not area:
		area = Area2D.new()
		var collision = CollisionShape2D.new()
		var shape = CircleShape2D.new()
		shape.radius = 15.0  # Larger hitbox
		collision.shape = shape
		area.add_child.call_deferred(collision)
		node.add_child.call_deferred(area)
	
	# Connect signals to the Area2D
	if not area.mouse_entered.is_connected(_on_end_node_mouse_entered):
		area.mouse_entered.connect(_on_end_node_mouse_entered)
	if not area.mouse_exited.is_connected(_on_end_node_mouse_exited):
		area.mouse_exited.connect(_on_end_node_mouse_exited)
	
	print("PixelRope: Draggable node set up for", node.name)

# Initialize the rope segments
func _initialize_rope() -> void:
	_segments.clear()
	
	# Calculate initial segment length if not manually set
	if segment_length <= 0:
		segment_length = _start_node.global_position.distance_to(_end_node.global_position) / float(segment_count)
	
	# Create segments
	var step_vector: Vector2 = (_end_node.global_position - _start_node.global_position) / float(segment_count)
	
	for i in range(segment_count + 1):
		var pos: Vector2 = _start_node.global_position + step_vector * float(i)
		
		# Determine if segment is locked based on dynamic anchor settings
		var is_locked = false
		if i == 0:  # Start anchor
			is_locked = not dynamic_start_anchor
		elif i == segment_count:  # End anchor
			is_locked = not dynamic_end_anchor
		
		_segments.append({
			"position": pos,
			"old_position": pos,
			"is_locked": is_locked,
			"velocity": Vector2.ZERO,  # For additional physics effects
			"mass": 1.0 if (i > 0 and i < segment_count) else anchor_mass,  # Different mass for anchors
			"is_grabbed": false  # New property to track if this segment is being grabbed
		})
	
	print("PixelRope: Created", _segments.size(), "segments with length", segment_length)
	
	# Set up collision detection if enabled
	if enable_collisions and not Engine.is_editor_hint():
		_setup_collision_detection()
	
	_broken = false
	_state = RopeState.NORMAL

# Update the lock state of segments based on dynamic anchor settings
func _update_segment_lock_states() -> void:
	if _segments.is_empty():
		return
	
	# Update start anchor
	if _segments.size() > 0:
		_segments[0].is_locked = not dynamic_start_anchor
	
	# Update end anchor
	if _segments.size() > segment_count:
		_segments[segment_count].is_locked = not dynamic_end_anchor

# Set up interaction areas for rope segments
func _setup_interaction_areas() -> void:
	# Skip in editor mode
	if _editor_mode:
		return
		
	# Clean up existing areas
	for area in _segment_areas:
		if area:
			area.queue_free()
	_segment_areas.clear()
	
	# If we're not in "any point" interaction mode, stop here
	if interaction_mode != GrabMode.ANY_POINT or _segments.is_empty():
		return
	
	# We'll create one area for each segment
	for i in range(_segments.size() - 1):
		var area = Area2D.new()
		area.name = "SegmentArea_" + str(i)
		
		# Store segment index as metadata
		area.set_meta("segment_index", i)
		
		# Create the collision shape
		var collision = CollisionShape2D.new()
		collision.name = "CollisionShape2D"
		
		# Create a capsule shape for the segment
		var shape = CapsuleShape2D.new()
		shape.radius = interaction_width / 2.0
		
		# Update the shape size and position
		_update_segment_area_shape(i, shape, collision)
		
		collision.shape = shape
		
		area.add_child.call_deferred(collision)
		add_child.call_deferred(area)
		
		# Connect mouse signals
		area.mouse_entered.connect(_on_segment_mouse_entered.bind(i))
		area.mouse_exited.connect(_on_segment_mouse_exited.bind(i))
		
		_segment_areas.append(area)
	
	print("PixelRope: Created", _segment_areas.size(), "interaction areas")

# Update the shapes of all segment areas
func _update_interaction_areas() -> void:
	if _segments.is_empty() or _segment_areas.is_empty():
		return
	
	for i in range(_segment_areas.size()):
		var area = _segment_areas[i]
		var collision = area.get_node_or_null("CollisionShape2D")
		
		if collision and collision.shape is CapsuleShape2D:
			var shape = collision.shape as CapsuleShape2D
			shape.radius = interaction_width / 2.0
			_update_segment_area_shape(i, shape, collision)

# Update a single segment area's shape and position
func _update_segment_area_shape(segment_index: int, shape: CapsuleShape2D, collision: CollisionShape2D) -> void:
	if segment_index >= _segments.size() - 1:
		return
	
	# Get the segment points in local coordinates
	var start_pos = to_local(_segments[segment_index].position)
	var end_pos = to_local(_segments[segment_index + 1].position)
	
	# Calculate the length and angle of the segment
	var segment_vec = end_pos - start_pos
	var segment_length = segment_vec.length()
	var segment_angle = segment_vec.angle()
	
	# Update the capsule height (needs to account for the rounded ends)
	shape.height = max(segment_length, 0.1)  # Prevent zero height
	
	# Position the collision shape at the midpoint of the segment
	collision.position = (start_pos + end_pos) / 2.0
	
	# Rotate the collision shape to match the segment angle
	collision.rotation = segment_angle

# Property change handler
func _notification(what: int) -> void:
	if what == NOTIFICATION_EDITOR_PRE_SAVE:
		# Update anchor positions before saving
		if _start_node and _end_node:
			start_position = _start_node.position
			end_position = _end_node.position
			queue_redraw()
	elif what == NOTIFICATION_PATH_RENAMED:
		# Relink nodes if path changed
		_ensure_anchor_nodes()
		queue_redraw()
	# Handle transform changes in the editor
	elif what == NOTIFICATION_TRANSFORM_CHANGED and Engine.is_editor_hint():
		queue_redraw()

# Handle property changes in editor
func _set(property: StringName, value) -> bool:
	if property == "start_position" and _start_node:
		_start_node.position = value
		queue_redraw()
		return true
	elif property == "end_position" and _end_node:
		_end_node.position = value
		queue_redraw()
		return true
	elif property == "anchor_radius" and (_start_node or _end_node):
		if _start_node and _start_node.has_method("set"):
			_start_node.set("radius", value)
		if _end_node and _end_node.has_method("set"):
			_end_node.set("radius", value)
		queue_redraw()
		return true
	elif property == "anchor_color" and (_start_node or _end_node):
		if _start_node and _start_node.has_method("set"):
			_start_node.set("color", value)
		if _end_node and _end_node.has_method("set"):
			_end_node.set("color", value)
		queue_redraw()
		return true
	elif property == "dynamic_start_anchor" or property == "dynamic_end_anchor":
		_update_segment_lock_states()
		return true
	elif property == "interaction_mode":
		_setup_interaction_areas()
		return true
	elif property == "interaction_width":
		_update_interaction_areas()
		return true
	return false

# Mouse handling for dragging
func _input(event: InputEvent) -> void:
	if _editor_mode:
		# Handle editor dragging here if needed
		return
	
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				# Start dragging
				if _mouse_over_end and end_anchor_draggable and not dynamic_end_anchor:
					# Handle end anchor drag as before
					_is_dragging = true
					_grabbed_segment_index = -1
				elif _hover_segment_index >= 0 and interaction_mode == GrabMode.ANY_POINT:
					# Start dragging a segment
					_is_dragging = true
					_grabbed_segment_index = _hover_segment_index
					_segments[_grabbed_segment_index].is_grabbed = true
					
					# Calculate grab offset (for more natural dragging)
					var mouse_pos = get_global_mouse_position()
					_grab_offset = _segments[_grabbed_segment_index].position - mouse_pos
					
					# Emit signal
					emit_signal("rope_grabbed", _grabbed_segment_index)
			else:
				# Stop dragging
				_is_dragging = false
				
				# Reset grab state if we were grabbing a segment
				if _grabbed_segment_index >= 0 and _grabbed_segment_index < _segments.size():
					_segments[_grabbed_segment_index].is_grabbed = false
					_grabbed_segment_index = -1
					
					# Emit signal
					emit_signal("rope_released")
				
				# Check if we need to reset a broken rope
				if _state == RopeState.BROKEN:
					reset_rope()

func _on_end_node_mouse_entered() -> void:
	_mouse_over_end = true
	Input.set_default_cursor_shape(Input.CURSOR_POINTING_HAND)

func _on_end_node_mouse_exited() -> void:
	_mouse_over_end = false
	if _hover_segment_index < 0:  # Only reset cursor if not hovering over a segment
		Input.set_default_cursor_shape(Input.CURSOR_ARROW)

func _on_segment_mouse_entered(segment_index: int) -> void:
	_hover_segment_index = segment_index
	Input.set_default_cursor_shape(Input.CURSOR_POINTING_HAND)

func _on_segment_mouse_exited(segment_index: int) -> void:
	if _hover_segment_index == segment_index:
		_hover_segment_index = -1
		if not _mouse_over_end:  # Only reset cursor if not hovering over end anchor
			Input.set_default_cursor_shape(Input.CURSOR_ARROW)

func _handle_collisions() -> void:
	if not enable_collisions or not _physics_direct_state:
		return
		
	# Clear last frame's collisions for debug visualization
	_last_collisions.clear()
	
	# Check collisions for each segment
	for i in range(_segments.size()):
		var segment = _segments[i]
		
		# Skip locked or grabbed segments
		if segment.is_locked or segment.is_grabbed:
			continue
			
		# Set up query for this segment
		_collision_query.shape = _segment_collision_shapes[i]
		_collision_query.transform = Transform2D(0, segment.position)
		
		# Perform the collision query
		var collisions = _physics_direct_state.intersect_shape(_collision_query, 1)
		
		if not collisions.is_empty():
			var collision = collisions[0]
			
			# Store collision data for debugging
			_last_collisions[i] = {
				"position": collision.point,
				"normal": collision.normal
			}
			
			# Calculate collision response
			var penetration_depth = collision_radius - (segment.position - collision.point).length()
			if penetration_depth > 0:
				# Movement vector
				var movement_vec = segment.position - segment.old_position
				
				# Calculate reflection vector
				var reflection = movement_vec.bounce(collision.normal)
				
				# Apply bounce and friction
				var velocity = reflection * collision_bounce
				
				# Calculate friction - apply to the component parallel to the surface
				var normal_component = collision.normal * velocity.dot(collision.normal)
				var tangent_component = velocity - normal_component
				tangent_component *= (1.0 - collision_friction)
				
				# Final velocity after friction
				velocity = normal_component + tangent_component
				
				# Move the segment out of collision
				segment.position = collision.point + (collision.normal * (collision_radius + 0.1))
				
				# Update old position to reflect bounce
				segment.old_position = segment.position - velocity
				
				# Update segment in the array
				_segments[i] = segment

# Called every physics frame
func _physics_process(delta: float) -> void:
	if _editor_mode:
		# In editor mode, check if anchors have moved
		if _start_node and _end_node:
			if _start_node.position != _last_start_pos or _end_node.position != _last_end_pos:
				_last_start_pos = _start_node.position
				_last_end_pos = _end_node.position
				start_position = _start_node.position
				end_position = _end_node.position
				queue_redraw()
		return
		
	if not _initialized or _segments.is_empty():
		return
	
	# Update physics direct state if needed
	if enable_collisions and _physics_direct_state == null:
		_physics_direct_state = get_world_2d().direct_space_state
	
	# Handle dragging based on what's being dragged
	if _is_dragging:
		if _grabbed_segment_index >= 0 and _grabbed_segment_index < _segments.size():
			# Dragging a rope segment
			var target_pos = get_global_mouse_position() + _grab_offset
			
			# Apply grab strength to make dragging feel more responsive
			_segments[_grabbed_segment_index].position = _segments[_grabbed_segment_index].position.lerp(
				target_pos, grab_strength
			)
			_segments[_grabbed_segment_index].old_position = _segments[_grabbed_segment_index].position
		elif _mouse_over_end and not dynamic_end_anchor:
			# Dragging the end anchor (old behavior)
			_end_node.global_position = get_global_mouse_position()
			_segments[segment_count].position = _end_node.global_position
	
	# If rope is broken, just request redraw to update the red line
	if _broken:
		queue_redraw()
		return
	
	# Update start and end positions from nodes if not dynamic
	if not dynamic_start_anchor:
		_segments[0].position = _start_node.global_position
	
	if not dynamic_end_anchor:
		_segments[segment_count].position = _end_node.global_position
	
	# Apply physics
	_update_physics(delta)
	
	# Update node positions for dynamic anchors
	if dynamic_start_anchor:
		_start_node.global_position = _segments[0].position
	
	if dynamic_end_anchor:
		_end_node.global_position = _segments[segment_count].position
	
	# Update interaction area shapes to match segment positions
	if interaction_mode == GrabMode.ANY_POINT and not _segment_areas.is_empty():
		for i in range(_segment_areas.size()):
			var area = _segment_areas[i]
			var collision = area.get_node_or_null("CollisionShape2D")
			
			if collision and collision.shape is CapsuleShape2D:
				var shape = collision.shape as CapsuleShape2D
				_update_segment_area_shape(i, shape, collision)
	
	# Check if rope is stretched too much
	_check_rope_state()
	
	# Request redraw
	queue_redraw()

# Apply verlet integration and constraints
func _update_physics(delta: float) -> void:
	# Apply verlet integration
	for i in range(_segments.size()):
		var segment: Dictionary = _segments[i]
		
		# Skip locked or grabbed segments
		if segment.is_locked or segment.is_grabbed:
			continue
		
		var temp: Vector2 = segment.position
		var velocity: Vector2 = segment.position - segment.old_position
		
		# Apply forces based on segment type
		var segment_gravity = gravity
		var segment_damping = damping
		
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
		segment.position += velocity * segment_damping + segment_gravity * delta * delta / segment.mass
		segment.old_position = temp
		
		_segments[i] = segment
	
	# Apply constraints multiple times for stability
	for _i in range(iterations):
		_apply_constraints()
	
	# Handle collisions after constraints
	if enable_collisions:
		_handle_collisions()

# Maintain proper distance between segments
func _apply_constraints() -> void:
	for i in range(segment_count):
		var segment1: Dictionary = _segments[i]
		var segment2: Dictionary = _segments[i + 1]
		
		var current_vec: Vector2 = segment2.position - segment1.position
		var current_dist: float = current_vec.length()
		
		if current_dist < 2.0:
			current_dist = 2.0
		
		var difference: float = segment_length - current_dist
		var percent: float = difference / current_dist
		var correction: Vector2 = current_vec * percent
		
		# Apply position correction - weight by mass for more realistic movement
		# of the dynamic anchors compared to regular segments
		var mass_ratio1 = segment2.mass / (segment1.mass + segment2.mass)
		var mass_ratio2 = segment1.mass / (segment1.mass + segment2.mass)
		
		if not segment1.is_locked:
			segment1.position -= correction * mass_ratio1
			_segments[i] = segment1
			
		if not segment2.is_locked:
			segment2.position += correction * mass_ratio2
			_segments[i + 1] = segment2

# Monitor rope state
func _check_rope_state() -> void:
	var total_length: float = 0.0
	var ideal_length: float = segment_length * segment_count
	
	for i in range(segment_count):
		var dist: float = _segments[i].position.distance_to(_segments[i + 1].position)
		total_length += dist
	
	var stretch_factor: float = total_length / ideal_length
	
	if stretch_factor >= max_stretch_factor:
		_state = RopeState.BROKEN
		_broken = true
		emit_signal("rope_broken")
	elif stretch_factor >= max_stretch_factor * 0.8:
		_state = RopeState.STRETCHED
	else:
		_state = RopeState.NORMAL

# Draw the rope using the selected line algorithm
func _draw() -> void:
	if _editor_mode:
		# Draw a preview in the editor between anchor positions
		if _start_node and _end_node:
			var start = to_local(_start_node.global_position)
			var end = to_local(_end_node.global_position)
			_draw_pixelated_line(start, end, rope_color)
		else:
			# Fallback if nodes aren't available yet
			var start = start_position
			var end = end_position
			_draw_pixelated_line(start, end, rope_color)
		return
	
	if _segments.is_empty():
		return
	
	# Prepare local points array
	var points: Array[Vector2] = []
	
	# If rope is broken, just draw a red line between the anchors
	if _broken:
		# Make sure we're using the current positions of the anchors
		var start_point = to_local(_start_node.global_position)
		var end_point = to_local(_end_node.global_position)
		
		# Draw red line with the same pixel properties as the rope
		_draw_pixelated_line(start_point, end_point, Color.RED)
	else:
		# Normal rope drawing
		for segment in _segments:
			points.append(to_local(segment.position))
		
		# Select color based on state
		var color: Color = rope_color
		if _state == RopeState.STRETCHED:
			color = Color.DARK_ORANGE
		
		# Draw pixelated rope segments
		for i in range(len(points) - 1):
			_draw_pixelated_line(points[i], points[i + 1], color)
	
	# Draw collision debug visualization if enabled
	if enable_collisions and show_collision_debug:
		_draw_collision_debug()

func _draw_collision_debug() -> void:
	if not enable_collisions or not show_collision_debug:
		return
		
	# Draw collision shapes for debugging
	var debug_color = Color(1.0, 0.3, 0.3, 0.4)
	
	for i in range(_segments.size()):
		var segment = _segments[i]
		var pos = to_local(segment.position)
		
		# Draw circle representing collision shape
		draw_circle(pos, collision_radius, debug_color)
		
		# Draw contact points if any
		if _last_collisions.has(i):
			var collision_data = _last_collisions[i]
			var contact_point = to_local(collision_data.position)
			var normal = collision_data.normal * 10.0
			
			# Draw contact point
			draw_circle(contact_point, 2.0, Color.RED)
			
			# Draw normal
			draw_line(contact_point, contact_point + normal, Color.GREEN, 1.0)

# Draw a line using the selected algorithm from LineAlgorithms
func _draw_pixelated_line(from: Vector2, to: Vector2, color: Color) -> void:
	# Get points using the selected algorithm
	var points = LineAlgorithms.get_line_points(
		from, to, 
		pixel_size, 
		line_algorithm, 
		pixel_spacing
	)
	
	# Draw pixels
	for point in points:
		_draw_pixel(point, pixel_size, color)

# Draw a pixel in the specified position, size, and color
func _draw_pixel(pixel_position: Vector2, size: float, color: Color) -> void:
	# Draw a rectangle to mimick a pixel with the inputs:
	# Position of the pixel, 
	# size of the pixel, 
	# and the color of the pixel
	draw_rect(Rect2(pixel_position - Vector2(size/2, size/2), Vector2(size, size)), color)

# Public methods
func break_rope() -> void:
	_broken = true
	_state = RopeState.BROKEN
	emit_signal("rope_broken")

func reset_rope() -> void:
	_broken = false
	_state = RopeState.NORMAL
	_initialize_rope()

func get_state() -> int:
	return _state

# Listen for child transforms changing
func _on_child_transform_changed() -> void:
	if Engine.is_editor_hint():
		if _start_node and _end_node:
			start_position = _start_node.position
			end_position = _end_node.position
			queue_redraw()

# Editor methods
func _get_tool_buttons() -> Array:
	return []
