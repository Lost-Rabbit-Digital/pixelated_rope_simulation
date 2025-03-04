## A collection of line-drawing algorithms for pixel-perfect rendering
##
## Provides multiple line-drawing algorithms optimized for pixelated graphics.
## Includes Bresenham's algorithm for integer-based, efficient line drawing and
## DDA (Digital Differential Analyzer) for smooth, floating-point line drawing.
## Choose the appropriate algorithm based on performance needs and visual style.
class_name LineAlgorithms
extends RefCounted

## Different line drawing algorithm types
enum LineAlgorithmType {
	BRESENHAM, ## Integer-based line drawing, computationally efficient
	DDA        ## Floating-point based line drawing, visually smoother
}

## Returns an array of points along a line using the specified algorithm
##
## Uses either Bresenham's or DDA algorithm to compute a series of points
## along a line from 'from_point' to 'to_point', with specified pixel size
## and optional spacing between pixels.
##
## @param from_point The starting point of the line
## @param to_point The ending point of the line
## @param pixel_size The size of each pixel in the grid
## @param algorithm_type The algorithm to use (default: Bresenham)
## @param pixel_spacing How many pixels to skip between drawn pixels (0 = none)
## @return Array of Vector2 points representing pixel positions
static func get_line_points(
	from_point: Vector2, 
	to_point: Vector2, 
	pixel_size: int, 
	algorithm_type: LineAlgorithmType = LineAlgorithmType.BRESENHAM,
	pixel_spacing: int = 0
) -> Array[Vector2]:
	# Snap points to pixel grid
	var grid_from = Vector2(
		round(from_point.x / pixel_size) * pixel_size,
		round(from_point.y / pixel_size) * pixel_size
	)
	
	var grid_to = Vector2(
		round(to_point.x / pixel_size) * pixel_size,
		round(to_point.y / pixel_size) * pixel_size
	)
	
	# Use the specified algorithm
	match algorithm_type:
		LineAlgorithmType.BRESENHAM:
			return _bresenham_line(grid_from, grid_to, pixel_size, pixel_spacing)
		LineAlgorithmType.DDA:
			return _dda_line(grid_from, grid_to, pixel_size, pixel_spacing)
		_:
			# Default to Bresenham if unknown algorithm type
			push_warning("LineAlgorithms: Unknown algorithm type, defaulting to Bresenham")
			return _bresenham_line(grid_from, grid_to, pixel_size, pixel_spacing)

## Implementation of Bresenham's line algorithm
##
## A highly optimized integer-based algorithm that produces pixel-perfect lines
## without using floating-point operations. Particularly efficient for orthogonal
## or diagonal lines.
##
## @param from The starting point (snapped to grid)
## @param to The ending point (snapped to grid)
## @param pixel_size The size of each pixel
## @param spacing Number of pixels to skip between drawn pixels
## @return Array of Vector2 points for drawing
static func _bresenham_line(from: Vector2, to: Vector2, pixel_size: int, spacing: int = 0) -> Array[Vector2]:
	var points: Array[Vector2] = []
	
	var x0 = int(from.x / pixel_size)
	var y0 = int(from.y / pixel_size)
	var x1 = int(to.x / pixel_size)
	var y1 = int(to.y / pixel_size)
	
	var dx = abs(x1 - x0)
	var dy = -abs(y1 - y0)
	var sx = 1 if x0 < x1 else -1
	var sy = 1 if y0 < y1 else -1
	var err = dx + dy
	
	# Apply pixel spacing to make the line less dense
	var pixel_count = 0
	
	while true:
		# Only add points based on spacing
		if spacing == 0 or pixel_count % (spacing + 1) == 0:
			points.append(Vector2(x0 * pixel_size, y0 * pixel_size))
		
		pixel_count += 1
		
		if x0 == x1 and y0 == y1:
			break
			
		var e2 = 2 * err
		if e2 >= dy:
			if x0 == x1:
				break
			err += dy
			x0 += sx
		
		if e2 <= dx:
			if y0 == y1:
				break
			err += dx
			y0 += sy
	
	return points

## Implementation of Digital Differential Analyzer (DDA) line algorithm
##
## A floating-point based algorithm that produces smooth lines by sampling at
## regular intervals. More computationally expensive than Bresenham but can
## provide more visually pleasing results, especially for longer lines.
##
## @param from The starting point (snapped to grid)
## @param to The ending point (snapped to grid)
## @param pixel_size The size of each pixel
## @param spacing Number of pixels to skip between drawn pixels
## @return Array of Vector2 points for drawing
static func _dda_line(from: Vector2, to: Vector2, pixel_size: int, spacing: int = 0) -> Array[Vector2]:
	var points: Array[Vector2] = []
	
	# Convert to grid coordinates
	var x0 = from.x / pixel_size
	var y0 = from.y / pixel_size
	var x1 = to.x / pixel_size
	var y1 = to.y / pixel_size
	
	# Calculate distances and determine stepping direction
	var dx = x1 - x0
	var dy = y1 - y0
	
	# Determine the number of steps to take
	var steps = max(abs(dx), abs(dy))
	
	if steps < 1:
		# Add at least one point if the distance is very small
		points.append(Vector2(round(x0) * pixel_size, round(y0) * pixel_size))
		return points
	
	# Calculate the increment for each direction
	var x_inc = dx / steps
	var y_inc = dy / steps
	
	# Start coordinates
	var x = x0
	var y = y0
	
	# Loop through each step
	for i in range(steps + 1):
		if spacing == 0 or i % (spacing + 1) == 0:
			# Convert back to world coordinates and add to points
			points.append(Vector2(round(x) * pixel_size, round(y) * pixel_size))
		
		# Increment positions
		x += x_inc
		y += y_inc
	
	return points

## Analyzes performance between Bresenham and DDA algorithms
##
## Useful for debugging and performance comparisons.
## Runs both algorithms multiple times and reports execution time.
##
## @param from_point The starting point of the line
## @param to_point The ending point of the line
## @param pixel_size The size of each pixel in the grid
## @param iterations Number of times to run each algorithm
## @return Dictionary with performance results
static func benchmark_algorithms(
	from_point: Vector2, 
	to_point: Vector2, 
	pixel_size: int, 
	iterations: int = 1000
) -> Dictionary:
	var results = {
		"bresenham_time": 0.0,
		"dda_time": 0.0,
		"bresenham_points": 0,
		"dda_points": 0
	}
	
	# Benchmark Bresenham
	var start_time = Time.get_ticks_usec()
	var bresenham_points: Array[Vector2] = []
	
	for i in range(iterations):
		bresenham_points = _bresenham_line(from_point, to_point, pixel_size)
	
	results.bresenham_time = (Time.get_ticks_usec() - start_time) / 1000.0  # ms
	results.bresenham_points = bresenham_points.size()
	
	# Benchmark DDA
	start_time = Time.get_ticks_usec()
	var dda_points: Array[Vector2] = []
	
	for i in range(iterations):
		dda_points = _dda_line(from_point, to_point, pixel_size)
	
	results.dda_time = (Time.get_ticks_usec() - start_time) / 1000.0  # ms
	results.dda_points = dda_points.size()
	
	return results
