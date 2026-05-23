class_name RenderBatchSystem
extends RefCounted


const SETTLER_STATUS_MARKER_SIZE_PX: float = 3.6
const SETTLER_STATUS_MARKER_OFFSET_Y: float = -7.0
const DEBUG_PLAIN_SQUARES_ONLY: bool = true

var _positions: PackedVector2Array = PackedVector2Array()
var _scales: PackedVector2Array = PackedVector2Array()
var _colors: PackedColorArray = PackedColorArray()
var _texture: Texture2D
var _mesh: QuadMesh
var _multimesh: MultiMesh = MultiMesh.new()
var _batch_ready: bool = false
var _capacity: int = 0


func begin_frame() -> void:
	_positions.clear()
	_scales.clear()
	_colors.clear()


func sprite_count() -> int:
	return _positions.size()


func append_sprite(pos: Vector2, size_px: float, col: Color) -> void:
	if col.a <= 0.001 or size_px <= 0.01:
		return
	_positions.append(pos)
	_scales.append(Vector2(size_px, size_px))
	_colors.append(col)


func append_sprite_rect(pos: Vector2, size_xy: Vector2, col: Color) -> void:
	if col.a <= 0.001 or size_xy.x <= 0.01 or size_xy.y <= 0.01:
		return
	_positions.append(pos)
	_scales.append(size_xy)
	_colors.append(col)


func queue_sprite(pos: Vector2, size_px: float, col: Color, _sprite_id: int = 0) -> void:
	append_sprite(pos, size_px, col)


func queue_particles(particles: Array[Dictionary], _sprite_id: int = 0) -> void:
	for p in particles:
		var alpha: float = 1.0 - clampf(float(p["t"]) / float(p["dur"]), 0.0, 1.0)
		var col: Color = p["color"]
		var size: float = float(p["size"])
		var pos: Vector2 = p["pos"]
		append_sprite(pos, size, Color(col.r, col.g, col.b, alpha))


func queue_settler_indicators(
	agents: PackedVector2Array,
	active_indices: PackedInt32Array,
	think_state: PackedInt32Array,
	min_x: float,
	max_x: float,
	min_y: float,
	max_y: float,
	think_thinking: int,
	_sprite_diamond: int = 0
) -> void:
	for i in active_indices:
		if i < 0 or i >= agents.size():
			continue
		var pos: Vector2 = agents[i]
		if pos.x < min_x or pos.x > max_x or pos.y < min_y or pos.y > max_y:
			continue
		if think_state[i] == think_thinking:
			append_sprite(
				pos + Vector2(0.0, SETTLER_STATUS_MARKER_OFFSET_Y),
				SETTLER_STATUS_MARKER_SIZE_PX,
				Color(1.0, 0.86, 0.22, 0.92)
			)


func queue_wildlife(
	wildlife: Array,
	min_x: float,
	max_x: float,
	min_y: float,
	max_y: float,
	cb_is_explored: Callable,
	cb_world_to_tile: Callable,
	animal_deer: int,
	animal_wolf: int,
	animal_bear: int
) -> void:
	if wildlife.is_empty():
		return
	for w in wildlife:
		var pos: Vector2 = w["pos"]
		if pos.x < min_x or pos.x > max_x or pos.y < min_y or pos.y > max_y:
			continue
		var tile: Vector2i = cb_world_to_tile.call(pos)
		if not bool(cb_is_explored.call(tile)):
			continue
		var typ: int = int(w["type"])
		var hp: float = float(w["hp"])
		var max_hp: float = float(w["max_hp"])
		match typ:
			animal_deer:
				append_sprite(pos, 9.0, Color(0.82, 0.68, 0.42, 0.95))
			animal_wolf:
				append_sprite(pos, 10.0, Color(0.55, 0.55, 0.6, 0.95))
			animal_bear:
				append_sprite(pos, 16.0, Color(0.52, 0.32, 0.14, 0.95))
			_:
				append_sprite(pos, 8.0, Color(0.7, 0.7, 0.7, 0.9))
		if max_hp > 0.0 and hp < max_hp:
			var bar_w: float = 14.0 if typ == animal_bear else 10.0
			var bar_y: float = pos.y - (14.0 if typ == animal_bear else 10.0)
			var hp_ratio: float = clampf(hp / max_hp, 0.0, 1.0)
			append_sprite_rect(Vector2(pos.x, bar_y + 1.0), Vector2(bar_w, 2.0), Color(0.3, 0.1, 0.1, 0.8))
			if hp_ratio > 0.01:
				var fill_w: float = bar_w * hp_ratio
				append_sprite_rect(
					Vector2(pos.x - bar_w * 0.5 + fill_w * 0.5, bar_y + 1.0),
					Vector2(fill_w, 2.0),
					Color(0.85, 0.25, 0.25, 0.9)
				)


