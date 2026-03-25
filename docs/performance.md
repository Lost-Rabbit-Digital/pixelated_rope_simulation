# Performance Optimization

This guide provides strategies for optimizing PixelRope performance, helping you create efficient rope simulations even in complex scenes.

## Table of Contents

- [Key Performance Factors](#key-performance-factors)
- [Profiling PixelRope Performance](#profiling-pixelrope-performance)
- [Segment Count Optimization](#segment-count-optimization)
- [Physics Optimization](#physics-optimization)
- [Rendering Optimization](#rendering-optimization)
- [Collision Optimization](#collision-optimization)
- [Visibility Optimization](#visibility-optimization)
- [Multiple Rope Strategies](#multiple-rope-strategies)
- [Mobile Device Optimization](#mobile-device-optimization)

## Key Performance Factors

PixelRope's performance is primarily affected by these factors (in order of impact):

1. **Segment Count**: The number of segments has the largest impact on performance
2. **Physics Iteration Count**: More iterations means more calculations
3. **Collision Detection**: Checking for collisions is computationally expensive
4. **Rendering Algorithm**: Different line algorithms have different performance costs
5. **Number of Ropes**: Total number of active ropes in the scene

## Profiling PixelRope Performance

Before optimizing, measure the current performance to identify bottlenecks:

```gdscript
# Profiling helper for PixelRope
extends Node

@export var target_rope: PixelRope

var _physics_time: float = 0
var _render_time: float = 0
var _measurements: int = 0
var _start_time: int = 0

func _ready():
    if target_rope:
        # Create timer for periodic reporting
        var timer = Timer.new()
        timer.wait_time = 2.0
        timer.timeout.connect(_report_performance)
        add_child(timer)
        timer.start()

func _physics_process(_delta):
    if target_rope:
        _start_time = Time.get_ticks_usec()
        
        # Call our custom method to track how long physics takes
        # NOTE: This requires modifying PixelRope.gd to expose _update_physics
        target_rope._update_physics(_delta)
        
        _physics_time += (Time.get_ticks_usec() - _start_time) / 1000.0
        _measurements += 1

func _process(_delta):
    if target_rope:
        # Measure rendering time on next frame
        _start_time = Time.get_ticks_usec()
        target_rope.queue_redraw()  # Force redraw
        # We'll measure in _notification hook of target

func _report_performance():
    if _measurements > 0:
        # Calculate averages
        var avg_physics = _physics_time / _measurements
        var avg_render = _render_time / _measurements
        
        print("=== PixelRope Performance ===")
        print("Segment count: ", target_rope.segment_count)
        print("Physics iterations: ", target_rope.iterations)
        print("Average physics time: %.2f ms" % avg_physics)
        print("Average render time: %.2f ms" % avg_render)
        print("Total time per frame: %.2f ms" % (avg_physics + avg_render))
        
        # Reset for next measurement period
        _physics_time = 0
        _render_time = 0
        _measurements = 0
```

Use this profiler to identify which operations are consuming the most time, then optimize accordingly.

## Segment Count Optimization

The segment count has the most significant impact on performance. Each additional segment increases physics calculations and rendering time.

### Recommendations:

```gdscript
# Automatically determine optimum segment count based on length
func optimize_rope_segments(rope: PixelRope):
    var distance = rope.start_position.distance_to(rope.end_position)
    
    # Different segment densities based on importance:
    if is_gameplay_critical_rope(rope):
        # For gameplay-critical ropes: higher detail
        rope.segment_count = int(distance / 10.0)
    else:
        # For background/decorative ropes: lower detail
        rope.segment_count = int(distance / 25.0)
    
    # Ensure minimum and maximum values
    rope.segment_count = clamp(rope.segment_count, 5, 100)
    
    # Adjust segment length to maintain intended rope length
    rope.segment_length = distance / rope.segment_count
```

### Adaptive Segment Count:

For very long ropes, consider using adaptive segmentation based on distance to camera:

```gdscript
func update_adaptive_segment_count(rope: PixelRope, camera: Camera2D):
    # Calculate distance to camera
    var rope_center = (rope.start_position + rope.end_position) / 2
    var distance_to_camera = rope_center.distance_to(camera.global_position)
    
    # Scale segment count inversely with distance
    var base_segment_count = 60
    var distance_factor = clamp(1.0 - (distance_to_camera / 1000.0), 0.1, 1.0)
    var new_segment_count = int(base_segment_count * distance_factor)
    
    # Only update if the change is significant (to avoid constant resizing)
    if abs(new_segment_count - rope.segment_count) > 5:
        var rope_length = rope.segment_count * rope.segment_length
        rope.segment_count = max(5, new_segment_count)
        rope.segment_length = rope_length / rope.segment_count
```

## Physics Optimization

### Physics Iteration Count

The `iterations` property controls how many times constraints are applied per physics frame. Higher values create more stable ropes but consume more CPU.

```gdscript
# Recommended iteration counts for different use cases:
func configure_iterations(rope: PixelRope, rope_type: String):
    match rope_type:
        "decorative":
            # Background elements that don't affect gameplay
            rope.iterations = 5
        "interactive":
            # Ropes the player can interact with
            rope.iterations = 10
        "critical":
            # Ropes essential for gameplay (bridges, grappling hooks)
            rope.iterations = 15-20
```

### Physics Process Mode

For non-essential ropes, you can reduce the physics update frequency:

```gdscript
# For background ropes, update physics less frequently
func optimize_background_rope(rope: PixelRope):
    rope.physics_process_mode = Node.PROCESS_MODE_PAUSABLE
    
    # Custom timer for less frequent updates
    var timer = Timer.new()
    timer.wait_time = 0.05  # Update at 20Hz instead of 60Hz
    timer.timeout.connect(func(): rope._update_physics(0.05))
    rope.add_child(timer)
    timer.start()
```

## Rendering Optimization

### Line Algorithm Selection

```gdscript
# Choose the most appropriate line algorithm
func optimize_line_algorithm(rope: PixelRope, is_critical: bool):
    if is_critical:
        # Use DDA for smoother, more precise visuals
        rope.line_algorithm = LineAlgorithms.LineAlgorithmType.DDA
    else:
        # Use Bresenham for better performance
        rope.line_algorithm = LineAlgorithms.LineAlgorithmType.BRESENHAM
```

### Pixel Size and Spacing

```gdscript
# Optimize rendering by adjusting pixel properties
func optimize_rope_visuals(rope: PixelRope, distance_to_camera: float):
    # Increase pixel size for distant ropes (less detail needed)
    var base_pixel_size = 3
    var distance_factor = clamp(distance_to_camera / 500.0, 1.0, 3.0)
    rope.pixel_size = int(base_pixel_size * distance_factor)
    
    # Add spacing for distant ropes to reduce pixel count
    if distance_to_camera > 800:
        rope.pixel_spacing = 1  # Skip every other pixel
```

## Collision Optimization

Collision detection is one of the most expensive operations. Disable it when not needed and optimize when required.

```gdscript
# Optimize collision settings
func optimize_rope_collisions(rope: PixelRope, purpose: String):
    match purpose:
        "decorative":
            # Background ropes don't need collisions
            rope.enable_collisions = false
        "interactive":
            # Only enable collision with relevant layers
            rope.enable_collisions = true
            rope.collision_mask = 1  # Only collide with main world
        "gameplay":
            # Full collision for gameplay-critical ropes
            rope.enable_collisions = true
            rope.collision_mask = 3  # Collide with world and characters
```

### Collision Radius Optimization

```gdscript
# Scale collision radius with distance to camera
func optimize_collision_radius(rope: PixelRope, distance_to_camera: float):
    var base_radius = 5.0
    var distance_factor = clamp(1.0 - (distance_to_camera / 1000.0), 0.5, 1.0)
    rope.collision_radius = base_radius * distance_factor
```

## Visibility Optimization

### Culling Ropes Outside the View

```gdscript
# Only process ropes that are visible
func manage_rope_visibility(ropes: Array[PixelRope], camera: Camera2D):
    var viewport_rect = get_viewport_rect()
    var camera_center = camera.global_position
    var camera_rect = Rect2(
        camera_center - viewport_rect.size / 2,
        viewport_rect.size
    )
    
    # Add margin to prevent pop-in
    camera_rect = camera_rect.grow(200)
    
    for rope in ropes:
        # Check if any part of the rope is visible
        var rope_rect = Rect2(rope.start_position, Vector2.ZERO)
        rope_rect = rope_rect.expand(rope.end_position)
        
        if camera_rect.intersects(rope_rect):
            # Rope is visible - process normally
            rope.process_mode = Node.PROCESS_MODE_INHERIT
        else:
            # Rope is not visible - disable processing
            rope.process_mode = Node.PROCESS_MODE_DISABLED
```

### Level of Detail (LOD) System

```gdscript
# Apply different detail levels based on distance
func apply_rope_lod(rope: PixelRope, distance: float):
    # Define LOD thresholds
    var close_threshold = 300.0
    var medium_threshold = 600.0
    
    if distance < close_threshold:
        # High detail for close ropes
        rope.segment_count = 40
        rope.iterations = 15
        rope.enable_collisions = true
        rope.line_algorithm = LineAlgorithms.LineAlgorithmType.DDA
        
    elif distance < medium_threshold:
        # Medium detail
        rope.segment_count = 20
        rope.iterations = 10
        rope.enable_collisions = true
        rope.line_algorithm = LineAlgorithms.LineAlgorithmType.BRESENHAM
        
    else:
        # Low detail for distant ropes
        rope.segment_count = 10
        rope.iterations = 5
        rope.enable_collisions = false
        rope.line_algorithm = LineAlgorithms.LineAlgorithmType.BRESENHAM
        rope.pixel_spacing = 1
```

## Multiple Rope Strategies

### Pooling for Temporary Ropes

For games that create and destroy ropes frequently, implement a rope pool:

```gdscript
extends Node

# Rope pool for efficient reuse
var _rope_pool: Array[PixelRope] = []
@export var pool_size: int = 10
@export var default_segment_count: int = 30

func _ready():
    # Initialize pool
    for i in range(pool_size):
        var rope = PixelRope.new()
        rope.segment_count = default_segment_count
        rope.process_mode = Node.PROCESS_MODE_DISABLED
        rope.visible = false
        add_child(rope)
        _rope_pool.append(rope)

func get_rope() -> PixelRope:
    # Try to find an available rope in the pool
    for rope in _rope_pool:
        if rope.process_mode == Node.PROCESS_MODE_DISABLED:
            # Configure rope for reuse
            rope.process_mode = Node.PROCESS_MODE_INHERIT
            rope.visible = true
            rope._broken = false
            rope._state = PixelRope.RopeState.NORMAL
            return rope
    
    # If no rope is available, create a new one
    var new_rope = PixelRope.new()
    new_rope.segment_count = default_segment_count
    add_child(new_rope)
    _rope_pool.append(new_rope)
    return new_rope

func release_rope(rope: PixelRope):
    # Return rope to pool
    rope.process_mode = Node.PROCESS_MODE_DISABLED
    rope.visible = false
```

### Threading for Complex Rope Simulations

For games with many ropes, consider using multithreading for physics calculations:

```gdscript
# Note: This is an advanced technique that requires thread safety
# considerations and should be implemented carefully
extends Node

var thread: Thread
var physics_mutex: Mutex
var rope_data: Array = []
var is_processing: bool = false

func _ready():
    thread = Thread.new()
    physics_mutex = Mutex.new()

func _physics_process(delta):
    if not is_processing and rope_data.size() > 0:
        is_processing = true
        physics_mutex.lock()
        var data_copy = rope_data.duplicate(true)
        physics_mutex.unlock()
        
        thread.start(Callable(self, "_thread_physics"), [data_copy, delta])

func _thread_physics(userdata):
    var data = userdata[0]
    var delta = userdata[1]
    
    # Process physics for all ropes
    for rope_entry in data:
        _process_rope_physics(rope_entry, delta)
    
    # Signal completion
    call_deferred("_thread_completed")

func _thread_completed():
    thread.wait_to_finish()
    is_processing = false

# Example of how to process rope physics in a thread-safe way
func _process_rope_physics(rope_data, delta):
    # This would contain a thread-safe implementation of rope physics
    # You'd need to update position data without direct node access
    pass
```

## Mobile Device Optimization

For mobile platforms, additional optimizations may be necessary:

```gdscript
# Apply mobile-specific optimizations
func optimize_for_mobile(rope: PixelRope):
    # Reduce segment count
    rope.segment_count = max(10, rope.segment_count / 2)
    
    # Use fewer iterations
    rope.iterations = max(5, rope.iterations / 2)
    
    # Use faster line algorithm
    rope.line_algorithm = LineAlgorithms.LineAlgorithmType.BRESENHAM
    
    # Increase pixel size for better visibility on small screens
    rope.pixel_size = max(4, rope.pixel_size)
    
    # Simplify physics
    rope.gravity = Vector2(0, 490)  # Half gravity
    
    # Optimize collisions
    if not is_gameplay_critical(rope):
        rope.enable_collisions = false
```

## Benchmarking Guide

Use this code to compare different configurations:

```gdscript
# Benchmark different rope configurations
func benchmark_rope_configs():
    var results = []
    var test_duration = 5.0  # seconds
    var ropes = []
    
    # Create test configurations
    var configs = [
        {"segments": 10, "iterations": 5, "algorithm": LineAlgorithms.LineAlgorithmType.BRESENHAM},
        {"segments": 20, "iterations": 10, "algorithm": LineAlgorithms.LineAlgorithmType.BRESENHAM},
        {"segments": 20, "iterations": 10, "algorithm": LineAlgorithms.LineAlgorithmType.DDA},
        {"segments": 40, "iterations": 15, "algorithm": LineAlgorithms.LineAlgorithmType.BRESENHAM},
        {"segments": 40, "iterations": 15, "algorithm": LineAlgorithms.LineAlgorithmType.DDA}
    ]
    
    # Create test ropes
    for config in configs:
        var rope = PixelRope.new()
        rope.segment_count = config.segments
        rope.iterations = config.iterations
        rope.line_algorithm = config.algorithm
        rope.start_position = Vector2(100, 100)
        rope.end_position = Vector2(500, 400)
        add_child(rope)
        ropes.append(rope)
    
    # Run benchmarks
    for i in range(configs.size()):
        var config = configs[i]
        var rope = ropes[i]
        
        print("Testing config: ", config)
        var start_time = Time.get_ticks_msec()
        var frames = 0
        
        while Time.get_ticks_msec() - start_time < test_duration * 1000:
            # Simulate one frame of processing
            rope._update_physics(1.0/60.0)
            rope.queue_redraw()
            frames += 1
            await get_tree().process_frame
        
        var elapsed = (Time.get_ticks_msec() - start_time) / 1000.0
        var fps = frames / elapsed
        
        results.append({
            "config": config,
            "fps": fps,
            "frame_time": 1000.0 / fps
        })
        
        print("Result: %.2f fps (%.2f ms/frame)" % [fps, 1000.0 / fps])
    
    # Clean up test ropes
    for rope in ropes:
        rope.queue_free()
    
    return results
```

## Key Takeaways

1. **Segment Count**: The single most important factor. Use the minimum necessary.
2. **Iteration Count**: Balance between 5-15 based on importance/stability needs.
3. **Collisions**: Disable for non-gameplay ropes.
4. **LOD System**: Implement distance-based detail reduction.
5. **Culling**: Disable processing for off-screen ropes.
6. **Line Algorithm**: Use Bresenham when performance matters most.
7. **Mobile Optimization**: Apply targeted reductions for mobile platforms.

By applying these optimization strategies, you can maintain high performance even in scenes with multiple rope instances.