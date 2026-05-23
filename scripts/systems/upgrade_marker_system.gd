class_name UpgradeMarkerSystem
extends RefCounted


var _visual_tiles: Dictionary = {}


func draw_markers(
	canvas_item: CanvasItem,
	upgrade_ranks: Dictionary,
	camp_tile: Vector2i,
	house_tiles: Array[Vector2i],
	sawmill_tiles: Array[Vector2i],
	quarry_tiles: Array[Vector2i],
	workshop_tiles: Array[Vector2i],
	storehouse_tiles: Array[Vector2i],
	armory_tiles: Array[Vector2i],
	scout_lodge_tiles: Array[Vector2i],
	outpost_tiles: Array[Vector2i],
	camera_zoom_x: float,
	cb_tile_key: Callable,
	cb_tile_center: Callable,
	cb_upgrade_color_for: Callable
) -> void:
	if not cb_tile_key.is_valid() or not cb_tile_center.is_valid() or not cb_upgrade_color_for.is_valid():
		return
	var font: Font = ThemeDB.fallback_font
	var scale: float = clampf(camera_zoom_x, 0.8, 2.2)
	for id_v in upgrade_ranks.keys():
		var id: String = String(id_v)
		var rank: int = int(upgrade_ranks[id])
		if rank <= 0:
			continue
		var tile: Vector2i = _ensure_visual_tile(
			id,
			camp_tile,
			house_tiles,
			sawmill_tiles,
			quarry_tiles,
			workshop_tiles,
			storehouse_tiles,
			armory_tiles,
			scout_lodge_tiles,
			outpost_tiles,
			cb_tile_key
		)
		var center: Vector2 = cb_tile_center.call(tile)
		var col: Color = cb_upgrade_color_for.call(id)
		var category: String = _category_for(id)
		canvas_item.draw_arc(center, 5.4 * scale, 0.0, TAU, 20, Color(col.r, col.g, col.b, 0.55), 1.1 * scale)
		_draw_category_icon(canvas_item, center, col, category, 0.95, scale)
		canvas_item.draw_string(
			font,
			center + Vector2(-4.0, -6.0) * scale,
			str(rank),
			HORIZONTAL_ALIGNMENT_LEFT,
			-1.0,
			int(round(10.0 * scale)),
			Color(1.0, 1.0, 1.0, 0.95)
		)


func _ensure_visual_tile(
	id: String,
	camp_tile: Vector2i,
	house_tiles: Array[Vector2i],
	sawmill_tiles: Array[Vector2i],
	quarry_tiles: Array[Vector2i],
	workshop_tiles: Array[Vector2i],
	storehouse_tiles: Array[Vector2i],
	armory_tiles: Array[Vector2i],
	scout_lodge_tiles: Array[Vector2i],
	outpost_tiles: Array[Vector2i],
	cb_tile_key: Callable
) -> Vector2i:
	if _visual_tiles.has(id):
		return _visual_tiles[id]

	var occupied: Dictionary = {}
	occupied[String(cb_tile_key.call(camp_tile))] = true
	for t in house_tiles:
		occupied[String(cb_tile_key.call(t))] = true
	for t in sawmill_tiles:
		occupied[String(cb_tile_key.call(t))] = true
	for t in quarry_tiles:
		occupied[String(cb_tile_key.call(t))] = true
	for t in workshop_tiles:
		occupied[String(cb_tile_key.call(t))] = true
	for t in storehouse_tiles:
		occupied[String(cb_tile_key.call(t))] = true
	for t in armory_tiles:
		occupied[String(cb_tile_key.call(t))] = true
	for t in scout_lodge_tiles:
		occupied[String(cb_tile_key.call(t))] = true
	for t in outpost_tiles:
		occupied[String(cb_tile_key.call(t))] = true
	for v in _visual_tiles.values():
		occupied[String(cb_tile_key.call(v))] = true

	var base_hash: int = abs(id.hash())
	for attempt in 48:
		var ring: int = 6 + int(floor(attempt / 12.0))
		var angle_step: float = TAU / 12.0
		var slot: int = (base_hash + attempt) % 12
		var a: float = slot * angle_step
		var tile := Vector2i(
			camp_tile.x + int(round(cos(a) * ring)),
			camp_tile.y + int(round(sin(a) * ring))
		)
		var key: String = String(cb_tile_key.call(tile))
		if occupied.has(key):
			continue
		_visual_tiles[id] = tile
		return tile

	var fallback := Vector2i(camp_tile.x + 6 + _visual_tiles.size(), camp_tile.y)
	_visual_tiles[id] = fallback
	return fallback


