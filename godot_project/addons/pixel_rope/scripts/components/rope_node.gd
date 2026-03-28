@tool
@icon("res://addons/pixel_rope/icons/Curve2D.svg")
## Pixel-perfect rope simulation using Verlet integration.
##
## Verlet integration is the optimal algorithm for rope/chain simulation:
## it's numerically stable, preserves energy well, and naturally handles
## constraints through iterative position correction. Each frame:
## 1. Integrate positions using velocity = current_pos - old_pos (implicit)
## 2. Apply gravity and damping
## 3. Iteratively solve distance constraints between adjacent points
## 4. Resolve collisions with environment
extends Node2D
class_name PixelRope

signal rope_broken
signal rope_grabbed(segment_index: int)
signal rope_released

enum RopeState { NORMAL, STRETCHED, BROKEN }
enum GrabMode { NONE, ANCHORS_ONLY, ANY_POINT }

# --- Rope Properties ---
@export_group("Rope Properties")
@export var segment_count: int = 100:
	set(v):
		segment_count = v
		if Engine.is_editor_hint(): queue_redraw()

@export var segment_length: float = 5.0:
	set(v):
		segment_length = v
		if Engine.is_editor_hint(): queue_redraw()

@export var rope_color: Color = Color(0.8, 0.6, 0.2):
	set(v):
		rope_color = v
		if Engine.is_editor_hint(): queue_redraw()

# --- Pixelation ---
@export_group("Pixelation Properties")
@export var pixel_size: int = 4:
	set(v):
		pixel_size = v
		if Engine.is_editor_hint(): queue_redraw()

@export var pixel_spacing: int = 0:
	set(v):
		pixel_spacing = v
		if Engine.is_editor_hint(): queue_redraw()

@export var line_algorithm: LineAlgorithms.LineAlgorithmType = LineAlgorithms.LineAlgorithmType.BRESENHAM:
	set(v):
		line_algorithm = v
		if Engine.is_editor_hint(): queue_redraw()

# --- Physics ---
@export_group("Physics Properties")
@export var gravity: Vector2 = Vector2(0, 980)
@export_range(0.0, 1.0) var damping: float = 0.98
@export_range(1, 50) var iterations: int = 10
@export_range(1, 10) var physics_substeps: int = 3
@export var max_stretch_factor: float = 2.0

# --- Anchors ---
@export_group("Anchor Properties")
@export var start_position: Vector2 = Vector2(-100, 0):
	set(v):
		start_position = v
		if _start_anchor: _start_anchor.position = v
		if Engine.is_editor_hint(): queue_redraw()

@export var end_position: Vector2 = Vector2(100, 0):
	set(v):
		end_position = v
		if _end_anchor: _end_anchor.position = v
		if Engine.is_editor_hint(): queue_redraw()

@export var anchor_radius: float = 8.0:
	set(v):
		anchor_radius = v
		_sync_anchor_properties()

@export var anchor_debug_color: Color = Color(0.0, 0.698, 0.885, 0.5):
	set(v):
		anchor_debug_color = v
		_sync_anchor_properties()

@export var show_anchor_debug: bool = true:
	set(v):
		show_anchor_debug = v
		_sync_anchor_properties()

# --- Dynamic Anchors ---
@export_group("Dynamic Anchors")
@export var dynamic_start_anchor: bool = false:
	set(v):
		dynamic_start_anchor = v
		if _points.size() > 0: _locked[0] = not v

@export var dynamic_end_anchor: bool = true:
	set(v):
		dynamic_end_anchor = v
		if _points.size() > segment_count: _locked[segment_count] = not v

@export_range(0.1, 10.0) var anchor_mass: float = 1.0
@export var anchor_jitter: float = 0.0
@export var anchor_gravity: Vector2 = Vector2.ZERO

# --- Collision ---
@export_group("Collision Properties")
@export var enable_collisions: bool = true
@export_flags_2d_physics var collision_mask: int = 1
@export_range(0.0, 1.0) var collision_bounce: float = 0.3
@export_range(0.0, 1.0) var collision_friction: float = 0.7
@export_range(1.0, 20.0) var collision_radius: float = 4.0
@export var show_collision_debug: bool = false:
	set(v):
		show_collision_debug = v
		queue_redraw()

# --- Interaction ---
@export_group("Interaction Properties")
@export var interaction_mode: GrabMode = GrabMode.ANY_POINT
@export_range(5.0, 50.0) var interaction_width: float = 20.0
@export_range(0.1, 1.0) var grab_strength: float = 0.8
@export var end_anchor_draggable: bool = true

