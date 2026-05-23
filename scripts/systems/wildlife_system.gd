class_name WildlifeSystem
extends RefCounted


func run(state: Dictionary) -> Dictionary:
	var delta: float = float(state["delta"])
	var structure_raze_cooldown: float = float(state["structure_raze_cooldown"])
	var wildlife_spawn_tick: float = float(state["wildlife_spawn_tick"])
	var night_visual_boost: float = float(state["night_visual_boost"])
	var wolf_raid_active: bool = bool(state["wolf_raid_active"])
	var camp_tile: Vector2i = state["camp_tile"]

	var wildlife: Array = state["wildlife"]
	var resources: Dictionary = state["resources"]
	var house_tiles: Array = state["house_tiles"]

	var animal_deer: int = int(state["animal_deer"])
	var animal_wolf: int = int(state["animal_wolf"])
	var animal_bear: int = int(state["animal_bear"])

	var cb_is_night: Callable = state["cb_is_night"]
	var cb_try_spawn_wildlife: Callable = state["cb_try_spawn_wildlife"]
	var cb_agent_positions: Callable = state["cb_agent_positions"]
	var cb_flee_direction: Callable = state["cb_flee_direction"]
	var cb_wander: Callable = state["cb_wander"]
	var cb_tile_center: Callable = state["cb_tile_center"]
	var cb_apply_predator_strike: Callable = state["cb_apply_predator_strike"]
	var cb_try_raze_structure: Callable = state["cb_try_raze_structure"]
	var cb_wildlife_food_yield: Callable = state["cb_wildlife_food_yield"]
	var cb_spawn_floating_text: Callable = state["cb_spawn_floating_text"]

	var deer_count: int = 0
	var predator_positions := PackedVector2Array()
	var herd_stats: Dictionary = {}
	for w0 in wildlife:
		var typ0: int = int(w0["type"])
		if typ0 == animal_deer:
			deer_count += 1
			var herd_id: int = int(w0.get("herd_id", -1))
			if herd_id >= 0:
				if not herd_stats.has(herd_id):
					herd_stats[herd_id] = {"sum_pos": Vector2.ZERO, "sum_vel": Vector2.ZERO, "count": 0}
				var stat: Dictionary = herd_stats[herd_id]
				stat["sum_pos"] = Vector2(stat["sum_pos"]) + Vector2(w0["pos"])
				stat["sum_vel"] = Vector2(stat["sum_vel"]) + Vector2(w0.get("vel", Vector2.ZERO))
				stat["count"] = int(stat["count"]) + 1
				herd_stats[herd_id] = stat
		elif typ0 == animal_wolf or typ0 == animal_bear:
			predator_positions.append(Vector2(w0["pos"]))

	structure_raze_cooldown = maxf(0.0, structure_raze_cooldown - delta)
	wildlife_spawn_tick += delta
	if bool(cb_is_night.call()) and wildlife_spawn_tick >= 6.0:
		wildlife_spawn_tick = 0.0
		cb_try_spawn_wildlife.call(false, 1)
	elif not bool(cb_is_night.call()) and wildlife_spawn_tick >= 3.5:
		wildlife_spawn_tick = 0.0
		if deer_count < 14:
			var group_size: int = clampi(2 + int((14 - deer_count) / 4), 2, 5)
			cb_try_spawn_wildlife.call(true, group_size)

	var settler_positions: PackedVector2Array = cb_agent_positions.call()

	for wi in range(wildlife.size()):
		var w: Dictionary = wildlife[wi]
		var pos: Vector2 = w["pos"]
		var vel := Vector2.ZERO
		var typ: int = int(w["type"])
		var state_str: String = String(w["state"])
		w["attack_cd"] = maxf(0.0, float(w["attack_cd"]) - delta)

		match typ:
			animal_deer:
				var flee_settler: Vector2 = cb_flee_direction.call(pos, settler_positions, 110.0)
				var flee_predator: Vector2 = cb_flee_direction.call(pos, predator_positions, 95.0)
				var flee_dir: Vector2 = flee_settler + flee_predator * 1.25
				var herd_center := pos
				var herd_vel := Vector2.ZERO
				var herd_id: int = int(w.get("herd_id", -1))
				if herd_id >= 0 and herd_stats.has(herd_id):
					var hs: Dictionary = herd_stats[herd_id]
					var count_h: int = maxi(1, int(hs["count"]))
					herd_center = Vector2(hs["sum_pos"]) / float(count_h)
					herd_vel = Vector2(hs["sum_vel"]) / float(count_h)
				var cohesion: Vector2 = herd_center - pos
				if flee_dir.length_squared() > 0.01:
					var flee_vec: Vector2 = flee_dir.normalized() * 42.0
					if cohesion.length_squared() > 4.0:
						flee_vec += cohesion.normalized() * 8.0
					vel = flee_vec.limit_length(44.0)
					w["state"] = "flee"
				else:
					var herd_move: Vector2 = cb_wander.call(w, delta, 14.0)
					if cohesion.length() > 18.0:
						herd_move += cohesion.normalized() * 12.0
					herd_move += herd_vel * 0.25
					vel = herd_move.limit_length(22.0)
					w["state"] = "herd"

			animal_wolf:
				var nearest_dist: float = 1e9
				var nearest_pos := Vector2.ZERO
				for sp in settler_positions:
					var d: float = pos.distance_to(sp)
					if d < nearest_dist:
						nearest_dist = d
						nearest_pos = sp
				var chasing: bool = state_str == "chase" or state_str == "attack" or state_str == "raid_hunt"
				var phase: float = float(w.get("phase", 0.0))
				if not bool(cb_is_night.call()):
					w["state"] = "wander"
					w["chase_timer"] = 0.0
					vel = cb_wander.call(w, delta, 16.0)
				elif nearest_dist < 220.0 or wolf_raid_active:
					if not chasing:
						w["chase_timer"] = 5.0
					w["state"] = "raid_hunt" if nearest_dist > 22.0 else "attack"
					var hunt_target: Vector2 = nearest_pos
					if nearest_dist >= 220.0:
						hunt_target = cb_tile_center.call(camp_tile)
						if house_tiles.size() > 0:
							hunt_target = cb_tile_center.call(house_tiles[int(wi) % house_tiles.size()])
					w["target_pos"] = hunt_target
					var toward: Vector2 = hunt_target - pos
					var dir: Vector2 = toward.normalized() if toward.length_squared() > 0.001 else Vector2.RIGHT
					var side := Vector2(-dir.y, dir.x)
					var zig: float = sin(Time.get_ticks_msec() * 0.004 + phase)
					vel = (dir + side * (0.34 * zig)).normalized() * 38.0
					if nearest_dist < 22.0 and float(w["attack_cd"]) <= 0.0:
						w["attack_cd"] = 1.8
						night_visual_boost = minf(0.2, night_visual_boost + 0.03)
						cb_apply_predator_strike.call(nearest_pos, animal_wolf)
						cb_try_raze_structure.call(nearest_pos, animal_wolf)
				elif chasing:
					w["chase_timer"] = float(w.get("chase_timer", 0.0)) - delta
					if float(w["chase_timer"]) > 0.0 and nearest_dist < 280.0:
						var chase_dir: Vector2 = (nearest_pos - pos).normalized()
						vel = chase_dir * 31.0
					else:
						w["state"] = "wander"
						w["chase_timer"] = 0.0
						vel = cb_wander.call(w, delta, 14.0)
				else:
					var center2: Vector2 = cb_tile_center.call(camp_tile)
					if house_tiles.size() > 0:
						center2 = cb_tile_center.call(house_tiles[int(wi) % house_tiles.size()])
					var diff2: Vector2 = center2 - pos
					var ddir: Vector2 = diff2.normalized() if diff2.length_squared() > 0.001 else Vector2.RIGHT
					var side2 := Vector2(-ddir.y, ddir.x)
					var wiggle: float = sin(Time.get_ticks_msec() * 0.003 + phase * 0.7)
					vel = (ddir + side2 * 0.42 * wiggle).normalized() * 26.0
					w["state"] = "wander"

			animal_bear:
				var nearest_dist_b: float = 1e9
				var nearest_pos_b := Vector2.ZERO
				for sp in settler_positions:
					var d2: float = pos.distance_to(sp)
					if d2 < nearest_dist_b:
						nearest_dist_b = d2
						nearest_pos_b = sp
				var phase_b: float = float(w.get("phase", 0.0))
				if bool(cb_is_night.call()):
					w["state"] = "aggro"
					var bear_target: Vector2 = nearest_pos_b
					if nearest_dist_b > 240.0:
						bear_target = cb_tile_center.call(camp_tile)
					var bdir: Vector2 = (bear_target - pos).normalized()
					var swing: float = sin(Time.get_ticks_msec() * 0.0025 + phase_b)
					var bside := Vector2(-bdir.y, bdir.x)
					vel = (bdir + bside * 0.22 * swing).normalized() * 34.0
					if nearest_dist_b < 22.0 and float(w["attack_cd"]) <= 0.0:
						w["attack_cd"] = 3.0
						cb_apply_predator_strike.call(nearest_pos_b, animal_bear)
						cb_try_raze_structure.call(nearest_pos_b, animal_bear)
				else:
					vel = cb_wander.call(w, delta, 8.0)
					w["state"] = "wander"

		w["pos"] = pos + vel * delta

	for wi in range(wildlife.size() - 1, -1, -1):
		if float(wildlife[wi]["hp"]) <= 0.0:
			var t: int = int(wildlife[wi]["type"])
			var gain: float = float(cb_wildlife_food_yield.call(t))
			resources["food"] = float(resources["food"]) + gain
			cb_spawn_floating_text.call(wildlife[wi]["pos"], "+%d food" % int(gain), Color(0.95, 0.8, 0.34, 1.0))
			wildlife.remove_at(wi)

	return {
		"structure_raze_cooldown": structure_raze_cooldown,
		"wildlife_spawn_tick": wildlife_spawn_tick,
		"night_visual_boost": night_visual_boost,
	}
