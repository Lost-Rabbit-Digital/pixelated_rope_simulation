@tool
## PixelRope editor plugin - registers custom node types and handles editor integration.
extends EditorPlugin

const rope_node_script = preload("res://addons/pixel_rope/scripts/components/rope_node.gd")
const rope_anchor_script = preload("res://addons/pixel_rope/scripts/components/rope_anchor.gd")
const rope_creation_tool_script = preload("res://addons/pixel_rope/scripts/editor_tools/rope_creation_button.gd")

var _editor_selection: EditorSelection
var _selected_rope: PixelRope
var _selected_anchor: RopeAnchor
var _rope_creation_tool = null


func _enter_tree() -> void:
	add_custom_type("PixelRope", "Node2D", rope_node_script,
		preload("res://addons/pixel_rope/icons/Curve2D.svg"))
	add_custom_type("RopeAnchor", "Node2D", rope_anchor_script,
		preload("res://addons/pixel_rope/icons/CircleShape2D.svg"))

	_editor_selection = get_editor_interface().get_selection()
	_editor_selection.selection_changed.connect(_on_selection_changed)

	_rope_creation_tool = rope_creation_tool_script.new()
	_rope_creation_tool.initialize(self, _editor_selection)


func _exit_tree() -> void:
	remove_custom_type("PixelRope")
	remove_custom_type("RopeAnchor")

	if _editor_selection and _editor_selection.selection_changed.is_connected(_on_selection_changed):
		_editor_selection.selection_changed.disconnect(_on_selection_changed)

	if _rope_creation_tool:
		_rope_creation_tool.cleanup()
		_rope_creation_tool = null


func _on_selection_changed() -> void:
	_selected_rope = null
	_selected_anchor = null

	var selected := _editor_selection.get_selected_nodes()
	if selected.size() != 1:
		return

	if selected[0] is PixelRope:
		_selected_rope = selected[0]
		_selected_rope.queue_redraw()
	elif selected[0] is RopeAnchor:
		_selected_anchor = selected[0]
		var parent := _selected_anchor.get_parent()
		if parent is PixelRope:
			_selected_rope = parent
			_selected_rope.queue_redraw()


func _forward_canvas_gui_input(event: InputEvent) -> bool:
	if _rope_creation_tool and _rope_creation_tool.handle_input(event):
		return true

	if _selected_anchor and _selected_anchor.has_method("_input"):
		_selected_anchor._input(event)
		return true

	return false


func _has_main_screen() -> bool:
	return false
