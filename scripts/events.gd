extends Node

signal settler_acted(settler_idx: int, message: String)
signal resource_gained(resource_key: String, amount: float)
signal upgrade_purchased(upgrade_id: String, new_rank: int)
signal building_placed(building_id: String, tile: Vector2i)
signal building_razed(building_id: String, tile: Vector2i)
signal combat_strike(world_pos: Vector2, damage: float)
signal ui_intent(intent_id: String, payload: Dictionary)


func emit_ui_intent(intent_id: String, payload: Dictionary = {}) -> void:
	ui_intent.emit(intent_id, payload)
