class_name SettlerManager
extends RefCounted

var happiness: PackedFloat32Array
var attack_cooldowns: PackedFloat32Array
var weapons: PackedInt32Array
var tools: PackedInt32Array
var tool_modes: PackedInt32Array
var next_think_time: PackedFloat32Array
var think_state: PackedInt32Array
var last_pos: PackedVector2Array
var idle_time: PackedFloat32Array


func ensure_core_buffers(
	count: int,
	rng: RandomNumberGenerator,
	default_weapon: int,
	default_tool: int,
	default_tool_mode: int
) -> void:
	if happiness.size() != count:
		var old_happiness := happiness
		happiness.resize(count)
		for i in count:
			if i < old_happiness.size():
				happiness[i] = old_happiness[i]
			else:
				happiness[i] = clampf(0.52 + rng.randf_range(-0.06, 0.12), 0.0, 1.0)

	if attack_cooldowns.size() != count:
		var old_cd := attack_cooldowns
		attack_cooldowns.resize(count)
		for i in count:
			attack_cooldowns[i] = old_cd[i] if i < old_cd.size() else rng.randf_range(0.0, 0.5)

	if weapons.size() != count:
		var old_weapons := weapons
		weapons.resize(count)
		for i in count:
			weapons[i] = old_weapons[i] if i < old_weapons.size() else default_weapon

	if tools.size() != count:
		var old_tools := tools
		tools.resize(count)
		for i in count:
			tools[i] = old_tools[i] if i < old_tools.size() else default_tool

	if tool_modes.size() != count:
		var old_tool_modes := tool_modes
		tool_modes.resize(count)
		for i in count:
			tool_modes[i] = old_tool_modes[i] if i < old_tool_modes.size() else default_tool_mode


func ensure_think_buffers(
	count: int,
	agent_positions: PackedVector2Array,
	now_sec: float,
	jitter_sec: float,
	rng: RandomNumberGenerator,
	default_think_state: int
) -> void:
	if next_think_time.size() != count:
		var old_times := next_think_time
		next_think_time.resize(count)
		for i in count:
			if i < old_times.size():
				next_think_time[i] = old_times[i]
			else:
				next_think_time[i] = now_sec + _jitter(rng, jitter_sec)

	if think_state.size() != count:
		var old_states := think_state
		think_state.resize(count)
		for i in count:
			think_state[i] = old_states[i] if i < old_states.size() else default_think_state

	if last_pos.size() != count:
		var old_pos := last_pos
		last_pos.resize(count)
		for i in count:
			if i < old_pos.size():
				last_pos[i] = old_pos[i]
			elif i < agent_positions.size():
				last_pos[i] = agent_positions[i]
			else:
				last_pos[i] = Vector2.ZERO

	if idle_time.size() != count:
		var old_idle := idle_time
		idle_time.resize(count)
		for i in count:
			idle_time[i] = old_idle[i] if i < old_idle.size() else 0.0


func _jitter(rng: RandomNumberGenerator, jitter_sec: float) -> float:
	if jitter_sec <= 0.0:
		return 0.0
	return rng.randf_range(-jitter_sec, jitter_sec)
