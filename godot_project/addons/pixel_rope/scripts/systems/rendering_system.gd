# addons/pixel_rope/scripts/systems/rendering_system.gd
@tool
class_name RopeRenderingSystem
extends RefCounted

## Draw a complete rope based on segment positions
static func draw_rope(canvas: CanvasItem, rope_data: RopeData, 
					local_transform_func: Callable, current_state: int,
					rope_color: Color, pixel_size: int, 
					line_algorithm: int, pixel_spacing: int) -> void:
	# If no segments, early return
	if rope_data.segments.is_empty():
		return
		
	# Prepare local points array
	var points: Array[Vector2] = []
	
	# If rope is broken (state 2), just draw a red line between anchors
	if current_state == 2: # BROKEN
		if rope_data.segments.size() >= 2:
			var start_point = local_transform_func.call(rope_data.segments[0].position)
			var end_point = local_transform_func.call(rope_data.segments[rope_data.segment_count].position)
			
			# Draw red line with the same pixel properties as the rope
			_draw_pixelated_line(canvas, start_point, end_point, Color.RED, 
								pixel_size, line_algorithm, pixel_spacing)
		return
	
	# Normal rope drawing
	for segment in rope_data.segments:
		points.append(local_transform_func.call(segment.position))
	
	# Select color based on state
	var color: Color = rope_color
	if current_state == 1: # STRETCHED
		color = Color.DARK_ORANGE
	
	# Draw pixelated rope segments
	for i in range(len(points) - 1):
		_draw_pixelated_line(canvas, points[i], points[i + 1], color, 
						   pixel_size, line_algorithm, pixel_spacing)

## Draw a pixelated line using specified algorithm
static func _draw_pixelated_line(canvas: CanvasItem, from: Vector2, to: Vector2, 
							   color: Color, pixel_size: int, 
							   line_algorithm: int, pixel_spacing: int) -> void:
	# Get points using the selected algorithm
	var points = LineAlgorithms.get_line_points(
		from, to, 
		pixel_size, 
		line_algorithm, 
		pixel_spacing
	)
	
	# Draw pixels
	for point in points:
		_draw_pixel(canvas, point, pixel_size, color)

## Draw a single pixel
static func _draw_pixel(canvas: CanvasItem, pixel_position: Vector2, size: float, color: Color) -> void:
	canvas.draw_rect(
		Rect2(pixel_position - Vector2(size/2, size/2), Vector2(size, size)), 
		color
	)

## Draw a preview rope (used in editor)
static func draw_editor_preview(canvas: CanvasItem, start_pos: Vector2, end_pos: Vector2,
							  rope_color: Color, pixel_size: int, 
							  line_algorithm: int, pixel_spacing: int) -> void:
	_draw_pixelated_line(canvas, start_pos, end_pos, rope_color, 
					   pixel_size, line_algorithm, pixel_spacing)