func queue_visible_resources_fast(
	cmin: Vector2i,
	cmax: Vector2i,
	remaining: int,
	food_chunk_map: Dictionary,
	tree_chunk_map: Dictionary,
	stone_chunk_map: Dictionary,
	metal_chunk_map: Dictionary,
	resource_type_cache: Dictionary,
	resource_remaining_id: Dictionary,
	tile_size: float,
	min_x: float,
	max_x: float,
	min_y: float,
	max_y: float,
	cb_world_chunk_key: Callable,
	cb_resource_initial_amount: Callable,
	res_tree: int,
	res_stone: int,
	res_metal: int,
	res_apple: int,
	res_berry_blue: int,
	res_berry_rasp: int,
	res_berry_black: int
) -> int:
	if remaining <= 0 or not cb_world_chunk_key.is_valid():
		return remaining
	for cy in range(cmin.y, cmax.y + 1):
		for cx in range(cmin.x, cmax.x + 1):
			if remaining <= 0:
				return 0
			var key: String = String(cb_world_chunk_key.call(Vector2i(cx, cy)))
			remaining = _queue_food_chunk_fast(
				key,
				food_chunk_map,
				remaining,
				resource_type_cache,
				resource_remaining_id,
				tile_size,
				min_x,
				max_x,
				min_y,
				max_y,
				cb_resource_initial_amount,
				res_apple,
				res_berry_blue,
				res_berry_rasp,
				res_berry_black
			)
			if remaining <= 0:
				return 0
			remaining = _queue_fixed_chunk_fast(
				key,
				tree_chunk_map,
				remaining,
				resource_remaining_id,
				tile_size,
				7.2,
				Color(0.12, 0.56, 0.2, 0.95),
				min_x,
				max_x,
				min_y,
				max_y,
				res_tree,
				cb_resource_initial_amount
			)
			if remaining <= 0:
				return 0
			remaining = _queue_fixed_chunk_fast(
				key,
				stone_chunk_map,
				remaining,
				resource_remaining_id,
				tile_size,
				8.2,
				Color(0.58, 0.6, 0.64, 0.95),
				min_x,
				max_x,
				min_y,
				max_y,
				res_stone,
				cb_resource_initial_amount
			)
			if remaining <= 0:
				return 0
			remaining = _queue_fixed_chunk_fast(
				key,
				metal_chunk_map,
				remaining,
				resource_remaining_id,
				tile_size,
				8.2,
				Color(0.34, 0.36, 0.4, 0.98),
				min_x,
				max_x,
				min_y,
				max_y,
				res_metal,
				cb_resource_initial_amount
			)
	return remaining


