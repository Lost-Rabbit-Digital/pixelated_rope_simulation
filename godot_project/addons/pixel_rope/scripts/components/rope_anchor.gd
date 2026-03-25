@tool
@icon("res://addons/pixel_rope/icons/CircleShape2D.svg")
## An anchor point for PixelRope connections.
##
## Provides editor-draggable anchor points with collision detection areas.
## Notifies the parent rope when position changes.
class_name RopeAnchor
extends Node2D

signal position_changed

@export var radius: float = 8.0:
	set(v):
		radius = v
		_update_shape()

@export var debug_color: Color = Color(0.7, 0.7, 1.0, 0.5):
	set(v):
		debug_color = v
		_update_debug()

@export var show_debug_shape: bool = true:
	set(v):
		show_debug_shape = v
		_update_debug()

var _is_editor: bool = false
var _dragging: bool = false
var _drag_offset: Vector2
var _last_position: Vector2


func _ready() -> void:
	_is_editor = Engine.is_editor_hint()
	_last_position = position
	_ensure_collision_area()


func _ensure_collision_area() -> void:
	if has_node("Area2D"):
		_update_shape()
		_update_debug()
		return

	var area := Area2D.new()
	area.name = "Area2D"

	var collision := CollisionShape2D.new()
	collision.name = "CollisionShape2D"

	var shape := CircleShape2D.new()
	shape.radius = radius
	collision.shape = shape
	collision.debug_color = debug_color if show_debug_shape else Color(0, 0, 0, 0)

	area.add_child(collision)
	add_child(area)

	if _is_editor and get_tree().edited_scene_root:
		area.owner = get_tree().edited_scene_root
		collision.owner = get_tree().edited_scene_root


func _update_shape() -> void:
	var collision := _get_collision()
	if collision and collision.shape is CircleShape2D:
		collision.shape.radius = radius


func _update_debug() -> void:
	var collision := _get_collision()
	if collision:
		collision.debug_color = debug_color if show_debug_shape else Color(0, 0, 0, 0)


func _get_collision() -> CollisionShape2D:
	var area := get_node_or_null("Area2D")
	if area:
		return area.get_node_or_null("CollisionShape2D")
	return null


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSFORM_CHANGED:
		if _is_editor and position != _last_position and not _dragging:
			_last_position = position
			_notify_parent()


func _input(event: InputEvent) -> void:
	if not _is_editor:
		return

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		var mouse: Vector2 = get_viewport().get_canvas_transform().affine_inverse() * event.position

		if event.pressed:
			if mouse.distance_to(global_position) <= radius:
				_dragging = true
				_drag_offset = global_position - mouse
				get_viewport().set_input_as_handled()
		elif _dragging:
			_dragging = false
			_notify_parent()
			get_viewport().set_input_as_handled()

	elif event is InputEventMouseMotion and _dragging:
		var mouse: Vector2 = get_viewport().get_canvas_transform().affine_inverse() * event.position
		global_position = mouse + _drag_offset
		_last_position = position
		_notify_parent()
		get_viewport().set_input_as_handled()


func _notify_parent() -> void:
	if not _is_editor:
		return

	var parent := get_parent()
	if parent is PixelRope:
		if name == "StartAnchor":
			parent.start_position = position
		elif name == "EndAnchor":
			parent.end_position = position
		parent.queue_redraw()

	position_changed.emit()
