# Troubleshooting Guide

This guide helps resolve common issues encountered when working with PixelRope.

## Table of Contents

- [Physics Issues](#physics-issues)
- [Rendering Issues](#rendering-issues)
- [Collision Problems](#collision-problems)
- [Interaction Issues](#interaction-issues)
- [Performance Problems](#performance-problems)
- [Editor Related Issues](#editor-related-issues)
- [Integration Challenges](#integration-challenges)
- [Debugging Tools](#debugging-tools)

## Physics Issues

### Rope Appears Overly Stretched or Breaks Immediately

**Symptoms:**
- Rope breaks as soon as the scene starts
- Rope appears tightly stretched before breaking
- Rope is tagged as "STRETCHED" immediately

**Causes:**
- Start and end positions are too far apart
- Segment count is too low for the rope length
- `segment_length` is too small for the total distance

**Solutions:**

```gdscript
# Automatically fix segment count and length
func fix_rope_stretching(rope: PixelRope) -> void:
    # Calculate the distance between anchors
    var distance = rope.start_position.distance_to(rope.end_position)
    
    # Adjust segment count based on distance
    rope.segment_count = int(distance / 10.0)  # 1 segment per 10 pixels is a good balance
    
    # Ensure a minimum number of segments
    rope.segment_count = max(rope.segment_count, 10)
    
    # Update segment length to match
    rope.segment_length = distance / rope.segment_count
    
    # Reset rope to apply changes
    rope.reset_rope()
    
    print("Rope adjusted: ", rope.segment_count, " segments of length ", rope.segment_length)
```

### Rope Jitters or Oscillates Uncontrollably

**Symptoms:**
- Rope constantly shakes even when undisturbed
- Small movements amplify into large oscillations
- Segments pass through each other

**Causes:**
- Not enough physics iterations
- Damping value too high (not enough dampening)
- Segment count too high relative to length
- Very small segment length

**Solutions:**

```gdscript
# Stabilize a jittery rope
func stabilize_rope(rope: PixelRope) -> void:
    # Increase iterations for more stability
    rope.iterations = 20
    
    # Lower damping to reduce oscillation (more damping)
    rope.damping = 0.9
    
    # Ensure segment length isn't too small
    var distance = rope.start_position.distance_to(rope.end_position)
    var min_segment_length = 5.0
    
    if rope.segment_length < min_segment_length:
        rope.segment_count = int(distance / min_segment_length)
        rope.segment_length = distance / rope.segment_count
    
    # Reset the rope to apply changes
    rope.reset_rope()
    
    print("Rope stabilized with ", rope.iterations, " iterations and damping of ", rope.damping)
```

### Dynamic Anchors Not Responding to Physics

**Symptoms:**
- Anchors don't move even with `dynamic_start_anchor` or `dynamic_end_anchor` set to true
- Anchors ignore gravity or forces

**Causes:**
- Missing initialization
- Segment lock state not updated
- Anchor mass is too high

**Solutions:**

```gdscript
# Fix dynamic anchor issues
func fix_dynamic_anchors(rope: PixelRope) -> void:
    # Ensure dynamic flags are properly set
    if rope.dynamic_start_anchor:
        print("Start anchor should be dynamic")
        
        # Force update of internal segments
        if rope._segments.size() > 0:
            rope._segments[0].is_locked = false
    
    if rope.dynamic_end_anchor:
        print("End anchor should be dynamic")
        
        # Force update of internal segments
        if rope._segments.size() > rope.segment_count:
            rope._segments[rope.segment_count].is_locked = false
    
    # Check anchor mass (lower = more responsive to forces)
    if rope.anchor_mass > 2.0:
        print("Warning: High anchor mass (", rope.anchor_mass, ") may make anchors unresponsive")
        print("Consider reducing to 0.5-2.0 range")
    
    # Force a re-initialization if all else fails
    rope.reset_rope()
```

### Rope Doesn't Hang Naturally

**Symptoms:**
- Rope appears too straight
- Doesn't form a proper catenary curve
- Lacks realistic sagging

**Causes:**
- Insufficient gravity
- Too few segments
- Too many iterations
- Damping too low

**Solutions:**

```gdscript
# Improve natural hanging appearance
func improve_rope_hanging(rope: PixelRope) -> void:
    # Ensure sufficient gravity
    if rope.gravity.length() < 500:
        rope.gravity = Vector2(0, 980)  # Standard gravity
    
    # Ensure enough segments for a smooth curve
    var distance = rope.start_position.distance_to(rope.end_position)
    var target_segments = int(distance / 15.0)  # 1 segment per 15px
    
    if rope.segment_count < target_segments:
        rope.segment_count = target_segments
        rope.segment_length = distance / rope.segment_count
    
    # Adjust physics parameters
    rope.iterations = 10  # Lower iterations allow more natural movement
    rope.damping = 0.96  # Slight damping for controlled movement
    
    # Reset rope to apply changes
    rope.reset_rope()
```

## Rendering Issues

### Rope Appears Pixelated in the Wrong Way

**Symptoms:**
- Pixels don't align with the game's pixel grid
- Visual artifacts when moving/rotating
- Rope doesn't match the game's art style

**Causes:**
- Incorrect pixel size
- Wrong line algorithm
- Pixel spacing issues

**Solutions:**

```gdscript
# Fix visual appearance issues
func fix_rope_appearance(rope: PixelRope, game_pixel_size: int) -> void:
    # Match the game's pixel size
    rope.pixel_size = game_pixel_size
    
    # Choose appropriate algorithm based on angle
    var rope_angle = (rope.end_position - rope.start_position).angle()
    var is_diagonal = not (is_approximately(sin(rope_angle), 0) or is_approximately(cos(rope_angle), 0))
    
    if is_diagonal:
        # Use DDA for diagonal lines
        rope.line_algorithm = LineAlgorithms.LineAlgorithmType.DDA
    else:
        # Use Bresenham for horizontal/vertical lines
        rope.line_algorithm = LineAlgorithms.LineAlgorithmType.BRESENHAM
    
    # Reset pixel spacing unless intentionally using dotted effect
    if rope.pixel_spacing > 0 and not using_dotted_style:
        rope.pixel_spacing = 0
    
    print("Adjusted rope appearance to match game pixel size: ", game_pixel_size)

# Helper for angle comparison with tolerance
func is_approximately(value: float, target: float, tolerance: float = 0.1) -> bool:
    return abs(value - target) < tolerance
```

### Rope Not Visible or Disappears

**Symptoms:**
- Rope doesn't appear in the scene
- Rope appears briefly then vanishes
- Visible in editor but not when running

**Causes:**
- Broken initialization
- Alpha value of color is zero
- Positioned outside camera view
- Process mode disabled

**Solutions:**

```gdscript
# Debug visibility issues
func debug_rope_visibility(rope: PixelRope, camera: Camera2D) -> void:
    print("=== Rope Visibility Debug ===")
    
    # Check if rope is initialized
    print("Rope initialized: ", rope._initialized)
    
    # Check color alpha
    print("Rope color: ", rope.rope_color, " (Alpha: ", rope.rope_color.a, ")")
    if rope.rope_color.a < 0.1:
        print("WARNING: Alpha value near zero - rope is transparent")
        rope.rope_color.a = 1.0
    
    # Check if rope is in camera view
    var view_rect = get_viewport_rect().size
    var camera_pos = camera.global_position
    var top_left = camera_pos - view_rect / 2
    var bottom_right = camera_pos + view_rect / 2
    var camera_rect = Rect2(top_left, view_rect)
    
    var rope_rect = Rect2(rope.start_position, Vector2.ZERO)
    rope_rect = rope_rect.expand(rope.end_position)
    
    print("Rope in camera view: ", camera_rect.intersects(rope_rect))
    if not camera_rect.intersects(rope_rect):
        print("WARNING: Rope is outside camera view!")
        print("Camera rect: ", camera_rect)
        print("Rope positions - Start: ", rope.start_position, " End: ", rope.end_position)
    
    # Check process mode
    print("Process mode: ", rope.process_mode)
    if rope.process_mode == Node.PROCESS_MODE_DISABLED:
        print("WARNING: Process mode is disabled!")
        rope.process_mode = Node.PROCESS_MODE_INHERIT
    
    # Force redraw
    rope.visible = true
    rope.queue_redraw()
```

## Collision Problems

### Rope Passes Through Objects

**Symptoms:**
- Rope ignores collision with environment
- Passes through walls or platforms
- Collisions work inconsistently

**Causes:**
- Collisions not enabled
- Incorrect collision mask
- Physics state not initialized
- Collision radius too small

**Solutions:**

```gdscript
# Fix collision detection issues
func fix_collision_detection(rope: PixelRope) -> void:
    print("=== Collision Detection Debug ===")
    
    # Check if collisions are enabled
    print("Collisions enabled: ", rope.enable_collisions)
    if not rope.enable_collisions:
        print("Enabling collisions...")
        rope.enable_collisions = true
    
    # Check collision mask
    print("Current collision mask: ", rope.collision_mask, " (binary: ", "%d" % rope.collision_mask, ")")
    
    # Get world collision layers
    var physics_layers = []
    for i in range(32):
        if ProjectSettings.get_setting("layer_names/2d_physics/layer_" + str(i+1)) != "":
            physics_layers.append(i+1)
    
    print("Available physics layers: ", physics_layers)
    
    # Suggestion for appropriate collision mask
    print("Suggested collision mask: ", 1)  # Default to layer 1
    
    # Check physics direct state
    print("Physics state initialized: ", rope._physics_direct_state != null)
    if rope._physics_direct_state == null:
        print("Force initialization of physics state...")
        rope._initialize_physics_state()
    
    # Check collision radius
    print("Collision radius: ", rope.collision_radius)
    if rope.collision_radius < 2.0:
        print("Collision radius may be too small, increasing...")
        rope.collision_radius = 5.0
    
    # Enable debug visualization
    print("Enabling collision debug visualization...")
    rope.show_collision_debug = true
```

### Collision Response Issues

**Symptoms:**
- Rope bounces too much or not enough
- Gets stuck in colliders
- Jitters when colliding

**Causes:**
- Inappropriate collision response values
- Collision shapes interpenetrating
- Physics processing conflicts

**Solutions:**

```gdscript
# Tune collision response parameters
func tune_collision_response(rope: PixelRope) -> void:
    # Balance collision response for stability
    rope.collision_bounce = 0.2  # Moderate bounce
    rope.collision_friction = 0.8  # Higher friction to prevent sliding
    
    # Slightly larger collision radius to prevent interpenetration
    rope.collision_radius = max(5.0, rope.collision_radius)
    
    # Increase physics iterations for stable collisions
    rope.iterations = max(15, rope.iterations)
    
    # Small collision margin
    if rope._collision_query:
        rope._collision_query.margin = 2.0
    
    print("Collision response tuned for stability")
    print("Bounce: ", rope.collision_bounce)
    print("Friction: ", rope.collision_friction)
    print("Radius: ", rope.collision_radius)
    print("Iterations: ", rope.iterations)
```

## Interaction Issues

### Can't Grab or Interact with Rope

**Symptoms:**
- Unable to click and drag the rope
- Interaction areas not working
- No response to player input

**Causes:**
- Interaction mode set incorrectly
- Interaction areas not initialized
- Interaction width too small
- Input handling conflicts

**Solutions:**

```gdscript
# Fix rope interaction issues
func fix_interaction_issues(rope: PixelRope) -> void:
    print("=== Interaction Debug ===")
    
    # Check interaction mode
    print("Current interaction mode: ", rope.interaction_mode)
    match rope.interaction_mode:
        PixelRope.GrabMode.NONE:
            print("WARNING: Interaction is disabled (NONE)")
            print("Setting to ANY_POINT...")
            rope.interaction_mode = PixelRope.GrabMode.ANY_POINT
        PixelRope.GrabMode.ANCHORS_ONLY:
            print("Only anchors can be grabbed")
            print("Make sure end_anchor_draggable is enabled")
            rope.end_anchor_draggable = true
        PixelRope.GrabMode.ANY_POINT:
            print("Full rope interaction enabled")
    
    # Check interaction width
    print("Interaction width: ", rope.interaction_width)
    if rope.interaction_width < 15.0:
        print("Interaction width may be too small, increasing...")
        rope.interaction_width = 20.0
    
    # Check if segment areas exist
    print("Segment areas: ", rope._segment_areas.size())
    if rope._segment_areas.is_empty() and rope.interaction_mode == PixelRope.GrabMode.ANY_POINT:
        print("Segment areas not initialized, reinitializing...")
        rope._setup_interaction_areas()
    
    # Enable input visualization
    print("TIP: Connect to rope signals:")
    print("rope.rope_grabbed.connect(_on_rope_grabbed)")
    print("rope.rope_released.connect(_on_rope_released)")
```

### End Anchor Not Draggable

**Symptoms:**
- Can't drag the end anchor
- End anchor moves but doesn't respond to input
- Inconsistent dragging behavior

**Causes:**
- `end_anchor_draggable` set to false
- Conflict with `dynamic_end_anchor`
- Missing interaction areas

**Solutions:**

```gdscript
# Fix end anchor dragging issues
func fix_end_anchor_dragging(rope: PixelRope) -> void:
    print("=== End Anchor Dragging Debug ===")
    
    # Check end anchor draggable flag
    print("end_anchor_draggable: ", rope.end_anchor_draggable)
    if not rope.end_anchor_draggable:
        print("Enabling end anchor dragging...")
        rope.end_anchor_draggable = true
    
    # Check if end anchor is dynamic
    print("dynamic_end_anchor: ", rope.dynamic_end_anchor)
    if rope.dynamic_end_anchor:
        print("WARNING: End anchor is dynamic, which may conflict with dragging")
        print("For pure dragging behavior, consider setting dynamic_end_anchor = false")
    
    # Check end node setup
    if rope._end_node:
        print("End node exists")
        # Check for Area2D on end node
        var has_area = false
        for child in rope._end_node.get_children():
            if child is Area2D:
                has_area = true
                break
        
        print("End node has Area2D: ", has_area)
        if not has_area:
            print("Setting up draggable end node...")
            rope._setup_draggable_node(rope._end_node)
    else:
        print("WARNING: End node doesn't exist!")
```

## Performance Problems

### Rope Causes FPS Drops

**Symptoms:**
- Significant frame rate drops with ropes
- Lag increases with rope movement
- Performance degrades with multiple ropes

**Causes:**
- Too many segments
- Too many physics iterations
- Excessive collision checks
- Inefficient line algorithm

**Solutions:**

```gdscript
# Optimize rope for performance
func optimize_rope_performance(rope: PixelRope) -> void:
    print("=== Performance Optimization ===")
    
    # Check segment count
    print("Current segment count: ", rope.segment_count)
    var distance = rope.start_position.distance_to(rope.end_position)
    var optimal_segments = int(distance / 20.0)  # 1 segment per 20px
    
    if rope.segment_count > optimal_segments * 1.5:
        print("Too many segments, reducing to: ", optimal_segments)
        rope.segment_count = optimal_segments
        rope.segment_length = distance / rope.segment_count
    
    # Check physics iterations
    print("Current iterations: ", rope.iterations)
    if rope.iterations > 10:
        print("High iteration count, reducing to 10")
        rope.iterations = 10
    
    # Check collision setup
    if rope.enable_collisions:
        print("Collisions enabled - consider disabling if not essential")
        print("Current collision mask: ", rope.collision_mask)
        if not is_gameplay_critical(rope):
            print("Non-critical rope: suggesting disabling collisions")
    
    # Check line algorithm
    if rope.line_algorithm == LineAlgorithms.LineAlgorithmType.DDA:
        print("Using DDA algorithm - Bresenham is faster")
        rope.line_algorithm = LineAlgorithms.LineAlgorithmType.BRESENHAM
    
    print("Applied performance optimizations")
    
    # Reset rope to apply changes
    rope.reset_rope()

# Helper to determine if a rope is critical for gameplay
func is_gameplay_critical(rope: PixelRope) -> bool:
    # This is a placeholder - implement your own logic
    # to determine if a rope is essential for gameplay
    return false
```

### Memory Leaks

**Symptoms:**
- Memory usage grows over time
- Performance degrades during long sessions
- Errors when creating/destroying ropes

**Causes:**
- Not properly cleaning up ropes
- Orphaned Area2D/CollisionShape2D nodes
- Signal connections not cleaned up

**Solutions:**

```gdscript
# Proper rope cleanup to prevent memory leaks
func clean_up_rope(rope: PixelRope) -> void:
    print("=== Rope Cleanup ===")
    
    # Disconnect all signals
    for connection in rope.get_signal_connection_list("rope_broken"):
        rope.rope_broken.disconnect(connection["callable"])
    
    for connection in rope.get_signal_connection_list("rope_grabbed"):
        rope.rope_grabbed.disconnect(connection["callable"])
    
    for connection in rope.get_signal_connection_list("rope_released"):
        rope.rope_released.disconnect(connection["callable"])
    
    # Clean up any interaction areas
    for area in rope._segment_areas:
        if is_instance_valid(area):
            area.queue_free()
    
    rope._segment_areas.clear()
    
    # Free the rope itself
    rope.queue_free()
    
    print("Rope cleaned up successfully")
```

## Editor Related Issues

### Rope Doesn't Show in Editor

**Symptoms:**
- Rope isn't visible in the editor
- Anchor points visible but no rope between them
- Changes to properties don't update editor view

**Causes:**
- Editor preview functionality not initialized
- Plugin not properly loaded
- Custom type registration issues

**Solutions:**

```gdscript
# Fix editor preview issues
func fix_editor_preview(rope: PixelRope) -> void:
    # Force editor update
    rope._editor_mode = Engine.is_editor_hint()
    
    # Ensure anchor nodes exist
    rope._ensure_anchor_nodes()
    
    # Update stored positions
    if rope._start_node and rope._end_node:
        rope._last_start_pos = rope._start_node.position
        rope._last_end_pos = rope._end_node.position
        
        # Update properties to match
        rope.start_position = rope._start_node.position
        rope.end_position = rope._end_node.position
    
    # Force redraw
    rope.queue_redraw()
    
    # Setup editor updates
    rope._setup_editor_updates()
    
    print("Editor preview updated")
```

### Anchors Difficult to Position

**Symptoms:**
- Difficulty selecting or moving anchors
- Anchors don't snap to grid
- Visual issues with anchor handles

**Causes:**
- Anchor radius too small
- Debugging visualization disabled
- Conflict with other editor tools

**Solutions:**

```gdscript
# Improve anchor usability in editor
func improve_anchor_usability(rope: PixelRope) -> void:
    # Make anchors more visible
    rope.anchor_radius = 12.0  # Larger clickable area
    rope.anchor_debug_color = Color(0, 0.698, 0.885, 0.7)  # More visible
    rope.show_anchor_debug = true
    
    # Update anchor properties
    if rope._start_node and rope._start_node is RopeAnchor:
        rope._start_node.radius = rope.anchor_radius
        rope._start_node.debug_color = rope.anchor_debug_color
        rope._start_node.show_debug_shape = rope.show_anchor_debug
    
    if rope._end_node and rope._end_node is RopeAnchor:
        rope._end_node.radius = rope.anchor_radius
        rope._end_node.debug_color = rope.anchor_debug_color
        rope._end_node.show_debug_shape = rope.show_anchor_debug
    
    print("Anchor visibility and usability improved")
```

## Integration Challenges

### Connecting PixelRope to Other Nodes

**Symptoms:**
- Difficulty attaching rope to dynamic objects
- Rope doesn't follow attached objects
- Connection points drift over time

**Causes:**
- Missing update code
- Transform hierarchy issues
- Physics synchronization problems

**Solutions:**

```gdscript
# Create a synchronizer script for connecting ropes to other nodes
class_name RopeAttachment
extends Node

var rope: PixelRope
var start_node: Node2D
var end_node: Node2D
var maintain_local_positions: bool = false
var start_local_pos: Vector2
var end_local_pos: Vector2

func _ready():
    if rope and start_node:
        if maintain_local_positions:
            start_local_pos = start_node.to_local(rope.start_position)
    
    if rope and end_node:
        if maintain_local_positions:
            end_local_pos = end_node.to_local(rope.end_position)

func _physics_process(_delta):
    if rope and start_node and is_instance_valid(start_node):
        if maintain_local_positions:
            rope.start_position = start_node.to_global(start_local_pos)
        else:
            rope.start_position = start_node.global_position
    
    if rope and end_node and is_instance_valid(end_node):
        if maintain_local_positions:
            rope.end_position = end_node.to_global(end_local_pos)
        else:
            rope.end_position = end_node.global_position
```

Usage:
```gdscript
# Example of using the RopeAttachment
func connect_rope_to_objects(rope: PixelRope, start_obj: Node2D, end_obj: Node2D) -> void:
    var attachment = RopeAttachment.new()
    attachment.name = "RopeAttachment"
    attachment.rope = rope
    attachment.start_node = start_obj
    attachment.end_node = end_obj
    
    add_child(attachment)
    
    print("Rope connected to objects with automatic synchronization")
```

### Interaction with RigidBody2D Nodes

**Symptoms:**
- Rope doesn't apply forces correctly to RigidBody2D
- Physics behavior is erratic
- Unrealistic tethering/towing behavior

**Causes:**
- Inappropriate force application
- Missing physics callbacks
- Force direction issues

**Solutions:**

```gdscript
# Create a specialized attachment for rigid bodies
class_name RopeRigidBodyConnector
extends Node

@export var rope: PixelRope
@export var body: RigidBody2D
@export var connection_point: Vector2 = Vector2.ZERO
@export var force_scale: float = 100.0
@export var max_force: float = 1000.0
@export var rope_end: String = "end"  # "start" or "end"

var prev_position: Vector2

func _ready():
    if body:
        prev_position = body.global_position

func _physics_process(delta):
    if not rope or not body or not is_instance_valid(body):
        return
    
    if rope._broken:
        return
    
    # Update rope endpoint based on body position
    var attach_point = body.global_position
    if connection_point != Vector2.ZERO:
        attach_point = body.global_position + connection_point.rotated(body.global_rotation)
    
    if rope_end == "start":
        rope.start_position = attach_point
    else:
        rope.end_position = attach_point
    
    # Apply forces from rope tension to body
    if rope._state == PixelRope.RopeState.STRETCHED:
        # Calculate rope direction and tension
        var rope_point = rope_end == "start" ? 0 : rope.segment_count
        var prev_point = rope_end == "start" ? 1 : rope.segment_count - 1
        
        if rope._segments.size() > max(rope_point, prev_point):
            var direction = (rope._segments[prev_point].position - rope._segments[rope_point].position).normalized()
            
            # Calculate force based on stretch
            var stretch_factor = calculate_stretch_factor(rope)
            var tension = force_scale * (stretch_factor - 1.0)
            tension = min(tension, max_force)
            
            # Apply force to rigid body
            body.apply_central_force(direction * tension)
    
    # Store position for next frame
    prev_position = body.global_position

func calculate_stretch_factor(rope: PixelRope) -> float:
    # Calculate total length and compare to ideal length
    var total_length = 0.0
    var ideal_length = rope.segment_length * rope.segment_count
    
    for i in range(rope.segment_count):
        if i < rope._segments.size() - 1:
            total_length += rope._segments[i].position.distance_to(rope._segments[i+1].position)
    
    return total_length / ideal_length
```

Usage:
```gdscript
# Connect a rope to a rigid body
func connect_rope_to_rigidbody(rope: PixelRope, body: RigidBody2D) -> void:
    var connector = RopeRigidBodyConnector.new()
    connector.name = "RopeConnector"
    connector.rope = rope
    connector.body = body
    connector.rope_end = "end"  # Connect to end of rope
    
    add_child(connector)
    
    print("Rope connected to rigid body with physics interactions")
```

## Debugging Tools

### Visual Debug Helpers

```gdscript
# Visual debugging helper for ropes
class_name RopeDebugger
extends Node2D

@export var target_rope: PixelRope
@export var enable_physics_debug: bool = true
@export var enable_segment_debug: bool = true
@export var enable_state_debug: bool = true

func _ready():
    if not target_rope:
        set_physics_process(false)
        set_process(false)

func _process(_delta):
    queue_redraw()

func _draw():
    if not target_rope or not is_instance_valid(target_rope):
        return
    
    var segments = target_rope._segments
    if segments.is_empty():
        return
    
    if enable_segment_debug:
        # Draw circles at segment points
        for i in range(segments.size()):
            var pos = to_local(segments[i].position)
            
            # Color based on segment properties
            var color = Color.WHITE
            if segments[i].is_locked:
                color = Color.RED
            elif segments[i].is_grabbed:
                color = Color.GREEN
            
            draw_circle(pos, 3, color)
            
            # Draw index numbers
            draw_string(SystemFont.new(), pos + Vector2(5, 0), str(i), HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color.WHITE)
    
    if enable_physics_debug:
        # Draw velocity vectors
        for i in range(segments.size()):
            if i < segments.size() - 1:
                var pos = to_local(segments[i].position)
                var velocity = segments[i].position - segments[i].old_position
                draw_line(pos, pos + velocity * 10, Color.YELLOW, 1.0)
    
    if enable_state_debug:
        # Draw rope state indicator
        var state_text = "State: "
        var state_color = Color.WHITE
        
        match target_rope._state:
            PixelRope.RopeState.NORMAL:
                state_text += "NORMAL"
                state_color = Color.GREEN
            PixelRope.RopeState.STRETCHED:
                state_text += "STRETCHED"
                state_color = Color.YELLOW
            PixelRope.RopeState.BROKEN:
                state_text += "BROKEN"
                state_color = Color.RED
        
        var top_pos = to_local(target_rope.global_position) + Vector2(0, -30)
        draw_string(SystemFont.new(), top_pos, state_text, HORIZONTAL_ALIGNMENT_CENTER, -1, 14, state_color)
```

Usage:
```gdscript
# Add a visual debugger
func add_rope_debugger(rope: PixelRope) -> RopeDebugger:
    var debugger = RopeDebugger.new()
    debugger.name = "RopeDebugger"
    debugger.target_rope = rope
    
    rope.get_parent().add_child(debugger)
    
    print("Visual debugger added to rope")
    return debugger
```

### Console Debug Helper

```gdscript
# Console debugging helper for ropes
func debug_rope_to_console(rope: PixelRope) -> void:
    print("=== PixelRope Debug Report ===")
    print("Instance ID: ", rope.get_instance_id())
    print("Node path: ", rope.get_path())
    
    # Basic configuration
    print("\nBasic Configuration:")
    print("- Segment count: ", rope.segment_count)
    print("- Segment length: ", rope.segment_length)
    print("- Pixel size: ", rope.pixel_size)
    print("- Line algorithm: ", "Bresenham" if rope.line_algorithm == LineAlgorithms.LineAlgorithmType.BRESENHAM else "DDA")
    
    # Physics configuration
    print("\nPhysics Configuration:")
    print("- Gravity: ", rope.gravity)
    print("- Damping: ", rope.damping)
    print("- Iterations: ", rope.iterations)
    print("- Max stretch factor: ", rope.max_stretch_factor)
    
    # Anchor configuration
    print("\nAnchor Configuration:")
    print("- Start position: ", rope.start_position)
    print("- End position: ", rope.end_position)
    print("- Dynamic start: ", rope.dynamic_start_anchor)
    print("- Dynamic end: ", rope.dynamic_end_anchor)
    
    # Collision configuration
    print("\nCollision Configuration:")
    print("- Collisions enabled: ", rope.enable_collisions)
    print("- Collision mask: ", rope.collision_mask)
    print("- Collision radius: ", rope.collision_radius)
    
    # Current state
    print("\nCurrent State:")
    print("- State: ", ["NORMAL", "STRETCHED", "BROKEN"][rope._state])
    print("- Broken: ", rope._broken)
    print("- Initialized: ", rope._initialized)
    print("- Physics state: ", "Active" if rope._physics_direct_state != null else "Inactive")
    
    # Segment info
    print("\nSegment Info:")
    print("- Segment count: ", rope._segments.size())
    if not rope._segments.is_empty():
        print("- First few segments:")
        for i in range(min(3, rope._segments.size())):
            print("  [", i, "] Position: ", rope._segments[i].position, 
                  " Locked: ", rope._segments[i].is_locked,
                  " Grabbed: ", rope._segments[i].is_grabbed)
    
    print("\n=== End PixelRope Debug Report ===")
```

This troubleshooting guide should help you diagnose and fix the most common issues encountered when working with PixelRope in your Godot projects.