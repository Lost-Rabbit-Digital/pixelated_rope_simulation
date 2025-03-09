@tool
## A high-performance pixel-perfect rope simulation node
## 
## Implements rope physics using multiple line drawing algorithms for accurate
## pixel rendering. Features include configurable tension, gravity effects,
## collision detection, and anchoring points. Ideal for platformers, puzzle
## games, and any project requiring interactive rope mechanics.
extends EditorPlugin

# Register custom node types
const rope_node_script = preload("res://addons/pixel_rope/scripts/components/rope_node.gd")
const rope_anchor_script = preload("res://addons/pixel_rope/scripts/components/rope_anchor.gd")
const line_algorithms = preload("res://addons/pixel_rope/scripts/utils/line_algorithms.gd")

# Editor gizmo and selection tracking
var _editor_selection: EditorSelection
var _current_selected_rope: PixelRope = null
var _current_selected_anchor: RopeAnchor = null

# Rope creator tool
var toolbar: HBoxContainer
var rope_button: Button
var separator: VSeparator
var is_rope_creating_mode: bool = false
var start_position: Vector2
var current_rope: Node
const RopeScene = preload("res://addons/pixel_rope/example/demo_scene.tscn")

func _enter_tree() -> void:
	# Add custom types with icons
	add_custom_type(
		"PixelRope", 
		"Node2D", 
		rope_node_script, 
		preload("res://addons/pixel_rope/icons/Curve2D.svg")
	)
	
	add_custom_type(
		"RopeAnchor", 
		"Node2D", 
		rope_anchor_script, 
		preload("res://addons/pixel_rope/icons/CircleShape2D.svg")
	)
	
	# Get editor selection
	_editor_selection = get_editor_interface().get_selection()
	_editor_selection.selection_changed.connect(_on_editor_selection_changed)
	
	# Setup the rope creator toolbar
	_setup_rope_creator()
	
	print("PixelRope - Plugin enabled")

func _exit_tree() -> void:
	# Clean-up
	remove_custom_type("PixelRope")
	remove_custom_type("RopeAnchor")
	
	# Disconnect selection tracking
	if _editor_selection and _editor_selection.selection_changed.is_connected(_on_editor_selection_changed):
		_editor_selection.selection_changed.disconnect(_on_editor_selection_changed)
	
	# Clean up rope creator
	_cleanup_rope_creator()
	
	push_warning("PixelRope - Plugin disabled")

# Setup the rope creator toolbar and button
func _setup_rope_creator() -> void:
	# Create toolbar container
	toolbar = HBoxContainer.new()
	
	# Create a separator for visual clarity
	separator = VSeparator.new()
	toolbar.add_child(separator)
	
	# Create the rope creator button
	rope_button = Button.new()
	rope_button.text = "Create Rope"
	rope_button.tooltip_text = "Click and drag to create a rope"
	rope_button.flat = true
	rope_button.icon = preload("res://addons/pixel_rope/icons/Curve2D.svg")
	rope_button.pressed.connect(_on_rope_button_pressed)
	toolbar.add_child(rope_button)
	
	# Add toolbar to the editor
	add_control_to_container(EditorPlugin.CONTAINER_CANVAS_EDITOR_MENU, toolbar)
	
	print("PixelRope - Initialized toolbar button in 2D Editor")

# Clean up the rope creator
func _cleanup_rope_creator() -> void:
	if toolbar:
		remove_control_from_container(EditorPlugin.CONTAINER_CANVAS_EDITOR_MENU, toolbar)
		toolbar.queue_free()
		toolbar = null
		
	print("PixelRope - Removed button from toolbar in 2D Editor")

func _on_rope_button_pressed() -> void:
	# Toggle the rope creation mode
	is_rope_creating_mode = !is_rope_creating_mode
	
	if is_rope_creating_mode:
		rope_button.text = "Cancel Rope"
		rope_button.modulate = Color(1.0, 0.5, 0.5) # Visual feedback for active state
	else:
		rope_button.text = "Create Rope"
		rope_button.modulate = Color(1.0, 1.0, 1.0) # Reset color
		if current_rope:
			current_rope.queue_free()
			current_rope = null

# Handle selection changes in the editor
func _on_editor_selection_changed() -> void:
	var selected = _editor_selection.get_selected_nodes()
	
	# Clear current selections
	_current_selected_rope = null
	_current_selected_anchor = null
	
	if selected.size() == 1:
		if selected[0] is PixelRope:
			_current_selected_rope = selected[0]
			# Force a redraw when selected
			_current_selected_rope.queue_redraw()
		elif selected[0] is RopeAnchor:
			_current_selected_anchor = selected[0]
			
			# Find parent rope if any
			var parent = _current_selected_anchor.get_parent()
			if parent is PixelRope:
				_current_selected_rope = parent
				_current_selected_rope.queue_redraw()

# Forward input events to allow custom handling in the editor
func _forward_canvas_gui_input(event: InputEvent) -> bool:
	# Handle rope creation mode first
	if is_rope_creating_mode:
		return _handle_rope_creation_input(event)
	
	# Check if we have an anchor selected, and if so, let it handle the input
	if _current_selected_anchor:
		if _current_selected_anchor.has_method("_input"):
			_current_selected_anchor._input(event)
			return true
	
	# If not handled by an anchor, check if we have a rope selected
	if _current_selected_rope:
		# Forward input to rope (if it can handle it)
		if _current_selected_rope.has_method("_editor_input"):
			return _current_selected_rope._editor_input(event)
	
	return false

# Handle input for rope creation
func _handle_rope_creation_input(event: InputEvent) -> bool:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				# Start position of the rope
				start_position = get_viewport_transform(event)
				
				# Create a temporary rope
				current_rope = RopeScene.instantiate()
				if get_editor_interface().get_edited_scene_root():
					get_editor_interface().get_edited_scene_root().add_child(current_rope)
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
					var end_position = get_viewport_transform(event)
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
					rope_button.modulate = Color(1.0, 1.0, 1.0) # Reset color
					
					return true
	
	if event is InputEventMouseMotion and current_rope:
		# Update the end position during dragging
		var end_position = get_viewport_transform(event)
		var end_anchor = current_rope.get_node("EndAnchor")
		end_anchor.global_position = end_position
		return true
	
	return false

# Helper function to get the correct viewport position
func get_viewport_transform(event: InputEvent) -> Vector2:
	# Get the canvas transform from the viewport
	var canvas = get_editor_interface().get_editor_viewport()
	var canvas_transform = canvas.get_canvas_transform()
	
	# Convert event position to world position
	var world_position = canvas_transform.affine_inverse() * event.position
	
	return world_position

# Optionally add custom editor toolbar 
func _has_main_screen() -> bool:
	return false
