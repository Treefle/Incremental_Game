class_name AgentSystem
extends Node2D

## Data-oriented agent simulation for large crowds.
##
## Performance architecture for 10,000 agents:
##   - Agent state stored in flat PackedArrays (positions, velocities) — no per-Node overhead.
##   - Single MultiMeshInstance2D draws all agents in ONE draw call.
##   - Render buffer updated via set_instance_transform_2d each frame;
##     reads directly from positions[] so it stays in sync with particle/indicator draws.
##   - Flow field sampled per agent: O(1) bilinear lookup.
##   - Total per-frame work: O(agent_count) loop + 1 GPU upload.
##
## Memory estimate at 10,000 agents:
##   positions  : 10k × 8  bytes = ~80 KB
##   velocities : 10k × 8  bytes = ~80 KB
##   flow field : 64×64 × 12 bytes ≈ 48 KB
##   Total      : < 250 KB

const CELL_SIZE:   int   = 16
const WORLD_W:     int   = 64
const WORLD_H:     int   = 64
const TILE_CAPACITY: int = 5
const START_REVEAL_RADIUS: int = 4
const REVEAL_RADIUS: int = 3
const DEFAULT_WATCHTOWER_RADIUS: int = 7

## How many agents to simulate. Change in the Inspector before running.
@export var agent_count: int = 1
## When enabled, agent movement is unbounded and ignores fixed-grid pathfinding.
@export var infinite_mode: bool = true
## Movement speed in tiles per second (1.0 = one tile each second).
@export_range(0.1, 20.0, 0.1) var tiles_per_second: float = 1.0
## Agent quad size in pixels. Raise for easier visibility.
@export_range(2.0, 16.0, 0.5) var agent_size_px: float = 8.0
## Blends a tiny noise vector into steering to avoid visible sorting artifacts.
@export_range(0.0, 0.4, 0.01) var direction_noise: float = 0.12
## Small persistent per-agent render jitter (pixels) for more organic settling.
@export_range(0.0, 2.0, 0.05) var visual_jitter_px: float = 0.6
## Allow tighter same-tile stacking. 0.5 = 50% overlap, 0.8 = 80% overlap.
@export_range(0.5, 0.9, 0.05) var max_overlap_ratio: float = 0.75
## Settling ring radius around target in tiles.
@export_range(0.5, 10.0, 0.1) var settle_radius_tiles: float = 3.0
## Blend range around settle radius in tiles.
@export_range(0.1, 5.0, 0.1) var settle_band_tiles: float = 1.0
## Max cached flow fields keyed by target tile + walkability revision.
@export_range(8, 256, 8) var flow_cache_capacity: int = 64
## Delay before recomputing flow after rapid retargeting.
@export_range(0.0, 0.5, 0.01) var flow_recompute_debounce_sec: float = 0.03
## Skip drawing agents outside active camera bounds while still simulating them.
@export var cull_offscreen_render: bool = true
## Extra margin around the camera rectangle so pop-in is less noticeable.
@export_range(0.0, 512.0, 1.0) var render_cull_margin_px: float = 96.0
@export var render_via_external_batch: bool = false

## Read-only: flat arrays of agent state (public for external systems to read).
var positions:  PackedVector2Array
var velocities: PackedVector2Array
var _speed_multipliers: PackedFloat32Array
var _agent_colors: PackedColorArray
var _agent_targets: PackedVector2Array
var _ignore_tile_capacity: PackedByteArray
var _noise_phase: PackedFloat32Array
var _noise_rate: PackedFloat32Array
var _visual_dir: PackedVector2Array

var _flow:    FlowField
var _walkable: PackedByteArray
var _mmi:     MultiMeshInstance2D
var _tile_counts: PackedInt32Array
var _render_tile_counts: PackedInt32Array
var _slot_offsets: Array[Vector2] = []
var _target_world: Vector2
var _explored: PackedByteArray
var _agent_reveal_radius: int = REVEAL_RADIUS
var _watchtower_radius: int = DEFAULT_WATCHTOWER_RADIUS
var _auto_watchtower_enabled: bool = false
var _max_watchtowers: int = 12
var _watchtowers: Array[Vector2i] = []
var _flow_dirty: bool = false
var _pending_flow_target_world: Vector2 = Vector2.ZERO
var _flow_recompute_cooldown: float = 0.0
var _last_flow_target_cell: Vector2i = Vector2i(-9999, -9999)
var _render_bounds_enabled: bool = false
var _render_bounds_min: Vector2 = Vector2.ZERO
var _render_bounds_max: Vector2 = Vector2.ZERO




