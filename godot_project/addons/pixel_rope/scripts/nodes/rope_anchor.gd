@tool
@icon("res://addons/pixel_rope/icons/CircleShape2D.svg")
## An interactive anchor point for rope connections
##
## Creates a circular node that serves as an attachment point for PixelRope instances.
## Features adjustable radius and color, with built-in collision detection for
## interaction. Automatically sets up required physics components on creation.
class_name RopeAnchor
extends Node2D

@export var radius: float = 8.0:
	set(value):
		radius = value
		_update_collision_shape()
		queue_redraw()

@export var color: Color = Color.WHITE:
	set(value):
		color = value
		queue_redraw()

var _last_position: Vector2
var _editor_mode: bool = false

func _ready() -> void:
	# Check if we're in the editor
	_editor_mode = Engine.is_editor_hint()
	
	# Store initial position
	_last_position = position
	
	# Make sure we have an Area2D for interaction
	if not has_node("Area2D"):
		var area = Area2D.new()
		area.name = "Area2D"
		
		var collision = CollisionShape2D.new()
		collision.name = "CollisionShape2D"
		
		var shape = CircleShape2D.new()
		shape.radius = radius
		
		collision.shape = shape
		area.add_child(collision)
		add_child(area)
		
		if _editor_mode and get_tree().edited_scene_root:
			area.owner = get_tree().edited_scene_root
			collision.owner = get_tree().edited_scene_root
	else:
		# Update existing shape
		_update_collision_shape()

func _draw() -> void:
	draw_circle(Vector2.ZERO, radius, color)

func _update_collision_shape() -> void:
	var area = get_node_or_null("Area2D")
	if area:
		var collision = area.get_node_or_null("CollisionShape2D")
		if collision and collision.shape is CircleShape2D:
			collision.shape.radius = radius

func _notification(what: int) -> void:
	match what:
		NOTIFICATION_TRANSFORM_CHANGED:
			# Position has changed, notify parent if in editor
			if _editor_mode and position != _last_position:
				_last_position = position
				_notify_parent_of_movement()
	
# Notify the parent rope of position changes
func _notify_parent_of_movement() -> void:
	if not _editor_mode:
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

# Listen for property changes in the editor
func _set(property: StringName, value) -> bool:
	if property == "position" and _editor_mode:
		# Position changed directly
		_last_position = value
		_notify_parent_of_movement()
	return false

# This is called in the editor when moving the node
func _process(_delta: float) -> void:
	if _editor_mode and position != _last_position:
		_last_position = position
		_notify_parent_of_movement()
