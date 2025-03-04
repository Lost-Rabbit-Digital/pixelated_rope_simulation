# addons/pixel_rope/scripts/nodes/rope_node.gd
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

@export var anchor_color: Color = Color.WHITE:
	set(value):
		anchor_color = value
		_update_anchor_properties()
		if Engine.is_editor_hint():
			queue_redraw()

# Dynamic anchors group
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

@export_group("Interaction Properties")
## Control how the rope can be interacted with
@export var interaction_mode: RopeInteractionSystem.GrabMode = RopeInteractionSystem.GrabMode.ANY_POINT:
	set(value):
		interaction_mode = value
		if not _editor_mode and _initialized:
			RopeInteractionSystem.setup_interaction_areas(
				self, _rope_data, _interaction_state, 
				interaction_mode, interaction_width, show_interaction_areas
			)

## Width of the interaction area around the rope (in pixels)
@export_range(5.0, 50.0) var interaction_width: float = 20.0:
	set(value):
		interaction_width = value
		if not _editor_mode and _initialized:
			RopeInteractionSystem.update_interaction_areas(
				self, _rope_data, _interaction_state,
				interaction_width, show_interaction_areas
			)

## How strongly the rope segment being held is pulled toward mouse position
@export_range(0.1, 1.0) var grab_strength: float = 0.8

## If true, end anchor can be dragged like before
@export var end_anchor_draggable: bool = true

@export_group("State Properties")
## Maximum stretch factor before rope breaks
@export var max_stretch_factor: float = 1.5

@export_group("Anchor Visualization")
@export var show_anchors: bool = true:
	set(value):
		show_anchors = value
		_update_anchor_visibility()

@export var show_anchor_shapes: bool = false:
	set(value):
		show_anchor_shapes = value
		_update_anchor_visualization()

@export var show_collision_debug: bool = true:
	set(value):
		show_collision_debug = value
		_update_collision_debug_visualization()

## Whether to show the interaction areas for debugging
@export var show_interaction_areas: bool = false:
	set(value):
		show_interaction_areas = value
		if not _editor_mode and _initialized:
			RopeInteractionSystem.update_interaction_areas_visibility(
				_interaction_state, show_interaction_areas
			)

# Private variables
var _start_node: Node2D
var _end_node: Node2D
var _initialized: bool = false
var _last_start_pos: Vector2
var _last_end_pos: Vector2
var _editor_mode: bool = false
var _editor_timer: SceneTreeTimer

# System state
var _rope_data: RopeData
var _interaction_state: RopeInteractionSystem.InteractionState
var _rope_state: int = RopeStateSystem.RopeState.NORMAL
var _rope_broken: bool = false

# Called when the node enters the scene tree
func _ready() -> void:
	# Check if we're in the editor
	_editor_mode = Engine.is_editor_hint()
	
	# Initialize rope data
	_rope_data = RopeData.new()
	
	# Initialize interaction state
	_interaction_state = RopeInteractionSystem.InteractionState.new()
	
	# Create anchor nodes if they don't exist
	_ensure_anchor_nodes()
	
	# Update anchor visibility and visualization
	_update_anchor_visibility()
	_update_anchor_visualization()
	_update_collision_debug_visualization()
	
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
		
		# Set up interaction areas
		if interaction_mode == RopeInteractionSystem.GrabMode.ANY_POINT:
			RopeInteractionSystem.setup_interaction_areas(
				self, _rope_data, _interaction_state,
				interaction_mode, interaction_width, show_interaction_areas
			)
		
		# Set up the end anchor for dragging if needed
		if end_anchor_draggable and not dynamic_end_anchor:
			RopeInteractionSystem.setup_draggable_node(_end_node)
		
		# Connect area signals
		_connect_area_signals()
		
		# Initialize the rope
		_initialize_rope()
		_initialized = true

# Connect signals for interaction
func _connect_area_signals() -> void:
	# Set up end anchor signals
	if _end_node:
		var end_area = _end_node.get_node_or_null("Area2D")
		if end_area:
			if not end_area.mouse_entered.is_connected(_on_end_node_mouse_entered):
				end_area.mouse_entered.connect(_on_end_node_mouse_entered)
			if not end_area.mouse_exited.is_connected(_on_end_node_mouse_exited):
				end_area.mouse_exited.connect(_on_end_node_mouse_exited)

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

# Ensure anchor nodes exist and are positioned correctly
func _ensure_anchor_nodes() -> void:
	# Handle start anchor
	_start_node = get_node_or_null("StartAnchor")
	if not _start_node:
		_start_node = _create_anchor_node("StartAnchor", start_position)
	else:
		_start_node.position = start_position
	
	# Handle end anchor
	_end_node = get_node_or_null("EndAnchor")
	if not _end_node:
		_end_node = _create_anchor_node("EndAnchor", end_position)
	else:
		_end_node.position = end_position