func _ready() -> void:
	_build_multimesh()
	_build_slot_offsets()
	if infinite_mode:
		_spawn_agents_infinite()
		_target_world = Vector2.ZERO
		return

	_build_world()
	_spawn_agents()
	# Default target: world centre
	_target_world = Vector2(WORLD_W * CELL_SIZE * 0.5, WORLD_H * CELL_SIZE * 0.5)
	_flow.compute(_target_world, _walkable)
	_last_flow_target_cell = _world_to_cell(_target_world)


## ─── World ────────────────────────────────────────────────────────────────────

func _build_world() -> void:
	_flow = FlowField.new()
	_flow.setup(WORLD_W, WORLD_H, CELL_SIZE)
	_flow.set_cache_capacity(flow_cache_capacity)
	_tile_counts = PackedInt32Array()
	_tile_counts.resize(WORLD_W * WORLD_H)
	_render_tile_counts = PackedInt32Array()
	_render_tile_counts.resize(WORLD_W * WORLD_H)

	_walkable = PackedByteArray()
	_walkable.resize(WORLD_W * WORLD_H)
	_walkable.fill(1)
	_explored = PackedByteArray()
	_explored.resize(WORLD_W * WORLD_H)
	_explored.fill(0)

	# 1-cell-wide impassable border
	for x in WORLD_W:
		_walkable[x] = 0
		_walkable[(WORLD_H - 1) * WORLD_W + x] = 0
	for y in WORLD_H:
		_walkable[y * WORLD_W] = 0
		_walkable[y * WORLD_W + WORLD_W - 1] = 0

	# Small starting area (fog surrounds it).
	var cx: int = WORLD_W / 2
	var cy: int = WORLD_H / 2
	for y in range(cy - START_REVEAL_RADIUS, cy + START_REVEAL_RADIUS + 1):
		for x in range(cx - START_REVEAL_RADIUS, cx + START_REVEAL_RADIUS + 1):
			if x > 0 and x < WORLD_W - 1 and y > 0 and y < WORLD_H - 1:
				_explored[y * WORLD_W + x] = 1

	# Start with one small landmark watchtower in the initial area.
	_watchtowers.clear()
	_add_watchtower_tile(Vector2i(cx, cy))
	_flow.notify_walkable_changed()


func _build_slot_offsets() -> void:
	# Convert overlap ratio to center separation.
	# separation = size * (1 - overlap), so higher overlap => tighter packing.
	var separation: float = agent_size_px * (1.0 - max_overlap_ratio)
	_slot_offsets = [
		Vector2(cos(0.0),       sin(0.0))       * separation,
		Vector2(cos(TAU * 0.2), sin(TAU * 0.2)) * separation,
		Vector2(cos(TAU * 0.4), sin(TAU * 0.4)) * separation,
		Vector2(cos(TAU * 0.6), sin(TAU * 0.6)) * separation,
		Vector2(cos(TAU * 0.8), sin(TAU * 0.8)) * separation,
	]


## ─── Rendering ───────────────────────────────────────────────────────────────

func _build_multimesh() -> void:
	var mesh := QuadMesh.new()
	mesh.size = Vector2(agent_size_px, agent_size_px)

	# Flat unshaded material — no lighting cost
	var mat := StandardMaterial3D.new()
	mat.albedo_color  = Color(0.35, 0.9, 1.0)   # bright cyan for clarity
	mat.shading_mode  = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.cull_mode     = BaseMaterial3D.CULL_DISABLED
	mat.vertex_color_use_as_albedo = true
	mesh.material     = mat

	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_2D
	mm.use_colors       = true
	mm.use_custom_data  = false
	mm.mesh             = mesh
	mm.instance_count   = agent_count
	mm.visible_instance_count = agent_count

	_mmi            = MultiMeshInstance2D.new()
	_mmi.multimesh  = mm
	_mmi.visible = not render_via_external_batch
	add_child(_mmi)


## ─── Agents ──────────────────────────────────────────────────────────────────

