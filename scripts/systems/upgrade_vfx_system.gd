class_name UpgradeVfxSystem
extends RefCounted


var _bursts: Array[Dictionary] = []


func spawn_burst(pos: Vector2, color: Color) -> void:
	_bursts.append({
		"pos": pos,
		"color": color,
		"t": 0.0,
		"dur": 0.65,
	})


func update(delta: float) -> void:
	for i in range(_bursts.size() - 1, -1, -1):
		var b: Dictionary = _bursts[i]
		b["t"] = float(b["t"]) + delta
		if float(b["t"]) >= float(b["dur"]):
			_bursts.remove_at(i)
		else:
			_bursts[i] = b


func draw_to(canvas_item: CanvasItem) -> void:
	for burst in _bursts:
		var t: float = float(burst["t"])
		var dur: float = float(burst["dur"])
		var p: float = clampf(t / dur, 0.0, 1.0)
		var ease_out: float = 1.0 - pow(1.0 - p, 2.0)
		var pos: Vector2 = burst["pos"]
		var col: Color = burst["color"]
		var radius: float = lerpf(10.0, 70.0, ease_out)
		var alpha: float = 1.0 - p

		canvas_item.draw_circle(pos, 12.0 + 20.0 * ease_out, Color(col.r, col.g, col.b, 0.18 * alpha))
		canvas_item.draw_arc(pos, radius, 0.0, TAU, 48, Color(col.r, col.g, col.b, 0.85 * alpha), 2.0)
