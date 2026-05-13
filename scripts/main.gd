extends Node2D

const TILE_SIZE: int = 16
const MINIMAP_TILES: int = 96

const RES_NONE: int = 0
const RES_TREE: int = 1
const RES_STONE: int = 2
const RES_APPLE: int = 3   # apple-bearing tree (plains/forest)
const RES_BERRY_BLUE: int = 4   # blueberry bush (marsh/forest)
const RES_BERRY_RASP: int = 5   # raspberry bush (plains/hills)
const RES_BERRY_BLACK: int = 6  # blackberry bush (hills/forest)
const JOB_FARM: int = 0
const JOB_LUMBER: int = 1
const JOB_STONE: int = 2
const JOB_HUNT: int = 3
const JOB_SCOUT: int = 4
const HOUSE_CAPACITY: int = 2

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
const THINK_EXECUTING: int = 0
const THINK_THINKING: int = 1
const THINK_BLOCKED: int = 2

const UI_BG := Color(0.06, 0.09, 0.12, 0.94)
const UI_BG_ALT := Color(0.1, 0.14, 0.18, 0.94)
const UI_BORDER := Color(0.36, 0.56, 0.66, 0.92)
const UI_TEXT_ACCENT := Color(0.86, 0.95, 1.0, 1.0)
const MAP_STRUCTURE_OUTLINE := Color(0.05, 0.05, 0.07, 0.95)
const UPGRADE_VISUAL_RADIUS_TILES: int = 6

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
@export var offscreen_decision_throttle_enabled: bool = true
@export_range(1, 16, 1) var offscreen_decision_stride: int = 4
@export_range(1, 16, 1) var offscreen_night_planning_stride: int = 2
@export_range(0.0, 12.0, 0.1) var morning_dispatch_spread_sec: float = 4.0
@export_range(1.0, 25.0, 0.25) var resource_node_yield_mult: float = 6.0
@export_range(1, 1000, 1) var night_planning_budget_per_tick: int = 120
@export_range(2, 32, 1) var settler_route_segment_tiles: int = 10
@export_range(8, 64, 4) var world_chunk_tiles: int = 24
@export_range(64, 4096, 64) var world_chunk_cache_max_entries: int = 768
@export_range(1, 32, 1) var world_chunk_rebuild_budget_per_frame: int = 3
@export_range(0.1, 5.0, 0.1) var world_chunk_prune_interval_sec: float = 0.5

var _target: Vector2 = Vector2.ZERO
var _world_seed: int = 912713

var _vision_radius: int = 4
var _watchtower_radius: int = 8
var _auto_watchtowers: bool = false
var _max_watchtowers: int = 20
var _watchtowers: Array[Vector2i] = []
var _explored: Dictionary = {}

var _resource_remaining: Dictionary = {}
var _berry_overnight_regrow_due: Dictionary = {}  # tile_key -> seconds until full overnight regrow
var _harvest_tick: float = 0.0
var _resource_regrow_tick: float = 0.0
var _ai_tick: float = 0.0
var _cook_tick: float = 0.0  # cooking accumulator (ticks every 4s per housed settler)
var _tree_yield_mult: float = 1.0
var _stone_yield_mult: float = 1.0
var _convert_mult: float = 1.0
var _day_time: float = 0.22
var _day_length_seconds: float = 150.0

var _resources := {
	"food": 0.0,
	"lumber": 0.0,
	"stone": 0.0,
	"cobblestone": 0.0,
}

var _buildings := {
	"camp": 1,
	"house": 0,
	"sawmill": 0,
	"quarry": 0,
	"workshop": 0,
	"storehouse": 0,
	"armory": 0,
	"scout_lodge": 0,
}

var _camp_tile: Vector2i = Vector2i.ZERO
var _house_tiles: Array[Vector2i] = []
var _sawmill_tiles: Array[Vector2i] = []
var _quarry_tiles: Array[Vector2i] = []
var _workshop_tiles: Array[Vector2i] = []
var _storehouse_tiles: Array[Vector2i] = []
var _armory_tiles: Array[Vector2i] = []
var _scout_lodge_tiles: Array[Vector2i] = []
var _outpost_tiles: Array[Vector2i] = []
var _settler_homes: PackedInt32Array
var _job_counts := {
	"farm": 1,
	"lumber": 0,
	"stone": 0,
	"hunt": 0,
	"scout": 0,
}
var _job_count_labels: Dictionary = {}
var _job_reassign_cursor: int = 0

const BUILDING_RECIPES := {
	"House": {"id": "house", "cost": {"lumber": 24.0, "cobblestone": 8.0}},
	"Sawmill": {"id": "sawmill", "cost": {"lumber": 35.0}},
	"Quarry": {"id": "quarry", "cost": {"lumber": 30.0}},
	"Workshop": {"id": "workshop", "cost": {"lumber": 40.0, "stone": 18.0}},
	"Storehouse": {"id": "storehouse", "cost": {"lumber": 55.0, "cobblestone": 25.0}},
	"Armory": {"id": "armory", "cost": {"lumber": 60.0, "stone": 40.0, "cobblestone": 18.0}},
	"Scout Lodge": {"id": "scout_lodge", "cost": {"lumber": 52.0, "stone": 22.0, "cobblestone": 10.0}},
}

const POP_ACTIONS := {
	"recruit": {"name": "Recruit Settler", "effect": "+1 colonist (requires available housing)", "cost": {"food": 26.0}},
	"house": {"name": "Build House", "effect": "+2 housing (settlers return nightly)", "cost": {"lumber": 22.0, "cobblestone": 7.0}},
}