# Create a new anchor node
func _create_anchor_node(node_name: String, position: Vector2) -> Node2D:
	var anchor = Node2D.new()
	anchor.name = node_name
	anchor.position = position
	anchor.set_script(load("res://addons/pixel_rope/scripts/nodes/rope_anchor.gd"))
	
	# Set properties
	if anchor.has_method("set") and anchor.get_script():
		anchor.set("radius", anchor_radius)
		anchor.set("color", anchor_color)
		anchor.set("visible_shape", show_anchor_shapes)
	
	# Create Area2D
	var area = Area2D.new()
	area.name = "Area2D"
	
	var collision = CollisionShape2D.new()
	collision.name = "CollisionShape2D"
	
	var shape = CircleShape2D.new()
	shape.radius = anchor_radius
	
	collision.shape = shape
	
	# Set debug color based on show_collision_debug setting
	if show_collision_debug:
		collision.debug_color = Color(0.7, 0.7, 1.0, 0.5)  # Light blue, semi-transparent
	else:
		collision.debug_color = Color(0, 0, 0, 0)  # Fully transparent
	
	area.add_child(collision)
	anchor.add_child(area)
	
	add_child(anchor)
	
	# If this is being run in the editor, ensure the node is properly set up
	if Engine.is_editor_hint():
		# Mark the node as needing to be saved
		anchor.owner = get_tree().edited_scene_root
		area.owner = get_tree().edited_scene_root
		collision.owner = get_tree().edited_scene_root
	
	return anchor

# Update anchor visibility based on show_anchors property
func _update_anchor_visibility() -> void:
	if _start_node and _start_node.has_method("set"):
		_start_node.set("visible", show_anchors)
	
	if _end_node and _end_node.has_method("set"):
		_end_node.set("visible", show_anchors)

# Update anchor visualization (showing/hiding drawn shapes)
func _update_anchor_visualization() -> void:
	if _start_node and _start_node.has_method("set"):
		_start_node.set("visible_shape", show_anchor_shapes)
	
	if _end_node and _end_node.has_method("set"):
		_end_node.set("visible_shape", show_anchor_shapes)

# Update collision debug visualization
func _update_collision_debug_visualization() -> void:
	if _start_node:
		var start_area = _start_node.get_node_or_null("Area2D")
		if start_area:
			var start_collision = start_area.get_node_or_null("CollisionShape2D")
			if start_collision:
				if show_collision_debug:
					start_collision.debug_color = Color(0.7, 0.7, 1.0, 0.5)  # Light blue, semi-transparent
				else:
					start_collision.debug_color = Color(0, 0, 0, 0)  # Fully transparent
	
	if _end_node:
		var end_area = _end_node.get_node_or_null("Area2D")
		if end_area:
			var end_collision = end_area.get_node_or_null("CollisionShape2D")
			if end_collision:
				if show_collision_debug:
					end_collision.debug_color = Color(0.7, 0.7, 1.0, 0.5)  # Light blue, semi-transparent
				else:
					end_collision.debug_color = Color(0, 0, 0, 0)  # Fully transparent

# Update anchor properties when changed
func _update_anchor_properties() -> void:
	if _start_node and _start_node.has_method("set"):
		_start_node.set("radius", anchor_radius)
		_start_node.set("color", anchor_color)
	
	if _end_node and _end_node.has_method("set"):
		_end_node.set("radius", anchor_radius)
		_end_node.set("color", anchor_color)

# Initialize the rope segments
func _initialize_rope() -> void:
	# Calculate initial segment length if not manually set
	if segment_length <= 0:
		segment_length = _start_node.global_position.distance_to(_end_node.global_position) / float(segment_count)
	
	# Initialize rope data
	_rope_data.initialize(
		_start_node.global_position, 
		_end_node.global_position,
		segment_count,
		segment_length,
		dynamic_start_anchor,
		dynamic_end_anchor,
		anchor_mass
	)
	
	# Reset rope state
	_rope_state = RopeStateSystem.RopeState.NORMAL
	_rope_broken = false
	
	print("PixelRope: Created", _rope_data.segments.size(), "segments with length", segment_length)

# Update the lock state of segments based on dynamic anchor settings
func _update_segment_lock_states() -> void:
	if _rope_data:
		_rope_data.update_lock_states(dynamic_start_anchor, dynamic_end_anchor)

# Interaction signal handlers
func _on_end_node_mouse_entered() -> void:
	_interaction_state.mouse_over_end = true
	Input.set_default_cursor_shape(Input.CURSOR_POINTING_HAND)

func _on_end_node_mouse_exited() -> void:
	_interaction_state.mouse_over_end = false
	if _interaction_state.hover_segment_index < 0:  # Only reset cursor if not hovering over a segment
		Input.set_default_cursor_shape(Input.CURSOR_ARROW)

func _on_segment_mouse_entered(segment_index: int) -> void:
	_interaction_state.hover_segment_index = segment_index
	Input.set_default_cursor_shape(Input.CURSOR_POINTING_HAND)

