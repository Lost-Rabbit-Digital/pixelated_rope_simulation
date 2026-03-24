@tool
## Pixel-perfect line drawing algorithms for rope rendering.
##
## Provides Bresenham's (integer-based, fast) and DDA (floating-point, smooth)
## algorithms for computing pixel positions along a line.
class_name LineAlgorithms
extends RefCounted

enum LineAlgorithmType {
	BRESENHAM, ## Integer-based, computationally efficient
	DDA        ## Floating-point based, visually smoother
}


static func get_line_points(
	from_point: Vector2,
	to_point: Vector2,
	pixel_size: int,
	algorithm_type: LineAlgorithmType = LineAlgorithmType.BRESENHAM,
	pixel_spacing: int = 0
) -> Array[Vector2]:
	var grid_from := Vector2(
		round(from_point.x / pixel_size) * pixel_size,
		round(from_point.y / pixel_size) * pixel_size
	)
	var grid_to := Vector2(
		round(to_point.x / pixel_size) * pixel_size,
		round(to_point.y / pixel_size) * pixel_size
	)

	if algorithm_type == LineAlgorithmType.DDA:
		return _dda_line(grid_from, grid_to, pixel_size, pixel_spacing)
	return _bresenham_line(grid_from, grid_to, pixel_size, pixel_spacing)


static func _bresenham_line(from: Vector2, to: Vector2, pixel_size: int, spacing: int = 0) -> Array[Vector2]:
	var points: Array[Vector2] = []

	var x0 := int(from.x / pixel_size)
	var y0 := int(from.y / pixel_size)
	var x1 := int(to.x / pixel_size)
	var y1 := int(to.y / pixel_size)

	var dx := abs(x1 - x0)
	var dy := -abs(y1 - y0)
	var sx := 1 if x0 < x1 else -1
	var sy := 1 if y0 < y1 else -1
	var err := dx + dy
	var pixel_count := 0

	while true:
		if spacing == 0 or pixel_count % (spacing + 1) == 0:
			points.append(Vector2(x0 * pixel_size, y0 * pixel_size))

		pixel_count += 1

		if x0 == x1 and y0 == y1:
			break

		var e2 := 2 * err
		if e2 >= dy:
			if x0 == x1: break
			err += dy
			x0 += sx

		if e2 <= dx:
			if y0 == y1: break
			err += dx
			y0 += sy

	return points


static func _dda_line(from: Vector2, to: Vector2, pixel_size: int, spacing: int = 0) -> Array[Vector2]:
	var points: Array[Vector2] = []

	var x0 := from.x / pixel_size
	var y0 := from.y / pixel_size
	var x1 := to.x / pixel_size
	var y1 := to.y / pixel_size

	var dx := x1 - x0
	var dy := y1 - y0
	var steps := max(abs(dx), abs(dy))

	if steps < 1:
		points.append(Vector2(round(x0) * pixel_size, round(y0) * pixel_size))
		return points

	var x_inc := dx / steps
	var y_inc := dy / steps
	var x := x0
	var y := y0

	for i in range(int(steps) + 1):
		if spacing == 0 or i % (spacing + 1) == 0:
			points.append(Vector2(round(x) * pixel_size, round(y) * pixel_size))
		x += x_inc
		y += y_inc

	return points
