extends Node2D

const TILE_SIZE: int = 16
const MINIMAP_TILES: int = 96

const RES_NONE: int = 0
const RES_TREE: int = 1
const RES_STONE: int = 2
const RES_METAL: int = 7
const RES_APPLE: int = 3   # apple-bearing tree (plains/forest/berry thicket)
const RES_BERRY_BLUE: int = 4   # blueberry bush (marsh/berry thicket)
const RES_BERRY_RASP: int = 5   # raspberry bush (plains/hills/berry thicket)
const RES_BERRY_BLACK: int = 6  # blackberry bush (hills/forest/berry thicket)
const JOB_FARM: int = 0
const JOB_LUMBER: int = 1
const JOB_STONE: int = 2
const JOB_HUNT: int = 3
const JOB_SCOUT: int = 4
const HOUSE_CAPACITY: int = 2
const MANOR_CAPACITY: int = 6
const MANOR_FOOTPRINT: int = 2

# Wildlife types
const ANIMAL_DEER: int = 0
const ANIMAL_WOLF: int = 1
const ANIMAL_BEAR: int = 2
const FOOD_MIN_HARVEST: float = 0.15

const WEAPON_SPEAR: int = 0
const WEAPON_SHIELD: int = 1
const WEAPON_BOW: int = 2
const WEAPON_JAVELIN: int = 3

const TOOL_HAND: int = 0
const TOOL_AXE: int = 1
const TOOL_PICK: int = 2
const TOOL_SCYTHE: int = 3
const TOOL_MODE_AUTO: int = 0
const TOOL_MODE_LOCKED: int = 1
const TOOL_STATE_SAVE_PATH: String = "user://tool_state.json"
const TOOL_STATE_VERSION: int = 1
const TOOL_CRAFT_RECIPES: Dictionary = {
	"axe": {"lumber": 16.0, "metal": 4.0},
	"pick": {"lumber": 12.0, "metal": 6.0},
	"scythe": {"lumber": 14.0, "metal": 5.0},
}
const THINK_EXECUTING: int = 0
const THINK_THINKING: int = 1
const THINK_BLOCKED: int = 2
const BATCH_SPRITE_CIRCLE: int = 0
const BATCH_SPRITE_SQUARE: int = 1
const BATCH_SPRITE_DIAMOND: int = 2

const UI_BG := Color(0.06, 0.09, 0.12, 0.94)
const UI_BG_ALT := Color(0.1, 0.14, 0.18, 0.94)
const UI_BORDER := Color(0.36, 0.56, 0.66, 0.92)
const UI_TEXT_ACCENT := Color(0.86, 0.95, 1.0, 1.0)
const MAP_STRUCTURE_OUTLINE := Color(0.05, 0.05, 0.07, 0.95)

const SETTLER_NAMES: PackedStringArray = [
	"Aldric", "Bera", "Cai", "Dwyn", "Elva", "Finn", "Gara", "Holt",
	"Idris", "Jena", "Kael", "Lyra", "Mord", "Nara", "Osric", "Petra",
	"Quen", "Reva", "Sorn", "Tala", "Uren", "Vael", "Wren", "Xan",
	"Yara", "Zeth", "Amon", "Brix", "Cora", "Dael", "Elin", "Fern",
	"Gwin", "Hael", "Iola", "Jorn", "Kira", "Lund", "Mira", "Noel",
	"Orin", "Pell", "Quel", "Runa", "Sael", "Tove", "Ula", "Vern",
]

@onready var _agents: AgentSystem = $AgentSystem
@onready var _label: Label = $UI/Label
@onready var _ui_layer: CanvasLayer = $UI
@onready var _camera: Camera2D = $Camera2D

const WEAPON_EDITOR_SCENE: PackedScene = preload("res://scenes/weapon_editor/weapon_editor.tscn")
const UPGRADE_VFX_SYSTEM_SCRIPT: GDScript = preload("res://scripts/systems/upgrade_vfx_system.gd")

@export var run_10k_settler_stress_test: bool = true
@export_range(1000, 50000, 500) var stress_test_settler_target: int = 400
@export var enable_global_settler_log: bool = true
@export var global_settler_log_path: String = "user://settler_global_log.csv"
@export_range(0.1, 10.0, 0.1) var global_settler_log_flush_sec: float = 0.5
@export_range(1.0, 60.0, 0.5) var global_settler_snapshot_sec: float = 5.0
@export_range(1000, 200000, 1000) var global_settler_log_max_buffered_lines: int = 30000
@export var show_performance_debug_panel: bool = true
@export_range(0.1, 2.0, 0.05) var performance_debug_refresh_sec: float = 0.25
@export_range(0.1, 5.0, 0.1) var minimap_update_interval_sec: float = 1.0
@export_range(0.1, 5.0, 0.1) var fog_reveal_update_interval_sec: float = 1.0
@export_range(0.1, 3.0, 0.05) var settler_idle_think_interval_sec: float = 0.75
@export_range(0.2, 5.0, 0.05) var settler_active_think_interval_sec: float = 2.0
@export_range(0.0, 1.0, 0.01) var settler_think_jitter_sec: float = 0.2
@export var show_settler_thinking_indicator: bool = true
@export_range(2.0, 32.0, 1.0) var settler_arrival_rethink_distance_px: float = 10.0
@export_range(0.1, 5.0, 0.1) var settler_stuck_rethink_sec: float = 1.0
@export_range(0.01, 4.0, 0.01) var settler_min_progress_px: float = 0.2
@export_range(10, 2000, 10) var settler_decision_budget_per_tick: int = 120
@export_range(30, 144, 1) var pathfinding_target_fps: int = 60
@export_range(0.05, 1.0, 0.01) var pathfinding_min_budget_ratio: float = 0.18
@export_range(0.2, 1.0, 0.01) var dawn_dusk_budget_ratio: float = 0.55
@export_range(0.005, 0.08, 0.005) var dawn_dusk_window_day_fraction: float = 0.02
@export var offscreen_decision_throttle_enabled: bool = true
@export_range(1, 16, 1) var offscreen_decision_stride: int = 4
@export_range(1, 16, 1) var offscreen_night_planning_stride: int = 2
@export_range(0.0, 12.0, 0.1) var morning_dispatch_spread_sec: float = 4.0
@export_range(1, 512, 1) var morning_dispatch_pathfind_budget_per_frame: int = 28
@export_range(8.0, 80.0, 1.0) var hunter_wander_radius_tiles: float = 22.0
@export_range(0.5, 6.0, 0.1) var hunter_boost_duration_sec: float = 2.0
@export_range(1.0, 10.0, 0.1) var hunter_rest_duration_sec: float = 5.0
@export_range(1.05, 3.0, 0.05) var hunter_boost_speed_mult: float = 1.75
@export_range(0.0, 1.0, 0.05) var hunter_rest_speed_mult: float = 0.0
@export_range(2.0, 24.0, 1.0) var hunter_group_spacing_px: float = 8.0
@export_range(1.0, 25.0, 0.25) var resource_node_yield_mult: float = 6.0
@export_range(0.1, 1.0, 0.05) var tool_harvest_secondary_strength: float = 0.65
@export_range(0.1, 1.0, 0.05) var tool_combat_secondary_strength: float = 0.55
@export_range(0.05, 0.5, 0.01) var settler_combat_tick_sec: float = 0.15
@export_range(1, 16, 1) var max_attackers_per_wildlife_target: int = 4
@export_range(100, 3000, 50) var combat_action_log_cooldown_msec: int = 700
@export_range(10, 4000, 10) var auto_tool_assign_budget_per_tick: int = 220
@export_range(1, 1000, 1) var night_planning_budget_per_tick: int = 120
@export_range(2, 32, 1) var settler_route_segment_tiles: int = 10
@export_range(8, 64, 4) var world_chunk_tiles: int = 24
@export_range(64, 4096, 64) var world_chunk_cache_max_entries: int = 768
@export_range(1, 32, 1) var world_chunk_rebuild_budget_per_frame: int = 3
@export_range(0.1, 10.0, 0.1) var world_chunk_streaming_ms_budget: float = 1.2
@export_range(0.1, 5.0, 0.1) var world_chunk_prune_interval_sec: float = 0.5
@export_range(32, 4096, 32) var world_chunk_prune_scan_budget_per_pass: int = 512
@export_range(64, 10000, 32) var resource_icon_batch_budget_per_frame: int = 1800
@export_range(8, 4096, 8) var resource_reload_budget_per_pass: int = 384

var _target: Vector2 = Vector2.ZERO
var _world_seed: int = 912713

var _vision_radius: int = 4
var _watchtower_radius: int = 8
var _auto_watchtowers: bool = false
var _max_watchtowers: int = 20
var _watchtowers: Array[Vector2i] = []
var _explored: Dictionary = {}

var _resource_remaining: Dictionary = {}
var _resource_remaining_id: Dictionary = {}  # tile_id -> amount (hot-path lookup)
var _berry_overnight_regrow_due: Dictionary = {}  # tile_key -> seconds until full overnight regrow (berries + trees)
var _harvest_tick: float = 0.0
var _resource_regrow_tick: float = 0.0
var _ai_tick: float = 0.0
var _cook_tick: float = 0.0  # cooking accumulator (ticks every 4s per housed settler)
var _tree_yield_mult: float = 1.0
var _stone_yield_mult: float = 1.0
var _metal_yield_mult: float = 1.0
var _metal_mining_unlocked: bool = false
var _convert_mult: float = 1.0
var _day_time: float = 0.22
var _day_length_seconds: float = 150.0

var _resources := {
	"food": 0.0,
	"lumber": 0.0,
	"stone": 0.0,
	"metal_ore": 0.0,
	"metal": 0.0,
}

var _buildings := {
	"camp": 1,
	"house": 0,
	"manor": 0,
	"sawmill": 0,
	"quarry": 0,
	"workshop": 0,
	"storehouse": 0,
	"armory": 0,
	"scout_lodge": 0,
}

var _camp_tile: Vector2i = Vector2i.ZERO
var _house_tiles: Array[Vector2i] = []
var _manor_origins: Array[Vector2i] = []
var _sawmill_tiles: Array[Vector2i] = []
var _quarry_tiles: Array[Vector2i] = []
var _workshop_tiles: Array[Vector2i] = []
var _storehouse_tiles: Array[Vector2i] = []
var _armory_tiles: Array[Vector2i] = []
var _scout_lodge_tiles: Array[Vector2i] = []
var _outpost_tiles: Array[Vector2i] = []
var _settler_homes: PackedInt32Array
var _job_counts := {
	"farm": 0,
	"lumber": 1,
	"stone": 0,
	"hunt": 0,
	"scout": 0,
}
var _job_count_labels: Dictionary = {}
var _job_reassign_cursor: int = 0

const BUILDING_RECIPES := {
	"House": {"id": "house", "cost": {"lumber": 22.0}},
	"Manor": {"id": "manor", "cost": {"lumber": 48.0, "metal": 8.0}},
	"Sawmill": {"id": "sawmill", "cost": {"lumber": 35.0}},
	"Quarry": {"id": "quarry", "cost": {"lumber": 30.0}},
	"Refinery": {"id": "workshop", "cost": {"lumber": 40.0, "stone": 18.0}},
	"Storehouse": {"id": "storehouse", "cost": {"lumber": 55.0, "metal": 25.0}},
	"Armory": {"id": "armory", "cost": {"lumber": 60.0, "stone": 40.0, "metal": 18.0}},
	"Scout Lodge": {"id": "scout_lodge", "cost": {"lumber": 52.0, "stone": 22.0, "metal": 10.0}},
}

const POP_ACTIONS := {
	"recruit": {"name": "Recruit Settler", "effect": "+1 colonist (requires available housing)", "cost": {"food": 26.0}},
	"house": {"name": "Build House", "effect": "+2 housing (settlers return nightly)", "cost": {"lumber": 20.0}},
}

const UPGRADE_DATA := {
	"Volume": [
		{"id": "vol_lumber", "name": "Timber Crews", "effect": "Tree harvest +42% per rank", "cost": {"lumber": 42.0}, "max_rank": 5, "cost_scale": 1.68},
		{"id": "vol_stone", "name": "Heavy Picks", "effect": "Stone harvest +42% per rank", "cost": {"lumber": 34.0, "stone": 18.0}, "max_rank": 5, "cost_scale": 1.68},
		{"id": "vol_geology", "name": "Geologist Teams", "effect": "Unlock metal mining, then +30% stone and +22% metal per rank", "cost": {"lumber": 28.0, "stone": 14.0}, "max_rank": 4, "cost_scale": 1.68},
		{"id": "vol_forage", "name": "Foraging Baskets", "effect": "Food gather +36% per rank", "cost": {"food": 10.0, "lumber": 30.0}, "max_rank": 4, "cost_scale": 1.73},
		{"id": "vol_hoard", "name": "Hoarding Cellars", "effect": "Storehouse output +84%, but -8% happiness gain", "cost": {"lumber": 48.0, "metal": 14.0}, "max_rank": 3, "cost_scale": 1.84},
	],
	"Efficiency": [
		{"id": "eff_speed", "name": "Road Kits", "effect": "Colonist speed +21% per rank", "cost": {"lumber": 52.0}, "max_rank": 5, "cost_scale": 1.73},
		{"id": "eff_convert", "name": "Stone Saws", "effect": "Metal refining +60% per rank", "cost": {"lumber": 44.0, "stone": 28.0}, "max_rank": 4, "cost_scale": 1.79},
		{"id": "eff_quarry_ops", "name": "Quarry Logistics", "effect": "Passive quarry stone trickle +72% per rank", "cost": {"lumber": 30.0, "stone": 20.0}, "max_rank": 4, "cost_scale": 1.73},
		{"id": "eff_hearth", "name": "Camp Kitchens", "effect": "Unlock evening food cooking for housed settlers", "cost": {"food": 18.0, "lumber": 26.0}, "max_rank": 1, "cost_scale": 1.0},
		{"id": "eff_ration", "name": "Strict Rationing", "effect": "Food use -24%, but happiness drops faster", "cost": {"food": 20.0, "metal": 18.0}, "max_rank": 3, "cost_scale": 1.96},
		{"id": "eff_campfire", "name": "Campfire Stories", "effect": "Night happiness recovery +48%", "cost": {"food": 24.0, "lumber": 20.0}, "max_rank": 4, "cost_scale": 1.79},
	],
	"Specialization": [
		{"id": "spec_forestry", "name": "Forester Doctrine", "effect": "Adds a free Sawmill per rank", "cost": {"lumber": 84.0, "metal": 18.0}, "max_rank": 3, "cost_scale": 1.96},
		{"id": "spec_masonry", "name": "Mason Doctrine", "effect": "Adds a free Quarry per rank", "cost": {"lumber": 66.0, "metal": 24.0}, "max_rank": 3, "cost_scale": 1.96},
		{"id": "spec_hunting", "name": "Militia Drills", "effect": "Hunter food yield +30% per rank", "cost": {"food": 28.0, "lumber": 28.0}, "max_rank": 5, "cost_scale": 1.68},
		{"id": "spec_bravado", "name": "Bravado Culture", "effect": "Huge morale gain, but food consumption rises", "cost": {"food": 40.0, "lumber": 45.0}, "max_rank": 2, "cost_scale": 2.13},
	],
	"Vision & Exploration": [
		{"id": "vision_lenses", "name": "Surveyor Lenses", "effect": "Vision radius +1 per rank", "cost": {"lumber": 36.0}, "max_rank": 7, "cost_scale": 1.61},
		{"id": "vision_tower_net", "name": "Watchtower Network", "effect": "Enable watchtower placement", "cost": {"lumber": 70.0, "metal": 26.0}, "max_rank": 1, "cost_scale": 1.0},
		{"id": "vision_tower_range", "name": "Cartography Guild", "effect": "Watchtower radius +2 per rank", "cost": {"lumber": 90.0, "metal": 45.0}, "max_rank": 4, "cost_scale": 1.84},
		{"id": "vision_nightwatch", "name": "Moon Lanterns", "effect": "Brighter nights, wolves raid less often", "cost": {"food": 18.0, "lumber": 26.0}, "max_rank": 3, "cost_scale": 1.96},
	],
	"Scouting": [
		{"id": "scout_training", "name": "Pathfinder Training", "effect": "POI discovery radius +19% per rank", "cost": {"food": 24.0, "lumber": 34.0}, "max_rank": 4, "cost_scale": 1.73},
		{"id": "scout_survey", "name": "Survey Maps", "effect": "POI spawn interval -14% per rank", "cost": {"lumber": 40.0, "stone": 18.0}, "max_rank": 4, "cost_scale": 1.79},
		{"id": "scout_beacons", "name": "Signal Beacons", "effect": "POI discovery radius +10% per rank", "cost": {"lumber": 38.0, "metal": 14.0}, "max_rank": 4, "cost_scale": 1.73},
		{"id": "scout_salvage", "name": "Expedition Salvage", "effect": "POI rewards +21% per rank", "cost": {"food": 20.0, "lumber": 32.0}, "max_rank": 4, "cost_scale": 1.79},
	],
	"Defense": [
		{"id": "def_spears", "name": "Spear Wall", "effect": "Settler defense +12% per rank", "cost": {"lumber": 30.0, "stone": 18.0}, "max_rank": 5, "cost_scale": 1.68},
		{"id": "def_horns", "name": "Alarm Horns", "effect": "Night raids start with less wolf morale", "cost": {"lumber": 45.0, "metal": 20.0}, "max_rank": 3, "cost_scale": 1.84},
		{"id": "def_training", "name": "Shield Drills", "effect": "Settlers lose less happiness when hungry", "cost": {"food": 22.0, "stone": 20.0}, "max_rank": 4, "cost_scale": 1.79},
	],
	"Combat": [
		{"id": "cmb_armory", "name": "War Foundry", "effect": "Adds 1 free Armory per rank for weapon logistics", "cost": {"lumber": 88.0, "stone": 60.0}, "max_rank": 3, "cost_scale": 1.90},
		{"id": "cmb_shields", "name": "Shield Corps", "effect": "Unlock shield units: high defense, lower damage", "cost": {"lumber": 46.0, "stone": 36.0}, "max_rank": 1, "cost_scale": 1.0},
		{"id": "cmb_bowcraft", "name": "Bowyer Guild", "effect": "Unlock bow units: long range, reduced defense", "cost": {"lumber": 54.0, "food": 22.0}, "max_rank": 3, "cost_scale": 1.84},
		{"id": "cmb_javelin", "name": "Skirmisher Kits", "effect": "Unlock javelin units: burst ranged, slower cadence", "cost": {"lumber": 52.0, "stone": 34.0}, "max_rank": 2, "cost_scale": 1.84},
		{"id": "cmb_steel", "name": "Tempered Steel", "effect": "Melee damage +19% per rank", "cost": {"lumber": 42.0, "stone": 24.0}, "max_rank": 4, "cost_scale": 1.73},
		{"id": "cmb_drills", "name": "Squad Drills", "effect": "Better same-weapon cohesion per rank", "cost": {"food": 30.0, "lumber": 38.0}, "max_rank": 4, "cost_scale": 1.73},
	],
}

var _purchased_upgrades: Dictionary = {}
var _upgrade_ranks: Dictionary = {}

var _upgrade_panel: PanelContainer
var _upgrade_toggle: Button
var _panel_open: bool = false
var _drawer_width: float = 680.0
var _upgrade_category_btns: Dictionary = {}   # cat_name -> Button
var _upgrade_content_col: VBoxContainer       # replaced on category switch
var _upgrade_content_scroll: ScrollContainer  # right-side scroll
var _active_category: String = ""
var _debug_panel_toggle_btn: Button

var _resource_labels: Dictionary = {}
var _resource_job_labels: Dictionary = {}
var _building_labels: Dictionary = {}
var _status_label: Label
var _workshop_toggle_btn: Button
var _fast_recruit_btn: Button
var _fast_house_btn: Button
var _tool_stock_label: Label
var _craft_tool_btns: Dictionary = {}
var _tool_shortage_notice_msec: int = -999999
var _hovered_agent_idx: int = -1
var _pinned_agent_idx: int = -1
var _hover_probe_radius_px: float = 12.0
var _hover_panel: PanelContainer
var _hover_title_label: Label
var _hover_body_label: RichTextLabel
var _tool_mode_btn: Button
var _agent_recent_actions: Dictionary = {}
var _agent_last_state: Dictionary = {}
var _resource_mgr: ResourceManager = ResourceManager.new()
var _settler_resource_targets: Dictionary = {}  # index -> Vector2i, cached resource tile
var _resource_claims: Dictionary = {}  # tile_key -> settler index
var _settler_day_plan_targets: Dictionary = {}  # index -> Vector2i planned destination for next day
var _settler_day_plan_job: Dictionary = {}      # index -> int job id used when plan was created
var _settler_job_overrides: Dictionary = {}  # index -> int, per-settler job override
var _settler_names: Array[String] = []  # index -> name
var _job_btn_row: HBoxContainer
var _tool_btn_row: HBoxContainer

var _poi_sites: Array[Dictionary] = []
var _poi_spawn_tick: float = 0.0
var _poi_offer_active: bool = false
var _poi_offer: Dictionary = {}
var _max_poi_sites: int = 2
var _poi_panel: PanelContainer
var _poi_title_label: Label
var _poi_body_label: Label

# Wildlife: each entry is {type, pos, vel, hp, max_hp, state, target_pos, attack_cd, flee_cd}
var _wildlife: Array[Dictionary] = []
var _wildlife_spawn_tick: float = 0.0
var _hunter_attack_anims: Array[Dictionary] = []  # {from, to, t, dur} spear flash VFX
var _wildlife_query_grid: Dictionary = {}
var _wildlife_wolf_query_grid: Dictionary = {}
var _wildlife_hostile_query_grid: Dictionary = {}
var _wildlife_query_min_cell: Vector2i = Vector2i.ZERO
var _wildlife_query_max_cell: Vector2i = Vector2i.ZERO

var _minimap_rect: TextureRect
var _minimap_texture: ImageTexture
var _minimap_image: Image
var _minimap_accum: float = 0.0
var _fog_reveal_accum: float = 0.0
var _minimap_scale: float = 2.6
var _world_chunk_textures: Dictionary = {}   # chunk_key -> ImageTexture
var _world_chunk_dirty: Dictionary = {}      # chunk_key -> bool
var _world_chunk_last_used: Dictionary = {}  # chunk_key -> frame
var _world_chunk_rebuild_queue: Array[Vector2i] = []
var _world_chunk_rebuild_queue_head: int = 0
var _world_chunk_rebuild_queued: Dictionary = {}
var _world_chunk_prune_accum: float = 0.0
var _resource_type_cache: Dictionary = {}
var _resource_initial_amount_cache: Dictionary = {}
var _resource_food_tiles: Array[Vector2i] = []
var _resource_tree_tiles: Array[Vector2i] = []
var _resource_stone_tiles: Array[Vector2i] = []
var _resource_metal_tiles: Array[Vector2i] = []
var _resource_food_pos: Dictionary = {}
var _resource_tree_pos: Dictionary = {}
var _resource_stone_pos: Dictionary = {}
var _resource_metal_pos: Dictionary = {}
var _resource_food_chunk_tiles: Dictionary = {}
var _resource_tree_chunk_tiles: Dictionary = {}
var _resource_stone_chunk_tiles: Dictionary = {}
var _resource_metal_chunk_tiles: Dictionary = {}
var _resource_food_tile_chunk: Dictionary = {}
var _resource_tree_tile_chunk: Dictionary = {}
var _resource_stone_tile_chunk: Dictionary = {}
var _resource_metal_tile_chunk: Dictionary = {}
var _resource_reload_queue: Array[Vector2i] = []
var _resource_reload_queue_head: int = 0
var _resource_reload_queued: Dictionary = {}

var _upgrade_vfx_system = UPGRADE_VFX_SYSTEM_SCRIPT.new()
var _upgrade_marker_system: UpgradeMarkerSystem = UpgradeMarkerSystem.new()
var _floating_text_system: FloatingTextSystem = FloatingTextSystem.new()
var _collection_particles_system: CollectionParticlesSystem = CollectionParticlesSystem.new()
var _render_batch_system: RenderBatchSystem = RenderBatchSystem.new()
var _audio_stream_cache: Dictionary = {}
var _camera_base_pos: Vector2
var _camera_kick: Vector2 = Vector2.ZERO
var _rng := RandomNumberGenerator.new()
var _camera_dragging: bool = false
var _camera_drag_last_mouse: Vector2 = Vector2.ZERO

var _food_consume_per_settler: float = 0.025
var _food_consume_mult: float = 1.0
var _food_consume_tick: float = 0.0
var _food_gather_mult: float = 1.0
var _storehouse_mult: float = 1.0
var _settler_mgr: SettlerManager = SettlerManager.new()
var _settler_decision_system: SettlerDecisionSystem = SettlerDecisionSystem.new()
var _economy_system: EconomySystem = EconomySystem.new()
var _wildlife_system: WildlifeSystem = WildlifeSystem.new()
var _combat_system: CombatSystem = CombatSystem.new()
var _settler_happiness: PackedFloat32Array
var _happiness_gain_mult: float = 1.0
var _happiness_loss_mult: float = 1.0
var _hunting_yield_mult: float = 1.0
var _night_cooking_unlocked: bool = false
var _food_shortage_streak_sec: float = 0.0
var _settler_starvation_time: PackedFloat32Array
var _settler_attack_cooldowns: PackedFloat32Array
var _settler_combat_tick_accum: float = 0.0
var _settler_last_combat_log_msec: Dictionary = {}
var _settler_attack_speed_mult: float = 1.0
var _settler_combat_damage_mult: float = 1.0
var _settler_weapons: PackedInt32Array
var _settler_tools: PackedInt32Array
var _settler_tool_modes: PackedInt32Array
var _settler_next_think_time: PackedFloat32Array
var _settler_think_state: PackedInt32Array
var _settler_last_pos: PackedVector2Array
var _settler_idle_time: PackedFloat32Array
var _settler_due_buckets: Dictionary = {}
var _settler_due_versions: PackedInt32Array
var _settler_due_next_bucket_key: int = 0
var _weapon_cluster_strength: float = 0.14
var _melee_damage_mult: float = 1.0
var _ranged_damage_mult: float = 1.0
var _ranged_range_mult: float = 1.0
var _settler_defense_mult: float = 1.0
var _weapon_bow_unlocked: bool = false
var _weapon_javelin_unlocked: bool = false
var _weapon_shield_unlocked: bool = false
var _weapon_registry: Dictionary = {}  # weapon_id -> WeaponData
var _weapon_editor_panel: WeaponEditorPanel
var _poi_spawn_interval_mult: float = 1.0
var _poi_discovery_radius: float = 18.0
var _poi_reward_mult: float = 1.0

var _was_night: bool = false
var _day_index: int = 0
var _first_night_event_done: bool = false
var _wolf_raid_active: bool = false
var _wolf_next_raid_day: int = 3
var _wolf_raid_interval_days: int = 3
var _wolf_raid_size_mult: float = 1.0
var _night_visual_boost: float = 0.0
var _night_overlay_reduction: float = 0.0
var _raid_warning_active: bool = false
var _raid_warning_timer: float = 0.0
var _raid_warning_duration: float = 5.0
var _quarry_passive_mult: float = 1.0
var _pending_wolf_spawn_count: int = 0
var _pending_bear_spawn_count: int = 0
var _combat_neglect_streak: int = 0
var _razes_this_night: int = 0
var _max_razes_per_night: int = 1
var _structure_raze_cooldown: float = 0.0

var _howl_player: AudioStreamPlayer
var _howl_stream: AudioStreamGenerator
var _workshop_paused: bool = false
var _refinery_smelt_activity: float = 0.0
var _refinery_glow_intensity: float = 0.0
var _refinery_smoke_particles: Array[Dictionary] = []
var _global_settler_log_lines: Array[String] = []
var _global_settler_log_flush_accum: float = 0.0
var _global_settler_snapshot_accum: float = 0.0
var _global_settler_log_drop_count: int = 0
var _global_settler_log_active: bool = false
var _tool_inventory: Dictionary = {"axe": 0, "pick": 0, "scythe": 0}
var _tool_state_dirty: bool = false
var _tool_state_save_accum: float = 0.0
var _auto_tool_assign_pending: bool = false
var _auto_tool_assign_cursor: int = 0
var _tracked_agent_count: int = -1
var _settler_weapons_dirty: bool = true
var _settler_decisions_this_tick: int = 0
var _settler_decision_cursor: int = 0
var _perf_panel: PanelContainer
var _perf_label: RichTextLabel
var _perf_refresh_accum: float = 0.0
var _perf_last_frame_ms: float = 0.0
var _perf_frame_avg_ms: float = 0.0
var _perf_frame_max_ms: float = 0.0
var _perf_frame_samples: int = 0
var _perf_stats: Dictionary = {}
var _settler_decision_tick_counter: int = 0
var _pathfind_budget_effective: int = 1
var _morning_dispatch_cursor: int = -1
var _morning_dispatch_active: bool = false
var _hunter_shared_wander_target: Vector2 = Vector2.ZERO
var _hunter_wander_retarget_at: float = 0.0
var _hunter_boost_until: Dictionary = {}
var _hunter_rest_until: Dictionary = {}
var _hunter_runtime_state: Dictionary = {}
var _hunter_recent_enemy_focus: Vector2 = Vector2.ZERO
var _hunter_enemy_focus_until: float = 0.0
var _active_indicator_settlers: PackedInt32Array
var _active_indicator_settlers_dirty: bool = true
var _active_indicator_settler_pos: Dictionary = {}
var _active_indicator_population_count: int = -1
var _agent_speed_multipliers: PackedFloat32Array
var _agent_job_colors: PackedColorArray
var _agent_job_colors_dirty: bool = true
var _settler_decision_run_state: Dictionary = {}
var _settler_candidate_seen: PackedByteArray = PackedByteArray()
var _settler_capacity_ignore: PackedByteArray = PackedByteArray()


func _ready() -> void:
	_rng.randomize()
	_camera.enabled = true
	_camera_base_pos = _camera.position
	_settler_resource_targets = _resource_mgr.settler_resource_targets
	_resource_claims = _resource_mgr.resource_claims
	_settler_day_plan_targets = _resource_mgr.settler_day_plan_targets
	_settler_day_plan_job = _resource_mgr.settler_day_plan_job

	if _agents.agent_count < 1:
		_agents.agent_count = 1
	_agents.set_external_batch_render_enabled(true)

	_bootstrap_10k_stress_test()
	_init_global_settler_log()

	var agents: PackedVector2Array = _agents.get_agent_positions()
	if agents.size() > 0:
		_target = agents[0]
	else:
		_target = Vector2.ZERO
	_camp_tile = _world_to_tile(_target)
	_agents.set_target(_target)

	_resources["food"] = 42.0
	_resources["lumber"] = 30.0
	_resources["stone"] = 8.0
	_resources["metal_ore"] = 0.0
	_resources["metal"] = 0.0
	_recompute_homes()
	_load_weapon_registry()
	_sync_agent_tracking()
	_load_tool_state()
	_distribute_jobs_evenly()
	_sync_agent_render_bounds()

	_reveal_around_world(_target, 6)
	_rebuild_resource_indices()
	_sync_resource_remaining_ids()
	_sync_resource_claim_ids()
	_init_settler_decision_run_state()
	_setup_howl_audio()

	_build_resource_ui()
	_build_minimap_ui()
	_build_upgrade_ui()
	_build_hover_ui()
	_build_poi_ui()
	_build_performance_debug_ui()
	_build_weapon_editor_ui()
	_spawn_initial_pois()
	_was_night = _is_night()

	queue_redraw()


func _setup_howl_audio() -> void:
	_howl_player = AudioStreamPlayer.new()
	_howl_stream = AudioStreamGenerator.new()
	_howl_stream.mix_rate = 22050.0
	_howl_stream.buffer_length = 1.2
	_howl_player.stream = _howl_stream
	_howl_player.volume_db = -7.5
	add_child(_howl_player)


func _play_howl_warning() -> void:
	if _howl_player == null or _howl_stream == null:
		return
	_howl_player.play()
	var playback := _howl_player.get_stream_playback() as AudioStreamGeneratorPlayback
	if playback == null:
		return
	var mix_rate: float = _howl_stream.mix_rate
	var total_frames: int = int(mix_rate * 0.95)
	var frames_avail: int = playback.get_frames_available()
	var frames_to_push: int = mini(total_frames, frames_avail)
	for i in frames_to_push:
		var t: float = float(i) / mix_rate
		var p: float = t / 0.95
		var env: float = 0.0
		if p < 0.2:
			env = p / 0.2
		elif p > 0.82:
			env = (1.0 - p) / 0.18
		else:
			env = 1.0
		env = clampf(env, 0.0, 1.0)
		var glide: float = sin(t * 2.0)
		var freq: float = 240.0 + 75.0 * glide
		var vibrato: float = sin(TAU * 5.5 * t) * 0.05
		var sample: float = sin(TAU * (freq * (1.0 + vibrato)) * t) * env * 0.34
		playback.push_frame(Vector2(sample, sample))


func _process(delta: float) -> void:
	var frame_start_us: int = Time.get_ticks_usec()
	var step_start_us: int = Time.get_ticks_usec()
	_sync_agent_render_bounds()
	_perf_record_step("sync_agent_render_bounds", step_start_us)
	step_start_us = Time.get_ticks_usec()
	_sync_agent_tracking()
	_perf_record_step("sync_agent_tracking", step_start_us)
	step_start_us = Time.get_ticks_usec()
	_process_auto_tool_assignments()
	_perf_record_step("auto_tool_assign_budgeted", step_start_us)
	step_start_us = Time.get_ticks_usec()
	_refresh_settler_weapons_if_dirty()
	_perf_record_step("refresh_settler_weapons", step_start_us)
	step_start_us = Time.get_ticks_usec()
	_update_day_cycle(delta)
	_perf_record_step("update_day_cycle", step_start_us)
	step_start_us = Time.get_ticks_usec()
	_process_resource_reload_queue()
	_perf_record_step("process_resource_reload_queue_pre_ai", step_start_us)
	step_start_us = Time.get_ticks_usec()
	_process_morning_dispatch_queue()
	_perf_record_step("process_morning_dispatch_queue", step_start_us)
	step_start_us = Time.get_ticks_usec()
	_update_raid_warning(delta)
	_perf_record_step("update_raid_warning", step_start_us)
	step_start_us = Time.get_ticks_usec()
	_update_settler_targets(delta)
	_perf_record_step("update_settler_targets", step_start_us)
	step_start_us = Time.get_ticks_usec()
	_update_global_settler_log(delta)
	_perf_record_step("update_global_settler_log", step_start_us)
	step_start_us = Time.get_ticks_usec()
	_update_poi_system(delta)
	_perf_record_step("update_poi_system", step_start_us)
	step_start_us = Time.get_ticks_usec()
	_update_hovered_agent()
	_perf_record_step("update_hovered_agent", step_start_us)
	step_start_us = Time.get_ticks_usec()
	_update_economy(delta)
	_perf_record_step("update_economy", step_start_us)
	step_start_us = Time.get_ticks_usec()
	_process_resource_reload_queue()
	_perf_record_step("process_resource_reload_queue_post_econ", step_start_us)
	step_start_us = Time.get_ticks_usec()
	_upgrade_vfx_system.update(delta)
	_perf_record_step("update_upgrade_bursts", step_start_us)
	step_start_us = Time.get_ticks_usec()
	_floating_text_system.update(delta)
	_perf_record_step("update_floating_texts", step_start_us)
	step_start_us = Time.get_ticks_usec()
	_collection_particles_system.update(delta)
	_perf_record_step("update_collection_particles", step_start_us)
	step_start_us = Time.get_ticks_usec()
	_update_refinery_vfx(delta)
	_perf_record_step("update_refinery_vfx", step_start_us)
	step_start_us = Time.get_ticks_usec()
	_update_settler_combat_budgeted(delta)
	_perf_record_step("update_settler_combat", step_start_us)
	step_start_us = Time.get_ticks_usec()
	_update_camera_kick(delta)
	_perf_record_step("update_camera_kick", step_start_us)
	step_start_us = Time.get_ticks_usec()
	_update_wildlife(delta)
	_perf_record_step("update_wildlife", step_start_us)
	step_start_us = Time.get_ticks_usec()
	_process_world_chunk_streaming(delta)
	_perf_record_step("world_chunk_streaming", step_start_us)
	step_start_us = Time.get_ticks_usec()
	# Advance hunter attack anims
	for i in range(_hunter_attack_anims.size() - 1, -1, -1):
		_hunter_attack_anims[i]["t"] = float(_hunter_attack_anims[i]["t"]) + delta
		if float(_hunter_attack_anims[i]["t"]) >= float(_hunter_attack_anims[i]["dur"]):
			_hunter_attack_anims.remove_at(i)
	_perf_record_step("update_hunter_anims", step_start_us)
	step_start_us = Time.get_ticks_usec()
	_update_resource_ui()
	_perf_record_step("update_resource_ui", step_start_us)
	step_start_us = Time.get_ticks_usec()
	_update_hover_ui()
	_perf_record_step("update_hover_ui", step_start_us)
	step_start_us = Time.get_ticks_usec()
	_update_starvation_deaths(delta)
	_perf_record_step("update_starvation", step_start_us)
	step_start_us = Time.get_ticks_usec()
	_update_happiness(delta)
	_perf_record_step("update_happiness", step_start_us)
	step_start_us = Time.get_ticks_usec()
	_maybe_save_tool_state(delta)
	_perf_record_step("save_tool_state", step_start_us)
	step_start_us = Time.get_ticks_usec()

	_minimap_accum += delta
	if _minimap_accum >= minimap_update_interval_sec:
		_minimap_accum = 0.0
		_update_minimap()
	_perf_record_step("update_minimap_tick", step_start_us)
	step_start_us = Time.get_ticks_usec()

	_fog_reveal_accum += delta
	if _fog_reveal_accum >= fog_reveal_update_interval_sec:
		_fog_reveal_accum = 0.0
		var agents: PackedVector2Array = _agents.get_agent_positions()
		for i in agents.size():
			_reveal_around_world(agents[i], _vision_radius)
		for ot in _outpost_tiles:
			_reveal_around_tile(ot, 5)
	_perf_record_step("update_fog_reveal", step_start_us)
	step_start_us = Time.get_ticks_usec()

	var day_state: String = "Night" if _is_night() else "Day"
	_label.text = (
		"FPS: %d  |  %s (Day %d)  |  Food drain: %.2f/s  |  Avg happiness: %d%%\n"
		+ "LMB terrain set target  |  LMB settler pin  |  RMB drag camera  |  U upgrades"
	) % [
		Engine.get_frames_per_second(),
		day_state,
		_day_index,
		_agents.get_agent_count() * _food_consume_per_settler * _food_consume_mult,
		int(round(_average_happiness() * 100.0)),
	]

	queue_redraw()
	_perf_record_step("queue_redraw", step_start_us)
	_perf_end_frame(frame_start_us, delta)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_PREDELETE:
		_save_tool_state(true)