func _on_segment_mouse_exited(segment_index: int) -> void:
	if _interaction_state.hover_segment_index == segment_index:
		_interaction_state.hover_segment_index = -1
		if not _interaction_state.mouse_over_end:  # Only reset cursor if not hovering over end anchor
			Input.set_default_cursor_shape(Input.CURSOR_ARROW)

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
	elif property == "show_anchors":
		_update_anchor_visibility()
		queue_redraw()
		return true
	elif property == "show_anchor_shapes":
		_update_anchor_visualization()
		queue_redraw()
		return true
	elif property == "show_collision_debug":
		_update_collision_debug_visualization()
		queue_redraw()
		return true
	elif property == "dynamic_start_anchor" or property == "dynamic_end_anchor":
		_update_segment_lock_states()
		return true
	
	return false

# Handle mouse input for dragging
func _input(event: InputEvent) -> void:
	if _editor_mode or not _initialized:
		return
	
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				# Start dragging
				if _interaction_state.mouse_over_end and end_anchor_draggable and not dynamic_end_anchor:
					# Handle end anchor drag
					_interaction_state.is_dragging = true
					_interaction_state.grabbed_segment_index = -1
				elif _interaction_state.hover_segment_index >= 0 and interaction_mode == RopeInteractionSystem.GrabMode.ANY_POINT:
					# Start dragging a segment
					_interaction_state.is_dragging = true
					_interaction_state.grabbed_segment_index = _interaction_state.hover_segment_index
					_rope_data.segments[_interaction_state.grabbed_segment_index].is_grabbed = true
					
					# Calculate grab offset (for more natural dragging)
					var mouse_pos = get_global_mouse_position()
					_interaction_state.grab_offset = _rope_data.segments[_interaction_state.grabbed_segment_index].position - mouse_pos
					
					# Emit signal
					rope_grabbed.emit(_interaction_state.grabbed_segment_index)
			else:
				# Stop dragging
				_interaction_state.is_dragging = false
				
				# Reset grab state if we were grabbing a segment
				if _interaction_state.grabbed_segment_index >= 0 and _interaction_state.grabbed_segment_index < _rope_data.segments.size():
					_rope_data.segments[_interaction_state.grabbed_segment_index].is_grabbed = false
					_interaction_state.grabbed_segment_index = -1
					
					# Emit signal
					rope_released.emit()
				
				# Check if we need to reset a broken rope
				if _rope_state == RopeStateSystem.RopeState.BROKEN:
					reset_rope()

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
		
	if not _initialized or not _rope_data or _rope_data.segments.is_empty():
		return
	
	# Handle dragging through interaction system
	RopeInteractionSystem.process_dragging(
		self, _rope_data, _interaction_state, 
		_end_node, dynamic_end_anchor, grab_strength
	)
	
	# If rope is broken, just request redraw to update the red line
	if _rope_broken:
		queue_redraw()
		return
	
	# Update start and end positions from nodes if not dynamic
	if not dynamic_start_anchor:
		_rope_data.segments[0].position = _start_node.global_position
	
	if not dynamic_end_anchor:
		_rope_data.segments[segment_count].position = _end_node.global_position
	
	# Apply physics
	RopePhysicsSystem.update_physics(
		_rope_data, 
		delta, 
		gravity, 
		damping, 
		iterations, 
		anchor_gravity,
		anchor_jitter
	)
	
	# Update node positions for dynamic anchors
	if dynamic_start_anchor:
		_start_node.global_position = _rope_data.segments[0].position
	
	if dynamic_end_anchor:
		_end_node.global_position = _rope_data.segments[segment_count].position
	
	# Update interaction area shapes
	if not _interaction_state.segment_areas.is_empty():
		RopeInteractionSystem.update_interaction_areas(
			self, _rope_data, _interaction_state,
			interaction_width, show_interaction_areas
		)
	
	# Check if rope is stretched too much
	var state_result = RopeStateSystem.check_rope_state(
		_rope_data, max_stretch_factor, _rope_state, _rope_broken
	)
	
	_rope_state = state_result[0]
	_rope_broken = state_result[1]
	var state_changed = state_result[2]
	
	if state_changed and _rope_broken:
		rope_broken.emit()
	
	# Request redraw
	queue_redraw()

# Draw the rope
func _draw() -> void:
	if _editor_mode:
		# Draw a preview in the editor between anchor positions
		if _start_node and _end_node:
			var start = to_local(_start_node.global_position)
			var end = to_local(_end_node.global_position)
			RopeRenderingSystem.draw_editor_preview(
				self, start, end, rope_color, pixel_size, 
				line_algorithm, pixel_spacing
			)
		return
		
	if not _rope_data or _rope_data.segments.is_empty():
		return
	
	# Draw the rope using the rendering system
	RopeRenderingSystem.draw_rope(
		self, 
		_rope_data, 
		func(pos): return to_local(pos), # Local transform function
		_rope_state,
		rope_color, 
		pixel_size, 
		line_algorithm, 
		pixel_spacing
	)

# Public methods
func break_rope() -> void:
	var state_result = RopeStateSystem.break_rope()
	_rope_state = state_result[0]
	_rope_broken = state_result[1]
	rope_broken.emit()

func reset_rope() -> void:
	var state_result = RopeStateSystem.reset_state()
	_rope_state = state_result[0]
	_rope_broken = state_result[1]
	_initialize_rope()

func get_state() -> int:
	return _rope_state