func _spawn_agents() -> void:
	var pw: float = (WORLD_W - 2) * CELL_SIZE
	var ph: float = (WORLD_H - 2) * CELL_SIZE
	var ox: float = CELL_SIZE
	var oy: float = CELL_SIZE

	positions.resize(agent_count)
	velocities.resize(agent_count)
	_speed_multipliers.resize(agent_count)
	_agent_colors.resize(agent_count)
	_noise_phase.resize(agent_count)
	_noise_rate.resize(agent_count)
	_visual_dir.resize(agent_count)
	_tile_counts.fill(0)

	var rng := RandomNumberGenerator.new()
	rng.randomize()

	for i in agent_count:
		var pos := Vector2(ox, oy)
		var placed := false
		for _attempt in 64:
			var candidate := Vector2(
				ox + rng.randf() * pw,
				oy + rng.randf() * ph
			)
			var cidx: int = _cell_index_from_world(candidate)
			if _walkable[cidx] and _tile_counts[cidx] < TILE_CAPACITY:
				pos = candidate
				_tile_counts[cidx] += 1
				placed = true
				break
		if not placed:
			for y in WORLD_H:
				for x in WORLD_W:
					var idx: int = y * WORLD_W + x
					if _walkable[idx] and _tile_counts[idx] < TILE_CAPACITY:
						pos = Vector2((x + 0.5) * CELL_SIZE, (y + 0.5) * CELL_SIZE)
						_tile_counts[idx] += 1
						placed = true
						break
				if placed:
					break
		positions[i]  = pos
		velocities[i] = Vector2.ZERO
		_speed_multipliers[i] = 1.0
		_agent_colors[i] = Color(0.35, 0.9, 1.0, 1.0)
		_reveal_around(pos, _agent_reveal_radius)
		_noise_phase[i] = rng.randf() * TAU
		_noise_rate[i] = rng.randf_range(0.6, 1.5)
		var jitter_angle: float = rng.randf() * TAU
		_visual_dir[i] = Vector2(cos(jitter_angle), sin(jitter_angle))
		_mmi.multimesh.set_instance_transform_2d(i, Transform2D(0.0, pos))
		_mmi.multimesh.set_instance_color(i, _agent_colors[i])

		# Buffer is fully refreshed in _flush_render each frame.


## ─── Per-frame ───────────────────────────────────────────────────────────────

func _process(delta: float) -> void:
	if infinite_mode:
		_step_infinite(delta)
		if render_via_external_batch:
			_mmi.multimesh.visible_instance_count = 0
		else:
			_flush_render_infinite()
		return

	if _flow_dirty:
		_flow_recompute_cooldown = maxf(0.0, _flow_recompute_cooldown - delta)
		if _flow_recompute_cooldown <= 0.0:
			_apply_pending_flow_target()

	_step(delta)
	if render_via_external_batch:
		_mmi.multimesh.visible_instance_count = 0
	else:
		_flush_render()


func _step(delta: float) -> void:
	var spd: float = tiles_per_second * float(CELL_SIZE)
	var t: float = Time.get_ticks_msec() * 0.001
	var next_counts := _tile_counts.duplicate()
	for i in agent_count:
		var speed_mult: float = 1.0
		if _speed_multipliers.size() == agent_count:
			speed_mult = maxf(0.0, _speed_multipliers[i])
		var pos: Vector2 = positions[i]
		var dir: Vector2 = _flow.sample(pos)
		var vel := Vector2.ZERO
		var to_target: Vector2 = _target_world - pos
		var dist: float = to_target.length()
		var settle_radius_px: float = settle_radius_tiles * float(CELL_SIZE)
		var settle_band_px: float = settle_band_tiles * float(CELL_SIZE)

		if dir.length_squared() > 0.01:
			# Ring settle behavior: near destination, steer toward a circular shell.
			var base_dir: Vector2 = dir.normalized()
			if dist < (settle_radius_px + settle_band_px) and dist > 0.001:
				var radial: Vector2 = to_target / dist
				var tangential: Vector2 = Vector2(-radial.y, radial.x)
				if (i & 1) == 0:
					tangential = -tangential
				var radial_error: float = dist - settle_radius_px
				var ring_dir: Vector2 = (tangential * 0.85 + radial * clampf(radial_error / maxf(1.0, settle_band_px), -1.0, 1.0) * 0.35).normalized()
				base_dir = base_dir.lerp(ring_dir, 0.9).normalized()

			# Add slight per-agent directional noise to break deterministic lane patterns.
			if direction_noise > 0.0:
				var phase: float = _noise_phase[i] + t * _noise_rate[i]
				var noise_dir := Vector2(cos(phase), sin(phase))
				base_dir = (base_dir + noise_dir * direction_noise).normalized()
			vel = base_dir * (spd * speed_mult)

		var proposed: Vector2 = pos + vel * delta
		var from_idx: int = _cell_index_from_world(pos)
		var to_idx: int = _cell_index_from_world(proposed)
		var ignore_capacity: bool = i < _ignore_tile_capacity.size() and _ignore_tile_capacity[i] != 0

		if to_idx != from_idx:
			if (not _walkable[to_idx]) or (not ignore_capacity and next_counts[to_idx] >= TILE_CAPACITY):
				proposed = pos
				vel = Vector2.ZERO
			else:
				next_counts[from_idx] -= 1
				if not ignore_capacity:
					next_counts[to_idx] += 1

		velocities[i] = vel
		positions[i] = proposed
		_reveal_around(proposed, _agent_reveal_radius)

	_tile_counts = next_counts


