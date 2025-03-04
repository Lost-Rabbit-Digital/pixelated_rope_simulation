class_name RopeController
extends RefCounted

var _verlet_system: VerletSystem
var _constraint_system: ConstraintSystem 
var _collision_system: CollisionSystem
var _line_renderer: LineRenderer
var _debug_renderer: DebugRenderer
var _anchor_interaction: AnchorInteraction
var _rope_interaction: RopeInteraction
var _signal_manager: SignalManager

# State tracking
var _broken: bool = false
var _state: int = 0 # RopeState.NORMAL
var _physics_direct_state: PhysicsDirectSpaceState2D = null
var _initialized: bool = false

func _init() -> void:
	# Initialize systems
	_verlet_system = VerletSystem.new()
	_constraint_system = ConstraintSystem.new()
	_collision_system = CollisionSystem.new()
	_line_renderer = LineRenderer.new()
	_debug_renderer = DebugRenderer.new()
	_anchor_interaction = AnchorInteraction.new()
	_rope_interaction = RopeInteraction.new()
	_signal_manager = SignalManager.new()

# Initialize systems and connect signals
func initialize(
	rope_broken_signal: Callable,
	rope_grabbed_signal: Callable,
	rope_released_signal: Callable
) -> void:
	# Connect signal manager signals
	_signal_manager.rope_broken.connect(rope_broken_signal)
	_signal_manager.rope_grabbed.connect(rope_grabbed_signal)
	_signal_manager.rope_released.connect(rope_released_signal)
	
	_initialized = true

# Process physics simulation for rope
func process_physics(
	delta: float,
	segments: Array[RopeSegment],
	collision_data: RopeCollision,
	gravity: Vector2,
	damping: float,
	iterations: int,
	segment_count: int,
	segment_length: float,
	max_stretch_factor: float,
	anchor_gravity: Vector2,
	anchor_jitter: float,
	enable_collisions: bool
) -> void:
	# Apply verlet integration
	_verlet_system.process_segments(
		segments, gravity, damping, delta,
		anchor_gravity, anchor_jitter, segment_count
	)
	
	# Apply constraints multiple times for stability
	_constraint_system.apply_constraints(
		segments, segment_length, iterations
	)
	
	# Handle collisions
	if enable_collisions and _physics_direct_state:
		_collision_system.process_collisions(
			segments, collision_data, _physics_direct_state
		)
	
	# Check rope state
	var state_info = _signal_manager.check_rope_state(
		segments, segment_length, segment_count, max_stretch_factor
	)
	_state = state_info.state
	_broken = state_info.broken

# Process input for interactions
func process_input(
	event: InputEvent,
	segments: Array[RopeSegment],
	end_node: Node2D,
	dynamic_end_anchor: bool,
	segment_count: int,
	grab_strength: float,
	interaction_mode: int,
	end_anchor_draggable: bool
) -> bool:
	var handled = false
	
	# Handle rope interactions
	if interaction_mode == 2: # GrabMode.ANY_POINT
		var result = _rope_interaction.process_segment_interaction(
			event, segments, grab_strength
		)
		
		if result.interaction_occurred:
			if result.segment_grabbed >= 0:
				_signal_manager.rope_grabbed.emit(result.segment_grabbed)
			elif result.segment_released:
				_signal_manager.rope_released.emit()
				
				# Check if we need to reset a broken rope
				if _state == 2: # RopeState.BROKEN
					# Don't reset here, just signal need for reset
					return true
					
			handled = true
	
	# Handle anchor interactions
	if end_anchor_draggable and not handled:
		var result = _anchor_interaction.process_anchor_interaction(
			event, end_node, dynamic_end_anchor, segments, segment_count
		)
		
		if result:
			handled = true
	
	return handled

# Set up physics state for collision detection
func setup_physics_state(parent: Node) -> void:
	var world = parent.get_world_2d()
	if world:
		_physics_direct_state = world.direct_space_state

# Get the current rope state
func get_state() -> int:
	return _state

# Check if the rope is broken
func is_broken() -> bool:
	return _broken

# Set broken state
func set_broken(broken: bool) -> void:
	_broken = broken
	if broken:
		_state = 2 # RopeState.BROKEN
	else:
		_state = 0 # RopeState.NORMAL

# Reset rope state
func reset_state() -> void:
	_broken = false
	_state = 0 # RopeState.NORMAL
	_signal_manager.reset_state()

# Render the rope
func render_rope(
	canvas: CanvasItem,
	segments: Array[RopeSegment],
	collision_data: RopeCollision,
	pixel_size: int,
	rope_color: Color,
	line_algorithm: int,
	pixel_spacing: int,
	enable_collisions: bool
) -> void:
	# Draw the rope segments
	_line_renderer.draw_rope(
		canvas,
		segments,
		pixel_size,
		rope_color,
		line_algorithm,
		pixel_spacing,
		_state,
		_broken
	)
	
	# Draw collision debug if enabled
	if enable_collisions and collision_data.show_collision_debug:
		_debug_renderer.draw_collision_debug(
			canvas,
			segments,
			collision_data
		)

# Render editor preview
func render_editor_preview(
	canvas: CanvasItem,
	start_pos: Vector2,
	end_pos: Vector2,
	pixel_size: int,
	rope_color: Color,
	line_algorithm: int,
	pixel_spacing: int
) -> void:
	_line_renderer.draw_preview_line(
		canvas,
		start_pos,
		end_pos,
		rope_color,
		pixel_size,
		line_algorithm,
		pixel_spacing
	)

# Set up interaction areas
func setup_interaction_areas(
	parent: CanvasItem,
	segments: Array[RopeSegment],
	interaction_width: float
) -> void:
	_rope_interaction.setup_interaction_areas(
		parent, segments, interaction_width
	)

# Update interaction areas
func update_interaction_areas(
	parent: CanvasItem,
	segments: Array[RopeSegment],
	interaction_width: float
) -> void:
	_rope_interaction.update_interaction_areas(
		segments, parent, interaction_width
	)

# Setup draggable anchor
func setup_draggable_anchor(node: Node2D) -> void:
	_anchor_interaction.setup_draggable_anchor(node)
