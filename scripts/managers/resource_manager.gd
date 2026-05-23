class_name ResourceManager
extends RefCounted

var resource_claims: Dictionary = {}
var resource_claims_id: Dictionary = {}  # tile_id -> settler index
var settler_resource_targets: Dictionary = {}
var settler_day_plan_targets: Dictionary = {}
var settler_day_plan_job: Dictionary = {}


func is_tile_claimed_by_other(tile_key: String, settler_index: int, tile_id: int = -1) -> bool:
	if tile_id >= 0 and resource_claims_id.has(tile_id):
		return int(resource_claims_id[tile_id]) != settler_index
	if not resource_claims.has(tile_key):
		return false
	return int(resource_claims[tile_key]) != settler_index


func release_resource_claim(settler_index: int, tile_key: String, tile_id: int = -1) -> void:
	if not settler_resource_targets.has(settler_index):
		return
	if resource_claims.has(tile_key) and int(resource_claims[tile_key]) == settler_index:
		resource_claims.erase(tile_key)
	if tile_id >= 0:
		resource_claims_id.erase(tile_id)
	settler_resource_targets.erase(settler_index)


func try_claim_resource_tile(settler_index: int, tile: Vector2i, tile_key: String, prev_key: String = "", tile_id: int = -1, prev_tile_id: int = -1) -> bool:
	if tile == Vector2i(-9999, -9999):
		return false
	if tile_id >= 0 and resource_claims_id.has(tile_id) and int(resource_claims_id[tile_id]) != settler_index:
		return false
	if resource_claims.has(tile_key) and int(resource_claims[tile_key]) != settler_index:
		return false
	if prev_key != "" and prev_key != tile_key and resource_claims.has(prev_key) and int(resource_claims[prev_key]) == settler_index:
		resource_claims.erase(prev_key)
	if prev_tile_id >= 0:
		resource_claims_id.erase(prev_tile_id)
	resource_claims[tile_key] = settler_index
	if tile_id >= 0:
		resource_claims_id[tile_id] = settler_index
	settler_resource_targets[settler_index] = tile
	return true


func _erase_claim_key(key: String) -> void:
	resource_claims.erase(key)
	var parts: PackedStringArray = key.split(":")
	if parts.size() == 2:
		var tile := Vector2i(int(parts[0]), int(parts[1]))
		var tile_id: int = (int(tile.x) << 32) ^ (int(tile.y) & 0xffffffff)
		resource_claims_id.erase(tile_id)


func cleanup_claims(settler_count: int, tile_key_fn: Callable) -> void:
	var keys: Array = resource_claims.keys()
	for key_v in keys:
		var key: String = String(key_v)
		var owner: int = int(resource_claims[key])
		if owner < 0 or owner >= settler_count:
			_erase_claim_key(key)
			continue
		if not settler_resource_targets.has(owner):
			_erase_claim_key(key)
			continue
		var claimed_tile: Vector2i = settler_resource_targets[owner]
		if String(tile_key_fn.call(claimed_tile)) != key:
			_erase_claim_key(key)

	var planned_keys: Array = settler_day_plan_targets.keys()
	for idx_v in planned_keys:
		var idx: int = int(idx_v)
		if idx < 0 or idx >= settler_count:
			settler_day_plan_targets.erase(idx)
			settler_day_plan_job.erase(idx)