# --- Internal State ---
# Struct-of-Arrays for better cache performance and simpler code.
# Instead of Array[Dictionary], we use parallel arrays.
var _points: PackedVector2Array = PackedVector2Array()
var _old_points: PackedVector2Array = PackedVector2Array()
var _locked: PackedByteArray = PackedByteArray()
var _masses: PackedFloat32Array = PackedFloat32Array()

var _start_anchor: Node2D
var _end_anchor: Node2D
var _state: RopeState = RopeState.NORMAL
var _initialized: bool = false

# Collision
var _space_state: PhysicsDirectSpaceState2D
var _collision_shape: CircleShape2D
var _collision_query: PhysicsShapeQueryParameters2D
var _collision_contacts: Dictionary = {}

# Interaction
var _is_dragging: bool = false
var _grabbed_index: int = -1
var _grab_offset: Vector2 = Vector2.ZERO

# Editor
var _editor_mode: bool = false


func _ready() -> void:
	_editor_mode = Engine.is_editor_hint()
	_ensure_anchors()

	if _editor_mode:
		set_notify_transform(true)
		queue_redraw()
		return

	await get_tree().process_frame
	_init_rope()
	_initialized = true

	if enable_collisions:
		call_deferred("_init_collisions")


func _notification(what: int) -> void:
	if what == NOTIFICATION_EDITOR_PRE_SAVE and _start_anchor and _end_anchor:
		start_position = _start_anchor.position
		end_position = _end_anchor.position
	elif what == NOTIFICATION_TRANSFORM_CHANGED and _editor_mode:
		queue_redraw()


# ==========================================================================
# Rope Initialization
# ==========================================================================

func _init_rope() -> void:
	var count := segment_count + 1
	_points.resize(count)
	_old_points.resize(count)
	_locked.resize(count)
	_masses.resize(count)

	var start_pos := _start_anchor.global_position
	var end_pos := _end_anchor.global_position
	var step := (end_pos - start_pos) / float(segment_count)

	for i in count:
		var pos := start_pos + step * float(i)
		_points[i] = pos
		_old_points[i] = pos
		_masses[i] = anchor_mass if (i == 0 or i == segment_count) else 1.0

		if i == 0:
			_locked[i] = 0 if dynamic_start_anchor else 1
		elif i == segment_count:
			_locked[i] = 0 if dynamic_end_anchor else 1
		else:
			_locked[i] = 0

	_state = RopeState.NORMAL


func _init_collisions() -> void:
	if _editor_mode or not enable_collisions:
		return

	_collision_shape = CircleShape2D.new()
	_collision_shape.radius = collision_radius

	_collision_query = PhysicsShapeQueryParameters2D.new()
	_collision_query.collision_mask = collision_mask
	_collision_query.margin = 2.0
	_collision_query.shape = _collision_shape

	var world := get_world_2d()
	if world:
		_space_state = world.direct_space_state


# ==========================================================================
# Anchor Management
# ==========================================================================

func _ensure_anchors() -> void:
	_start_anchor = _get_or_create_anchor("StartAnchor", start_position)
	_end_anchor = _get_or_create_anchor("EndAnchor", end_position)


func _get_or_create_anchor(anchor_name: String, pos: Vector2) -> Node2D:
	var node := get_node_or_null(anchor_name)
	if node:
		node.position = pos
		if node is RopeAnchor and not node.position_changed.is_connected(_on_anchor_moved):
			node.position_changed.connect(_on_anchor_moved.bind(node))
		return node

	var anchor := RopeAnchor.new()
	anchor.name = anchor_name
	anchor.position = pos
	anchor.radius = anchor_radius
	anchor.debug_color = anchor_debug_color
	anchor.show_debug_shape = show_anchor_debug
	anchor.position_changed.connect(_on_anchor_moved.bind(anchor))
	add_child(anchor)

	if _editor_mode and get_tree().edited_scene_root:
		anchor.owner = get_tree().edited_scene_root

	return anchor


func _sync_anchor_properties() -> void:
	for anchor in [_start_anchor, _end_anchor]:
		if anchor and anchor is RopeAnchor:
			anchor.radius = anchor_radius
			anchor.debug_color = anchor_debug_color
			anchor.show_debug_shape = show_anchor_debug


func _on_anchor_moved(anchor: RopeAnchor) -> void:
	if anchor.name == "StartAnchor":
		start_position = anchor.position
	elif anchor.name == "EndAnchor":
		end_position = anchor.position
	queue_redraw()


# ==========================================================================
# Physics - Verlet Integration
# ==========================================================================

