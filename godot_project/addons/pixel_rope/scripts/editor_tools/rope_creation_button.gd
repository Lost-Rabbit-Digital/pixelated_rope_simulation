@tool
## Editor toolbar button for creating PixelRope instances by click-and-drag.
extends EditorPlugin

const DISABLED_TOOLTIP := "DISABLED: Enable to spawn rope nodes on click"
const ENABLED_TOOLTIP := "ENABLED: Currently spawning pixel rope nodes"
const DISABLED_COLOR := Color(1.0, 0.5, 0.5)
const ENABLED_COLOR := Color(0.5, 1.0, 0.5)
const RopeScene = preload("res://addons/pixel_rope/examples/basic_ropes/demo_scene_1.tscn")

var rope_button: Button
var is_rope_creating_mode: bool = false
var start_position: Vector2
var current_rope: Node
var _editor_selection: EditorSelection
var plugin_root: EditorPlugin


func initialize(parent_plugin: EditorPlugin, editor_selection: EditorSelection) -> void:
	plugin_root = parent_plugin
	_editor_selection = editor_selection

	rope_button = Button.new()
	rope_button.toggle_mode = false
	rope_button.tooltip_text = DISABLED_TOOLTIP
	rope_button.modulate = DISABLED_COLOR
	rope_button.icon = preload("res://addons/pixel_rope/icons/Curve2D.svg")
	rope_button.pressed.connect(_on_rope_button_pressed)

	plugin_root.add_control_to_container(EditorPlugin.CONTAINER_CANVAS_EDITOR_MENU, rope_button)


func cleanup() -> void:
	if rope_button:
		plugin_root.remove_control_from_container(EditorPlugin.CONTAINER_CANVAS_EDITOR_MENU, rope_button)
		rope_button.queue_free()
		rope_button = null


func _on_rope_button_pressed() -> void:
	is_rope_creating_mode = not is_rope_creating_mode

	if is_rope_creating_mode:
		rope_button.toggle_mode = true
		rope_button.tooltip_text = ENABLED_TOOLTIP
		rope_button.modulate = ENABLED_COLOR
	else:
		rope_button.toggle_mode = false
		rope_button.tooltip_text = DISABLED_TOOLTIP
		rope_button.modulate = DISABLED_COLOR
		if current_rope:
			current_rope.queue_free()
			current_rope = null


func handle_input(event: InputEvent) -> bool:
	if not is_rope_creating_mode:
		return false

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			start_position = _get_world_position(event)
			var scene_root := plugin_root.get_editor_interface().get_edited_scene_root()
			if not scene_root:
				return false

			current_rope = RopeScene.instantiate()
			scene_root.add_child(current_rope)
			current_rope.owner = scene_root

			var start_anchor := current_rope.get_node("StartAnchor")
			start_anchor.global_position = start_position
			var end_anchor := current_rope.get_node("EndAnchor")
			end_anchor.global_position = start_position
			return true
		else:
			if not current_rope:
				return false

			var end_pos := _get_world_position(event)
			current_rope.get_node("EndAnchor").global_position = end_pos

			var rope := current_rope.get_node("PixelRope")
			var distance := start_position.distance_to(end_pos)
			rope.segment_count = max(int(distance / 20.0), 5)
			rope.segment_length = distance / float(rope.segment_count)

			current_rope = null
			is_rope_creating_mode = false
			rope_button.toggle_mode = false
			rope_button.tooltip_text = DISABLED_TOOLTIP
			rope_button.modulate = DISABLED_COLOR
			return true

	if event is InputEventMouseMotion and current_rope:
		current_rope.get_node("EndAnchor").global_position = _get_world_position(event)
		return true

	return false


func _get_world_position(event: InputEvent) -> Vector2:
	var canvas: Control = plugin_root.get_editor_interface().get_editor_viewport()
	return canvas.get_canvas_transform().affine_inverse() * event.position