func _flush_render() -> void:
	_render_tile_counts.fill(0)
	var write_i: int = 0
	for i in agent_count:
		var idx: int = _cell_index_from_world(positions[i])
		var slot: int = mini(_render_tile_counts[idx], TILE_CAPACITY - 1)
		_render_tile_counts[idx] += 1
		var draw_pos: Vector2 = positions[i] + _slot_offsets[slot] + _visual_dir[i] * visual_jitter_px
		if cull_offscreen_render and _render_bounds_enabled:
			if draw_pos.x < _render_bounds_min.x or draw_pos.x > _render_bounds_max.x or draw_pos.y < _render_bounds_min.y or draw_pos.y > _render_bounds_max.y:
				continue
		_mmi.multimesh.set_instance_transform_2d(write_i, Transform2D(0.0, draw_pos))
		var color: Color = _agent_colors[i] if i < _agent_colors.size() else Color(0.35, 0.9, 1.0, 1.0)
		_mmi.multimesh.set_instance_color(write_i, color)
		write_i += 1
	_mmi.multimesh.visible_instance_count = write_i


## ─── Public API ──────────────────────────────────────────────────────────────

## Recompute flow field toward a new world-space target.
## Cost: O(grid_cells) — safe to call on click events, not every frame.
func set_target(world_pos: Vector2) -> void:
	_target_world = world_pos
	if infinite_mode:
		if _agent_targets.size() == agent_count:
			for i in agent_count:
				_agent_targets[i] = world_pos
		return
	_pending_flow_target_world = world_pos
	_flow_dirty = true
	_flow_recompute_cooldown = flow_recompute_debounce_sec
	if _auto_watchtower_enabled:
		place_watchtower(world_pos)


func get_agent_count() -> int:
	return agent_count


func set_agent_target(index: int, world_pos: Vector2) -> void:
	if index < 0 or index >= agent_count:
		return
	if _agent_targets.size() != agent_count:
		_agent_targets.resize(agent_count)
		for i in agent_count:
			_agent_targets[i] = _target_world
	_agent_targets[index] = world_pos


func set_agent_speed_multiplier(index: int, value: float) -> void:
	if index < 0 or index >= agent_count:
		return
	if _speed_multipliers.size() != agent_count:
		_speed_multipliers.resize(agent_count)
		for i in agent_count:
			_speed_multipliers[i] = 1.0
	_speed_multipliers[index] = maxf(0.0, value)


func set_agent_speed_multipliers(values: PackedFloat32Array) -> void:
	if values.size() != agent_count:
		return
	_speed_multipliers = values


func set_agent_colors(values: PackedColorArray) -> void:
	if values.size() != agent_count:
		return
	_agent_colors = values


func set_agent_targets(targets: PackedVector2Array) -> void:
	if targets.size() != agent_count:
		return
	_agent_targets = targets


func set_agent_capacity_ignore(values: PackedByteArray) -> void:
	if values.size() != agent_count:
		return
	_ignore_tile_capacity = values


