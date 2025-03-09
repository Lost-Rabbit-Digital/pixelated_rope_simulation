@tool
extends EditorPlugin

const RopeScene = preload("res://addons/pixel_rope/example/demo_scene.tscn")
var rope_button: Button
var is_rope_creating_mode: bool = false
var start_position: Vector2
var current_rope: Node

func _enter_tree() -> void:
	# Create the rope creator button
	rope_button = Button.new()
	rope_button.text = "Create Rope"
	rope_button.tooltip_text = "Click and drag to create a rope"
	rope_button.flat = true
	rope_button.pressed.connect(_on_rope_button_pressed)
	
	add_control_to_container(EditorPlugin.CONTAINER_CANVAS_EDITOR_MENU, rope_button)

func _exit_tree() -> void:
	# Clean up
	if rope_button:
		remove_control_from_container(EditorPlugin.CONTAINER_CANVAS_EDITOR_MENU, rope_button)
		rope_button.queue_free()

func _on_rope_button_pressed() -> void:
	# Toggle the rope creation mode
	is_rope_creating_mode = !is_rope_creating_mode
	
	if is_rope_creating_mode:
		rope_button.text = "Cancel Rope"
	else:
		rope_button.text = "Create Rope"
		if current_rope:
			current_rope.queue_free()
			current_rope = null

# Handle input in the editor viewport
func _forward_canvas_gui_input(event: InputEvent) -> bool:
	if not is_rope_creating_mode:
		return false
	
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				# Start position of the rope
				start_position = get_editor_interface().get_editor_viewport().get_screen_transform().affine_inverse() * event.position
				
				# Create a temporary rope
				current_rope = RopeScene.instantiate()
				get_editor_interface().get_edited_scene_root().add_child.call_deferred(current_rope)
				current_rope.owner = get_editor_interface().get_edited_scene_root()
				
				# Set up the anchors
				var start_anchor = current_rope.get_node("StartAnchor")
				start_anchor.global_position = start_position
				
				var end_anchor = current_rope.get_node("EndAnchor")
				end_anchor.global_position = start_position
				
				return true
			else:
				# End position and finalize rope
				if current_rope:
					var end_position = get_editor_interface().get_editor_viewport().get_screen_transform().affine_inverse() * event.position
					var end_anchor = current_rope.get_node("EndAnchor")
					end_anchor.global_position = end_position
					
					# Update rope properties based on length
					var rope = current_rope.get_node("PixelRope")
					var distance = start_position.distance_to(end_position)
					rope.segment_count = max(int(distance / 20.0), 5)
					rope.segment_length = distance / float(rope.segment_count)
					
					current_rope = null
					is_rope_creating_mode = false
					rope_button.text = "Create Rope"
					
					return true
	
	if event is InputEventMouseMotion and current_rope:
		# Update the end position during dragging
		var end_position = get_editor_interface().get_editor_viewport().get_screen_transform().affine_inverse() * event.position
		var end_anchor = current_rope.get_node("EndAnchor")
		end_anchor.global_position = end_position
		return true
	
	return false
