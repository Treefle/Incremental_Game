class_name FloatingTextSystem
extends RefCounted


var _items: Array[Dictionary] = []


func spawn(pos: Vector2, text: String, color: Color, scale: float = 1.0) -> void:
	_items.append({
		"pos": pos + Vector2(8.0, -6.0),
		"text": text,
		"color": color,
		"scale": maxf(0.1, scale),
		"t": 0.0,
		"dur": 0.85,
	})


func update(delta: float) -> void:
	for i in range(_items.size() - 1, -1, -1):
		var ft: Dictionary = _items[i]
		ft["t"] = float(ft["t"]) + delta
		if float(ft["t"]) >= float(ft["dur"]):
			_items.remove_at(i)
		else:
			_items[i] = ft


func draw_to(canvas_item: CanvasItem, font: Font = null, font_size: int = 14) -> void:
	var draw_font: Font = font
	if draw_font == null:
		draw_font = ThemeDB.fallback_font
	for ft in _items:
		var t: float = float(ft["t"])
		var dur: float = float(ft["dur"])
		var p: float = clampf(t / dur, 0.0, 1.0)
		var ease_out: float = 1.0 - pow(1.0 - p, 2.0)
		var pos: Vector2 = ft["pos"] + Vector2(0.0, -24.0 * ease_out)
		var col: Color = ft["color"]
		var alpha: float = 1.0 - p
		var text: String = String(ft["text"])
		var scale: float = maxf(0.1, float(ft.get("scale", 1.0)))
		var draw_font_size: int = maxi(6, int(round(float(font_size) * scale)))
		var shadow_off: Vector2 = Vector2.ONE * maxf(1.0, scale)
		canvas_item.draw_string(draw_font, pos + shadow_off, text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, draw_font_size, Color(0, 0, 0, 0.5 * alpha))
		canvas_item.draw_string(draw_font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, draw_font_size, Color(col.r, col.g, col.b, alpha))
