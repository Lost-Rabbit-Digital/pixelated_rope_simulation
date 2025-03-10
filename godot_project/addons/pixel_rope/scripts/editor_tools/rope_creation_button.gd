@tool 
## A tool for creating PixelRope instances in the editor
##
## Adds a button to the canvas editor toolbar that enables a special mode
## for creating rope instances by clicking and dragging in the editor viewport.
## The rope's properties are automatically configured based on the drag distance.
extends EditorPlugin

# Constants
const DISABLED_TOOLTIP: String = "DISABLED: Enable to spawn rope nodes on click"
const DISABLED_COLOR: Color = Color(1.0, 0.5, 0.5) 
const ENABLED_COLOR: Color = Color(0.5, 1.0, 0.5) 
const ENABLED_TOOLTIP: String = "ENABLED: Currently spawning pixel rope nodes"

# UI component
var rope_button: Button

# Creation state tracking
var is_rope_creating_mode: bool = false
var start_position: Vector2
var current_rope: Node

# Reference to the editor selection
var _editor_selection: EditorSelection

# Reference to the plugin instance that created us
var plugin_root: EditorPlugin

# The scene to instance when creating ropes
# TODO: Change this to whatever current scene is open
const RopeScene = preload("res://addons/pixel_rope/examples/basic_ropes/demo_scene_1.tscn")

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
	
	# Create the rope creator button
	rope_button = Button.new()
	rope_button.toggle_mode = false
	rope_button.tooltip_text = DISABLED_TOOLTIP
	rope_button.modulate = DISABLED_COLOR
	rope_button.icon = preload("res://addons/pixel_rope/icons/Curve2D.svg")
	rope_button.pressed.connect(_on_rope_button_pressed)

	# Add toolbar to the editor
	plugin_root.add_control_to_container(EditorPlugin.CONTAINER_CANVAS_EDITOR_MENU, rope_button)

## Cleans up the rope creation tool
##
## Removes UI elements and disconnects signals. Should be called by
## the parent plugin when it is deactivated.
func cleanup() -> void:
	if rope_button:
		plugin_root.remove_control_from_container(EditorPlugin.CONTAINER_CANVAS_EDITOR_MENU, rope_button)
		rope_button.queue_free()
		rope_button = null

## Button press handler
func _on_rope_button_pressed() -> void:
	# Toggle the rope creation mode
	is_rope_creating_mode = !is_rope_creating_mode
	
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


# TODO: Redo input, click to create the pixel rope node, then you can drag and drop the anchors for it.
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
					
					# Reset the button state
					rope_button.text = "Enable Rope Creation"
					rope_button.remove_theme_color_override("font_color")
					rope_button.modulate = Color(1.0, 1.0, 1.0)
					
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
