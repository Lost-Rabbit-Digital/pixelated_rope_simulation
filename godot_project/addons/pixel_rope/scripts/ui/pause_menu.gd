extends CanvasLayer
## Pause menu overlay that can be toggled with Escape or P.
## Registered as an autoload so it works across all demo scenes.

const DEMO_SCENES: Array[Dictionary] = [
	{"name": "Basic Ropes", "path": "res://addons/pixel_rope/examples/basic_ropes/basic_rope_demo.tscn"},
	{"name": "Dynamic Bridge", "path": "res://addons/pixel_rope/examples/dynamic_bridge/dynamic_bridge_demo.tscn"},
	{"name": "Dynamic Lights", "path": "res://addons/pixel_rope/examples/dynamic_lights/dynamic_lights_demo.tscn"},
	{"name": "Grappling Hook", "path": "res://addons/pixel_rope/examples/grappling_hook/grappling_hook_demo.tscn"},
	{"name": "Pulley System", "path": "res://addons/pixel_rope/examples/pulley_interaction/puley_demo.tscn"},
	{"name": "Technical Playground", "path": "res://addons/pixel_rope/examples/technical_playground/playground_demo.tscn"},
	{"name": "Towing & Winching", "path": "res://addons/pixel_rope/examples/towing_and_winching/towing_and_winching_demo.tscn"},
]

var _panel: Control
var _visible: bool = false
var _scene_buttons: Array[Button] = []


func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()
	_set_menu_visible(false)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE or event.keycode == KEY_P:
			_toggle_pause()
			get_viewport().set_input_as_handled()


func _toggle_pause() -> void:
	_set_menu_visible(not _visible)


func _set_menu_visible(show: bool) -> void:
	_visible = show
	_panel.visible = show
	get_tree().paused = show
	if show:
		_update_current_scene_highlight()


func _update_current_scene_highlight() -> void:
	var current_path := get_tree().current_scene.scene_file_path
	for btn in _scene_buttons:
		var scene_path: String = btn.get_meta("scene_path")
		if scene_path == current_path:
			btn.text = "> " + btn.text.trim_prefix("> ") + " (current)"
			btn.disabled = true
		else:
			btn.text = btn.text.trim_prefix("> ").replace(" (current)", "")
			btn.disabled = false


func _build_ui() -> void:
	# Full-screen dark overlay
	var overlay := ColorRect.new()
	overlay.color = Color(0.0, 0.0, 0.0, 0.6)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(overlay)
	_panel = overlay  # Reuse overlay as the toggled root

	# Center container
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)

	# Panel
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.13, 0.10, 0.95)
	style.border_color = Color(0.8, 0.6, 0.2, 0.8)
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(24)
	panel.add_theme_stylebox_override("panel", style)
	center.add_child(panel)

	# Main vertical layout
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	panel.add_child(vbox)

	# Title
	var title := Label.new()
	title.text = "PAUSED"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Color(0.8, 0.6, 0.2))
	vbox.add_child(title)

	# Separator
	vbox.add_child(HSeparator.new())

	# Resume button
	var resume_btn := _create_button("Resume", Color(0.2, 0.7, 0.3))
	resume_btn.pressed.connect(_on_resume)
	vbox.add_child(resume_btn)

	# Restart button
	var restart_btn := _create_button("Restart Scene", Color(0.9, 0.6, 0.1))
	restart_btn.pressed.connect(_on_restart)
	vbox.add_child(restart_btn)

	# Separator before scene list
	vbox.add_child(HSeparator.new())

	# Scene heading
	var scene_label := Label.new()
	scene_label.text = "Demo Scenes"
	scene_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	scene_label.add_theme_font_size_override("font_size", 18)
	scene_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	vbox.add_child(scene_label)

	# Scene buttons
	_scene_buttons.clear()
	for demo in DEMO_SCENES:
		var btn := _create_button(demo["name"], Color(0.3, 0.5, 0.8))
		btn.set_meta("scene_path", demo["path"])
		btn.pressed.connect(_on_scene_selected.bind(demo["path"]))
		_scene_buttons.append(btn)
		vbox.add_child(btn)

	# Hint
	var hint := Label.new()
	hint.text = "Press Escape or P to resume"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 12)
	hint.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
	vbox.add_child(hint)


func _create_button(text: String, color: Color) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(260, 36)

	var normal := StyleBoxFlat.new()
	normal.bg_color = color.darkened(0.5)
	normal.set_corner_radius_all(4)
	normal.set_content_margin_all(8)
	btn.add_theme_stylebox_override("normal", normal)

	var hover := StyleBoxFlat.new()
	hover.bg_color = color.darkened(0.3)
	hover.set_corner_radius_all(4)
	hover.set_content_margin_all(8)
	btn.add_theme_stylebox_override("hover", hover)

	var pressed := StyleBoxFlat.new()
	pressed.bg_color = color.darkened(0.6)
	pressed.set_corner_radius_all(4)
	pressed.set_content_margin_all(8)
	btn.add_theme_stylebox_override("pressed", pressed)

	return btn


func _on_resume() -> void:
	_set_menu_visible(false)


func _on_restart() -> void:
	_set_menu_visible(false)
	get_tree().reload_current_scene()


func _on_scene_selected(scene_path: String) -> void:
	_set_menu_visible(false)
	get_tree().change_scene_to_file(scene_path)
