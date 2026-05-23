class_name SettlerDecisionSystem
extends RefCounted


func run(state: Dictionary) -> Dictionary:
	var delta: float = float(state["delta"])
	var is_night: bool = bool(state["is_night"])
	var agents: PackedVector2Array = state["agents"]
	var count: int = int(state["count"])
	var now_sec: float = float(state["now_sec"])
	var targets: PackedVector2Array = state["targets"]
	var decision_budget: int = int(state["decision_budget"])
	var night_plan_budget: int = int(state["night_plan_budget"])
	var scan_budget: int = maxi(1, int(state.get("scan_budget", count)))
	var candidate_indices: PackedInt32Array = state.get("candidate_indices", PackedInt32Array())
	var monitor_advance: int = int(state.get("monitor_advance", 0))
	var offscreen_decision_throttle_enabled: bool = bool(state.get("offscreen_decision_throttle_enabled", false))
	var offscreen_decision_stride: int = maxi(1, int(state.get("offscreen_decision_stride", 1)))
	var offscreen_night_planning_stride: int = maxi(1, int(state.get("offscreen_night_planning_stride", 1)))
	var decision_tick_counter: int = int(state.get("decision_tick_counter", 0))
	var view_min: Vector2 = state.get("view_min", Vector2(-1e12, -1e12))
	var view_max: Vector2 = state.get("view_max", Vector2(1e12, 1e12))
	var settler_decision_cursor: int = int(state["settler_decision_cursor"])
	var settler_decisions_this_tick: int = int(state["settler_decisions_this_tick"])
	var invalid_tile: Vector2i = state["invalid_tile"]
	var global_target: Vector2 = state["global_target"]
	var camp_tile: Vector2i = state["camp_tile"]

	var settler_next_think_time: PackedFloat32Array = state["settler_next_think_time"]
	var settler_think_state: PackedInt32Array = state["settler_think_state"]
	var settler_idle_time: PackedFloat32Array = state["settler_idle_time"]
	var settler_last_pos: PackedVector2Array = state["settler_last_pos"]
	var agent_last_state: Dictionary = state["agent_last_state"]
	var settler_resource_targets: Dictionary = state["settler_resource_targets"]
	var settler_day_plan_targets: Dictionary = state["settler_day_plan_targets"]
	var settler_day_plan_job: Dictionary = state["settler_day_plan_job"]
	var poi_sites: Array = state["poi_sites"]

	var think_executing: int = int(state["think_executing"])
	var think_thinking: int = int(state["think_thinking"])
	var think_blocked: int = int(state["think_blocked"])
	var job_farm: int = int(state["job_farm"])
	var job_lumber: int = int(state["job_lumber"])
	var job_stone: int = int(state["job_stone"])
	var job_hunt: int = int(state["job_hunt"])
	var job_scout: int = int(state["job_scout"])
	var res_apple: int = int(state["res_apple"])
	var res_berry_blue: int = int(state["res_berry_blue"])
	var res_berry_rasp: int = int(state["res_berry_rasp"])
	var res_berry_black: int = int(state["res_berry_black"])
	var res_tree: int = int(state["res_tree"])
	var res_stone: int = int(state["res_stone"])
	var res_metal: int = int(state.get("res_metal", -9999))
	var metal_mining_unlocked: bool = bool(state.get("metal_mining_unlocked", false))
	var food_min_harvest: float = float(state["food_min_harvest"])

	var settler_arrival_rethink_distance_px: float = float(state["settler_arrival_rethink_distance_px"])
	var settler_stuck_rethink_sec: float = float(state["settler_stuck_rethink_sec"])
	var settler_min_progress_px: float = float(state["settler_min_progress_px"])

	var cb_think_jitter: Callable = state["cb_think_jitter"]
	var cb_current_poi_target_index: Callable = state["cb_current_poi_target_index"]
	var cb_tile_center: Callable = state["cb_tile_center"]
	var cb_select_poi_scout: Callable = state["cb_select_poi_scout"]
	var cb_update_day_plan_for_settler: Callable = state["cb_update_day_plan_for_settler"]
	var cb_world_to_tile: Callable = state["cb_world_to_tile"]
	var cb_job_for_settler: Callable = state["cb_job_for_settler"]
	var cb_segment_world_target: Callable = state["cb_segment_world_target"]
	var cb_home_center_for_settler: Callable = state["cb_home_center_for_settler"]
	var cb_schedule_next_think: Callable = state["cb_schedule_next_think"]
	var cb_set_next_think_time: Callable = state.get("cb_set_next_think_time", Callable())
	var cb_release_resource_claim: Callable = state["cb_release_resource_claim"]
	var cb_record_agent_action: Callable = state["cb_record_agent_action"]
	var cb_log_global_settler_event: Callable = state["cb_log_global_settler_event"]
	var cb_resource_type_at: Callable = state["cb_resource_type_at"]
	var cb_resource_left: Callable = state["cb_resource_left"]
	var cb_is_day_plan_valid: Callable = state["cb_is_day_plan_valid"]
	var cb_nearest_food_tile: Callable = state["cb_nearest_food_tile"]
	var cb_try_claim_resource_tile: Callable = state["cb_try_claim_resource_tile"]
	var cb_segment_target_toward: Callable = state["cb_segment_target_toward"]
	var cb_nearest_wildlife_pos: Callable = state["cb_nearest_wildlife_pos"]
	var cb_nearest_resource_tile: Callable = state["cb_nearest_resource_tile"]
	var cb_nearest_mining_tile: Callable = state.get("cb_nearest_mining_tile", Callable())
	var indicator_changed: PackedInt32Array = PackedInt32Array()

	var poi_idx: int = -1
	var poi_target: Vector2 = Vector2.ZERO
	var scout_idx: int = -1
	if not is_night:
		poi_idx = int(cb_current_poi_target_index.call())
		if poi_idx >= 0 and poi_idx < poi_sites.size():
			var psite: Dictionary = poi_sites[poi_idx]
			poi_target = cb_tile_center.call(psite["tile"])
			scout_idx = int(cb_select_poi_scout.call(agents, poi_target))

	var processed_steps: int = candidate_indices.size() if not candidate_indices.is_empty() else mini(count, scan_budget)
	for step in processed_steps:
		var i: int = int(candidate_indices[step]) if not candidate_indices.is_empty() else (settler_decision_cursor + step) % count
		var prev_think_state: int = settler_think_state[i]
		var state_tag: String = ""
		var pos_now: Vector2 = agents[i]
		var is_visible: bool = pos_now.x >= view_min.x and pos_now.x <= view_max.x and pos_now.y >= view_min.y and pos_now.y <= view_max.y
		if offscreen_decision_throttle_enabled and not is_visible:
			var stride: int = offscreen_night_planning_stride if is_night else offscreen_decision_stride
			if stride > 1 and ((i + decision_tick_counter) % stride) != 0:
				if settler_think_state[i] != prev_think_state:
					indicator_changed.append(i)
				continue
		if is_night:
			if night_plan_budget > 0:
				cb_update_day_plan_for_settler.call(i, cb_world_to_tile.call(pos_now), cb_job_for_settler.call(i))
				night_plan_budget -= 1
			if String(agent_last_state.get(i, "")) == "night_home" and now_sec < settler_next_think_time[i]:
				if settler_think_state[i] != think_blocked:
					settler_think_state[i] = think_executing
				settler_idle_time[i] = 0.0
				settler_last_pos[i] = pos_now
				if settler_think_state[i] != prev_think_state:
					indicator_changed.append(i)
				continue
			var night_from_tile: Vector2i = cb_world_to_tile.call(pos_now)
			targets[i] = cb_segment_world_target.call(night_from_tile, cb_home_center_for_settler.call(i))
			state_tag = "night_home"
			settler_decisions_this_tick += 1
			settler_think_state[i] = think_executing
			settler_idle_time[i] = 0.0
			settler_last_pos[i] = pos_now
			cb_schedule_next_think.call(i, now_sec, false)
			if String(agent_last_state.get(i, "")) != state_tag:
				agent_last_state[i] = state_tag
				cb_release_resource_claim.call(i)
				cb_record_agent_action.call(i, "Returning to home")
				cb_log_global_settler_event.call("state_change", i, cb_job_for_settler.call(i), state_tag, targets[i], "night_return_home")
			if settler_think_state[i] != prev_think_state:
				indicator_changed.append(i)
			continue

		var current_target: Vector2 = targets[i] if i < targets.size() else global_target
		var dist_to_target: float = pos_now.distance_to(current_target)
		var moved_px: float = pos_now.distance_to(settler_last_pos[i])
		settler_last_pos[i] = pos_now
		var force_rethink: bool = false
		var monitor_last_state: String = String(agent_last_state.get(i, ""))
		if dist_to_target <= settler_arrival_rethink_distance_px and monitor_last_state != "night_home":
			force_rethink = true
		elif moved_px < settler_min_progress_px and dist_to_target > settler_arrival_rethink_distance_px * 1.5:
			settler_idle_time[i] += delta
			if settler_idle_time[i] >= settler_stuck_rethink_sec:
				force_rethink = true
		else:
			settler_idle_time[i] = 0.0

		if force_rethink:
			if cb_set_next_think_time.is_valid():
				cb_set_next_think_time.call(i, now_sec)
			else:
				settler_next_think_time[i] = now_sec
			settler_think_state[i] = think_thinking

		if now_sec < settler_next_think_time[i]:
			if settler_think_state[i] != think_blocked:
				settler_think_state[i] = think_executing
			if settler_think_state[i] != prev_think_state:
				indicator_changed.append(i)
			continue

		if not is_night and settler_decisions_this_tick >= decision_budget:
			var delayed_think_time: float = now_sec + 0.08 + abs(float(cb_think_jitter.call()))
			if cb_set_next_think_time.is_valid():
				cb_set_next_think_time.call(i, delayed_think_time)
			else:
				settler_next_think_time[i] = delayed_think_time
			settler_think_state[i] = think_thinking
			if settler_think_state[i] != prev_think_state:
				indicator_changed.append(i)
			continue

		settler_idle_time[i] = 0.0
		var pos: Vector2 = pos_now
		var tile: Vector2i = cb_world_to_tile.call(pos)
		var job: int = int(cb_job_for_settler.call(i))
		var last_state: String = String(agent_last_state.get(i, ""))
		if job != job_farm and job != job_lumber and job != job_stone:
			cb_release_resource_claim.call(i)
		var blocked: bool = false
		if i == scout_idx and poi_idx >= 0:
			targets[i] = cb_segment_world_target.call(tile, poi_target)
			state_tag = "day_explore"
			cb_release_resource_claim.call(i)
			settler_decisions_this_tick += 1
			settler_think_state[i] = think_executing
			cb_schedule_next_think.call(i, now_sec, false)
			if last_state != state_tag:
				agent_last_state[i] = state_tag
				cb_record_agent_action.call(i, "Scouting point of interest")
				cb_log_global_settler_event.call("state_change", i, job, state_tag, targets[i], "poi_scouting")
			continue

		if job == job_farm:
			var cached: Vector2i = settler_resource_targets.get(i, invalid_tile)
			var need_new: bool = cached == invalid_tile
			if not need_new:
				var rt: int = int(cb_resource_type_at.call(cached))
				var is_food: bool = rt == res_apple or rt == res_berry_blue or rt == res_berry_rasp or rt == res_berry_black
				if not is_food or float(cb_resource_left.call(cached, rt)) <= 0.0:
					need_new = true
				elif float(cb_resource_left.call(cached, rt)) < food_min_harvest:
					need_new = true
				elif tile.distance_to(cached) <= 1.5:
					need_new = true
			if need_new:
				cb_release_resource_claim.call(i)
				if settler_day_plan_targets.has(i) and int(settler_day_plan_job.get(i, -1)) == job:
					var planned_tile: Vector2i = settler_day_plan_targets[i]
					if bool(cb_is_day_plan_valid.call(i, planned_tile, job)):
						cached = planned_tile
					else:
						cached = invalid_tile
				else:
					cached = invalid_tile
				if cached == invalid_tile:
					cached = cb_nearest_food_tile.call(tile, i)
				if cached == invalid_tile:
					blocked = true
					cached = camp_tile
				else:
					if not bool(cb_try_claim_resource_tile.call(i, cached)):
						blocked = true
						cached = camp_tile
					else:
						settler_day_plan_targets[i] = cached
						settler_day_plan_job[i] = job
			var move_tile: Vector2i = cb_segment_target_toward.call(tile, cached)
			targets[i] = cb_tile_center.call(move_tile)
			state_tag = "day_blocked" if blocked else "day_farm"
		elif job == job_hunt:
			var hunt_pos: Vector2 = cb_nearest_wildlife_pos.call(pos, true)
			if hunt_pos == pos:
				blocked = true
			targets[i] = cb_segment_world_target.call(tile, hunt_pos)
			state_tag = "day_blocked" if blocked else "day_hunt"
		elif job == job_scout:
			var scout_goal: Vector2 = poi_target if poi_idx >= 0 else global_target
			targets[i] = cb_segment_world_target.call(tile, scout_goal)
			state_tag = "day_scout"
		else:
			var res_type: int = res_tree if job == job_lumber else res_stone
			var cached2: Vector2i = settler_resource_targets.get(i, invalid_tile)
			var need_new2: bool = false
			if cached2 == invalid_tile:
				need_new2 = true
			elif job == job_stone:
				var cached_rt: int = int(cb_resource_type_at.call(cached2))
				if cached_rt != res_stone and (not metal_mining_unlocked or cached_rt != res_metal):
					need_new2 = true
				elif float(cb_resource_left.call(cached2, cached_rt)) <= 0.0:
					need_new2 = true
			elif float(cb_resource_left.call(cached2, res_type)) <= 0.0:
				need_new2 = true
			elif tile.distance_to(cached2) <= 1.5:
				need_new2 = true
			if need_new2:
				cb_release_resource_claim.call(i)
				if settler_day_plan_targets.has(i) and int(settler_day_plan_job.get(i, -1)) == job:
					var planned_rt: Vector2i = settler_day_plan_targets[i]
					if bool(cb_is_day_plan_valid.call(i, planned_rt, job)):
						cached2 = planned_rt
					else:
						cached2 = invalid_tile
				else:
					cached2 = invalid_tile
				if cached2 == invalid_tile:
					if job == job_stone and cb_nearest_mining_tile.is_valid():
						cached2 = cb_nearest_mining_tile.call(tile, i)
					else:
						cached2 = cb_nearest_resource_tile.call(tile, res_type, i)
				if cached2 == invalid_tile:
					blocked = true
					cached2 = camp_tile
				else:
					if not bool(cb_try_claim_resource_tile.call(i, cached2)):
						blocked = true
						cached2 = camp_tile
					else:
						settler_day_plan_targets[i] = cached2
						settler_day_plan_job[i] = job
			var move_tile2: Vector2i = cb_segment_target_toward.call(tile, cached2)
			targets[i] = cb_tile_center.call(move_tile2)
			if blocked:
				state_tag = "day_blocked"
			else:
				state_tag = "day_lumber" if job == job_lumber else "day_stone"

		settler_decisions_this_tick += 1
		settler_think_state[i] = think_blocked if blocked else think_executing
		cb_schedule_next_think.call(i, now_sec, blocked)

		if last_state != state_tag:
			agent_last_state[i] = state_tag
			if state_tag == "day_farm":
				cb_record_agent_action.call(i, "Assigned to farming")
			elif state_tag == "day_lumber":
				cb_record_agent_action.call(i, "Assigned to lumber")
			elif state_tag == "day_hunt":
				cb_record_agent_action.call(i, "Assigned to hunting")
			elif state_tag == "day_scout":
				cb_record_agent_action.call(i, "Assigned to scouting")
			elif state_tag == "day_blocked":
				cb_record_agent_action.call(i, "Waiting for next decision")
			else:
				cb_record_agent_action.call(i, "Assigned to mining")
			cb_log_global_settler_event.call("state_change", i, job, state_tag, targets[i], "target_reassigned")
		if settler_think_state[i] != prev_think_state:
			indicator_changed.append(i)

	if count > 0:
		settler_decision_cursor = (settler_decision_cursor + max(1, monitor_advance if monitor_advance > 0 else processed_steps)) % count

	return {
		"targets": targets,
		"settler_decisions_this_tick": settler_decisions_this_tick,
		"settler_decision_cursor": settler_decision_cursor,
		"settler_next_think_time": settler_next_think_time,
		"settler_think_state": settler_think_state,
		"settler_idle_time": settler_idle_time,
		"settler_last_pos": settler_last_pos,
		"agent_last_state": agent_last_state,
		"indicator_changed": indicator_changed,
	}
