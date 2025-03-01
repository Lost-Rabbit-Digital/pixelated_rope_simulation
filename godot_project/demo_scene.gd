extends Control

# Node references - PixelRope is a standalone scene
@onready var rope: PixelRope = $PixelRope

# UI References
@onready var pixel_size_slider = %PixelSizeSlider
@onready var pixel_segment_slider = %PixelSegmentSlider
@onready var outline_checkbox = %OutlineCheckbox
@onready var outline_color_picker = %PixelColorPicker
@onready var pixel_color_picker = %OutlineColorPicker

# Rope properties
@onready var rope_color: Color = rope.rope_color
@onready var segment_length: int = rope.segment_length

# Variables to track dragging
var _dragging_node: Node2D = null
var _start_node: Node2D = null
var _end_node: Node2D = null

func _ready() -> void:
	# Ensure rope is properly configured
	if not rope:
		push_error("Rope node not found")
		return
	
	print("Main scene: Setting up rope")
	
	# Apply initial properties to rope
	outline_color_picker.color = rope.rope_color
	pixel_segment_slider.value = segment_length
	
	# Get references to start and end nodes from the rope
	# These are now part of the PixelRope scene
	_start_node = rope.get_node(rope.start_anchor_name)
	_end_node = rope.get_node(rope.end_anchor_name)
	
	if not _start_node or not _end_node:
		push_error("Could not find anchor nodes in PixelRope scene")
		return
	
	print("Start node: ", _start_node.name, ", End node: ", _end_node.name)
	
	# Connect signal for rope broken
	if rope.has_signal("rope_broken"):
		rope.rope_broken.connect(_on_rope_broken)
	
	# Set up initial positions if needed
	if _start_node.position == Vector2.ZERO and _end_node.position == Vector2.ZERO:
		_start_node.position = Vector2(300, 200)
		_end_node.position = Vector2(600, 200)
	
	# Connect UI controls to their respective functions
	_connect_ui_controls()

func _process(_delta: float) -> void:
	# Check for dragging in _process instead of relying on input events
	var mouse_pos = get_global_mouse_position()
	
	# If left mouse button is pressed
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		# If already dragging a node, update its position
		if _dragging_node:
			_dragging_node.global_position = mouse_pos
		# Otherwise check if we should start dragging
		elif not _dragging_node:
			# Check start node
			if _is_point_near_node(mouse_pos, _start_node, 30.0):
				_dragging_node = _start_node
				print("Started dragging start node")
			# Check end node
			elif _is_point_near_node(mouse_pos, _end_node, 30.0):
				_dragging_node = _end_node
				print("Started dragging end node")
	else:
		# If left mouse is released and we were dragging, stop dragging
		if _dragging_node:
			print("Stopped dragging node")
			_dragging_node = null
			
			# Reset rope if broken
			if rope.get_state() == rope.RopeState.BROKEN:
				rope.reset_rope()
	
	# Update cursor based on hover state
	if not _dragging_node:
		if _is_point_near_node(mouse_pos, _start_node, 30.0) or _is_point_near_node(mouse_pos, _end_node, 30.0):
			Input.set_default_cursor_shape(Input.CURSOR_POINTING_HAND)
		else:
			Input.set_default_cursor_shape(Input.CURSOR_ARROW)

# Helper function to check if a point is near a node
func _is_point_near_node(point: Vector2, node: Node2D, distance: float) -> bool:
	var node_pos = node.global_position
	return point.distance_to(node_pos) < distance

func _on_rope_broken() -> void:
	print("Rope has broken!")
	# Optional: Play sound, particle effect, etc.

# Connect existing UI controls to their respective functions
func _connect_ui_controls() -> void:
	# Connect pixel size slider
	if pixel_size_slider:
		if pixel_size_slider.is_connected("value_changed", _on_pixel_size_slider_value_changed):
			pixel_size_slider.disconnect("value_changed", _on_pixel_size_slider_value_changed)
		pixel_size_slider.value_changed.connect(_on_pixel_size_slider_value_changed)
		# Initialize with current value
		_on_pixel_size_slider_value_changed(pixel_size_slider.value)
	
	# Connect pixel segment slider
	if pixel_segment_slider:
		if pixel_segment_slider.is_connected("value_changed", _on_pixel_segment_slider_value_changed):
			pixel_segment_slider.disconnect("value_changed", _on_pixel_segment_slider_value_changed)
		pixel_segment_slider.value_changed.connect(_on_pixel_segment_slider_value_changed)
		# Initialize with current value
		_on_pixel_segment_slider_value_changed(pixel_segment_slider.value)
	
	# Connect outline checkbox
	if outline_checkbox:
		if outline_checkbox.is_connected("toggled", _on_outline_checkbox_toggled):
			outline_checkbox.disconnect("toggled", _on_outline_checkbox_toggled)
		outline_checkbox.toggled.connect(_on_outline_checkbox_toggled)
		# Initialize with current state
		_on_outline_checkbox_toggled(outline_checkbox.button_pressed)
	
	# Connect outline color picker
	if outline_color_picker:
		if outline_color_picker.is_connected("color_changed", _on_outline_color_picker_color_changed):
			outline_color_picker.disconnect("color_changed", _on_outline_color_picker_color_changed)
		outline_color_picker.color_changed.connect(_on_outline_color_picker_color_changed)
		# Initialize with current color
		_on_outline_color_picker_color_changed(outline_color_picker.color)
	
	# Connect pixel color picker
	if pixel_color_picker:
		if pixel_color_picker.is_connected("color_changed", _on_pixel_color_picker_color_changed):
			pixel_color_picker.disconnect("color_changed", _on_pixel_color_picker_color_changed)
		pixel_color_picker.color_changed.connect(_on_pixel_color_picker_color_changed)
		# Initialize with current color
		_on_pixel_color_picker_color_changed(pixel_color_picker.color)
	
# UI callback functions
func _on_pixel_size_slider_value_changed(value: float) -> void:
	rope.pixel_size = int(value)

func _on_pixel_segment_slider_value_changed(value: float) -> void:
	rope.segment_length = int(value)

func _on_outline_checkbox_toggled(toggled_on: bool) -> void:
	rope.use_outline = toggled_on

func _on_outline_color_picker_color_changed(color: Color) -> void:
	rope.outline_color = color

func _on_pixel_color_picker_color_changed(color: Color) -> void:
	rope.rope_color = color