func _physics_process(delta: float) -> void:
	if _editor_mode:
		_editor_check_anchors()
		return

	if not _initialized or _points.is_empty():
		return

	_handle_dragging()

	if _state == RopeState.BROKEN:
		queue_redraw()
		return

	var sub_delta := delta / float(physics_substeps)

	for _substep in physics_substeps:
		# Pin non-dynamic anchors to their node positions
		if not dynamic_start_anchor:
			_points[0] = _start_anchor.global_position
		if not dynamic_end_anchor:
			_points[segment_count] = _end_anchor.global_position

		_verlet_integrate(sub_delta)
		_solve_constraints()

		if enable_collisions:
			_resolve_collisions()

	# Sync dynamic anchor nodes to simulation
	if dynamic_start_anchor:
		_start_anchor.global_position = _points[0]
	if dynamic_end_anchor:
		_end_anchor.global_position = _points[segment_count]

	_check_rope_state()
	queue_redraw()


## Verlet integration step: position += velocity * damping + acceleration * dt^2
## Velocity is implicitly stored as (position - old_position).
func _verlet_integrate(delta: float) -> void:
	var dt2 := delta * delta

	for i in _points.size():
		if _locked[i] or _grabbed_index == i:
			continue

		var pos := _points[i]
		var old := _old_points[i]
		var velocity := pos - old

		# Select gravity (custom for anchors if set)
		var g := gravity
		if (i == 0 or i == segment_count) and anchor_gravity != Vector2.ZERO:
			g = anchor_gravity

		# Anchor jitter
		if anchor_jitter > 0.0 and (i == 0 or i == segment_count):
			velocity += Vector2(
				randf_range(-anchor_jitter, anchor_jitter),
				randf_range(-anchor_jitter, anchor_jitter)
			)

		_old_points[i] = pos
		_points[i] = pos + velocity * damping + g * dt2 / _masses[i]


## Iteratively solve distance constraints between adjacent points.
## This is the core of rope simulation stability - more iterations = stiffer rope.
func _solve_constraints() -> void:
	for _iter in iterations:
		for i in segment_count:
			var p1 := _points[i]
			var p2 := _points[i + 1]

			var diff := p2 - p1
			var dist := diff.length()
			if dist < 0.001:
				dist = 0.001

			var correction := diff * ((segment_length - dist) / dist)

			var m1 := _masses[i]
			var m2 := _masses[i + 1]
			var total_mass := m1 + m2

			if not _locked[i] and _grabbed_index != i:
				_points[i] = p1 - correction * (m2 / total_mass)
			if not _locked[i + 1] and _grabbed_index != i + 1:
				_points[i + 1] = p2 + correction * (m1 / total_mass)


# ==========================================================================
# Collision Detection
# ==========================================================================

func _resolve_collisions() -> void:
	if not _space_state:
		var world := get_world_2d()
		if world:
			_space_state = world.direct_space_state
		else:
			return

	if not _collision_query:
		return

	_collision_contacts.clear()

	for i in _points.size():
		if _locked[i] or _grabbed_index == i:
			continue

		_collision_query.transform = Transform2D(0, _points[i])

		var info := _space_state.get_rest_info(_collision_query)
		if info.is_empty() or not info.has("point") or not info.has("normal"):
			continue

		var contact: Vector2 = info["point"]
		var normal: Vector2 = info["normal"]
		_collision_contacts[i] = {"position": contact, "normal": normal}

		var penetration := collision_radius - (_points[i] - contact).length()
		if penetration > 0:
			var movement := _points[i] - _old_points[i]
			var reflection := movement.bounce(normal) * collision_bounce

			# Apply friction to tangent component
			var normal_comp := normal * reflection.dot(normal)
			var tangent_comp := (reflection - normal_comp) * (1.0 - collision_friction)
			var final_vel := normal_comp + tangent_comp

			_points[i] = contact + normal * (collision_radius + 0.1)
			_old_points[i] = _points[i] - final_vel


# ==========================================================================
# Interaction - Simple distance-based (no per-segment Area2D)
# ==========================================================================

func _handle_dragging() -> void:
	if not _is_dragging:
		return

	var mouse_pos := get_global_mouse_position()

	if _grabbed_index >= 0 and _grabbed_index < _points.size():
		var target := mouse_pos + _grab_offset
		_points[_grabbed_index] = _points[_grabbed_index].lerp(target, grab_strength)
		_old_points[_grabbed_index] = _points[_grabbed_index]
	elif end_anchor_draggable and not dynamic_end_anchor:
		_end_anchor.global_position = mouse_pos
		_points[segment_count] = mouse_pos