func _update_raid_warning(delta: float) -> void:
	if not _raid_warning_active:
		return
	_raid_warning_timer = maxf(0.0, _raid_warning_timer - delta)
	if _raid_warning_timer > 0.0:
		return
	_raid_warning_active = false
	_wolf_raid_active = true
	_spawn_predators_from_fog(_pending_wolf_spawn_count, _pending_bear_spawn_count)
	_spawn_floating_text(_tile_center(_camp_tile), "Predators emerge from the fog!", Color(1.0, 0.32, 0.3, 1.0))
	_night_visual_boost = minf(0.22, _night_visual_boost + 0.06)
	_pending_wolf_spawn_count = 0
	_pending_bear_spawn_count = 0


func _build_poi_ui() -> void:
	var ui_layer: CanvasLayer = $UI
	_poi_panel = PanelContainer.new()
	_poi_panel.position = Vector2(12.0, 260.0)
	_poi_panel.size = Vector2(300.0, 164.0)
	_poi_panel.visible = false
	ui_layer.add_child(_poi_panel)

	var style := StyleBoxFlat.new()
	style.bg_color = UI_BG_ALT
	style.border_color = UI_BORDER
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.corner_radius_top_left = 2
	style.corner_radius_top_right = 2
	style.corner_radius_bottom_left = 2
	style.corner_radius_bottom_right = 2
	_poi_panel.add_theme_stylebox_override("panel", style)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	_poi_panel.add_child(margin)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	margin.add_child(col)

	_poi_title_label = Label.new()
	_poi_title_label.text = "Point Of Interest"
	_poi_title_label.add_theme_font_size_override("font_size", 16)
	col.add_child(_poi_title_label)

	_poi_body_label = Label.new()
	_poi_body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_poi_body_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_poi_body_label.add_theme_font_size_override("font_size", 12)
	col.add_child(_poi_body_label)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	col.add_child(row)

	var accept := Button.new()
	accept.text = "Accept"
	accept.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	accept.pressed.connect(_on_poi_accept_pressed)
	row.add_child(accept)

	var decline := Button.new()
	decline.text = "Decline"
	decline.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	decline.pressed.connect(_on_poi_decline_pressed)
	row.add_child(decline)


func _spawn_initial_pois() -> void:
	for _i in 1:
		_try_spawn_poi()


func _update_poi_system(delta: float) -> void:
	if not _scouting_unlocked():
		return
	_poi_spawn_tick += delta
	var spawn_interval: float = _scouting_spawn_interval_seconds()
	if _poi_spawn_tick >= spawn_interval:
		_poi_spawn_tick = 0.0
		_try_spawn_poi()

	if _poi_offer_active:
		return

	var agents: PackedVector2Array = _agents.get_agent_positions()
	if agents.is_empty():
		return
	var scout_indexes: Array[int] = []
	for ai in agents.size():
		if _job_for_settler(ai) == JOB_SCOUT:
			scout_indexes.append(ai)
	if scout_indexes.is_empty():
		return

	for i in _poi_sites.size():
		var site: Dictionary = _poi_sites[i]
		if bool(site.get("resolved", false)):
			continue
		if bool(site.get("discovered", false)):
			continue
		var tile: Vector2i = site["tile"]
		var center: Vector2 = _tile_center(tile)
		for idx in scout_indexes:
			var p: Vector2 = agents[idx]
			if p.distance_to(center) <= _poi_discovery_radius:
				site["discovered"] = true
				_poi_sites[i] = site
				_open_poi_offer(i)
				return


func _try_spawn_poi() -> void:
	if not _scouting_unlocked():
		return
	var active_count: int = 0
	for site in _poi_sites:
		if not bool(site.get("resolved", false)):
			active_count += 1
	if active_count >= _effective_max_poi_sites():
		return
	var tile: Vector2i = _find_poi_spawn_tile()
	if tile == Vector2i(-9999, -9999):
		return
	var name_pool: Array[String] = ["Lost Caravan", "Collapsed Shrine", "Abandoned Camp", "Signal Beacon", "Buried Cache"]
	var site := {
		"tile": tile,
		"name": String(name_pool[_rng.randi() % name_pool.size()]),
		"discovered": false,
		"resolved": false,
	}
	_poi_sites.append(site)


func _find_poi_spawn_tile() -> Vector2i:
	var center: Vector2i = _camp_tile
	var agents: PackedVector2Array = _agents.get_agent_positions()
	if agents.size() > 0:
		center = _world_to_tile(agents[0])
	for _attempt in 90:
		var angle: float = _rng.randf() * TAU
		var dist: float = _rng.randf_range(28.0, 86.0)
		var tile := Vector2i(
			center.x + int(round(cos(angle) * dist)),
			center.y + int(round(sin(angle) * dist))
		)
		if _is_explored(tile):
			continue
		var blocked: bool = false
		for site in _poi_sites:
			if bool(site.get("resolved", false)):
				continue
			var st: Vector2i = site["tile"]
			if st.distance_to(tile) < 10.0:
				blocked = true
				break
		if blocked:
			continue
		return tile
	return Vector2i(-9999, -9999)


func _open_poi_offer(site_index: int) -> void:
	if site_index < 0 or site_index >= _poi_sites.size():
		return
	var site: Dictionary = _poi_sites[site_index]
	var day_boost: int = maxi(0, _day_index / 5)
	var colonists: int = 1 + int(_rng.randi() % 2)
	if _rng.randf() < 0.16 + day_boost * 0.015:
		colonists += 1
	var loot := {
		"food": (6.0 + _rng.randf_range(2.0, 7.0) + day_boost * 0.8) * _effective_poi_reward_mult(),
		"lumber": (6.0 + _rng.randf_range(1.0, 6.5) + day_boost * 0.55) * _effective_poi_reward_mult(),
		"stone": (3.0 + _rng.randf_range(1.0, 6.0) + day_boost * 0.5) * _effective_poi_reward_mult(),
		"metal_ore": (_rng.randf_range(0.0, 2.2) + day_boost * 0.25) * _effective_poi_reward_mult(),
	}
	var outpost_chance: float = clampf(0.16 + float(_day_index) * 0.008, 0.16, 0.42)
	_poi_offer = {
		"site_index": site_index,
		"colonists": colonists,
		"loot": loot,
		"outpost_chance": outpost_chance,
	}
	_poi_offer_active = true
	if _poi_panel != null:
		_poi_title_label.text = String(site["name"])
		_poi_body_label.text = (
			"Scouts reached a destination in the wild.\n"
			+ "Possible survivors: +%d\n"
			+ "Potential loot: %.0f food, %.0f lumber, %.0f stone, %.0f ore\n"
			+ "Chance to establish an outpost: %d%%"
		) % [
			int(_poi_offer["colonists"]),
			float(loot["food"]),
			float(loot["lumber"]),
			float(loot["stone"]),
			float(loot["metal_ore"]),
			int(round(outpost_chance * 100.0)),
		]
		_poi_panel.visible = true
	_spawn_floating_text(_tile_center(_camp_tile), "POI discovered: %s" % String(site["name"]), Color(0.52, 0.95, 0.88, 1.0))


func _on_poi_accept_pressed() -> void:
	if not _poi_offer_active:
		return
	var site_index: int = int(_poi_offer.get("site_index", -1))
	if site_index < 0 or site_index >= _poi_sites.size():
		_poi_offer_active = false
		if _poi_panel != null:
			_poi_panel.visible = false
		return
	var site: Dictionary = _poi_sites[site_index]
	if bool(site.get("resolved", false)):
		_poi_offer_active = false
		if _poi_panel != null:
			_poi_panel.visible = false
		return

	var loot: Dictionary = _poi_offer["loot"]
	for key in ["food", "lumber", "stone", "metal_ore"]:
		_resources[key] += float(loot[key])

	var rescued: int = int(_poi_offer.get("colonists", 0))
	var capacity_left: int = _housing_capacity() - _agents.get_agent_count()
	if capacity_left <= 0:
		rescued = 0
	else:
		rescued = mini(rescued, capacity_left)
	if rescued > 0:
		var old_count: int = _agents.get_agent_count()
		_agents.add_agents(rescued, _tile_center(_camp_tile))
		_recompute_homes()
		_clamp_job_counts()
		_sync_agent_tracking()
		for k in rescued:
			_record_agent_action(old_count + k, "Joined from expedition")

	if _rng.randf() < float(_poi_offer.get("outpost_chance", 0.0)):
		var ot: Vector2i = site["tile"]
		if not _outpost_tiles.has(ot):
			_outpost_tiles.append(ot)
			_reveal_around_tile(ot, 6)
			_spawn_floating_text(_tile_center(ot), "Outpost established", Color(0.48, 0.84, 1.0, 1.0))

	site["resolved"] = true
	_poi_sites[site_index] = site
	_poi_offer_active = false
	if _poi_panel != null:
		_poi_panel.visible = false
	_spawn_floating_text(_tile_center(_camp_tile), "Expedition returns with loot", Color(0.95, 0.9, 0.38, 1.0))


func _on_poi_decline_pressed() -> void:
	if not _poi_offer_active:
		return
	var site_index: int = int(_poi_offer.get("site_index", -1))
	if site_index >= 0 and site_index < _poi_sites.size():
		var site: Dictionary = _poi_sites[site_index]
		site["resolved"] = true
		_poi_sites[site_index] = site
	_poi_offer_active = false
	if _poi_panel != null:
		_poi_panel.visible = false
	_spawn_floating_text(_tile_center(_camp_tile), "Expedition moved on", Color(0.72, 0.82, 0.9, 1.0))


func _draw() -> void:
	var draw_step_us: int = Time.get_ticks_usec()
	_draw_world_tiles()
	_perf_record_step("draw_world_tiles", draw_step_us)
	_render_batch_system.begin_frame()
	draw_step_us = Time.get_ticks_usec()
	_draw_refinery_vfx()
	_perf_record_step("draw_refinery_vfx", draw_step_us)
	draw_step_us = Time.get_ticks_usec()
	_draw_night_fx()
	_perf_record_step("draw_night_fx", draw_step_us)
	draw_step_us = Time.get_ticks_usec()
	_draw_watchtowers()
	_perf_record_step("draw_watchtowers", draw_step_us)
	draw_step_us = Time.get_ticks_usec()
	_queue_sprite_batch()
	_render_batch_system.draw_to(self)
	_perf_record_step("draw_sprite_batch", draw_step_us)
	draw_step_us = Time.get_ticks_usec()
	draw_step_us = Time.get_ticks_usec()
	_draw_hunter_anims()
	_perf_record_step("draw_hunter_anims", draw_step_us)
	draw_step_us = Time.get_ticks_usec()
	_floating_text_system.draw_to(self, ThemeDB.fallback_font, 14)
	_perf_record_step("draw_floating_texts", draw_step_us)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		_pinned_agent_idx = -1
		return

	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_U:
		_toggle_upgrade_panel()
		return

	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_K:
		_toggle_weapon_editor()
		return

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT:
		if event.pressed:
			_camera_dragging = true
			_camera_drag_last_mouse = event.position
			_pinned_agent_idx = -1
		else:
			_camera_dragging = false
		return

	if event is InputEventMouseMotion and _camera_dragging:
		var delta_px: Vector2 = event.position - _camera_drag_last_mouse
		_camera_drag_last_mouse = event.position
		_camera_base_pos -= Vector2(delta_px.x / _camera.zoom.x, delta_px.y / _camera.zoom.y)
		return

	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if _hovered_agent_idx >= 0:
			_pinned_agent_idx = _hovered_agent_idx
			_record_agent_action(_pinned_agent_idx, "Inspector pinned")
			return
		_target = get_global_mouse_position()
		_agents.set_target(_target)
		if _auto_watchtowers:
			_add_watchtower_at_world(_target)


func _draw_world_tiles() -> void:
	var vp: Vector2 = get_viewport_rect().size
	var z: Vector2 = _camera.zoom
	var half: Vector2 = Vector2(vp.x * 0.5 / z.x, vp.y * 0.5 / z.y)
	var cam: Vector2 = _camera.position

	var min_x: int = int(floor((cam.x - half.x) / TILE_SIZE)) - 2
	var max_x: int = int(ceil((cam.x + half.x) / TILE_SIZE)) + 2
	var min_y: int = int(floor((cam.y - half.y) / TILE_SIZE)) - 2
	var max_y: int = int(ceil((cam.y + half.y) / TILE_SIZE)) + 2
	var chunk_size: int = maxi(4, world_chunk_tiles)
	var cmin_x: int = floori(float(min_x) / float(chunk_size))
	var cmax_x: int = floori(float(max_x) / float(chunk_size))
	var cmin_y: int = floori(float(min_y) / float(chunk_size))
	var cmax_y: int = floori(float(max_y) / float(chunk_size))

	for cy in range(cmin_y, cmax_y + 1):
		for cx in range(cmin_x, cmax_x + 1):
			var c: Vector2i = Vector2i(cx, cy)
			var tex: ImageTexture = _get_world_chunk_texture(c)
			if tex == null:
				_request_world_chunk_rebuild(c)
				continue
			var world_pos := Vector2(float(cx * chunk_size * TILE_SIZE), float(cy * chunk_size * TILE_SIZE))
			var world_size := Vector2(float(chunk_size * TILE_SIZE), float(chunk_size * TILE_SIZE))
			draw_texture_rect(tex, Rect2(world_pos, world_size), false, Color(1, 1, 1, 1))

	# Camp and houses
	_draw_structure_tile(_camp_tile, Color(0.95, 0.73, 0.32, 0.95))
	for home in _house_tiles:
		_draw_structure_tile(home, Color(0.82, 0.6, 0.34, 0.95))
	for origin in _manor_origins:
		for dx in MANOR_FOOTPRINT:
			for dy in MANOR_FOOTPRINT:
				_draw_structure_tile(origin + Vector2i(dx, dy), Color(0.72, 0.5, 0.28, 0.95))
	for t in _sawmill_tiles:
		_draw_structure_tile(t, Color(0.72, 0.48, 0.22, 0.95))
	for t in _quarry_tiles:
		_draw_structure_tile(t, Color(0.52, 0.58, 0.65, 0.95))
	for t in _workshop_tiles:
		_draw_structure_tile(t, Color(0.78, 0.52, 0.28, 0.95))
	for t in _storehouse_tiles:
		_draw_structure_tile(t, Color(0.85, 0.76, 0.48, 0.95))
	for t in _armory_tiles:
		_draw_structure_tile(t, Color(0.64, 0.37, 0.34, 0.95))
	for t in _scout_lodge_tiles:
		_draw_structure_tile(t, Color(0.45, 0.78, 0.96, 0.95))
	for t in _outpost_tiles:
		_draw_structure_tile(t, Color(0.36, 0.7, 0.9, 0.95))

	_draw_upgrade_markers()

	for poi in _poi_sites:
		if bool(poi.get("resolved", false)):
			continue
		var tile: Vector2i = poi["tile"]
		var center: Vector2 = _tile_center(tile)
		var col: Color = Color(0.4, 1.0, 0.86, 0.95)
		if bool(poi.get("discovered", false)):
			col = Color(0.95, 0.95, 0.42, 0.98)
		draw_rect(Rect2(center.x - 3.0, center.y - 3.0, 6.0, 6.0), col)
		draw_rect(Rect2(center.x - 5.0, center.y - 5.0, 10.0, 10.0), Color(col.r, col.g, col.b, 0.35), false, 1.0)


func _world_chunk_key(chunk: Vector2i) -> String:
	return "%d:%d" % [chunk.x, chunk.y]


func _chunk_for_tile(tile: Vector2i) -> Vector2i:
	var csz: int = maxi(4, world_chunk_tiles)
	return Vector2i(
		floori(float(tile.x) / float(csz)),
		floori(float(tile.y) / float(csz))
	)


func _mark_chunk_dirty(chunk: Vector2i) -> void:
	var key: String = _world_chunk_key(chunk)
	_world_chunk_dirty[key] = true
	_request_world_chunk_rebuild(chunk)


func _mark_tile_dirty(tile: Vector2i) -> void:
	_mark_chunk_dirty(_chunk_for_tile(tile))
	_resource_index_sync_tile(tile)


func _queue_resource_tile_reload(tile: Vector2i) -> void:
	var id: int = _tile_id(tile)
	if _resource_reload_queued.has(id):
		return
	_resource_reload_queued[id] = true
	_resource_reload_queue.append(tile)


func _compact_resource_reload_queue_if_needed() -> void:
	if _resource_reload_queue_head <= 0:
		return
	var size_now: int = _resource_reload_queue.size()
	if _resource_reload_queue_head < size_now and _resource_reload_queue_head < 128 and _resource_reload_queue_head * 2 < size_now:
		return
	var remaining: Array[Vector2i] = []
	for i in range(_resource_reload_queue_head, size_now):
		remaining.append(_resource_reload_queue[i])
	_resource_reload_queue = remaining
	_resource_reload_queue_head = 0


func _process_resource_reload_queue() -> void:
	var budget: int = maxi(1, resource_reload_budget_per_pass)
	var queued_count: int = _resource_reload_queue.size() - _resource_reload_queue_head
	var count: int = mini(budget, maxi(0, queued_count))
	for _i in count:
		if _resource_reload_queue_head >= _resource_reload_queue.size():
			break
		var tile: Vector2i = _resource_reload_queue[_resource_reload_queue_head]
		_resource_reload_queue_head += 1
		_resource_reload_queued.erase(_tile_id(tile))
		_resource_index_sync_tile(tile)
	_compact_resource_reload_queue_if_needed()


func _get_world_chunk_texture(chunk: Vector2i) -> ImageTexture:
	var key: String = _world_chunk_key(chunk)
	var frame: int = Engine.get_process_frames()
	_world_chunk_last_used[key] = frame
	if _world_chunk_textures.has(key) and not bool(_world_chunk_dirty.get(key, false)):
		return _world_chunk_textures[key]
	if not _world_chunk_textures.has(key):
		_request_world_chunk_rebuild(chunk)
		return null
	if bool(_world_chunk_dirty.get(key, false)):
		_request_world_chunk_rebuild(chunk)
	return _world_chunk_textures[key]


func _request_world_chunk_rebuild(chunk: Vector2i) -> void:
	var key: String = _world_chunk_key(chunk)
	if _world_chunk_rebuild_queued.has(key):
		return
	_world_chunk_rebuild_queued[key] = true
	_world_chunk_rebuild_queue.append(chunk)


func _compact_world_chunk_rebuild_queue_if_needed() -> void:
	if _world_chunk_rebuild_queue_head <= 0:
		return
	var size_now: int = _world_chunk_rebuild_queue.size()
	if _world_chunk_rebuild_queue_head < size_now and _world_chunk_rebuild_queue_head < 128 and _world_chunk_rebuild_queue_head * 2 < size_now:
		return
	var remaining: Array[Vector2i] = []
	for i in range(_world_chunk_rebuild_queue_head, size_now):
		remaining.append(_world_chunk_rebuild_queue[i])
	_world_chunk_rebuild_queue = remaining
	_world_chunk_rebuild_queue_head = 0


func _process_world_chunk_streaming(delta: float) -> void:
	var stream_start_us: int = Time.get_ticks_usec()
	_world_chunk_prune_accum += delta
	if world_chunk_rebuild_budget_per_frame > 0:
		var queued_count: int = _world_chunk_rebuild_queue.size() - _world_chunk_rebuild_queue_head
		var budget: int = mini(world_chunk_rebuild_budget_per_frame, maxi(0, queued_count))
		for _i in budget:
			if _world_chunk_rebuild_queue_head >= _world_chunk_rebuild_queue.size():
				break
			if _i > 0 and world_chunk_streaming_ms_budget > 0.0:
				var elapsed_ms: float = float(Time.get_ticks_usec() - stream_start_us) / 1000.0
				if elapsed_ms >= world_chunk_streaming_ms_budget:
					break
			var chunk: Vector2i = _world_chunk_rebuild_queue[_world_chunk_rebuild_queue_head]
			_world_chunk_rebuild_queue_head += 1
			var key: String = _world_chunk_key(chunk)
			_world_chunk_rebuild_queued.erase(key)
			var tex: ImageTexture = _rebuild_world_chunk_texture(chunk)
			if tex != null:
				_world_chunk_textures[key] = tex
				_world_chunk_dirty[key] = false
		_compact_world_chunk_rebuild_queue_if_needed()

	if _world_chunk_prune_accum < world_chunk_prune_interval_sec:
		return
	if world_chunk_streaming_ms_budget > 0.0:
		var elapsed_before_prune_ms: float = float(Time.get_ticks_usec() - stream_start_us) / 1000.0
		if elapsed_before_prune_ms >= world_chunk_streaming_ms_budget:
			return
	_world_chunk_prune_accum = 0.0

	var vp: Vector2 = get_viewport_rect().size
	var z: Vector2 = _camera.zoom
	var half: Vector2 = Vector2(vp.x * 0.5 / z.x, vp.y * 0.5 / z.y)
	var cam: Vector2 = _camera.position
	var min_x: int = int(floor((cam.x - half.x) / TILE_SIZE)) - 2
	var max_x: int = int(ceil((cam.x + half.x) / TILE_SIZE)) + 2
	var min_y: int = int(floor((cam.y - half.y) / TILE_SIZE)) - 2
	var max_y: int = int(ceil((cam.y + half.y) / TILE_SIZE)) + 2
	var chunk_size: int = maxi(4, world_chunk_tiles)
	var cmin_x: int = floori(float(min_x) / float(chunk_size))
	var cmax_x: int = floori(float(max_x) / float(chunk_size))
	var cmin_y: int = floori(float(min_y) / float(chunk_size))
	var cmax_y: int = floori(float(max_y) / float(chunk_size))
	_prune_world_chunk_cache(
		Vector2i((cmin_x + cmax_x) / 2, (cmin_y + cmax_y) / 2),
		maxi(cmax_x - cmin_x, cmax_y - cmin_y) + 2,
		world_chunk_prune_scan_budget_per_pass
	)


func _rebuild_world_chunk_texture(chunk: Vector2i) -> ImageTexture:
	var csz: int = maxi(4, world_chunk_tiles)
	var px_size: int = csz * TILE_SIZE
	var img := Image.create(px_size, px_size, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.015, 0.02, 0.03, 1.0))

	var tile_origin: Vector2i = Vector2i(chunk.x * csz, chunk.y * csz)
	for ly in csz:
		for lx in csz:
			var tile := Vector2i(tile_origin.x + lx, tile_origin.y + ly)
			var px: int = lx * TILE_SIZE
			var py: int = ly * TILE_SIZE
			if not _is_explored(tile):
				continue
			img.fill_rect(Rect2i(px, py, TILE_SIZE, TILE_SIZE), _biome_color(_biome_at(tile)))

	if _world_chunk_textures.has(_world_chunk_key(chunk)):
		var existing: ImageTexture = _world_chunk_textures[_world_chunk_key(chunk)]
		existing.update(img)
		return existing
	return ImageTexture.create_from_image(img)


func _prune_world_chunk_cache(center_chunk: Vector2i, keep_radius: int, scan_budget: int = -1) -> void:
	if _world_chunk_textures.size() <= world_chunk_cache_max_entries:
		return
	var keys: Array = _world_chunk_textures.keys()
	var scanned: int = 0
	for key_v in keys:
		if scan_budget > 0 and scanned >= scan_budget:
			break
		scanned += 1
		if _world_chunk_textures.size() <= world_chunk_cache_max_entries:
			break
		var key: String = String(key_v)
		var parts: PackedStringArray = key.split(":")
		if parts.size() != 2:
			continue
		var cx: int = int(parts[0])
		var cy: int = int(parts[1])
		if abs(cx - center_chunk.x) <= keep_radius and abs(cy - center_chunk.y) <= keep_radius:
			continue
		_world_chunk_textures.erase(key)
		_world_chunk_dirty.erase(key)
		_world_chunk_last_used.erase(key)


func _draw_structure_tile(tile: Vector2i, col: Color) -> void:
	var rect := Rect2(tile.x * TILE_SIZE + 2, tile.y * TILE_SIZE + 2, TILE_SIZE - 4, TILE_SIZE - 4)
	draw_rect(rect, col)
	draw_rect(rect, MAP_STRUCTURE_OUTLINE, false, 1.0)


func _draw_upgrade_markers() -> void:
	_upgrade_marker_system.draw_markers(
		self,
		_upgrade_ranks,
		_camp_tile,
		_house_tiles,
		_sawmill_tiles,
		_quarry_tiles,
		_workshop_tiles,
		_storehouse_tiles,
		_armory_tiles,
		_scout_lodge_tiles,
		_outpost_tiles,
		_camera.zoom.x,
		Callable(self, "_tile_key"),
		Callable(self, "_tile_center"),
		Callable(self, "_upgrade_color_for")
	)


func _draw_watchtowers() -> void:
	for tile in _watchtowers:
		var center := _tile_center(tile)
		draw_circle(center, 4.5, Color(0.95, 0.86, 0.2, 0.95))
		draw_arc(center, _watchtower_radius * TILE_SIZE, 0.0, TAU, 42, Color(0.95, 0.86, 0.2, 0.14), 1.2)


func _draw_target() -> void:
	var c := Color(1.0, 0.28, 0.24, 0.9)
	draw_rect(Rect2(_target.x - 3.0, _target.y - 3.0, 6.0, 6.0), c)
	draw_rect(Rect2(_target.x - 8.0, _target.y - 8.0, 16.0, 16.0), Color(c.r, c.g, c.b, 0.5), false, 1.0)
	draw_line(_target + Vector2(-11, 0), _target + Vector2(-5, 0), c, 1.0)
	draw_line(_target + Vector2(5, 0), _target + Vector2(11, 0), c, 1.0)
	draw_line(_target + Vector2(0, -11), _target + Vector2(0, -5), c, 1.0)
	draw_line(_target + Vector2(0, 5), _target + Vector2(0, 11), c, 1.0)


func _sprite_batch_view_bounds(margin_px: float = 24.0) -> Vector4:
	var vp: Vector2 = get_viewport_rect().size
	var z: Vector2 = _camera.zoom
	var half: Vector2 = Vector2(vp.x * 0.5 / z.x, vp.y * 0.5 / z.y)
	var cam: Vector2 = _camera.position
	return Vector4(cam.x - half.x - margin_px, cam.x + half.x + margin_px, cam.y - half.y - margin_px, cam.y + half.y + margin_px)


func _queue_sprite_batch() -> void:
	if _agents != null:
		_agents.append_agents_to_sprite_batch(_render_batch_system, float(TILE_SIZE) * 0.4, BATCH_SPRITE_SQUARE)
	var bounds: Vector4 = _sprite_batch_view_bounds(24.0)
	var min_x: float = bounds.x
	var max_x: float = bounds.y
	var min_y: float = bounds.z
	var max_y: float = bounds.w
	var remaining: int = maxi(0, resource_icon_batch_budget_per_frame)
	if remaining > 0:
		var min_tile: Vector2i = _world_to_tile(Vector2(min_x, min_y))
		var max_tile: Vector2i = _world_to_tile(Vector2(max_x, max_y))
		_render_batch_system.queue_visible_resources_fast(
			_chunk_for_tile(min_tile),
			_chunk_for_tile(max_tile),
			remaining,
			_resource_food_chunk_tiles,
			_resource_tree_chunk_tiles,
			_resource_stone_chunk_tiles,
			_resource_metal_chunk_tiles,
			_resource_type_cache,
			_resource_remaining_id,
			float(TILE_SIZE),
			min_x,
			max_x,
			min_y,
			max_y,
			Callable(self, "_world_chunk_key"),
			Callable(self, "_resource_initial_amount"),
			RES_TREE,
			RES_STONE,
			RES_METAL,
			RES_APPLE,
			RES_BERRY_BLUE,
			RES_BERRY_RASP,
			RES_BERRY_BLACK
		)
	_collection_particles_system.queue_to_batch(_render_batch_system, BATCH_SPRITE_SQUARE)
	if show_settler_thinking_indicator:
		var agents: PackedVector2Array = _agents.get_agent_positions()
		if not agents.is_empty() and _settler_think_state.size() == agents.size():
			_refresh_active_indicator_settlers(agents.size())
			if not _active_indicator_settlers.is_empty():
				var indicator_bounds: Vector4 = _sprite_batch_view_bounds(20.0)
				_render_batch_system.queue_settler_indicators(
					agents,
					_active_indicator_settlers,
					_settler_think_state,
					indicator_bounds.x,
					indicator_bounds.y,
					indicator_bounds.z,
					indicator_bounds.w,
					THINK_THINKING,
					BATCH_SPRITE_DIAMOND
				)
	_render_batch_system.queue_wildlife(
		_wildlife,
		min_x,
		max_x,
		min_y,
		max_y,
		Callable(self, "_is_explored"),
		Callable(self, "_world_to_tile"),
		ANIMAL_DEER,
		ANIMAL_WOLF,
		ANIMAL_BEAR
	)


func _draw_chunk_resource_emojis(
	key: String,
	remaining: int,
	font: Font,
	emoji_font_size: int,
	min_tx: int,
	max_tx: int,
	min_ty: int,
	max_ty: int,
	min_x: float,
	max_x: float,
	min_y: float,
	max_y: float
) -> int:
	if remaining <= 0:
		return 0

	if _resource_food_chunk_tiles.has(key):
		var food_tiles: Array = _resource_food_chunk_tiles[key]
		for tile_v in food_tiles:
			if remaining <= 0:
				return 0
			var tile: Vector2i = tile_v
			if tile.x < min_tx or tile.x > max_tx or tile.y < min_ty or tile.y > max_ty:
				continue
			var res_type: int = _resource_type_at(tile)
			if res_type == RES_NONE or _resource_left(tile, res_type) <= 0.0:
				continue
			if _draw_resource_emoji_if_visible(tile, res_type, font, emoji_font_size, min_x, max_x, min_y, max_y):
				remaining -= 1

	if _resource_tree_chunk_tiles.has(key):
		var tree_tiles: Array = _resource_tree_chunk_tiles[key]
		for tile_v in tree_tiles:
			if remaining <= 0:
				return 0
			var tree_tile: Vector2i = tile_v
			if tree_tile.x < min_tx or tree_tile.x > max_tx or tree_tile.y < min_ty or tree_tile.y > max_ty:
				continue
			if _resource_left(tree_tile, RES_TREE) <= 0.0:
				continue
			if _draw_resource_emoji_if_visible(tree_tile, RES_TREE, font, emoji_font_size, min_x, max_x, min_y, max_y):
				remaining -= 1

	if _resource_stone_chunk_tiles.has(key):
		var stone_tiles: Array = _resource_stone_chunk_tiles[key]
		for tile_v in stone_tiles:
			if remaining <= 0:
				return 0
			var stone_tile: Vector2i = tile_v
			if stone_tile.x < min_tx or stone_tile.x > max_tx or stone_tile.y < min_ty or stone_tile.y > max_ty:
				continue
			if _resource_left(stone_tile, RES_STONE) <= 0.0:
				continue
			if _draw_resource_emoji_if_visible(stone_tile, RES_STONE, font, emoji_font_size, min_x, max_x, min_y, max_y):
				remaining -= 1

	if _resource_metal_chunk_tiles.has(key):
		var metal_tiles: Array = _resource_metal_chunk_tiles[key]
		for tile_v in metal_tiles:
			if remaining <= 0:
				return 0
			var metal_tile: Vector2i = tile_v
			if metal_tile.x < min_tx or metal_tile.x > max_tx or metal_tile.y < min_ty or metal_tile.y > max_ty:
				continue
			if _resource_left(metal_tile, RES_METAL) <= 0.0:
				continue
			if _draw_resource_emoji_if_visible(metal_tile, RES_METAL, font, emoji_font_size, min_x, max_x, min_y, max_y):
				remaining -= 1

	return remaining


func _draw_resource_emoji_if_visible(
	tile: Vector2i,
	res_type: int,
	font: Font,
	emoji_font_size: int,
	min_x: float,
	max_x: float,
	min_y: float,
	max_y: float
) -> bool:
	var center: Vector2 = _tile_center(tile)
	if center.x < min_x or center.x > max_x or center.y < min_y or center.y > max_y:
		return false
	var emoji: String = _resource_world_emoji(res_type)
	var tint: Color = _resource_world_emoji_color(res_type)
	var size: Vector2 = font.get_string_size(emoji, HORIZONTAL_ALIGNMENT_LEFT, -1.0, emoji_font_size)
	var baseline: Vector2 = center + Vector2(-size.x * 0.5, size.y * 0.4)
	draw_string(font, baseline, emoji, HORIZONTAL_ALIGNMENT_LEFT, -1.0, emoji_font_size, tint)
	return true


func _resource_world_emoji(res_type: int) -> String:
	match res_type:
		RES_TREE:
			return "🌲"
		RES_STONE:
			return "🪨"
		RES_METAL:
			return "◈"
		RES_APPLE:
			return "🍎"
		RES_BERRY_BLUE:
			return "🫐"
		RES_BERRY_RASP:
			return "🍓"
		RES_BERRY_BLACK:
			return "🫐"
		_:
			return "•"


func _resource_world_emoji_color(res_type: int) -> Color:
	match res_type:
		RES_TREE:
			return Color(0.22, 0.72, 0.3, 0.96)
		RES_STONE:
			return Color(0.76, 0.78, 0.82, 0.96)
		RES_METAL:
			return Color(0.36, 0.38, 0.42, 0.98)
		RES_APPLE:
			return Color(0.95, 0.46, 0.4, 0.98)
		RES_BERRY_BLUE:
			return Color(0.54, 0.68, 1.0, 0.98)
		RES_BERRY_RASP:
			return Color(1.0, 0.52, 0.62, 0.98)
		RES_BERRY_BLACK:
			return Color(0.68, 0.52, 0.86, 0.98)
		_:
			return Color(1.0, 1.0, 1.0, 0.95)


func _draw_night_fx() -> void:
	if not _is_night():
		return
	var vp: Vector2 = get_viewport_rect().size
	var z: Vector2 = _camera.zoom
	var half: Vector2 = Vector2(vp.x * 0.5 / z.x, vp.y * 0.5 / z.y)
	var cam: Vector2 = _camera.position
	var left: float = cam.x - half.x
	var top: float = cam.y - half.y
	var width: float = half.x * 2.0
	var height: float = half.y * 2.0

	var pulse: float = 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.0017)
	var alpha: float = 0.24 + 0.16 * pulse + _night_visual_boost - _night_overlay_reduction
	draw_rect(Rect2(left, top, width, height), Color(0.02, 0.05, 0.12, clampf(alpha, 0.24, 0.55)))

	# Moonlight sweep bands
	for i in 3:
		var off: float = fmod(Time.get_ticks_msec() * 0.02 + i * 130.0, width + 220.0) - 110.0
		var p0 := Vector2(left + off, top)
		var p1 := Vector2(left + off + 130.0, top)
		var p2 := Vector2(left + off + 40.0, top + height)
		var p3 := Vector2(left + off - 90.0, top + height)
		draw_colored_polygon(PackedVector2Array([p0, p1, p2, p3]), Color(0.2, 0.32, 0.5, 0.05))

	# Camp moon halo to anchor nighttime attention
	var camp_center: Vector2 = _tile_center(_camp_tile)
	draw_arc(camp_center, 72.0, 0.0, TAU, 56, Color(0.65, 0.8, 1.0, 0.14), 2.0)
	draw_arc(camp_center, 112.0, 0.0, TAU, 56, Color(0.45, 0.64, 0.95, 0.08), 1.4)

	if _raid_warning_active:
		var font: Font = ThemeDB.fallback_font
		var remain: int = maxi(1, int(ceil(_raid_warning_timer)))
		var pulse2: float = 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.02)
		draw_arc(camp_center, 96.0 + 7.0 * pulse2, 0.0, TAU, 48, Color(0.95, 0.1, 0.12, 0.75), 2.6)
		draw_string(font, camp_center + Vector2(-104.0, -84.0), "Howl in the fog... %ds" % remain, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 16, Color(1.0, 0.35, 0.35, 0.95))


func _update_economy(delta: float) -> void:
	var result: Dictionary = _economy_system.run({
		"delta": delta,
		"harvest_tick": _harvest_tick,
		"cook_tick": _cook_tick,
		"resource_regrow_tick": _resource_regrow_tick,
		"resources": _resources,
		"resource_remaining": _resource_remaining,
		"berry_overnight_regrow_due": _berry_overnight_regrow_due,
		"buildings": _buildings,
		"house_tiles": _house_tiles,
		"manor_origins": _manor_origins,
		"manor_footprint": MANOR_FOOTPRINT,
		"outpost_tiles": _outpost_tiles,
		"food_consume_per_settler": _food_consume_per_settler,
		"food_consume_mult": _food_consume_mult,
		"convert_mult": _convert_mult,
		"quarry_passive_mult": _quarry_passive_mult,
		"storehouse_mult": _storehouse_mult,
		"night_cooking_unlocked": _night_cooking_unlocked,
		"res_apple": RES_APPLE,
		"res_berry_blue": RES_BERRY_BLUE,
		"res_berry_rasp": RES_BERRY_RASP,
		"res_berry_black": RES_BERRY_BLACK,
		"res_tree": RES_TREE,
		"metal_processing_unlocked": _metal_mining_unlocked,
		"camp_tile": _camp_tile,
		"workshop_paused": _workshop_paused,
		"cb_harvest_resources": Callable(self, "_harvest_resources"),
		"cb_agent_count": Callable(_agents, "get_agent_count"),
		"cb_is_night": Callable(self, "_is_night"),
		"cb_housing_capacity": Callable(self, "_housing_capacity"),
		"cb_spawn_floating_text": Callable(self, "_spawn_floating_text"),
		"cb_tile_center": Callable(self, "_tile_center"),
		"cb_resource_type_at": Callable(self, "_resource_type_at"),
		"cb_resource_initial_amount": Callable(self, "_resource_initial_amount"),
		"cb_mark_tile_dirty": Callable(self, "_mark_tile_dirty"),
	})
	_harvest_tick = float(result["harvest_tick"])
	_cook_tick = float(result["cook_tick"])
	_resource_regrow_tick = float(result["resource_regrow_tick"])
	_refinery_smelt_activity = float(result.get("smelted_amount", 0.0))


