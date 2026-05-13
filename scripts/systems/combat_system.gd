class_name CombatSystem
extends RefCounted


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

	var cb_is_night: Callable = state["cb_is_night"]
	var cb_agent_positions: Callable = state["cb_agent_positions"]
	var cb_weapon_for_settler: Callable = state["cb_weapon_for_settler"]
	var cb_weapon_profile: Callable = state["cb_weapon_profile"]
	var cb_record_agent_action: Callable = state["cb_record_agent_action"]
	var cb_weapon_name_for_id: Callable = state["cb_weapon_name_for_id"]

	if wildlife.is_empty():
		return {
			"attack_cooldowns": attack_cooldowns,
			"hunter_attack_anims": hunter_attack_anims,
			"combat_sfx_events": combat_sfx_events,
		}

	for i in attack_cooldowns.size():
		attack_cooldowns[i] = maxf(0.0, attack_cooldowns[i] - delta)

	var agents: PackedVector2Array = cb_agent_positions.call()
	for i in agents.size():
		if i >= attack_cooldowns.size() or attack_cooldowns[i] > 0.0:
			continue
		var from_pos: Vector2 = agents[i]
		var weapon_id: int = int(cb_weapon_for_settler.call(i))
		var profile: Dictionary = cb_weapon_profile.call(weapon_id)
		var attack_range: float = float(profile["range"])
		var nearest_idx: int = -1
		var nearest_dist: float = 1e9
		for wi in wildlife.size():
			var w: Dictionary = wildlife[wi]
			var typ: int = int(w["type"])
			if typ != animal_wolf and typ != animal_bear:
				continue
			if not bool(cb_is_night.call()):
				continue
			var d: float = from_pos.distance_to(w["pos"])
			if d < nearest_dist:
				nearest_dist = d
				nearest_idx = wi
		if nearest_idx < 0 or nearest_dist > attack_range:
			continue

		var target: Dictionary = wildlife[nearest_idx]
		var to_pos: Vector2 = target["pos"]
		var attack_kind: String = String(profile.get("attack_kind", "melee"))
		var ranged: bool = bool(profile.get("ranged", attack_kind != "melee"))
		var role_mult: float = ranged_damage_mult if ranged else melee_damage_mult
		var damage: float = 1.1 * float(profile["damage"]) * settler_combat_damage_mult * role_mult
		var aoe_radius: float = float(profile.get("aoe_radius", 0.0))
		if attack_kind == "aoe" or aoe_radius > 0.01:
			var impact_radius: float = maxf(aoe_radius, 8.0)
			for wi in wildlife.size():
				var w2: Dictionary = wildlife[wi]
				var typ2: int = int(w2["type"])
				if typ2 != animal_wolf and typ2 != animal_bear:
					continue
				var dist_to_impact: float = to_pos.distance_to(w2["pos"])
				if dist_to_impact > impact_radius:
					continue
				var falloff: float = 1.0 - clampf(dist_to_impact / impact_radius, 0.0, 0.92)
				w2["hp"] = float(w2["hp"]) - damage * maxf(0.2, falloff)
				wildlife[wi] = w2
		else:
			target["hp"] = float(target["hp"]) - damage
			wildlife[nearest_idx] = target
		var anim_dur: float = 0.13 if ranged else 0.16
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
		attack_cooldowns[i] = maxf(0.25, float(profile["cooldown"]) / settler_attack_speed_mult)
		cb_record_agent_action.call(i, "Defended with %s" % String(cb_weapon_name_for_id.call(weapon_id)))

	return {
		"attack_cooldowns": attack_cooldowns,
		"hunter_attack_anims": hunter_attack_anims,
		"combat_sfx_events": combat_sfx_events,
	}
