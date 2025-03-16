# Advanced Usage

This document covers more advanced topics for using PixelRope, including detailed explanations of the physics system, interaction mechanics, custom rendering, and collision detection.

## Table of Contents

- [Physics Simulation](#physics-simulation)
  - [Verlet Integration](#verlet-integration)
  - [Constraint Solving](#constraint-solving)
  - [Custom Forces](#custom-forces)
  - [Breaking Mechanics](#breaking-mechanics)
- [Interaction System](#interaction-system)
  - [Grab Modes](#grab-modes)
  - [Interaction Areas](#interaction-areas)
  - [Custom Interaction Handlers](#custom-interaction-handlers)
- [Custom Line Rendering](#custom-line-rendering)
  - [Line Algorithms](#line-algorithms)
  - [Custom Visual Effects](#custom-visual-effects)
- [Collision Detection](#collision-detection)
  - [Collision Response](#collision-response)
  - [Collision Masks](#collision-masks)
  - [Advanced Collision Handling](#advanced-collision-handling)
- [Runtime Modification](#runtime-modification)
  - [Dynamic Rope Splitting](#dynamic-rope-splitting)
  - [Rope Length Adaptation](#rope-length-adaptation)
  - [Attaching Objects to Ropes](#attaching-objects-to-ropes)
- [Integration with Other Systems](#integration-with-other-systems)
  - [Character Controllers](#character-controllers)
  - [Physics Objects](#physics-objects)
  - [Custom Game Mechanics](#custom-game-mechanics)

## Physics Simulation

PixelRope uses a verlet integration physics system combined with iterative constraint solving to create realistic rope behavior. This approach offers stability without requiring complex differential equations.

### Verlet Integration

Verlet integration calculates physics by storing current and previous positions to derive velocity implicitly:

```gdscript
# Simplified version of the verlet integration used in PixelRope
for i in range(_segments.size()):
    var segment = _segments[i]
    if segment.is_locked or segment.is_grabbed:
        continue
        
    var temp = segment.position
    var velocity = segment.position - segment.old_position
    
    # Apply forces with mass factoring
    segment.position += velocity * damping + gravity * delta * delta / segment.mass
    segment.old_position = temp
```

Key advantages of this approach:
- Simple implementation with stable behavior
- Natural energy conservation
- No need to explicitly store velocities
- Easily combined with constraint systems

### Constraint Solving

After position updates, PixelRope applies distance constraints to maintain segment lengths:

```gdscript
for _i in range(iterations):
    for j in range(segment_count):
        var segment1 = _segments[j]
        var segment2 = _segments[j + 1]
        
        var current_vec = segment2.position - segment1.position
        var current_dist = current_vec.length()
        
        # Skip if already at the correct distance
        if current_dist < 0.0001:
            continue
            
        # Calculate correction vector
        var difference = segment_length - current_dist
        var percent = difference / current_dist
        var correction = current_vec * percent
        
        # Apply correction based on mass ratio
        var mass_ratio1 = segment2.mass / (segment1.mass + segment2.mass)
        var mass_ratio2 = segment1.mass / (segment1.mass + segment2.mass)
        
        if not segment1.is_locked:
            segment1.position -= correction * mass_ratio1
            
        if not segment2.is_locked:
            segment2.position += correction * mass_ratio2
```

The `iterations` property controls how many times constraints are applied per physics frame. Higher values create stiffer, more stable ropes at the cost of performance.

### Custom Forces

You can apply custom forces to the rope by adding code in your game loop:

```gdscript
func apply_wind_force(rope: PixelRope, wind_direction: Vector2, wind_strength: float, delta: float):
    # Function must be called during physics processing
    
    # Access internal segments (use with caution - implementation detail)
    var segments = rope._segments
    
    for i in range(segments.size()):
        var segment = segments[i]
        
        # Skip locked segments
        if segment.is_locked or segment.is_grabbed:
            continue
            
        # Apply wind force
        var wind_force = wind_direction.normalized() * wind_strength
        
        # Apply force to segment position
        segment.position += wind_force * delta * delta / segment.mass
```

### Breaking Mechanics

PixelRope implements a breaking system that monitors the total rope length:

```gdscript
# Simplified version of rope breaking detection
func _check_rope_state() -> void:
    var total_length: float = 0.0
    var ideal_length: float = segment_length * segment_count
    
    # Calculate current total length
    for i in range(segment_count):
        var dist = _segments[i].position.distance_to(_segments[i + 1].position)
        total_length += dist
    
    # Calculate stretch factor and determine state
    var stretch_factor: float = total_length / ideal_length
    
    if stretch_factor >= max_stretch_factor:
        _state = RopeState.BROKEN
        _broken = true
        emit_signal("rope_broken")
    elif stretch_factor >= max_stretch_factor * 0.8:
        _state = RopeState.STRETCHED
    else:
        _state = RopeState.NORMAL
```

You can configure the breaking threshold using the `max_stretch_factor` property, or manually break the rope using `break_rope()`.

## Interaction System

PixelRope offers a flexible interaction system that allows players to grab and manipulate ropes.

### Grab Modes

There are three grab modes available, controlled by the `interaction_mode` property:

1. **NONE**: No interaction is possible with the rope
2. **ANCHORS_ONLY**: Only the anchor points can be grabbed
3. **ANY_POINT**: Any point along the rope can be grabbed

```gdscript
# Configure a rope to be fully interactive
rope.interaction_mode = PixelRope.GrabMode.ANY_POINT

# Or restrict to just the end anchors
rope.interaction_mode = PixelRope.GrabMode.ANCHORS_ONLY

# Or disable interaction entirely
rope.interaction_mode = PixelRope.GrabMode.NONE
```

### Interaction Areas

When `ANY_POINT` mode is enabled, PixelRope creates collision areas along the rope segments:

```gdscript
# Customize interaction area width
rope.interaction_width = 25.0  # Wider area for easier grabbing

# Adjust how strongly the rope responds to grabbing
rope.grab_strength = 0.9  # More responsive (0.0-1.0)
```

The implementation creates capsule collision shapes between segments to allow for smooth interaction anywhere along the rope.

### Custom Interaction Handlers

You can connect to the rope's signals to implement custom interaction behavior:

```gdscript
# Connect to interaction signals
func _ready():
    rope.rope_grabbed.connect(_on_rope_grabbed)
    rope.rope_released.connect(_on_rope_released)
    rope.rope_broken.connect(_on_rope_broken)

# Handle grab events
func _on_rope_grabbed(segment_index):
    print("Grabbed segment: ", segment_index)
    
    # You can access the grabbed segment from the rope's internal state
    var segment_position = rope._segments[segment_index].position
    
    # Implement custom behavior like attaching objects to the grab point
    attach_object_to_point(segment_position)
    
# Handle release events
func _on_rope_released():
    print("Rope released")
    
# Handle breaking events
func _on_rope_broken():
    print("Rope broke!")
    play_break_sound()
    
    # You can reset the rope after a delay if desired
    await get_tree().create_timer(2.0).timeout
    rope.reset_rope()
```

## Custom Line Rendering

PixelRope implements two line drawing algorithms that can be selected based on your needs.

### Line Algorithms

1. **Bresenham's Algorithm**: An integer-based line drawing algorithm that is computationally efficient and produces perfect pixel alignment. This is the default and recommended for most cases.

2. **DDA (Digital Differential Analyzer)**: A floating-point based algorithm that produces smoother lines, especially for diagonal segments. It's slightly more expensive computationally.

```gdscript
# Use Bresenham's algorithm for maximum performance
rope.line_algorithm = LineAlgorithms.LineAlgorithmType.BRESENHAM

# Use DDA for smoother lines (especially diagonals)
rope.line_algorithm = LineAlgorithms.LineAlgorithmType.DDA
```

You can benchmark the algorithms to see the performance difference:

```gdscript
# Compare performance and point count between algorithms
var from_point = Vector2(100, 100)
var to_point = Vector2(500, 300)
var pixel_size = 4
var results = LineAlgorithms.benchmark_algorithms(from_point, to_point, pixel_size)

print("Bresenham time: ", results.bresenham_time, "ms")
print("DDA time: ", results.dda_time, "ms")
print("Bresenham points: ", results.bresenham_points)
print("DDA points: ", results.dda_points)
```

### Custom Visual Effects

You can customize the rope's appearance beyond the basic settings:

```gdscript
# Create a dotted line effect
rope.pixel_spacing = 2  # Skip every other pixel

# Change rope color dynamically based on state
func _process(delta):
    match rope.get_state():
        PixelRope.RopeState.NORMAL:
            rope.rope_color = Color(0.8, 0.6, 0.2)  # Normal color
        PixelRope.RopeState.STRETCHED:
            # Interpolate to orange when stretched
            var stretch_color = Color(1.0, 0.5, 0.0)
            rope.rope_color = rope.rope_color.lerp(stretch_color, 0.1)
```

For more complex visual effects, you can extend the PixelRope class and override the `_draw` method:

```gdscript
class_name CustomRope
extends PixelRope

# Override draw method to add custom visuals
func _draw():
    # First call the parent implementation
    super._draw()
    
    # Add custom drawing on top of the rope
    if not _segments.is_empty() and not _broken:
        # Example: Draw small circles at each segment point
        for i in range(0, _segments.size(), 5):  # Every 5th segment
            var point = to_local(_segments[i].position)
            draw_circle(point, 3.0, Color.WHITE)
```

## Collision Detection

PixelRope includes a collision system that allows the rope to interact with the environment.

### Collision Response

Collision detection uses Godot's physics system to detect and respond to collisions:

```gdscript
# Basic collision configuration
rope.enable_collisions = true
rope.collision_mask = 1  # Collide with layer 1 objects
rope.collision_radius = 5.0  # Size of collision shapes
```

You can fine-tune the collision response:

```gdscript
# Configure collision bounce (0.0 = no bounce, 1.0 = full bounce)
rope.collision_bounce = 0.3  # Medium bounce

# Configure collision friction (0.0 = no friction, 1.0 = maximum friction)
rope.collision_friction = 0.7  # Medium-high friction

# Visualize collision shapes for debugging
rope.show_collision_debug = true
```

### Collision Masks

The `collision_mask` property determines which physics layers the rope will interact with:

```gdscript
# Set up collision masks for specific interactions

# Collide only with terrain (assuming terrain is on layer 1)
rope.collision_mask = 1  # binary: 00000001

# Collide with terrain (layer 1) and objects (layer 2)
rope.collision_mask = 3  # binary: 00000011

# Collide with terrain (layer 1) and players (layer 3)
rope.collision_mask = 5  # binary: 00000101
```

### Advanced Collision Handling

For advanced collision scenarios, you might need to handle collisions manually in your game code:

```gdscript
# Detect when the rope collides with specific objects
func _physics_process(delta):
    if rope._last_collisions.size() > 0:
        for segment_index in rope._last_collisions:
            var collision_data = rope._last_collisions[segment_index]
            var collision_point = collision_data["position"]
            var collision_normal = collision_data["normal"]
            
            # Check if collision is with a specific object
            var space_state = get_world_2d().direct_space_state
            var query = PhysicsPointQueryParameters2D.new()
            query.position = collision_point
            query.collision_mask = 2  # Check only layer 2 (objects)
            
            var result = space_state.intersect_point(query)
            if result.size() > 0:
                var collider = result[0]["collider"]
                if collider.is_in_group("interactive_objects"):
                    handle_rope_object_interaction(collider, segment_index, collision_normal)
```

## Runtime Modification

### Dynamic Rope Splitting

While PixelRope doesn't natively support splitting into multiple ropes, you can simulate this effect:

```gdscript
# Simulate rope splitting at a specific segment
func split_rope_at_segment(original_rope: PixelRope, segment_index: int):
    # Create two new ropes
    var rope1 = PixelRope.new()
    var rope2 = PixelRope.new()
    
    # Copy basic properties from the original rope
    for rope in [rope1, rope2]:
        rope.pixel_size = original_rope.pixel_size
        rope.rope_color = original_rope.rope_color
        rope.line_algorithm = original_rope.line_algorithm
        rope.gravity = original_rope.gravity
        rope.damping = original_rope.damping
        # Copy other properties as needed...
    
    # Configure first rope segment (from start to split point)
    rope1.segment_count = segment_index
    rope1.segment_length = original_rope.segment_length
    rope1.start_position = original_rope._segments[0].position
    rope1.end_position = original_rope._segments[segment_index].position
    rope1.dynamic_start_anchor = original_rope.dynamic_start_anchor
    rope1.dynamic_end_anchor = true  # The split end is dynamic
    
    # Configure second rope segment (from split point to end)
    rope2.segment_count = original_rope.segment_count - segment_index
    rope2.segment_length = original_rope.segment_length
    rope2.start_position = original_rope._segments[segment_index].position
    rope2.end_position = original_rope._segments[original_rope.segment_count].position
    rope2.dynamic_start_anchor = true  # The split start is dynamic
    rope2.dynamic_end_anchor = original_rope.dynamic_end_anchor
    
    # Add the new ropes to the scene
    original_rope.get_parent().add_child(rope1)
    original_rope.get_parent().add_child(rope2)
    
    # Remove the original rope
    original_rope.queue_free()
    
    return [rope1, rope2]
```

### Rope Length Adaptation

You can dynamically change a rope's length during gameplay:

```gdscript
# Gradually extend a rope
func extend_rope(rope: PixelRope, total_extension: float, extension_time: float):
    var original_segment_count = rope.segment_count
    var target_segment_count = original_segment_count + int(total_extension / rope.segment_length)
    
    var timer = 0.0
    while timer < extension_time:
        var t = timer / extension_time
        rope.segment_count = int(lerp(original_segment_count, target_segment_count, t))
        
        # Wait for next frame
        await get_tree().process_frame
        timer += get_process_delta_time()
    
    # Ensure we reach the exact target count
    rope.segment_count = target_segment_count

# Gradually shorten a rope (like reeling in a winch)
func shorten_rope(rope: PixelRope, total_reduction: float, reduction_time: float):
    var original_segment_count = rope.segment_count
    var min_count = 5  # Don't let rope get too short
    var target_segment_count = max(min_count, original_segment_count - int(total_reduction / rope.segment_length))
    
    var timer = 0.0
    while timer < reduction_time:
        var t = timer / reduction_time
        rope.segment_count = int(lerp(original_segment_count, target_segment_count, t))
        
        # Wait for next frame
        await get_tree().process_frame
        timer += get_process_delta_time()
    
    # Ensure we reach the exact target count
    rope.segment_count = target_segment_count
```

### Attaching Objects to Ropes

You can create a system to attach objects to specific rope segments:

```gdscript
# Attach an object to a specific rope segment
func attach_object_to_rope(rope: PixelRope, object: Node2D, segment_index: int):
    # Create a custom Remote Transform node to follow the segment
    var remote_transform = RemoteTransform2D.new()
    remote_transform.remote_path = object.get_path()
    rope.add_child(remote_transform)
    
    # Store the attachment information
    object.set_meta("attached_to_rope", rope)
    object.set_meta("attached_segment", segment_index)
    
    # Update the remote transform in process
    rope.set_meta("object_attachments", rope.get_meta("object_attachments", {}).duplicate())
    rope.get_meta("object_attachments")[segment_index] = remote_transform
    
    # Connect to process for updates if not already connected
    if not rope.is_connected("rope_broken", Callable(self, "_on_attachment_rope_broken")):
        rope.rope_broken.connect(_on_attachment_rope_broken.bind(rope))
    
    # Add this to rope's process to update attachment positions
    if not rope.has_method("_update_attachments"):
        rope.set_script(load("res://scripts/extended_rope.gd"))

# In extended_rope.gd:
extends PixelRope

func _physics_process(delta):
    super._physics_process(delta)
    _update_attachments()
    
func _update_attachments():
    var attachments = get_meta("object_attachments", {})
    for segment_index in attachments:
        if segment_index < _segments.size():
            var remote_transform = attachments[segment_index]
            remote_transform.global_position = _segments[segment_index].position
```

## Integration with Other Systems

### Character Controllers

Integrate PixelRope with character controllers for gameplay mechanics:

```gdscript
# Player climbing a rope
func _physics_process(delta):
    if player.is_grabbing_rope and player.grabbed_rope:
        var rope = player.grabbed_rope
        var segment = player.grabbed_segment
        
        # Move up the rope
        if Input.is_action_pressed("climb_up") and segment > 0:
            player.grabbed_segment -= 1
            player.global_position = rope._segments[player.grabbed_segment].position
            
        # Move down the rope
        elif Input.is_action_pressed("climb_down") and segment < rope.segment_count - 1:
            player.grabbed_segment += 1
            player.global_position = rope._segments[player.grabbed_segment].position
```

### Physics Objects

Connect ropes to RigidBody2D objects:

```gdscript
# Attach a rope to a swinging crate
func attach_rope_to_physics_object(rope: PixelRope, physics_object: RigidBody2D):
    # Configure the rope
    rope.dynamic_start_anchor = false  # Fixed to ceiling
    rope.dynamic_end_anchor = true     # Connected to physics object
    
    # Create a script to update positions
    var attachment_script = load("res://scripts/rope_physics_attachment.gd").new()
    attachment_script.rope = rope
    attachment_script.physics_object = physics_object
    add_child(attachment_script)

# In rope_physics_attachment.gd:
extends Node

var rope: PixelRope
var physics_object: RigidBody2D

func _physics_process(_delta):
    # Update the end anchor position to follow the physics object
    rope.end_position = physics_object.global_position
    
    # Apply force to the physics object based on rope tension
    if rope._state == PixelRope.RopeState.STRETCHED:
        # Calculate rope direction
        var end_segment = rope._segments[rope.segment_count]
        var pre_end_segment = rope._segments[rope.segment_count - 1]
        var direction = (pre_end_segment.position - end_segment.position).normalized()
        
        # Apply force proportional to stretch
        var ideal_length = rope.segment_length * rope.segment_count
        var actual_length = 0
        for i in range(rope.segment_count):
            actual_length += rope._segments[i].position.distance_to(rope._segments[i+1].position)
            
        var stretch_factor = actual_length / ideal_length
        var force_magnitude = 500.0 * (stretch_factor - 1.0)
        
        physics_object.apply_central_force(direction * force_magnitude)
```

### Custom Game Mechanics

Implement game-specific mechanics with ropes:

```gdscript
# Electrical wire that damages player on contact
class_name ElectricalWire
extends PixelRope

var damage_per_second = 15.0
var spark_effect = preload("res://effects/electric_spark.tscn")

func _ready():
    super._ready()
    rope_color = Color(0.9, 0.9, 0.2)  # Yellow
    
    # Create a timer to spawn particles
    var timer = Timer.new()
    timer.wait_time = 0.2
    timer.timeout.connect(_spawn_spark)
    add_child(timer)
    timer.start()

func _spawn_spark():
    if _broken:
        return
        
    # Create spark at random segment
    var segment_index = randi() % segment_count
    var spark = spark_effect.instantiate()
    spark.global_position = _segments[segment_index].position
    get_parent().add_child(spark)

func _on_area_entered(area):
    if area.is_in_group("player") and not _broken:
        var player = area.get_parent()
        if player.has_method("take_damage"):
            player.take_damage(damage_per_second * get_process_delta_time())
```

For more specific examples of implementation patterns, refer to the [Examples](examples.md) document.