class_name UpgradeRegistry
extends RefCounted

var _ranks: Dictionary = {}
var _multipliers: Dictionary = {}
var _unlocks: Dictionary = {}


func reset() -> void:
	_ranks.clear()
	_multipliers.clear()
	_unlocks.clear()


func set_ranks(ranks: Dictionary) -> void:
	_ranks = ranks.duplicate(true)


func get_rank(id: String) -> int:
	return int(_ranks.get(id, 0))


func set_multiplier(key: String, value: float) -> void:
	_multipliers[key] = value


func get_multiplier(key: String, default_value: float = 1.0) -> float:
	return float(_multipliers.get(key, default_value))


func set_unlock(key: String, value: bool) -> void:
	_unlocks[key] = value


func is_unlocked(key: String) -> bool:
	return bool(_unlocks.get(key, false))


func snapshot() -> Dictionary:
	return {
		"ranks": _ranks.duplicate(true),
		"multipliers": _multipliers.duplicate(true),
		"unlocks": _unlocks.duplicate(true),
	}
