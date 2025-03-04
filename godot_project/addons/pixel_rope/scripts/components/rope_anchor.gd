@icon("res://addons/pixel_rope/icons/CircleShape2D.svg")
## An optimized anchor point for PixelRope connections
##
## Creates a minimalist, editor-friendly anchor point that can be positioned
## through direct dragging in the editor. Displays only a debug collision shape
## and efficiently communicates position changes to the parent rope.
class_name RopeAnchor
extends Node2D

## Signal emitted when the anchor position changes in the editor
signal position_changed

## Radius of the anchor's collision detection area
@export var radius: float = 8.0:
	set(value):
		radius = value
		_update_collision_shape()

## Color of the debug visualization (only affects collision shape)
@export var debug_color: Color = Color(0.7, 0.7, 1.0, 0.5):
	set(value):
		debug_color = value
		_update_debug_visualization()

## Whether to show the collision debug shape
@export var show_debug_shape: bool = true:
	set(value):
		show_debug_shape = value
		_update_debug_visualization()

# Editor and runtime tracking variables
var _last_position: Vector2
var _is_editor: bool = false
var _is_initialized: bool = false
var _dragging: bool = false
var _drag_offset: Vector2

func _ready() -> void:
	# Check if running in the editor
	_is_editor = Engine.is_editor_hint()
	
	# Store initial position for change detection
	_last_position = position
	
	# Setup the collision area in a deferred way to avoid errors
	_setup_collision_area()
	
	_is_initialized = true

func _setup_collision_area() -> void:
	# Check if the Area2D already exists
	if has_node("Area2D"):
		# Just update existing components
		_update_collision_shape()
		_update_debug_visualization()
		return
		
	# Create Area2D for interaction
	var area = Area2D.new()
	area.name = "Area2D"
	
	# Create collision shape
	var collision = CollisionShape2D.new()
	collision.name = "CollisionShape2D"
	
	# Create circle shape
	var shape = CircleShape2D.new()
	shape.radius = radius
	collision.shape = shape
	
	# Set debug color
	if show_debug_shape:
		collision.debug_color = debug_color
	else:
		collision.debug_color = Color(0, 0, 0, 0)
	
	# Add child nodes
	area.add_child(collision)
	add_child(area)
	
	# Set ownership if in edited scene
	if _is_editor and get_tree().edited_scene_root:
		area.owner = get_tree().edited_scene_root
		collision.owner = get_tree().edited_scene_root

func _update_collision_shape() -> void:
	if not _is_initialized:
		return
		
	var area = get_node_or_null("Area2D")
	if not area:
		return
		
	var collision = area.get_node_or_null("CollisionShape2D")
	if not collision or not collision.shape is CircleShape2D:
		return
		
	collision.shape.radius = radius

func _update_debug_visualization() -> void:
	if not _is_initialized:
		return
		
	var area = get_node_or_null("Area2D")
	if not area:
		return
		
	var collision = area.get_node_or_null("CollisionShape2D")
	if not collision:
		return
		
	if show_debug_shape:
		collision.debug_color = debug_color
	else:
		collision.debug_color = Color(0, 0, 0, 0)

func _notification(what: int) -> void:
	match what:
		NOTIFICATION_TRANSFORM_CHANGED:
			if _is_editor and position != _last_position and not _dragging:
				_last_position = position
				_notify_parent_of_movement()

# Handle mouse input for dragging in the editor
func _input(event: InputEvent) -> void:
	if not _is_editor:
		return
	
	# Handle mouse actions only within the editor viewport
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		var area = get_node_or_null("Area2D")
		if not area:
			return
			
		# Calculate global mouse position in viewport
		var global_mouse_pos = get_viewport().get_canvas_transform().affine_inverse() * event.position
		
		# Test if the click is within our shape radius
		var distance = global_mouse_pos.distance_to(global_position)
		
		if event.pressed:
			# Start dragging if mouse is over the anchor
			if distance <= radius:
				_dragging = true
				_drag_offset = global_position - global_mouse_pos
				get_viewport().set_input_as_handled()
		else:
			# Stop dragging
			if _dragging:
				_dragging = false
				_notify_parent_of_movement()
				get_viewport().set_input_as_handled()
	
	# Handle dragging motion
	elif event is InputEventMouseMotion and _dragging:
		var global_mouse_pos = get_viewport().get_canvas_transform().affine_inverse() * event.position
		# Update position with the original offset to maintain grab point
		global_position = global_mouse_pos + _drag_offset
		_last_position = position
		_notify_parent_of_movement()
		get_viewport().set_input_as_handled()

# Notify the parent rope of position changes
func _notify_parent_of_movement() -> void:
	if not _is_editor:
		return
		
	var parent = get_parent()
	if parent is PixelRope:
		# Update the parent rope's corresponding property
		if name == "StartAnchor":
			parent.start_position = position
		elif name == "EndAnchor":
			parent.end_position = position
			
		# Force a redraw
		parent.queue_redraw()
		# Emit signal for potential listeners
		position_changed.emit()

# This prevents the editor from grabbing the node when we're handling the drag
func _get_configuration_warnings() -> PackedStringArray:
	# Return empty array to keep the node "valid"
	return []
