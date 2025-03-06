@tool
class_name LineRenderer
extends RefCounted

# Draw the rope using the selected line algorithm
func draw_rope(
	canvas: CanvasItem,
	segments: Array[RopeSegment],
	pixel_size: int,
	rope_color: Color,
	algorithm_type: LineAlgorithms.LineAlgorithmType,
	pixel_spacing: int = 0,
	state: int = 0,  # RopeState enum
	broken: bool = false
) -> void:
	if segments.is_empty():
		return
	
	# If rope is broken, just draw a red line between anchors
	if broken:
		var start_point = canvas.to_local(segments[0].position)
		var end_point = canvas.to_local(segments[segments.size() - 1].position)
		_draw_pixelated_line(canvas, start_point, end_point, Color.RED, pixel_size, algorithm_type, pixel_spacing)
		return
	
	# Select color based on state
	var color = rope_color
	if state == 1:  # STRETCHED state
		color = Color.DARK_ORANGE
	
	# Draw pixelated rope segments
	for i in range(segments.size() - 1):
		var start = canvas.to_local(segments[i].position)
		var end = canvas.to_local(segments[i + 1].position)
		_draw_pixelated_line(canvas, start, end, color, pixel_size, algorithm_type, pixel_spacing)

# Draw a preview line between two points in the editor
func draw_preview_line(
	canvas: CanvasItem,
	start_pos: Vector2,
	end_pos: Vector2,
	color: Color,
	pixel_size: int,
	algorithm_type: LineAlgorithms.LineAlgorithmType,
	pixel_spacing: int = 0
) -> void:
	var start = canvas.to_local(start_pos)
	var end = canvas.to_local(end_pos)
	_draw_pixelated_line(canvas, start, end, color, pixel_size, algorithm_type, pixel_spacing)

# Draw a line using the selected algorithm
func _draw_pixelated_line(
	canvas: CanvasItem,
	from: Vector2,
	to: Vector2, 
	color: Color,
	pixel_size: int,
	algorithm_type: LineAlgorithms.LineAlgorithmType,
	pixel_spacing: int
) -> void:
	# Get points using the selected algorithm
	var points = LineAlgorithms.get_line_points(
		from, to, 
		pixel_size, 
		algorithm_type, 
		pixel_spacing
	)
	
	# Draw pixels
	for point in points:
		_draw_pixel(canvas, point, pixel_size, color)

# Draw a pixel
func _draw_pixel(canvas: CanvasItem, pixel_position: Vector2, size: float, color: Color) -> void:
	canvas.draw_rect(
		Rect2(pixel_position - Vector2(size/2, size/2), Vector2(size, size)), 
		color
	)