func _update_refinery_vfx(delta: float) -> void:
	var target_intensity: float = 1.0 if _refinery_smelt_activity > 0.0001 and not _workshop_paused else 0.0
	_refinery_glow_intensity = lerpf(_refinery_glow_intensity, target_intensity, clampf(delta * 5.5, 0.0, 1.0))
	if _refinery_glow_intensity > 0.08 and not _workshop_tiles.is_empty():
		for tile in _workshop_tiles:
			if _rng.randf() < (0.8 + 1.9 * _refinery_glow_intensity) * delta:
				var center: Vector2 = _tile_center(tile)
				_refinery_smoke_particles.append({
					"pos": center + Vector2(_rng.randf_range(-2.0, 2.0), _rng.randf_range(-7.0, -3.0)),
					"vel": Vector2(_rng.randf_range(-6.0, 6.0), _rng.randf_range(-26.0, -14.0)),
					"t": 0.0,
					"dur": _rng.randf_range(0.65, 1.25),
					"size": _rng.randf_range(1.6, 3.4),
				})
	for i in range(_refinery_smoke_particles.size() - 1, -1, -1):
		var p: Dictionary = _refinery_smoke_particles[i]
		p["t"] = float(p["t"]) + delta
		p["vel"] = Vector2(float(p["vel"].x) * 0.985, float(p["vel"].y) - 5.0 * delta)
		p["pos"] = Vector2(p["pos"]) + Vector2(p["vel"]) * delta
		if float(p["t"]) >= float(p["dur"]):
			_refinery_smoke_particles.remove_at(i)
		else:
			_refinery_smoke_particles[i] = p


func _draw_refinery_vfx() -> void:
	if _refinery_glow_intensity > 0.04:
		var t: float = Time.get_ticks_msec() * 0.001
		for tile in _workshop_tiles:
			var center: Vector2 = _tile_center(tile)
			var pulse: float = 0.65 + 0.35 * sin(t * 8.0 + float(tile.x + tile.y) * 0.7)
			var alpha: float = 0.08 + 0.18 * _refinery_glow_intensity * pulse
			draw_circle(center + Vector2(0.0, -2.0), 6.0 + 2.2 * pulse, Color(1.0, 0.62, 0.2, alpha))
			draw_circle(center + Vector2(0.0, -3.2), 3.0 + 1.3 * pulse, Color(1.0, 0.82, 0.36, alpha * 1.2))
	for p in _refinery_smoke_particles:
		var life: float = clampf(float(p["t"]) / maxf(0.001, float(p["dur"])), 0.0, 1.0)
		var a: float = (1.0 - life) * (0.22 + 0.32 * _refinery_glow_intensity)
		draw_circle(Vector2(p["pos"]), float(p["size"]) * (1.0 + life * 0.9), Color(0.55, 0.58, 0.62, a))


func _update_day_cycle(delta: float) -> void:
	var was_night: bool = _is_night()
	_day_time = fmod(_day_time + delta / _day_length_seconds, 1.0)
	var now_night: bool = _is_night()
	if not was_night and now_night:
		_on_night_start()
	if was_night and not now_night:
		_day_index += 1
		_on_morning_start()
	_was_night = now_night


func _on_night_start() -> void:
	_night_visual_boost = 0.0
	if not _first_night_event_done:
		_first_night_event_done = true
	_razes_this_night = 0
	_structure_raze_cooldown = 0.0
	_raid_warning_active = false
	_pending_wolf_spawn_count = 0
	_pending_bear_spawn_count = 0
	_wolf_raid_active = false
	if _combat_neglect_level() >= 0.55:
		_spawn_floating_text(_tile_center(_camp_tile), "The militia looks unprepared...", Color(1.0, 0.58, 0.42, 1.0))
	if _day_index >= _wolf_next_raid_day:
		var raid: Dictionary = _compute_raid_spawn_counts()
		_pending_wolf_spawn_count = int(raid.get("wolves", 0))
		_pending_bear_spawn_count = int(raid.get("bears", 0))
		_raid_warning_active = true
		_raid_warning_timer = _raid_warning_duration
		_play_howl_warning()
		_spawn_floating_text(_tile_center(_camp_tile), "Howl heard. Hold for 5 seconds!", Color(1.0, 0.45, 0.4, 1.0))
		_wolf_next_raid_day = _day_index + 3

	_berry_overnight_regrow_due.clear()
	var night_duration: float = maxf(1.0, _day_length_seconds * (1.0 - 0.78 + 0.2))
	for key_v in _resource_remaining.keys():
		var key: String = String(key_v)
		var parts: Array = key.split(":")
		if parts.size() != 2:
			continue
		var tile := Vector2i(int(parts[0]), int(parts[1]))
		if _is_structure_tile_occupied(tile):
			continue
		var rt: int = _resource_type_at(tile)
		if rt != RES_TREE and rt != RES_BERRY_BLUE and rt != RES_BERRY_RASP and rt != RES_BERRY_BLACK:
			continue
		var cur: float = float(_resource_remaining[key])
		var max_amt: float = _resource_initial_amount(tile, rt)
		if cur < max_amt:
			_berry_overnight_regrow_due[key] = _rng.randf_range(0.05, night_duration)


func _compute_raid_spawn_counts() -> Dictionary:
	var houses: int = maxi(1, int(_buildings["house"]) + int(_buildings.get("manor", 0)))
	var settlers: int = maxi(1, _agents.get_agent_count())
	var age_days: float = float(maxi(0, _day_index))
	var age_mult: float = 1.0 + age_days * 0.08
	var base: float = 2.0 + float(houses) * 0.6 + float(settlers) * 0.35
	var neglect: float = _combat_neglect_level()
	var neglect_mult: float = 1.0 + neglect * 0.42 + minf(0.16, 0.04 * float(_combat_neglect_streak))
	var wolf_count: int = maxi(4, int(round(base * age_mult * _wolf_raid_size_mult * neglect_mult)))
	var bear_count: int = maxi(1, int(floor(float(wolf_count) * (0.18 + neglect * 0.06) + age_days / 18.0)))
	return {"wolves": wolf_count, "bears": bear_count}


func _combat_investment_points() -> float:
	var points: float = 0.0
	points += float(int(_buildings.get("armory", 0))) * 1.4
	var keys: Array[String] = [
		"def_spears", "def_horns", "def_training",
		"cmb_armory", "cmb_shields", "cmb_bowcraft", "cmb_javelin", "cmb_steel", "cmb_drills",
	]
	for key in keys:
		points += float(int(_upgrade_ranks.get(key, 0)))
	if _weapon_shield_unlocked:
		points += 0.6
	if _weapon_bow_unlocked:
		points += 0.6
	if _weapon_javelin_unlocked:
		points += 0.6
	return points


func _combat_neglect_level() -> float:
	var houses: float = float(maxi(1, int(_buildings["house"]) + int(_buildings.get("manor", 0))))
	var settlers: float = float(maxi(1, _agents.get_agent_count()))
	var age_days: float = float(maxi(0, _day_index))
	# Expected combat investment rises with population, housing footprint, and colony age.
	var expected: float = 1.6 + houses * 0.5 + settlers * 0.24 + age_days * 0.2
	var actual: float = _combat_investment_points()
	if expected <= 0.01:
		return 0.0
	return clampf((expected - actual) / expected, 0.0, 1.0)


func _on_morning_start() -> void:
	_wolf_raid_active = false
	_raid_warning_active = false
	_pending_wolf_spawn_count = 0
	_pending_bear_spawn_count = 0
	_apply_auto_tool_assignments()
	if morning_dispatch_spread_sec > 0.0 and _agents.get_agent_count() > 0:
		var count: int = _agents.get_agent_count()
		_sync_settler_think_buffers(count)
		_morning_dispatch_cursor = 0
		_morning_dispatch_active = true
		_process_morning_dispatch_queue()
	else:
		_morning_dispatch_cursor = -1
		_morning_dispatch_active = false
	var neglect: float = _combat_neglect_level()
	if neglect >= 0.45:
		_combat_neglect_streak += 1
	else:
		_combat_neglect_streak = maxi(0, _combat_neglect_streak - 1)
	# Shared-home births: chance = happiness / 2, evaluated at dawn
	var births: int = 0
	var capacity_left: int = _housing_capacity() - _agents.get_agent_count()
	if capacity_left > 0:
		for i in _agents.get_agent_count():
			if births >= capacity_left:
				break
			if not _has_housemate(i):
				continue
			var chance: float = clampf(_settler_happiness[i] * 0.5, 0.0, 0.5)
			if _rng.randf() < chance:
				births += 1
	if births > 0:
		var old_count: int = _agents.get_agent_count()
		_agents.add_agents(births, _tile_center(_camp_tile))
		_recompute_homes()
		_clamp_job_counts()
		_sync_agent_tracking()
		for n in births:
			_record_agent_action(old_count + n, "Born at sunrise")
		_spawn_floating_text(_tile_center(_camp_tile), "+%d dawn birth" % births, Color(0.78, 0.98, 0.72, 1.0))


func _has_housemate(index: int) -> bool:
	if index < 0 or index >= _settler_homes.size():
		return false
	var home_idx: int = _settler_homes[index]
	if home_idx < 0:
		return false
	for i in _settler_homes.size():
		if i == index:
			continue
		if _settler_homes[i] == home_idx:
			return true
	return false


func _update_starvation_deaths(delta: float) -> void:
	var count: int = _agents.get_agent_count()
	if count <= 0:
		return
	if _settler_starvation_time.size() != count:
		var old_starve: PackedFloat32Array = _settler_starvation_time
		_settler_starvation_time.resize(count)
		for i in count:
			_settler_starvation_time[i] = old_starve[i] if i < old_starve.size() else 0.0
	if _resources["food"] > 0.0:
		for i in count:
			_settler_starvation_time[i] = maxf(0.0, _settler_starvation_time[i] - delta * 3.0)
		return
	var starvation_threshold: float = maxf(10.0, _day_length_seconds)
	var casualties: PackedInt32Array = PackedInt32Array()
	for i in count:
		_settler_starvation_time[i] += delta
		if _settler_starvation_time[i] >= starvation_threshold:
			casualties.append(i)
	if not casualties.is_empty():
		_remove_settlers_by_indices(casualties, "starvation", _tile_center(_camp_tile))


func _update_happiness(delta: float) -> void:
	if _resources["food"] <= 0.0:
		_food_shortage_streak_sec += delta
	else:
		_food_shortage_streak_sec = maxf(0.0, _food_shortage_streak_sec - delta * 2.0)
	var starvation_mult: float = 1.0 + minf(1.0, _food_shortage_streak_sec / 90.0)
	for i in _agents.get_agent_count():
		var h: float = _settler_happiness[i]
		if _resources["food"] <= 0.0:
			h -= 0.09 * starvation_mult * _happiness_loss_mult * delta
		elif _is_night() and _has_housemate(i):
			h += 0.04 * _happiness_gain_mult * delta
		elif _is_night():
			h += 0.015 * _happiness_gain_mult * delta
		else:
			h += 0.01 * _happiness_gain_mult * delta
		_settler_happiness[i] = clampf(h, 0.0, 1.0)


func _average_happiness() -> float:
	if _agents.get_agent_count() <= 0:
		return 0.0
	var total: float = 0.0
	for i in _agents.get_agent_count():
		total += _settler_happiness[i]
	return total / float(_agents.get_agent_count())


func _harvest_resources() -> void:
	var agents: PackedVector2Array = _agents.get_agent_positions()
	for i in agents.size():
		var pos: Vector2 = agents[i]
		var job: int = _job_for_settler(i)
		var tile := _world_to_tile(pos)

		if job == JOB_FARM:
			# Farmers only gather during the day from food resource tiles
			if _is_night():
				continue
			var tool_mult_farm: float = _tool_harvest_mult(i, JOB_FARM)
			var res_type: int = _resource_type_at(tile)
			var food_gain: float = 0.0
			var food_color := Color(0.95, 0.8, 0.34, 1.0)
			var food_label := ""
			if res_type == RES_APPLE and _resource_left(tile, res_type) >= FOOD_MIN_HARVEST:
				var left: float = _resource_left(tile, res_type)
				var pick: float = minf(left, 1.2 * (1.0 + float(_buildings["camp"]) * 0.1) * _food_gather_mult * tool_mult_farm)
				if pick < FOOD_MIN_HARVEST:
					_release_resource_claim(i)
					continue
				_set_resource_left(tile, left - pick)
				food_gain = pick
				food_label = "+%.1f apple" % pick
				food_color = Color(0.92, 0.3, 0.2, 1.0)
			elif (res_type == RES_BERRY_BLUE or res_type == RES_BERRY_RASP or res_type == RES_BERRY_BLACK) and _resource_left(tile, res_type) >= FOOD_MIN_HARVEST:
				var left: float = _resource_left(tile, res_type)
				# Berries are consumed on harvest so the node visually disappears immediately.
				var pick: float = left
				if pick < FOOD_MIN_HARVEST:
					_release_resource_claim(i)
					continue
				_set_resource_left(tile, 0.0)
				food_gain = pick
				var berry_names := {RES_BERRY_BLUE: "blueberry", RES_BERRY_RASP: "raspberry", RES_BERRY_BLACK: "blackberry"}
				food_label = "+%.1f %s" % [pick, berry_names[res_type]]
				food_color = Color(0.72, 0.28, 0.82, 1.0) if res_type == RES_BERRY_BLACK else Color(0.4, 0.55, 0.95, 1.0)
			if food_gain > 0.0:
				_resources["food"] += food_gain
				_record_agent_action(i, "Gathered %s" % food_label)
				_spawn_collect_feedback(_tile_center(tile), _resource_feedback_text("food", food_gain), food_color)
			continue

		var res_type: int = _resource_type_at(tile)
		if res_type == RES_NONE:
			continue
		if job == JOB_LUMBER and res_type != RES_TREE:
			continue
		if job == JOB_STONE and res_type != RES_STONE and (not _metal_mining_unlocked or res_type != RES_METAL):
			continue
		if job != JOB_LUMBER and job != JOB_STONE:
			continue
		var left: float = _resource_left(tile, res_type)
		if left <= 0.0:
			continue

		var amount: float = 1.0
		if res_type == RES_TREE:
			amount += float(_buildings["sawmill"])
			amount *= _tree_yield_mult
		elif res_type == RES_STONE:
			amount += float(_buildings["quarry"])
			amount *= _stone_yield_mult
		elif res_type == RES_METAL:
			amount += float(_buildings["quarry"]) * 0.35
			amount *= _metal_yield_mult
		amount *= _tool_harvest_mult(i, job)

		var mined: float = minf(left, amount)
		_set_resource_left(tile, left - mined)

		var center := _tile_center(tile)
		if res_type == RES_TREE:
			_resources["lumber"] += mined
			_record_agent_action(i, "Chopped +%d lumber" % int(ceil(mined)))
			_spawn_collect_feedback(center, _resource_feedback_text("lumber", mined), Color(0.22, 0.9, 0.34, 1.0))
		elif res_type == RES_STONE:
			_resources["stone"] += mined
			_record_agent_action(i, "Mined +%d stone" % int(ceil(mined)))
			_spawn_collect_feedback(center, _resource_feedback_text("stone", mined), Color(0.8, 0.86, 0.95, 1.0))
		else:
			_resources["metal_ore"] += mined
			_record_agent_action(i, "Extracted +%d ore" % int(ceil(mined)))
			_spawn_collect_feedback(center, _resource_feedback_text("metal_ore", mined), Color(0.42, 0.44, 0.48, 1.0))


func _build_resource_ui() -> void:
	var ui_layer: CanvasLayer = $UI
	var bar := PanelContainer.new()
	bar.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	bar.position = Vector2(12.0, -100.0)
	ui_layer.add_child(bar)

	var bg := StyleBoxFlat.new()
	bg.bg_color = UI_BG
	bg.border_width_left = 1
	bg.border_width_top = 1
	bg.border_width_right = 1
	bg.border_width_bottom = 1
	bg.border_color = UI_BORDER
	bg.corner_radius_top_left = 2
	bg.corner_radius_top_right = 2
	bg.corner_radius_bottom_left = 2
	bg.corner_radius_bottom_right = 2
	bg.content_margin_left = 8.0
	bg.content_margin_right = 8.0
	bg.content_margin_top = 6.0
	bg.content_margin_bottom = 6.0
	bar.add_theme_stylebox_override("panel", bg)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	bar.add_child(vbox)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	vbox.add_child(row)

	_add_resource_widget(row, "lumber", Color(0.22, 0.84, 0.34, 1.0), "lumber")
	_add_resource_widget(row, "stone", Color(0.74, 0.8, 0.88, 1.0), "stone")
	_add_resource_widget(row, "metal_ore", Color(0.64, 0.7, 0.78, 1.0))
	_add_resource_widget(row, "metal", Color(0.62, 0.66, 0.78, 1.0))
	_add_resource_widget(row, "food", Color(0.95, 0.8, 0.32, 1.0), "farm")

	_status_label = Label.new()
	_status_label.add_theme_font_size_override("font_size", 13)
	_status_label.modulate = Color(0.78, 0.88, 0.95, 0.9)
	vbox.add_child(_status_label)

	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 6)
	vbox.add_child(actions)

	_fast_recruit_btn = Button.new()
	_fast_recruit_btn.text = "+ Colonist"
	_fast_recruit_btn.custom_minimum_size = Vector2(110.0, 28.0)
	_fast_recruit_btn.pressed.connect(_on_fast_recruit_pressed)
	actions.add_child(_fast_recruit_btn)

	_fast_house_btn = Button.new()
	_fast_house_btn.text = "+ House"
	_fast_house_btn.custom_minimum_size = Vector2(90.0, 28.0)
	_fast_house_btn.pressed.connect(_on_fast_house_pressed)
	actions.add_child(_fast_house_btn)

	_workshop_toggle_btn = Button.new()
	_workshop_toggle_btn.text = "Refinery: ON"
	_workshop_toggle_btn.custom_minimum_size = Vector2(120.0, 28.0)
	_workshop_toggle_btn.pressed.connect(_on_toggle_workshop_pressed)
	actions.add_child(_workshop_toggle_btn)

	var tool_row := HBoxContainer.new()
	tool_row.add_theme_constant_override("separation", 6)
	vbox.add_child(tool_row)

	_tool_stock_label = Label.new()
	_tool_stock_label.add_theme_font_size_override("font_size", 12)
	_tool_stock_label.modulate = Color(0.88, 0.94, 0.98, 0.94)
	_tool_stock_label.tooltip_text = "Tools are consumed when equipped and returned when swapped or unequipped. Use quick actions to mass-assign by role."
	tool_row.add_child(_tool_stock_label)

	for recipe_key in ["axe", "pick", "scythe"]:
		var craft_btn := Button.new()
		craft_btn.text = "Craft %s" % _tool_name_for_id(_tool_id_for_inventory_key(String(recipe_key)))
		craft_btn.custom_minimum_size = Vector2(88.0, 24.0)
		craft_btn.add_theme_font_size_override("font_size", 11)
		craft_btn.tooltip_text = _cost_to_string(TOOL_CRAFT_RECIPES.get(recipe_key, {}))
		craft_btn.pressed.connect(_on_craft_tool_pressed.bind(String(recipe_key)))
		tool_row.add_child(craft_btn)
		_craft_tool_btns[String(recipe_key)] = craft_btn

	var tool_actions_row := HBoxContainer.new()
	tool_actions_row.add_theme_constant_override("separation", 6)
	vbox.add_child(tool_actions_row)

	var equip_role_btn := Button.new()
	equip_role_btn.text = "Equip By Role"
	equip_role_btn.custom_minimum_size = Vector2(104.0, 24.0)
	equip_role_btn.add_theme_font_size_override("font_size", 11)
	equip_role_btn.tooltip_text = "Set everyone to Auto mode and equip job-preferred tools where stock allows."
	equip_role_btn.pressed.connect(_on_tool_quick_equip_by_role_pressed)
	tool_actions_row.add_child(equip_role_btn)

	var clear_locks_btn := Button.new()
	clear_locks_btn.text = "Clear Locks"
	clear_locks_btn.custom_minimum_size = Vector2(92.0, 24.0)
	clear_locks_btn.add_theme_font_size_override("font_size", 11)
	clear_locks_btn.tooltip_text = "Set all settlers to Auto tool mode."
	clear_locks_btn.pressed.connect(_on_tool_quick_clear_locks_pressed)
	tool_actions_row.add_child(clear_locks_btn)

	var rebalance_btn := Button.new()
	rebalance_btn.text = "Rebalance Tools"
	rebalance_btn.custom_minimum_size = Vector2(106.0, 24.0)
	rebalance_btn.add_theme_font_size_override("font_size", 11)
	rebalance_btn.tooltip_text = "Return auto-settler tools to stock and redistribute by active jobs."
	rebalance_btn.pressed.connect(_on_tool_quick_rebalance_pressed)
	tool_actions_row.add_child(rebalance_btn)


func _add_resource_widget(parent: HBoxContainer, key: String, color: Color, add_job_key: String = "") -> void:
	var box := HBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	parent.add_child(box)

	var icon_lbl := Label.new()
	icon_lbl.text = _resource_icon(key)
	icon_lbl.custom_minimum_size = Vector2(18.0, 18.0)
	icon_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	icon_lbl.add_theme_font_size_override("font_size", 15)
	icon_lbl.modulate = color
	box.add_child(icon_lbl)

	var lbl := Label.new()
	lbl.text = "0.0" if key == "food" else "0"
	lbl.add_theme_font_size_override("font_size", 15)
	box.add_child(lbl)
	_resource_labels[key] = lbl

	if add_job_key != "":
		var count_lbl := Label.new()
		count_lbl.text = "👥 0"
		count_lbl.custom_minimum_size = Vector2(42.0, 0.0)
		count_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		count_lbl.add_theme_font_size_override("font_size", 12)
		count_lbl.modulate = Color(0.82, 0.9, 0.98, 0.95)
		box.add_child(count_lbl)
		_resource_job_labels[key] = count_lbl

		var add_btn := Button.new()
		add_btn.text = "+"
		add_btn.custom_minimum_size = Vector2(22.0, 22.0)
		add_btn.add_theme_font_size_override("font_size", 12)
		add_btn.pressed.connect(_change_job_count.bind(add_job_key, 1))
		box.add_child(add_btn)


func _resource_icon(key: String) -> String:
	match key:
		"food":
			return "🍎"
		"lumber":
			return "🪵"
		"stone":
			return "🪨"
		"metal_ore":
			return "◈"
		"metal":
			return "▬"
		_:
			return "◼"


func _resource_feedback_text(key: String, amount: float) -> String:
	if key == "food":
		return "%s +%.1f" % [_resource_icon(key), amount]
	return "%s +%d" % [_resource_icon(key), int(ceil(amount))]


func _update_resource_ui() -> void:
	for key in _resource_labels.keys():
		var lbl_obj: Variant = _resource_labels[key]
		if not is_instance_valid(lbl_obj):
			_resource_labels.erase(key)
			continue
		var lbl: Label = lbl_obj as Label
		if lbl == null:
			_resource_labels.erase(key)
			continue
		if String(key) == "food":
			lbl.text = "%.1f" % float(_resources[key])
		else:
			lbl.text = "%d" % int(_resources[key])
	for key in _resource_job_labels.keys():
		var count_lbl_obj: Variant = _resource_job_labels[key]
		if not is_instance_valid(count_lbl_obj):
			_resource_job_labels.erase(key)
			continue
		var count_lbl: Label = count_lbl_obj as Label
		if count_lbl == null:
			_resource_job_labels.erase(key)
			continue
		var job_key := ""
		match String(key):
			"food":
				job_key = "farm"
			"lumber":
				job_key = "lumber"
			"stone":
				job_key = "stone"
		if job_key != "":
			count_lbl.text = "👥 %d" % int(_job_counts.get(job_key, 0))
	for b_key in _building_labels.keys():
		var b_lbl_obj: Variant = _building_labels[b_key]
		if not is_instance_valid(b_lbl_obj):
			_building_labels.erase(b_key)
			continue
		var b_lbl: Label = b_lbl_obj as Label
		if b_lbl == null:
			_building_labels.erase(b_key)
			continue
		b_lbl.text = "Built: %d" % int(_buildings[b_key])
	if _workshop_toggle_btn != null and is_instance_valid(_workshop_toggle_btn):
		_workshop_toggle_btn.text = "Refinery: %s" % ("OFF" if _workshop_paused else "ON")
		_workshop_toggle_btn.disabled = int(_buildings["workshop"]) <= 0
	if _fast_recruit_btn != null and is_instance_valid(_fast_recruit_btn):
		_fast_recruit_btn.disabled = _agents.get_agent_count() >= _housing_capacity()
	if _fast_house_btn != null and is_instance_valid(_fast_house_btn):
		_fast_house_btn.disabled = false
	if _tool_stock_label != null and is_instance_valid(_tool_stock_label):
		_tool_stock_label.text = "Tools  Axe:%d  Pick:%d  Scythe:%d" % [
			int(_tool_inventory.get("axe", 0)),
			int(_tool_inventory.get("pick", 0)),
			int(_tool_inventory.get("scythe", 0)),
		]
	for recipe_key in _craft_tool_btns.keys():
		var btn_obj: Variant = _craft_tool_btns[recipe_key]
		if not is_instance_valid(btn_obj):
			_craft_tool_btns.erase(recipe_key)
			continue
		var btn: Button = btn_obj as Button
		if btn == null:
			_craft_tool_btns.erase(recipe_key)
			continue
		btn.disabled = int(_buildings.get("workshop", 0)) <= 0 or not _can_afford(TOOL_CRAFT_RECIPES.get(recipe_key, {}))
	if _status_label != null and is_instance_valid(_status_label):
		var sc: int = _agents.get_agent_count()
		var hc: int = _housing_capacity()
		var f: int = int(_job_counts["farm"])
		var l: int = int(_job_counts["lumber"])
		var s: int = int(_job_counts["stone"])
		var h: int = int(_job_counts["hunt"])
		var sc2: int = int(_job_counts["scout"])
		_status_label.text = "Settlers: %d/%d   Farm %d  Lumber %d  Mine %d  Hunt %d  Scout %d" % [sc, hc, f, l, s, h, sc2]


func _on_toggle_workshop_pressed() -> void:
	if int(_buildings["workshop"]) <= 0:
		return
	_workshop_paused = not _workshop_paused
	_spawn_floating_text(_tile_center(_camp_tile), "Refinery %s" % ("paused" if _workshop_paused else "resumed"), Color(0.72, 0.88, 1.0, 1.0))


func _on_fast_recruit_pressed() -> void:
	var cost: Dictionary = POP_ACTIONS["recruit"]["cost"]
	if not _can_afford(cost):
		_spawn_floating_text(_tile_center(_camp_tile), "Need resources", Color(1.0, 0.55, 0.4, 1.0))
		return
	if _agents.get_agent_count() >= _housing_capacity():
		_spawn_floating_text(_tile_center(_camp_tile), "Need housing", Color(1.0, 0.68, 0.3, 1.0))
		return
	var old_count: int = _agents.get_agent_count()
	_spend_cost(cost)
	_agents.add_agents(1, _tile_center(_camp_tile))
	_recompute_homes()
	_clamp_job_counts()
	_sync_agent_tracking()
	_record_agent_action(old_count, "Recruited into the village")
	_spawn_floating_text(_tile_center(_camp_tile), "+1 Settler", Color(0.65, 0.95, 1.0, 1.0))


func _on_fast_house_pressed() -> void:
	var cost: Dictionary = POP_ACTIONS["house"]["cost"]
	if not _can_afford(cost):
		_spawn_floating_text(_tile_center(_camp_tile), "Need resources", Color(1.0, 0.55, 0.4, 1.0))
		return
	_spend_cost(cost)
	_buildings["house"] = int(_buildings["house"]) + 1
	_place_house_near_target()
	_recompute_homes()
	_mark_settler_weapons_dirty()
	_spawn_floating_text(_tile_center(_camp_tile), "+2 Housing", Color(0.95, 0.87, 0.45, 1.0))


func _on_craft_tool_pressed(tool_key: String) -> void:
	if int(_buildings.get("workshop", 0)) <= 0:
		_spawn_floating_text(_tile_center(_camp_tile), "Need a Refinery", Color(1.0, 0.62, 0.42, 1.0))
		return
	var recipe: Dictionary = TOOL_CRAFT_RECIPES.get(tool_key, {})
	if recipe.is_empty():
		return
	if not _can_afford(recipe):
		_spawn_floating_text(_tile_center(_camp_tile), "Need materials", Color(1.0, 0.62, 0.42, 1.0))
		return
	_spend_cost(recipe)
	var next_count: int = int(_tool_inventory.get(tool_key, 0)) + 1
	_tool_inventory[tool_key] = next_count
	_mark_tool_state_dirty()
	_spawn_floating_text(_tile_center(_camp_tile), "+1 %s" % _tool_name_for_id(_tool_id_for_inventory_key(tool_key)), Color(0.62, 0.95, 0.78, 1.0))


func _on_tool_quick_equip_by_role_pressed() -> void:
	for i in _settler_tool_modes.size():
		if int(_settler_tool_modes[i]) != TOOL_MODE_AUTO:
			_settler_tool_modes[i] = TOOL_MODE_AUTO
	_mark_tool_state_dirty()
	_rebalance_auto_tools_by_role()
	_spawn_floating_text(_tile_center(_camp_tile), "Auto-equipped by role", Color(0.68, 0.92, 1.0, 1.0))


func _on_tool_quick_clear_locks_pressed() -> void:
	var changed: bool = false
	for i in _settler_tool_modes.size():
		if int(_settler_tool_modes[i]) != TOOL_MODE_AUTO:
			_settler_tool_modes[i] = TOOL_MODE_AUTO
			changed = true
	if changed:
		_mark_tool_state_dirty()
	_apply_auto_tool_assignments()
	_spawn_floating_text(_tile_center(_camp_tile), "Tool locks cleared", Color(0.68, 0.92, 1.0, 1.0))


func _on_tool_quick_rebalance_pressed() -> void:
	_rebalance_auto_tools_by_role()
	_spawn_floating_text(_tile_center(_camp_tile), "Tools rebalanced", Color(0.68, 0.92, 1.0, 1.0))


func _build_hover_ui() -> void:
	var ui_layer: CanvasLayer = $UI
	_hover_panel = PanelContainer.new()
	_hover_panel.size = Vector2(280.0, 220.0)
	_hover_panel.visible = false
	ui_layer.add_child(_hover_panel)

	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = UI_BG_ALT
	panel_style.border_width_left = 1
	panel_style.border_width_top = 1
	panel_style.border_width_right = 1
	panel_style.border_width_bottom = 1
	panel_style.border_color = UI_BORDER
	panel_style.corner_radius_top_left = 2
	panel_style.corner_radius_top_right = 2
	panel_style.corner_radius_bottom_left = 2
	panel_style.corner_radius_bottom_right = 2
	_hover_panel.add_theme_stylebox_override("panel", panel_style)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	_hover_panel.add_child(margin)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	margin.add_child(col)

	_hover_title_label = Label.new()
	_hover_title_label.text = "Settler"
	_hover_title_label.add_theme_font_size_override("font_size", 16)
	col.add_child(_hover_title_label)

	_hover_body_label = RichTextLabel.new()
	_hover_body_label.bbcode_enabled = true
	_hover_body_label.scroll_active = false
	_hover_body_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_hover_body_label.fit_content = true
	_hover_body_label.add_theme_font_size_override("normal_font_size", 13)
	col.add_child(_hover_body_label)

	# Job override buttons — only visible when a settler is pinned
	_job_btn_row = HBoxContainer.new()
	_job_btn_row.add_theme_constant_override("separation", 4)
	_job_btn_row.visible = false
	col.add_child(_job_btn_row)

	var btn_data := [
		["Farm",   Color(0.95, 0.8, 0.32), JOB_FARM],
		["Lumber", Color(0.22, 0.84, 0.34), JOB_LUMBER],
		["Mine",   Color(0.74, 0.8, 0.88), JOB_STONE],
		["Hunt",   Color(0.85, 0.55, 0.2),  JOB_HUNT],
		["Scout",  Color(0.5, 0.82, 0.98), JOB_SCOUT],
		["Auto",   Color(0.55, 0.55, 0.55), -1],
	]
	for entry in btn_data:
		var btn := Button.new()
		btn.text = entry[0]
		btn.add_theme_font_size_override("font_size", 12)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var bstyle := StyleBoxFlat.new()
		bstyle.bg_color = (entry[1] as Color).darkened(0.45)
		bstyle.border_color = entry[1]
		bstyle.border_width_left = 1
		bstyle.border_width_top = 1
		bstyle.border_width_right = 1
		bstyle.border_width_bottom = 1
		bstyle.corner_radius_top_left = 2
		bstyle.corner_radius_top_right = 2
		bstyle.corner_radius_bottom_left = 2
		bstyle.corner_radius_bottom_right = 2
		btn.add_theme_stylebox_override("normal", bstyle)
		var job_id: int = entry[2]
		btn.pressed.connect(Callable(self, "_set_pinned_settler_job").bind(job_id))
		_job_btn_row.add_child(btn)

	# Tool equip buttons — only visible when a settler is pinned
	_tool_btn_row = HBoxContainer.new()
	_tool_btn_row.add_theme_constant_override("separation", 4)
	_tool_btn_row.visible = false
	col.add_child(_tool_btn_row)

	var tool_data := [
		["Hands", Color(0.56, 0.56, 0.56), TOOL_HAND],
		["Axe", Color(0.2, 0.78, 0.28), TOOL_AXE],
		["Pick", Color(0.64, 0.76, 0.92), TOOL_PICK],
		["Scythe", Color(0.9, 0.84, 0.3), TOOL_SCYTHE],
	]
	for entry in tool_data:
		var tbtn := Button.new()
		tbtn.text = entry[0]
		tbtn.add_theme_font_size_override("font_size", 12)
		tbtn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var tstyle := StyleBoxFlat.new()
		tstyle.bg_color = (entry[1] as Color).darkened(0.45)
		tstyle.border_color = entry[1]
		tstyle.border_width_left = 1
		tstyle.border_width_top = 1
		tstyle.border_width_right = 1
		tstyle.border_width_bottom = 1
		tstyle.corner_radius_top_left = 2
		tstyle.corner_radius_top_right = 2
		tstyle.corner_radius_bottom_left = 2
		tstyle.corner_radius_bottom_right = 2
		tbtn.add_theme_stylebox_override("normal", tstyle)
		var tool_id: int = entry[2]
		tbtn.pressed.connect(Callable(self, "_set_pinned_settler_tool").bind(tool_id))
		_tool_btn_row.add_child(tbtn)

	_tool_mode_btn = Button.new()
	_tool_mode_btn.text = "Tool Mode: Auto"
	_tool_mode_btn.custom_minimum_size = Vector2(120.0, 24.0)
	_tool_mode_btn.add_theme_font_size_override("font_size", 12)
	_tool_mode_btn.visible = false
	_tool_mode_btn.pressed.connect(_toggle_pinned_settler_tool_mode)
	col.add_child(_tool_mode_btn)

	_position_hover_panel()


func _position_hover_panel() -> void:
	if _hover_panel == null:
		return
	var vp := get_viewport_rect().size
	_hover_panel.position = Vector2(vp.x - _hover_panel.size.x - 12.0, 58.0)


func _set_pinned_settler_job(job_id: int) -> void:
	if _pinned_agent_idx < 0:
		return
	if job_id == JOB_SCOUT and not _scouting_unlocked():
		_record_agent_action(_pinned_agent_idx, "Scouting locked (build Scout Lodge)")
		return
	if job_id == JOB_SCOUT and _active_scout_count_excluding(_pinned_agent_idx) >= _scout_job_cap():
		_record_agent_action(_pinned_agent_idx, "Scout cap reached (expand support structures)")
		return
	if job_id < 0:
		_settler_job_overrides.erase(_pinned_agent_idx)
		_record_agent_action(_pinned_agent_idx, "Job set to Auto")
	else:
		_settler_job_overrides[_pinned_agent_idx] = job_id
		var name_map := {JOB_FARM: "Farmer", JOB_LUMBER: "Lumberjack", JOB_STONE: "Stone Miner", JOB_HUNT: "Hunter", JOB_SCOUT: "Scout"}
		_record_agent_action(_pinned_agent_idx, "Job set to %s" % name_map[job_id])
	# Clear cached resource target so the new job takes effect immediately
	_release_resource_claim(_pinned_agent_idx)
	_settler_day_plan_targets.erase(_pinned_agent_idx)
	_settler_day_plan_job.erase(_pinned_agent_idx)
	_agent_last_state.erase(_pinned_agent_idx)
	_agent_job_colors_dirty = true
	_apply_auto_tool_for_settler(_pinned_agent_idx)
	_mark_settler_weapons_dirty()


func _set_pinned_settler_tool(tool_id: int) -> void:
	if _pinned_agent_idx < 0:
		return
	if _pinned_agent_idx >= _settler_tools.size():
		return
	var next_tool: int = _coerce_tool_id(tool_id)
	if not _try_set_settler_tool(_pinned_agent_idx, next_tool, TOOL_MODE_LOCKED):
		_notify_tool_shortage(next_tool)
		_record_agent_action(_pinned_agent_idx, "No %s available" % _tool_name_for_id(next_tool))
		return
	_record_agent_action(_pinned_agent_idx, "Tool equipped: %s" % _tool_name_for_id(next_tool))


func _toggle_pinned_settler_tool_mode() -> void:
	if _pinned_agent_idx < 0 or _pinned_agent_idx >= _settler_tools.size():
		return
	var current_mode: int = _tool_mode_for_settler(_pinned_agent_idx)
	var next_mode: int = TOOL_MODE_AUTO if current_mode == TOOL_MODE_LOCKED else TOOL_MODE_LOCKED
	if _pinned_agent_idx < _settler_tool_modes.size():
		_settler_tool_modes[_pinned_agent_idx] = next_mode
	_mark_tool_state_dirty()
	if next_mode == TOOL_MODE_AUTO:
		_apply_auto_tool_for_settler(_pinned_agent_idx)
	_record_agent_action(_pinned_agent_idx, "Tool mode: %s" % _tool_mode_name(next_mode))


func _update_hovered_agent() -> void:
	var agents: PackedVector2Array = _agents.get_agent_positions()
	if agents.is_empty():
		_hovered_agent_idx = -1
		return

	var mouse_world: Vector2 = get_global_mouse_position()
	var r2: float = _hover_probe_radius_px * _hover_probe_radius_px
	var best_idx: int = -1
	var best_d2: float = 1e30

	for i in agents.size():
		var d2: float = mouse_world.distance_squared_to(agents[i])
		if d2 <= r2 and d2 < best_d2:
			best_idx = i
			best_d2 = d2

	_hovered_agent_idx = best_idx


func _inspected_agent_idx() -> int:
	if _pinned_agent_idx >= 0:
		return _pinned_agent_idx
	return _hovered_agent_idx


