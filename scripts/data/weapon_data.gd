class_name WeaponData
extends Resource

enum AttackKind {
	MELEE,
	RANGED,
	AOE,
}

@export var weapon_id: int = 0
@export var weapon_name: String = "Spear"
@export_enum("Melee", "Ranged", "AoE") var attack_kind: int = AttackKind.MELEE
@export_range(1.0, 256.0, 0.5) var range: float = 34.0
@export_range(0.1, 20.0, 0.05) var damage: float = 1.0
@export_range(0.1, 10.0, 0.05) var cooldown: float = 1.4
@export_range(0.1, 5.0, 0.05) var defense: float = 1.0
@export_range(0.0, 128.0, 0.5) var aoe_radius: float = 0.0
@export_range(0.0, 2000.0, 1.0) var projectile_speed: float = 380.0

@export var icon_texture: Texture2D
@export var projectile_texture: Texture2D
@export var attack_sound: AudioStream
@export var trail_color: Color = Color(0.82, 0.76, 0.42, 1.0)
@export_range(0.5, 8.0, 0.1) var trail_width: float = 2.2


func is_ranged() -> bool:
	return attack_kind == AttackKind.RANGED


func is_aoe() -> bool:
	return attack_kind == AttackKind.AOE or aoe_radius > 0.01


func to_profile(ranged_range_mult: float = 1.0) -> Dictionary:
	var uses_ranged_range: bool = attack_kind == AttackKind.RANGED or attack_kind == AttackKind.AOE
	var final_range: float = range * ranged_range_mult if uses_ranged_range else range
	var kind_label: String = "melee"
	if attack_kind == AttackKind.RANGED:
		kind_label = "ranged"
	elif attack_kind == AttackKind.AOE:
		kind_label = "aoe"
	return {
		"id": weapon_id,
		"name": weapon_name,
		"attack_kind": kind_label,
		"range": final_range,
		"damage": damage,
		"cooldown": cooldown,
		"defense": defense,
		"ranged": uses_ranged_range,
		"aoe_radius": aoe_radius,
		"projectile_speed": projectile_speed,
		"trail_color": trail_color,
		"trail_width": trail_width,
		"sound_path": "" if attack_sound == null else String(attack_sound.resource_path),
	}