const UPGRADE_DATA := {
	"Volume": [
		{"id": "vol_lumber", "name": "Timber Crews", "effect": "Tree harvest +35% per rank", "cost": {"lumber": 42.0}, "max_rank": 5, "cost_scale": 1.45},
		{"id": "vol_stone", "name": "Heavy Picks", "effect": "Stone harvest +35% per rank", "cost": {"lumber": 34.0, "stone": 18.0}, "max_rank": 5, "cost_scale": 1.45},
		{"id": "vol_geology", "name": "Geologist Teams", "effect": "Stone harvest +25% per rank", "cost": {"lumber": 28.0, "stone": 14.0}, "max_rank": 4, "cost_scale": 1.45},
		{"id": "vol_forage", "name": "Foraging Baskets", "effect": "Food gather +30% per rank", "cost": {"food": 10.0, "lumber": 30.0}, "max_rank": 4, "cost_scale": 1.5},
		{"id": "vol_hoard", "name": "Hoarding Cellars", "effect": "Storehouse output +70%, but -8% happiness gain", "cost": {"lumber": 48.0, "cobblestone": 14.0}, "max_rank": 3, "cost_scale": 1.6},
	],
	"Efficiency": [
		{"id": "eff_speed", "name": "Road Kits", "effect": "Colonist speed +18% per rank", "cost": {"lumber": 52.0}, "max_rank": 5, "cost_scale": 1.5},
		{"id": "eff_convert", "name": "Stone Saws", "effect": "Cobble conversion +50% per rank", "cost": {"lumber": 44.0, "stone": 28.0}, "max_rank": 4, "cost_scale": 1.55},
		{"id": "eff_quarry_ops", "name": "Quarry Logistics", "effect": "Passive quarry stone trickle +60% per rank", "cost": {"lumber": 30.0, "stone": 20.0}, "max_rank": 4, "cost_scale": 1.5},
		{"id": "eff_ration", "name": "Strict Rationing", "effect": "Food use -20%, but happiness drops faster", "cost": {"food": 20.0, "cobblestone": 18.0}, "max_rank": 3, "cost_scale": 1.7},
		{"id": "eff_campfire", "name": "Campfire Stories", "effect": "Night happiness recovery +40%", "cost": {"food": 24.0, "lumber": 20.0}, "max_rank": 4, "cost_scale": 1.55},
	],
	"Specialization": [
		{"id": "spec_forestry", "name": "Forester Doctrine", "effect": "Adds a free Sawmill per rank", "cost": {"lumber": 84.0, "cobblestone": 18.0}, "max_rank": 3, "cost_scale": 1.7},
		{"id": "spec_masonry", "name": "Mason Doctrine", "effect": "Adds a free Quarry per rank", "cost": {"lumber": 66.0, "cobblestone": 24.0}, "max_rank": 3, "cost_scale": 1.7},
		{"id": "spec_hunting", "name": "Militia Drills", "effect": "All colonists deal +35% damage to wolves", "cost": {"food": 28.0, "lumber": 28.0}, "max_rank": 5, "cost_scale": 1.45},
		{"id": "spec_bravado", "name": "Bravado Culture", "effect": "Huge morale gain, but food consumption rises", "cost": {"food": 40.0, "lumber": 45.0}, "max_rank": 2, "cost_scale": 1.85},
	],
	"Vision & Exploration": [
		{"id": "vision_lenses", "name": "Surveyor Lenses", "effect": "Vision radius +1 per rank", "cost": {"lumber": 36.0}, "max_rank": 7, "cost_scale": 1.4},
		{"id": "vision_tower_net", "name": "Watchtower Network", "effect": "Enable watchtower placement", "cost": {"lumber": 70.0, "cobblestone": 26.0}, "max_rank": 1, "cost_scale": 1.0},
		{"id": "vision_tower_range", "name": "Cartography Guild", "effect": "Watchtower radius +2 per rank", "cost": {"lumber": 90.0, "cobblestone": 45.0}, "max_rank": 4, "cost_scale": 1.6},
		{"id": "vision_nightwatch", "name": "Moon Lanterns", "effect": "Brighter nights, wolves raid less often", "cost": {"food": 18.0, "lumber": 26.0}, "max_rank": 3, "cost_scale": 1.7},
	],
	"Scouting": [
		{"id": "scout_training", "name": "Pathfinder Training", "effect": "POI discovery radius +16% per rank", "cost": {"food": 24.0, "lumber": 34.0}, "max_rank": 4, "cost_scale": 1.5},
		{"id": "scout_survey", "name": "Survey Maps", "effect": "POI spawn interval -12% per rank", "cost": {"lumber": 40.0, "stone": 18.0}, "max_rank": 4, "cost_scale": 1.55},
		{"id": "scout_beacons", "name": "Signal Beacons", "effect": "POI discovery radius +20% per rank", "cost": {"lumber": 38.0, "cobblestone": 14.0}, "max_rank": 4, "cost_scale": 1.5},
		{"id": "scout_salvage", "name": "Expedition Salvage", "effect": "POI rewards +18% per rank", "cost": {"food": 20.0, "lumber": 32.0}, "max_rank": 4, "cost_scale": 1.55},
	],
	"Defense": [
		{"id": "def_spears", "name": "Spear Wall", "effect": "All settlers can strike wolves faster", "cost": {"lumber": 30.0, "stone": 18.0}, "max_rank": 5, "cost_scale": 1.45},
		{"id": "def_horns", "name": "Alarm Horns", "effect": "Night raids start with less wolf morale", "cost": {"lumber": 45.0, "cobblestone": 20.0}, "max_rank": 3, "cost_scale": 1.6},
		{"id": "def_training", "name": "Shield Drills", "effect": "Settlers lose less happiness when hungry", "cost": {"food": 22.0, "stone": 20.0}, "max_rank": 4, "cost_scale": 1.55},
	],
	"Combat": [
		{"id": "cmb_armory", "name": "War Foundry", "effect": "Adds 1 free Armory per rank for weapon logistics", "cost": {"lumber": 88.0, "stone": 60.0}, "max_rank": 3, "cost_scale": 1.65},
		{"id": "cmb_shields", "name": "Shield Corps", "effect": "Unlock shield units: high defense, lower damage", "cost": {"lumber": 46.0, "stone": 36.0}, "max_rank": 1, "cost_scale": 1.0},
		{"id": "cmb_bowcraft", "name": "Bowyer Guild", "effect": "Unlock bow units: long range, reduced defense", "cost": {"lumber": 54.0, "food": 22.0}, "max_rank": 3, "cost_scale": 1.6},
		{"id": "cmb_javelin", "name": "Skirmisher Kits", "effect": "Unlock javelin units: burst ranged, slower cadence", "cost": {"lumber": 52.0, "stone": 34.0}, "max_rank": 2, "cost_scale": 1.6},
		{"id": "cmb_steel", "name": "Tempered Steel", "effect": "Melee damage +16% per rank", "cost": {"lumber": 42.0, "stone": 24.0}, "max_rank": 4, "cost_scale": 1.5},
		{"id": "cmb_drills", "name": "Squad Drills", "effect": "Attack speed +8% and better same-weapon cohesion", "cost": {"food": 30.0, "lumber": 38.0}, "max_rank": 4, "cost_scale": 1.5},
	],
}

var _purchased_upgrades: Dictionary = {}
var _upgrade_ranks: Dictionary = {}
var _upgrade_visual_tiles: Dictionary = {}  # upgrade_id -> Vector2i marker tile

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
var _hovered_agent_idx: int = -1
var _pinned_agent_idx: int = -1
var _hover_probe_radius_px: float = 12.0
var _hover_panel: PanelContainer
var _hover_title_label: Label
var _hover_body_label: RichTextLabel
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
var _world_chunk_rebuild_queued: Dictionary = {}
var _world_chunk_prune_accum: float = 0.0
var _resource_type_cache: Dictionary = {}
var _resource_initial_amount_cache: Dictionary = {}

