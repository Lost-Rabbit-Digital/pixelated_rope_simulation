@tool
@icon("res://addons/pixel_rope/icons/Curve2D.svg")
## A physically-simulated, pixel-perfect rope with multiple rendering algorithms
##
## Implements a complete rope physics system using verlet integration with
## configurable properties. Built using an Entity Component System architecture
## for optimal performance and modularity.
class_name PixelRope
extends Node2D

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
@export var segment_count: int = 100:
	set(value):
		segment_count = value
		if Engine.is_editor_hint():
			queue_redraw()

@export var segment_length: float = 5.0:
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
@export var iterations: int = 10
@export var max_stretch_factor: float = 2

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

@export var anchor_debug_color: Color = Color(0.0, 0.698, 0.885, 0.5):
	set(value):
		anchor_debug_color = value
		_update_anchor_properties()
		if Engine.is_editor_hint():
			queue_redraw()

@export var show_anchor_debug: bool = true:
	set(value):
		show_anchor_debug = value
		_update_anchor_debug_visualization()

# Dynamic anchor properties
@export_group("Dynamic Anchors")
@export var dynamic_start_anchor: bool = false:
	set(value):
		dynamic_start_anchor = value
		_update_segment_lock_states()

@export var dynamic_end_anchor: bool = true:
	set(value):
		dynamic_end_anchor = value
		_update_segment_lock_states()

@export_range(0.1, 10.0) var anchor_mass: float = 1.0
@export var anchor_jitter: float = 0.0
@export var anchor_gravity: Vector2 = Vector2.ZERO

@export_group("Collision Properties")
@export var enable_collisions: bool = true:
	set(value):
		enable_collisions = value
		_setup_collision_detection()

@export_flags_2d_physics var collision_mask: int = 1
@export_range(0.0, 1.0) var collision_bounce: float = 0.3
@export_range(0.0, 1.0) var collision_friction: float = 0.7
@export_range(1.0, 20.0) var collision_radius: float = 4.0:
	set(value):
		collision_radius = value
		if _collision_data:
			_collision_data.collision_radius = value
			_collision_data.update_all_shapes()

@export var show_collision_debug: bool = false:
	set(value):
		show_collision_debug = value
		if _collision_data:
			_collision_data.show_collision_debug = value
		queue_redraw()

@export_group("Interaction Properties")
@export var interaction_mode: GrabMode = GrabMode.ANY_POINT:
	set(value):
		interaction_mode = value
		_setup_interaction_areas()

@export_range(5.0, 50.0) var interaction_width: float = 20.0:
	set(value):
		interaction_width = value
		_update_interaction_areas()

@export_range(0.1, 1.0) var grab_strength: float = 0.8
@export var end_anchor_draggable: bool = true

# Node references
var _start_node: Node2D
var _end_node: Node2D

# ECS components
var _segments: Array[RopeSegment] = []
var _collision_data: RopeCollision = RopeCollision.new()

# Module references - our new controllers
var _controller: RopeController = RopeController.new()
var _editor_mode: bool = false
var _last_start_pos: Vector2
var _last_end_pos: Vector2
var _editor_timer: SceneTreeTimer


func _ready() -> void:
	# Check if running in editor
	_editor_mode = Engine.is_editor_hint()
	
	# Initialize controller
	_controller.initialize(
		func(): rope_broken.emit(),
		func(idx): rope_grabbed.emit(idx),
		func(): rope_released.emit()
	)
	
	# Create anchor nodes if needed
	_ensure_anchor_nodes()
	
	# Initialize editor tracking variables and setup timer if in editor
	if _editor_mode and _start_node and _end_node:
		_last_start_pos = _start_node.position
		_last_end_pos = _end_node.position
		_setup_editor_updates()
		queue_redraw()
	else:
		# Game mode initialization
		await get_tree().process_frame
		
		# Set up interaction for the end anchor if needed
		if end_anchor_draggable and not dynamic_end_anchor:
			_controller.setup_draggable_anchor(_end_node)
		
		# Initialize rope
		_initialize_rope()
		
		# Set up segment interaction areas if enabled
		if interaction_mode == GrabMode.ANY_POINT:
			_controller.setup_interaction_areas(self, _segments, interaction_width)
		
		# Set up collision detection if enabled
		if enable_collisions:
			call_deferred("_setup_collision_detection")
	
	# Configure collision data
	RopeFactory.setup_collision_data(
		_collision_data,
		collision_radius,
		collision_mask,
		collision_bounce,
		collision_friction,
		show_collision_debug
	)