func _queue_food_chunk_fast(
	key: String,
	chunk_map: Dictionary,
	remaining: int,
	resource_type_cache: Dictionary,
	resource_remaining_id: Dictionary,
	tile_size: float,
	min_x: float,
	max_x: float,
	min_y: float,
	max_y: float,
	cb_resource_initial_amount: Callable,
	res_apple: int,
	res_berry_blue: int,
	res_berry_rasp: int,
	res_berry_black: int
) -> int:
	if remaining <= 0 or not chunk_map.has(key):
		return remaining
	var tiles: Array = chunk_map[key]
	for tile_v in tiles:
		if remaining <= 0:
			break
		var tile: Vector2i = tile_v
		var center := Vector2((tile.x + 0.5) * tile_size, (tile.y + 0.5) * tile_size)
		if center.x < min_x or center.x > max_x or center.y < min_y or center.y > max_y:
			continue
		var id: int = (int(tile.x) << 32) ^ (int(tile.y) & 0xffffffff)
		if not resource_type_cache.has(id):
			continue
		var typ: int = int(resource_type_cache[id])
		var col: Color
		var size_px: float
		match typ:
			res_apple:
				col = Color(0.18, 0.6, 0.2, 0.95)
				size_px = 6.4
			res_berry_blue:
				col = Color(0.24, 0.46, 0.84, 0.95)
				size_px = 5.6
			res_berry_rasp:
				col = Color(0.84, 0.24, 0.36, 0.95)
				size_px = 5.6
			res_berry_black:
				col = Color(0.34, 0.16, 0.42, 0.95)
				size_px = 5.6
			_:
				continue
		var amount: float = float(resource_remaining_id[id]) if resource_remaining_id.has(id) else float(cb_resource_initial_amount.call(tile, typ))
		if amount <= 0.0:
			continue
		append_sprite(center, size_px, col)
		remaining -= 1
	return remaining


func _queue_fixed_chunk_fast(
	key: String,
	chunk_map: Dictionary,
	remaining: int,
	resource_remaining_id: Dictionary,
	tile_size: float,
	size_px: float,
	col: Color,
	min_x: float,
	max_x: float,
	min_y: float,
	max_y: float,
	res_type: int,
	cb_resource_initial_amount: Callable
) -> int:
	if remaining <= 0 or not chunk_map.has(key):
		return remaining
	var tiles: Array = chunk_map[key]
	for tile_v in tiles:
		if remaining <= 0:
			break
		var tile: Vector2i = tile_v
		var center := Vector2((tile.x + 0.5) * tile_size, (tile.y + 0.5) * tile_size)
		if center.x < min_x or center.x > max_x or center.y < min_y or center.y > max_y:
			continue
		var id: int = (int(tile.x) << 32) ^ (int(tile.y) & 0xffffffff)
		var amount: float = float(resource_remaining_id[id]) if resource_remaining_id.has(id) else float(cb_resource_initial_amount.call(tile, res_type))
		if amount <= 0.0:
			continue
		append_sprite(center, size_px, col)
		remaining -= 1
	return remaining


func draw_to(canvas_item: CanvasItem) -> void:
	_prepare_batch()
	if _texture == null and not DEBUG_PLAIN_SQUARES_ONLY:
		return
	if _multimesh.visible_instance_count <= 0:
		return
	canvas_item.draw_multimesh(_multimesh, _texture)


func _prepare_batch() -> void:
	var count: int = _positions.size()
	if count <= 0:
		if _batch_ready:
			_multimesh.instance_count = 0
			_multimesh.visible_instance_count = 0
		return
	_ensure_batch_resources()
	if count > _capacity:
		_capacity = maxi(count, _capacity + maxi(256, count / 4))
		_multimesh.instance_count = _capacity
	_multimesh.visible_instance_count = count
	for i in count:
		var scale: Vector2 = _scales[i]
		_multimesh.set_instance_transform_2d(i, Transform2D(Vector2(scale.x, 0.0), Vector2(0.0, scale.y), _positions[i]))
		_multimesh.set_instance_color(i, _colors[i])


func _ensure_batch_resources() -> void:
	if _batch_ready:
		return
	if _mesh == null:
		_mesh = QuadMesh.new()
		_mesh.size = Vector2.ONE
		var mat := ShaderMaterial.new()
		var shader := Shader.new()
		shader.code = "shader_type canvas_item;\nvoid fragment() {\n\tCOLOR = vec4(1.0, 1.0, 1.0, 1.0) * COLOR;\n}"
		mat.shader = shader
		_mesh.material = mat
	var white_img: Image = Image.create(1, 1, false, Image.FORMAT_RGBA8)
	white_img.fill(Color(1.0, 1.0, 1.0, 1.0))
	_texture = ImageTexture.create_from_image(white_img)
	_multimesh.mesh = _mesh
	_multimesh.instance_count = 0
	_multimesh.visible_instance_count = 0
	_multimesh.transform_format = MultiMesh.TRANSFORM_2D
	_multimesh.use_colors = true
	_multimesh.use_custom_data = false
	_batch_ready = true
	_capacity = 0