var _upgrade_bursts: Array[Dictionary] = []
var _floating_texts: Array[Dictionary] = []
var _collect_particles: Array[Dictionary] = []
var _collect_particle_texture: Texture2D
var _collect_particle_mesh: QuadMesh
var _collect_particle_multimesh: MultiMesh = MultiMesh.new()
var _collect_particle_batch_ready: bool = false
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
var _settler_attack_cooldowns: PackedFloat32Array
var _settler_attack_speed_mult: float = 1.0
var _settler_combat_damage_mult: float = 1.0
var _settler_weapons: PackedInt32Array
var _settler_tools: PackedInt32Array
var _settler_next_think_time: PackedFloat32Array
var _settler_think_state: PackedInt32Array
var _settler_last_pos: PackedVector2Array
var _settler_idle_time: PackedFloat32Array
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
var _global_settler_log_lines: Array[String] = []
var _global_settler_log_flush_accum: float = 0.0
var _global_settler_snapshot_accum: float = 0.0
var _global_settler_log_drop_count: int = 0
var _global_settler_log_active: bool = false
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
	_resources["cobblestone"] = 0.0
	_recompute_homes()
	_load_weapon_registry()
	_sync_agent_tracking()
	_distribute_jobs_evenly()
	_sync_agent_render_bounds()

	_reveal_around_world(_target, 6)
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
	_update_day_cycle(delta)
	_perf_record_step("update_day_cycle", step_start_us)
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
	_update_upgrade_bursts(delta)
	_perf_record_step("update_upgrade_bursts", step_start_us)
	step_start_us = Time.get_ticks_usec()
	_update_floating_texts(delta)
	_perf_record_step("update_floating_texts", step_start_us)
	step_start_us = Time.get_ticks_usec()
	_update_collection_particles(delta)
	_perf_record_step("update_collection_particles", step_start_us)
	step_start_us = Time.get_ticks_usec()
	_update_settler_combat(delta)
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
	_update_happiness(delta)
	_perf_record_step("update_happiness", step_start_us)
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
		"cobblestone": (_rng.randf_range(0.0, 3.5) + day_boost * 0.3) * _effective_poi_reward_mult(),
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
			+ "Potential loot: %.0f food, %.0f lumber, %.0f stone, %.0f cobblestone\n"
			+ "Chance to establish an outpost: %d%%"
		) % [
			int(_poi_offer["colonists"]),
			float(loot["food"]),
			float(loot["lumber"]),
			float(loot["stone"]),
			float(loot["cobblestone"]),
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
	for key in ["food", "lumber", "stone", "cobblestone"]:
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
		_rebalance_settler_weapons()
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
	draw_step_us = Time.get_ticks_usec()
	_draw_night_fx()
	_perf_record_step("draw_night_fx", draw_step_us)
	draw_step_us = Time.get_ticks_usec()
	_draw_watchtowers()
	_perf_record_step("draw_watchtowers", draw_step_us)
	draw_step_us = Time.get_ticks_usec()
	_draw_target()
	_perf_record_step("draw_target", draw_step_us)
	draw_step_us = Time.get_ticks_usec()
	_draw_settler_thinking_indicators()
	_perf_record_step("draw_settler_thinking_indicators", draw_step_us)
	draw_step_us = Time.get_ticks_usec()
	_draw_hover_feedback()
	_perf_record_step("draw_hover_feedback", draw_step_us)
	draw_step_us = Time.get_ticks_usec()
	_draw_upgrade_vfx()
	_perf_record_step("draw_upgrade_vfx", draw_step_us)
	draw_step_us = Time.get_ticks_usec()
	_draw_collection_particles()
	_perf_record_step("draw_collection_particles", draw_step_us)
	draw_step_us = Time.get_ticks_usec()
	_draw_wildlife()
	_perf_record_step("draw_wildlife", draw_step_us)
	draw_step_us = Time.get_ticks_usec()
	_draw_hunter_anims()
	_perf_record_step("draw_hunter_anims", draw_step_us)
	draw_step_us = Time.get_ticks_usec()
	_draw_floating_texts()
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


func _process_world_chunk_streaming(delta: float) -> void:
	_world_chunk_prune_accum += delta
	if world_chunk_rebuild_budget_per_frame > 0:
		var budget: int = mini(world_chunk_rebuild_budget_per_frame, _world_chunk_rebuild_queue.size())
		for _i in budget:
			var chunk: Vector2i = _world_chunk_rebuild_queue.pop_front()
			var key: String = _world_chunk_key(chunk)
			_world_chunk_rebuild_queued.erase(key)
			var tex: ImageTexture = _rebuild_world_chunk_texture(chunk)
			if tex != null:
				_world_chunk_textures[key] = tex
				_world_chunk_dirty[key] = false

	if _world_chunk_prune_accum < world_chunk_prune_interval_sec:
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
	_prune_world_chunk_cache(Vector2i((cmin_x + cmax_x) / 2, (cmin_y + cmax_y) / 2), maxi(cmax_x - cmin_x, cmax_y - cmin_y) + 2)


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

			var res_type: int = _resource_type_at(tile)
			if res_type == RES_NONE or _resource_left(tile, res_type) <= 0.0:
				continue

			match res_type:
				RES_TREE:
					img.fill_rect(Rect2i(px + 5, py + 5, 6, 6), Color(0.1, 0.55, 0.18, 0.95))
				RES_STONE:
					img.fill_rect(Rect2i(px + 4, py + 4, 8, 8), Color(0.58, 0.6, 0.64, 0.95))
				RES_APPLE:
					img.fill_rect(Rect2i(px + 4, py + 4, 7, 7), Color(0.12, 0.52, 0.14, 0.95))
					img.fill_rect(Rect2i(px + 9, py + 4, 2, 2), Color(0.92, 0.22, 0.18, 0.95))
				RES_BERRY_BLUE:
					img.fill_rect(Rect2i(px + 6, py + 6, 5, 5), Color(0.22, 0.44, 0.82, 0.95))
				RES_BERRY_RASP:
					img.fill_rect(Rect2i(px + 6, py + 6, 5, 5), Color(0.82, 0.2, 0.32, 0.95))
				RES_BERRY_BLACK:
					img.fill_rect(Rect2i(px + 6, py + 6, 5, 5), Color(0.28, 0.12, 0.36, 0.95))

	if _world_chunk_textures.has(_world_chunk_key(chunk)):
		var existing: ImageTexture = _world_chunk_textures[_world_chunk_key(chunk)]
		existing.update(img)
		return existing
	return ImageTexture.create_from_image(img)


func _prune_world_chunk_cache(center_chunk: Vector2i, keep_radius: int) -> void:
	if _world_chunk_textures.size() <= world_chunk_cache_max_entries:
		return
	var keys: Array = _world_chunk_textures.keys()
	for key_v in keys:
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


func _draw_settler_thinking_indicators() -> void:
	if not show_settler_thinking_indicator:
		return
	var agents: PackedVector2Array = _agents.get_agent_positions()
	if agents.is_empty() or _settler_think_state.size() != agents.size():
		return

	var vp: Vector2 = get_viewport_rect().size
	var z: Vector2 = _camera.zoom
	var half: Vector2 = Vector2(vp.x * 0.5 / z.x, vp.y * 0.5 / z.y)
	var cam: Vector2 = _camera.position
	var min_x: float = cam.x - half.x - 20.0
	var max_x: float = cam.x + half.x + 20.0
	var min_y: float = cam.y - half.y - 20.0
	var max_y: float = cam.y + half.y + 20.0

	for i in agents.size():
		var pos: Vector2 = agents[i]
		if pos.x < min_x or pos.x > max_x or pos.y < min_y or pos.y > max_y:
			continue
		var state: int = _settler_think_state[i]
		if state != THINK_THINKING:
			continue
		draw_circle(pos + Vector2(0.0, -7.0), 1.6, Color(1.0, 0.86, 0.22, 0.92))


func _draw_structure_tile(tile: Vector2i, col: Color) -> void:
	var rect := Rect2(tile.x * TILE_SIZE + 2, tile.y * TILE_SIZE + 2, TILE_SIZE - 4, TILE_SIZE - 4)
	draw_rect(rect, col)
	draw_rect(rect, MAP_STRUCTURE_OUTLINE, false, 1.0)


func _draw_upgrade_markers() -> void:
	var font: Font = ThemeDB.fallback_font
	var scale: float = _upgrade_marker_visual_scale()
	for id_v in _upgrade_ranks.keys():
		var id: String = String(id_v)
		var rank: int = int(_upgrade_ranks[id])
		if rank <= 0:
			continue
		var tile: Vector2i = _ensure_upgrade_visual_tile(id)
		var center: Vector2 = _tile_center(tile)
		var col: Color = _upgrade_color_for(id)
		var category: String = _upgrade_category_for(id)
		draw_arc(center, 5.4 * scale, 0.0, TAU, 20, Color(col.r, col.g, col.b, 0.55), 1.1 * scale)
		_draw_upgrade_category_icon(center, col, category, 0.95, scale)
		draw_string(
			font,
			center + Vector2(-4.0, -6.0) * scale,
			str(rank),
			HORIZONTAL_ALIGNMENT_LEFT,
			-1.0,
			int(round(10.0 * scale)),
			Color(1.0, 1.0, 1.0, 0.95)
		)


func _upgrade_marker_visual_scale() -> float:
	if _camera == null:
		return 1.0
	return clampf(_camera.zoom.x, 0.8, 2.2)


func _ensure_upgrade_visual_tile(id: String) -> Vector2i:
	if _upgrade_visual_tiles.has(id):
		return _upgrade_visual_tiles[id]

	var occupied: Dictionary = {}
	occupied[_tile_key(_camp_tile)] = true
	for t in _house_tiles:
		occupied[_tile_key(t)] = true
	for t in _sawmill_tiles:
		occupied[_tile_key(t)] = true
	for t in _quarry_tiles:
		occupied[_tile_key(t)] = true
	for t in _workshop_tiles:
		occupied[_tile_key(t)] = true
	for t in _storehouse_tiles:
		occupied[_tile_key(t)] = true
	for t in _armory_tiles:
		occupied[_tile_key(t)] = true
	for t in _scout_lodge_tiles:
		occupied[_tile_key(t)] = true
	for t in _outpost_tiles:
		occupied[_tile_key(t)] = true
	for v in _upgrade_visual_tiles.values():
		occupied[_tile_key(v)] = true

	var base_hash: int = abs(id.hash())
	for attempt in 48:
		var ring: int = UPGRADE_VISUAL_RADIUS_TILES + int(floor(attempt / 12.0))
		var angle_step: float = TAU / 12.0
		var slot: int = (base_hash + attempt) % 12
		var a: float = slot * angle_step
		var tile := Vector2i(
			_camp_tile.x + int(round(cos(a) * ring)),
			_camp_tile.y + int(round(sin(a) * ring))
		)
		var key: String = _tile_key(tile)
		if occupied.has(key):
			continue
		_upgrade_visual_tiles[id] = tile
		return tile

	var fallback := Vector2i(_camp_tile.x + UPGRADE_VISUAL_RADIUS_TILES + _upgrade_visual_tiles.size(), _camp_tile.y)
	_upgrade_visual_tiles[id] = fallback
	return fallback


func _upgrade_category_for(id: String) -> String:
	if id.begins_with("vol"):
		return "volume"
	if id.begins_with("eff"):
		return "efficiency"
	if id.begins_with("spec"):
		return "specialization"
	if id.begins_with("vision"):
		return "vision"
	if id.begins_with("scout"):
		return "scouting"
	if id.begins_with("def"):
		return "defense"
	if id.begins_with("cmb"):
		return "combat"
	return "misc"


func _draw_upgrade_category_icon(center: Vector2, col: Color, category: String, alpha: float = 1.0, scale: float = 1.0) -> void:
	var c := Color(col.r, col.g, col.b, alpha)
	var lw: float = 1.2 * scale
	match category:
		"volume":
			draw_line(center + Vector2(-3.0, -3.0) * scale, center + Vector2(-3.0, 3.0) * scale, c, lw)
			draw_line(center + Vector2(0.0, -4.0) * scale, center + Vector2(0.0, 4.0) * scale, c, lw)
			draw_line(center + Vector2(3.0, -2.0) * scale, center + Vector2(3.0, 2.0) * scale, c, lw)
		"efficiency":
			draw_line(center + Vector2(-4.0, -3.0) * scale, center + Vector2(-1.0, 0.0) * scale, c, 1.4 * scale)
			draw_line(center + Vector2(-1.0, 0.0) * scale, center + Vector2(-4.0, 3.0) * scale, c, 1.4 * scale)
			draw_line(center + Vector2(0.0, -3.0) * scale, center + Vector2(3.0, 0.0) * scale, c, 1.4 * scale)
			draw_line(center + Vector2(3.0, 0.0) * scale, center + Vector2(0.0, 3.0) * scale, c, 1.4 * scale)
		"specialization":
			var p0 := center + Vector2(0.0, -4.0) * scale
			var p1 := center + Vector2(4.0, 0.0) * scale
			var p2 := center + Vector2(0.0, 4.0) * scale
			var p3 := center + Vector2(-4.0, 0.0) * scale
			draw_line(p0, p1, c, lw)
			draw_line(p1, p2, c, lw)
			draw_line(p2, p3, c, lw)
			draw_line(p3, p0, c, lw)
			draw_circle(center, 1.0 * scale, c)
		"vision":
			draw_line(center + Vector2(-4.0, 0.0) * scale, center + Vector2(0.0, -2.5) * scale, c, lw)
			draw_line(center + Vector2(0.0, -2.5) * scale, center + Vector2(4.0, 0.0) * scale, c, lw)
			draw_line(center + Vector2(4.0, 0.0) * scale, center + Vector2(0.0, 2.5) * scale, c, lw)
			draw_line(center + Vector2(0.0, 2.5) * scale, center + Vector2(-4.0, 0.0) * scale, c, lw)
			draw_circle(center, 1.0 * scale, c)
		"scouting":
			var s0 := center + Vector2(0.0, -4.0) * scale
			var s1 := center + Vector2(4.0, 3.0) * scale
			var s2 := center + Vector2(-4.0, 3.0) * scale
			draw_line(s0, s1, c, lw)
			draw_line(s1, s2, c, lw)
			draw_line(s2, s0, c, lw)
			draw_circle(center + Vector2(0.0, -1.0) * scale, 1.0 * scale, c)
		"defense":
			var d0 := center + Vector2(0.0, -4.0) * scale
			var d1 := center + Vector2(4.0, -1.0) * scale
			var d2 := center + Vector2(2.0, 3.5) * scale
			var d3 := center + Vector2(-2.0, 3.5) * scale
			var d4 := center + Vector2(-4.0, -1.0) * scale
			draw_line(d0, d1, c, lw)
			draw_line(d1, d2, c, lw)
			draw_line(d2, d3, c, lw)
			draw_line(d3, d4, c, lw)
			draw_line(d4, d0, c, lw)
		"combat":
			draw_line(center + Vector2(-3.5, -3.5) * scale, center + Vector2(3.5, 3.5) * scale, c, 1.4 * scale)
			draw_line(center + Vector2(3.5, -3.5) * scale, center + Vector2(-3.5, 3.5) * scale, c, 1.4 * scale)
			draw_circle(center, 1.0 * scale, c)
		_:
			draw_rect(Rect2(center.x - 3.0 * scale, center.y - 3.0 * scale, 6.0 * scale, 6.0 * scale), c, false, lw)


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


func _draw_upgrade_vfx() -> void:
	for burst in _upgrade_bursts:
		var t: float = float(burst["t"])
		var dur: float = float(burst["dur"])
		var p: float = clampf(t / dur, 0.0, 1.0)
		var ease_out: float = 1.0 - pow(1.0 - p, 2.0)
		var pos: Vector2 = burst["pos"]
		var col: Color = burst["color"]
		var radius: float = lerpf(10.0, 70.0, ease_out)
		var alpha: float = 1.0 - p

		draw_circle(pos, 12.0 + 20.0 * ease_out, Color(col.r, col.g, col.b, 0.18 * alpha))
		draw_arc(pos, radius, 0.0, TAU, 48, Color(col.r, col.g, col.b, 0.85 * alpha), 2.0)


func _draw_floating_texts() -> void:
	var font: Font = ThemeDB.fallback_font
	for ft in _floating_texts:
		var t: float = float(ft["t"])
		var dur: float = float(ft["dur"])
		var p: float = clampf(t / dur, 0.0, 1.0)
		var ease_out: float = 1.0 - pow(1.0 - p, 2.0)
		var pos: Vector2 = ft["pos"] + Vector2(0.0, -24.0 * ease_out)
		var col: Color = ft["color"]
		var alpha: float = 1.0 - p
		var text: String = String(ft["text"])
		draw_string(font, pos + Vector2(1, 1), text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 14, Color(0, 0, 0, 0.5 * alpha))
		draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 14, Color(col.r, col.g, col.b, alpha))