func _setup_editor_updates() -> void:
	# Cancel existing timer
	if _editor_timer and not _editor_timer.is_queued_for_deletion():
		if _editor_timer.timeout.is_connected(_check_for_anchor_movement):
			_editor_timer.timeout.disconnect(_check_for_anchor_movement)
		
	# Create new timer
	_editor_timer = get_tree().create_timer(0.05) # 50ms
	_editor_timer.timeout.connect(_check_for_anchor_movement)

func _check_for_anchor_movement() -> void:
	if not _editor_mode:
		return
		
	if _start_node and _end_node:
		if _start_node.position != _last_start_pos or _end_node.position != _last_end_pos:
			# Update stored positions
			_last_start_pos = _start_node.position
			_last_end_pos = _end_node.position
			
			# Update export variables
			start_position = _start_node.position
			end_position = _end_node.position
			
			# Redraw rope
			queue_redraw()
	
	# Set up next timer
	_setup_editor_updates()

# Create and set up anchor nodes
func _ensure_anchor_nodes() -> void:
	# Handle start anchor
	_start_node = get_node_or_null("StartAnchor") 
	if not _start_node:
		_start_node = _create_anchor_node("StartAnchor", start_position)
	else:
		# Make sure existing node has correct position and properties
		_start_node.position = start_position
		if _start_node is RopeAnchor:
			_update_anchor_node_properties(_start_node)
			# Safely disconnect and reconnect signal to prevent duplicates
			if _start_node.position_changed.is_connected(_on_anchor_position_changed):
				_start_node.position_changed.disconnect(_on_anchor_position_changed)
			_start_node.position_changed.connect(_on_anchor_position_changed.bind(_start_node))
	
	# Handle end anchor
	_end_node = get_node_or_null("EndAnchor")
	if not _end_node:
		_end_node = _create_anchor_node("EndAnchor", end_position)
	else:
		# Make sure existing node has correct position and properties
		_end_node.position = end_position
		if _end_node is RopeAnchor:
			_update_anchor_node_properties(_end_node)
			# Safely disconnect and reconnect signal to prevent duplicates
			if _end_node.position_changed.is_connected(_on_anchor_position_changed):
				_end_node.position_changed.disconnect(_on_anchor_position_changed)
			_end_node.position_changed.connect(_on_anchor_position_changed.bind(_end_node))

func _update_anchor_node_properties(anchor: RopeAnchor) -> void:
	anchor.radius = anchor_radius
	anchor.debug_color = anchor_debug_color
	anchor.show_debug_shape = show_anchor_debug

func _create_anchor_node(node_name: String, position: Vector2) -> Node2D:
	var anchor = RopeAnchor.new()
	anchor.name = node_name
	anchor.position = position
	
	# Set properties
	anchor.radius = anchor_radius
	anchor.debug_color = anchor_debug_color
	anchor.show_debug_shape = show_anchor_debug
	
	# Connect position change signal with the node as the bind parameter
	anchor.position_changed.connect(_on_anchor_position_changed.bind(anchor))
	
	add_child.call_deferred(anchor)
	
	# If this is being run in the editor, ensure the node is properly set up
	if Engine.is_editor_hint() and get_tree().edited_scene_root:
		anchor.owner = get_tree().edited_scene_root
	
	return anchor

func _notification(what: int) -> void:
	match what:
		NOTIFICATION_PARENTED:
			# When the node gets a new parent, we need to ensure signals are properly connected
			if not Engine.is_editor_hint():
				call_deferred("_reconnect_anchor_signals")

func _reconnect_anchor_signals() -> void:
	if not is_inside_tree():
		return
		
	# Reconnect start anchor
	if _start_node is RopeAnchor:
		if _start_node.position_changed.is_connected(_on_anchor_position_changed):
			_start_node.position_changed.disconnect(_on_anchor_position_changed)
		_start_node.position_changed.connect(_on_anchor_position_changed.bind(_start_node))
	
	# Reconnect end anchor
	if _end_node is RopeAnchor:
		if _end_node.position_changed.is_connected(_on_anchor_position_changed):
			_end_node.position_changed.disconnect(_on_anchor_position_changed)
		_end_node.position_changed.connect(_on_anchor_position_changed.bind(_end_node))

# Handle anchor position change signal
func _on_anchor_position_changed(anchor: RopeAnchor) -> void:
	if anchor.name == "StartAnchor":
		start_position = anchor.position
	elif anchor.name == "EndAnchor":
		end_position = anchor.position
	queue_redraw()

# Initialize the rope segments
func _initialize_rope() -> void:
	_segments = RopeFactory.create_segments(
		_start_node.global_position,
		_end_node.global_position,
		segment_count,
		segment_length,
		dynamic_start_anchor,
		dynamic_end_anchor,
		anchor_mass
	)
	
	# Reset state
	_controller.reset_state()

