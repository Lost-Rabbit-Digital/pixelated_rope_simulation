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

# ECS systems
var _verlet_system: VerletSystem = VerletSystem.new()
var _constraint_system: ConstraintSystem = ConstraintSystem.new()
var _collision_system: CollisionSystem = CollisionSystem.new()
var _line_renderer: LineRenderer = LineRenderer.new()
var _debug_renderer: DebugRenderer = DebugRenderer.new()
var _anchor_interaction: AnchorInteraction = AnchorInteraction.new()
var _rope_interaction: RopeInteraction = RopeInteraction.new()
var _signal_manager: SignalManager = SignalManager.new()

# State variables
var _state: int = RopeState.NORMAL
var _broken: bool = false
var _initialized: bool = false
var _last_start_pos: Vector2
var _last_end_pos: Vector2
var _physics_direct_state: PhysicsDirectSpaceState2D = null
var _editor_mode: bool = false
var _editor_timer: SceneTreeTimer

func _ready() -> void:
	# Check if running in editor
	_editor_mode = Engine.is_editor_hint()
	
	# Connect signal manager signals to our signals
	_signal_manager.rope_broken.connect(func(): rope_broken.emit())
	_signal_manager.rope_grabbed.connect(func(idx): rope_grabbed.emit(idx))
	_signal_manager.rope_released.connect(func(): rope_released.emit())
	
	# Create anchor nodes if needed
	_ensure_anchor_nodes()
	
	# Save initial positions for change detection
	if _start_node and _end_node:
		_last_start_pos = _start_node.position
		_last_end_pos = _end_node.position
	
# Configure collision data
	_collision_data.collision_radius = collision_radius
	_collision_data.collision_mask = collision_mask
	_collision_data.collision_bounce = collision_bounce
	_collision_data.collision_friction = collision_friction
	_collision_data.show_collision_debug = show_collision_debug
	
	# Set up editor update timer
	if _editor_mode:
		_setup_editor_updates()
		queue_redraw()
	else:
		# Initialize in game mode only
		await get_tree().process_frame
		
		# Set up interaction for the end anchor if needed
		if end_anchor_draggable and not dynamic_end_anchor:
			_anchor_interaction.setup_draggable_anchor(_end_node)
		
		# Initialize the rope
		_initialize_rope()
		
		# Mark as initialized before setting up interactions
		_initialized = true
		
		# Set up segment interaction areas if enabled
		if interaction_mode == GrabMode.ANY_POINT:
			_rope_interaction.setup_interaction_areas(self, _segments, interaction_width)
		
		# Set up collision detection if enabled
		if enable_collisions:
			call_deferred("_setup_collision_detection")

# Set up collision detection system
func _setup_collision_detection() -> void:
	if Engine.is_editor_hint() or not enable_collisions:
		return
	
	# Create collision shapes for each segment
	_collision_data.create_shapes_for_segments(_segments.size())
	
	# Schedule physics state acquisition for next frame
	call_deferred("_initialize_physics_state")
	
	print("PixelRope: Collision detection prepared")

# Initialize physics state for collisions
func _initialize_physics_state() -> void:
	if Engine.is_editor_hint() or not enable_collisions:
		return
		
	if not is_inside_tree():
		# If not in tree yet, try again next frame
		call_deferred("_initialize_physics_state")
		return
		
	# Get the physics world
	var world = get_world_2d()
	if world:
		_physics_direct_state = world.direct_space_state
		print("PixelRope: Physics state successfully initialized")
	else:
		# If world not available yet, try again next frame
		call_deferred("_initialize_physics_state")

# Set up a timer for editor updates
func _setup_editor_updates() -> void:
	# Cancel existing timer
	if _editor_timer and not _editor_timer.is_queued_for_deletion():
		_editor_timer.timeout.disconnect(_check_for_anchor_movement)
		
	# Create new timer
	_editor_timer = get_tree().create_timer(0.05) # 50ms
	_editor_timer.timeout.connect(_check_for_anchor_movement)

# Check if anchors have moved in editor
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
	
	# Set ownership in editor
	if Engine.is_editor_hint() and get_tree().edited_scene_root:
		anchor.owner = get_tree().edited_scene_root
	
	return anchor

# Update anchor properties
func _update_anchor_properties() -> void:
	if _start_node and _start_node is RopeAnchor:
		_start_node.radius = anchor_radius
		_start_node.debug_color = anchor_debug_color
	
	if _end_node and _end_node is RopeAnchor:
		_end_node.radius = anchor_radius
		_end_node.debug_color = anchor_debug_color

