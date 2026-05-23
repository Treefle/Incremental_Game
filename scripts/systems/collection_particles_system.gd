class_name CollectionParticlesSystem
extends RefCounted


var _items: Array[Dictionary] = []


func spawn_burst(pos: Vector2, color: Color, rng: RandomNumberGenerator, count: int = 6) -> void:
	for i in count:
		_items.append({
			"pos": pos,
			"vel": Vector2(rng.randf_range(-22.0, 22.0), rng.randf_range(-38.0, -12.0)),
			"size": rng.randf_range(1.4, 2.5),
			"color": color,
			"t": 0.0,
			"dur": rng.randf_range(0.35, 0.62),
		})


func update(delta: float) -> void:
	for i in range(_items.size() - 1, -1, -1):
		var p: Dictionary = _items[i]
		p["t"] = float(p["t"]) + delta
		p["vel"] = Vector2(p["vel"].x, p["vel"].y + 65.0 * delta)
		p["pos"] = Vector2(p["pos"].x, p["pos"].y) + Vector2(p["vel"].x, p["vel"].y) * delta
		if float(p["t"]) >= float(p["dur"]):
			_items.remove_at(i)
		else:
			_items[i] = p


func queue_to_batch(render_batch_system: RenderBatchSystem, sprite_id: int) -> void:
	if _items.is_empty():
		return
	render_batch_system.queue_particles(_items, sprite_id)
