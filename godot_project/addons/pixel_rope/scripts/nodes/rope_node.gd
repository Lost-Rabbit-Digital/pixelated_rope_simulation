@tool
@icon("res://addons/pixel_rope/icons/Curve2D.svg")
## A physically-simulated, pixel-perfect rope with multiple rendering algorithms
##
## Implements a complete rope physics system using verlet integration with
## configurable properties including segment count, length, gravity, and tension.
## Features pixelated rendering using either Bresenham or DDA line algorithms for
## authentic retro visuals. Supports dynamic interaction with breakable ropes,
## stretch detection, and drag-and-drop functionality.
extends Node2D
class_name PixelRope

# Signals
signal rope_broken

# Enums
enum RopeState {
	NORMAL,
	STRETCHED,
	BROKEN
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
@export var pixel_size: int = 8:
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

@export var anchor_color: Color = Color.WHITE:
	set(value):
		anchor_color = value
		_update_anchor_properties()
		if Engine.is_editor_hint():
			queue_redraw()

@export var end_anchor_draggable: bool = true
@export var show_anchors: bool = true:
	set(value):
		show_anchors = value
		_update_anchor_visibility()

# Private variables
var _start_node: Node2D
var _end_node: Node2D
var _segments: Array[Dictionary] = []
var _state: RopeState = RopeState.NORMAL
var _broken: bool = false
var _initialized: bool = false
var _last_start_pos: Vector2
var _last_end_pos: Vector2

# Dragging variables
var _is_dragging: bool = false
var _mouse_over_end: bool = false

# Editor-specific variables
var _editor_mode: bool = false
var _editor_timer: SceneTreeTimer

# Called when the node enters the scene tree
func _ready() -> void:
	# Check if we're in the editor
	_editor_mode = Engine.is_editor_hint()
	
	# Create anchor nodes if they don't exist
	_ensure_anchor_nodes()
	
	# Update anchor visibility
	_update_anchor_visibility()
	
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
		if end_anchor_draggable:
			_setup_draggable_node(_end_node)
		
		# Initialize the rope
		_initialize_rope()
		_initialized = true

# Set up a timer for editor updates
func _setup_editor_updates() -> void:
	# Cancel any existing timer
	if _editor_timer and not _editor_timer.is_queued_for_deletion():
		_editor_timer.disconnect("timeout", Callable(self, "_check_for_anchor_movement"))
		
	# Create a new timer that fires frequently to check for changes
	_editor_timer = get_tree().create_timer(0.05) # 50ms
	_editor_timer.connect("timeout", Callable(self, "_check_for_anchor_movement"))

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
	
	# Create Area2D
	var area = Area2D.new()
	area.name = "Area2D"
	
	var collision = CollisionShape2D.new()
	collision.name = "CollisionShape2D"
	
	var shape = CircleShape2D.new()
	shape.radius = anchor_radius
	
	collision.shape = shape
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

# Update anchor properties when changed
func _update_anchor_properties() -> void:
	if _start_node and _start_node.has_method("set"):
		_start_node.set("radius", anchor_radius)
		_start_node.set("color", anchor_color)
	
	if _end_node and _end_node.has_method("set"):
		_end_node.set("radius", anchor_radius)
		_end_node.set("color", anchor_color)

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
		area.add_child(collision)
		node.add_child(area)
	
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
		
		_segments.append({
			"position": pos,
			"old_position": pos,
			"is_locked": (i == 0 or i == segment_count)
		})
	
	print("PixelRope: Created", _segments.size(), "segments with length", segment_length)
	_broken = false
	_state = RopeState.NORMAL

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
	return false

# Mouse handling for dragging
func _input(event: InputEvent) -> void:
	if _editor_mode:
		# Handle editor dragging here if needed
		return
		
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			_is_dragging = event.pressed and _mouse_over_end
			
			if not event.pressed and _state == RopeState.BROKEN:
				reset_rope()

func _on_end_node_mouse_entered() -> void:
	_mouse_over_end = true
	Input.set_default_cursor_shape(Input.CURSOR_POINTING_HAND)

func _on_end_node_mouse_exited() -> void:
	_mouse_over_end = false
	Input.set_default_cursor_shape(Input.CURSOR_ARROW)

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
	
	# Handle dragging of end node - keep this active even when broken
	if _is_dragging:
		_end_node.global_position = get_global_mouse_position()
	
	# If rope is broken, just request redraw to update the red line
	if _broken:
		queue_redraw()
		return
		
	# Update endpoints to match node positions
	_segments[0].position = _start_node.global_position
	_segments[segment_count].position = _end_node.global_position
	
	# Apply physics
	_update_physics(delta)
	
	# Check if rope is stretched too much
	_check_rope_state()
	
	# Request redraw
	queue_redraw()

# Apply verlet integration and constraints
func _update_physics(delta: float) -> void:
	# Apply verlet integration
	for i in range(_segments.size()):
		var segment: Dictionary = _segments[i]
		
		if segment.is_locked:
			continue
			
		var temp: Vector2 = segment.position
		var velocity: Vector2 = segment.position - segment.old_position
		
		# Apply forces
		segment.position += velocity * damping + gravity * delta * delta
		segment.old_position = temp
		
		_segments[i] = segment
	
	# Apply constraints multiple times for stability
	for _i in range(iterations):
		_apply_constraints()

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
		
		# Apply position correction
		if not segment1.is_locked:
			segment1.position -= correction * 0.5
			_segments[i] = segment1
			
		if not segment2.is_locked:
			segment2.position += correction * 0.5
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