func _sync_agent_tracking() -> void:
	var count: int = _agents.get_agent_count()
	var previous_count: int = _tracked_agent_count if _tracked_agent_count >= 0 else _settler_names.size()
	if previous_count == count and _settler_names.size() >= count:
		var repaired: bool = false
		for i in count:
			var clean_name: String = _sanitize_settler_name(_settler_names[i], i)
			if clean_name != _settler_names[i]:
				_settler_names[i] = clean_name
				repaired = true
		if not repaired:
			return
	_tracked_agent_count = count
	_sync_agent_tracking_on_population_change(count, previous_count)


func _sanitize_settler_name(raw_name: String, settler_index: int) -> String:
	var clean: String = raw_name.strip_edges()
	if clean.is_empty():
		return "Settler %d" % (settler_index + 1)
	return clean


func _roll_settler_name() -> String:
	if SETTLER_NAMES.is_empty():
		return "Settler %d" % (_settler_names.size() + 1)
	var pick_idx: int = _rng.randi_range(0, SETTLER_NAMES.size() - 1)
	var guard: int = 0
	while (_settler_names.has(SETTLER_NAMES[pick_idx]) or String(SETTLER_NAMES[pick_idx]).strip_edges().is_empty()) and guard < SETTLER_NAMES.size() * 2:
		pick_idx = _rng.randi_range(0, SETTLER_NAMES.size() - 1)
		guard += 1
	var candidate: String = String(SETTLER_NAMES[pick_idx]).strip_edges()
	if not candidate.is_empty() and not _settler_names.has(candidate):
		return candidate
	return "Settler %d" % (_settler_names.size() + 1)


func _sync_agent_tracking_on_population_change(count: int, previous_count: int) -> void:
	if previous_count > count:
		for i in range(count, previous_count):
			var removed_tool: int = _coerce_tool_id(_settler_tools[i])
			if removed_tool == TOOL_HAND:
				continue
			var removed_key: String = _tool_inventory_key_for_id(removed_tool)
			if removed_key != "":
				_tool_inventory[removed_key] = int(_tool_inventory.get(removed_key, 0)) + 1
	_settler_mgr.ensure_core_buffers(count, _rng, WEAPON_SPEAR, TOOL_HAND, TOOL_MODE_AUTO)
	_settler_happiness = _settler_mgr.happiness
	_settler_attack_cooldowns = _settler_mgr.attack_cooldowns
	_settler_weapons = _settler_mgr.weapons
	_settler_tools = _settler_mgr.tools
	_settler_tool_modes = _settler_mgr.tool_modes
	if _settler_starvation_time.size() != count:
		var old_starve: PackedFloat32Array = _settler_starvation_time
		_settler_starvation_time.resize(count)
		for i in count:
			_settler_starvation_time[i] = old_starve[i] if i < old_starve.size() else 0.0
	_apply_auto_tool_assignments()
	_mark_tool_state_dirty()
	_sync_settler_think_buffers(count)
	_mark_settler_weapons_dirty()
	_assign_default_jobs_for_new_settlers(previous_count, count)
	_prime_new_settlers_for_immediate_work(previous_count, count)
	for i in range(previous_count, count):
		if not _agent_recent_actions.has(i):
			_agent_recent_actions[i] = []
		if not _agent_last_state.has(i):
			_agent_last_state[i] = ""
	while _settler_names.size() < count:
		_settler_names.append(_sanitize_settler_name(_roll_settler_name(), _settler_names.size()))
	if _settler_names.size() > count:
		_settler_names.resize(count)
	for i in _settler_names.size():
		_settler_names[i] = _sanitize_settler_name(_settler_names[i], i)
	if _pinned_agent_idx >= count:
		_pinned_agent_idx = -1
	if _agent_speed_multipliers.size() != count:
		var old_speed: PackedFloat32Array = _agent_speed_multipliers
		_agent_speed_multipliers.resize(count)
		for i in count:
			_agent_speed_multipliers[i] = old_speed[i] if i < old_speed.size() else 1.0
	if _agent_job_colors.size() != count:
		_agent_job_colors.resize(count)
		for i in count:
			_agent_job_colors[i] = Color(0.35, 0.9, 1.0, 1.0)
		_agent_job_colors_dirty = true
	for key_v in _hunter_boost_until.keys():
		var idx: int = int(key_v)
		if idx < 0 or idx >= count:
			_hunter_boost_until.erase(key_v)
	for key_v in _hunter_rest_until.keys():
		var idx: int = int(key_v)
		if idx < 0 or idx >= count:
			_hunter_rest_until.erase(key_v)
	for key_v in _hunter_runtime_state.keys():
		var idx: int = int(key_v)
		if idx < 0 or idx >= count:
			_hunter_runtime_state.erase(key_v)
			_active_indicator_settlers_dirty = true
	for key_v in _agent_recent_actions.keys():
		var idx: int = int(key_v)
		if idx < 0 or idx >= count:
			_agent_recent_actions.erase(key_v)
	for key_v in _agent_last_state.keys():
		var idx: int = int(key_v)
		if idx < 0 or idx >= count:
			_agent_last_state.erase(key_v)
	_agent_job_colors_dirty = true
	_cleanup_resource_claims(count)


func _prime_new_settlers_for_immediate_work(previous_count: int, count: int) -> void:
	if count <= previous_count:
		return
	var now_sec: float = Time.get_ticks_msec() * 0.001
	var is_night_now: bool = _is_night()
	var agents: PackedVector2Array = _agents.get_agent_positions()
	var targets: PackedVector2Array = _agents.get_agent_targets()
	if targets.size() != count:
		targets.resize(count)
		for t in count:
			targets[t] = _target
	for i in range(previous_count, count):
		if i >= _settler_next_think_time.size() or i >= _settler_think_state.size():
			continue
		_set_settler_next_think_time(i, now_sec)
		_settler_think_state[i] = THINK_THINKING
		if i < _settler_idle_time.size():
			_settler_idle_time[i] = 0.0
		if i < _settler_last_pos.size() and i < agents.size():
			_settler_last_pos[i] = agents[i]
		if is_night_now or i >= agents.size():
			continue
		var from_tile: Vector2i = _world_to_tile(agents[i])
		var job: int = _job_for_settler(i)
		_update_day_plan_for_settler(i, from_tile, job)
		if _settler_day_plan_targets.has(i) and int(_settler_day_plan_job.get(i, -1)) == job:
			var plan_tile: Vector2i = _settler_day_plan_targets[i]
			var step_tile: Vector2i = _segment_target_toward(from_tile, plan_tile)
			targets[i] = _tile_center(step_tile)
	_agents.set_agent_targets(targets)
	_active_indicator_settlers_dirty = true


func _mark_settler_weapons_dirty() -> void:
	_settler_weapons_dirty = true


func _refresh_settler_weapons_if_dirty() -> void:
	if not _settler_weapons_dirty:
		return
	_settler_weapons_dirty = false
	_rebalance_settler_weapons()


func _cleanup_resource_claims(settler_count: int) -> void:
	_resource_mgr.cleanup_claims(settler_count, Callable(self, "_tile_key"))


func _remap_indexed_dictionary(source: Dictionary, old_to_new: PackedInt32Array) -> Dictionary:
	var remapped: Dictionary = {}
	for key_v in source.keys():
		var old_idx: int = int(key_v)
		if old_idx < 0 or old_idx >= old_to_new.size():
			continue
		var new_idx: int = int(old_to_new[old_idx])
		if new_idx < 0:
			continue
		remapped[new_idx] = source[key_v]
	return remapped


func _replace_dictionary_in_place(target: Dictionary, replacement: Dictionary) -> void:
	target.clear()
	for key_v in replacement.keys():
		target[key_v] = replacement[key_v]


func _remove_settlers_by_indices(indices: PackedInt32Array, reason: String, source_pos: Vector2 = Vector2.ZERO) -> int:
	var old_count: int = _agents.get_agent_count()
	if old_count <= 0 or indices.is_empty():
		return 0
	var remove_flags: PackedByteArray = PackedByteArray()
	remove_flags.resize(old_count)
	remove_flags.fill(0)
	var unique_sorted: PackedInt32Array = PackedInt32Array()
	var kill_count: int = 0
	for idx_v in indices:
		var idx: int = int(idx_v)
		if idx < 0 or idx >= old_count:
			continue
		if remove_flags[idx] == 1:
			continue
		remove_flags[idx] = 1
		unique_sorted.append(idx)
		kill_count += 1
	if kill_count <= 0:
		return 0
	unique_sorted.sort()

	var old_to_new: PackedInt32Array = PackedInt32Array()
	old_to_new.resize(old_count)
	old_to_new.fill(-1)
	var survivor_idx: int = 0
	for i in old_count:
		if remove_flags[i] == 1:
			continue
		old_to_new[i] = survivor_idx
		survivor_idx += 1

	for i in unique_sorted.size():
		var dead_idx: int = int(unique_sorted[i])
		_release_resource_claim(dead_idx)

	var old_happiness: PackedFloat32Array = _settler_happiness
	var old_attack_cooldowns: PackedFloat32Array = _settler_attack_cooldowns
	var old_weapons: PackedInt32Array = _settler_weapons
	var old_tools: PackedInt32Array = _settler_tools
	var old_tool_modes: PackedInt32Array = _settler_tool_modes
	var old_next_think_time: PackedFloat32Array = _settler_next_think_time
	var old_think_state: PackedInt32Array = _settler_think_state
	var old_last_pos: PackedVector2Array = _settler_last_pos
	var old_idle_time: PackedFloat32Array = _settler_idle_time
	var old_homes: PackedInt32Array = _settler_homes
	var old_starvation: PackedFloat32Array = _settler_starvation_time
	var old_speed: PackedFloat32Array = _agent_speed_multipliers
	var old_colors: PackedColorArray = _agent_job_colors
	var old_names: Array[String] = _settler_names.duplicate()

	var new_count: int = old_count - kill_count
	var new_happiness: PackedFloat32Array = PackedFloat32Array()
	new_happiness.resize(new_count)
	var new_attack_cooldowns: PackedFloat32Array = PackedFloat32Array()
	new_attack_cooldowns.resize(new_count)
	var new_weapons: PackedInt32Array = PackedInt32Array()
	new_weapons.resize(new_count)
	var new_tools: PackedInt32Array = PackedInt32Array()
	new_tools.resize(new_count)
	var new_tool_modes: PackedInt32Array = PackedInt32Array()
	new_tool_modes.resize(new_count)
	var new_next_think_time: PackedFloat32Array = PackedFloat32Array()
	new_next_think_time.resize(new_count)
	var new_think_state: PackedInt32Array = PackedInt32Array()
	new_think_state.resize(new_count)
	var new_last_pos: PackedVector2Array = PackedVector2Array()
	new_last_pos.resize(new_count)
	var new_idle_time: PackedFloat32Array = PackedFloat32Array()
	new_idle_time.resize(new_count)
	var new_homes: PackedInt32Array = PackedInt32Array()
	new_homes.resize(new_count)
	var new_starvation: PackedFloat32Array = PackedFloat32Array()
	new_starvation.resize(new_count)
	var new_speed: PackedFloat32Array = PackedFloat32Array()
	new_speed.resize(new_count)
	var new_colors: PackedColorArray = PackedColorArray()
	new_colors.resize(new_count)
	var new_names: Array[String] = []

	for old_idx in old_count:
		var new_idx: int = int(old_to_new[old_idx])
		if new_idx < 0:
			continue
		new_happiness[new_idx] = old_happiness[old_idx] if old_idx < old_happiness.size() else 0.5
		new_attack_cooldowns[new_idx] = old_attack_cooldowns[old_idx] if old_idx < old_attack_cooldowns.size() else 0.0
		new_weapons[new_idx] = old_weapons[old_idx] if old_idx < old_weapons.size() else WEAPON_SPEAR
		new_tools[new_idx] = old_tools[old_idx] if old_idx < old_tools.size() else TOOL_HAND
		new_tool_modes[new_idx] = old_tool_modes[old_idx] if old_idx < old_tool_modes.size() else TOOL_MODE_AUTO
		new_next_think_time[new_idx] = old_next_think_time[old_idx] if old_idx < old_next_think_time.size() else 0.0
		new_think_state[new_idx] = old_think_state[old_idx] if old_idx < old_think_state.size() else THINK_THINKING
		new_last_pos[new_idx] = old_last_pos[old_idx] if old_idx < old_last_pos.size() else Vector2.ZERO
		new_idle_time[new_idx] = old_idle_time[old_idx] if old_idx < old_idle_time.size() else 0.0
		new_homes[new_idx] = old_homes[old_idx] if old_idx < old_homes.size() else -1
		new_starvation[new_idx] = old_starvation[old_idx] if old_idx < old_starvation.size() else 0.0
		new_speed[new_idx] = old_speed[old_idx] if old_idx < old_speed.size() else 1.0
		new_colors[new_idx] = old_colors[old_idx] if old_idx < old_colors.size() else Color(0.35, 0.9, 1.0, 1.0)
		var source_name: String = old_names[old_idx] if old_idx < old_names.size() else ""
		new_names.append(_sanitize_settler_name(source_name, new_idx))

	var remapped_recent_actions: Dictionary = _remap_indexed_dictionary(_agent_recent_actions, old_to_new)
	var remapped_last_state: Dictionary = _remap_indexed_dictionary(_agent_last_state, old_to_new)
	var remapped_resource_targets: Dictionary = _remap_indexed_dictionary(_settler_resource_targets, old_to_new)
	var remapped_day_plan_targets: Dictionary = _remap_indexed_dictionary(_settler_day_plan_targets, old_to_new)
	var remapped_day_plan_job: Dictionary = _remap_indexed_dictionary(_settler_day_plan_job, old_to_new)
	var remapped_job_overrides: Dictionary = _remap_indexed_dictionary(_settler_job_overrides, old_to_new)
	var remapped_boost_until: Dictionary = _remap_indexed_dictionary(_hunter_boost_until, old_to_new)
	var remapped_rest_until: Dictionary = _remap_indexed_dictionary(_hunter_rest_until, old_to_new)
	var remapped_runtime_state: Dictionary = _remap_indexed_dictionary(_hunter_runtime_state, old_to_new)

	var remapped_claims: Dictionary = {}
	for key_v in _resource_claims.keys():
		var owner: int = int(_resource_claims[key_v])
		if owner < 0 or owner >= old_to_new.size():
			continue
		var new_owner: int = int(old_to_new[owner])
		if new_owner < 0:
			continue
		remapped_claims[key_v] = new_owner

	_agents.remove_agents_by_indices(unique_sorted)

	_settler_mgr.happiness = new_happiness
	_settler_mgr.attack_cooldowns = new_attack_cooldowns
	_settler_mgr.weapons = new_weapons
	_settler_mgr.tools = new_tools
	_settler_mgr.tool_modes = new_tool_modes
	_settler_mgr.next_think_time = new_next_think_time
	_settler_mgr.think_state = new_think_state
	_settler_mgr.last_pos = new_last_pos
	_settler_mgr.idle_time = new_idle_time

	_settler_happiness = _settler_mgr.happiness
	_settler_attack_cooldowns = _settler_mgr.attack_cooldowns
	_settler_weapons = _settler_mgr.weapons
	_settler_tools = _settler_mgr.tools
	_settler_tool_modes = _settler_mgr.tool_modes
	_settler_next_think_time = _settler_mgr.next_think_time
	_settler_think_state = _settler_mgr.think_state
	_settler_last_pos = _settler_mgr.last_pos
	_settler_idle_time = _settler_mgr.idle_time
	_settler_homes = new_homes
	_settler_starvation_time = new_starvation
	_settler_names = new_names
	_agent_speed_multipliers = new_speed
	_agent_job_colors = new_colors

	_agent_recent_actions = remapped_recent_actions
	_agent_last_state = remapped_last_state
	_settler_job_overrides = remapped_job_overrides
	_hunter_boost_until = remapped_boost_until
	_hunter_rest_until = remapped_rest_until
	_hunter_runtime_state = remapped_runtime_state
	_replace_dictionary_in_place(_settler_resource_targets, remapped_resource_targets)
	_replace_dictionary_in_place(_settler_day_plan_targets, remapped_day_plan_targets)
	_replace_dictionary_in_place(_settler_day_plan_job, remapped_day_plan_job)
	_replace_dictionary_in_place(_resource_claims, remapped_claims)
	_sync_resource_claim_ids()
	_cleanup_resource_claims(new_count)

	var remapped_hover: int = _hovered_agent_idx
	if remapped_hover >= 0 and remapped_hover < old_to_new.size():
		_hovered_agent_idx = int(old_to_new[remapped_hover])
	else:
		_hovered_agent_idx = -1
	var remapped_pinned: int = _pinned_agent_idx
	if remapped_pinned >= 0 and remapped_pinned < old_to_new.size():
		_pinned_agent_idx = int(old_to_new[remapped_pinned])
	else:
		_pinned_agent_idx = -1

	_settler_due_buckets.clear()
	_settler_due_versions.resize(new_count)
	_settler_due_versions.fill(0)
	_rebuild_settler_due_queue(Time.get_ticks_msec() * 0.001, new_count)
	_settler_candidate_seen.resize(new_count)
	_settler_candidate_seen.fill(0)
	_active_indicator_settlers.resize(0)
	_active_indicator_settler_pos.clear()
	_active_indicator_settlers_dirty = true
	_tracked_agent_count = new_count
	_clamp_job_counts()
	_recompute_homes()
	_mark_settler_weapons_dirty()
	_mark_tool_state_dirty()
	_spawn_floating_text(source_pos if source_pos != Vector2.ZERO else _tile_center(_camp_tile), "-%d settler" % kill_count, Color(1.0, 0.35, 0.3, 1.0))
	if new_count <= 0:
		_spawn_floating_text(_tile_center(_camp_tile), "Colony wiped out", Color(1.0, 0.2, 0.2, 1.0))
	else:
		_record_agent_action(0, "%d settler lost (%s)" % [kill_count, reason])
	return kill_count


func _mark_tool_state_dirty() -> void:
	_tool_state_dirty = true


func _coerce_tool_id(value: Variant) -> int:
	if typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT:
		return clampi(int(value), TOOL_HAND, TOOL_SCYTHE)
	if typeof(value) == TYPE_STRING:
		match String(value).to_lower():
			"axe":
				return TOOL_AXE
			"pick", "pickaxe":
				return TOOL_PICK
			"scythe":
				return TOOL_SCYTHE
			_:
				return TOOL_HAND
	return TOOL_HAND


func _normalize_tool_inventory(raw_value: Variant) -> Dictionary:
	var raw: Dictionary = raw_value if typeof(raw_value) == TYPE_DICTIONARY else {}
	return {
		"axe": maxi(0, int(raw.get("axe", raw.get("axes", 0)))),
		"pick": maxi(0, int(raw.get("pick", raw.get("picks", 0)))),
		"scythe": maxi(0, int(raw.get("scythe", raw.get("scythes", 0)))),
	}


func _migrate_tool_state_snapshot(raw_snapshot: Dictionary) -> Dictionary:
	var snapshot: Dictionary = raw_snapshot.duplicate(true)
	var changed: bool = false
	var version: int = int(snapshot.get("version", 0))
	if version < 1:
		changed = true
	if not snapshot.has("tool_inventory") and snapshot.has("inventory"):
		snapshot["tool_inventory"] = snapshot["inventory"]
		changed = true
	if not snapshot.has("settler_tools") and snapshot.has("tools"):
		snapshot["settler_tools"] = snapshot["tools"]
		changed = true
	if not snapshot.has("settler_tool_modes") and snapshot.has("tool_modes"):
		snapshot["settler_tool_modes"] = snapshot["tool_modes"]
		changed = true
	snapshot["tool_inventory"] = _normalize_tool_inventory(snapshot.get("tool_inventory", {}))
	if int(snapshot.get("version", 0)) != TOOL_STATE_VERSION:
		snapshot["version"] = TOOL_STATE_VERSION
		changed = true
	return {"snapshot": snapshot, "changed": changed}


func _capture_tool_state_snapshot() -> Dictionary:
	var tools_out: Array = []
	var tool_modes_out: Array = []
	for i in _settler_tools.size():
		tools_out.append(int(_settler_tools[i]))
	for i in _settler_tool_modes.size():
		tool_modes_out.append(int(_settler_tool_modes[i]))
	return {
		"version": TOOL_STATE_VERSION,
		"tool_inventory": _normalize_tool_inventory(_tool_inventory),
		"settler_tools": tools_out,
		"settler_tool_modes": tool_modes_out,
	}


func _apply_tool_state_snapshot(snapshot: Dictionary) -> void:
	_tool_inventory = _normalize_tool_inventory(snapshot.get("tool_inventory", {}))
	var tools_raw: Array = snapshot.get("settler_tools", [])
	var modes_raw: Array = snapshot.get("settler_tool_modes", [])
	var has_modes: bool = modes_raw.size() > 0
	for i in _settler_tools.size():
		if i < tools_raw.size():
			_settler_tools[i] = _coerce_tool_id(tools_raw[i])
		else:
			_settler_tools[i] = TOOL_HAND
	for i in _settler_tool_modes.size():
		if i < modes_raw.size():
			var mode_v: int = int(modes_raw[i])
			_settler_tool_modes[i] = TOOL_MODE_LOCKED if mode_v == TOOL_MODE_LOCKED else TOOL_MODE_AUTO
		elif not has_modes and _settler_tools[i] != TOOL_HAND:
			# Legacy snapshots with tools but no modes default to locked.
			_settler_tool_modes[i] = TOOL_MODE_LOCKED
		else:
			# Migration path for saves created before tool-mode persistence.
			_settler_tool_modes[i] = TOOL_MODE_AUTO
	_tool_state_dirty = false


func _load_tool_state() -> void:
	if not FileAccess.file_exists(TOOL_STATE_SAVE_PATH):
		return
	var f: FileAccess = FileAccess.open(TOOL_STATE_SAVE_PATH, FileAccess.READ)
	if f == null:
		return
	var text: String = f.get_as_text()
	if text.is_empty():
		return
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	var migrated: Dictionary = _migrate_tool_state_snapshot(parsed)
	_apply_tool_state_snapshot(migrated.get("snapshot", {}))
	if bool(migrated.get("changed", false)):
		_mark_tool_state_dirty()


func _save_tool_state(force: bool = false) -> void:
	if not force and not _tool_state_dirty:
		return
	var f: FileAccess = FileAccess.open(TOOL_STATE_SAVE_PATH, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify(_capture_tool_state_snapshot()))
	_tool_state_dirty = false


func _maybe_save_tool_state(delta: float) -> void:
	if not _tool_state_dirty:
		return
	_tool_state_save_accum += delta
	if _tool_state_save_accum < 3.0:
		return
	_tool_state_save_accum = 0.0
	_save_tool_state(false)


func _sync_settler_think_buffers(count: int) -> void:
	var now: float = Time.get_ticks_msec() * 0.001
	_settler_mgr.ensure_think_buffers(
		count,
		_agents.get_agent_positions(),
		now,
		settler_think_jitter_sec,
		_rng,
		THINK_EXECUTING
	)
	_settler_next_think_time = _settler_mgr.next_think_time
	_settler_think_state = _settler_mgr.think_state
	_settler_last_pos = _settler_mgr.last_pos
	_settler_idle_time = _settler_mgr.idle_time
	_sync_settler_due_queue(count, now)
	if _active_indicator_population_count != count:
		_active_indicator_settlers_dirty = true


func _think_jitter() -> float:
	if settler_think_jitter_sec <= 0.0:
		return 0.0
	return _rng.randf_range(-settler_think_jitter_sec, settler_think_jitter_sec)


func _schedule_next_think(index: int, now_sec: float, idle: bool = false) -> void:
	if index < 0 or index >= _settler_next_think_time.size():
		return
	var base: float = settler_idle_think_interval_sec if idle else settler_active_think_interval_sec
	_set_settler_next_think_time(index, now_sec + maxf(0.1, base + _think_jitter()))


func _sync_settler_due_queue(count: int, now_sec: float) -> void:
	if _settler_due_versions.size() != count:
		var old_versions := _settler_due_versions
		_settler_due_versions.resize(count)
		for i in count:
			_settler_due_versions[i] = old_versions[i] if i < old_versions.size() else 0
		_rebuild_settler_due_queue(now_sec, count)
		return
	if count > 0 and _settler_due_buckets.is_empty():
		# Safety net: if buckets are cleared unexpectedly, settlers can stop receiving decisions.
		_rebuild_settler_due_queue(now_sec, count)


func _rebuild_settler_due_queue(now_sec: float, count: int) -> void:
	_settler_due_buckets.clear()
	_settler_due_next_bucket_key = _think_bucket_key_for_time(now_sec)
	for i in count:
		_queue_settler_due_at(i, _settler_next_think_time[i])


func _set_settler_next_think_time(index: int, next_time_sec: float) -> void:
	if index < 0 or index >= _settler_next_think_time.size():
		return
	_settler_next_think_time[index] = next_time_sec
	_queue_settler_due_at(index, next_time_sec)


func _queue_settler_due_at(index: int, next_time_sec: float) -> void:
	if index < 0 or index >= _settler_due_versions.size():
		return
	var version: int = int(_settler_due_versions[index]) + 1
	_settler_due_versions[index] = version
	var bucket_key: int = _think_bucket_key_for_time(next_time_sec)
	if not _settler_due_buckets.has(bucket_key):
		_settler_due_buckets[bucket_key] = []
	var bucket: Array = _settler_due_buckets[bucket_key]
	bucket.append(_encode_settler_due_entry(index, version))
	_settler_due_buckets[bucket_key] = bucket


func _think_bucket_key_for_time(time_sec: float) -> int:
	return floori(time_sec * 4.0)


func _encode_settler_due_entry(index: int, version: int) -> int:
	return (int(version) << 32) | (index & 0xffffffff)


func _decode_settler_due_entry_index(entry: int) -> int:
	return int(entry & 0xffffffff)


func _decode_settler_due_entry_version(entry: int) -> int:
	return int(entry >> 32)


func _collect_due_settler_indices(now_sec: float, limit: int) -> PackedInt32Array:
	var out: PackedInt32Array = PackedInt32Array()
	if limit <= 0 or _settler_due_versions.is_empty():
		return out
	var current_bucket: int = _think_bucket_key_for_time(now_sec)
	if _settler_due_next_bucket_key > current_bucket:
		_settler_due_next_bucket_key = current_bucket
	var carry_over: Dictionary = {}
	for bucket_key in range(_settler_due_next_bucket_key, current_bucket + 1):
		if not _settler_due_buckets.has(bucket_key):
			continue
		var entries: Array = _settler_due_buckets[bucket_key]
		_settler_due_buckets.erase(bucket_key)
		for entry_v in entries:
			var entry: int = int(entry_v)
			var index: int = _decode_settler_due_entry_index(entry)
			var version: int = _decode_settler_due_entry_version(entry)
			if index < 0 or index >= _settler_due_versions.size():
				continue
			if int(_settler_due_versions[index]) != version:
				continue
			var target_bucket: int = _think_bucket_key_for_time(_settler_next_think_time[index])
			if target_bucket != bucket_key:
				continue
			if _settler_next_think_time[index] > now_sec:
				if not carry_over.has(bucket_key):
					carry_over[bucket_key] = []
				var carry_entries: Array = carry_over[bucket_key]
				carry_entries.append(entry)
				carry_over[bucket_key] = carry_entries
				continue
			out.append(index)
			if out.size() >= limit:
				for pending_key in carry_over.keys():
					_settler_due_buckets[int(pending_key)] = carry_over[pending_key]
				_settler_due_next_bucket_key = bucket_key
				return out
	for pending_key in carry_over.keys():
		_settler_due_buckets[int(pending_key)] = carry_over[pending_key]
	_settler_due_next_bucket_key = current_bucket
	return out


func _collect_monitor_settler_indices(count: int, budget: int, now_sec: float, seen: PackedByteArray) -> PackedInt32Array:
	var out: PackedInt32Array = PackedInt32Array()
	if count <= 0 or budget <= 0:
		return out
	for step in budget:
		var i: int = (_settler_decision_cursor + step) % count
		if i < seen.size() and seen[i] != 0:
			continue
		if i >= _settler_next_think_time.size():
			continue
		if _settler_next_think_time[i] <= now_sec:
			continue
		if i < seen.size():
			seen[i] = 1
		out.append(i)
	return out


func _effective_settler_scan_budget(count: int, decision_budget: int, night_plan_budget: int, is_night: bool) -> int:
	if count <= 0:
		return 0
	var base_budget: int = night_plan_budget if is_night else decision_budget
	var min_scan: int = maxi(64, base_budget * 2)
	var fractional_scan: int = ceili(float(count) * (0.5 if is_night else 0.35))
	return mini(count, maxi(min_scan, fractional_scan))


func _effective_settler_monitor_budget(count: int, decision_budget: int, night_plan_budget: int, is_night: bool) -> int:
	if count <= 0:
		return 0
	var base_budget: int = night_plan_budget if is_night else decision_budget
	return mini(count, maxi(48, base_budget))


func _weapon_name_for_id(weapon_id: int) -> String:
	var profile: Dictionary = _weapon_profile(weapon_id)
	return String(profile.get("name", "Weapon"))


func _tool_name_for_id(tool_id: int) -> String:
	match tool_id:
		TOOL_AXE:
			return "Axe"
		TOOL_PICK:
			return "Pick"
		TOOL_SCYTHE:
			return "Scythe"
		_:
			return "Hands"


func _tool_mode_name(mode_id: int) -> String:
	return "Locked" if mode_id == TOOL_MODE_LOCKED else "Auto"


func _tool_mode_for_settler(index: int) -> int:
	if index < 0 or index >= _settler_tool_modes.size():
		return TOOL_MODE_AUTO
	return TOOL_MODE_LOCKED if int(_settler_tool_modes[index]) == TOOL_MODE_LOCKED else TOOL_MODE_AUTO


func _tool_mode_name_for_settler(index: int) -> String:
	return _tool_mode_name(_tool_mode_for_settler(index))


func _preferred_tool_for_job(job_id: int) -> int:
	match job_id:
		JOB_LUMBER:
			return TOOL_AXE
		JOB_STONE:
			return TOOL_PICK
		JOB_FARM:
			return TOOL_SCYTHE
		_:
			return TOOL_HAND


func _tool_inventory_key_for_id(tool_id: int) -> String:
	match tool_id:
		TOOL_AXE:
			return "axe"
		TOOL_PICK:
			return "pick"
		TOOL_SCYTHE:
			return "scythe"
		_:
			return ""


func _tool_id_for_inventory_key(tool_key: String) -> int:
	match tool_key:
		"axe":
			return TOOL_AXE
		"pick":
			return TOOL_PICK
		"scythe":
			return TOOL_SCYTHE
		_:
			return TOOL_HAND


func _try_set_settler_tool(index: int, tool_id: int, mode_override: int = -1) -> bool:
	if index < 0 or index >= _settler_tools.size():
		return false
	var old_tool: int = _coerce_tool_id(_settler_tools[index])
	var next_tool: int = _coerce_tool_id(tool_id)
	if old_tool != next_tool:
		if next_tool != TOOL_HAND:
			var next_key: String = _tool_inventory_key_for_id(next_tool)
			if next_key == "" or int(_tool_inventory.get(next_key, 0)) <= 0:
				return false
			_tool_inventory[next_key] = maxi(0, int(_tool_inventory.get(next_key, 0)) - 1)
		if old_tool != TOOL_HAND:
			var old_key: String = _tool_inventory_key_for_id(old_tool)
			if old_key != "":
				_tool_inventory[old_key] = int(_tool_inventory.get(old_key, 0)) + 1
		_settler_tools[index] = next_tool
		_mark_tool_state_dirty()
	if mode_override >= 0 and index < _settler_tool_modes.size():
		var next_mode: int = TOOL_MODE_LOCKED if mode_override == TOOL_MODE_LOCKED else TOOL_MODE_AUTO
		if int(_settler_tool_modes[index]) != next_mode:
			_settler_tool_modes[index] = next_mode
			_mark_tool_state_dirty()
	return true


func _apply_auto_tool_for_settler(index: int) -> void:
	if index < 0 or index >= _settler_tools.size():
		return
	if _tool_mode_for_settler(index) != TOOL_MODE_AUTO:
		return
	var preferred: int = _preferred_tool_for_job(_job_for_settler(index))
	if _try_set_settler_tool(index, preferred, TOOL_MODE_AUTO):
		return
	_notify_tool_shortage(preferred)
	_try_set_settler_tool(index, TOOL_HAND, TOOL_MODE_AUTO)


func _apply_auto_tool_assignments() -> void:
	_auto_tool_assign_pending = true
	_process_auto_tool_assignments()


func _process_auto_tool_assignments() -> void:
	if not _auto_tool_assign_pending:
		return
	var total: int = _settler_tools.size()
	if total <= 0:
		_auto_tool_assign_pending = false
		_auto_tool_assign_cursor = 0
		return
	var budget: int = maxi(1, auto_tool_assign_budget_per_tick)
	var processed: int = 0
	while processed < budget and _auto_tool_assign_pending:
		if _auto_tool_assign_cursor >= total:
			_auto_tool_assign_cursor = 0
		_apply_auto_tool_for_settler(_auto_tool_assign_cursor)
		_auto_tool_assign_cursor += 1
		processed += 1
		if _auto_tool_assign_cursor >= total:
			_auto_tool_assign_cursor = 0
			_auto_tool_assign_pending = false


func _notify_tool_shortage(tool_id: int) -> void:
	if tool_id == TOOL_HAND:
		return
	var now_msec: int = Time.get_ticks_msec()
	if now_msec - _tool_shortage_notice_msec < 1000:
		return
	_tool_shortage_notice_msec = now_msec
	_spawn_floating_text(_tile_center(_camp_tile), "Tool shortage: %s" % _tool_name_for_id(tool_id), Color(1.0, 0.62, 0.42, 1.0))


func _rebalance_auto_tools_by_role() -> void:
	for i in _settler_tools.size():
		if _tool_mode_for_settler(i) != TOOL_MODE_AUTO:
			continue
		var tool_id: int = _coerce_tool_id(_settler_tools[i])
		if tool_id == TOOL_HAND:
			continue
		var inv_key: String = _tool_inventory_key_for_id(tool_id)
		if inv_key != "":
			_tool_inventory[inv_key] = int(_tool_inventory.get(inv_key, 0)) + 1
		_settler_tools[i] = TOOL_HAND
	_mark_tool_state_dirty()
	_apply_auto_tool_assignments()


func _tool_for_settler(index: int) -> int:
	if index < 0 or index >= _settler_tools.size():
		return TOOL_HAND
	return int(_settler_tools[index])


func _tool_harvest_mult(index: int, job: int) -> float:
	var strength: float = clampf(tool_harvest_secondary_strength, 0.1, 1.0)
	var tool_id: int = _tool_for_settler(index)
	match tool_id:
		TOOL_AXE:
			if job == JOB_LUMBER:
				return 1.0 + (1.35 - 1.0) * strength
			if job == JOB_STONE:
				return 1.0 + (0.9 - 1.0) * strength
			return 1.0 + (0.95 - 1.0) * strength
		TOOL_PICK:
			if job == JOB_STONE:
				return 1.0 + (1.35 - 1.0) * strength
			if job == JOB_LUMBER:
				return 1.0 + (0.9 - 1.0) * strength
			return 1.0 + (0.95 - 1.0) * strength
		TOOL_SCYTHE:
			if job == JOB_FARM:
				return 1.0 + (1.3 - 1.0) * strength
			return 1.0 + (0.9 - 1.0) * strength
		_:
			return 1.0


func _tool_effect_text(index: int, job: int) -> String:
	var m: float = _tool_harvest_mult(index, job)
	if m > 1.001:
		return "+%d%% harvest" % int(round((m - 1.0) * 100.0))
	if m < 0.999:
		return "-%d%% off-role" % int(round((1.0 - m) * 100.0))
	return "No bonus"


func _tool_expected_benefit_text(index: int, job: int) -> String:
	var harvest_text: String = _tool_effect_text(index, job)
	var combat_profile: Dictionary = _tool_combat_modifiers_for_settler(index)
	var dmg_pct: int = int(round((float(combat_profile.get("damage_mult", 1.0)) - 1.0) * 100.0))
	var spd_pct: int = int(round((float(combat_profile.get("speed_mult", 1.0)) - 1.0) * 100.0))
	var combat_text: String = "Combat Dmg %+d%% / Spd %+d%%" % [dmg_pct, spd_pct]
	return "%s | %s" % [harvest_text, combat_text]


func _tool_combat_profile_for_id(tool_id: int) -> Dictionary:
	var strength: float = clampf(tool_combat_secondary_strength, 0.1, 1.0)
	match tool_id:
		TOOL_AXE:
			return {
				"damage_mult": 1.0 + (1.08 - 1.0) * strength,
				"speed_mult": 1.0 + (0.97 - 1.0) * strength,
				"crit_chance": 0.04 * strength,
				"crit_mult": 1.0 + (1.40 - 1.0) * strength,
				"defense_mult": 1.0 + (1.02 - 1.0) * strength,
			}
		TOOL_PICK:
			return {
				"damage_mult": 1.0 + (1.14 - 1.0) * strength,
				"speed_mult": 1.0 + (0.92 - 1.0) * strength,
				"crit_chance": 0.02 * strength,
				"crit_mult": 1.0 + (1.45 - 1.0) * strength,
				"defense_mult": 1.0 + (1.08 - 1.0) * strength,
			}
		TOOL_SCYTHE:
			return {
				"damage_mult": 1.0 + (0.94 - 1.0) * strength,
				"speed_mult": 1.0 + (1.08 - 1.0) * strength,
				"crit_chance": 0.06 * strength,
				"crit_mult": 1.0 + (1.30 - 1.0) * strength,
				"defense_mult": 1.0 + (0.92 - 1.0) * strength,
			}
		_:
			return {
				"damage_mult": 1.0,
				"speed_mult": 1.0,
				"crit_chance": 0.0,
				"crit_mult": 1.35,
				"defense_mult": 1.0,
			}


func _tool_combat_modifiers_for_settler(index: int) -> Dictionary:
	return _tool_combat_profile_for_id(_tool_for_settler(index))


func _tool_defense_mult_for_settler(index: int) -> float:
	var profile: Dictionary = _tool_combat_modifiers_for_settler(index)
	return maxf(0.5, float(profile.get("defense_mult", 1.0)))


func _weapon_profile(weapon_id: int) -> Dictionary:
	var data: WeaponData = _weapon_registry.get(weapon_id, null)
	if data == null:
		data = _default_weapon_data(weapon_id)
	return data.to_profile(_ranged_range_mult)