func _category_for(id: String) -> String:
	if id.begins_with("vol"):
		return "volume"
	if id.begins_with("eff"):
		return "efficiency"
	if id.begins_with("spec"):
		return "specialization"
	if id.begins_with("vision"):
		return "vision"
	if id.begins_with("scout"):
		return "scouting"
	if id.begins_with("def"):
		return "defense"
	if id.begins_with("cmb"):
		return "combat"
	return "misc"


func _draw_category_icon(canvas_item: CanvasItem, center: Vector2, col: Color, category: String, alpha: float = 1.0, scale: float = 1.0) -> void:
	var c := Color(col.r, col.g, col.b, alpha)
	var lw: float = 1.2 * scale
	match category:
		"volume":
			canvas_item.draw_line(center + Vector2(-3.0, -3.0) * scale, center + Vector2(-3.0, 3.0) * scale, c, lw)
			canvas_item.draw_line(center + Vector2(0.0, -4.0) * scale, center + Vector2(0.0, 4.0) * scale, c, lw)
			canvas_item.draw_line(center + Vector2(3.0, -2.0) * scale, center + Vector2(3.0, 2.0) * scale, c, lw)
		"efficiency":
			canvas_item.draw_line(center + Vector2(-4.0, -3.0) * scale, center + Vector2(-1.0, 0.0) * scale, c, 1.4 * scale)
			canvas_item.draw_line(center + Vector2(-1.0, 0.0) * scale, center + Vector2(-4.0, 3.0) * scale, c, 1.4 * scale)
			canvas_item.draw_line(center + Vector2(0.0, -3.0) * scale, center + Vector2(3.0, 0.0) * scale, c, 1.4 * scale)
			canvas_item.draw_line(center + Vector2(3.0, 0.0) * scale, center + Vector2(0.0, 3.0) * scale, c, 1.4 * scale)
		"specialization":
			var p0 := center + Vector2(0.0, -4.0) * scale
			var p1 := center + Vector2(4.0, 0.0) * scale
			var p2 := center + Vector2(0.0, 4.0) * scale
			var p3 := center + Vector2(-4.0, 0.0) * scale
			canvas_item.draw_line(p0, p1, c, lw)
			canvas_item.draw_line(p1, p2, c, lw)
			canvas_item.draw_line(p2, p3, c, lw)
			canvas_item.draw_line(p3, p0, c, lw)
			canvas_item.draw_circle(center, 1.0 * scale, c)
		"vision":
			canvas_item.draw_line(center + Vector2(-4.0, 0.0) * scale, center + Vector2(0.0, -2.5) * scale, c, lw)
			canvas_item.draw_line(center + Vector2(0.0, -2.5) * scale, center + Vector2(4.0, 0.0) * scale, c, lw)
			canvas_item.draw_line(center + Vector2(4.0, 0.0) * scale, center + Vector2(0.0, 2.5) * scale, c, lw)
			canvas_item.draw_line(center + Vector2(0.0, 2.5) * scale, center + Vector2(-4.0, 0.0) * scale, c, lw)
			canvas_item.draw_circle(center, 1.0 * scale, c)
		"scouting":
			var s0 := center + Vector2(0.0, -4.0) * scale
			var s1 := center + Vector2(4.0, 3.0) * scale
			var s2 := center + Vector2(-4.0, 3.0) * scale
			canvas_item.draw_line(s0, s1, c, lw)
			canvas_item.draw_line(s1, s2, c, lw)
			canvas_item.draw_line(s2, s0, c, lw)
			canvas_item.draw_circle(center + Vector2(0.0, -1.0) * scale, 1.0 * scale, c)
		"defense":
			var d0 := center + Vector2(0.0, -4.0) * scale
			var d1 := center + Vector2(4.0, -1.0) * scale
			var d2 := center + Vector2(2.0, 3.5) * scale
			var d3 := center + Vector2(-2.0, 3.5) * scale
			var d4 := center + Vector2(-4.0, -1.0) * scale
			canvas_item.draw_line(d0, d1, c, lw)
			canvas_item.draw_line(d1, d2, c, lw)
			canvas_item.draw_line(d2, d3, c, lw)
			canvas_item.draw_line(d3, d4, c, lw)
			canvas_item.draw_line(d4, d0, c, lw)
		"combat":
			canvas_item.draw_line(center + Vector2(-3.5, -3.5) * scale, center + Vector2(3.5, 3.5) * scale, c, 1.4 * scale)
			canvas_item.draw_line(center + Vector2(3.5, -3.5) * scale, center + Vector2(-3.5, 3.5) * scale, c, 1.4 * scale)
			canvas_item.draw_circle(center, 1.0 * scale, c)
		_:
			canvas_item.draw_rect(Rect2(center.x - 3.0 * scale, center.y - 3.0 * scale, 6.0 * scale, 6.0 * scale), c, false, lw)