# Update anchor debug visualization
func _update_anchor_debug_visualization() -> void:
	if _start_node and _start_node is RopeAnchor:
		_start_node.show_debug_shape = show_anchor_debug
	
	if _end_node and _end_node is RopeAnchor:
		_end_node.show_debug_shape = show_anchor_debug

# Handle anchor position change signal
func _on_anchor_position_changed(anchor: RopeAnchor) -> void:
	if anchor.name == "StartAnchor":
		start_position = anchor.position
	elif anchor.name == "EndAnchor":
		end_position = anchor.position
	queue_redraw()

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
		
		var segment_mass = 1.0 if (i > 0 and i < segment_count) else anchor_mass
		
		var segment = RopeSegment.new(pos, i, is_locked, segment_mass)
		_segments.append(segment)
	
	print("PixelRope: Created", _segments.size(), "segments with length", segment_length)
	
	# Reset state
	_broken = false
	_state = RopeState.NORMAL

# Update segment lock states based on dynamic anchor settings
func _update_segment_lock_states() -> void:
	if _segments.is_empty():
		return
	
	# Update start anchor
	if _segments.size() > 0:
		_segments[0].is_locked = not dynamic_start_anchor
	
	# Update end anchor
	if _segments.size() > segment_count:
		_segments[segment_count].is_locked = not dynamic_end_anchor

# Set up interaction areas
func _setup_interaction_areas() -> void:
	if _editor_mode or _segments.is_empty():
		return
		
	if interaction_mode == GrabMode.ANY_POINT:
		_rope_interaction.setup_interaction_areas(self, _segments, interaction_width)

# Update interaction area shapes
func _update_interaction_areas() -> void:
	if _segments.is_empty() or _editor_mode:
		return
	
	_rope_interaction.update_interaction_areas(_segments, self, interaction_width)

# Input handling for interactions
func _input(event: InputEvent) -> void:
	if _editor_mode:
		return
	
	# Handle rope interactions
	if interaction_mode == GrabMode.ANY_POINT:
		var result = _rope_interaction.process_segment_interaction(event, _segments, grab_strength)
		
		if result.interaction_occurred:
			if result.segment_grabbed >= 0:
				rope_grabbed.emit(result.segment_grabbed)
			elif result.segment_released:
				rope_released.emit()
				
				# Check if we need to reset a broken rope
				if _state == RopeState.BROKEN:
					reset_rope()
					
			return
	
	# Handle anchor interactions
	if end_anchor_draggable:
		var result = _anchor_interaction.process_anchor_interaction(
			event, _end_node, dynamic_end_anchor, _segments, segment_count
		)
		
		if result:
			return

# Physics process
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
	
	# If rope is broken, just request redraw
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
	
	# Update interaction areas
	if interaction_mode == GrabMode.ANY_POINT:
		_rope_interaction.update_interaction_areas(_segments, self, interaction_width)
	
	# Check rope state
	var state_info = _signal_manager.check_rope_state(
		_segments, segment_length, segment_count, max_stretch_factor
	)
	_state = state_info.state
	_broken = state_info.broken
	
	# Request redraw
	queue_redraw()

# Apply physics to rope segments
func _update_physics(delta: float) -> void:
	# Apply verlet integration
	_verlet_system.process_segments(
		_segments, gravity, damping, delta,
		anchor_gravity, anchor_jitter, segment_count
	)
	
	# Apply constraints multiple times for stability
	_constraint_system.apply_constraints(
		_segments, segment_length, iterations
	)
	
	# Handle collisions
	if enable_collisions and _physics_direct_state:
		_collision_system.process_collisions(
			_segments, _collision_data, _physics_direct_state
		)

# Draw the rope
func _draw() -> void:
	if _editor_mode:
		# Draw a preview in the editor
		if _start_node and _end_node:
			_line_renderer.draw_preview_line(
				self,
				_start_node.global_position,
				_end_node.global_position,
				rope_color,
				pixel_size,
				line_algorithm,
				pixel_spacing
			)
		return
	
	if _segments.is_empty():
		return
	
	# Draw the rope segments
	_line_renderer.draw_rope(
		self,
		_segments,
		pixel_size,
		rope_color,
		line_algorithm,
		pixel_spacing,
		_state,
		_broken
	)
	
	# Draw collision debug if enabled
	if enable_collisions and show_collision_debug:
		_debug_renderer.draw_collision_debug(
			self,
			_segments,
			_collision_data
		)

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

# Public methods
func break_rope() -> void:
	_broken = true
	_state = RopeState.BROKEN
	rope_broken.emit()

func reset_rope() -> void:
	_broken = false
	_state = RopeState.NORMAL
	_initialize_rope()
	_signal_manager.reset_state()

func get_state() -> int:
	return _state
