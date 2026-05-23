class_name CombatSystem
extends RefCounted


const _TARGET_GRID_CELL_PX: float = 96.0


func _grid_key_for_pos(pos: Vector2) -> String:
	var cx: int = floori(pos.x / _TARGET_GRID_CELL_PX)
	var cy: int = floori(pos.y / _TARGET_GRID_CELL_PX)
	return "%d:%d" % [cx, cy]


func _collect_candidates_in_radius(
	grid: Dictionary,
	origin: Vector2,
	radius_px: float
) -> Array[int]:
	var out: Array[int] = []
	var cx: int = floori(origin.x / _TARGET_GRID_CELL_PX)
	var cy: int = floori(origin.y / _TARGET_GRID_CELL_PX)
	var cell_radius: int = maxi(1, int(ceil(radius_px / _TARGET_GRID_CELL_PX)))
	for oy in range(-cell_radius, cell_radius + 1):
		for ox in range(-cell_radius, cell_radius + 1):
			var key: String = "%d:%d" % [cx + ox, cy + oy]
			if not grid.has(key):
				continue
			var indices: Array = grid[key]
			for idx_v in indices:
				out.append(int(idx_v))
	return out


func run(state: Dictionary) -> Dictionary:
	var delta: float = float(state["delta"])
	var wildlife: Array = state["wildlife"]
	var attack_cooldowns: PackedFloat32Array = state["attack_cooldowns"]
	var hunter_attack_anims: Array = state["hunter_attack_anims"]
	var combat_sfx_events: Array = state.get("combat_sfx_events", [])

	var settler_combat_damage_mult: float = float(state["settler_combat_damage_mult"])
	var settler_attack_speed_mult: float = float(state["settler_attack_speed_mult"])
	var melee_damage_mult: float = float(state["melee_damage_mult"])
	var ranged_damage_mult: float = float(state["ranged_damage_mult"])

	var animal_wolf: int = int(state["animal_wolf"])
	var animal_bear: int = int(state["animal_bear"])
	var animal_deer: int = int(state.get("animal_deer", -9999))
	var weapon_spear: int = int(state.get("weapon_spear", -9999))
	var job_hunt: int = int(state.get("job_hunt", -9999))
	var max_attackers_per_target: int = maxi(1, int(state.get("max_attackers_per_target", 4)))

	var cb_is_night: Callable = state["cb_is_night"]
	var cb_agent_positions: Callable = state["cb_agent_positions"]
	var cb_job_for_settler: Callable = state.get("cb_job_for_settler", Callable())
	var cb_weapon_for_settler: Callable = state["cb_weapon_for_settler"]
	var cb_weapon_profile: Callable = state["cb_weapon_profile"]
	var cb_tool_for_settler: Callable = state.get("cb_tool_for_settler", Callable())
	var cb_tool_name_for_id: Callable = state.get("cb_tool_name_for_id", Callable())
	var cb_tool_combat_modifiers_for_settler: Callable = state.get("cb_tool_combat_modifiers_for_settler", Callable())
	var cb_record_agent_action: Callable = state["cb_record_agent_action"]
	var cb_weapon_name_for_id: Callable = state["cb_weapon_name_for_id"]
	var is_night: bool = bool(state.get("is_night", cb_is_night.call()))

	if wildlife.is_empty():
		return {
			"attack_cooldowns": attack_cooldowns,
			"hunter_attack_anims": hunter_attack_anims,
			"combat_sfx_events": combat_sfx_events,
		}

	var day_candidates: Array[int] = []
	var night_candidates: Array[int] = []
	var day_grid: Dictionary = {}
	var night_grid: Dictionary = {}
	for wi in wildlife.size():
		var typ: int = int(wildlife[wi]["type"])
		if typ == animal_deer:
			day_candidates.append(wi)
			var day_key: String = _grid_key_for_pos(Vector2(wildlife[wi]["pos"]))
			if not day_grid.has(day_key):
				day_grid[day_key] = []
			var day_list: Array = day_grid[day_key]
			day_list.append(wi)
			day_grid[day_key] = day_list
		elif typ == animal_wolf or typ == animal_bear:
			night_candidates.append(wi)
			var night_key: String = _grid_key_for_pos(Vector2(wildlife[wi]["pos"]))
			if not night_grid.has(night_key):
				night_grid[night_key] = []
			var night_list: Array = night_grid[night_key]
			night_list.append(wi)
			night_grid[night_key] = night_list
	if is_night and night_candidates.is_empty():
		return {
			"attack_cooldowns": attack_cooldowns,
			"hunter_attack_anims": hunter_attack_anims,
			"combat_sfx_events": combat_sfx_events,
		}
	if not is_night and day_candidates.is_empty():
		return {
			"attack_cooldowns": attack_cooldowns,
			"hunter_attack_anims": hunter_attack_anims,
			"combat_sfx_events": combat_sfx_events,
		}

	for i in attack_cooldowns.size():
		attack_cooldowns[i] = maxf(0.0, attack_cooldowns[i] - delta)

	var agents: PackedVector2Array = cb_agent_positions.call()
	var attackers_by_target: Dictionary = {}
	for i in agents.size():
		if i >= attack_cooldowns.size() or attack_cooldowns[i] > 0.0:
			continue
		var from_pos: Vector2 = agents[i]
		var is_hunter: bool = cb_job_for_settler.is_valid() and int(cb_job_for_settler.call(i)) == job_hunt
		var can_hunt_deer: bool = is_hunter and not is_night
		var weapon_id: int = int(cb_weapon_for_settler.call(i))
		var profile: Dictionary = cb_weapon_profile.call(weapon_id)
		var tool_id: int = int(cb_tool_for_settler.call(i)) if cb_tool_for_settler.is_valid() else -1
		var tool_name: String = String(cb_tool_name_for_id.call(tool_id)) if cb_tool_name_for_id.is_valid() else "Hands"
		var tool_mods: Dictionary = cb_tool_combat_modifiers_for_settler.call(i) if cb_tool_combat_modifiers_for_settler.is_valid() else {}
		var tool_damage_mult: float = clampf(float(tool_mods.get("damage_mult", 1.0)), 0.75, 1.35)
		var tool_speed_mult: float = clampf(float(tool_mods.get("speed_mult", 1.0)), 0.75, 1.35)
		var tool_crit_chance: float = clampf(float(tool_mods.get("crit_chance", 0.0)), 0.0, 0.35)
		var tool_crit_mult: float = maxf(1.0, float(tool_mods.get("crit_mult", 1.35)))
		var attack_range: float = float(profile["range"])
		var candidates: Array[int]
		var effective_query_range: float = attack_range
		if not is_night:
			if not can_hunt_deer:
				continue
			if weapon_id == weapon_spear:
				effective_query_range = maxf(effective_query_range, 96.0)
			candidates = _collect_candidates_in_radius(day_grid, from_pos, effective_query_range)
		else:
			candidates = _collect_candidates_in_radius(night_grid, from_pos, effective_query_range)
		if candidates.is_empty():
			continue
		var nearest_dist_sq: float = 1e18
		var nearest_idx: int = -1
		for wi in candidates:
			if int(attackers_by_target.get(wi, 0)) >= max_attackers_per_target:
				continue
			var w: Dictionary = wildlife[wi]
			var offset: Vector2 = Vector2(w["pos"]) - from_pos
			var d_sq: float = offset.length_squared()
			if d_sq < nearest_dist_sq:
				nearest_dist_sq = d_sq
				nearest_idx = wi
		if nearest_idx < 0:
			continue

		var target: Dictionary = wildlife[nearest_idx]
		var to_pos: Vector2 = target["pos"]
		var target_type: int = int(target["type"])
		var attack_kind: String = String(profile.get("attack_kind", "melee"))
		var ranged: bool = bool(profile.get("ranged", attack_kind != "melee"))
		var effective_range: float = attack_range
		var used_spear_throw: bool = false
		if target_type == animal_deer and weapon_id == weapon_spear:
			# Hunters can throw spears at fleeing deer.
			effective_range = maxf(effective_range, 96.0)
			ranged = true
			used_spear_throw = true
		var effective_range_sq: float = effective_range * effective_range
		if nearest_dist_sq > effective_range_sq:
			continue
		attackers_by_target[nearest_idx] = int(attackers_by_target.get(nearest_idx, 0)) + 1
		var role_mult: float = ranged_damage_mult if ranged else melee_damage_mult
		var damage: float = 1.1 * float(profile["damage"]) * settler_combat_damage_mult * role_mult * tool_damage_mult
		var crit: bool = randf() < tool_crit_chance
		if crit:
			damage *= tool_crit_mult
		if target_type == animal_deer:
			damage *= 1.25
		var aoe_radius: float = float(profile.get("aoe_radius", 0.0))
		if attack_kind == "aoe" or aoe_radius > 0.01:
			var impact_radius: float = maxf(aoe_radius, 8.0)
			var impact_radius_sq: float = impact_radius * impact_radius
			for wi in night_candidates:
				var w2: Dictionary = wildlife[wi]
				var typ2: int = int(w2["type"])
				if typ2 != animal_wolf and typ2 != animal_bear:
					continue
				var impact_delta: Vector2 = Vector2(w2["pos"]) - to_pos
				var dist_sq: float = impact_delta.length_squared()
				if dist_sq > impact_radius_sq:
					continue
				var dist_to_impact: float = sqrt(dist_sq)
				var falloff: float = 1.0 - clampf(dist_to_impact / impact_radius, 0.0, 0.92)
				w2["hp"] = float(w2["hp"]) - damage * maxf(0.2, falloff)
				wildlife[wi] = w2
		else:
			target["hp"] = float(target["hp"]) - damage
			wildlife[nearest_idx] = target
		var anim_dur: float = 0.2 if used_spear_throw else (0.13 if ranged else 0.16)
		hunter_attack_anims.append({
			"from": from_pos,
			"to": to_pos,
			"t": 0.0,
			"dur": anim_dur,
			"color": profile.get("trail_color", Color(0.82, 0.76, 0.42, 1.0)),
			"width": float(profile.get("trail_width", 2.2)),
		})
		var sound_path: String = String(profile.get("sound_path", ""))
		if not sound_path.is_empty():
			combat_sfx_events.append({
				"path": sound_path,
				"pos": from_pos.lerp(to_pos, 0.3),
			})
		attack_cooldowns[i] = maxf(0.25, float(profile["cooldown"]) / maxf(0.1, settler_attack_speed_mult * tool_speed_mult))
		var tool_msg: String = ""
		if tool_name != "Hands":
			tool_msg = " + %s" % tool_name
		if crit:
			tool_msg += " (crit)"
		if target_type == animal_deer and used_spear_throw:
			cb_record_agent_action.call(i, "Threw spear at deer%s" % tool_msg)
		elif target_type == animal_deer:
			cb_record_agent_action.call(i, "Hunted deer with %s%s" % [String(cb_weapon_name_for_id.call(weapon_id)), tool_msg])
		else:
			cb_record_agent_action.call(i, "Defended with %s%s" % [String(cb_weapon_name_for_id.call(weapon_id)), tool_msg])

	return {
		"attack_cooldowns": attack_cooldowns,
		"hunter_attack_anims": hunter_attack_anims,
		"combat_sfx_events": combat_sfx_events,
	}