func add_agents(count: int, spawn_center: Vector2 = Vector2.ZERO) -> void:
	if count <= 0 or not infinite_mode:
		return

	var old_count: int = agent_count
	agent_count += count

	positions.resize(agent_count)
	velocities.resize(agent_count)
	_speed_multipliers.resize(agent_count)
	_agent_colors.resize(agent_count)
	_noise_phase.resize(agent_count)
	_noise_rate.resize(agent_count)
	_visual_dir.resize(agent_count)
	_agent_targets.resize(agent_count)
	_ignore_tile_capacity.resize(agent_count)
	_ignore_tile_capacity.fill(0)
	_mmi.multimesh.instance_count = agent_count
	_mmi.multimesh.visible_instance_count = agent_count

	var rng := RandomNumberGenerator.new()
	rng.randomize()

	for i in range(old_count, agent_count):
		var pos := spawn_center + Vector2(
			rng.randf_range(-1.0, 1.0) * CELL_SIZE,
			rng.randf_range(-1.0, 1.0) * CELL_SIZE
		)
		positions[i] = pos
		velocities[i] = Vector2.ZERO
		_speed_multipliers[i] = 1.0
		_agent_colors[i] = Color(0.35, 0.9, 1.0, 1.0)
		_agent_targets[i] = _target_world
		_noise_phase[i] = rng.randf() * TAU
		_noise_rate[i] = rng.randf_range(0.6, 1.5)
		var jitter_angle: float = rng.randf() * TAU
		_visual_dir[i] = Vector2(cos(jitter_angle), sin(jitter_angle))
		_mmi.multimesh.set_instance_transform_2d(i, Transform2D(0.0, pos))


func remove_agents_by_indices(indices: PackedInt32Array) -> void:
	if indices.is_empty() or agent_count <= 0:
		return
	var unique_sorted: Array[int] = []
	var seen: Dictionary = {}
	for idx_v in indices:
		var idx: int = int(idx_v)
		if idx < 0 or idx >= agent_count:
			continue
		if seen.has(idx):
			continue
		seen[idx] = true
		unique_sorted.append(idx)
	if unique_sorted.is_empty():
		return
	unique_sorted.sort()
	for ri in range(unique_sorted.size() - 1, -1, -1):
		var idx: int = unique_sorted[ri]
		positions.remove_at(idx)
		velocities.remove_at(idx)
		if idx < _speed_multipliers.size():
			_speed_multipliers.remove_at(idx)
		if idx < _agent_colors.size():
			_agent_colors.remove_at(idx)
		if idx < _noise_phase.size():
			_noise_phase.remove_at(idx)
		if idx < _noise_rate.size():
			_noise_rate.remove_at(idx)
		if idx < _visual_dir.size():
			_visual_dir.remove_at(idx)
		if idx < _agent_targets.size():
			_agent_targets.remove_at(idx)
	agent_count = positions.size()
	_mmi.multimesh.instance_count = agent_count
	_mmi.multimesh.visible_instance_count = agent_count


func _cell_index_from_world(world_pos: Vector2) -> int:
	var x: int = clampi(int(world_pos.x / CELL_SIZE), 0, WORLD_W - 1)
	var y: int = clampi(int(world_pos.y / CELL_SIZE), 0, WORLD_H - 1)
	return y * WORLD_W + x


func _reveal_around(world_pos: Vector2, radius_tiles: int) -> void:
	var cx: int = clampi(int(world_pos.x / CELL_SIZE), 0, WORLD_W - 1)
	var cy: int = clampi(int(world_pos.y / CELL_SIZE), 0, WORLD_H - 1)
	for oy in range(-radius_tiles, radius_tiles + 1):
		for ox in range(-radius_tiles, radius_tiles + 1):
			var x: int = cx + ox
			var y: int = cy + oy
			if x < 0 or x >= WORLD_W or y < 0 or y >= WORLD_H:
				continue
			if ox * ox + oy * oy <= radius_tiles * radius_tiles:
				_explored[y * WORLD_W + x] = 1


func get_world_size() -> Vector2i:
	return Vector2i(WORLD_W, WORLD_H)


func get_walkable_cells() -> PackedByteArray:
	return _walkable


func get_explored_cells() -> PackedByteArray:
	return _explored


func get_agent_positions() -> PackedVector2Array:
	return positions


