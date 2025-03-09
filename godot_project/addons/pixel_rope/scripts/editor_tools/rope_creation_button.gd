@tool 
extends EditorPlugin

## A tool for creating PixelRope instances in the editor
##
## Adds a button to the canvas editor toolbar that enables a special mode
## for creating rope instances by clicking and dragging in the editor viewport.
## The rope's properties are automatically configured based on the drag distance.

# UI components
var toolbar: HBoxContainer
var rope_button: Button
var separator: VSeparator

# Creation state tracking
var is_rope_creating_mode: bool = false
var start_position: Vector2
var current_rope: Node

# Reference to the editor selection
var _editor_selection: EditorSelection

# Reference to the plugin instance that created us
var plugin_root: EditorPlugin

# The scene to instance when creating ropes
const RopeScene = preload("res://addons/pixel_rope/example/demo_scene.tscn")

## Initializes the rope creation tool
##
## Creates the toolbar button and adds it to the editor interface.
## Should be called by the parent plugin when it is activated.
##
## @param parent_plugin Reference to the parent plugin for callbacks
## @param editor_selection The editor's selection object for tracking selected nodes
func initialize(parent_plugin: EditorPlugin, editor_selection: EditorSelection) -> void:
	# Store references
	plugin_root = parent_plugin
	_editor_selection = editor_selection
	
	# Create toolbar container
	toolbar = HBoxContainer.new()
	
	# Create a separator for visual clarity
	separator = VSeparator.new()
	toolbar.add_child(separator)
	
	# Create the rope creator button
	rope_button = Button.new()
	rope_button.text = "Enable Rope Creation"
	rope_button.tooltip_text = "Enable spawning of rope nodes on click"
	rope_button.flat = true
	rope_button.icon = preload("res://addons/pixel_rope/icons/Curve2D.svg")
	rope_button.pressed.connect(_on_rope_button_pressed)
	toolbar.add_child(rope_button)
	
	# Add toolbar to the editor
	plugin_root.add_control_to_container(EditorPlugin.CONTAINER_CANVAS_EDITOR_MENU, toolbar)
	
	print("PixelRope - Initialized rope creation tool")

## Cleans up the rope creation tool
##
## Removes UI elements and disconnects signals. Should be called by
## the parent plugin when it is deactivated.
func cleanup() -> void:
	if toolbar:
		plugin_root.remove_control_from_container(EditorPlugin.CONTAINER_CANVAS_EDITOR_MENU, toolbar)
		toolbar.queue_free()
		toolbar = null
		
	print("PixelRope - Removed rope creation tool")

## Button press handler
func _on_rope_button_pressed() -> void:
	# Toggle the rope creation mode
	is_rope_creating_mode = !is_rope_creating_mode
	
	if is_rope_creating_mode:
		rope_button.text = "Disable Rope Creation"
		rope_button.tooltip_text = "Disable spawning of rope nodes on click"
		rope_button.modulate = Color(1.0, 0.5, 0.5) # Visual feedback for active state
	else:
		rope_button.text = "Enable Rope Creation"
		rope_button.tooltip_text = "Enable spawning of rope nodes on click"
		rope_button.modulate = Color(1.0, 1.0, 1.0) # Reset color
		if current_rope:
			current_rope.queue_free()
			current_rope = null

## Handles input events for rope creation
##
## Manages the mouse interaction for creating rope nodes by clicking and dragging.
## This should be called from the parent plugin's _forward_canvas_gui_input.
##
## @param event The input event to process
## @return Whether the event was handled
func handle_input(event: InputEvent) -> bool:
	# Skip if not in rope creation mode
	if not is_rope_creating_mode:
		return false
		
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				# Start position of the rope
				start_position = get_viewport_transform(event)
				
				# Create a temporary rope
				current_rope = RopeScene.instantiate()
				if plugin_root.get_editor_interface().get_edited_scene_root():
					plugin_root.get_editor_interface().get_edited_scene_root().add_child(current_rope)
					current_rope.owner = plugin_root.get_editor_interface().get_edited_scene_root()
					
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
					rope_button.text = "Enable Rope Creation"
					rope_button.modulate = Color(1.0, 1.0, 1.0) # Reset color
					
					return true
	
	if event is InputEventMouseMotion and current_rope:
		# Update the end position during dragging
		var end_position = get_viewport_transform(event)
		var end_anchor = current_rope.get_node("EndAnchor")
		end_anchor.global_position = end_position
		return true
	
	return false

## Helper function to get the correct viewport position
func get_viewport_transform(event: InputEvent) -> Vector2:
	# Get the canvas transform from the viewport
	var canvas = plugin_root.get_editor_interface().get_editor_viewport()
	var canvas_transform = canvas.get_canvas_transform()
	
	# Convert event position to world position
	var world_position = canvas_transform.affine_inverse() * event.position
	
	return world_position