func _input(event: InputEvent) -> void:
	if _editor_mode or not _initialized:
		return

	if not event is InputEventMouseButton or event.button_index != MOUSE_BUTTON_LEFT:
		return

	if event.pressed:
		_try_grab(get_global_mouse_position())
	else:
		_release_grab()


func _try_grab(mouse_pos: Vector2) -> void:
	if interaction_mode == GrabMode.NONE:
		return

	var best_index := -1
	var best_dist := interaction_width

	# Check end anchor first
	if end_anchor_draggable and not dynamic_end_anchor:
		var d := mouse_pos.distance_to(_points[segment_count])
		if d < best_dist:
			best_dist = d
			best_index = -2  # sentinel for end anchor drag

	# Check all segments if allowed
	if interaction_mode == GrabMode.ANY_POINT:
		for i in _points.size():
			if _locked[i]:
				continue
			var d := mouse_pos.distance_to(_points[i])
			if d < best_dist:
				best_dist = d
				best_index = i

	if best_index == -2:
		_is_dragging = true
		_grabbed_index = -1
	elif best_index >= 0:
		_is_dragging = true
		_grabbed_index = best_index
		_grab_offset = _points[best_index] - mouse_pos
		rope_grabbed.emit(best_index)


func _release_grab() -> void:
	if _grabbed_index >= 0:
		rope_released.emit()
	_is_dragging = false
	_grabbed_index = -1

	if _state == RopeState.BROKEN:
		reset_rope()


# ==========================================================================
# Rope State
# ==========================================================================

func _check_rope_state() -> void:
	var total_length := 0.0
	for i in segment_count:
		total_length += _points[i].distance_to(_points[i + 1])

	var ideal := segment_length * segment_count
	var stretch := total_length / ideal

	if stretch >= max_stretch_factor:
		_state = RopeState.BROKEN
		rope_broken.emit()
	elif stretch >= max_stretch_factor * 0.8:
		_state = RopeState.STRETCHED
	else:
		_state = RopeState.NORMAL


func break_rope() -> void:
	_state = RopeState.BROKEN
	rope_broken.emit()


func reset_rope() -> void:
	_state = RopeState.NORMAL
	_init_rope()


func get_state() -> int:
	return _state


# ==========================================================================
# Rendering - Pixelated Line Drawing
# ==========================================================================

func _draw() -> void:
	if _editor_mode:
		_draw_editor_preview()
		return

	if _points.is_empty():
		return

	if _state == RopeState.BROKEN:
		var s := to_local(_start_anchor.global_position)
		var e := to_local(_end_anchor.global_position)
		_draw_pixelated_line(s, e, Color.RED)
	else:
		var color := Color.DARK_ORANGE if _state == RopeState.STRETCHED else rope_color
		for i in _points.size() - 1:
			_draw_pixelated_line(to_local(_points[i]), to_local(_points[i + 1]), color)

	if enable_collisions and show_collision_debug:
		_draw_collision_debug()


func _draw_editor_preview() -> void:
	var s: Vector2
	var e: Vector2
	if _start_anchor and _end_anchor:
		s = to_local(_start_anchor.global_position)
		e = to_local(_end_anchor.global_position)
	else:
		s = start_position
		e = end_position
	_draw_pixelated_line(s, e, rope_color)


func _draw_pixelated_line(from: Vector2, to: Vector2, color: Color) -> void:
	var pts := LineAlgorithms.get_line_points(from, to, pixel_size, line_algorithm, pixel_spacing)
	var half := Vector2(pixel_size / 2.0, pixel_size / 2.0)
	var size := Vector2(pixel_size, pixel_size)
	for pt in pts:
		draw_rect(Rect2(pt - half, size), color)


func _draw_collision_debug() -> void:
	var debug_color := Color(1.0, 0.3, 0.3, 0.4)
	for i in _points.size():
		var pos := to_local(_points[i])
		draw_circle(pos, collision_radius, debug_color)

		if _collision_contacts.has(i):
			var data: Dictionary = _collision_contacts[i]
			var contact := to_local(data["position"])
			draw_circle(contact, 2.0, Color.RED)
			draw_line(contact, contact + data["normal"] * 10.0, Color.GREEN, 1.0)


# ==========================================================================
# Editor Helpers
# ==========================================================================

func _editor_check_anchors() -> void:
	if _start_anchor and _end_anchor:
		var sp := _start_anchor.position
		var ep := _end_anchor.position
		if sp != start_position or ep != end_position:
			start_position = sp
			end_position = ep
			queue_redraw()