func _weapon_for_settler(index: int) -> int:
	if index < 0 or index >= _settler_weapons.size():
		return WEAPON_SPEAR
	return int(_settler_weapons[index])


func _settler_defense_for_index(index: int) -> float:
	var profile: Dictionary = _weapon_profile(_weapon_for_settler(index))
	return float(profile["defense"]) * _settler_defense_mult


func _rebalance_settler_weapons() -> void:
	var settlers: int = _agents.get_agent_count()
	if settlers <= 0:
		return
	if _settler_weapons.size() != settlers:
		_settler_weapons.resize(settlers)

	var hunters: Array[int] = []
	var others: Array[int] = []
	for i in settlers:
		if _job_for_settler(i) == JOB_HUNT:
			hunters.append(i)
		else:
			others.append(i)
		_settler_weapons[i] = WEAPON_SPEAR

	var armory: int = int(_buildings.get("armory", 0))
	var bow_target: int = 0
	var javelin_target: int = 0
	var shield_target: int = 0
	if _weapon_bow_unlocked:
		bow_target = mini(hunters.size(), maxi(0, int(round(float(hunters.size()) * (0.5 + 0.07 * armory)))))
	if _weapon_javelin_unlocked:
		javelin_target = mini(hunters.size() - bow_target, maxi(0, int(round(float(hunters.size()) * (0.35 + 0.04 * armory)))))
	if _weapon_shield_unlocked:
		shield_target = mini(others.size(), maxi(0, int(round(float(others.size()) * (0.22 + 0.03 * armory)))))

	for i in bow_target:
		_settler_weapons[hunters[i]] = WEAPON_BOW
	for i in javelin_target:
		_settler_weapons[hunters[bow_target + i]] = WEAPON_JAVELIN
	for i in shield_target:
		_settler_weapons[others[i]] = WEAPON_SHIELD


func _record_agent_action(index: int, message: String) -> void:
	if index < 0:
		return
	var prefix: String = "[Night] " if _is_night() else "[Day] "
	var line: String = prefix + message
	var actions: Array = _agent_recent_actions.get(index, [])
	if actions.size() > 0 and String(actions[0]) == line:
		return
	actions.push_front(line)
	while actions.size() > 6:
		actions.pop_back()
	_agent_recent_actions[index] = actions
	var agents: PackedVector2Array = _agents.get_agent_positions()
	var pos: Vector2 = agents[index] if index >= 0 and index < agents.size() else Vector2.ZERO
	_log_global_settler_event("action", index, _job_for_settler(index), String(_agent_last_state.get(index, "")), pos, line)


func _record_combat_action(index: int, message: String) -> void:
	if index < 0:
		return
	var now_msec: int = Time.get_ticks_msec()
	var last_msec: int = int(_settler_last_combat_log_msec.get(index, -999999))
	if now_msec - last_msec < maxi(100, combat_action_log_cooldown_msec):
		return
	_settler_last_combat_log_msec[index] = now_msec
	_record_agent_action(index, message)


func _bootstrap_10k_stress_test() -> void:
	if not run_10k_settler_stress_test:
		return
	var target_count: int = maxi(1000, stress_test_settler_target)
	var current_count: int = _agents.get_agent_count()
	if current_count >= target_count:
		return
	if _agents.infinite_mode:
		_agents.add_agents(target_count - current_count, _target)
		_recompute_homes()
		_sync_agent_tracking()
		_record_agent_action(0, "Stress test enabled: scaled settlers to %d" % target_count)
	else:
		push_warning("10k stress test requires AgentSystem.infinite_mode=true or a preconfigured agent_count >= target")


func _init_global_settler_log() -> void:
	_global_settler_log_active = enable_global_settler_log
	if not _global_settler_log_active:
		return
	var f: FileAccess = FileAccess.open(global_settler_log_path, FileAccess.WRITE)
	if f == null:
		_global_settler_log_active = false
		push_warning("Failed to open global settler log file at %s" % global_settler_log_path)
		return
	var now: String = Time.get_datetime_string_from_system()
	f.store_line("session_start,%s" % now)
	f.store_line("msec,frame,event,settler,job_id,job_name,state,target_x,target_y,message")
	f.close()


func _update_global_settler_log(delta: float) -> void:
	if not _global_settler_log_active:
		return
	_global_settler_log_flush_accum += delta
	_global_settler_snapshot_accum += delta
	if _global_settler_snapshot_accum >= global_settler_snapshot_sec:
		_global_settler_snapshot_accum = 0.0
		_log_global_snapshot()
	if _global_settler_log_flush_accum >= global_settler_log_flush_sec:
		_global_settler_log_flush_accum = 0.0
		_flush_global_settler_log()


func _log_global_snapshot() -> void:
	var targets: PackedVector2Array = _agents.get_agent_targets()
	var count: int = _agents.get_agent_count()
	for i in count:
		var target: Vector2 = targets[i] if i < targets.size() else Vector2.ZERO
		_log_global_settler_event("snapshot", i, _job_for_settler(i), String(_agent_last_state.get(i, "")), target, "")


func _log_global_settler_event(event_name: String, settler_idx: int, job_id: int, state_tag: String, target: Vector2, message: String) -> void:
	if not _global_settler_log_active:
		return
	if _global_settler_log_lines.size() >= global_settler_log_max_buffered_lines:
		_global_settler_log_drop_count += 1
		return
	var clean_state: String = state_tag.replace(",", ";")
	var clean_msg: String = message.replace(",", ";")
	var row: String = "%d,%d,%s,%d,%d,%s,%s,%.2f,%.2f,%s" % [
		Time.get_ticks_msec(),
		Engine.get_process_frames(),
		event_name,
		settler_idx,
		job_id,
		_job_name_from_id(job_id),
		clean_state,
		target.x,
		target.y,
		clean_msg,
	]
	_global_settler_log_lines.append(row)


func _flush_global_settler_log() -> void:
	if not _global_settler_log_active:
		return
	if _global_settler_log_lines.is_empty() and _global_settler_log_drop_count <= 0:
		return
	var f: FileAccess = FileAccess.open(global_settler_log_path, FileAccess.READ_WRITE)
	if f == null:
		push_warning("Unable to flush global settler log")
		return
	f.seek_end()
	for line in _global_settler_log_lines:
		f.store_line(line)
	if _global_settler_log_drop_count > 0:
		f.store_line("%d,%d,drop,-1,-1,NA,NA,0.00,0.00,dropped_%d_buffered_rows" % [Time.get_ticks_msec(), Engine.get_process_frames(), _global_settler_log_drop_count])
		_global_settler_log_drop_count = 0
	f.close()
	_global_settler_log_lines.clear()


func _job_name_from_id(job_id: int) -> String:
	match job_id:
		JOB_FARM:
			return "farmer"
		JOB_LUMBER:
			return "lumber"
		JOB_STONE:
			return "stone"
		JOB_HUNT:
			return "hunt"
		JOB_SCOUT:
			return "scout"
		_:
			return "unknown"


func _action_icon(action: String) -> String:
	var lower := action.to_lower()
	if "food" in lower or "farm" in lower or "harvest" in lower:
		return "[color=#ffdd55]▶[/color] "
	elif "lumber" in lower or "tree" in lower or "wood" in lower:
		return "[color=#55cc55]▶[/color] "
	elif "stone" in lower or "mine" in lower or "metal" in lower or "ore" in lower:
		return "[color=#aaaaaa]▶[/color] "
	elif "home" in lower or "return" in lower or "sleep" in lower:
		return "[color=#5599ff]▶[/color] "
	elif "recruit" in lower:
		return "[color=#55eeff]▶[/color] "
	elif "assign" in lower:
		return "[color=#cc88ff]▶[/color] "
	else:
		return "[color=#cccccc]▶[/color] "


func _recent_actions_text(index: int) -> String:
	var actions: Array = _agent_recent_actions.get(index, [])
	if actions.is_empty():
		return "  [color=#888888]No recent events[/color]"
	var lines: Array[String] = []
	for item in actions:
		var s := String(item)
		lines.append(_action_icon(s) + s)
	return "\n".join(lines)


func _update_hover_ui() -> void:
	if _hover_panel == null:
		return
	var inspected_idx: int = _inspected_agent_idx()
	if inspected_idx < 0:
		# Check if mouse is hovering over a house tile
		var mouse_world: Vector2 = get_global_mouse_position()
		var mouse_tile := _world_to_tile(mouse_world)
		var house_idx: int = _house_tiles.find(mouse_tile)
		if house_idx >= 0:
			_show_home_hover(house_idx, false)
			return
		var manor_idx: int = _manor_index_at(mouse_tile)
		if manor_idx >= 0:
			_show_home_hover(int(_buildings["house"]) + manor_idx, true)
			return
		_hover_panel.visible = false
		return

	var agents: PackedVector2Array = _agents.get_agent_positions()
	var targets: PackedVector2Array = _agents.get_agent_targets()
	if inspected_idx >= agents.size():
		_hover_panel.visible = false
		return

	var i: int = inspected_idx
	var pos: Vector2 = agents[i]
	var tile := _world_to_tile(pos)
	var target: Vector2 = targets[i] if i < targets.size() else _target
	var target_tile := _world_to_tile(target)
	var job: int = _job_for_settler(i)
	var home: Vector2 = _home_center_for_settler(i)
	var home_tile := _world_to_tile(home)
	var vel: Vector2 = Vector2.ZERO
	if i < _agents.velocities.size():
		vel = _agents.velocities[i]
	var happiness: float = _settler_happiness[i] if i < _settler_happiness.size() else 0.5
	var birth_chance: float = (happiness * 0.5) if _has_housemate(i) else 0.0

	var state: String = "Returning Home" if _is_night() else "Working"
	var job_name: String = "Farmer"
	if job == JOB_LUMBER:
		job_name = "Lumberjack"
	elif job == JOB_STONE:
		job_name = "Stone Miner"
	elif job == JOB_HUNT:
		job_name = "Hunter"
	elif job == JOB_SCOUT:
		job_name = "Scout"
	if job == JOB_HUNT:
		var hunter_state: String = String(_hunter_runtime_state.get(i, ""))
		if not hunter_state.is_empty():
			state = "Hunter %s" % hunter_state.capitalize()
	var weapon_name: String = _weapon_name_for_id(_weapon_for_settler(i))
	var tool_name: String = _tool_name_for_id(_tool_for_settler(i))
	var tool_effect: String = _tool_effect_text(i, job)
	var tool_expected: String = _tool_expected_benefit_text(i, job)
	var tool_mode: String = _tool_mode_name_for_settler(i)

	var pinned_tag: String = " (Pinned)" if i == _pinned_agent_idx else ""
	var raw_name: String = _settler_names[i] if i < _settler_names.size() else ""
	var settler_name: String = _sanitize_settler_name(raw_name, i)
	_hover_title_label.text = "%s%s" % [settler_name, pinned_tag]
	_hover_body_label.text = (
		"State: %s\n"
		+ "Job: %s\n"
		+ "Weapon: %s\n"
		+ "Tool: %s (%s)\n"
		+ "Expected Benefit: %s\n"
		+ "Tool Mode: %s\n"
		+ "Badges: %s\n"
		+ "Happiness: %d%%  |  Dawn birth chance: %d%%\n"
		+ "Position: (%.1f, %.1f)  Tile (%d, %d)\n"
		+ "Home Tile: (%d, %d)\n"
		+ "Target Tile: (%d, %d)\n"
		+ "Distance to Target: %.1f\n"
		+ "Speed: %.1f / %.1f\n"
		+ "Vision Radius: %d\n"
		+ "Yield Mult: Tree x%.2f  Stone x%.2f\n\n"
		+ "Recent Actions:\n%s"
	) % [
		state,
		job_name,
		weapon_name,
		tool_name,
		tool_effect,
		tool_expected,
		tool_mode,
		_colonist_upgrade_badges_text(),
		int(round(happiness * 100.0)),
		int(round(birth_chance * 100.0)),
		pos.x,
		pos.y,
		tile.x,
		tile.y,
		home_tile.x,
		home_tile.y,
		target_tile.x,
		target_tile.y,
		pos.distance_to(target),
		vel.length(),
		_agents.tiles_per_second * TILE_SIZE,
		_vision_radius,
		_tree_yield_mult,
		_stone_yield_mult,
		_recent_actions_text(i),
	]

	_job_btn_row.visible = (i == _pinned_agent_idx)
	_tool_btn_row.visible = (i == _pinned_agent_idx)
	if _tool_mode_btn != null and is_instance_valid(_tool_mode_btn):
		_tool_mode_btn.visible = (i == _pinned_agent_idx)
		_tool_mode_btn.text = "Tool Mode: %s" % tool_mode
	_hover_panel.visible = true


func _colonist_upgrade_badges_text() -> String:
	var badges: Array[String] = []
	for id_v in _upgrade_ranks.keys():
		var id: String = String(id_v)
		var rank: int = int(_upgrade_ranks[id])
		if rank <= 0:
			continue
		if not _upgrade_affects_colonist_ui(id):
			continue
		badges.append("%s-R%d" % [_upgrade_badge_code(id), rank])
	if badges.is_empty():
		return "None"
	badges.sort()
	return " ".join(badges)


func _upgrade_affects_colonist_ui(id: String) -> bool:
	if id.begins_with("def") or id.begins_with("cmb"):
		return true
	if id in ["eff_speed", "eff_ration", "eff_campfire", "spec_hunting", "spec_bravado"]:
		return true
	if id.begins_with("scout") or id.begins_with("vision"):
		return true
	return false


func _upgrade_badge_code(id: String) -> String:
	match id:
		"eff_speed":
			return "SPD"
		"eff_ration":
			return "RAT"
		"eff_campfire":
			return "FIRE"
		"spec_hunting":
			return "HUNT"
		"spec_bravado":
			return "BRV"
		"vision_lenses":
			return "EYE"
		"vision_tower_net":
			return "NET"
		"vision_tower_range":
			return "TWR"
		"vision_nightwatch":
			return "MOON"
		"scout_training":
			return "PATH"
		"scout_survey":
			return "MAP"
		"scout_beacons":
			return "BCN"
		"scout_salvage":
			return "SALV"
		"def_spears":
			return "SPR"
		"def_horns":
			return "HRN"
		"def_training":
			return "SHLD"
		"cmb_armory":
			return "ARM"
		"cmb_shields":
			return "W-S"
		"cmb_bowcraft":
			return "W-B"
		"cmb_javelin":
			return "W-J"
		"cmb_steel":
			return "STL"
		"cmb_drills":
			return "DRL"
		_:
			return id.to_upper().substr(0, min(4, id.length()))


func _show_home_hover(home_slot: int, is_manor: bool) -> void:
	var residents: Array[String] = []
	for i in _settler_homes.size():
		if int(_settler_homes[i]) == home_slot:
			var raw_name: String = _settler_names[i] if i < _settler_names.size() else ""
			var name_str: String = _sanitize_settler_name(raw_name, i)
			residents.append(name_str)

	if is_manor:
		var manor_idx: int = home_slot - int(_buildings["house"])
		_hover_title_label.text = "Manor %d" % (manor_idx + 1)
	else:
		_hover_title_label.text = "House %d" % (home_slot + 1)
	if residents.is_empty():
		_hover_body_label.text = "[color=#aaaaaa]Unoccupied[/color]"
	else:
		var lines: Array[String] = []
		for r in residents:
			lines.append("• %s" % r)
		_hover_body_label.text = "\n".join(lines)

	_job_btn_row.visible = false
	_tool_btn_row.visible = false
	if _tool_mode_btn != null and is_instance_valid(_tool_mode_btn):
		_tool_mode_btn.visible = false
	_hover_panel.visible = true


func _draw_hover_feedback() -> void:
	var inspected_idx: int = _inspected_agent_idx()
	if inspected_idx < 0:
		return
	var agents: PackedVector2Array = _agents.get_agent_positions()
	var targets: PackedVector2Array = _agents.get_agent_targets()
	if inspected_idx >= agents.size():
		return

	var pos: Vector2 = agents[inspected_idx]
	var target: Vector2 = targets[inspected_idx] if inspected_idx < targets.size() else _target
	var col: Color = Color(1.0, 0.85, 0.35, 0.95) if inspected_idx == _pinned_agent_idx else Color(0.62, 0.95, 1.0, 0.95)
	draw_arc(pos, 9.0, 0.0, TAU, 28, col, 1.8)
	draw_circle(pos, 2.0, Color(col.r, col.g, col.b, 0.9))
	draw_line(pos, target, Color(col.r, col.g, col.b, 0.45), 1.0)


func _build_upgrade_ui() -> void:
	var ui_layer: CanvasLayer = $UI

	_upgrade_toggle = Button.new()
	_upgrade_toggle.text = "Upgrades"
	_upgrade_toggle.size = Vector2(120.0, 38.0)
	_upgrade_toggle.position = Vector2(get_viewport_rect().size.x - 136.0, 10.0)
	_upgrade_toggle.pressed.connect(_toggle_upgrade_panel)
	ui_layer.add_child(_upgrade_toggle)

	_upgrade_panel = PanelContainer.new()
	_upgrade_panel.size = Vector2(_drawer_width, get_viewport_rect().size.y - 80.0)
	_upgrade_panel.position = Vector2(get_viewport_rect().size.x + 12.0, 48.0)
	ui_layer.add_child(_upgrade_panel)

	var bg_style := StyleBoxFlat.new()
	bg_style.bg_color = UI_BG
	bg_style.corner_radius_top_left = 2
	bg_style.corner_radius_bottom_left = 2
	bg_style.border_width_left = 2
	bg_style.border_width_top = 2
	bg_style.border_width_bottom = 2
	bg_style.border_color = UI_BORDER
	_upgrade_panel.add_theme_stylebox_override("panel", bg_style)

	var root_margin := MarginContainer.new()
	root_margin.add_theme_constant_override("margin_left", 14)
	root_margin.add_theme_constant_override("margin_right", 14)
	root_margin.add_theme_constant_override("margin_top", 12)
	root_margin.add_theme_constant_override("margin_bottom", 12)
	_upgrade_panel.add_child(root_margin)

	var root_col := VBoxContainer.new()
	root_col.add_theme_constant_override("separation", 10)
	root_col.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root_margin.add_child(root_col)

	# ── Header ────────────────────────────────────────────────────────────────
	var title := Label.new()
	title.text = "Village Growth"
	title.add_theme_font_size_override("font_size", 22)
	root_col.add_child(title)

	# ── Body: sidebar + content ───────────────────────────────────────────────
	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 10)
	root_col.add_child(body)

	# Left sidebar: scrollable category buttons
	var sidebar_scroll := ScrollContainer.new()
	sidebar_scroll.custom_minimum_size = Vector2(220.0, 0.0)
	sidebar_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sidebar_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(sidebar_scroll)

	var sidebar_col := VBoxContainer.new()
	sidebar_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sidebar_col.add_theme_constant_override("separation", 6)
	sidebar_scroll.add_child(sidebar_col)

	# Divider
	var sep := VSeparator.new()
	sep.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(sep)

	# Right side: scrollable content
	_upgrade_content_scroll = ScrollContainer.new()
	_upgrade_content_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_upgrade_content_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_upgrade_content_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(_upgrade_content_scroll)

	_upgrade_content_col = VBoxContainer.new()
	_upgrade_content_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_upgrade_content_col.add_theme_constant_override("separation", 8)
	_upgrade_content_scroll.add_child(_upgrade_content_col)

	# Build category buttons
	var categories: Array = ["Volume", "Efficiency", "Specialization", "Vision & Exploration", "Scouting", "Defense", "Combat", "Buildings", "Population", "Jobs", "Debug"]
	for cat in categories:
		var btn := Button.new()
		btn.text = cat
		btn.toggle_mode = true
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.custom_minimum_size = Vector2(0.0, 34.0)
		btn.add_theme_font_size_override("font_size", 14)
		btn.pressed.connect(Callable(self, "_on_upgrade_category_selected").bind(cat))
		sidebar_col.add_child(btn)
		_upgrade_category_btns[cat] = btn

	# Select first category
	_on_upgrade_category_selected("Volume")

	get_viewport().size_changed.connect(_on_viewport_resized)


func _on_upgrade_category_selected(cat: String) -> void:
	if _active_category == cat:
		return
	_active_category = cat

	# Update sidebar button pressed states
	for c in _upgrade_category_btns.keys():
		var b: Button = _upgrade_category_btns[c]
		b.button_pressed = (c == cat)

	# Clear and repopulate content column
	for child in _upgrade_content_col.get_children():
		child.queue_free()

	var heading := Label.new()
	heading.text = cat
	heading.add_theme_font_size_override("font_size", 18)
	heading.modulate = UI_TEXT_ACCENT
	_upgrade_content_col.add_child(heading)

	match cat:
		"Volume", "Efficiency", "Specialization", "Vision & Exploration", "Scouting", "Defense", "Combat":
			for item in UPGRADE_DATA[cat]:
				_upgrade_content_col.add_child(_make_upgrade_row(item))
		"Buildings":
			for b_name in BUILDING_RECIPES.keys():
				_upgrade_content_col.add_child(_make_building_row(b_name, BUILDING_RECIPES[b_name]))
		"Population":
			_build_population_tab(_upgrade_content_col)
		"Jobs":
			_build_jobs_tab(_upgrade_content_col)
		"Debug":
			_build_debug_tab(_upgrade_content_col)

	# Scroll back to top
	_upgrade_content_scroll.scroll_vertical = 0


func _build_population_tab(page: VBoxContainer) -> void:
	page.add_child(_make_population_action_row("recruit", POP_ACTIONS["recruit"]))
	page.add_child(_make_population_action_row("house", POP_ACTIONS["house"]))


func _build_jobs_tab(page: VBoxContainer) -> void:
	var jobs_title := Label.new()
	jobs_title.text = "Worker Allocation"
	jobs_title.add_theme_font_size_override("font_size", 15)
	page.add_child(jobs_title)

	var hint := Label.new()
	hint.text = "If no free colonist is available, + will pull one from another job evenly. Tools: lock manually per settler, or use Equip By Role / Clear Locks / Rebalance Tools in the bottom bar."
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.modulate = Color(0.86, 0.9, 0.98, 0.9)
	hint.add_theme_font_size_override("font_size", 11)
	page.add_child(hint)

	var scouting_gate := Label.new()
	scouting_gate.text = "Scouting scales fluidly with support structures (Scout Lodge, Sawmill, Quarry, Refinery, Storehouse, Armory)."
	scouting_gate.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	scouting_gate.modulate = Color(0.62, 0.86, 1.0, 0.95)
	scouting_gate.add_theme_font_size_override("font_size", 11)
	page.add_child(scouting_gate)

	page.add_child(_make_job_row("farm", "Farmers"))
	page.add_child(_make_job_row("lumber", "Lumberjacks"))
	page.add_child(_make_job_row("stone", "Stone Miners"))
	page.add_child(_make_job_row("hunt", "Hunters"))
	page.add_child(_make_job_row("scout", "Scouts (requires Scout Lodge)"))

	_update_job_labels()


func _build_debug_tab(page: VBoxContainer) -> void:
	var title := Label.new()
	title.text = "Performance Debug"
	title.add_theme_font_size_override("font_size", 15)
	page.add_child(title)

	var hint := Label.new()
	hint.text = "Tracks expensive systems per frame with avg/max timing. Use toggle to hide the on-screen debug panel."
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.modulate = Color(0.86, 0.9, 0.98, 0.9)
	hint.add_theme_font_size_override("font_size", 11)
	page.add_child(hint)

	_debug_panel_toggle_btn = Button.new()
	_debug_panel_toggle_btn.custom_minimum_size = Vector2(180.0, 34.0)
	_debug_panel_toggle_btn.pressed.connect(_on_toggle_debug_panel_pressed)
	page.add_child(_debug_panel_toggle_btn)
	_sync_debug_panel_toggle_button()

	var clear_btn := Button.new()
	clear_btn.text = "Reset Timing History"
	clear_btn.custom_minimum_size = Vector2(180.0, 30.0)
	clear_btn.pressed.connect(_reset_perf_stats)
	page.add_child(clear_btn)


func _make_population_action_row(action_id: String, data: Dictionary) -> Control:
	var panel := _styled_row_panel(Color(0.14, 0.19, 0.25, 0.95))
	var margin: MarginContainer = panel.get_child(0)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	margin.add_child(row)

	var text_col := VBoxContainer.new()
	text_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(text_col)

	var n := Label.new()
	n.text = String(data["name"])
	n.add_theme_font_size_override("font_size", 16)
	text_col.add_child(n)

	var e := Label.new()
	e.text = String(data["effect"])
	e.modulate = Color(0.86, 0.93, 0.78, 1.0)
	e.add_theme_font_size_override("font_size", 12)
	text_col.add_child(e)

	var c := Label.new()
	c.text = _cost_to_string(data["cost"])
	c.modulate = Color(0.82, 0.84, 0.9, 0.95)
	c.add_theme_font_size_override("font_size", 11)
	text_col.add_child(c)

	if action_id == "house":
		var note := Label.new()
		note.text = "Placed near your last click target. Left-click the map first to choose a location."
		note.modulate = Color(0.95, 0.85, 0.45, 0.9)
		note.add_theme_font_size_override("font_size", 11)
		note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		text_col.add_child(note)

	var btn := Button.new()
	btn.text = "Do"
	btn.custom_minimum_size = Vector2(100.0, 34.0)
	btn.pressed.connect(_on_population_action_pressed.bind(action_id, data["cost"], panel))
	row.add_child(btn)

	return panel


func _make_job_row(job_key: String, label_text: String) -> Control:
	var panel := _styled_row_panel(Color(0.11, 0.14, 0.2, 0.92))
	var margin: MarginContainer = panel.get_child(0)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	margin.add_child(row)

	var lbl := Label.new()
	lbl.text = label_text
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl.add_theme_font_size_override("font_size", 14)
	row.add_child(lbl)

	var dec := Button.new()
	dec.text = "-"
	dec.custom_minimum_size = Vector2(30.0, 30.0)
	dec.pressed.connect(_change_job_count.bind(job_key, -1))
	row.add_child(dec)

	var count_lbl := Label.new()
	count_lbl.text = "0"
	count_lbl.custom_minimum_size = Vector2(26.0, 0.0)
	count_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	row.add_child(count_lbl)
	_job_count_labels[job_key] = count_lbl

	var inc := Button.new()
	inc.text = "+"
	inc.custom_minimum_size = Vector2(30.0, 30.0)
	inc.pressed.connect(_change_job_count.bind(job_key, 1))
	row.add_child(inc)

	return panel


func _make_upgrade_row(item: Dictionary) -> Control:
	var id: String = String(item["id"])
	var name: String = String(item["name"])
	var effect: String = String(item["effect"])

	var panel := _styled_row_panel(Color(0.12, 0.16, 0.22, 0.92))
	var margin: MarginContainer = panel.get_child(0)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	margin.add_child(row)

	var text_col := VBoxContainer.new()
	text_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(text_col)

	var n := Label.new()
	n.text = name
	n.add_theme_font_size_override("font_size", 16)
	text_col.add_child(n)

	var e := Label.new()
	e.text = effect
	e.modulate = Color(0.75, 0.92, 0.78, 1.0)
	e.add_theme_font_size_override("font_size", 12)
	text_col.add_child(e)

	var rank_lbl := Label.new()
	rank_lbl.text = _upgrade_rank_text(item)
	rank_lbl.modulate = Color(0.95, 0.86, 0.58, 1.0)
	rank_lbl.add_theme_font_size_override("font_size", 11)
	text_col.add_child(rank_lbl)

	var c := Label.new()
	c.text = _cost_to_string(_upgrade_cost_for_rank(item, int(_upgrade_ranks.get(id, 0))))
	c.modulate = Color(0.82, 0.84, 0.9, 0.95)
	c.add_theme_font_size_override("font_size", 11)
	text_col.add_child(c)

	var buy := Button.new()
	buy.text = "Upgrade"
	buy.custom_minimum_size = Vector2(110.0, 34.0)
	buy.pressed.connect(_on_upgrade_pressed.bind(item, buy, rank_lbl, c, panel))
	row.add_child(buy)

	var rank: int = int(_upgrade_ranks.get(id, 0))
	var max_rank: int = _upgrade_max_rank(item)
	if rank >= max_rank:
		buy.disabled = true
		buy.text = "Maxed"

	return panel


func _upgrade_cost_for_rank(item: Dictionary, rank: int) -> Dictionary:
	var base: Dictionary = item["cost"]
	var max_rank: int = _upgrade_max_rank(item)
	var scale: float = _upgrade_exp_scale(max_rank)
	var out: Dictionary = {}
	for key in base.keys():
		out[key] = ceil(float(base[key]) * pow(scale, rank))
	return out


func _upgrade_max_rank(item: Dictionary) -> int:
	var id: String = String(item.get("id", ""))
	if id in ["vision_tower_net", "cmb_shields"]:
		return 1
	if int(item.get("max_rank", 1)) <= 1:
		return 1
	return 10


func _upgrade_exp_scale(max_rank: int) -> float:
	if max_rank <= 1:
		return 1.0
	# Exponential growth that reaches 10x cost by final rank.
	return pow(10.0, 1.0 / float(max_rank - 1))


func _upgrade_rank_text(item: Dictionary) -> String:
	var id: String = String(item["id"])
	var rank: int = int(_upgrade_ranks.get(id, 0))
	var max_rank: int = _upgrade_max_rank(item)
	return "Rank %d / %d" % [rank, max_rank]


func _make_building_row(display_name: String, recipe: Dictionary) -> Control:
	var id: String = String(recipe["id"])
	var cost: Dictionary = recipe["cost"]

	var panel := _styled_row_panel(Color(0.14, 0.18, 0.2, 0.94))
	var margin: MarginContainer = panel.get_child(0)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	margin.add_child(row)

	var text_col := VBoxContainer.new()
	text_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(text_col)

	var n := Label.new()
	n.text = display_name
	n.add_theme_font_size_override("font_size", 16)
	text_col.add_child(n)

	var e := Label.new()
	e.text = _building_effect_text(id)
	e.modulate = Color(0.75, 0.92, 0.78, 1.0)
	e.add_theme_font_size_override("font_size", 12)
	text_col.add_child(e)

	var c := Label.new()
	c.text = _cost_to_string(cost)
	c.modulate = Color(0.82, 0.84, 0.9, 0.95)
	c.add_theme_font_size_override("font_size", 11)
	text_col.add_child(c)

	var built := Label.new()
	built.text = "Built: 0"
	built.modulate = Color(0.95, 0.87, 0.6, 1.0)
	built.add_theme_font_size_override("font_size", 12)
	text_col.add_child(built)
	_building_labels[id] = built

	if id in ["house", "manor"]:
		var note := Label.new()
		note.text = "Placed near your last click target. Left-click the map first to choose a location."
		note.modulate = Color(0.95, 0.85, 0.45, 0.9)
		note.add_theme_font_size_override("font_size", 11)
		note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		text_col.add_child(note)

	var build := Button.new()
	build.text = "Build"
	build.custom_minimum_size = Vector2(110.0, 34.0)
	build.pressed.connect(_on_building_pressed.bind(id, cost, panel))
	row.add_child(build)

	return panel


func _styled_row_panel(bg_color: Color) -> PanelContainer:
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = bg_color.lerp(UI_BG_ALT, 0.35)
	style.corner_radius_top_left = 2
	style.corner_radius_top_right = 2
	style.corner_radius_bottom_left = 2
	style.corner_radius_bottom_right = 2
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.border_color = UI_BORDER
	panel.add_theme_stylebox_override("panel", style)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_top", 9)
	margin.add_theme_constant_override("margin_bottom", 9)
	panel.add_child(margin)
	return panel


func _toggle_upgrade_panel() -> void:
	_panel_open = not _panel_open
	if _upgrade_panel == null:
		return
	var vp := get_viewport_rect().size
	var target_x := vp.x - _drawer_width if _panel_open else vp.x + 12.0
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(_upgrade_panel, "position:x", target_x, 0.22)
	_upgrade_toggle.text = "Hide" if _panel_open else "Upgrades"


func _build_performance_debug_ui() -> void:
	var ui_layer: CanvasLayer = $UI
	_perf_panel = PanelContainer.new()
	_perf_panel.size = Vector2(430.0, 270.0)
	_perf_panel.visible = show_performance_debug_panel
	ui_layer.add_child(_perf_panel)

	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.05, 0.08, 0.12, 0.92)
	panel_style.border_width_left = 1
	panel_style.border_width_top = 1
	panel_style.border_width_right = 1
	panel_style.border_width_bottom = 1
	panel_style.border_color = Color(0.32, 0.56, 0.7, 0.95)
	panel_style.corner_radius_top_left = 2
	panel_style.corner_radius_top_right = 2
	panel_style.corner_radius_bottom_left = 2
	panel_style.corner_radius_bottom_right = 2
	_perf_panel.add_theme_stylebox_override("panel", panel_style)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	_perf_panel.add_child(margin)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	margin.add_child(col)

	var title := Label.new()
	title.text = "Performance Breakdown"
	title.add_theme_font_size_override("font_size", 15)
	col.add_child(title)

	_perf_label = RichTextLabel.new()
	_perf_label.bbcode_enabled = true
	_perf_label.scroll_active = true
	_perf_label.fit_content = false
	_perf_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_perf_label.add_theme_font_size_override("normal_font_size", 12)
	col.add_child(_perf_label)

	_position_performance_panel()
	_sync_debug_panel_toggle_button()
	_refresh_perf_panel_text()


func _on_toggle_debug_panel_pressed() -> void:
	show_performance_debug_panel = not show_performance_debug_panel
	if _perf_panel != null:
		_perf_panel.visible = show_performance_debug_panel
	_sync_debug_panel_toggle_button()


func _sync_debug_panel_toggle_button() -> void:
	if _debug_panel_toggle_btn != null and is_instance_valid(_debug_panel_toggle_btn):
		_debug_panel_toggle_btn.text = "Hide Debug Panel" if show_performance_debug_panel else "Show Debug Panel"


func _reset_perf_stats() -> void:
	_perf_stats.clear()
	_perf_frame_avg_ms = 0.0
	_perf_frame_max_ms = 0.0
	_perf_frame_samples = 0
	_refresh_perf_panel_text()


func _perf_record_step(step_name: String, start_us: int) -> void:
	var elapsed_ms: float = float(Time.get_ticks_usec() - start_us) * 0.001
	var stat: Dictionary = _perf_stats.get(step_name, {
		"avg_ms": 0.0,
		"max_ms": 0.0,
		"last_ms": 0.0,
		"samples": 0,
	})
	var samples: int = int(stat["samples"]) + 1
	var prev_avg: float = float(stat["avg_ms"])
	stat["avg_ms"] = prev_avg + (elapsed_ms - prev_avg) / float(samples)
	stat["last_ms"] = elapsed_ms
	stat["max_ms"] = maxf(float(stat["max_ms"]), elapsed_ms)
	stat["samples"] = samples
	_perf_stats[step_name] = stat


func _perf_end_frame(frame_start_us: int, delta: float) -> void:
	_perf_last_frame_ms = float(Time.get_ticks_usec() - frame_start_us) * 0.001
	_perf_frame_samples += 1
	_perf_frame_avg_ms += (_perf_last_frame_ms - _perf_frame_avg_ms) / float(_perf_frame_samples)
	_perf_frame_max_ms = maxf(_perf_frame_max_ms, _perf_last_frame_ms)
	_perf_refresh_accum += delta
	if _perf_refresh_accum >= performance_debug_refresh_sec:
		_perf_refresh_accum = 0.0
		_refresh_perf_panel_text()


func _refresh_perf_panel_text() -> void:
	if _perf_label == null or not is_instance_valid(_perf_label):
		return
	var lines: Array[String] = []
	var thinking_count: int = 0
	var executing_count: int = 0
	var blocked_count: int = 0
	for state in _settler_think_state:
		if int(state) == THINK_THINKING:
			thinking_count += 1
		elif int(state) == THINK_BLOCKED:
			blocked_count += 1
		else:
			executing_count += 1
	lines.append("[color=#a8d9ff]Settlers:[/color] %d    [color=#a8d9ff]FPS:[/color] %d" % [_agents.get_agent_count(), Engine.get_frames_per_second()])
	lines.append("[color=#a8d9ff]Frame ms[/color] last %.2f | avg %.2f | max %.2f" % [_perf_last_frame_ms, _perf_frame_avg_ms, _perf_frame_max_ms])
	lines.append("[color=#a8d9ff]Decisions/tick:[/color] %d" % _settler_decisions_this_tick)
	lines.append("[color=#a8d9ff]Pathfind budget:[/color] %d/%d%s" % [
		_pathfind_budget_effective,
		maxi(1, settler_decision_budget_per_tick),
		" (dawn/dusk)" if _is_dawn_dusk_window() else "",
	])
	lines.append("[color=#a8d9ff]States[/color] thinking %d | executing %d | blocked %d" % [thinking_count, executing_count, blocked_count])
	lines.append("[color=#8fb7cc]Top expensive systems (avg ms):[/color]")

	var rows: Array[Dictionary] = []
	for key_v in _perf_stats.keys():
		var key: String = String(key_v)
		var stat: Dictionary = _perf_stats[key]
		rows.append({
			"name": key,
			"avg": float(stat.get("avg_ms", 0.0)),
			"max": float(stat.get("max_ms", 0.0)),
			"last": float(stat.get("last_ms", 0.0)),
		})
	rows.sort_custom(Callable(self, "_sort_perf_rows_desc"))

	var shown: int = mini(14, rows.size())
	for i in shown:
		var row: Dictionary = rows[i]
		lines.append("• %s  [avg %.3f | max %.3f | last %.3f]" % [String(row["name"]), float(row["avg"]), float(row["max"]), float(row["last"])])

	_perf_label.text = "\n".join(lines)


func _sort_perf_rows_desc(a: Dictionary, b: Dictionary) -> bool:
	return float(a.get("avg", 0.0)) > float(b.get("avg", 0.0))


func _position_performance_panel() -> void:
	if _perf_panel == null:
		return
	var vp := get_viewport_rect().size
	var margin_x: float = 12.0
	var min_y: float = MINIMAP_TILES * _minimap_scale + 106.0
	var max_y: float = maxf(52.0, vp.y - _perf_panel.size.y - 10.0)
	_perf_panel.position = Vector2(margin_x, minf(min_y, max_y))