func _draw_collection_particles() -> void:
	if _collect_particles.is_empty():
		return
	_ensure_collect_particle_batch_resources()
	var count: int = _collect_particles.size()
	_collect_particle_multimesh.instance_count = count
	_collect_particle_multimesh.visible_instance_count = count
	for i in count:
		var p: Dictionary = _collect_particles[i]
		var alpha: float = 1.0 - clampf(float(p["t"]) / float(p["dur"]), 0.0, 1.0)
		var col: Color = p["color"]
		var size: float = float(p["size"])
		var pos: Vector2 = p["pos"]
		_collect_particle_multimesh.set_instance_transform_2d(i, Transform2D(Vector2(size, 0.0), Vector2(0.0, size), pos))
		_collect_particle_multimesh.set_instance_color(i, Color(col.r, col.g, col.b, alpha))
	draw_multimesh(_collect_particle_multimesh, _collect_particle_texture)


func _ensure_collect_particle_batch_resources() -> void:
	if _collect_particle_batch_ready:
		return
	if _collect_particle_mesh == null:
		_collect_particle_mesh = QuadMesh.new()
		_collect_particle_mesh.size = Vector2.ONE
	if _collect_particle_texture == null:
		var img: Image = Image.create(16, 16, false, Image.FORMAT_RGBA8)
		img.fill(Color(0.0, 0.0, 0.0, 0.0))
		for y in 16:
			for x in 16:
				var uv: Vector2 = Vector2(float(x) + 0.5, float(y) + 0.5)
				var d: float = uv.distance_to(Vector2(8.0, 8.0))
				var a: float = clampf((7.5 - d) / 2.0, 0.0, 1.0)
				img.set_pixel(x, y, Color(1.0, 1.0, 1.0, a))
		_collect_particle_texture = ImageTexture.create_from_image(img)
	_collect_particle_multimesh.mesh = _collect_particle_mesh
	_collect_particle_multimesh.instance_count = 0
	_collect_particle_multimesh.visible_instance_count = 0
	_collect_particle_multimesh.transform_format = MultiMesh.TRANSFORM_2D
	_collect_particle_multimesh.use_colors = true
	_collect_particle_multimesh.use_custom_data = false
	_collect_particle_batch_ready = true


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
		"outpost_tiles": _outpost_tiles,
		"food_consume_per_settler": _food_consume_per_settler,
		"food_consume_mult": _food_consume_mult,
		"convert_mult": _convert_mult,
		"quarry_passive_mult": _quarry_passive_mult,
		"storehouse_mult": _storehouse_mult,
		"res_apple": RES_APPLE,
		"res_berry_blue": RES_BERRY_BLUE,
		"res_berry_rasp": RES_BERRY_RASP,
		"res_berry_black": RES_BERRY_BLACK,
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
		var rt: int = _resource_type_at(tile)
		if rt != RES_BERRY_BLUE and rt != RES_BERRY_RASP and rt != RES_BERRY_BLACK:
			continue
		var cur: float = float(_resource_remaining[key])
		var max_amt: float = _resource_initial_amount(tile, rt)
		if cur < max_amt:
			_berry_overnight_regrow_due[key] = _rng.randf_range(0.05, night_duration)


func _compute_raid_spawn_counts() -> Dictionary:
	var houses: int = maxi(1, int(_buildings["house"]))
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
	var houses: float = float(maxi(1, int(_buildings["house"])))
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
	if not _berry_overnight_regrow_due.is_empty():
		for key_v in _berry_overnight_regrow_due.keys():
			var key: String = String(key_v)
			var parts: Array = key.split(":")
			if parts.size() != 2:
				continue
			var tile := Vector2i(int(parts[0]), int(parts[1]))
			var rt: int = _resource_type_at(tile)
			if rt == RES_BERRY_BLUE or rt == RES_BERRY_RASP or rt == RES_BERRY_BLACK:
				_resource_remaining[key] = _resource_initial_amount(tile, rt)
				_mark_tile_dirty(tile)
		_berry_overnight_regrow_due.clear()
	if morning_dispatch_spread_sec > 0.0 and _agents.get_agent_count() > 0:
		_sync_settler_think_buffers(_agents.get_agent_count())
		var now_sec: float = Time.get_ticks_msec() * 0.001
		for i in _agents.get_agent_count():
			var was_blocked: bool = _settler_think_state[i] == THINK_BLOCKED
			_settler_next_think_time[i] = now_sec if was_blocked else now_sec + _rng.randf_range(0.0, morning_dispatch_spread_sec)
			_settler_think_state[i] = THINK_EXECUTING
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


