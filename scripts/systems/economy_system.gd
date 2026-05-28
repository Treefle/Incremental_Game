class_name EconomySystem
extends RefCounted


func run(state: Dictionary) -> Dictionary:
	var delta: float = float(state["delta"])
	var harvest_tick: float = float(state["harvest_tick"])
	var cook_tick: float = float(state["cook_tick"])
	var resource_regrow_tick: float = float(state["resource_regrow_tick"])

	var resources: Dictionary = state["resources"]
	var resource_remaining: Dictionary = state["resource_remaining"]
	var berry_overnight_regrow_due: Dictionary = state["berry_overnight_regrow_due"]
	var buildings: Dictionary = state["buildings"]
	var outpost_tiles: Array = state["outpost_tiles"]
	var house_tiles: Array = state.get("house_tiles", [])
	var manor_origins: Array = state.get("manor_origins", [])
	var manor_footprint: int = int(state.get("manor_footprint", 2))

	var food_consume_per_settler: float = float(state["food_consume_per_settler"])
	var food_consume_mult: float = float(state["food_consume_mult"])
	var convert_mult: float = float(state["convert_mult"])
	var quarry_passive_mult: float = float(state["quarry_passive_mult"])
	var storehouse_mult: float = float(state["storehouse_mult"])
	var night_cooking_unlocked: bool = bool(state.get("night_cooking_unlocked", false))

	var res_apple: int = int(state["res_apple"])
	var res_berry_blue: int = int(state["res_berry_blue"])
	var res_berry_rasp: int = int(state["res_berry_rasp"])
	var res_berry_black: int = int(state["res_berry_black"])
	var res_tree: int = int(state.get("res_tree", -9999))
	var metal_processing_unlocked: bool = bool(state.get("metal_processing_unlocked", false))

	var cb_harvest_resources: Callable = state["cb_harvest_resources"]
	var cb_agent_count: Callable = state["cb_agent_count"]
	var cb_is_night: Callable = state["cb_is_night"]
	var cb_housing_capacity: Callable = state["cb_housing_capacity"]
	var cb_spawn_floating_text: Callable = state["cb_spawn_floating_text"]
	var cb_tile_center: Callable = state["cb_tile_center"]
	var cb_resource_type_at: Callable = state["cb_resource_type_at"]
	var cb_resource_initial_amount: Callable = state["cb_resource_initial_amount"]
	var cb_mark_tile_dirty: Callable = state["cb_mark_tile_dirty"]

	var camp_tile: Vector2i = state["camp_tile"]
	var workshop_paused: bool = bool(state["workshop_paused"])
	var house_tile_keys: Dictionary = {}
	for tile_v in house_tiles:
		var house_tile: Vector2i = tile_v
		house_tile_keys["%d:%d" % [house_tile.x, house_tile.y]] = true
	for origin_v in manor_origins:
		var origin: Vector2i = origin_v
		for dx in manor_footprint:
			for dy in manor_footprint:
				var manor_tile := origin + Vector2i(dx, dy)
				house_tile_keys["%d:%d" % [manor_tile.x, manor_tile.y]] = true

	harvest_tick += delta
	if harvest_tick >= 0.7:
		harvest_tick = 0.0
		cb_harvest_resources.call()

	var agent_count: int = int(cb_agent_count.call())
	if agent_count > 0:
		var consume: float = agent_count * food_consume_per_settler * food_consume_mult * delta
		resources["food"] = maxf(0.0, float(resources["food"]) - consume)

	if bool(cb_is_night.call()) and night_cooking_unlocked:
		var housed: int = mini(agent_count, int(cb_housing_capacity.call()))
		if housed > 0 and float(resources["food"]) >= 1.0:
			cook_tick += delta * housed
			if cook_tick >= 4.0:
				cook_tick = 0.0
				var cooked: float = minf(float(resources["food"]), 1.0)
				resources["food"] = float(resources["food"]) + cooked
				cb_spawn_floating_text.call(cb_tile_center.call(camp_tile), "+1 cooked food", Color(0.95, 0.72, 0.25, 1.0))
		else:
			cook_tick = 0.0

	if bool(cb_is_night.call()):
		resource_regrow_tick += delta
	if resource_regrow_tick >= 1.0 and bool(cb_is_night.call()):
		var regrow_dt: float = resource_regrow_tick
		resource_regrow_tick = 0.0
		for key in resource_remaining.keys():
			if house_tile_keys.has(String(key)):
				continue
			var parts: Array = String(key).split(":")
			if parts.size() == 2:
				var tile := Vector2i(int(parts[0]), int(parts[1]))
				var rt: int = int(cb_resource_type_at.call(tile))
				if rt == res_apple:
					var cur: float = float(resource_remaining[key])
					var max_amt: float = float(cb_resource_initial_amount.call(tile, rt))
					if cur < max_amt:
						resource_remaining[key] = minf(cur + regrow_dt / 120.0, max_amt)
						cb_mark_tile_dirty.call(tile)

	if bool(cb_is_night.call()) and not berry_overnight_regrow_due.is_empty():
		var ready_keys: Array = []
		for key_v in berry_overnight_regrow_due.keys():
			var key: String = String(key_v)
			var left_t: float = float(berry_overnight_regrow_due[key]) - delta
			if left_t <= 0.0:
				ready_keys.append(key)
			else:
				berry_overnight_regrow_due[key] = left_t
		for key_v in ready_keys:
			var key: String = String(key_v)
			if house_tile_keys.has(key):
				berry_overnight_regrow_due[key] = 0.0
				continue
			var parts: Array = key.split(":")
			if parts.size() != 2:
				berry_overnight_regrow_due.erase(key)
				continue
			var tile := Vector2i(int(parts[0]), int(parts[1]))
			var rt: int = int(cb_resource_type_at.call(tile))
			if rt == res_tree or rt == res_berry_blue or rt == res_berry_rasp or rt == res_berry_black:
				resource_remaining[key] = cb_resource_initial_amount.call(tile, rt)
				cb_mark_tile_dirty.call(tile)
			berry_overnight_regrow_due.erase(key)

	var workshop_count: int = int(buildings["workshop"])
	var smelted_amount: float = 0.0
	# Refinery should smelt as soon as it's built (if ore exists and it isn't paused).
	if workshop_count > 0 and not workshop_paused:
		var convert_rate: float = (0.35 + workshop_count * 0.22) * convert_mult
		var convert: float = minf(float(resources["metal_ore"]), convert_rate * delta)
		resources["metal_ore"] = float(resources["metal_ore"]) - convert
		resources["metal"] = float(resources["metal"]) + convert * 0.35
		smelted_amount = convert

	var quarry_count: int = int(buildings["quarry"])
	if quarry_count > 0:
		resources["stone"] = float(resources["stone"]) + (0.22 * float(quarry_count) * quarry_passive_mult) * delta

	var store_count: int = int(buildings["storehouse"])
	if store_count > 0:
		resources["lumber"] = float(resources["lumber"]) + (0.4 * store_count * storehouse_mult) * delta

	if outpost_tiles.size() > 0:
		resources["food"] = float(resources["food"]) + 0.022 * float(outpost_tiles.size()) * delta
		resources["lumber"] = float(resources["lumber"]) + 0.016 * float(outpost_tiles.size()) * delta

	return {
		"harvest_tick": harvest_tick,
		"cook_tick": cook_tick,
		"resource_regrow_tick": resource_regrow_tick,
		"smelted_amount": smelted_amount,
	}