func get_agent_targets() -> PackedVector2Array:
	if _agent_targets.size() == agent_count:
		return _agent_targets
	var targets := PackedVector2Array()
	targets.resize(agent_count)
	for i in agent_count:
		targets[i] = _target_world
	return targets


func get_target_world() -> Vector2:
	return _target_world


func set_agent_reveal_radius(radius_tiles: int) -> void:
	_agent_reveal_radius = maxi(1, radius_tiles)


func get_agent_reveal_radius() -> int:
	return _agent_reveal_radius


func set_watchtower_radius(radius_tiles: int) -> void:
	_watchtower_radius = maxi(1, radius_tiles)
	for tile in _watchtowers:
		_reveal_around(_tile_center_world(tile), _watchtower_radius)


func get_watchtower_radius() -> int:
	return _watchtower_radius


func enable_auto_watchtowers(max_watchtowers: int = 12) -> void:
	_auto_watchtower_enabled = true
	_max_watchtowers = maxi(1, max_watchtowers)


func is_auto_watchtower_enabled() -> bool:
	return _auto_watchtower_enabled


func place_watchtower(world_pos: Vector2) -> void:
	var x: int = clampi(int(world_pos.x / CELL_SIZE), 0, WORLD_W - 1)
	var y: int = clampi(int(world_pos.y / CELL_SIZE), 0, WORLD_H - 1)
	_add_watchtower_tile(Vector2i(x, y))


func get_watchtower_tiles() -> Array[Vector2i]:
	return _watchtowers


func _add_watchtower_tile(tile: Vector2i) -> void:
	if tile.x <= 0 or tile.x >= WORLD_W - 1 or tile.y <= 0 or tile.y >= WORLD_H - 1:
		return
	if _watchtowers.has(tile):
		return
	_watchtowers.append(tile)
	if _watchtowers.size() > _max_watchtowers:
		_watchtowers.remove_at(0)
	_reveal_around(_tile_center_world(tile), _watchtower_radius)


func _tile_center_world(tile: Vector2i) -> Vector2:
	return Vector2((tile.x + 0.5) * CELL_SIZE, (tile.y + 0.5) * CELL_SIZE)


func _spawn_agents_infinite() -> void:
	positions.resize(agent_count)
	velocities.resize(agent_count)
	_speed_multipliers.resize(agent_count)
	_agent_colors.resize(agent_count)
	_agent_targets.resize(agent_count)
	_noise_phase.resize(agent_count)
	_noise_rate.resize(agent_count)
	_visual_dir.resize(agent_count)
	var rng := RandomNumberGenerator.new()
	rng.randomize()

	for i in agent_count:
		var pos := Vector2(
			rng.randf_range(-8.0, 8.0) * CELL_SIZE,
			rng.randf_range(-8.0, 8.0) * CELL_SIZE
		)
		positions[i] = pos
		velocities[i] = Vector2.ZERO
		_speed_multipliers[i] = 1.0
		_agent_colors[i] = Color(0.35, 0.9, 1.0, 1.0)
		_agent_targets[i] = _target_world
		_noise_phase[i] = rng.randf() * TAU
		_noise_rate[i] = rng.randf_range(0.6, 1.5)
		var jitter_angle: float = rng.randf() * TAU
		_visual_dir[i] = Vector2(cos(jitter_angle), sin(jitter_angle))
		_mmi.multimesh.set_instance_transform_2d(i, Transform2D(0.0, pos))
	_mmi.multimesh.visible_instance_count = agent_count


func _step_infinite(delta: float) -> void:
	var spd: float = tiles_per_second * float(CELL_SIZE)
	var t: float = Time.get_ticks_msec() * 0.001
	for i in agent_count:
		var speed_mult: float = 1.0
		if _speed_multipliers.size() == agent_count:
			speed_mult = maxf(0.0, _speed_multipliers[i])
		var pos: Vector2 = positions[i]
		var target: Vector2 = _target_world
		if _agent_targets.size() == agent_count:
			target = _agent_targets[i]
		var to_target: Vector2 = target - pos
		var dist: float = to_target.length()
		var vel := Vector2.ZERO

		if dist > 3.0:
			var base_dir: Vector2 = to_target / dist
			if direction_noise > 0.0:
				var phase: float = _noise_phase[i] + t * _noise_rate[i]
				var noise_dir := Vector2(cos(phase), sin(phase))
				base_dir = (base_dir + noise_dir * direction_noise * 0.5).normalized()
			vel = base_dir * (spd * speed_mult)

		velocities[i] = vel
		positions[i] = pos + vel * delta