func _update_happiness(delta: float) -> void:
	for i in _agents.get_agent_count():
		var h: float = _settler_happiness[i]
		if _resources["food"] <= 0.0:
			h -= 0.06 * _happiness_loss_mult * delta
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
		if job == JOB_STONE and res_type != RES_STONE:
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
		amount *= _tool_harvest_mult(i, job)

		var mined: float = minf(left, amount)
		_set_resource_left(tile, left - mined)

		var center := _tile_center(tile)
		if res_type == RES_TREE:
			_resources["lumber"] += mined
			_record_agent_action(i, "Chopped +%d lumber" % int(ceil(mined)))
			_spawn_collect_feedback(center, _resource_feedback_text("lumber", mined), Color(0.22, 0.9, 0.34, 1.0))
		else:
			_resources["stone"] += mined
			_record_agent_action(i, "Mined +%d stone" % int(ceil(mined)))
			_spawn_collect_feedback(center, _resource_feedback_text("stone", mined), Color(0.8, 0.86, 0.95, 1.0))


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
	_add_resource_widget(row, "cobblestone", Color(0.68, 0.72, 0.78, 1.0), "hunt")
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
	_workshop_toggle_btn.text = "Cobble: ON"
	_workshop_toggle_btn.custom_minimum_size = Vector2(120.0, 28.0)
	_workshop_toggle_btn.pressed.connect(_on_toggle_workshop_pressed)
	actions.add_child(_workshop_toggle_btn)


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
		"cobblestone":
			return "🧱"
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
			"cobblestone":
				job_key = "hunt"
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
		_workshop_toggle_btn.text = "Cobble: %s" % ("OFF" if _workshop_paused else "ON")
		_workshop_toggle_btn.disabled = int(_buildings["workshop"]) <= 0
	if _fast_recruit_btn != null and is_instance_valid(_fast_recruit_btn):
		_fast_recruit_btn.disabled = _agents.get_agent_count() >= _housing_capacity()
	if _fast_house_btn != null and is_instance_valid(_fast_house_btn):
		_fast_house_btn.disabled = false
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
	_spawn_floating_text(_tile_center(_camp_tile), "Cobble %s" % ("paused" if _workshop_paused else "resumed"), Color(0.72, 0.88, 1.0, 1.0))


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
	_rebalance_settler_weapons()
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
	_rebalance_settler_weapons()
	_spawn_floating_text(_tile_center(_camp_tile), "+2 Housing", Color(0.95, 0.87, 0.45, 1.0))


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
	_rebalance_settler_weapons()


func _set_pinned_settler_tool(tool_id: int) -> void:
	if _pinned_agent_idx < 0:
		return
	if _pinned_agent_idx >= _settler_tools.size():
		return
	_settler_tools[_pinned_agent_idx] = tool_id
	_record_agent_action(_pinned_agent_idx, "Tool equipped: %s" % _tool_name_for_id(tool_id))


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
	_settler_mgr.ensure_core_buffers(count, _rng, WEAPON_SPEAR, TOOL_HAND)
	_settler_happiness = _settler_mgr.happiness
	_settler_attack_cooldowns = _settler_mgr.attack_cooldowns
	_settler_weapons = _settler_mgr.weapons
	_settler_tools = _settler_mgr.tools
	_sync_settler_think_buffers(count)
	_rebalance_settler_weapons()
	for i in count:
		if not _agent_recent_actions.has(i):
			_agent_recent_actions[i] = []
		if not _agent_last_state.has(i):
			_agent_last_state[i] = ""
	# Assign names to any new settlers
	while _settler_names.size() < count:
		var idx: int = _settler_names.size()
		if idx < SETTLER_NAMES.size():
			_settler_names.append(SETTLER_NAMES[idx])
		else:
			_settler_names.append("Settler %d" % (idx + 1))
	if _pinned_agent_idx >= count:
		_pinned_agent_idx = -1
	_cleanup_resource_claims(count)


func _cleanup_resource_claims(settler_count: int) -> void:
	_resource_mgr.cleanup_claims(settler_count, Callable(self, "_tile_key"))


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


func _think_jitter() -> float:
	if settler_think_jitter_sec <= 0.0:
		return 0.0
	return _rng.randf_range(-settler_think_jitter_sec, settler_think_jitter_sec)


func _schedule_next_think(index: int, now_sec: float, idle: bool = false) -> void:
	if index < 0 or index >= _settler_next_think_time.size():
		return
	var base: float = settler_idle_think_interval_sec if idle else settler_active_think_interval_sec
	_settler_next_think_time[index] = now_sec + maxf(0.1, base + _think_jitter())


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


func _tool_for_settler(index: int) -> int:
	if index < 0 or index >= _settler_tools.size():
		return TOOL_HAND
	return int(_settler_tools[index])


func _tool_harvest_mult(index: int, job: int) -> float:
	var tool_id: int = _tool_for_settler(index)
	match tool_id:
		TOOL_AXE:
			if job == JOB_LUMBER:
				return 1.35
			if job == JOB_STONE:
				return 0.9
			return 0.95
		TOOL_PICK:
			if job == JOB_STONE:
				return 1.35
			if job == JOB_LUMBER:
				return 0.9
			return 0.95
		TOOL_SCYTHE:
			if job == JOB_FARM:
				return 1.3
			return 0.9
		_:
			return 1.0


func _tool_effect_text(index: int, job: int) -> String:
	var m: float = _tool_harvest_mult(index, job)
	if m > 1.001:
		return "+%d%% harvest" % int(round((m - 1.0) * 100.0))
	if m < 0.999:
		return "-%d%% off-role" % int(round((1.0 - m) * 100.0))
	return "No bonus"


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


