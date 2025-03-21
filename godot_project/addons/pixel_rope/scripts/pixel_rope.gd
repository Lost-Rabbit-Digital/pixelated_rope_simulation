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
const line_algorithms = preload("res://addons/pixel_rope/scripts/utilities/line_algorithms.gd")
const rope_creation_tool_script = preload("res://addons/pixel_rope/scripts/editor_tools/rope_creation_button.gd")

# Editor gizmo and selection tracking
var _editor_selection: EditorSelection
var _current_selected_rope: PixelRope = null
var _current_selected_anchor: RopeAnchor = null

# Rope creator tool instance
var rope_creation_tool = null

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
	
	# Initialize the rope creation tool
	rope_creation_tool = rope_creation_tool_script.new()
	rope_creation_tool.initialize(self, _editor_selection)
	
	print("PixelRope - Plugin enabled")

func _exit_tree() -> void:
	# Clean-up
	remove_custom_type("PixelRope")
	remove_custom_type("RopeAnchor")
	
	# Disconnect selection tracking
	if _editor_selection and _editor_selection.selection_changed.is_connected(_on_editor_selection_changed):
		_editor_selection.selection_changed.disconnect(_on_editor_selection_changed)
	
	# Clean up rope creator
	if rope_creation_tool:
		rope_creation_tool.cleanup()
		rope_creation_tool = null
	
	push_warning("PixelRope - Plugin disabled")

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
	# First check if the rope creation tool wants to handle this input
	if rope_creation_tool and rope_creation_tool.handle_input(event):
		return true
	
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

# Optionally add custom editor toolbar 
func _has_main_screen() -> bool:
	return false
