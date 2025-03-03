@tool
@icon("res://addons/pixel_rope/icons/Curve2D.svg")
## A physically-simulated, pixel-perfect rope with Bresenham rendering
##
## Implements a complete rope physics system using verlet integration with
## configurable properties including segment count, length, gravity, and tension.
## Features pixelated rendering using the Bresenham line algorithm for authentic
## retro visuals. Supports dynamic interaction with breakable ropes, stretch detection,
## and drag-and-drop functionality. Requires anchor nodes for start and end points.
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
@export var segment_count: int = 30
@export var segment_length: float = 25.0
@export var rope_color: Color = Color(0.8, 0.6, 0.2)

@export_group("Pixelation Properties")
@export var pixel_size: int = 8
@export var pixel_spacing: int = 0

@export_group("Physics Properties")
@export var gravity: Vector2 = Vector2(0, 980)
@export var damping: float = 0.98
@export var iterations: int = 5
@export var max_stretch_factor: float = 1.5

# Node references - now using node names since they're children
@export var start_anchor_name: String = "StartAnchor"
@export var end_anchor_name: String = "EndAnchor"

# Private variables
var _start_node: Node2D
var _end_node: Node2D
var _segments: Array[Dictionary] = []
var _state: RopeState = RopeState.NORMAL
var _broken: bool = false
var _initialized: bool = false

# Dragging variables
var _is_dragging: bool = false
var _mouse_over_end: bool = false

# Editor-specific variables
var _editor_mode: bool = false

# Called when the node enters the scene tree
func _ready() -> void:
	# Check if we're in the editor
	_editor_mode = Engine.is_editor_hint()
	
	# Initialize in game mode only
	if not _editor_mode:
		# Wait one frame to make sure all nodes are ready
		await get_tree().process_frame
		
		# Get the anchor nodes from children
		_start_node = find_child(start_anchor_name, true)
		_end_node = find_child(end_anchor_name, true)
		
		if not _start_node or not _end_node:
			push_error("PixelRope: Could not find anchor nodes named '%s' and '%s'" % [start_anchor_name, end_anchor_name])
			return
		
		print("PixelRope: Initializing rope between", _start_node.name, "and", _end_node.name)
		
		# Set up interaction for the end anchor
		_setup_draggable_node(_end_node)
		
		# Initialize the rope
		_initialize_rope()
		_initialized = true
	else:
		# In editor mode, just make it visible
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

# Mouse handling for dragging
func _input(event: InputEvent) -> void:
	if _editor_mode:
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
	if _editor_mode or not _initialized:
		return
		
	if _segments.is_empty():
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

# Draw the rope using Bresenham's line algorithm for pixelation
func _draw() -> void:
	if _editor_mode:
		# Draw a preview in the editor
		var start = Vector2(-100, 0)
		var end = Vector2(100, 0)
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

# Bresenham's line algorithm implementation for pixelated drawing
func _draw_pixelated_line(from: Vector2, to: Vector2, color: Color) -> void:
	# Snap to pixel grid
	var grid_from = Vector2(
		round(from.x / pixel_size) * pixel_size,
		round(from.y / pixel_size) * pixel_size
	)
	
	var grid_to = Vector2(
		round(to.x / pixel_size) * pixel_size,
		round(to.y / pixel_size) * pixel_size
	)
	
	# Get the grid points using Bresenham's algorithm
	var points = _bresenham_line(grid_from, grid_to)
	
	# Draw pixels
	for point in points:
		# Draw main pixel
		_draw_pixel(point, pixel_size, color)

# Implementation of Bresenham's line algorithm
func _bresenham_line(from: Vector2, to: Vector2) -> Array[Vector2]:
	var points: Array[Vector2] = []
	
	var x0 = int(from.x / pixel_size)
	var y0 = int(from.y / pixel_size)
	var x1 = int(to.x / pixel_size)
	var y1 = int(to.y / pixel_size)
	
	var dx = abs(x1 - x0)
	var dy = -abs(y1 - y0)
	var sx = 1 if x0 < x1 else -1
	var sy = 1 if y0 < y1 else -1
	var err = dx + dy
	
	# Apply pixel spacing to make the rope less dense
	var pixel_count = 0
	
	while true:
		# Only add points based on spacing
		if pixel_spacing == 0 or pixel_count % (pixel_spacing + 1) == 0:
			points.append(Vector2(x0 * pixel_size, y0 * pixel_size))
		
		pixel_count += 1
		
		if x0 == x1 and y0 == y1:
			break
			
		var e2 = 2 * err
		if e2 >= dy:
			if x0 == x1:
				break
			err += dy
			x0 += sx
		
		if e2 <= dx:
			if y0 == y1:
				break
			err += dx
			y0 += sy
	
	return points

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

# Editor methods
func _get_tool_buttons() -> Array:
	return []
