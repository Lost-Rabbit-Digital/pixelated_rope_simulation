# PixelRope Examples

This document provides complete, practical examples of how to use PixelRope for common gameplay mechanics. Each example includes a full implementation with code samples and explanations.

## Table of Contents

- [Grappling Hook](#grappling-hook)
- [Dynamic Bridge](#dynamic-bridge)
- [Pulley System](#pulley-system)
- [Towing/Winching](#towingwinching)
- [Dynamic Lighting](#dynamic-lighting)
- [Electrical Wire Hazard](#electrical-wire-hazard)
- [Chain Reaction](#chain-reaction)
- [Rope Cutting Mechanic](#rope-cutting-mechanic)

## Grappling Hook

A grappling hook system allows the player to shoot a rope that attaches to surfaces and then pull themselves toward the attachment point.

### Implementation

```gdscript
extends CharacterBody2D

# Grappling hook properties
@export var grapple_speed: float = 1000.0
@export var grapple_pull_speed: float = 300.0
@export var grapple_max_distance: float = 500.0
@export var grapple_layer_mask: int = 1  # Which physics layers the hook can attach to

# Rope properties
var rope: PixelRope
var is_grappling: bool = false
var hook_attached: bool = false
var grapple_target: Vector2
var grapple_direction: Vector2

func _ready():
    # Initialize rope (but don't add to scene yet)
    rope = PixelRope.new()
    rope.segment_count = 30
    rope.pixel_size = 3
    rope.rope_color = Color(0.6, 0.6, 0.6)
    rope.gravity = Vector2(0, 50)  # Very light gravity effect
    rope.damping = 0.9
    rope.iterations = 15  # More stable for gameplay
    rope.dynamic_start_anchor = false  # Start is fixed to player
    rope.dynamic_end_anchor = true     # End moves with physics
    rope.enable_collisions = true
    rope.collision_bounce = 0.1
    rope.interaction_mode = PixelRope.GrabMode.NONE
    
    # Connect signal for rope breaking
    rope.rope_broken.connect(_on_rope_broken)

func _unhandled_input(event):
    if event.is_action_pressed("fire_grapple") and not is_grappling:
        fire_grapple()
    elif event.is_action_pressed("release_grapple") and is_grappling:
        release_grapple()

func fire_grapple():
    # Get mouse position (or use joystick direction)
    grapple_target = get_global_mouse_position()
    grapple_direction = (grapple_target - global_position).normalized()
    
    # Calculate distance to prevent shooting too far
    var distance = global_position.distance_to(grapple_target)
    if distance > grapple_max_distance:
        grapple_target = global_position + grapple_direction * grapple_max_distance
    
    # Set up rope
    rope.start_position = global_position
    rope.end_position = global_position  # Will extend during physics
    
    # Add rope to scene
    get_parent().add_child(rope)
    
    # Start grappling state
    is_grappling = true
    hook_attached = false

func release_grapple():
    is_grappling = false
    hook_attached = false
    
    # Remove the rope
    if is_instance_valid(rope) and rope.is_inside_tree():
        rope.queue_free()
        
    # Create a new rope for next use
    rope = PixelRope.new()
    rope.segment_count = 30
    rope.pixel_size = 3
    rope.rope_color = Color(0.6, 0.6, 0.6)
    rope.gravity = Vector2(0, 50)
    rope.damping = 0.9
    rope.iterations = 15
    rope.dynamic_start_anchor = false
    rope.dynamic_end_anchor = true
    rope.enable_collisions = true
    rope.collision_bounce = 0.1
    rope.interaction_mode = PixelRope.GrabMode.NONE
    rope.rope_broken.connect(_on_rope_broken)

func _physics_process(delta):
    # Update the rope's start position to follow the player
    if is_grappling and is_instance_valid(rope):
        rope.start_position = global_position
        
        if not hook_attached:
            # Extend the grappling hook
            var current_end = rope.end_position
            var new_end = current_end + grapple_direction * grapple_speed * delta
            
            # Check for collision with environment
            var space_state = get_world_2d().direct_space_state
            var query = PhysicsRayQueryParameters2D.create(current_end, new_end, grapple_layer_mask)
            var result = space_state.intersect_ray(query)
            
            if result:
                # Hit something, attach the hook
                rope.end_position = result.position
                hook_attached = true
            else:
                # Keep extending
                rope.end_position = new_end
                
                # Check if we've gone too far
                if global_position.distance_to(new_end) > grapple_max_distance:
                    release_grapple()
        else:
            # Hook is attached, pull player toward attachment point
            var pull_direction = (rope.end_position - global_position).normalized()
            velocity = pull_direction * grapple_pull_speed
            move_and_slide()
    
    # Player's regular movement code would go here as well

func _on_rope_broken():
    release_grapple()
```

### Usage

This implementation creates a character that can shoot a grappling hook toward the mouse cursor. When the hook hits a valid surface, the player is pulled toward the attachment point.

Key features:
- Rope visually extends during grappling
- Physics-based rope behavior with light gravity
- Hook attaches to surfaces and pulls the player
- Rope can be released manually or breaks under stress

## Dynamic Bridge

A bridge made of rope that reacts to the player's weight and movement.

### Implementation

```gdscript
extends Node2D

@export var bridge_width: float = 400
@export var segment_count: int = 20
@export var player_path: NodePath

var rope: PixelRope
var player: CharacterBody2D

func _ready():
    # Get the player reference
    if not player_path.is_empty():
        player = get_node(player_path)
    
    # Create the bridge rope
    rope = PixelRope.new()
    
    # Configure the rope
    rope.segment_count = segment_count
    rope.segment_length = bridge_width / segment_count
    rope.pixel_size = 5
    rope.rope_color = Color(0.6, 0.4, 0.2)  # Brown color
    
    # Physics configuration
    rope.gravity = Vector2(0, 980)  # Standard gravity
    rope.damping = 0.7  # Less bouncy
    rope.iterations = 25  # Very stable
    rope.max_stretch_factor = 1.3
    
    # Anchor setup
    rope.dynamic_start_anchor = false  # Fixed left side
    rope.dynamic_end_anchor = false    # Fixed right side
    rope.start_position = Vector2(position.x - bridge_width/2, position.y)
    rope.end_position = Vector2(position.x + bridge_width/2, position.y)
    
    # Collision setup
    rope.enable_collisions = true
    rope.collision_bounce = 0.0  # No bounce
    rope.collision_friction = 0.9  # High friction
    rope.collision_radius = 8.0  # Larger collision
    
    # Add to scene
    add_child(rope)
    
    # Create platform bodies along the rope
    _create_platform_bodies()

func _create_platform_bodies():
    # Add static body children to each segment for better collision
    for i in range(1, segment_count):
        var platform = StaticBody2D.new()
        platform.name = "PlatformSegment_" + str(i)
        
        var collision = CollisionShape2D.new()
        var shape = RectangleShape2D.new()
        shape.size = Vector2(rope.segment_length + 5, 8)
        collision.shape = shape
        
        platform.add_child(collision)
        add_child(platform)

func _physics_process(_delta):
    # Update platform positions to follow rope segments
    for i in range(1, segment_count):
        var platform = get_node_or_null("PlatformSegment_" + str(i))
        if platform:
            # Calculate position and rotation from rope segments
            var start_pos = rope._segments[i-1].position
            var end_pos = rope._segments[i].position
            var center = (start_pos + end_pos) / 2
            var direction = (end_pos - start_pos).normalized()
            var angle = direction.angle()
            
            # Update platform transform
            platform.global_position = center
            platform.global_rotation = angle
    
    # Make the bridge react more to the player
    if player and is_instance_valid(player):
        for i in range(1, segment_count):
            var platform = get_node_or_null("PlatformSegment_" + str(i))
            if platform:
                # Check if player is standing on this segment
                var platform_rect = Rect2(
                    platform.global_position - Vector2(rope.segment_length/2, 10),
                    Vector2(rope.segment_length, 20)
                )
                
                if platform_rect.has_point(player.global_position):
                    # Increase the weight of this segment
                    rope._segments[i].mass = 4.0
                else:
                    # Reset the weight
                    rope._segments[i].mass = 1.0
```

### Usage

This creates a bridge that reacts to the player's weight by increasing the mass of segments the player is standing on. The bridge also:
- Has static bodies along each segment for better player collision
- Creates visually compelling movement as the bridge sags under weight
- Maintains stability with high iteration count and lower damping

## Pulley System

A pulley system with a counterweight, allowing the player to create an elevator-like system.

### Implementation

```gdscript
extends Node2D

@export var pulley_width: float = 300
@export var rope_length: float = 400
@export var counterweight_mass: float = 100
@export var platform_path: NodePath

var rope: PixelRope
var platform: RigidBody2D
var counterweight: RigidBody2D
var pulley_center: Node2D

func _ready():
    # Get the platform reference
    if not platform_path.is_empty():
        platform = get_node(platform_path)
    
    # Create the pulley center point
    pulley_center = Node2D.new()
    pulley_center.global_position = global_position
    add_child(pulley_center)
    
    # Create counterweight
    counterweight = RigidBody2D.new()
    counterweight.mass = counterweight_mass
    
    var counter_collision = CollisionShape2D.new()
    var counter_shape = RectangleShape2D.new()
    counter_shape.size = Vector2(50, 80)
    counter_collision.shape = counter_shape
    counterweight.add_child(counter_collision)
    
    var counter_visual = ColorRect.new()
    counter_visual.size = Vector2(50, 80)
    counter_visual.position = Vector2(-25, -40)
    counter_visual.color = Color(0.7, 0.7, 0.7)
    counterweight.add_child(counter_visual)
    
    # Position counterweight
    counterweight.global_position = global_position + Vector2(pulley_width/2, rope_length)
    add_child(counterweight)
    
    # Create the rope
    rope = PixelRope.new()
    
    # Configure rope properties
    rope.segment_count = 60
    rope.segment_length = (rope_length * 2 + pulley_width) / 60
    rope.pixel_size = 3
    rope.rope_color = Color(0.6, 0.6, 0.6)
    rope.gravity = Vector2(0, 980)
    rope.damping = 0.8
    rope.iterations = 20
    
    # Connect to platform and counterweight
    if platform:
        rope.start_position = platform.global_position
    else:
        rope.start_position = global_position + Vector2(-pulley_width/2, rope_length)
    
    rope.dynamic_start_anchor = true
    rope.dynamic_end_anchor = true
    rope.end_position = counterweight.global_position
    
    add_child(rope)
    
    # Add pulley constraint points
    _add_pulley_constraints()

func _add_pulley_constraints():
    # Add special segments that will serve as pulley points
    var middle_segment = rope.segment_count / 2
    rope._segments[middle_segment].is_locked = true
    rope._segments[middle_segment].position = pulley_center.global_position

func _physics_process(_delta):
    # Update rope endpoints to follow platform and counterweight
    if platform and is_instance_valid(platform):
        rope.start_position = platform.global_position
    
    if counterweight and is_instance_valid(counterweight):
        rope.end_position = counterweight.global_position
    
    # Keep the pulley point fixed
    var middle_segment = rope.segment_count / 2
    rope._segments[middle_segment].position = pulley_center.global_position
    
    # Ensure rope is the right length on both sides
    _balance_rope_segments()

func _balance_rope_segments():
    # This function ensures the rope maintains equal tension on both sides
    # It's a simplified version of how a real pulley works
    
    var middle_segment = rope.segment_count / 2
    
    # Calculate total rope length
    var total_length = 0
    for i in range(rope.segment_count):
        var segment1 = rope._segments[i]
        var segment2 = rope._segments[i + 1]
        total_length += segment1.position.distance_to(segment2.position)
    
    # Force platform and counterweight to maintain rope length
    if platform and counterweight:
        var platform_to_pulley = platform.global_position.distance_to(pulley_center.global_position)
        var counter_to_pulley = counterweight.global_position.distance_to(pulley_center.global_position)
        
        # Apply forces to maintain balance
        if abs(platform_to_pulley - counter_to_pulley) > 10:
            if platform_to_pulley > counter_to_pulley:
                # Pull counterweight down
                counterweight.apply_central_force(Vector2(0, 200))
                # Lift platform up
                platform.apply_central_force(Vector2(0, -200))
            else:
                # Pull platform down
                platform.apply_central_force(Vector2(0, 200))
                # Lift counterweight up
                counterweight.apply_central_force(Vector2(0, -200))
```

### Usage

This creates a pulley system where:
- A platform and counterweight are connected by a rope
- The rope passes over a pulley point in the center
- The system maintains balance by applying forces
- The platform can be used as an elevator
- The counterweight's mass affects how the system responds

## Towing/Winching

A system for towing or winching objects using a rope.

### Implementation

```gdscript
extends Node2D

@export var winch_power: float = 200.0
@export var max_winch_speed: float = 100.0
@export var towed_object_path: NodePath
@export var winch_point_path: NodePath

var rope: PixelRope
var towed_object: RigidBody2D
var winch_point: Node2D
var current_length: float
var target_length: float
var is_winching: bool = false
var winch_direction: int = 0  # -1: extend, 1: retract

func _ready():
    # Get references
    if not towed_object_path.is_empty():
        towed_object = get_node(towed_object_path)
    
    if not winch_point_path.is_empty():
        winch_point = get_node(winch_point_path)
    else:
        winch_point = self  # Use self as winch point
    
    # Create the rope
    rope = PixelRope.new()
    
    # Configure rope
    rope.segment_count = 30
    rope.segment_length = 10.0
    rope.pixel_size = 4
    rope.rope_color = Color(0.2, 0.2, 0.2)  # Dark gray/black
    
    rope.gravity = Vector2(0, 200)  # Reduced gravity
    rope.damping = 0.8
    rope.iterations = 20
    rope.max_stretch_factor = 1.8  # Strong cable
    
    rope.dynamic_start_anchor = false  # Winch point is fixed
    rope.dynamic_end_anchor = true     # Towed object can move
    
    rope.enable_collisions = true
    rope.collision_bounce = 0.1
    rope.collision_friction = 0.6
    
    rope.interaction_mode = PixelRope.GrabMode.NONE  # No interaction during towing
    
    # Set positions
    rope.start_position = winch_point.global_position
    if towed_object:
        rope.end_position = towed_object.global_position
    else:
        rope.end_position = global_position + Vector2(300, 0)
    
    # Add to scene
    add_child(rope)
    
    # Store initial length
    current_length = rope.segment_count * rope.segment_length
    target_length = current_length

func _unhandled_input(event):
    # Controls for extending/retracting the winch
    if event.is_action_pressed("extend_winch"):
        winch_direction = -1
        is_winching = true
    elif event.is_action_pressed("retract_winch"):
        winch_direction = 1
        is_winching = true
    elif event.is_action_released("extend_winch") or event.is_action_released("retract_winch"):
        is_winching = false

func _physics_process(delta):
    # Update rope positions
    rope.start_position = winch_point.global_position
    
    if towed_object and is_instance_valid(towed_object):
        rope.end_position = towed_object.global_position
    
    # Handle winching
    if is_winching:
        # Update target length
        target_length += winch_direction * max_winch_speed * delta
        target_length = max(rope.segment_length * 5, target_length)  # Minimum length
        
        # Calculate how many segments we need
        var target_segments = max(5, int(target_length / rope.segment_length))
        
        # Update rope segment count
        if target_segments != rope.segment_count:
            rope.segment_count = target_segments
    
    # Apply winching force to towed object
    if towed_object and is_instance_valid(towed_object) and is_winching and winch_direction > 0:
        # Calculate direction to winch
        var winch_dir = (winch_point.global_position - towed_object.global_position).normalized()
        
        # Apply force proportional to distance
        var distance = winch_point.global_position.distance_to(towed_object.global_position)
        var force_magnitude = winch_power * min(1.0, distance / 200.0)
        
        towed_object.apply_central_force(winch_dir * force_magnitude)
```

### Usage

This creates a winch/towing system where:
- A fixed winch point connects to a towed object
- The rope length can be extended or retracted
- Force is applied to pull the towed object when winching
- The system handles collisions with the environment

## Dynamic Lighting

Using rope to create a string of lights with dynamic shadows.

### Implementation

```gdscript
extends Node2D

@export var light_count: int = 10
@export var light_radius: float = 100.0
@export var light_energy: float = 0.7
@export var light_color: Color = Color(1.0, 0.9, 0.7)  # Warm light
@export var rope_length: float = 400
@export var sway_amount: float = 20.0

var rope: PixelRope
var lights: Array[PointLight2D] = []

func _ready():
    # Create the rope
    rope = PixelRope.new()
    
    # Configure rope
    rope.segment_count = light_count * 2  # More segments than lights
    rope.segment_length = rope_length / rope.segment_count
    rope.pixel_size = 2
    rope.rope_color = Color(0.4, 0.4, 0.4)  # Dark gray wire
    
    rope.gravity = Vector2(0, 100)  # Light gravity for gentle sag
    rope.damping = 0.97
    rope.iterations = 10
    
    rope.dynamic_start_anchor = false
    rope.dynamic_end_anchor = false
    rope.start_position = global_position
    rope.end_position = global_position + Vector2(rope_length, 0)
    
    rope.enable_collisions = false  # No need for collisions
    rope.interaction_mode = PixelRope.GrabMode.NONE
    
    add_child(rope)
    
    # Create lights along the rope
    _create_lights()
    
    # Add some gentle wind sway
    var timer = Timer.new()
    timer.wait_time = 1.5
    timer.timeout.connect(_apply_wind_sway)
    add_child(timer)
    timer.start()

func _create_lights():
    # Clear existing lights if any
    for light in lights:
        if is_instance_valid(light):
            light.queue_free()
    
    lights.clear()
    
    # Create light texture if needed
    var light_texture = _create_light_texture()
    
    # Add lights at regular intervals
    for i in range(light_count):
        var light = PointLight2D.new()
        light.texture = light_texture
        light.energy = light_energy
        light.color = light_color
        light.range_layer_min = -1  # Affect all layers below
        light.range_layer_max = 1   # Affect all layers above
        light.shadow_enabled = true
        light.shadow_filter = 1     # Soft shadows
        light.shadow_filter_smooth = 2.0
        light.texture_scale = light_radius / 128.0  # Assuming 128px texture
        
        add_child(light)
        lights.append(light)

func _create_light_texture() -> Texture2D:
    # Create a simple radial gradient texture for the light
    var img = Image.create(128, 128, false, Image.FORMAT_RGBA8)
    img.fill(Color(0, 0, 0, 0))
    
    var center = Vector2(64, 64)
    var radius = 64.0
    
    # Draw radial gradient
    for x in range(128):
        for y in range(128):
            var pos = Vector2(x, y)
            var dist = pos.distance_to(center)
            if dist <= radius:
                var alpha = 1.0 - (dist / radius)
                img.set_pixel(x, y, Color(1, 1, 1, alpha))
    
    return ImageTexture.create_from_image(img)

func _physics_process(_delta):
    # Update light positions based on rope segments
    for i in range(light_count):
        if i < lights.size():
            var segment_index = i * 2  # Every other segment
            if segment_index < rope._segments.size():
                lights[i].global_position = rope._segments[segment_index].position

func _apply_wind_sway():
    # Apply random forces to simulate wind
    var wind_direction = Vector2(randf_range(-1.0, 1.0), randf_range(-0.5, 0.2)).normalized()
    var wind_strength = randf_range(sway_amount * 0.5, sway_amount)
    
    for i in range(1, rope.segment_count):
        if not rope._segments[i].is_locked:
            var random_factor = randf_range(0.7, 1.3)
            rope._segments[i].position += wind_direction * wind_strength * random_factor
```

### Usage

This creates a string of lights that:
- Hangs naturally with a gentle sag
- Has dynamic lighting with soft shadows
- Sways gently to simulate wind
- Updates light positions based on rope physics

## Electrical Wire Hazard

A dangerous electrical wire that damages the player on contact.

### Implementation

```gdscript
extends Node2D

@export var damage_per_second: float = 30.0
@export var wire_length: float = 300.0
@export var spark_frequency: float = 0.2  # Seconds between sparks
@export var player_path: NodePath

var rope: PixelRope
var player: CharacterBody2D
var spark_effect = preload("res://effects/electric_spark.tscn")  # Assume this exists
var spark_timer: float = 0.0

func _ready():
    # Get player reference
    if not player_path.is_empty():
        player = get_node(player_path)
    
    # Create the electric wire
    rope = PixelRope.new()
    
    # Configure rope appearance
    rope.segment_count = 40
    rope.segment_length = wire_length / rope.segment_count
    rope.pixel_size = 3
    rope.rope_color = Color(0.9, 0.9, 0.2)  # Yellow
    
    # Physics configuration
    rope.gravity = Vector2(0, 300)
    rope.damping = 0.95
    rope.iterations = 10
    rope.max_stretch_factor = 1.1  # Breaks easily
    
    # Anchor setup
    rope.dynamic_start_anchor = false
    rope.dynamic_end_anchor = false
    rope.start_position = global_position
    rope.end_position = global_position + Vector2(wire_length, 0)
    
    # Collision setup
    rope.enable_collisions = true
    rope.collision_bounce = 0.2
    rope.collision_friction = 0.3
    
    # Enable interaction
    rope.interaction_mode = PixelRope.GrabMode.ANY_POINT
    rope.grab_strength = 0.7
    
    # Connect signals
    rope.rope_grabbed.connect(_on_rope_grabbed)
    rope.rope_broken.connect(_on_rope_broken)
    
    add_child(rope)
    
    # Create areas for damage detection
    _create_hazard_areas()

func _create_hazard_areas():
    # Add area2D nodes along the rope for damage detection
    for i in range(0, rope.segment_count, 2):
        var area = Area2D.new()
        area.name = "HazardArea_" + str(i)
        
        var collision = CollisionShape2D.new()
        var shape = CircleShape2D.new()
        shape.radius = 10.0
        collision.shape = shape
        
        area.add_child(collision)
        area.body_entered.connect(_on_hazard_area_body_entered.bind(area))
        
        add_child(area)

func _physics_process(delta):
    # Update hazard area positions
    for i in range(0, rope.segment_count, 2):
        var area = get_node_or_null("HazardArea_" + str(i))
        if area and i < rope._segments.size():
            area.global_position = rope._segments[i].position
    
    # Check for player damage
    if player and is_instance_valid(player):
        for i in range(0, rope.segment_count, 2):
            var area = get_node_or_null("HazardArea_" + str(i))
            if area:
                # Check if player is overlapping this area
                var overlapping_bodies = area.get_overlapping_bodies()
                if overlapping_bodies.has(player):
                    damage_player(delta)
    
    # Spawn sparks periodically
    spark_timer += delta
    if spark_timer >= spark_frequency:
        spark_timer = 0
        spawn_spark()

func damage_player(delta):
    if player.has_method("take_damage"):
        player.take_damage(damage_per_second * delta)

func spawn_spark():
    if rope._broken:
        return
        
    # Create spark at random segment
    var segment_index = randi() % rope.segment_count
    var spark = spark_effect.instantiate()
    spark.global_position = rope._segments[segment_index].position
    get_parent().add_child(spark)

func _on_rope_grabbed(segment_index):
    # Damage player immediately when grabbing
    if player and player.has_method("take_damage"):
        player.take_damage(damage_per_second * 0.5)  # Initial shock

func _on_rope_broken():
    # Wire broken - stop damaging and create big spark effect
    var break_spark = spark_effect.instantiate()
    break_spark.scale = Vector2(3, 3)  # Bigger spark
    break_spark.global_position = rope._segments[rope.segment_count / 2].position
    get_parent().add_child(break_spark)

func _on_hazard_area_body_entered(body, area):
    # Additional effect when something touches the wire
    if body != player and not rope._broken:
        spawn_spark()
```

### Usage

This creates an electrical hazard that:
- Visually resembles a power line with yellow color
- Creates spark effects at random intervals
- Damages the player on contact
- Can be broken, creating a larger spark effect
- Has Area2D nodes along the rope for precise collision detection

## Chain Reaction

A system where multiple ropes are connected, and breaking one triggers a chain reaction.

### Implementation

```gdscript
extends Node2D

@export var rope_count: int = 5
@export var rope_spacing: float = 100.0
@export var rope_length: float = 300.0
@export var chain_reaction_delay: float = 0.3

var ropes: Array[PixelRope] = []

func _ready():
    # Create multiple connected ropes
    for i in range(rope_count):
        var rope = create_rope(i)
        ropes.append(rope)
        
        # Connect to rope broken signal
        rope.rope_broken.connect(_on_rope_broken.bind(i))

func create_rope(index: int) -> PixelRope:
    var rope = PixelRope.new()
    
    # Configure rope
    rope.segment_count = 30
    rope.segment_length = rope_length / rope.segment_count
    rope.pixel_size = 4
    rope.rope_color = Color(0.7, 0.3, 0.3)  # Reddish
    
    rope.gravity = Vector2(0, 490)
    rope.damping = 0.95
    rope.iterations = 15
    rope.max_stretch_factor = 1.2  # Low breaking threshold
    
    rope.dynamic_start_anchor = false
    rope.dynamic_end_anchor = false
    
    # Position rope
    var x_pos = global_position.x + index * rope_spacing
    rope.start_position = Vector2(x_pos, global_position.y)
    rope.end_position = Vector2(x_pos, global_position.y + rope_length)
    
    rope.enable_collisions = true
    rope.interaction_mode = PixelRope.GrabMode.ANY_POINT
    
    add_child(rope)
    return rope

func _on_rope_broken(index: int):
    # Trigger next rope after delay
    if index < rope_count - 1:
        var timer = get_tree().create_timer(chain_reaction_delay)
        timer.timeout.connect(func(): break_next_rope(index + 1))
    
    # Visual/audio effects could be added here
    _create_break_effect(index)

func break_next_rope(index: int):
    if index < ropes.size():
        # Apply stress to the next rope to make it break
        var segments = ropes[index]._segments
        var mid_point = segments.size() / 2
        
        # Pull a middle segment strongly to break the rope
        if mid_point < segments.size():
            segments[mid_point].position += Vector2(0, 150)

func _create_break_effect(index: int):
    # Create a particle effect at the break location
    var particles = CPUParticles2D.new()
    
    # Configure particles
    particles.emitting = true
    particles.one_shot = true
    particles.explosiveness = 1.0
    particles.amount = 20
    particles.lifetime = 0.5
    particles.velocity_spread = 30.0
    particles.direction = Vector2.RIGHT
    particles.spread = 180
    particles.initial_velocity_min = 100
    particles.initial_velocity_max = 200
    particles.gravity = Vector2(0, 980)