# Set up collision detection
func _setup_collision_detection() -> void:
	if _editor_mode or not enable_collisions:
		return
		
	# Create collision shapes for segments
	_collision_data.create_shapes_for_segments(_segments.size())
	
	# Get physics state
	call_deferred("_initialize_physics_state")

# Initialize physics state for collisions
func _initialize_physics_state() -> void:
	if _editor_mode or not enable_collisions or not is_inside_tree():
		call_deferred("_initialize_physics_state")
		return
		
	_controller.setup_physics_state(self)

# Update anchor properties
func _update_anchor_properties() -> void:
	RopePropertyManager.update_anchor_properties(
		_start_node, _end_node, anchor_radius, anchor_debug_color
	)

# Update anchor debug visualization
func _update_anchor_debug_visualization() -> void:
	RopePropertyManager.update_anchor_visibility(
		_start_node, _end_node, show_anchor_debug
	)

# Update segment lock states
func _update_segment_lock_states() -> void:
	RopePropertyManager.update_segment_lock_states(
		_segments, segment_count, dynamic_start_anchor, dynamic_end_anchor
	)

# Update interaction areas
func _update_interaction_areas() -> void:
	if _segments.is_empty() or _editor_mode:
		return
	
	_controller.update_interaction_areas(self, _segments, interaction_width)

# Set up interaction areas
func _setup_interaction_areas() -> void:
	if _editor_mode or _segments.is_empty():
		return
		
	if interaction_mode == GrabMode.ANY_POINT:
		_controller.setup_interaction_areas(self, _segments, interaction_width)

# Input handling
func _input(event: InputEvent) -> void:
	if _editor_mode:
		return
	
	var reset_needed = _controller.process_input(
		event,
		_segments,
		_end_node,
		dynamic_end_anchor,
		segment_count,
		grab_strength,
		interaction_mode,
		end_anchor_draggable
	)
	
	if reset_needed:
		reset_rope()

# Physics process
func _physics_process(delta: float) -> void:
	if _editor_mode:
		# In editor mode, directly check if anchors have moved
		if _start_node and _end_node:
			if _start_node.position != _last_start_pos or _end_node.position != _last_end_pos:
				# Update stored positions
				_last_start_pos = _start_node.position
				_last_end_pos = _end_node.position
				
				# Update export variables
				start_position = _start_node.position
				end_position = _end_node.position
				
				# Redraw rope
				queue_redraw()
		return
	
	if _segments.is_empty():
		return
	
	# If rope is broken, just request redraw
	if _controller.is_broken():
		queue_redraw()
		return
	
	# Update start and end positions from nodes if not dynamic
	if not dynamic_start_anchor:
		_segments[0].position = _start_node.global_position
	
	if not dynamic_end_anchor:
		_segments[segment_count].position = _end_node.global_position
	
	# Apply physics
	_controller.process_physics(
		delta,
		_segments,
		_collision_data,
		gravity,
		damping,
		iterations,
		segment_count,
		segment_length,
		max_stretch_factor,
		anchor_gravity,
		anchor_jitter,
		enable_collisions
	)
	
	# Update node positions for dynamic anchors
	if dynamic_start_anchor:
		_start_node.global_position = _segments[0].position
	
	if dynamic_end_anchor:
		_end_node.global_position = _segments[segment_count].position
	
	# Update interaction areas
	if interaction_mode == GrabMode.ANY_POINT:
		_controller.update_interaction_areas(self, _segments, interaction_width)
	
	# Request redraw
	queue_redraw()

# Draw the rope
# Draw the rope
func _draw() -> void:
	if _editor_mode:
		# Draw editor preview directly without using the controller
		if _start_node and _end_node:
			# Get points using the selected algorithm
			var start = to_local(_start_node.global_position)
			var end = to_local(_end_node.global_position)
			
			var points = LineAlgorithms.get_line_points(
				start, end, 
				pixel_size, 
				line_algorithm, 
				pixel_spacing
			)
			
			# Draw pixels
			for point in points:
				draw_rect(
					Rect2(point - Vector2(pixel_size/2, pixel_size/2), Vector2(pixel_size, pixel_size)), 
					rope_color
				)
		return
	
	if _segments.is_empty():
		return
	
	# For game mode, still use the controller if it's working properly
	# Draw the rope
	_controller.render_rope(
		self,
		_segments,
		_collision_data,
		pixel_size,
		rope_color,
		line_algorithm,
		pixel_spacing,
		enable_collisions
	)

# Break the rope
func break_rope() -> void:
	_controller.set_broken(true)
	rope_broken.emit()

# Reset the rope
func reset_rope() -> void:
	_initialize_rope()

# Get the rope state
func get_state() -> int:
	return _controller.get_state()