func _build_minimap_ui() -> void:
	var ui_layer: CanvasLayer = $UI
	_minimap_image = Image.create(MINIMAP_TILES, MINIMAP_TILES, false, Image.FORMAT_RGBA8)
	_minimap_texture = ImageTexture.create_from_image(_minimap_image)

	var panel := PanelContainer.new()
	panel.position = Vector2(12.0, 64.0)
	panel.size = Vector2(MINIMAP_TILES * _minimap_scale + 10.0, MINIMAP_TILES * _minimap_scale + 30.0)
	ui_layer.add_child(panel)

	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = UI_BG
	panel_style.corner_radius_top_left = 2
	panel_style.corner_radius_top_right = 2
	panel_style.corner_radius_bottom_left = 2
	panel_style.corner_radius_bottom_right = 2
	panel_style.border_width_left = 1
	panel_style.border_width_top = 1
	panel_style.border_width_right = 1
	panel_style.border_width_bottom = 1
	panel_style.border_color = UI_BORDER
	panel.add_theme_stylebox_override("panel", panel_style)

	var title := Label.new()
	title.text = "Minimap (1px = 1 tile)"
	title.position = Vector2(8.0, 4.0)
	title.add_theme_font_size_override("font_size", 12)
	panel.add_child(title)

	_minimap_rect = TextureRect.new()
	_minimap_rect.texture = _minimap_texture
	_minimap_rect.position = Vector2(5.0, 22.0)
	_minimap_rect.size = Vector2(MINIMAP_TILES * _minimap_scale, MINIMAP_TILES * _minimap_scale)
	_minimap_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	panel.add_child(_minimap_rect)

	_update_minimap()


func _update_minimap() -> void:
	if _minimap_image == null:
		return

	var center_tile := Vector2i.ZERO
	var agents: PackedVector2Array = _agents.get_agent_positions()
	if agents.size() > 0:
		center_tile = _world_to_tile(agents[0])
	else:
		center_tile = _world_to_tile(_target)

	var half: int = MINIMAP_TILES / 2
	for py in MINIMAP_TILES:
		for px in MINIMAP_TILES:
			var tile := Vector2i(center_tile.x + (px - half), center_tile.y + (py - half))
			var col := Color(0.02, 0.02, 0.03, 1.0)
			if _is_explored(tile):
				col = _biome_color(_biome_at(tile))
				var res_type: int = _resource_type_at(tile)
				var rl: float = _resource_left(tile, res_type)
				if rl > 0.0:
					match res_type:
						RES_TREE:        col = col.lerp(Color(0.14, 0.75, 0.22, 1.0), 0.45)
						RES_STONE:       col = col.lerp(Color(0.74, 0.8, 0.88, 1.0), 0.45)
						RES_METAL:       col = col.lerp(Color(0.34, 0.36, 0.4, 1.0), 0.58)
						RES_APPLE:       col = col.lerp(Color(0.22, 0.72, 0.18, 1.0), 0.5)
						RES_BERRY_BLUE:  col = col.lerp(Color(0.22, 0.44, 0.82, 1.0), 0.5)
						RES_BERRY_RASP:  col = col.lerp(Color(0.82, 0.2, 0.32, 1.0), 0.5)
						RES_BERRY_BLACK: col = col.lerp(Color(0.28, 0.12, 0.36, 1.0), 0.5)
			_minimap_image.set_pixel(px, py, col)

	for w in _watchtowers:
		var mx: int = w.x - center_tile.x + half
		var my: int = w.y - center_tile.y + half
		if mx >= 0 and mx < MINIMAP_TILES and my >= 0 and my < MINIMAP_TILES:
			_minimap_image.set_pixel(mx, my, Color(0.95, 0.87, 0.2, 1.0))

	var camp_mx: int = _camp_tile.x - center_tile.x + half
	var camp_my: int = _camp_tile.y - center_tile.y + half
	if camp_mx >= 0 and camp_mx < MINIMAP_TILES and camp_my >= 0 and camp_my < MINIMAP_TILES:
		_minimap_image.set_pixel(camp_mx, camp_my, Color(0.95, 0.73, 0.32, 1.0))
	for home in _house_tiles:
		var hx: int = home.x - center_tile.x + half
		var hy: int = home.y - center_tile.y + half
		if hx >= 0 and hx < MINIMAP_TILES and hy >= 0 and hy < MINIMAP_TILES:
			_minimap_image.set_pixel(hx, hy, Color(0.84, 0.62, 0.36, 1.0))
	for origin in _manor_origins:
		for dx in MANOR_FOOTPRINT:
			for dy in MANOR_FOOTPRINT:
				var mt: Vector2i = origin + Vector2i(dx, dy)
				var mx: int = mt.x - center_tile.x + half
				var my: int = mt.y - center_tile.y + half
				if mx >= 0 and mx < MINIMAP_TILES and my >= 0 and my < MINIMAP_TILES:
					_minimap_image.set_pixel(mx, my, Color(0.7, 0.5, 0.26, 1.0))
	for t in _sawmill_tiles:
		var sx: int = t.x - center_tile.x + half
		var sy: int = t.y - center_tile.y + half
		if sx >= 0 and sx < MINIMAP_TILES and sy >= 0 and sy < MINIMAP_TILES:
			_minimap_image.set_pixel(sx, sy, Color(0.72, 0.48, 0.22, 1.0))
	for t in _quarry_tiles:
		var qx: int = t.x - center_tile.x + half
		var qy: int = t.y - center_tile.y + half
		if qx >= 0 and qx < MINIMAP_TILES and qy >= 0 and qy < MINIMAP_TILES:
			_minimap_image.set_pixel(qx, qy, Color(0.52, 0.58, 0.65, 1.0))
	for t in _workshop_tiles:
		var wx: int = t.x - center_tile.x + half
		var wy: int = t.y - center_tile.y + half
		if wx >= 0 and wx < MINIMAP_TILES and wy >= 0 and wy < MINIMAP_TILES:
			_minimap_image.set_pixel(wx, wy, Color(0.78, 0.52, 0.28, 1.0))
	for t in _storehouse_tiles:
		var stx: int = t.x - center_tile.x + half
		var sty: int = t.y - center_tile.y + half
		if stx >= 0 and stx < MINIMAP_TILES and sty >= 0 and sty < MINIMAP_TILES:
			_minimap_image.set_pixel(stx, sty, Color(0.85, 0.76, 0.48, 1.0))
	for t in _armory_tiles:
		var arx: int = t.x - center_tile.x + half
		var ary: int = t.y - center_tile.y + half
		if arx >= 0 and arx < MINIMAP_TILES and ary >= 0 and ary < MINIMAP_TILES:
			_minimap_image.set_pixel(arx, ary, Color(0.64, 0.37, 0.34, 1.0))
	for t in _scout_lodge_tiles:
		var slx: int = t.x - center_tile.x + half
		var sly: int = t.y - center_tile.y + half
		if slx >= 0 and slx < MINIMAP_TILES and sly >= 0 and sly < MINIMAP_TILES:
			_minimap_image.set_pixel(slx, sly, Color(0.45, 0.78, 0.96, 1.0))
	for t in _outpost_tiles:
		var ox: int = t.x - center_tile.x + half
		var oy: int = t.y - center_tile.y + half
		if ox >= 0 and ox < MINIMAP_TILES and oy >= 0 and oy < MINIMAP_TILES:
			_minimap_image.set_pixel(ox, oy, Color(0.38, 0.72, 0.92, 1.0))
	for poi in _poi_sites:
		if bool(poi.get("resolved", false)):
			continue
		var pt: Vector2i = poi["tile"]
		var px: int = pt.x - center_tile.x + half
		var py: int = pt.y - center_tile.y + half
		if px >= 0 and px < MINIMAP_TILES and py >= 0 and py < MINIMAP_TILES:
			var pcol: Color = Color(0.4, 1.0, 0.86, 1.0)
			if bool(poi.get("discovered", false)):
				pcol = Color(0.95, 0.95, 0.42, 1.0)
			_minimap_image.set_pixel(px, py, pcol)

	var target_tile := _world_to_tile(_target)
	var tx: int = target_tile.x - center_tile.x + half
	var ty: int = target_tile.y - center_tile.y + half
	if tx >= 0 and tx < MINIMAP_TILES and ty >= 0 and ty < MINIMAP_TILES:
		_minimap_image.set_pixel(tx, ty, Color(1.0, 0.2, 0.2, 1.0))

	for p in agents:
		var at := _world_to_tile(p)
		var ax: int = at.x - center_tile.x + half
		var ay: int = at.y - center_tile.y + half
		if ax >= 0 and ax < MINIMAP_TILES and ay >= 0 and ay < MINIMAP_TILES:
			_minimap_image.set_pixel(ax, ay, Color(0.35, 0.9, 1.0, 1.0))

	_minimap_texture.update(_minimap_image)


func _is_night() -> bool:
	return _day_time >= 0.78 or _day_time < 0.2


func _time_wrap_distance(a: float, b: float) -> float:
	var d: float = absf(a - b)
	return minf(d, 1.0 - d)


func _is_dawn_dusk_window() -> bool:
	var window: float = clampf(dawn_dusk_window_day_fraction, 0.001, 0.2)
	return _time_wrap_distance(_day_time, 0.2) <= window or _time_wrap_distance(_day_time, 0.78) <= window


func _effective_pathfind_budget(base_budget: int, min_budget: int = 1) -> int:
	var base: int = maxi(1, base_budget)
	var min_floor: int = maxi(1, min_budget)
	var fps: int = Engine.get_frames_per_second()
	var target_fps: int = maxi(1, pathfinding_target_fps)
	var fps_ratio: float = clampf(float(fps) / float(target_fps), pathfinding_min_budget_ratio, 1.0)
	var transition_ratio: float = dawn_dusk_budget_ratio if _is_dawn_dusk_window() else 1.0
	var ratio: float = minf(fps_ratio, transition_ratio)
	var budget: int = int(floor(float(base) * ratio))
	return clampi(budget, min_floor, base)


func _process_morning_dispatch_queue() -> void:
	if not _morning_dispatch_active or _morning_dispatch_cursor < 0:
		return
	if morning_dispatch_spread_sec <= 0.0:
		_morning_dispatch_active = false
		_morning_dispatch_cursor = -1
		return
	var count: int = _agents.get_agent_count()
	if count <= 0 or _morning_dispatch_cursor >= count:
		_morning_dispatch_active = false
		_morning_dispatch_cursor = -1
		return
	_sync_settler_think_buffers(count)
	var agents: PackedVector2Array = _agents.get_agent_positions()
	var now_sec: float = Time.get_ticks_msec() * 0.001
	var effective_budget: int = _effective_pathfind_budget(morning_dispatch_pathfind_budget_per_frame, 1)
	var remaining: int = count - _morning_dispatch_cursor
	var dispatch_budget: int = mini(effective_budget, remaining)
	for step in dispatch_budget:
		var i: int = _morning_dispatch_cursor + step
		if i < agents.size():
			var from_tile: Vector2i = _world_to_tile(agents[i])
			var job: int = _job_for_settler(i)
			_update_day_plan_for_settler(i, from_tile, job)
			if _settler_day_plan_targets.has(i) and _settler_day_plan_job.has(i) and int(_settler_day_plan_job[i]) == job:
				var plan_tile: Vector2i = _settler_day_plan_targets[i]
				var step_tile: Vector2i = _segment_target_toward(from_tile, plan_tile)
				_agents.set_agent_target(i, _tile_center(step_tile))
		var spread_slot: float = float(i % 8) * 0.04
		_set_settler_next_think_time(i, now_sec + spread_slot + _rng.randf_range(0.0, morning_dispatch_spread_sec))
		_settler_think_state[i] = THINK_EXECUTING
	if dispatch_budget > 0:
		_active_indicator_settlers_dirty = true
	_morning_dispatch_cursor += dispatch_budget
	if _morning_dispatch_cursor >= count:
		_morning_dispatch_active = false
		_morning_dispatch_cursor = -1


func _housing_capacity() -> int:
	return 1 + int(_buildings["house"]) * HOUSE_CAPACITY + int(_buildings.get("manor", 0)) * MANOR_CAPACITY


func _home_capacity_for_slot(slot: int) -> int:
	if slot < int(_buildings["house"]):
		return HOUSE_CAPACITY
	return MANOR_CAPACITY


func _home_center_for_slot(slot: int) -> Vector2:
	var houses: int = int(_buildings["house"])
	if slot < houses:
		if slot >= _house_tiles.size():
			return _tile_center(_camp_tile)
		return _tile_center(_house_tiles[slot])
	var manor_idx: int = slot - houses
	if manor_idx < 0 or manor_idx >= _manor_origins.size():
		return _tile_center(_camp_tile)
	var origin: Vector2i = _manor_origins[manor_idx]
	return Vector2(float(origin.x + 1) * TILE_SIZE, float(origin.y + 1) * TILE_SIZE)


func _is_structure_tile_occupied(tile: Vector2i) -> bool:
	if tile == _camp_tile:
		return true
	if _house_tiles.has(tile):
		return true
	if _tile_is_in_manor(tile):
		return true
	if _sawmill_tiles.has(tile):
		return true
	if _quarry_tiles.has(tile):
		return true
	if _workshop_tiles.has(tile):
		return true
	if _storehouse_tiles.has(tile):
		return true
	if _armory_tiles.has(tile):
		return true
	if _scout_lodge_tiles.has(tile):
		return true
	if _outpost_tiles.has(tile):
		return true
	return false


func _tile_is_in_manor(tile: Vector2i) -> bool:
	for origin in _manor_origins:
		if tile.x >= origin.x and tile.x < origin.x + MANOR_FOOTPRINT and tile.y >= origin.y and tile.y < origin.y + MANOR_FOOTPRINT:
			return true
	return false


func _manor_index_at(tile: Vector2i) -> int:
	for i in _manor_origins.size():
		var origin: Vector2i = _manor_origins[i]
		if tile.x >= origin.x and tile.x < origin.x + MANOR_FOOTPRINT and tile.y >= origin.y and tile.y < origin.y + MANOR_FOOTPRINT:
			return i
	return -1


func _job_for_settler(index: int) -> int:
	if _settler_job_overrides.has(index):
		var override_job: int = int(_settler_job_overrides[index])
		if override_job == JOB_SCOUT and not _scouting_unlocked():
			return JOB_FARM
		return override_job
	var farm_count: int = int(_job_counts["farm"])
	var lumber_count: int = int(_job_counts["lumber"])
	var stone_count: int = int(_job_counts["stone"])
	var hunt_count: int = int(_job_counts["hunt"])
	var scout_count: int = int(_job_counts["scout"])
	if index < farm_count:
		return JOB_FARM
	if index < farm_count + lumber_count:
		return JOB_LUMBER
	if index < farm_count + lumber_count + stone_count:
		return JOB_STONE
	if index < farm_count + lumber_count + stone_count + hunt_count:
		return JOB_HUNT
	if index < farm_count + lumber_count + stone_count + hunt_count + scout_count:
		return JOB_SCOUT
	return JOB_LUMBER if index % 2 == 1 else JOB_FARM


func _job_color_for(job: int) -> Color:
	match job:
		JOB_FARM:
			return Color(0.94, 0.25, 0.25, 1.0) # red
		JOB_LUMBER:
			return Color(0.24, 0.82, 0.34, 1.0) # green
		JOB_STONE:
			return Color(0.68, 0.68, 0.72, 1.0) # grey
		JOB_HUNT:
			return Color(0.53, 0.36, 0.22, 1.0) # brown
		JOB_SCOUT:
			return Color(0.48, 0.8, 0.98, 1.0)
		_:
			return Color(0.35, 0.9, 1.0, 1.0)


func _refresh_agent_job_colors(force: bool = false) -> void:
	var count: int = _agents.get_agent_count()
	if count <= 0:
		return
	if _agent_job_colors.size() != count:
		_agent_job_colors.resize(count)
		force = true
	if not force and not _agent_job_colors_dirty:
		return
	for i in count:
		_agent_job_colors[i] = _job_color_for(_job_for_settler(i))
	_agents.set_agent_colors(_agent_job_colors)
	_agent_job_colors_dirty = false


func _distribute_jobs_evenly() -> void:
	var settlers: int = _agents.get_agent_count()
	if settlers <= 0:
		return
	_job_counts["farm"] = 0
	_job_counts["lumber"] = 0
	_job_counts["stone"] = 0
	_job_counts["hunt"] = 0
	_job_counts["scout"] = 0
	for i in settlers:
		if i % 2 == 0:
			_job_counts["farm"] = int(_job_counts["farm"]) + 1
		else:
			_job_counts["lumber"] = int(_job_counts["lumber"]) + 1
	_clamp_job_counts()
	_apply_auto_tool_assignments()


func _assign_default_jobs_for_new_settlers(previous_count: int, count: int) -> void:
	if count <= previous_count:
		return
	for i in range(previous_count, count):
		if i % 2 == 0:
			_job_counts["farm"] = int(_job_counts["farm"]) + 1
		else:
			_job_counts["lumber"] = int(_job_counts["lumber"]) + 1
	_clamp_job_counts()
	_agent_job_colors_dirty = true


func _clamp_job_counts() -> void:
	var settlers: int = _agents.get_agent_count()
	var farm: int = clampi(int(_job_counts["farm"]), 0, settlers)
	var lumber: int = clampi(int(_job_counts["lumber"]), 0, settlers)
	var stone: int = clampi(int(_job_counts["stone"]), 0, settlers)
	var hunt: int = clampi(int(_job_counts["hunt"]), 0, settlers)
	var scout: int = clampi(int(_job_counts.get("scout", 0)), 0, settlers)
	if not _scouting_unlocked():
		scout = 0
	while farm + lumber + stone + hunt + scout > settlers:
		if stone > 0:
			stone -= 1
		elif scout > 0:
			scout -= 1
		elif hunt > 0:
			hunt -= 1
		elif lumber > 0:
			lumber -= 1
		else:
			farm -= 1
	_job_counts["farm"] = farm
	_job_counts["lumber"] = lumber
	_job_counts["stone"] = stone
	_job_counts["hunt"] = hunt
	_job_counts["scout"] = scout
	_agent_job_colors_dirty = true
	_update_job_labels()


func _update_job_labels() -> void:
	for key in _job_count_labels.keys():
		var lbl_obj: Variant = _job_count_labels[key]
		if not is_instance_valid(lbl_obj):
			_job_count_labels.erase(key)
			continue
		var lbl: Label = lbl_obj as Label
		if lbl == null:
			_job_count_labels.erase(key)
			continue
		lbl.text = str(int(_job_counts[key]))


func _recompute_homes() -> void:
	var settlers: int = _agents.get_agent_count()
	_settler_homes.resize(settlers)
	for i in settlers:
		_settler_homes[i] = -1
	var home_units: int = int(_buildings["house"]) + int(_buildings.get("manor", 0))
	if home_units <= 0:
		return
	var slot: int = 0
	var slots_left: int = _home_capacity_for_slot(slot)
	for i in settlers:
		while slots_left <= 0 and slot + 1 < home_units:
			slot += 1
			slots_left = _home_capacity_for_slot(slot)
		if slots_left > 0:
			_settler_homes[i] = slot
			slots_left -= 1


func _home_center_for_settler(index: int) -> Vector2:
	if index < 0 or index >= _settler_homes.size():
		return _tile_center(_camp_tile)
	var home_idx: int = _settler_homes[index]
	if home_idx < 0:
		return _tile_center(_camp_tile)
	return _home_center_for_slot(home_idx)


func _settler_has_home(index: int) -> bool:
	if index < 0 or index >= _settler_homes.size():
		return false
	return _settler_homes[index] >= 0


func _is_tile_claimed_by_other(tile: Vector2i, settler_index: int) -> bool:
	return _resource_mgr.is_tile_claimed_by_other(_tile_key(tile), settler_index, _tile_id(tile))


func _release_resource_claim(settler_index: int) -> void:
	if not _settler_resource_targets.has(settler_index):
		return
	var tile: Vector2i = _settler_resource_targets[settler_index]
	_resource_mgr.release_resource_claim(settler_index, _tile_key(tile), _tile_id(tile))


func _try_claim_resource_tile(settler_index: int, tile: Vector2i) -> bool:
	var key: String = _tile_key(tile)
	var tile_id: int = _tile_id(tile)
	var prev_key: String = ""
	var prev_tile_id: int = -1
	if _settler_resource_targets.has(settler_index):
		var prev: Vector2i = _settler_resource_targets[settler_index]
		prev_key = _tile_key(prev)
		prev_tile_id = _tile_id(prev)
	return _resource_mgr.try_claim_resource_tile(settler_index, tile, key, prev_key, tile_id, prev_tile_id)


func _is_resource_job(job: int) -> bool:
	return job == JOB_FARM or job == JOB_LUMBER or job == JOB_STONE


func _is_day_plan_valid(settler_index: int, plan_tile: Vector2i, job: int) -> bool:
	if plan_tile == Vector2i(-9999, -9999):
		return false
	if not _is_resource_job(job):
		return false
	if job == JOB_FARM:
		var rt: int = _resource_type_at(plan_tile)
		if rt != RES_APPLE and rt != RES_BERRY_BLUE and rt != RES_BERRY_RASP and rt != RES_BERRY_BLACK:
			return false
		if _resource_left(plan_tile, rt) < FOOD_MIN_HARVEST:
			return false
	elif job == JOB_STONE:
		var mined_type: int = _resource_type_at(plan_tile)
		if mined_type != RES_STONE and (not _metal_mining_unlocked or mined_type != RES_METAL):
			return false
		if _resource_left(plan_tile, mined_type) <= 0.0:
			return false
	else:
		var rtype: int = RES_TREE
		if _resource_type_at(plan_tile) != rtype:
			return false
		if _resource_left(plan_tile, rtype) <= 0.0:
			return false
	if _is_tile_claimed_by_other(plan_tile, settler_index):
		return false
	return true


func _update_day_plan_for_settler(settler_index: int, from_tile: Vector2i, job: int) -> void:
	if not _is_resource_job(job):
		_settler_day_plan_targets.erase(settler_index)
		_settler_day_plan_job.erase(settler_index)
		return
	if _settler_day_plan_targets.has(settler_index) and _settler_day_plan_job.has(settler_index):
		var cached_job: int = int(_settler_day_plan_job[settler_index])
		var cached_tile: Vector2i = _settler_day_plan_targets[settler_index]
		if cached_job == job and _is_day_plan_valid(settler_index, cached_tile, job):
			return

	var plan: Vector2i = Vector2i(-9999, -9999)
	if job == JOB_FARM:
		plan = _nearest_food_tile(from_tile, settler_index)
	elif job == JOB_STONE:
		plan = _nearest_mining_tile(from_tile, settler_index)
	else:
		var rtype: int = RES_TREE
		plan = _nearest_resource_tile(from_tile, rtype, settler_index)

	if plan == Vector2i(-9999, -9999):
		_settler_day_plan_targets.erase(settler_index)
		_settler_day_plan_job.erase(settler_index)
		return
	_settler_day_plan_targets[settler_index] = plan
	_settler_day_plan_job[settler_index] = job


func _segment_target_toward(from_tile: Vector2i, goal_tile: Vector2i) -> Vector2i:
	var max_step: int = maxi(1, settler_route_segment_tiles)
	var dx: int = goal_tile.x - from_tile.x
	var dy: int = goal_tile.y - from_tile.y
	var adx: int = absi(dx)
	var ady: int = absi(dy)
	var dist_tiles: int = maxi(adx, ady)
	if dist_tiles <= max_step:
		return goal_tile
	var ratio: float = float(max_step) / float(maxi(1, dist_tiles))
	var step_x: int = int(round(float(dx) * ratio))
	var step_y: int = int(round(float(dy) * ratio))
	if step_x == 0 and dx != 0:
		step_x = 1 if dx > 0 else -1
	if step_y == 0 and dy != 0:
		step_y = 1 if dy > 0 else -1
	return Vector2i(from_tile.x + step_x, from_tile.y + step_y)


func _segment_world_target(from_tile: Vector2i, goal_world: Vector2) -> Vector2:
	var goal_tile: Vector2i = _world_to_tile(goal_world)
	var move_tile: Vector2i = _segment_target_toward(from_tile, goal_tile)
	return _tile_center(move_tile)


func _settler_wander_target(settler_index: int, from_tile: Vector2i) -> Vector2:
	var directions: Array[Vector2i] = [
		Vector2i(1, 0), Vector2i(1, 1), Vector2i(0, 1), Vector2i(-1, 1),
		Vector2i(-1, 0), Vector2i(-1, -1), Vector2i(0, -1), Vector2i(1, -1),
	]
	var start: int = absi(settler_index) % directions.size()
	var base_step: int = maxi(1, settler_route_segment_tiles)
	for ring in range(1, 4):
		var step: int = base_step * ring
		for offset in directions.size():
			var dir: Vector2i = directions[(start + offset) % directions.size()]
			var candidate: Vector2i = from_tile + dir * step
			if _is_structure_tile_occupied(candidate):
				continue
			return _tile_center(candidate)
	return _tile_center(from_tile)


func _nearest_resource_tile(from_tile: Vector2i, res_type: int, claimant_index: int = -1, max_radius: int = 26) -> Vector2i:
	var chunk_tiles_map: Dictionary = {}
	var fallback_tiles: Array[Vector2i] = []
	if res_type == RES_TREE:
		chunk_tiles_map = _resource_tree_chunk_tiles
		fallback_tiles = _resource_tree_tiles
	elif res_type == RES_STONE:
		chunk_tiles_map = _resource_stone_chunk_tiles
		fallback_tiles = _resource_stone_tiles
	elif res_type == RES_METAL:
		chunk_tiles_map = _resource_metal_chunk_tiles
		fallback_tiles = _resource_metal_tiles
	return _nearest_chunked_resource_tile(from_tile, claimant_index, max_radius, fallback_tiles, chunk_tiles_map, res_type, 0.01, false)


func _nearest_mining_tile(from_tile: Vector2i, claimant_index: int = -1, max_radius: int = 30) -> Vector2i:
	var stone_tile: Vector2i = _nearest_resource_tile(from_tile, RES_STONE, claimant_index, max_radius)
	if not _metal_mining_unlocked:
		return stone_tile
	var metal_tile: Vector2i = _nearest_resource_tile(from_tile, RES_METAL, claimant_index, max_radius)
	if metal_tile == Vector2i(-9999, -9999):
		return stone_tile
	if stone_tile == Vector2i(-9999, -9999):
		return metal_tile
	var stone_d: float = float(from_tile.distance_to(stone_tile))
	var metal_d: float = float(from_tile.distance_to(metal_tile))
	# Prefer nearby metal slightly to keep it distinct and valuable.
	return metal_tile if metal_d <= stone_d + 2.0 else stone_tile


func _nearest_food_tile(from_tile: Vector2i, claimant_index: int = -1, max_radius: int = 32) -> Vector2i:
	return _nearest_chunked_resource_tile(from_tile, claimant_index, max_radius, _resource_food_tiles, _resource_food_chunk_tiles, RES_APPLE, FOOD_MIN_HARVEST, true)


func _nearest_chunked_resource_tile(
	from_tile: Vector2i,
	claimant_index: int,
	max_radius: int,
	fallback_tiles: Array[Vector2i],
	chunk_tiles_map: Dictionary,
	res_type: int,
	min_amount: float,
	is_food: bool
) -> Vector2i:
	if fallback_tiles.is_empty():
		return Vector2i(-9999, -9999)
	if chunk_tiles_map.is_empty():
		return _nearest_resource_tile_linear(from_tile, claimant_index, max_radius, fallback_tiles, res_type, min_amount, is_food)
	var origin_chunk: Vector2i = _chunk_for_tile(from_tile)
	var chunk_size: int = maxi(4, world_chunk_tiles)
	var max_d_sq: int = max_radius * max_radius
	var best_tile: Vector2i = Vector2i(-9999, -9999)
	var best_d_sq: int = 2147483647
	var max_chunk_radius: int = maxi(0, ceili(float(max_radius) / float(chunk_size)))
	for ring in range(0, max_chunk_radius + 1):
		for cy in range(origin_chunk.y - ring, origin_chunk.y + ring + 1):
			for cx in range(origin_chunk.x - ring, origin_chunk.x + ring + 1):
				if ring > 0 and cx != origin_chunk.x - ring and cx != origin_chunk.x + ring and cy != origin_chunk.y - ring and cy != origin_chunk.y + ring:
					continue
				var key: String = _world_chunk_key(Vector2i(cx, cy))
				if not chunk_tiles_map.has(key):
					continue
				var chunk_tiles: Array = chunk_tiles_map[key]
				for tile_v in chunk_tiles:
					var tile: Vector2i = tile_v
					var dx: int = tile.x - from_tile.x
					var dy: int = tile.y - from_tile.y
					var d_sq: int = dx * dx + dy * dy
					if not _nearest_candidate_passes(tile, d_sq, max_d_sq, best_d_sq, claimant_index, res_type, min_amount, is_food):
						continue
					best_d_sq = d_sq
					best_tile = tile
		if best_tile != Vector2i(-9999, -9999):
			var next_ring_min_tiles: int = maxi(0, ring * chunk_size - (chunk_size / 2))
			if next_ring_min_tiles * next_ring_min_tiles > best_d_sq:
				break
	if best_tile != Vector2i(-9999, -9999):
		return best_tile
	return _nearest_resource_tile_linear(from_tile, claimant_index, max_radius, fallback_tiles, res_type, min_amount, is_food)


func _nearest_resource_tile_linear(
	from_tile: Vector2i,
	claimant_index: int,
	max_radius: int,
	candidates: Array[Vector2i],
	res_type: int,
	min_amount: float,
	is_food: bool
) -> Vector2i:
	var max_d_sq: int = max_radius * max_radius
	var best_tile: Vector2i = Vector2i(-9999, -9999)
	var best_d_sq: int = 2147483647
	for tile in candidates:
		var dx: int = tile.x - from_tile.x
		var dy: int = tile.y - from_tile.y
		var d_sq: int = dx * dx + dy * dy
		if not _nearest_candidate_passes(tile, d_sq, max_d_sq, best_d_sq, claimant_index, res_type, min_amount, is_food):
			continue
		best_d_sq = d_sq
		best_tile = tile
	return best_tile


func _nearest_wildlife_pos(from_pos: Vector2, prefer_wolf: bool = true) -> Vector2:
	var grid: Dictionary = _wildlife_wolf_query_grid if prefer_wolf else _wildlife_query_grid
	return _nearest_wildlife_from_grid(from_pos, grid)


func _nearest_hostile_wildlife_pos(from_pos: Vector2) -> Vector2:
	return _nearest_wildlife_from_grid(from_pos, _wildlife_hostile_query_grid)


func _wildlife_grid_key_for_pos(pos: Vector2) -> String:
	var cell_size: float = 96.0
	return "%d:%d" % [floori(pos.x / cell_size), floori(pos.y / cell_size)]


func _rebuild_wildlife_query_grid() -> void:
	_wildlife_query_grid.clear()
	_wildlife_wolf_query_grid.clear()
	_wildlife_hostile_query_grid.clear()
	if _wildlife.is_empty():
		_wildlife_query_min_cell = Vector2i.ZERO
		_wildlife_query_max_cell = Vector2i.ZERO
		return
	var first_cell_set: bool = false
	for w in _wildlife:
		var pos: Vector2 = Vector2(w.get("pos", Vector2.ZERO))
		var typ: int = int(w.get("type", -1))
		var key: String = _wildlife_grid_key_for_pos(pos)
		if not _wildlife_query_grid.has(key):
			_wildlife_query_grid[key] = []
		var list: Array = _wildlife_query_grid[key]
		list.append(pos)
		_wildlife_query_grid[key] = list
		if typ == ANIMAL_WOLF:
			if not _wildlife_wolf_query_grid.has(key):
				_wildlife_wolf_query_grid[key] = []
			var wolf_list: Array = _wildlife_wolf_query_grid[key]
			wolf_list.append(pos)
			_wildlife_wolf_query_grid[key] = wolf_list
		if typ == ANIMAL_WOLF or typ == ANIMAL_BEAR:
			if not _wildlife_hostile_query_grid.has(key):
				_wildlife_hostile_query_grid[key] = []
			var hostile_list: Array = _wildlife_hostile_query_grid[key]
			hostile_list.append(pos)
			_wildlife_hostile_query_grid[key] = hostile_list
		var cell := Vector2i(floori(pos.x / 96.0), floori(pos.y / 96.0))
		if not first_cell_set:
			_wildlife_query_min_cell = cell
			_wildlife_query_max_cell = cell
			first_cell_set = true
		else:
			_wildlife_query_min_cell.x = mini(_wildlife_query_min_cell.x, cell.x)
			_wildlife_query_min_cell.y = mini(_wildlife_query_min_cell.y, cell.y)
			_wildlife_query_max_cell.x = maxi(_wildlife_query_max_cell.x, cell.x)
			_wildlife_query_max_cell.y = maxi(_wildlife_query_max_cell.y, cell.y)


func _nearest_wildlife_from_grid(from_pos: Vector2, grid: Dictionary) -> Vector2:
	if grid.is_empty():
		return from_pos
	var cell_size: float = 96.0
	var origin_cell := Vector2i(floori(from_pos.x / cell_size), floori(from_pos.y / cell_size))
	var max_ring: int = maxi(
		maxi(absi(origin_cell.x - _wildlife_query_min_cell.x), absi(origin_cell.x - _wildlife_query_max_cell.x)),
		maxi(absi(origin_cell.y - _wildlife_query_min_cell.y), absi(origin_cell.y - _wildlife_query_max_cell.y))
	)
	var best: Vector2 = from_pos
	var best_d_sq: float = 1e18
	for ring in range(0, max_ring + 1):
		for cy in range(origin_cell.y - ring, origin_cell.y + ring + 1):
			for cx in range(origin_cell.x - ring, origin_cell.x + ring + 1):
				if ring > 0 and cx != origin_cell.x - ring and cx != origin_cell.x + ring and cy != origin_cell.y - ring and cy != origin_cell.y + ring:
					continue
				var key: String = "%d:%d" % [cx, cy]
				if not grid.has(key):
					continue
				var positions: Array = grid[key]
				for pos_v in positions:
					var pos: Vector2 = pos_v
					var d_sq: float = from_pos.distance_squared_to(pos)
					if d_sq < best_d_sq:
						best_d_sq = d_sq
						best = pos
		if best != from_pos:
			var next_ring_min_px: float = maxf(0.0, float(ring) * cell_size - cell_size * 0.5)
			if next_ring_min_px * next_ring_min_px > best_d_sq:
				break
	return best


func _best_indexed_patrol_tile(
	candidates: Array[Vector2i],
	from_tile: Vector2i,
	max_radius: int,
	avoid_world: Vector2,
	res_type: int,
	min_amount: float
) -> Vector2i:
	if candidates.is_empty():
		return Vector2i(-9999, -9999)
	var best: Vector2i = Vector2i(-9999, -9999)
	var best_d_sq: int = 2147483647
	var max_d_sq: int = max_radius * max_radius
	var avoid_d_sq: float = (float(TILE_SIZE) * 3.0) * (float(TILE_SIZE) * 3.0)
	for tile in candidates:
		var dx: int = tile.x - from_tile.x
		var dy: int = tile.y - from_tile.y
		var d_sq: int = dx * dx + dy * dy
		if d_sq > max_d_sq or d_sq >= best_d_sq:
			continue
		if avoid_world != Vector2.ZERO and _tile_center(tile).distance_squared_to(avoid_world) < avoid_d_sq:
			continue
		if res_type == RES_APPLE:
			var rt: int = _resource_type_at(tile)
			if rt != RES_APPLE and rt != RES_BERRY_BLUE and rt != RES_BERRY_RASP and rt != RES_BERRY_BLACK:
				continue
			if _resource_left(tile, rt) < min_amount:
				continue
		else:
			if _resource_left(tile, res_type) < min_amount:
				continue
		best = tile
		best_d_sq = d_sq
	return best


func _retarget_hunter_shared_wander(now_sec: float) -> void:
	var radius: int = maxi(8, int(round(hunter_wander_radius_tiles)))
	var from_tile: Vector2i = _camp_tile
	if _hunter_recent_enemy_focus != Vector2.ZERO and now_sec < _hunter_enemy_focus_until:
		from_tile = _world_to_tile(_hunter_recent_enemy_focus)
	var avoid: Vector2 = _hunter_shared_wander_target

	var target_tile: Vector2i = _best_indexed_patrol_tile(_resource_food_tiles, from_tile, radius, avoid, RES_APPLE, FOOD_MIN_HARVEST)
	if target_tile == Vector2i(-9999, -9999):
		target_tile = _best_indexed_patrol_tile(_resource_tree_tiles, from_tile, radius, avoid, RES_TREE, 0.01)
	if target_tile == Vector2i(-9999, -9999):
		target_tile = _best_indexed_patrol_tile(_resource_stone_tiles, from_tile, radius, avoid, RES_STONE, 0.01)
	if target_tile == Vector2i(-9999, -9999) and _metal_mining_unlocked:
		target_tile = _best_indexed_patrol_tile(_resource_metal_tiles, from_tile, radius, avoid, RES_METAL, 0.01)

	if target_tile != Vector2i(-9999, -9999):
		_hunter_shared_wander_target = _tile_center(target_tile)
		_hunter_wander_retarget_at = now_sec + 3.25
		return

	_hunter_shared_wander_target = _tile_center(_camp_tile)
	_hunter_wander_retarget_at = now_sec + 2.0


func _hunter_group_offset(slot: int, total: int) -> Vector2:
	if total <= 1:
		return Vector2.ZERO
	var angle: float = TAU * float(slot) / float(total)
	var radius: float = minf(28.0, hunter_group_spacing_px + float(total) * 0.35)
	return Vector2(cos(angle), sin(angle)) * radius


func _set_hunter_runtime_state(index: int, status: String, reason: String, target_pos: Vector2) -> void:
	var prev: String = String(_hunter_runtime_state.get(index, ""))
	if prev == status:
		return
	_hunter_runtime_state[index] = status
	_active_indicator_settlers_dirty = true
	var state_tag: String = "hunt_%s" % status
	if String(_agent_last_state.get(index, "")) != state_tag:
		_agent_last_state[index] = state_tag
		_record_agent_action(index, reason)
		_log_global_settler_event("state_change", index, _job_for_settler(index), state_tag, target_pos, reason)


