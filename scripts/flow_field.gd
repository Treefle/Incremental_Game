class_name FlowField
extends RefCounted

## Flow field pathfinding for large agent crowds.
##
## Architecture:
##   - ONE BFS pass from target → generates a cost field over the grid.
##   - Each cell stores the best direction toward the target (gradient descent on cost).
##   - Agents sample via bilinear interpolation → smooth movement, no per-agent A*.
##   - Compute cost: O(grid_cells). Sample cost: O(1) per agent per frame.
##   - Memory: 2 × PackedArray → ~12 bytes/cell. 128×128 ≈ 192 KB total.
##
## Designed for 10,000 concurrent agents sharing a flow field.

var width:     int
var height:    int
var cell_size: int
var cache_max_entries: int = 64

## Direction per cell pointing toward the target (cardinal grid units, normalized).
var vectors: PackedVector2Array

var _cost: PackedFloat32Array
var _cache_vectors: Dictionary = {}
var _cache_order: Array[String] = []
var _walkable_revision: int = 0
var _cache_hits: int = 0
var _cache_misses: int = 0


## Call once to size internal arrays.
func setup(w: int, h: int, cs: int) -> void:
	width     = w
	height    = h
	cell_size = cs
	vectors.resize(w * h)
	_cost.resize(w * h)
	_clear_cache()


func set_cache_capacity(capacity: int) -> void:
	cache_max_entries = maxi(1, capacity)
	while _cache_order.size() > cache_max_entries:
		var oldest: String = _cache_order[0]
		_cache_order.remove_at(0)
		_cache_vectors.erase(oldest)


func notify_walkable_changed() -> void:
	_walkable_revision += 1
	_clear_cache()


func get_cache_stats() -> Dictionary:
	return {
		"hits": _cache_hits,
		"misses": _cache_misses,
		"entries": _cache_order.size(),
		"revision": _walkable_revision,
	}


## Recompute flow field from a world-space target position.
## walkable: PackedByteArray of size (width*height), 1 = passable, 0 = blocked.
func compute(target_world: Vector2, walkable: PackedByteArray) -> void:
	var tx := clampi(int(target_world.x / cell_size), 0, width - 1)
	var ty := clampi(int(target_world.y / cell_size), 0, height - 1)
	var key: String = "%d:%d:%d" % [_walkable_revision, tx, ty]
	if _cache_vectors.has(key):
		_cache_hits += 1
		_touch_cache_key(key)
		vectors = _cache_vectors[key]
		return

	_cache_misses += 1
	_bfs(ty * width + tx, walkable)
	_cache_vectors[key] = vectors.duplicate()
	_touch_cache_key(key)
	if _cache_order.size() > cache_max_entries:
		var oldest: String = _cache_order[0]
		_cache_order.remove_at(0)
		_cache_vectors.erase(oldest)


## BFS (uniform cost = 1 per cardinal step) from target outward.
## Each cell is enqueued at most once → queue bounded by grid size, no realloc.
func _bfs(target_idx: int, walkable: PackedByteArray) -> void:
	var total := width * height

	_cost.fill(1e30)
	_cost[target_idx] = 0.0

	# Pre-sized ring buffer; each of the `total` cells enters at most once.
	var q  := PackedInt32Array()
	q.resize(total)
	var qr := 0
	var qw := 0
	q[qw] = target_idx
	qw   += 1

	var w := width
	var h := height

	while qr < qw:
		var ci: int   = q[qr]; qr += 1
		var nc: float = _cost[ci] + 1.0
		var cx: int   = ci % w
		var cy: int   = ci / w

		if cx > 0:
			var ni: int = ci - 1
			if walkable[ni] and _cost[ni] > nc:
				_cost[ni] = nc; q[qw] = ni; qw += 1
		if cx < w - 1:
			var ni: int = ci + 1
			if walkable[ni] and _cost[ni] > nc:
				_cost[ni] = nc; q[qw] = ni; qw += 1
		if cy > 0:
			var ni: int = ci - w
			if walkable[ni] and _cost[ni] > nc:
				_cost[ni] = nc; q[qw] = ni; qw += 1
		if cy < h - 1:
			var ni: int = ci + w
			if walkable[ni] and _cost[ni] > nc:
				_cost[ni] = nc; q[qw] = ni; qw += 1

	# Derive one gradient vector per cell (cheapest cardinal neighbor wins).
	for i in total:
		if _cost[i] >= 1e29:
			vectors[i] = Vector2.ZERO
			continue

		var x:    int     = i % w
		var y:    int     = i / w
		var best: Vector2 = Vector2.ZERO
		var bc:   float   = _cost[i]

		if x > 0         and _cost[i - 1] < bc: bc = _cost[i - 1]; best = Vector2(-1.0,  0.0)
		if x < w - 1     and _cost[i + 1] < bc: bc = _cost[i + 1]; best = Vector2( 1.0,  0.0)
		if y > 0         and _cost[i - w] < bc: bc = _cost[i - w]; best = Vector2( 0.0, -1.0)
		if y < h - 1     and _cost[i + w] < bc: bc = _cost[i + w]; best = Vector2( 0.0,  1.0)

		vectors[i] = best


## Bilinear sample at a world-space position.
## Returns a smooth direction vector blended from the four surrounding cells.
## Smoothness eliminates the staircase motion that pure cardinal sampling produces.
func sample(world_pos: Vector2) -> Vector2:
	var fx: float = world_pos.x / cell_size - 0.5
	var fy: float = world_pos.y / cell_size - 0.5
	var x0: int   = int(fx)
	var y0: int   = int(fy)
	var tx: float = fx - float(x0)
	var ty: float = fy - float(y0)

	return (
		_cell(x0,     y0    ).lerp(_cell(x0 + 1, y0    ), tx)
		.lerp(
		_cell(x0,     y0 + 1).lerp(_cell(x0 + 1, y0 + 1), tx),
		ty)
	)


func _cell(x: int, y: int) -> Vector2:
	if x < 0 or x >= width or y < 0 or y >= height:
		return Vector2.ZERO
	return vectors[y * width + x]


func _touch_cache_key(key: String) -> void:
	var existing_idx: int = _cache_order.find(key)
	if existing_idx >= 0:
		_cache_order.remove_at(existing_idx)
	_cache_order.append(key)


func _clear_cache() -> void:
	_cache_vectors.clear()
	_cache_order.clear()