func _flush_render_infinite() -> void:
	var write_i: int = 0
	for i in agent_count:
		var draw_pos: Vector2 = positions[i] + _visual_dir[i] * visual_jitter_px
		if cull_offscreen_render and _render_bounds_enabled:
			if draw_pos.x < _render_bounds_min.x or draw_pos.x > _render_bounds_max.x or draw_pos.y < _render_bounds_min.y or draw_pos.y > _render_bounds_max.y:
				continue
		_mmi.multimesh.set_instance_transform_2d(write_i, Transform2D(0.0, draw_pos))
		var color: Color = _agent_colors[i] if i < _agent_colors.size() else Color(0.35, 0.9, 1.0, 1.0)
		_mmi.multimesh.set_instance_color(write_i, color)
		write_i += 1
	_mmi.multimesh.visible_instance_count = write_i


func set_render_bounds(view_min: Vector2, view_max: Vector2) -> void:
	_render_bounds_enabled = true
	_render_bounds_min = view_min - Vector2.ONE * render_cull_margin_px
	_render_bounds_max = view_max + Vector2.ONE * render_cull_margin_px


func clear_render_bounds() -> void:
	_render_bounds_enabled = false


func set_external_batch_render_enabled(enabled: bool) -> void:
	render_via_external_batch = enabled
	if _mmi != null:
		_mmi.visible = not enabled
		if enabled:
			_mmi.multimesh.visible_instance_count = 0


func append_agents_to_sprite_batch(batch_system: RenderBatchSystem, sprite_size_px: float = -1.0, _sprite_id: int = 0) -> void:
	if batch_system == null:
		return
	var size_px: float = sprite_size_px if sprite_size_px > 0.0 else agent_size_px
	if size_px <= 0.01 or agent_count <= 0:
		return
	if infinite_mode:
		for i in agent_count:
			var draw_pos: Vector2 = positions[i] + _visual_dir[i] * visual_jitter_px
			if cull_offscreen_render and _render_bounds_enabled:
				if draw_pos.x < _render_bounds_min.x or draw_pos.x > _render_bounds_max.x or draw_pos.y < _render_bounds_min.y or draw_pos.y > _render_bounds_max.y:
					continue
			var color: Color = _agent_colors[i] if i < _agent_colors.size() else Color(0.35, 0.9, 1.0, 1.0)
			batch_system.append_sprite(draw_pos, size_px, color)
		return

	if _render_tile_counts.size() != _tile_counts.size():
		_render_tile_counts.resize(_tile_counts.size())
	_render_tile_counts.fill(0)
	for i in agent_count:
		var idx: int = _cell_index_from_world(positions[i])
		var slot: int = mini(_render_tile_counts[idx], TILE_CAPACITY - 1)
		_render_tile_counts[idx] += 1
		var draw_pos: Vector2 = positions[i] + _slot_offsets[slot] + _visual_dir[i] * visual_jitter_px
		if cull_offscreen_render and _render_bounds_enabled:
			if draw_pos.x < _render_bounds_min.x or draw_pos.x > _render_bounds_max.x or draw_pos.y < _render_bounds_min.y or draw_pos.y > _render_bounds_max.y:
				continue
		var color: Color = _agent_colors[i] if i < _agent_colors.size() else Color(0.35, 0.9, 1.0, 1.0)
		batch_system.append_sprite(draw_pos, size_px, color)


func _apply_pending_flow_target() -> void:
	_flow_dirty = false
	var target_cell: Vector2i = _world_to_cell(_pending_flow_target_world)
	if target_cell == _last_flow_target_cell:
		return
	_last_flow_target_cell = target_cell
	_flow.compute(_pending_flow_target_world, _walkable)


func _world_to_cell(world_pos: Vector2) -> Vector2i:
	return Vector2i(
		clampi(int(world_pos.x / CELL_SIZE), 0, WORLD_W - 1),
		clampi(int(world_pos.y / CELL_SIZE), 0, WORLD_H - 1)
	)