func _update_hunter_movement_states(agents: PackedVector2Array, targets: PackedVector2Array, now_sec: float, is_night: bool) -> void:
	if _agent_speed_multipliers.size() != agents.size():
		_agent_speed_multipliers.resize(agents.size())
		for i in agents.size():
			_agent_speed_multipliers[i] = 1.0
	var hunter_indices: Array[int] = []
	for i in agents.size():
		if _job_for_settler(i) == JOB_HUNT:
			hunter_indices.append(i)
		else:
			_agent_speed_multipliers[i] = 1.0
			if _hunter_runtime_state.has(i):
				_hunter_runtime_state.erase(i)
				_active_indicator_settlers_dirty = true
			_hunter_boost_until.erase(i)
			_hunter_rest_until.erase(i)
	if hunter_indices.is_empty():
		return

	if _hunter_shared_wander_target == Vector2.ZERO:
		_retarget_hunter_shared_wander(now_sec)
	var should_retarget: bool = now_sec >= _hunter_wander_retarget_at
	if not should_retarget:
		for i in hunter_indices:
			if agents[i].distance_to(_hunter_shared_wander_target) <= float(TILE_SIZE) * 1.2:
				should_retarget = true
				break
	if should_retarget:
		_retarget_hunter_shared_wander(now_sec)

	var group_total: int = hunter_indices.size()
	for slot in group_total:
		var i: int = hunter_indices[slot]
		var formation_offset: Vector2 = _hunter_group_offset(slot, group_total)

		if is_night:
			_agent_speed_multipliers[i] = 1.0
			_set_hunter_runtime_state(i, "night", "Hunter returning home", targets[i])
			continue

		var pos: Vector2 = agents[i]
		var hostile_pos: Vector2 = _nearest_hostile_wildlife_pos(pos)
		var spotted_enemy: bool = hostile_pos != pos and pos.distance_to(hostile_pos) <= 220.0
		if spotted_enemy:
			_hunter_recent_enemy_focus = hostile_pos
			_hunter_enemy_focus_until = now_sec + 8.0
		var boost_until: float = float(_hunter_boost_until.get(i, 0.0))
		var rest_until: float = float(_hunter_rest_until.get(i, 0.0))
		if boost_until > 0.0 and now_sec >= boost_until and rest_until < boost_until + 0.001:
			rest_until = boost_until + maxf(0.2, hunter_rest_duration_sec)
			_hunter_rest_until[i] = rest_until

		if now_sec < rest_until:
			targets[i] = pos
			_agent_speed_multipliers[i] = clampf(hunter_rest_speed_mult, 0.0, 1.0)
			_set_hunter_runtime_state(i, "rest", "Hunter resting", targets[i])
			continue

		if spotted_enemy and now_sec >= boost_until:
			boost_until = now_sec + maxf(0.1, hunter_boost_duration_sec)
			_hunter_boost_until[i] = boost_until

		if now_sec < boost_until:
			var from_tile: Vector2i = _world_to_tile(pos)
			targets[i] = _segment_world_target(from_tile, hostile_pos + formation_offset * 0.5)
			_agent_speed_multipliers[i] = maxf(1.0, hunter_boost_speed_mult)
			_set_hunter_runtime_state(i, "boost", "Enemy spotted - sprint!", targets[i])
			if now_sec + (1.0 / 60.0) >= boost_until:
				_hunter_rest_until[i] = boost_until + maxf(0.2, hunter_rest_duration_sec)
			continue

		var from_tile_w: Vector2i = _world_to_tile(pos)
		targets[i] = _segment_world_target(from_tile_w, _hunter_shared_wander_target + formation_offset)
		_agent_speed_multipliers[i] = 1.0
		_set_hunter_runtime_state(i, "wander", "Patrolling", targets[i])


func _farm_tile_for_settler(index: int) -> Vector2i:
	var angle: float = float((index * 53) % 360) * PI / 180.0
	var radius: float = 5.0 + float((index * 13) % 7)
	return Vector2i(
		_camp_tile.x + int(round(cos(angle) * radius)),
		_camp_tile.y + int(round(sin(angle) * radius))
	)


func _apply_weapon_clustering(index: int, base_target: Vector2, agents: PackedVector2Array) -> Vector2:
	if agents.size() <= 1:
		return base_target
	var weapon_id: int = _weapon_for_settler(index)
	var center: Vector2 = Vector2.ZERO
	var same: int = 0
	for j in agents.size():
		if _weapon_for_settler(j) != weapon_id:
			continue
		center += agents[j]
		same += 1
	if same <= 1:
		return base_target
	center /= float(same)
	var cohesion: float = clampf(_weapon_cluster_strength, 0.0, 0.5)
	var clustered: Vector2 = base_target.lerp(center, cohesion)
	var slot: int = (index * 37 + weapon_id * 11) % same
	var angle: float = TAU * float(slot) / float(maxi(1, same))
	var spacing: float = minf(18.0, 6.0 + float(same) * 1.2)
	return clustered + Vector2(cos(angle), sin(angle)) * spacing


func _current_poi_target_index() -> int:
	var best_idx: int = -1
	var best_d: float = 1e9
	for i in _poi_sites.size():
		var site: Dictionary = _poi_sites[i]
		if bool(site.get("resolved", false)):
			continue
		var tile: Vector2i = site["tile"]
		var d: float = _tile_center(tile).distance_to(_tile_center(_camp_tile))
		if d < best_d:
			best_d = d
			best_idx = i
	return best_idx


func _select_poi_scout(agents: PackedVector2Array, poi_target: Vector2) -> int:
	var best_scout: int = -1
	var best_scout_d: float = 1e9
	for i in agents.size():
		if _job_for_settler(i) != JOB_SCOUT:
			continue
		var d: float = agents[i].distance_to(poi_target)
		if d < best_scout_d:
			best_scout_d = d
			best_scout = i
	return best_scout


func _update_settler_targets(delta: float) -> void:
	_ai_tick += delta
	_settler_decision_tick_counter += 1
	var is_night: bool = _is_night()
	var agents: PackedVector2Array = _agents.get_agent_positions()
	var count: int = agents.size()
	if count <= 0:
		_settler_decisions_this_tick = 0
		return
	_sync_settler_think_buffers(count)
	_refresh_agent_job_colors()
	var now_sec: float = Time.get_ticks_msec() * 0.001
	var targets: PackedVector2Array = _agents.get_agent_targets()
	if targets.size() != count:
		targets.resize(count)
		for i in count:
			targets[i] = _target
	var vp: Vector2 = get_viewport_rect().size
	var z: Vector2 = _camera.zoom
	var half: Vector2 = Vector2(vp.x * 0.5 / z.x, vp.y * 0.5 / z.y)
	var cam: Vector2 = _camera.position
	var view_min: Vector2 = cam - half
	var view_max: Vector2 = cam + half
	var effective_decision_budget: int = _effective_pathfind_budget(settler_decision_budget_per_tick, 1)
	_pathfind_budget_effective = effective_decision_budget
	var effective_night_plan_budget: int = _effective_pathfind_budget(night_planning_budget_per_tick, 1)
	var effective_scan_budget: int = _effective_settler_scan_budget(count, effective_decision_budget, effective_night_plan_budget, is_night)
	var effective_monitor_budget: int = _effective_settler_monitor_budget(count, effective_decision_budget, effective_night_plan_budget, is_night)
	var due_limit: int = mini(count, maxi(effective_decision_budget * 3, effective_scan_budget))
	var due_indices: PackedInt32Array = _collect_due_settler_indices(now_sec, due_limit)
	_ensure_settler_candidate_seen(count)
	_settler_candidate_seen.fill(0)
	for due_idx in due_indices:
		var due_index: int = int(due_idx)
		if due_index < count:
			_settler_candidate_seen[due_index] = 1
	var monitor_indices: PackedInt32Array = _collect_monitor_settler_indices(count, effective_monitor_budget, now_sec, _settler_candidate_seen)
	var candidate_indices: PackedInt32Array = PackedInt32Array()
	candidate_indices.resize(due_indices.size() + monitor_indices.size())
	for i in due_indices.size():
		candidate_indices[i] = due_indices[i]
	for i in monitor_indices.size():
		candidate_indices[due_indices.size() + i] = monitor_indices[i]
	var state: Dictionary = _settler_decision_run_state
	state["delta"] = delta
	state["is_night"] = is_night
	state["agents"] = agents
	state["count"] = count
	state["now_sec"] = now_sec
	state["targets"] = targets
	state["decision_budget"] = effective_decision_budget
	state["night_plan_budget"] = effective_night_plan_budget
	state["scan_budget"] = effective_scan_budget
	state["candidate_indices"] = candidate_indices
	state["monitor_advance"] = monitor_indices.size()
	state["decision_tick_counter"] = _settler_decision_tick_counter
	state["view_min"] = view_min
	state["view_max"] = view_max
	state["settler_decision_cursor"] = _settler_decision_cursor
	state["settler_decisions_this_tick"] = 0
	state["global_target"] = _target
	state["camp_tile"] = _camp_tile
	state["settler_next_think_time"] = _settler_next_think_time
	state["settler_think_state"] = _settler_think_state
	state["settler_idle_time"] = _settler_idle_time
	state["settler_last_pos"] = _settler_last_pos
	state["agent_last_state"] = _agent_last_state
	state["settler_resource_targets"] = _settler_resource_targets
	state["settler_day_plan_targets"] = _settler_day_plan_targets
	state["settler_day_plan_job"] = _settler_day_plan_job
	state["poi_sites"] = _poi_sites
	state["metal_mining_unlocked"] = _metal_mining_unlocked
	var result: Dictionary = _settler_decision_system.run(state)
	_settler_decisions_this_tick = int(result["settler_decisions_this_tick"])
	_settler_decision_cursor = int(result["settler_decision_cursor"])
	_settler_next_think_time = result["settler_next_think_time"]
	_settler_think_state = result["settler_think_state"]
	_settler_idle_time = result["settler_idle_time"]
	_settler_last_pos = result["settler_last_pos"]
	_agent_last_state = result["agent_last_state"]
	var indicator_changed: PackedInt32Array = result.get("indicator_changed", PackedInt32Array())
	for idx in indicator_changed:
		var indicator_index: int = int(idx)
		_set_active_indicator_state(indicator_index, indicator_index < _settler_think_state.size() and _settler_think_state[indicator_index] == THINK_THINKING)
	targets = result["targets"]
	if _settler_capacity_ignore.size() != count:
		_settler_capacity_ignore.resize(count)
	for i in count:
		var state_tag: String = String(_agent_last_state.get(i, ""))
		_settler_capacity_ignore[i] = 1 if (state_tag.begins_with("night_") or state_tag.ends_with("_night")) else 0
	_update_hunter_movement_states(agents, targets, now_sec, is_night)
	_agents.set_agent_targets(targets)
	_agents.set_agent_capacity_ignore(_settler_capacity_ignore)
	_agents.set_agent_speed_multipliers(_agent_speed_multipliers)
	_refresh_active_indicator_settlers(count)


func _is_settler_indicator_active(index: int, count: int) -> bool:
	if index < 0 or index >= count:
		return false
	if _settler_think_state.size() == count and _settler_think_state[index] == THINK_THINKING:
		return true
	return false


func _set_active_indicator_state(index: int, active: bool) -> void:
	if index < 0:
		return
	if active:
		if _active_indicator_settler_pos.has(index):
			return
		_active_indicator_settler_pos[index] = _active_indicator_settlers.size()
		_active_indicator_settlers.append(index)
		return
	if not _active_indicator_settler_pos.has(index):
		return
	var pos: int = int(_active_indicator_settler_pos[index])
	var last_idx: int = _active_indicator_settlers.size() - 1
	if pos < 0 or pos > last_idx:
		_active_indicator_settler_pos.erase(index)
		return
	if pos != last_idx:
		var moved: int = int(_active_indicator_settlers[last_idx])
		_active_indicator_settlers[pos] = moved
		_active_indicator_settler_pos[moved] = pos
	_active_indicator_settlers.remove_at(last_idx)
	_active_indicator_settler_pos.erase(index)


func _refresh_active_indicator_settlers(count: int) -> void:
	if not _active_indicator_settlers_dirty:
		return
	if count <= 0:
		_active_indicator_settlers.resize(0)
		_active_indicator_settler_pos.clear()
		_active_indicator_population_count = 0
		_active_indicator_settlers_dirty = false
		return
	_active_indicator_settlers.resize(0)
	_active_indicator_settler_pos.clear()
	for i in count:
		if _is_settler_indicator_active(i, count):
			_set_active_indicator_state(i, true)
	_active_indicator_population_count = count
	_active_indicator_settlers_dirty = false


func _on_viewport_resized() -> void:
	if _upgrade_panel == null:
		return
	var vp := get_viewport_rect().size
	_upgrade_panel.size.y = vp.y - 80.0
	_upgrade_panel.position.y = 48.0
	_upgrade_panel.position.x = vp.x - _drawer_width if _panel_open else vp.x + 12.0
	if _upgrade_toggle != null:
		_upgrade_toggle.position = Vector2(vp.x - 136.0, 10.0)
	_position_hover_panel()
	_position_performance_panel()
	_sync_agent_render_bounds()


func _sync_agent_render_bounds() -> void:
	if _agents == null or _camera == null:
		return
	var vp: Vector2 = get_viewport_rect().size
	if vp.x <= 0.0 or vp.y <= 0.0:
		return
	var z: Vector2 = _camera.zoom
	var half: Vector2 = Vector2(vp.x * 0.5 / z.x, vp.y * 0.5 / z.y)
	var cam: Vector2 = _camera.position
	_agents.set_render_bounds(cam - half, cam + half)


func _build_weapon_editor_ui() -> void:
	if WEAPON_EDITOR_SCENE == null or _ui_layer == null:
		return
	_weapon_editor_panel = WEAPON_EDITOR_SCENE.instantiate() as WeaponEditorPanel
	if _weapon_editor_panel == null:
		return
	_ui_layer.add_child(_weapon_editor_panel)
	_weapon_editor_panel.save_requested.connect(_on_weapon_editor_save_requested)
	_weapon_editor_panel.closed_requested.connect(func() -> void:
		_record_agent_action(0, "Closed weapon editor")
	)
	_refresh_weapon_editor_records()


func _toggle_weapon_editor() -> void:
	if _weapon_editor_panel == null:
		return
	if not _weapon_editor_panel.visible:
		_refresh_weapon_editor_records()
	_weapon_editor_panel.visible = not _weapon_editor_panel.visible
	if _weapon_editor_panel.visible:
		_record_agent_action(0, "Opened weapon editor")


func _refresh_weapon_editor_records() -> void:
	if _weapon_editor_panel == null:
		return
	_weapon_editor_panel.set_weapon_records(_weapon_records_for_editor())


func _weapon_records_for_editor() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var ids: Array = _weapon_registry.keys()
	ids.sort()
	for idv in ids:
		var weapon_id: int = int(idv)
		var data: WeaponData = _weapon_registry.get(weapon_id, null)
		if data == null:
			continue
		out.append({
			"weapon_id": data.weapon_id,
			"weapon_name": data.weapon_name,
			"attack_kind": data.attack_kind,
			"range": data.range,
			"damage": data.damage,
			"cooldown": data.cooldown,
			"defense": data.defense,
			"aoe_radius": data.aoe_radius,
			"projectile_speed": data.projectile_speed,
			"trail_color": data.trail_color,
			"trail_width": data.trail_width,
			"icon_path": "" if data.icon_texture == null else String(data.icon_texture.resource_path),
			"projectile_path": "" if data.projectile_texture == null else String(data.projectile_texture.resource_path),
			"sound_path": "" if data.attack_sound == null else String(data.attack_sound.resource_path),
			"resource_path": String(data.resource_path),
		})
	return out


func _on_weapon_editor_save_requested(record: Dictionary) -> void:
	var wd := WeaponData.new()
	wd.weapon_id = int(record.get("weapon_id", 0))
	wd.weapon_name = String(record.get("weapon_name", "Weapon %d" % wd.weapon_id))
	wd.attack_kind = int(record.get("attack_kind", WeaponData.AttackKind.MELEE))
	wd.range = float(record.get("range", 34.0))
	wd.damage = float(record.get("damage", 1.0))
	wd.cooldown = float(record.get("cooldown", 1.4))
	wd.defense = float(record.get("defense", 1.0))
	wd.aoe_radius = float(record.get("aoe_radius", 0.0))
	wd.projectile_speed = float(record.get("projectile_speed", 380.0))
	wd.trail_color = record.get("trail_color", Color(0.82, 0.76, 0.42, 1.0))
	wd.trail_width = float(record.get("trail_width", 2.2))

	var icon_path: String = String(record.get("icon_path", "")).strip_edges()
	if not icon_path.is_empty():
		var icon: Texture2D = load(icon_path)
		if icon != null:
			wd.icon_texture = icon
	var projectile_path: String = String(record.get("projectile_path", "")).strip_edges()
	if not projectile_path.is_empty():
		var projectile_tex: Texture2D = load(projectile_path)
		if projectile_tex != null:
			wd.projectile_texture = projectile_tex
	var sound_path: String = String(record.get("sound_path", "")).strip_edges()
	if not sound_path.is_empty():
		var attack_sfx: AudioStream = load(sound_path)
		if attack_sfx != null:
			wd.attack_sound = attack_sfx

	DirAccess.make_dir_recursive_absolute("user://weapons")
	var save_path: String = "user://weapons/weapon_%d.tres" % wd.weapon_id
	var err: int = ResourceSaver.save(wd, save_path)
	if err != OK:
		push_warning("Failed to save weapon resource %s (err %d)" % [save_path, err])
		return

	_load_weapon_registry()
	_refresh_weapon_editor_records()
	_mark_settler_weapons_dirty()
	_record_agent_action(0, "Saved weapon %s" % wd.weapon_name)


func _load_weapon_registry() -> void:
	_weapon_registry.clear()
	for wid in [WEAPON_SPEAR, WEAPON_SHIELD, WEAPON_BOW, WEAPON_JAVELIN]:
		_register_weapon_data(_default_weapon_data(wid))
	_load_weapon_dir("res://data/weapons")
	_load_weapon_dir("user://weapons")


func _load_weapon_dir(dir_path: String) -> void:
	var dir: DirAccess = DirAccess.open(dir_path)
	if dir == null:
		return
	dir.list_dir_begin()
	while true:
		var name: String = dir.get_next()
		if name.is_empty():
			break
		if dir.current_is_dir():
			continue
		if not name.ends_with(".tres") and not name.ends_with(".res"):
			continue
		var res_path: String = "%s/%s" % [dir_path, name]
		var wd: WeaponData = load(res_path)
		if wd == null:
			continue
		_register_weapon_data(wd)
	dir.list_dir_end()


func _register_weapon_data(data: WeaponData) -> void:
	if data == null:
		return
	_weapon_registry[data.weapon_id] = data


func _default_weapon_data(weapon_id: int) -> WeaponData:
	var d := WeaponData.new()
	d.weapon_id = weapon_id
	match weapon_id:
		WEAPON_SHIELD:
			d.weapon_name = "Shield"
			d.attack_kind = WeaponData.AttackKind.MELEE
			d.range = 26.0
			d.damage = 0.85
			d.cooldown = 1.05
			d.defense = 1.45
			d.trail_color = Color(0.5, 0.75, 0.95, 1.0)
			d.trail_width = 2.4
		WEAPON_BOW:
			d.weapon_name = "Bow"
			d.attack_kind = WeaponData.AttackKind.RANGED
			d.range = 90.0
			d.damage = 0.92
			d.cooldown = 1.2
			d.defense = 0.65
			d.projectile_speed = 520.0
			d.trail_color = Color(0.78, 0.62, 0.18, 1.0)
			d.trail_width = 2.0
		WEAPON_JAVELIN:
			d.weapon_name = "Javelin"
			d.attack_kind = WeaponData.AttackKind.RANGED
			d.range = 66.0
			d.damage = 1.25
			d.cooldown = 1.55
			d.defense = 0.78
			d.projectile_speed = 430.0
			d.trail_color = Color(0.9, 0.84, 0.55, 1.0)
			d.trail_width = 2.6
		_:
			d.weapon_name = "Spear"
			d.attack_kind = WeaponData.AttackKind.MELEE
			d.range = 34.0
			d.damage = 1.0
			d.cooldown = 1.4
			d.defense = 1.0
			d.trail_color = Color(0.82, 0.76, 0.42, 1.0)
			d.trail_width = 2.2
	return d


func _on_upgrade_pressed(item: Dictionary, buy_button: Button, rank_label: Label, cost_label: Label, row_panel: PanelContainer) -> void:
	var id: String = String(item["id"])
	var rank: int = int(_upgrade_ranks.get(id, 0))
	var max_rank: int = _upgrade_max_rank(item)
	if rank >= max_rank:
		buy_button.disabled = true
		buy_button.text = "Maxed"
		return
	var cost: Dictionary = _upgrade_cost_for_rank(item, rank)
	if not _can_afford(cost):
		_pulse_row(row_panel, Color(0.42, 0.18, 0.18, 0.95))
		return

	_spend_cost(cost)
	_purchased_upgrades[id] = true
	rank += 1
	_upgrade_ranks[id] = rank
	_apply_upgrade_effect(id)
	rank_label.text = _upgrade_rank_text(item)
	if rank >= max_rank:
		buy_button.disabled = true
		buy_button.text = "Maxed"
	else:
		cost_label.text = _cost_to_string(_upgrade_cost_for_rank(item, rank))
	_upgrade_vfx_system.spawn_burst(_target, _upgrade_color_for(id))
	_spawn_floating_text(_target, _upgrade_label_for(id) + " R" + str(rank), _upgrade_color_for(id))
	_kick_camera(7.0)
	_pulse_row(row_panel, Color(0.16, 0.34, 0.22, 0.96))


func _on_building_pressed(id: String, cost: Dictionary, row_panel: PanelContainer) -> void:
	if not _can_afford(cost):
		_pulse_row(row_panel, Color(0.42, 0.18, 0.18, 0.95))
		return
	var was_scouting_unlocked: bool = _scouting_unlocked()
	_spend_cost(cost)
	_buildings[id] = int(_buildings[id]) + 1
	if id == "house":
		_place_house_near_target()
		_recompute_homes()
	elif id == "manor":
		_place_manor_near_target()
		_recompute_homes()
	elif id in ["sawmill", "quarry", "workshop", "storehouse", "armory", "scout_lodge"]:
		_place_building_near_target(id)
	if id == "scout_lodge":
		_spawn_floating_text(_tile_center(_camp_tile), "Scouting unlocked", Color(0.58, 0.86, 1.0, 1.0))
		_clamp_job_counts()
		if not was_scouting_unlocked:
			_try_spawn_poi()
	_mark_settler_weapons_dirty()
	_upgrade_vfx_system.spawn_burst(_target, Color(0.7, 0.85, 1.0, 1.0))
	_spawn_floating_text(_target, "+%s" % id.capitalize(), Color(0.7, 0.85, 1.0, 1.0))
	_kick_camera(5.0)
	_pulse_row(row_panel, Color(0.17, 0.27, 0.37, 0.96))


func _on_population_action_pressed(action_id: String, cost: Dictionary, row_panel: PanelContainer) -> void:
	if not _can_afford(cost):
		_pulse_row(row_panel, Color(0.42, 0.18, 0.18, 0.95))
		return

	if action_id == "recruit":
		if _agents.get_agent_count() >= _housing_capacity():
			_pulse_row(row_panel, Color(0.38, 0.2, 0.1, 0.95))
			_spawn_floating_text(_target, "Need housing", Color(1.0, 0.68, 0.3, 1.0))
			return
		var old_count: int = _agents.get_agent_count()
		_spend_cost(cost)
		_agents.add_agents(1, _tile_center(_camp_tile))
		_recompute_homes()
		_clamp_job_counts()
		_sync_agent_tracking()
		_record_agent_action(old_count, "Recruited into the village")
		_spawn_floating_text(_target, "+1 Settler", Color(0.65, 0.95, 1.0, 1.0))
		_upgrade_vfx_system.spawn_burst(_target, Color(0.65, 0.95, 1.0, 1.0))
		_kick_camera(6.0)
		_pulse_row(row_panel, Color(0.15, 0.3, 0.34, 0.96))
		return

	if action_id == "house":
		_spend_cost(cost)
		_buildings["house"] = int(_buildings["house"]) + 1
		_place_house_near_target()
		_recompute_homes()
		_mark_settler_weapons_dirty()
		_spawn_floating_text(_target, "+2 Housing", Color(0.95, 0.87, 0.45, 1.0))
		_upgrade_vfx_system.spawn_burst(_target, Color(0.95, 0.87, 0.45, 1.0))
		_kick_camera(5.0)
		_pulse_row(row_panel, Color(0.3, 0.27, 0.14, 0.96))


func _change_job_count(job_key: String, delta: int) -> void:
	if job_key == "scout" and not _scouting_unlocked():
		_spawn_floating_text(_tile_center(_camp_tile), "Build Scout Lodge first", Color(0.58, 0.86, 1.0, 1.0))
		return
	if job_key == "scout" and delta > 0 and int(_job_counts["scout"]) >= _scout_job_cap():
		_spawn_floating_text(_tile_center(_camp_tile), "Scout cap reached (expand support structures)", Color(0.58, 0.86, 1.0, 1.0))
		return
	var val: int = int(_job_counts[job_key]) + delta
	if delta > 0:
		var total_assigned: int = int(_job_counts["farm"]) + int(_job_counts["lumber"]) + int(_job_counts["stone"]) + int(_job_counts["hunt"]) + int(_job_counts.get("scout", 0))
		if total_assigned >= _agents.get_agent_count():
			if not _reassign_one_to(job_key):
				return
	_job_counts[job_key] = maxi(0, val)
	_clamp_job_counts()
	_apply_auto_tool_assignments()
	_mark_settler_weapons_dirty()


func _reassign_one_to(target_job: String) -> bool:
	var keys: Array[String] = ["farm", "lumber", "stone", "hunt", "scout"]
	var names := {
		"farm": "Farm",
		"lumber": "Lumber",
		"stone": "Stone",
		"hunt": "Hunt",
		"scout": "Scout",
	}
	var n: int = keys.size()
	for off in n:
		var idx: int = (_job_reassign_cursor + off) % n
		var donor: String = keys[idx]
		if donor == target_job:
			continue
		if int(_job_counts[donor]) > 0:
			_job_counts[donor] = int(_job_counts[donor]) - 1
			_spawn_floating_text(
				_tile_center(_camp_tile),
				"Reassigned %s -> %s" % [String(names[donor]), String(names[target_job])],
				Color(0.62, 0.9, 1.0, 1.0)
			)
			_job_reassign_cursor = (idx + 1) % n
			return true
	return false


func _clear_resource_on_build_tile(tile: Vector2i) -> void:
	var id: int = _tile_id(tile)
	var key: String = _tile_key(tile)
	if not _resource_remaining_id.has(id) and not _resource_remaining.has(key) and _resource_type_at(tile) == RES_NONE:
		return
	_set_resource_left(tile, 0.0)


func _place_building_near_target(id: String) -> void:
	var tile_array: Array[Vector2i]
	match id:
		"sawmill": tile_array = _sawmill_tiles
		"quarry": tile_array = _quarry_tiles
		"workshop": tile_array = _workshop_tiles
		"storehouse": tile_array = _storehouse_tiles
		"armory": tile_array = _armory_tiles
		"scout_lodge": tile_array = _scout_lodge_tiles
		_: return
	var base := _world_to_tile(_target)
	for radius in range(1, 14):
		for y in range(base.y - radius, base.y + radius + 1):
			for x in range(base.x - radius, base.x + radius + 1):
				if abs(x - base.x) != radius and abs(y - base.y) != radius:
					continue
				var tile := Vector2i(x, y)
				if _is_structure_tile_occupied(tile):
					continue
				tile_array.append(tile)
				_clear_resource_on_build_tile(tile)
				_reveal_around_tile(tile, 3)
				return

func _place_house_near_target() -> void:
	var base := _world_to_tile(_target)
	for radius in range(1, 12):
		for y in range(base.y - radius, base.y + radius + 1):
			for x in range(base.x - radius, base.x + radius + 1):
				if abs(x - base.x) != radius and abs(y - base.y) != radius:
					continue
				var tile := Vector2i(x, y)
				if _is_structure_tile_occupied(tile):
					continue
				_house_tiles.append(tile)
				_clear_resource_on_build_tile(tile)
				_reveal_around_tile(tile, 3)
				return


func _place_manor_near_target() -> void:
	var base := _world_to_tile(_target)
	for radius in range(1, 16):
		for y in range(base.y - radius, base.y + radius + 1):
			for x in range(base.x - radius, base.x + radius + 1):
				if abs(x - base.x) != radius and abs(y - base.y) != radius:
					continue
				var origin := Vector2i(x, y)
				if not _can_place_manor_at(origin):
					continue
				_manor_origins.append(origin)
				for dx in MANOR_FOOTPRINT:
					for dy in MANOR_FOOTPRINT:
						var tile: Vector2i = origin + Vector2i(dx, dy)
						_clear_resource_on_build_tile(tile)
						_reveal_around_tile(tile, 3)
				return


func _can_place_manor_at(origin: Vector2i) -> bool:
	for dx in MANOR_FOOTPRINT:
		for dy in MANOR_FOOTPRINT:
			if _is_structure_tile_occupied(origin + Vector2i(dx, dy)):
				return false
	return true


func _apply_upgrade_effect(id: String) -> void:
	match id:
		"vol_lumber":
			_tree_yield_mult *= 1.42
		"vol_stone":
			_stone_yield_mult *= 1.42
		"vol_geology":
			_stone_yield_mult *= 1.30
			_metal_yield_mult *= 1.22
			if not _metal_mining_unlocked:
				_metal_mining_unlocked = true
				_spawn_floating_text(_target, "Metal veins discovered", Color(0.62, 0.72, 0.95, 1.0))
		"vol_forage":
			_food_gather_mult *= 1.36
		"vol_hoard":
			_storehouse_mult *= 1.84
			_happiness_gain_mult *= 0.92
		"eff_speed":
			_agents.tiles_per_second *= 1.21
		"eff_convert":
			_convert_mult *= 1.60
		"eff_quarry_ops":
			_quarry_passive_mult *= 1.72
		"eff_hearth":
			_night_cooking_unlocked = true
			_spawn_floating_text(_tile_center(_camp_tile), "Camp kitchens ready", Color(0.95, 0.74, 0.3, 1.0))
		"eff_ration":
			_food_consume_mult *= 0.76
			_happiness_loss_mult *= 1.12
		"eff_campfire":
			_happiness_gain_mult *= 1.48
		"spec_forestry":
			_buildings["sawmill"] = int(_buildings["sawmill"]) + 1
		"spec_masonry":
			_buildings["quarry"] = int(_buildings["quarry"]) + 1
		"spec_hunting":
			_hunting_yield_mult *= 1.30
		"spec_bravado":
			_happiness_gain_mult *= 1.25
			_food_consume_mult *= 1.18
		"vision_lenses":
			_vision_radius += 1
		"vision_tower_net":
			_auto_watchtowers = true
			_add_watchtower_at_world(_target)
		"vision_tower_range":
			_watchtower_radius += 2
			for w in _watchtowers:
				_reveal_around_tile(w, _watchtower_radius)
		"vision_nightwatch":
			_night_overlay_reduction = minf(0.2, _night_overlay_reduction + 0.05)
		"def_spears":
			_settler_defense_mult *= 1.12
		"def_horns":
			_wolf_raid_size_mult *= 0.82
		"def_training":
			_happiness_loss_mult *= 0.84
		"cmb_armory":
			_buildings["armory"] = int(_buildings["armory"]) + 1
			_place_building_near_target("armory")
		"cmb_shields":
			_weapon_shield_unlocked = true
			_settler_defense_mult *= 1.08
		"cmb_bowcraft":
			_weapon_bow_unlocked = true
			_ranged_range_mult *= 1.14
		"cmb_javelin":
			_weapon_javelin_unlocked = true
			_ranged_damage_mult *= 1.12
		"cmb_steel":
			_melee_damage_mult *= 1.19
		"cmb_drills":
			_weapon_cluster_strength = minf(0.42, _weapon_cluster_strength + 0.05)
		"scout_training":
			_poi_discovery_radius *= 1.19
		"scout_survey":
			_poi_spawn_interval_mult *= 0.86
		"scout_beacons":
			_poi_discovery_radius *= 1.10
		"scout_salvage":
			_poi_reward_mult *= 1.21
		_:
			pass
	_mark_settler_weapons_dirty()


func _can_afford(cost: Dictionary) -> bool:
	for key in cost.keys():
		if _resources[key] < float(cost[key]):
			return false
	return true


func _spend_cost(cost: Dictionary) -> void:
	for key in cost.keys():
		_resources[key] -= float(cost[key])


func _resource_cost_icon(key: String) -> String:
	return _resource_icon(key)


func _cost_to_string(cost: Dictionary) -> String:
	var parts: Array[String] = []
	for key in ["food", "lumber", "stone", "metal_ore", "metal"]:
		if cost.has(key):
			parts.append("%s %d" % [_resource_cost_icon(String(key)), int(cost[key])])
	return "Cost: " + ", ".join(parts)


func _building_effect_text(id: String) -> String:
	match id:
		"house":
			return "Adds 2 housing slots (1 tile)"
		"manor":
			return "Adds 6 housing slots (2x2 tiles)"
		"sawmill":
			return "Trees yield +1 each harvest"
		"quarry":
			return "Stone yield +1 each harvest"
		"workshop":
			return "Smelts ore into metal"
		"storehouse":
			return "Adds passive logistics trickle"
		"armory":
			return "Improves weapon logistics and squad loadouts"
		"scout_lodge":
			return "Unlocks Scout job and expedition routing"
		_:
			return ""


func _scouting_unlocked() -> bool:
	return int(_buildings.get("scout_lodge", 0)) > 0


func _scouting_structure_score() -> float:
	if not _scouting_unlocked():
		return 0.0
	var score: float = 1.2 * float(int(_buildings.get("scout_lodge", 0)))
	score += 0.55 * float(int(_buildings.get("sawmill", 0)))
	score += 0.55 * float(int(_buildings.get("quarry", 0)))
	score += 0.8 * float(int(_buildings.get("workshop", 0)))
	score += 0.9 * float(int(_buildings.get("storehouse", 0)))
	score += 0.85 * float(int(_buildings.get("armory", 0)))
	return score


func _scout_job_cap() -> int:
	if not _scouting_unlocked():
		return 0
	var cap: int = 1 + int(floor(_scouting_structure_score() / 2.25))
	return clampi(cap, 1, 4)


func _active_scout_count_excluding(exclude_index: int = -1) -> int:
	var count: int = 0
	for i in _agents.get_agent_count():
		if i == exclude_index:
			continue
		if _job_for_settler(i) == JOB_SCOUT:
			count += 1
	return count


func _effective_max_poi_sites() -> int:
	if not _scouting_unlocked():
		return 0
	var extra: int = int(floor(_scouting_structure_score() / 3.0))
	return clampi(1 + extra, 1, min(4, _max_poi_sites + 2))


func _scouting_spawn_interval_seconds() -> float:
	if not _scouting_unlocked():
		return 9999.0
	var base: float = 88.0 * _poi_spawn_interval_mult
	var score: float = _scouting_structure_score()
	var ramp: float = clampf(1.5 - score * 0.08, 0.82, 1.5)
	return maxf(34.0, base * ramp)


func _effective_poi_reward_mult() -> float:
	if not _scouting_unlocked():
		return 0.0
	var tier_scale: float = clampf(0.7 + _scouting_structure_score() * 0.06, 0.7, 1.16)
	return _poi_reward_mult * tier_scale


func _tile_key(tile: Vector2i) -> String:
	return "%d:%d" % [tile.x, tile.y]


func _tile_id(tile: Vector2i) -> int:
	return (int(tile.x) << 32) ^ (int(tile.y) & 0xffffffff)


func _sync_resource_remaining_ids() -> void:
	_resource_remaining_id.clear()
	for key_v in _resource_remaining.keys():
		var key: String = String(key_v)
		var parts: PackedStringArray = key.split(":")
		if parts.size() != 2:
			continue
		var tile := Vector2i(int(parts[0]), int(parts[1]))
		_resource_remaining_id[_tile_id(tile)] = _resource_remaining[key]


func _sync_resource_claim_ids() -> void:
	_resource_mgr.resource_claims_id.clear()
	for key_v in _resource_claims.keys():
		var key: String = String(key_v)
		var parts: PackedStringArray = key.split(":")
		if parts.size() != 2:
			continue
		var tile := Vector2i(int(parts[0]), int(parts[1]))
		_resource_mgr.resource_claims_id[_tile_id(tile)] = _resource_claims[key]


func _init_settler_decision_run_state() -> void:
	_settler_decision_run_state = {
		"invalid_tile": Vector2i(-9999, -9999),
		"think_executing": THINK_EXECUTING,
		"think_thinking": THINK_THINKING,
		"think_blocked": THINK_BLOCKED,
		"job_farm": JOB_FARM,
		"job_lumber": JOB_LUMBER,
		"job_stone": JOB_STONE,
		"job_hunt": JOB_HUNT,
		"job_scout": JOB_SCOUT,
		"res_apple": RES_APPLE,
		"res_berry_blue": RES_BERRY_BLUE,
		"res_berry_rasp": RES_BERRY_RASP,
		"res_berry_black": RES_BERRY_BLACK,
		"res_tree": RES_TREE,
		"res_stone": RES_STONE,
		"res_metal": RES_METAL,
		"food_min_harvest": FOOD_MIN_HARVEST,
		"settler_arrival_rethink_distance_px": settler_arrival_rethink_distance_px,
		"settler_stuck_rethink_sec": settler_stuck_rethink_sec,
		"settler_min_progress_px": settler_min_progress_px,
		"offscreen_decision_throttle_enabled": offscreen_decision_throttle_enabled,
		"offscreen_decision_stride": maxi(1, offscreen_decision_stride),
		"offscreen_night_planning_stride": maxi(1, offscreen_night_planning_stride),
		"cb_think_jitter": Callable(self, "_think_jitter"),
		"cb_current_poi_target_index": Callable(self, "_current_poi_target_index"),
		"cb_tile_center": Callable(self, "_tile_center"),
		"cb_select_poi_scout": Callable(self, "_select_poi_scout"),
		"cb_update_day_plan_for_settler": Callable(self, "_update_day_plan_for_settler"),
		"cb_world_to_tile": Callable(self, "_world_to_tile"),
		"cb_job_for_settler": Callable(self, "_job_for_settler"),
		"cb_segment_world_target": Callable(self, "_segment_world_target"),
		"cb_settler_wander_target": Callable(self, "_settler_wander_target"),
		"cb_home_center_for_settler": Callable(self, "_home_center_for_settler"),
		"cb_settler_has_home": Callable(self, "_settler_has_home"),
		"cb_schedule_next_think": Callable(self, "_schedule_next_think"),
		"cb_set_next_think_time": Callable(self, "_set_settler_next_think_time"),
		"cb_release_resource_claim": Callable(self, "_release_resource_claim"),
		"cb_record_agent_action": Callable(self, "_record_agent_action"),
		"cb_log_global_settler_event": Callable(self, "_log_global_settler_event"),
		"cb_resource_type_at": Callable(self, "_resource_type_at"),
		"cb_resource_left": Callable(self, "_resource_left"),
		"cb_is_day_plan_valid": Callable(self, "_is_day_plan_valid"),
		"cb_nearest_food_tile": Callable(self, "_nearest_food_tile"),
		"cb_try_claim_resource_tile": Callable(self, "_try_claim_resource_tile"),
		"cb_segment_target_toward": Callable(self, "_segment_target_toward"),
		"cb_nearest_wildlife_pos": Callable(self, "_nearest_wildlife_pos"),
		"cb_nearest_resource_tile": Callable(self, "_nearest_resource_tile"),
		"cb_nearest_mining_tile": Callable(self, "_nearest_mining_tile"),
	}