func _bootstrap_10k_stress_test() -> void:
	if not run_10k_settler_stress_test:
		return
	var target_count: int = maxi(400, stress_test_settler_target)
	var current_count: int = _agents.get_agent_count()
	if current_count >= target_count:
		return
	if _agents.infinite_mode:
		_agents.add_agents(target_count - current_count, _target)
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
	elif "stone" in lower or "mine" in lower or "cobble" in lower:
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
			_show_building_hover(house_idx)
		else:
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
	var weapon_name: String = _weapon_name_for_id(_weapon_for_settler(i))
	var tool_name: String = _tool_name_for_id(_tool_for_settler(i))
	var tool_effect: String = _tool_effect_text(i, job)

	var pinned_tag: String = " (Pinned)" if i == _pinned_agent_idx else ""
	var settler_name: String = _settler_names[i] if i < _settler_names.size() else "Settler %d" % (i + 1)
	_hover_title_label.text = "%s%s" % [settler_name, pinned_tag]
	_hover_body_label.text = (
		"State: %s\n"
		+ "Job: %s\n"
		+ "Weapon: %s\n"
		+ "Tool: %s (%s)\n"
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


func _show_building_hover(house_idx: int) -> void:
	# Gather residents of this house
	var residents: Array[String] = []
	for i in _settler_homes.size():
		if int(_settler_homes[i]) == house_idx:
			var name_str: String = _settler_names[i] if i < _settler_names.size() else "Settler %d" % (i + 1)
			residents.append(name_str)

	_hover_title_label.text = "House %d" % (house_idx + 1)
	if residents.is_empty():
		_hover_body_label.text = "[color=#aaaaaa]Unoccupied[/color]"
	else:
		var lines: Array[String] = []
		for r in residents:
			lines.append("• %s" % r)
		_hover_body_label.text = "\n".join(lines)

	_job_btn_row.visible = false
	_tool_btn_row.visible = false
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
	hint.text = "If no free colonist is available, + will pull one from another job evenly."
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.modulate = Color(0.86, 0.9, 0.98, 0.9)
	hint.add_theme_font_size_override("font_size", 11)
	page.add_child(hint)

	var scouting_gate := Label.new()
	scouting_gate.text = "Scouting scales fluidly with support structures (Scout Lodge, Sawmill, Quarry, Workshop, Storehouse, Armory)."
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
	var max_rank: int = int(item.get("max_rank", 1))
	if rank >= max_rank:
		buy.disabled = true
		buy.text = "Maxed"

	return panel


func _upgrade_cost_for_rank(item: Dictionary, rank: int) -> Dictionary:
	var base: Dictionary = item["cost"]
	var scale: float = float(item.get("cost_scale", 1.0))
	var out: Dictionary = {}
	for key in base.keys():
		out[key] = ceil(float(base[key]) * pow(scale, rank))
	return out


func _upgrade_rank_text(item: Dictionary) -> String:
	var id: String = String(item["id"])
	var rank: int = int(_upgrade_ranks.get(id, 0))
	var max_rank: int = int(item.get("max_rank", 1))
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


func _housing_capacity() -> int:
	return 1 + int(_buildings["house"]) * HOUSE_CAPACITY


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
	return JOB_STONE


func _distribute_jobs_evenly() -> void:
	var settlers: int = _agents.get_agent_count()
	if settlers <= 0:
		return
	# Spread across the 5 roles using floored integer quotient and
	# distribute any remainder one-per-role from the top.
	var jobs: Array[String] = ["farm", "lumber", "stone", "hunt", "scout"]
	var n: int = jobs.size()
	var base: int = settlers / n
	var remainder: int = settlers % n
	for idx in n:
		_job_counts[jobs[idx]] = base + (1 if idx < remainder else 0)
	_clamp_job_counts()


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
	for i in settlers:
		var home_idx: int = i / HOUSE_CAPACITY
		if home_idx < _house_tiles.size():
			_settler_homes[i] = home_idx


func _home_center_for_settler(index: int) -> Vector2:
	if index < 0 or index >= _settler_homes.size():
		return _tile_center(_camp_tile)
	var home_idx: int = _settler_homes[index]
	if home_idx < 0 or home_idx >= _house_tiles.size():
		return _tile_center(_camp_tile)
	return _tile_center(_house_tiles[home_idx])


func _is_tile_claimed_by_other(tile: Vector2i, settler_index: int) -> bool:
	return _resource_mgr.is_tile_claimed_by_other(_tile_key(tile), settler_index)


func _release_resource_claim(settler_index: int) -> void:
	if not _settler_resource_targets.has(settler_index):
		return
	var tile: Vector2i = _settler_resource_targets[settler_index]
	_resource_mgr.release_resource_claim(settler_index, _tile_key(tile))


func _try_claim_resource_tile(settler_index: int, tile: Vector2i) -> bool:
	var key: String = _tile_key(tile)
	var prev_key: String = ""
	if _settler_resource_targets.has(settler_index):
		var prev: Vector2i = _settler_resource_targets[settler_index]
		prev_key = _tile_key(prev)
	return _resource_mgr.try_claim_resource_tile(settler_index, tile, key, prev_key)


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
	else:
		var rtype: int = RES_TREE if job == JOB_LUMBER else RES_STONE
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
	else:
		var rtype: int = RES_TREE if job == JOB_LUMBER else RES_STONE
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


func _nearest_resource_tile(from_tile: Vector2i, res_type: int, claimant_index: int = -1, max_radius: int = 26) -> Vector2i:
	for r in range(0, max_radius + 1):
		for y in range(from_tile.y - r, from_tile.y + r + 1):
			for x in range(from_tile.x - r, from_tile.x + r + 1):
				if abs(x - from_tile.x) != r and abs(y - from_tile.y) != r:
					continue
				var tile := Vector2i(x, y)
				if _resource_type_at(tile) != res_type:
					continue
				if _resource_left(tile, res_type) <= 0.0:
					continue
				if claimant_index >= 0 and _is_tile_claimed_by_other(tile, claimant_index):
					continue
				return tile
	return Vector2i(-9999, -9999)


func _nearest_food_tile(from_tile: Vector2i, claimant_index: int = -1, max_radius: int = 32) -> Vector2i:
	for r in range(0, max_radius + 1):
		for y in range(from_tile.y - r, from_tile.y + r + 1):
			for x in range(from_tile.x - r, from_tile.x + r + 1):
				if abs(x - from_tile.x) != r and abs(y - from_tile.y) != r:
					continue
				var tile := Vector2i(x, y)
				var rt: int = _resource_type_at(tile)
				if rt != RES_APPLE and rt != RES_BERRY_BLUE and rt != RES_BERRY_RASP and rt != RES_BERRY_BLACK:
					continue
				if _resource_left(tile, rt) < FOOD_MIN_HARVEST:
					continue
				if claimant_index >= 0 and _is_tile_claimed_by_other(tile, claimant_index):
					continue
				return tile
	return Vector2i(-9999, -9999)


func _nearest_wildlife_pos(from_pos: Vector2, prefer_wolf: bool = true) -> Vector2:
	var best := from_pos
	var best_d: float = 1e9
	for w in _wildlife:
		var typ: int = int(w["type"])
		if prefer_wolf and typ != ANIMAL_WOLF:
			continue
		var d: float = from_pos.distance_to(w["pos"])
		if d < best_d:
			best_d = d
			best = w["pos"]
	return best


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
	var result: Dictionary = _settler_decision_system.run({
		"delta": delta,
		"is_night": is_night,
		"agents": agents,
		"count": count,
		"now_sec": now_sec,
		"targets": targets,
		"decision_budget": maxi(1, settler_decision_budget_per_tick),
		"night_plan_budget": maxi(1, night_planning_budget_per_tick),
		"offscreen_decision_throttle_enabled": offscreen_decision_throttle_enabled,
		"offscreen_decision_stride": maxi(1, offscreen_decision_stride),
		"offscreen_night_planning_stride": maxi(1, offscreen_night_planning_stride),
		"decision_tick_counter": _settler_decision_tick_counter,
		"view_min": view_min,
		"view_max": view_max,
		"settler_decision_cursor": _settler_decision_cursor,
		"settler_decisions_this_tick": 0,
		"invalid_tile": Vector2i(-9999, -9999),
		"global_target": _target,
		"camp_tile": _camp_tile,
		"settler_next_think_time": _settler_next_think_time,
		"settler_think_state": _settler_think_state,
		"settler_idle_time": _settler_idle_time,
		"settler_last_pos": _settler_last_pos,
		"agent_last_state": _agent_last_state,
		"settler_resource_targets": _settler_resource_targets,
		"settler_day_plan_targets": _settler_day_plan_targets,
		"settler_day_plan_job": _settler_day_plan_job,
		"poi_sites": _poi_sites,
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
		"food_min_harvest": FOOD_MIN_HARVEST,
		"settler_arrival_rethink_distance_px": settler_arrival_rethink_distance_px,
		"settler_stuck_rethink_sec": settler_stuck_rethink_sec,
		"settler_min_progress_px": settler_min_progress_px,
		"cb_think_jitter": Callable(self, "_think_jitter"),
		"cb_current_poi_target_index": Callable(self, "_current_poi_target_index"),
		"cb_tile_center": Callable(self, "_tile_center"),
		"cb_select_poi_scout": Callable(self, "_select_poi_scout"),
		"cb_update_day_plan_for_settler": Callable(self, "_update_day_plan_for_settler"),
		"cb_world_to_tile": Callable(self, "_world_to_tile"),
		"cb_job_for_settler": Callable(self, "_job_for_settler"),
		"cb_segment_world_target": Callable(self, "_segment_world_target"),
		"cb_home_center_for_settler": Callable(self, "_home_center_for_settler"),
		"cb_schedule_next_think": Callable(self, "_schedule_next_think"),
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
	})
	_settler_decisions_this_tick = int(result["settler_decisions_this_tick"])
	_settler_decision_cursor = int(result["settler_decision_cursor"])
	_settler_next_think_time = result["settler_next_think_time"]
	_settler_think_state = result["settler_think_state"]
	_settler_idle_time = result["settler_idle_time"]
	_settler_last_pos = result["settler_last_pos"]
	_agent_last_state = result["agent_last_state"]
	_agents.set_agent_targets(result["targets"])


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
	_rebalance_settler_weapons()
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
	var max_rank: int = int(item.get("max_rank", 1))
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
	_ensure_upgrade_visual_tile(id)
	_apply_upgrade_effect(id)
	rank_label.text = _upgrade_rank_text(item)
	if rank >= max_rank:
		buy_button.disabled = true
		buy_button.text = "Maxed"
	else:
		cost_label.text = _cost_to_string(_upgrade_cost_for_rank(item, rank))
	_spawn_upgrade_burst(_target, _upgrade_color_for(id))
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
	elif id in ["sawmill", "quarry", "workshop", "storehouse", "armory", "scout_lodge"]:
		_place_building_near_target(id)
	if id == "scout_lodge":
		_spawn_floating_text(_tile_center(_camp_tile), "Scouting unlocked", Color(0.58, 0.86, 1.0, 1.0))
		_clamp_job_counts()
		if not was_scouting_unlocked:
			_try_spawn_poi()
	_rebalance_settler_weapons()
	_spawn_upgrade_burst(_target, Color(0.7, 0.85, 1.0, 1.0))
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
		_rebalance_settler_weapons()
		_record_agent_action(old_count, "Recruited into the village")
		_spawn_floating_text(_target, "+1 Settler", Color(0.65, 0.95, 1.0, 1.0))
		_spawn_upgrade_burst(_target, Color(0.65, 0.95, 1.0, 1.0))
		_kick_camera(6.0)
		_pulse_row(row_panel, Color(0.15, 0.3, 0.34, 0.96))
		return

	if action_id == "house":
		_spend_cost(cost)
		_buildings["house"] = int(_buildings["house"]) + 1
		_place_house_near_target()
		_recompute_homes()
		_rebalance_settler_weapons()
		_spawn_floating_text(_target, "+2 Housing", Color(0.95, 0.87, 0.45, 1.0))
		_spawn_upgrade_burst(_target, Color(0.95, 0.87, 0.45, 1.0))
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
	_rebalance_settler_weapons()


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
	var occupied: Array[Vector2i] = [_camp_tile]
	occupied.append_array(_house_tiles)
	occupied.append_array(_sawmill_tiles)
	occupied.append_array(_quarry_tiles)
	occupied.append_array(_workshop_tiles)
	occupied.append_array(_storehouse_tiles)
	occupied.append_array(_armory_tiles)
	occupied.append_array(_scout_lodge_tiles)
	for radius in range(1, 14):
		for y in range(base.y - radius, base.y + radius + 1):
			for x in range(base.x - radius, base.x + radius + 1):
				if abs(x - base.x) != radius and abs(y - base.y) != radius:
					continue
				var tile := Vector2i(x, y)
				if occupied.has(tile):
					continue
				tile_array.append(tile)
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
				if _house_tiles.has(tile) or tile == _camp_tile:
					continue
				_house_tiles.append(tile)
				_reveal_around_tile(tile, 3)
				return


func _apply_upgrade_effect(id: String) -> void:
	match id:
		"vol_lumber":
			_tree_yield_mult *= 1.35
		"vol_stone":
			_stone_yield_mult *= 1.35
		"vol_geology":
			_stone_yield_mult *= 1.25
		"vol_forage":
			_food_gather_mult *= 1.3
		"vol_hoard":
			_storehouse_mult *= 1.7
			_happiness_gain_mult *= 0.92
		"eff_speed":
			_agents.tiles_per_second *= 1.18
		"eff_convert":
			_convert_mult *= 1.5
		"eff_quarry_ops":
			_quarry_passive_mult *= 1.6
		"eff_ration":
			_food_consume_mult *= 0.8
			_happiness_loss_mult *= 1.12
		"eff_campfire":
			_happiness_gain_mult *= 1.4
		"spec_forestry":
			_buildings["sawmill"] = int(_buildings["sawmill"]) + 1
		"spec_masonry":
			_buildings["quarry"] = int(_buildings["quarry"]) + 1
		"spec_hunting":
			_settler_combat_damage_mult *= 1.35
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
			_settler_attack_speed_mult *= 1.2
		"def_horns":
			_wolf_raid_size_mult *= 0.85
		"def_training":
			_happiness_loss_mult *= 0.88
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
			_melee_damage_mult *= 1.16
		"cmb_drills":
			_settler_attack_speed_mult *= 1.08
			_weapon_cluster_strength = minf(0.42, _weapon_cluster_strength + 0.05)
		"scout_training":
			_poi_discovery_radius *= 1.16
		"scout_survey":
			_poi_spawn_interval_mult *= 0.88
		"scout_beacons":
			_poi_discovery_radius += 3.6
		"scout_salvage":
			_poi_reward_mult *= 1.18
		_:
			pass
	_rebalance_settler_weapons()


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
	for key in ["food", "lumber", "stone", "cobblestone"]:
		if cost.has(key):
			parts.append("%s %d" % [_resource_cost_icon(String(key)), int(cost[key])])
	return "Cost: " + ", ".join(parts)


func _building_effect_text(id: String) -> String:
	match id:
		"house":
			return "Adds 2 housing slots"
		"sawmill":
			return "Trees yield +1 each harvest"
		"quarry":
			return "Stone yield +1 each harvest"
		"workshop":
			return "Converts stone -> cobblestone"
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


func _biome_at(tile: Vector2i) -> int:
	var macro_x: int = floori(tile.x / 22.0)
	var macro_y: int = floori(tile.y / 22.0)
	var r: float = _rand01(macro_x, macro_y, _world_seed)
	if r < 0.2:
		return 0
	elif r < 0.45:
		return 1
	elif r < 0.7:
		return 2
	elif r < 0.9:
		return 3
	return 4


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
		_:
			return Color(0.15, 0.2, 0.18, 1.0)


func _resource_type_at(tile: Vector2i) -> int:
	var biome: int = _biome_at(tile)
	var r: float = _rand01(tile.x, tile.y, _world_seed + 17)
	var rf: float = _rand01(tile.x, tile.y, _world_seed + 333)  # food subtype roll
	if biome == 1:  # forest
		if r < 0.50:
			# 15% of forest trees are apple trees
			if rf < 0.15:
				return RES_APPLE
			return RES_TREE
		if r < 0.65:
			# blackberry/blueberry bushes in forest undergrowth
			return RES_BERRY_BLACK if rf < 0.5 else RES_BERRY_BLUE
		return RES_NONE
	if biome == 0:  # plains
		if r < 0.13:
			return RES_APPLE if rf < 0.25 else RES_TREE
		if r < 0.22:
			return RES_BERRY_RASP  # raspberry on plains
		if r > 0.93:
			return RES_STONE
		return RES_NONE
	if biome == 2:  # hills
		if r < 0.18:
			return RES_TREE
		if r < 0.28:
			return RES_BERRY_RASP if rf < 0.6 else RES_BERRY_BLACK
		if r < 0.62:
			return RES_STONE
		return RES_NONE
	if biome == 3:  # mountain
		if r < 0.68:
			return RES_STONE
		if r > 0.96:
			return RES_TREE
		return RES_NONE
	if biome == 4:  # marsh
		if r < 0.15:
			return RES_TREE
		if r < 0.35:
			return RES_BERRY_BLUE  # blueberries love marsh
		return RES_NONE
	return RES_NONE


func _resource_initial_amount(tile: Vector2i, res_type: int) -> float:
	var r: float = _rand01(tile.x, tile.y, _world_seed + 991)
	var durability_mult: float = maxf(1.0, resource_node_yield_mult) * _resource_distance_multiplier(tile)
	if res_type == RES_TREE:
		return (4.0 + floor(r * 7.0)) * durability_mult
	if res_type == RES_STONE:
		return (5.0 + floor(r * 9.0)) * durability_mult
	if res_type == RES_APPLE:
		return (3.0 + floor(r * 5.0)) * durability_mult  # regrows — handled by slow respawn
	if res_type == RES_BERRY_BLUE or res_type == RES_BERRY_RASP or res_type == RES_BERRY_BLACK:
		return (3.0 + floor(r * 5.0)) * durability_mult
	return 0.0


func _resource_distance_multiplier(tile: Vector2i) -> float:
	var dist_tiles: float = float(tile.distance_to(_camp_tile))
	return 1.0 + minf(3.0, dist_tiles / 35.0)


func _resource_left(tile: Vector2i, res_type: int) -> float:
	var key: String = _tile_key(tile)
	if _resource_remaining.has(key):
		return float(_resource_remaining[key])
	return _resource_initial_amount(tile, res_type)


func _set_resource_left(tile: Vector2i, value: float) -> void:
	var key: String = _tile_key(tile)
	var clamped: float = maxf(0.0, value)
	_resource_remaining[key] = clamped
	if clamped <= 0.0 and _resource_claims.has(key):
		var owner: int = int(_resource_claims[key])
		if _settler_resource_targets.has(owner):
			var owner_tile: Vector2i = _settler_resource_targets[owner]
			if _tile_key(owner_tile) == key:
				_settler_resource_targets.erase(owner)
				_settler_day_plan_targets.erase(owner)
				_settler_day_plan_job.erase(owner)
		_resource_claims.erase(key)
	if clamped <= 0.0:
		var plan_keys: Array = _settler_day_plan_targets.keys()
		for idx_v in plan_keys:
			var idx: int = int(idx_v)
			var planned_tile: Vector2i = _settler_day_plan_targets[idx]
			if _tile_key(planned_tile) == key:
				_settler_day_plan_targets.erase(idx)
				_settler_day_plan_job.erase(idx)
	_mark_tile_dirty(tile)


func _rand01(x: int, y: int, seed: int) -> float:
	var h: int = x * 374761393 + y * 668265263 + seed * 982451653
	h = h ^ (h >> 13)
	h = h * 1274126177
	h = h ^ (h >> 16)
	return float(h & 0x7fffffff) / 2147483647.0


func _spawn_collect_feedback(pos: Vector2, text: String, color: Color) -> void:
	_spawn_floating_text(pos, text, color)
	for i in 6:
		_collect_particles.append({
			"pos": pos,
			"vel": Vector2(_rng.randf_range(-22.0, 22.0), _rng.randf_range(-38.0, -12.0)),
			"size": _rng.randf_range(1.4, 2.5),
			"color": color,
			"t": 0.0,
			"dur": _rng.randf_range(0.35, 0.62),
		})


func _pulse_row(row_panel: PanelContainer, tint: Color) -> void:
	var style: StyleBoxFlat = row_panel.get_theme_stylebox("panel").duplicate()
	var base_color := style.bg_color
	style.bg_color = tint
	row_panel.add_theme_stylebox_override("panel", style)
	var tw := create_tween()
	tw.set_trans(Tween.TRANS_CUBIC)
	tw.set_ease(Tween.EASE_OUT)
	tw.tween_method(func(v: Color): style.bg_color = v, tint, base_color, 0.34)


func _spawn_upgrade_burst(pos: Vector2, color: Color) -> void:
	_upgrade_bursts.append({
		"pos": pos,
		"color": color,
		"t": 0.0,
		"dur": 0.65,
	})


func _update_upgrade_bursts(delta: float) -> void:
	for i in range(_upgrade_bursts.size() - 1, -1, -1):
		var b: Dictionary = _upgrade_bursts[i]
		b["t"] = float(b["t"]) + delta
		if float(b["t"]) >= float(b["dur"]):
			_upgrade_bursts.remove_at(i)
		else:
			_upgrade_bursts[i] = b


func _spawn_floating_text(pos: Vector2, text: String, color: Color) -> void:
	_floating_texts.append({
		"pos": pos + Vector2(8.0, -6.0),
		"text": text,
		"color": color,
		"t": 0.0,
		"dur": 0.85,
	})


func _update_floating_texts(delta: float) -> void:
	for i in range(_floating_texts.size() - 1, -1, -1):
		var ft: Dictionary = _floating_texts[i]
		ft["t"] = float(ft["t"]) + delta
		if float(ft["t"]) >= float(ft["dur"]):
			_floating_texts.remove_at(i)
		else:
			_floating_texts[i] = ft


func _update_collection_particles(delta: float) -> void:
	for i in range(_collect_particles.size() - 1, -1, -1):
		var p: Dictionary = _collect_particles[i]
		p["t"] = float(p["t"]) + delta
		p["vel"] = Vector2(p["vel"].x, p["vel"].y + 65.0 * delta)
		p["pos"] = Vector2(p["pos"].x, p["pos"].y) + Vector2(p["vel"].x, p["vel"].y) * delta
		if float(p["t"]) >= float(p["dur"]):
			_collect_particles.remove_at(i)
		else:
			_collect_particles[i] = p
	if _collect_particles.is_empty():
		_collect_particle_multimesh.instance_count = 0
		_collect_particle_multimesh.visible_instance_count = 0


func _kick_camera(amount: float) -> void:
	var dir := Vector2(_rng.randf_range(-1.0, 1.0), _rng.randf_range(-1.0, 1.0)).normalized()
	_camera_kick += dir * amount


func _update_settler_combat(delta: float) -> void:
	var result: Dictionary = _combat_system.run({
		"delta": delta,
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
		"cb_is_night": Callable(self, "_is_night"),
		"cb_agent_positions": Callable(_agents, "get_agent_positions"),
		"cb_weapon_for_settler": Callable(self, "_weapon_for_settler"),
		"cb_weapon_profile": Callable(self, "_weapon_profile"),
		"cb_record_agent_action": Callable(self, "_record_agent_action"),
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
	var stream: AudioStream = load(sound_path)
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
	if _wolf_raid_active:
		base_hit *= 1.0 + _combat_neglect_level() * 0.35
	for i in agents.size():
		var d: float = agents[i].distance_to(strike_pos)
		if d > radius:
			continue
		var defense: float = maxf(0.35, _settler_defense_for_index(i))
		var morale_hit: float = base_hit / defense
		if i < _settler_happiness.size():
			_settler_happiness[i] = clampf(_settler_happiness[i] - morale_hit, 0.0, 1.0)


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
		_:
			return false

	_buildings[best_type] = maxi(0, int(_buildings.get(best_type, 0)) - 1)
	if best_type == "house" or best_type == "scout_lodge":
		_clamp_job_counts()
	_rebalance_settler_weapons()
	var label: String = "House" if best_type == "house" else best_type.capitalize()
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


func _try_spawn_wildlife() -> void:
	if _wildlife.size() >= 20:
		return
	if not _is_night():
		return
	var agents: PackedVector2Array = _agents.get_agent_positions()
	if agents.is_empty():
		return
	var center: Vector2 = agents[0]
	# Spawn 120–280px away from first agent, on explored tiles
	var rng2 := RandomNumberGenerator.new()
	rng2.seed = int(Time.get_ticks_msec())
	for _attempt in 12:
		var angle: float = rng2.randf() * TAU
		var dist: float = rng2.randf_range(120.0, 280.0)
		var pos := center + Vector2(cos(angle), sin(angle)) * dist
		var tile := _world_to_tile(pos)
		if not _is_explored(tile):
			continue
		var biome: int = _biome_at(tile)
		# Night spawns skew toward wolves, especially during raids.
		var roll: float = rng2.randf()
		var typ: int
		if biome == 1 or biome == 0:
			if _wolf_raid_active:
				typ = ANIMAL_WOLF if roll < 0.85 else ANIMAL_BEAR
			else:
				typ = ANIMAL_DEER if roll < 0.35 else (ANIMAL_WOLF if roll < 0.9 else ANIMAL_BEAR)
		elif biome == 2:
			if _wolf_raid_active:
				typ = ANIMAL_WOLF if roll < 0.8 else ANIMAL_BEAR
			else:
				typ = ANIMAL_DEER if roll < 0.25 else (ANIMAL_WOLF if roll < 0.75 else ANIMAL_BEAR)
		else:
			continue
		_wildlife.append({
			"type": typ,
			"pos": pos,
			"vel": Vector2.ZERO,
			"hp": _wildlife_max_hp(typ),
			"max_hp": _wildlife_max_hp(typ),
			"state": "wander",
			"target_pos": pos,
			"attack_cd": 0.0,
			"wander_timer": 0.0,
			"wander_dir": Vector2(cos(rng2.randf() * TAU), sin(rng2.randf() * TAU)),
			"chase_timer": 0.0,
			"phase": rng2.randf() * TAU,
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
		ANIMAL_DEER: return 4.0
		ANIMAL_WOLF: return 2.0
		ANIMAL_BEAR: return 10.0
	return 2.0


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


func _draw_wildlife() -> void:
	for w in _wildlife:
		var pos: Vector2 = w["pos"]
		var tile := _world_to_tile(pos)
		if not _is_explored(tile):
			continue
		var typ: int = int(w["type"])
		var hp: float = float(w["hp"])
		var max_hp: float = float(w["max_hp"])
		match typ:
			ANIMAL_DEER:
				# Small tan oval
				draw_circle(pos, 4.5, Color(0.82, 0.68, 0.42, 0.95))
				draw_circle(pos + Vector2(0.0, -3.5), 2.2, Color(0.72, 0.58, 0.34, 0.95))  # head
			ANIMAL_WOLF:
				# Darker gray, slightly larger
				draw_circle(pos, 5.0, Color(0.55, 0.55, 0.6, 0.95))
				draw_circle(pos + Vector2(0.0, -3.5), 2.5, Color(0.42, 0.42, 0.46, 0.95))
				# Ears
				draw_line(pos + Vector2(-2.5, -5.0), pos + Vector2(-4.0, -8.0), Color(0.42, 0.42, 0.46), 1.2)
				draw_line(pos + Vector2(2.5, -5.0), pos + Vector2(4.0, -8.0), Color(0.42, 0.42, 0.46), 1.2)
				if _is_night():
					draw_circle(pos + Vector2(-1.3, -3.7), 0.9, Color(1.0, 0.14, 0.14, 0.95))
					draw_circle(pos + Vector2(1.3, -3.7), 0.9, Color(1.0, 0.14, 0.14, 0.95))
			ANIMAL_BEAR:
				# Large brown body
				draw_circle(pos, 8.0, Color(0.52, 0.32, 0.14, 0.95))
				draw_circle(pos + Vector2(0.0, -5.5), 4.0, Color(0.44, 0.26, 0.1, 0.95))
				# Ears
				draw_circle(pos + Vector2(-4.0, -8.5), 2.0, Color(0.44, 0.26, 0.1, 0.95))
				draw_circle(pos + Vector2(4.0, -8.5), 2.0, Color(0.44, 0.26, 0.1, 0.95))
				if _is_night():
					draw_circle(pos + Vector2(-1.8, -5.8), 1.1, Color(0.96, 0.12, 0.12, 0.95))
					draw_circle(pos + Vector2(1.8, -5.8), 1.1, Color(0.96, 0.12, 0.12, 0.95))

		# HP bar only if damaged
		if hp < max_hp:
			var bar_w: float = 14.0 if typ == ANIMAL_BEAR else 10.0
			var bar_y: float = pos.y - (14.0 if typ == ANIMAL_BEAR else 10.0)
			draw_rect(Rect2(pos.x - bar_w * 0.5, bar_y, bar_w, 2.0), Color(0.3, 0.1, 0.1, 0.8))
			draw_rect(Rect2(pos.x - bar_w * 0.5, bar_y, bar_w * (hp / max_hp), 2.0), Color(0.85, 0.25, 0.25, 0.9))


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