func _ensure_settler_candidate_seen(count: int) -> void:
	if _settler_candidate_seen.size() != count:
		_settler_candidate_seen.resize(count)


func _resource_amount_at(tile: Vector2i, res_type: int, is_food: bool) -> float:
	var id: int = _tile_id(tile)
	var amount_type: int = res_type
	if is_food:
		if not _resource_type_cache.has(id):
			return 0.0
		amount_type = int(_resource_type_cache[id])
		if amount_type != RES_APPLE and amount_type != RES_BERRY_BLUE and amount_type != RES_BERRY_RASP and amount_type != RES_BERRY_BLACK:
			return 0.0
	if _resource_remaining_id.has(id):
		return float(_resource_remaining_id[id])
	return _resource_initial_amount(tile, amount_type)


func _nearest_candidate_passes(tile: Vector2i, d_sq: int, max_d_sq: int, best_d_sq: int, claimant_index: int, res_type: int, min_amount: float, is_food: bool) -> bool:
	if d_sq > max_d_sq or d_sq >= best_d_sq:
		return false
	if _resource_amount_at(tile, res_type, is_food) < min_amount:
		return false
	if claimant_index >= 0 and _is_tile_claimed_by_other(tile, claimant_index):
		return false
	return true


func _rebuild_resource_indices() -> void:
	_resource_food_tiles.clear()
	_resource_tree_tiles.clear()
	_resource_stone_tiles.clear()
	_resource_metal_tiles.clear()
	_resource_food_pos.clear()
	_resource_tree_pos.clear()
	_resource_stone_pos.clear()
	_resource_metal_pos.clear()
	_resource_food_chunk_tiles.clear()
	_resource_tree_chunk_tiles.clear()
	_resource_stone_chunk_tiles.clear()
	_resource_metal_chunk_tiles.clear()
	_resource_food_tile_chunk.clear()
	_resource_tree_tile_chunk.clear()
	_resource_stone_tile_chunk.clear()
	_resource_metal_tile_chunk.clear()
	for key_v in _explored.keys():
		var key: String = String(key_v)
		var parts: Array = key.split(":")
		if parts.size() != 2:
			continue
		var tile := Vector2i(int(parts[0]), int(parts[1]))
		_resource_index_sync_tile(tile)


func _is_explored(tile: Vector2i) -> bool:
	return _explored.has(_tile_key(tile))


func _reveal_around_world(world_pos: Vector2, radius: int) -> void:
	_reveal_around_tile(_world_to_tile(world_pos), radius)


func _reveal_around_tile(center: Vector2i, radius: int) -> void:
	for oy in range(-radius, radius + 1):
		for ox in range(-radius, radius + 1):
			if ox * ox + oy * oy > radius * radius:
				continue
			var t := Vector2i(center.x + ox, center.y + oy)
			var key: String = _tile_key(t)
			if not _explored.has(key):
				_explored[key] = true
				_mark_tile_dirty(t)


func _resource_index_add_tile(tile: Vector2i, list: Array[Vector2i], pos_map: Dictionary) -> void:
	var id: int = _tile_id(tile)
	if pos_map.has(id):
		return
	pos_map[id] = list.size()
	list.append(tile)


func _resource_chunk_index_add_tile(tile: Vector2i, chunk_tiles_map: Dictionary, tile_chunk_map: Dictionary) -> void:
	var id: int = _tile_id(tile)
	if tile_chunk_map.has(id):
		return
	var chunk: Vector2i = _chunk_for_tile(tile)
	var key: String = _world_chunk_key(chunk)
	if not chunk_tiles_map.has(key):
		chunk_tiles_map[key] = []
	var list: Array = chunk_tiles_map[key]
	list.append(tile)
	chunk_tiles_map[key] = list
	tile_chunk_map[id] = key


func _resource_index_remove_tile(tile: Vector2i, list: Array[Vector2i], pos_map: Dictionary) -> void:
	var id: int = _tile_id(tile)
	if not pos_map.has(id):
		return
	var idx: int = int(pos_map[id])
	var last_idx: int = list.size() - 1
	if idx < 0 or idx > last_idx:
		pos_map.erase(id)
		return
	if idx != last_idx:
		var moved: Vector2i = list[last_idx]
		list[idx] = moved
		pos_map[_tile_id(moved)] = idx
	list.remove_at(last_idx)
	pos_map.erase(id)


func _resource_chunk_index_remove_tile(tile: Vector2i, chunk_tiles_map: Dictionary, tile_chunk_map: Dictionary) -> void:
	var id: int = _tile_id(tile)
	if not tile_chunk_map.has(id):
		return
	var key: String = String(tile_chunk_map[id])
	if not chunk_tiles_map.has(key):
		tile_chunk_map.erase(id)
		return
	var list: Array = chunk_tiles_map[key]
	for i in range(list.size() - 1, -1, -1):
		if list[i] == tile:
			list.remove_at(i)
			break
	if list.is_empty():
		chunk_tiles_map.erase(key)
	else:
		chunk_tiles_map[key] = list
	tile_chunk_map.erase(id)


func _resource_index_remove_all(tile: Vector2i) -> void:
	_resource_index_remove_tile(tile, _resource_food_tiles, _resource_food_pos)
	_resource_index_remove_tile(tile, _resource_tree_tiles, _resource_tree_pos)
	_resource_index_remove_tile(tile, _resource_stone_tiles, _resource_stone_pos)
	_resource_index_remove_tile(tile, _resource_metal_tiles, _resource_metal_pos)
	_resource_chunk_index_remove_tile(tile, _resource_food_chunk_tiles, _resource_food_tile_chunk)
	_resource_chunk_index_remove_tile(tile, _resource_tree_chunk_tiles, _resource_tree_tile_chunk)
	_resource_chunk_index_remove_tile(tile, _resource_stone_chunk_tiles, _resource_stone_tile_chunk)
	_resource_chunk_index_remove_tile(tile, _resource_metal_chunk_tiles, _resource_metal_tile_chunk)


func _resource_index_sync_tile(tile: Vector2i) -> void:
	_resource_index_remove_all(tile)
	if not _is_explored(tile):
		return
	var rt: int = _resource_type_at(tile)
	if rt == RES_NONE:
		return
	if _resource_left(tile, rt) <= 0.0:
		return
	if rt == RES_TREE:
		_resource_index_add_tile(tile, _resource_tree_tiles, _resource_tree_pos)
		_resource_chunk_index_add_tile(tile, _resource_tree_chunk_tiles, _resource_tree_tile_chunk)
	elif rt == RES_STONE:
		_resource_index_add_tile(tile, _resource_stone_tiles, _resource_stone_pos)
		_resource_chunk_index_add_tile(tile, _resource_stone_chunk_tiles, _resource_stone_tile_chunk)
	elif rt == RES_METAL:
		_resource_index_add_tile(tile, _resource_metal_tiles, _resource_metal_pos)
		_resource_chunk_index_add_tile(tile, _resource_metal_chunk_tiles, _resource_metal_tile_chunk)
	elif rt == RES_APPLE or rt == RES_BERRY_BLUE or rt == RES_BERRY_RASP or rt == RES_BERRY_BLACK:
		_resource_index_add_tile(tile, _resource_food_tiles, _resource_food_pos)
		_resource_chunk_index_add_tile(tile, _resource_food_chunk_tiles, _resource_food_tile_chunk)


func _add_watchtower_at_world(world_pos: Vector2) -> void:
	var t := _world_to_tile(world_pos)
	if _watchtowers.has(t):
		return
	_watchtowers.append(t)
	if _watchtowers.size() > _max_watchtowers:
		_watchtowers.remove_at(0)
	_reveal_around_tile(t, _watchtower_radius)


func _world_to_tile(world_pos: Vector2) -> Vector2i:
	return Vector2i(floori(world_pos.x / TILE_SIZE), floori(world_pos.y / TILE_SIZE))


func _tile_center(tile: Vector2i) -> Vector2:
	return Vector2((tile.x + 0.5) * TILE_SIZE, (tile.y + 0.5) * TILE_SIZE)


func _value_noise(x: float, y: float, seed: int) -> float:
	var ix: int = floori(x)
	var iy: int = floori(y)
	var tx: float = x - float(ix)
	var ty: float = y - float(iy)
	var sx: float = tx * tx * (3.0 - 2.0 * tx)
	var sy: float = ty * ty * (3.0 - 2.0 * ty)
	var a: float = _rand01(ix, iy, seed)
	var b: float = _rand01(ix + 1, iy, seed)
	var c: float = _rand01(ix, iy + 1, seed)
	var d: float = _rand01(ix + 1, iy + 1, seed)
	var ab: float = lerpf(a, b, sx)
	var cd: float = lerpf(c, d, sx)
	return lerpf(ab, cd, sy)


func _biome_at(tile: Vector2i) -> int:
	# 10x larger, warped biome domains for natural curved boundaries.
	var sx: float = float(tile.x) / 220.0
	var sy: float = float(tile.y) / 220.0
	var warp_x: float = (_value_noise(sx * 0.8, sy * 0.8, _world_seed + 901) - 0.5) * 1.8
	var warp_y: float = (_value_noise(sx * 0.8, sy * 0.8, _world_seed + 1201) - 0.5) * 1.8
	var wx: float = sx + warp_x
	var wy: float = sy + warp_y
	var elevation: float = _value_noise(wx * 1.1, wy * 1.1, _world_seed + 17)
	var moisture: float = (
		_value_noise(wx * 1.5 + 13.0, wy * 1.5 - 7.0, _world_seed + 33) * 0.7
		+ _value_noise(wx * 3.1 - 4.0, wy * 3.1 + 9.0, _world_seed + 57) * 0.3
	)
	if moisture > 0.76 and elevation < 0.62:
		return 5  # berry thicket biome
	if elevation > 0.82:
		return 3  # mountain
	if elevation < 0.3:
		return 0  # plains
	if moisture < 0.24:
		return 4  # marsh
	if moisture > 0.58:
		return 1  # forest
	return 2  # hills


func _biome_color(biome: int) -> Color:
	match biome:
		0:
			return Color(0.18, 0.27, 0.16, 1.0)
		1:
			return Color(0.11, 0.24, 0.12, 1.0)
		2:
			return Color(0.2, 0.23, 0.16, 1.0)
		3:
			return Color(0.22, 0.22, 0.23, 1.0)
		4:
			return Color(0.15, 0.2, 0.18, 1.0)
		_:
			return Color(0.29, 0.19, 0.26, 1.0)


func _resource_type_at(tile: Vector2i) -> int:
	var id: int = _tile_id(tile)
	if _resource_type_cache.has(id):
		return int(_resource_type_cache[id])
	var biome: int = _biome_at(tile)
	var r: float = _rand01(tile.x, tile.y, _world_seed + 17)
	var rf: float = _rand01(tile.x, tile.y, _world_seed + 333)  # food subtype roll
	var ore_cluster: float = _value_noise(float(tile.x) / 7.0, float(tile.y) / 7.0, _world_seed + 611)
	var typ: int = RES_NONE
	if biome == 1:  # forest
		if r < 0.50:
			if rf < 0.15:
				typ = RES_APPLE
			else:
				typ = RES_TREE
		elif r < 0.65:
			typ = RES_BERRY_BLACK
		else:
			typ = RES_NONE
	elif biome == 0:  # plains
		if r < 0.13:
			typ = RES_APPLE if rf < 0.25 else RES_TREE
		elif r < 0.22:
			typ = RES_BERRY_RASP  # raspberry on plains
		elif r > 0.93:
			typ = RES_STONE
		else:
			typ = RES_NONE
	elif biome == 2:  # hills
		if r < 0.18:
			typ = RES_TREE
		elif r < 0.28:
			typ = RES_BERRY_RASP if rf < 0.6 else RES_BERRY_BLACK
		elif r < 0.62:
			if ore_cluster > 0.84 and r > 0.43:
				typ = RES_METAL
			else:
				typ = RES_STONE
		else:
			typ = RES_NONE
	elif biome == 3:  # mountain
		if r < 0.74:
			if ore_cluster > 0.79 and r > 0.52:
				typ = RES_METAL
			else:
				typ = RES_STONE
		else:
			typ = RES_NONE
	elif biome == 4:  # marsh
		if r < 0.15:
			typ = RES_TREE
		elif r < 0.35:
			typ = RES_BERRY_BLUE  # blueberries love marsh
		else:
			typ = RES_NONE
	elif biome == 5:  # berry thicket
		if r < 0.18:
			typ = RES_TREE if rf < 0.7 else RES_APPLE
		elif r < 0.83:
			if rf < 0.33:
				typ = RES_BERRY_BLUE
			elif rf < 0.66:
				typ = RES_BERRY_RASP
			else:
				typ = RES_BERRY_BLACK
		elif r < 0.9:
			typ = RES_STONE
		else:
			typ = RES_NONE
	else:
		typ = RES_NONE
	_resource_type_cache[id] = typ
	return typ


func _resource_initial_amount(tile: Vector2i, res_type: int) -> float:
	var cache_key: String = "%d:%d" % [_tile_id(tile), res_type]
	if _resource_initial_amount_cache.has(cache_key):
		return float(_resource_initial_amount_cache[cache_key])
	var r: float = _rand01(tile.x, tile.y, _world_seed + 991)
	var durability_mult: float = maxf(1.0, resource_node_yield_mult) * _resource_distance_multiplier(tile)
	var amount: float = 0.0
	if res_type == RES_TREE:
		amount = (4.0 + floor(r * 7.0)) * durability_mult
	elif res_type == RES_STONE:
		amount = (5.0 + floor(r * 9.0)) * durability_mult
	elif res_type == RES_METAL:
		amount = (2.0 + floor(r * 4.0)) * durability_mult * 0.7
	elif res_type == RES_APPLE:
		amount = (3.0 + floor(r * 5.0)) * durability_mult  # regrows — handled by slow respawn
	elif res_type == RES_BERRY_BLUE or res_type == RES_BERRY_RASP or res_type == RES_BERRY_BLACK:
		amount = (3.0 + floor(r * 5.0)) * durability_mult
	else:
		amount = 0.0
	_resource_initial_amount_cache[cache_key] = amount
	return amount


func _resource_distance_multiplier(tile: Vector2i) -> float:
	var dist_tiles: float = float(tile.distance_to(_camp_tile))
	return 1.0 + minf(3.0, dist_tiles / 35.0)


func _resource_left(tile: Vector2i, res_type: int) -> float:
	var id: int = _tile_id(tile)
	if _resource_remaining_id.has(id):
		return float(_resource_remaining_id[id])
	var key: String = _tile_key(tile)
	if _resource_remaining.has(key):
		var amount: float = float(_resource_remaining[key])
		_resource_remaining_id[id] = amount
		return amount
	return _resource_initial_amount(tile, res_type)


func _set_resource_left(tile: Vector2i, value: float) -> void:
	var key: String = _tile_key(tile)
	var id: int = _tile_id(tile)
	var clamped: float = maxf(0.0, value)
	_resource_remaining[key] = clamped
	if clamped > 0.0:
		_resource_remaining_id[id] = clamped
	else:
		_resource_remaining_id.erase(id)
	if clamped <= 0.0 and _resource_claims.has(key):
		var owner: int = int(_resource_claims[key])
		if _settler_resource_targets.has(owner):
			var owner_tile: Vector2i = _settler_resource_targets[owner]
			if _tile_key(owner_tile) == key:
				_settler_resource_targets.erase(owner)
				_settler_day_plan_targets.erase(owner)
				_settler_day_plan_job.erase(owner)
		_resource_claims.erase(key)
		_resource_mgr.resource_claims_id.erase(id)
	if clamped <= 0.0:
		var plan_keys: Array = _settler_day_plan_targets.keys()
		for idx_v in plan_keys:
			var idx: int = int(idx_v)
			var planned_tile: Vector2i = _settler_day_plan_targets[idx]
			if _tile_key(planned_tile) == key:
				_settler_day_plan_targets.erase(idx)
				_settler_day_plan_job.erase(idx)
	_queue_resource_tile_reload(tile)


func _rand01(x: int, y: int, seed: int) -> float:
	var h: int = x * 374761393 + y * 668265263 + seed * 982451653
	h = h ^ (h >> 13)
	h = h * 1274126177
	h = h ^ (h >> 16)
	return float(h & 0x7fffffff) / 2147483647.0


func _spawn_collect_feedback(pos: Vector2, text: String, color: Color) -> void:
	_spawn_floating_text(pos, text, color, 0.5)
	_collection_particles_system.spawn_burst(pos, color, _rng, 6)


func _pulse_row(row_panel: PanelContainer, tint: Color) -> void:
	var style: StyleBoxFlat = row_panel.get_theme_stylebox("panel").duplicate()
	var base_color := style.bg_color
	style.bg_color = tint
	row_panel.add_theme_stylebox_override("panel", style)
	var tw := create_tween()
	tw.set_trans(Tween.TRANS_CUBIC)
	tw.set_ease(Tween.EASE_OUT)
	tw.tween_method(func(v: Color): style.bg_color = v, tint, base_color, 0.34)


func _spawn_floating_text(pos: Vector2, text: String, color: Color, scale: float = 1.0) -> void:
	_floating_text_system.spawn(pos, text, color, scale)


func _kick_camera(amount: float) -> void:
	var dir := Vector2(_rng.randf_range(-1.0, 1.0), _rng.randf_range(-1.0, 1.0)).normalized()
	_camera_kick += dir * amount


func _update_settler_combat_budgeted(delta: float) -> void:
	var tick_sec: float = clampf(settler_combat_tick_sec, 0.05, 0.5)
	_settler_combat_tick_accum += delta
	var steps: int = mini(3, int(floor(_settler_combat_tick_accum / tick_sec)))
	if steps <= 0:
		return
	for _i in steps:
		_update_settler_combat(tick_sec)
		_settler_combat_tick_accum -= tick_sec
	_settler_combat_tick_accum = clampf(_settler_combat_tick_accum, 0.0, tick_sec)


func _update_settler_combat(delta: float) -> void:
	var result: Dictionary = _combat_system.run({
		"delta": delta,
		"is_night": _is_night(),
		"wildlife": _wildlife,
		"attack_cooldowns": _settler_attack_cooldowns,
		"hunter_attack_anims": _hunter_attack_anims,
		"combat_sfx_events": [],
		"settler_combat_damage_mult": _settler_combat_damage_mult,
		"settler_attack_speed_mult": _settler_attack_speed_mult,
		"melee_damage_mult": _melee_damage_mult,
		"ranged_damage_mult": _ranged_damage_mult,
		"animal_wolf": ANIMAL_WOLF,
		"animal_bear": ANIMAL_BEAR,
		"animal_deer": ANIMAL_DEER,
		"weapon_spear": WEAPON_SPEAR,
		"job_hunt": JOB_HUNT,
		"max_attackers_per_target": maxi(1, max_attackers_per_wildlife_target),
		"cb_is_night": Callable(self, "_is_night"),
		"cb_agent_positions": Callable(_agents, "get_agent_positions"),
		"cb_job_for_settler": Callable(self, "_job_for_settler"),
		"cb_weapon_for_settler": Callable(self, "_weapon_for_settler"),
		"cb_weapon_profile": Callable(self, "_weapon_profile"),
		"cb_tool_for_settler": Callable(self, "_tool_for_settler"),
		"cb_tool_name_for_id": Callable(self, "_tool_name_for_id"),
		"cb_tool_combat_modifiers_for_settler": Callable(self, "_tool_combat_modifiers_for_settler"),
		"cb_record_agent_action": Callable(self, "_record_combat_action"),
		"cb_weapon_name_for_id": Callable(self, "_weapon_name_for_id"),
	})
	_settler_attack_cooldowns = result["attack_cooldowns"]
	_hunter_attack_anims = result["hunter_attack_anims"]
	var sfx_events: Array = result.get("combat_sfx_events", [])
	for ev in sfx_events:
		_play_combat_sfx_at(String(ev.get("path", "")), ev.get("pos", _target))


func _play_combat_sfx_at(sound_path: String, world_pos: Vector2) -> void:
	if sound_path.is_empty():
		return
	var stream: AudioStream = null
	if _audio_stream_cache.has(sound_path):
		stream = _audio_stream_cache[sound_path]
	else:
		stream = load(sound_path)
		if stream != null:
			_audio_stream_cache[sound_path] = stream
	if stream == null:
		return
	var one_shot := AudioStreamPlayer2D.new()
	one_shot.stream = stream
	one_shot.global_position = world_pos
	one_shot.volume_db = -8.0
	one_shot.pitch_scale = _rng.randf_range(0.96, 1.04)
	add_child(one_shot)
	one_shot.finished.connect(func() -> void:
		one_shot.queue_free()
	)
	one_shot.play()


func _apply_predator_strike(strike_pos: Vector2, predator_type: int) -> void:
	var agents: PackedVector2Array = _agents.get_agent_positions()
	if agents.is_empty():
		return
	var radius: float = 24.0 if predator_type == ANIMAL_WOLF else 30.0
	var base_hit: float = 0.05 if predator_type == ANIMAL_WOLF else 0.085
	var base_lethal_chance: float = 0.065 if predator_type == ANIMAL_WOLF else 0.14
	if _wolf_raid_active:
		base_hit *= 1.0 + _combat_neglect_level() * 0.35
		base_lethal_chance *= 1.0 + _combat_neglect_level() * 0.35
	var casualties: PackedInt32Array = PackedInt32Array()
	for i in agents.size():
		var d: float = agents[i].distance_to(strike_pos)
		if d > radius:
			continue
		var defense: float = maxf(0.35, _settler_defense_for_index(i) * _tool_defense_mult_for_settler(i))
		var morale_hit: float = base_hit / defense
		if i < _settler_happiness.size():
			_settler_happiness[i] = clampf(_settler_happiness[i] - morale_hit, 0.0, 1.0)
		var lethal_chance: float = clampf(base_lethal_chance / defense, 0.01, 0.42)
		if _rng.randf() < lethal_chance:
			casualties.append(i)
	if not casualties.is_empty():
		var cause: String = "wolf attack" if predator_type == ANIMAL_WOLF else "bear attack"
		_remove_settlers_by_indices(casualties, cause, strike_pos)


func _try_raze_structure(strike_pos: Vector2, predator_type: int) -> void:
	if not _wolf_raid_active:
		return
	if _structure_raze_cooldown > 0.0:
		return
	if _razes_this_night >= _max_razes_per_night:
		return
	var neglect: float = _combat_neglect_level()
	if neglect < 0.72:
		return
	if _combat_neglect_streak < 2:
		return
	var base_chance: float = 0.055 if predator_type == ANIMAL_WOLF else 0.085
	var chance: float = base_chance + (neglect - 0.72) * 0.28 + minf(0.09, 0.03 * float(_combat_neglect_streak))
	if _rng.randf() > clampf(chance, 0.0, 0.45):
		return
	if not _raze_nearest_structure(strike_pos):
		return
	_razes_this_night += 1
	_structure_raze_cooldown = 18.0


func _raze_nearest_structure(strike_pos: Vector2) -> bool:
	var best_d: float = 1e9
	var best_type: String = ""
	var best_idx: int = -1

	for i in _sawmill_tiles.size():
		var d: float = strike_pos.distance_to(_tile_center(_sawmill_tiles[i]))
		if d < best_d:
			best_d = d
			best_type = "sawmill"
			best_idx = i
	for i in _quarry_tiles.size():
		var d: float = strike_pos.distance_to(_tile_center(_quarry_tiles[i]))
		if d < best_d:
			best_d = d
			best_type = "quarry"
			best_idx = i
	for i in _workshop_tiles.size():
		var d: float = strike_pos.distance_to(_tile_center(_workshop_tiles[i]))
		if d < best_d:
			best_d = d
			best_type = "workshop"
			best_idx = i
	for i in _storehouse_tiles.size():
		var d: float = strike_pos.distance_to(_tile_center(_storehouse_tiles[i]))
		if d < best_d:
			best_d = d
			best_type = "storehouse"
			best_idx = i
	for i in _armory_tiles.size():
		var d: float = strike_pos.distance_to(_tile_center(_armory_tiles[i]))
		if d < best_d:
			best_d = d
			best_type = "armory"
			best_idx = i
	for i in _scout_lodge_tiles.size():
		var d: float = strike_pos.distance_to(_tile_center(_scout_lodge_tiles[i]))
		if d < best_d:
			best_d = d
			best_type = "scout_lodge"
			best_idx = i
	if _house_tiles.size() > 1:
		for i in _house_tiles.size():
			var d: float = strike_pos.distance_to(_tile_center(_house_tiles[i]))
			if d < best_d:
				best_d = d
				best_type = "house"
				best_idx = i
	if _manor_origins.size() > 0:
		for i in _manor_origins.size():
			var d: float = strike_pos.distance_to(_home_center_for_slot(int(_buildings["house"]) + i))
			if d < best_d:
				best_d = d
				best_type = "manor"
				best_idx = i

	if best_idx < 0:
		return false

	match best_type:
		"sawmill":
			_sawmill_tiles.remove_at(best_idx)
		"quarry":
			_quarry_tiles.remove_at(best_idx)
		"workshop":
			_workshop_tiles.remove_at(best_idx)
		"storehouse":
			_storehouse_tiles.remove_at(best_idx)
		"armory":
			_armory_tiles.remove_at(best_idx)
		"scout_lodge":
			_scout_lodge_tiles.remove_at(best_idx)
		"house":
			_house_tiles.remove_at(best_idx)
			_recompute_homes()
		"manor":
			_manor_origins.remove_at(best_idx)
			_recompute_homes()
		_:
			return false

	_buildings[best_type] = maxi(0, int(_buildings.get(best_type, 0)) - 1)
	if best_type == "house" or best_type == "manor" or best_type == "scout_lodge":
		_clamp_job_counts()
	_mark_settler_weapons_dirty()
	var label: String = "House" if best_type == "house" else ("Manor" if best_type == "manor" else best_type.capitalize())
	_spawn_floating_text(_tile_center(_camp_tile), "Raiders razed %s!" % label, Color(1.0, 0.24, 0.2, 1.0))
	_kick_camera(11.0)
	return true


# ─── Wildlife ────────────────────────────────────────────────────────────────

func _update_wildlife(delta: float) -> void:
	var result: Dictionary = _wildlife_system.run({
		"delta": delta,
		"structure_raze_cooldown": _structure_raze_cooldown,
		"wildlife_spawn_tick": _wildlife_spawn_tick,
		"night_visual_boost": _night_visual_boost,
		"wolf_raid_active": _wolf_raid_active,
		"camp_tile": _camp_tile,
		"wildlife": _wildlife,
		"resources": _resources,
		"house_tiles": _house_tiles,
		"animal_deer": ANIMAL_DEER,
		"animal_wolf": ANIMAL_WOLF,
		"animal_bear": ANIMAL_BEAR,
		"cb_is_night": Callable(self, "_is_night"),
		"cb_try_spawn_wildlife": Callable(self, "_try_spawn_wildlife"),
		"cb_agent_positions": Callable(_agents, "get_agent_positions"),
		"cb_flee_direction": Callable(self, "_flee_direction"),
		"cb_wander": Callable(self, "_wander"),
		"cb_tile_center": Callable(self, "_tile_center"),
		"cb_apply_predator_strike": Callable(self, "_apply_predator_strike"),
		"cb_try_raze_structure": Callable(self, "_try_raze_structure"),
		"cb_wildlife_food_yield": Callable(self, "_wildlife_food_yield"),
		"cb_spawn_floating_text": Callable(self, "_spawn_floating_text"),
	})
	_structure_raze_cooldown = float(result["structure_raze_cooldown"])
	_wildlife_spawn_tick = float(result["wildlife_spawn_tick"])
	_night_visual_boost = float(result["night_visual_boost"])
	_rebuild_wildlife_query_grid()


func _try_spawn_wildlife(prefer_deer: bool = false, group_size: int = 1) -> void:
	if _wildlife.size() >= 64:
		return
	var agents: PackedVector2Array = _agents.get_agent_positions()
	if agents.is_empty():
		return
	var center: Vector2 = agents[0]
	# Spawn 120–280px away from first agent, on explored tiles
	var rng2 := RandomNumberGenerator.new()
	rng2.seed = int(Time.get_ticks_msec())
	var herd_id: int = int(rng2.randi())
	for _attempt in 18:
		var angle: float = rng2.randf() * TAU
		var dist: float = rng2.randf_range(120.0, 280.0)
		var pos := center + Vector2(cos(angle), sin(angle)) * dist
		var tile := _world_to_tile(pos)
		if not _is_explored(tile):
			continue
		var biome: int = _biome_at(tile)
		# Daytime fills deer herds; nighttime skews toward predators.
		var roll: float = rng2.randf()
		var typ: int
		if prefer_deer:
			if biome == 0 or biome == 1 or biome == 2 or biome == 5:
				typ = ANIMAL_DEER
			else:
				continue
		elif biome == 1 or biome == 0:
			if _is_night() and _wolf_raid_active:
				typ = ANIMAL_WOLF if roll < 0.85 else ANIMAL_BEAR
			elif _is_night():
				typ = ANIMAL_DEER if roll < 0.35 else (ANIMAL_WOLF if roll < 0.9 else ANIMAL_BEAR)
			else:
				typ = ANIMAL_DEER if roll < 0.92 else ANIMAL_WOLF
		elif biome == 2:
			if _is_night() and _wolf_raid_active:
				typ = ANIMAL_WOLF if roll < 0.8 else ANIMAL_BEAR
			elif _is_night():
				typ = ANIMAL_DEER if roll < 0.25 else (ANIMAL_WOLF if roll < 0.75 else ANIMAL_BEAR)
			else:
				typ = ANIMAL_DEER if roll < 0.88 else ANIMAL_WOLF
		elif biome == 5 and not _is_night():
			typ = ANIMAL_DEER if roll < 0.95 else ANIMAL_WOLF
		else:
			continue
		var spawns: int = 1
		if typ == ANIMAL_DEER:
			spawns = clampi(group_size, 1, 6)
		for gi in spawns:
			if _wildlife.size() >= 64:
				break
			var jitter_angle: float = rng2.randf() * TAU
			var jitter_dist: float = 5.0 + float(gi) * 4.0 + rng2.randf_range(0.0, 9.0)
			var spawn_pos: Vector2 = pos
			if typ == ANIMAL_DEER:
				spawn_pos = pos + Vector2(cos(jitter_angle), sin(jitter_angle)) * jitter_dist
			_wildlife.append({
				"type": typ,
				"pos": spawn_pos,
				"vel": Vector2.ZERO,
				"hp": _wildlife_max_hp(typ),
				"max_hp": _wildlife_max_hp(typ),
				"state": "wander",
				"target_pos": spawn_pos,
				"attack_cd": 0.0,
				"wander_timer": 0.0,
				"wander_dir": Vector2(cos(rng2.randf() * TAU), sin(rng2.randf() * TAU)),
				"chase_timer": 0.0,
				"phase": rng2.randf() * TAU,
				"herd_id": herd_id if typ == ANIMAL_DEER else -1,
			})
		break


func _spawn_predators_from_fog(wolf_count: int, bear_count: int) -> void:
	var center: Vector2 = _tile_center(_camp_tile)
	for i in wolf_count:
		if _wildlife.size() >= 48:
			break
		var spawn_pos: Vector2 = _find_fog_spawn_point(center)
		var angle: float = _rng.randf() * TAU
		_wildlife.append({
			"type": ANIMAL_WOLF,
			"pos": spawn_pos,
			"vel": Vector2.ZERO,
			"hp": _wildlife_max_hp(ANIMAL_WOLF),
			"max_hp": _wildlife_max_hp(ANIMAL_WOLF),
			"state": "raid_hunt",
			"target_pos": center,
			"attack_cd": _rng.randf_range(0.0, 1.0),
			"wander_timer": 0.0,
			"wander_dir": Vector2(cos(angle), sin(angle)),
			"chase_timer": 6.0,
			"phase": _rng.randf() * TAU,
			"herd_id": -1,
		})
	for j in bear_count:
		if _wildlife.size() >= 48:
			break
		var spawn_pos_b: Vector2 = _find_fog_spawn_point(center)
		var angle_b: float = _rng.randf() * TAU
		_wildlife.append({
			"type": ANIMAL_BEAR,
			"pos": spawn_pos_b,
			"vel": Vector2.ZERO,
			"hp": _wildlife_max_hp(ANIMAL_BEAR),
			"max_hp": _wildlife_max_hp(ANIMAL_BEAR),
			"state": "aggro",
			"target_pos": center,
			"attack_cd": _rng.randf_range(0.0, 1.0),
			"wander_timer": 0.0,
			"wander_dir": Vector2(cos(angle_b), sin(angle_b)),
			"chase_timer": 8.0,
			"phase": _rng.randf() * TAU,
			"herd_id": -1,
		})


func _find_fog_spawn_point(center: Vector2) -> Vector2:
	for _attempt in 40:
		var angle: float = _rng.randf() * TAU
		var dist: float = _rng.randf_range(170.0, 340.0)
		var pos: Vector2 = center + Vector2(cos(angle), sin(angle)) * dist
		var tile := _world_to_tile(pos)
		if _is_explored(tile):
			continue
		return pos
	# Fallback if no fog tile found nearby.
	var fallback_angle: float = _rng.randf() * TAU
	return center + Vector2(cos(fallback_angle), sin(fallback_angle)) * _rng.randf_range(240.0, 320.0)


func _spawn_wolves_around_homes(count: int, circle_only: bool) -> void:
	if count <= 0:
		return
	var center: Vector2 = _tile_center(_camp_tile)
	if _house_tiles.size() > 0:
		center = _tile_center(_house_tiles[0])
	for i in count:
		if _wildlife.size() >= 36:
			break
		var angle: float = TAU * float(i) / maxf(1.0, float(count))
		var radius: float = 84.0 + _rng.randf_range(-12.0, 22.0)
		var pos := center + Vector2(cos(angle), sin(angle)) * radius
		_wildlife.append({
			"type": ANIMAL_WOLF,
			"pos": pos,
			"vel": Vector2.ZERO,
			"hp": _wildlife_max_hp(ANIMAL_WOLF),
			"max_hp": _wildlife_max_hp(ANIMAL_WOLF),
			"state": "circle" if circle_only else "chase",
			"target_pos": center,
			"attack_cd": _rng.randf_range(0.0, 1.0),
			"wander_timer": 0.0,
			"wander_dir": Vector2(cos(angle + PI * 0.5), sin(angle + PI * 0.5)),
			"chase_timer": 5.0,
		})


func _wildlife_max_hp(typ: int) -> float:
	match typ:
		ANIMAL_DEER: return 3.0
		ANIMAL_WOLF: return 6.0
		ANIMAL_BEAR: return 18.0
	return 3.0


func _wildlife_food_yield(typ: int) -> float:
	match typ:
		ANIMAL_DEER: return 4.0 * _hunting_yield_mult
		ANIMAL_WOLF: return 2.0 * _hunting_yield_mult
		ANIMAL_BEAR: return 10.0 * _hunting_yield_mult
	return 2.0 * _hunting_yield_mult


func _wander(w: Dictionary, delta: float, speed: float) -> Vector2:
	w["wander_timer"] = float(w["wander_timer"]) - delta
	if float(w["wander_timer"]) <= 0.0:
		var angle: float = _rng.randf() * TAU
		w["wander_dir"] = Vector2(cos(angle), sin(angle))
		w["wander_timer"] = _rng.randf_range(1.5, 4.0)
	return w["wander_dir"] * speed


func _flee_direction(from_pos: Vector2, threats: PackedVector2Array, radius: float) -> Vector2:
	var flee := Vector2.ZERO
	for tp in threats:
		var diff: Vector2 = from_pos - tp
		var d: float = diff.length()
		if d < radius and d > 0.01:
			flee += diff.normalized() * (1.0 - d / radius)
	return flee


func _draw_hunter_anims() -> void:
	for anim in _hunter_attack_anims:
		var p: float = clampf(float(anim["t"]) / float(anim["dur"]), 0.0, 1.0)
		var alpha: float = 1.0 - p
		var tip: Vector2 = (anim["from"] as Vector2).lerp(anim["to"], minf(p * 2.5, 1.0))
		var base_col: Color = anim.get("color", Color(0.82, 0.76, 0.42, 1.0))
		var line_col: Color = Color(base_col.r, base_col.g, base_col.b, alpha)
		var width: float = float(anim.get("width", 2.2))
		draw_line(anim["from"], tip, line_col, width)
		# Spear tip
		draw_circle(tip, maxf(1.6, width * 0.9), line_col)


func _update_camera_kick(delta: float) -> void:
	if _camera_kick.length_squared() < 0.0001:
		_camera.position = _camera_base_pos
		_camera_kick = Vector2.ZERO
		return
	_camera_kick = _camera_kick.move_toward(Vector2.ZERO, 35.0 * delta)
	_camera.position = _camera_base_pos + _camera_kick


func _upgrade_color_for(id: String) -> Color:
	if id.begins_with("vision"):
		return Color(0.95, 0.87, 0.2, 1.0)
	if id.begins_with("scout"):
		return Color(0.5, 0.86, 1.0, 1.0)
	if id.begins_with("def"):
		return Color(1.0, 0.52, 0.45, 1.0)
	if id.begins_with("eff"):
		return Color(0.4, 1.0, 0.65, 1.0)
	if id.begins_with("vol"):
		return Color(0.35, 0.85, 1.0, 1.0)
	return Color(0.95, 0.55, 1.0, 1.0)


func _upgrade_label_for(id: String) -> String:
	match id:
		"vol_lumber":
			return "Timber Crews"
		"vol_stone":
			return "Heavy Picks"
		"vol_forage":
			return "Foraging Baskets"
		"eff_speed":
			return "Road Kits"
		"eff_ration":
			return "Strict Rationing"
		"spec_hunting":
			return "Militia Drills"
		"vision_lenses":
			return "Surveyor Lenses"
		"scout_training":
			return "Pathfinder Training"
		"scout_survey":
			return "Survey Maps"
		"scout_beacons":
			return "Signal Beacons"
		"scout_salvage":
			return "Expedition Salvage"
		"def_spears":
			return "Spear Wall"
		_:
			return "Upgrade Purchased"