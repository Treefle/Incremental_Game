extends Node2D

const TILE_SIZE: int = 16
const MINIMAP_TILES: int = 96

const RES_NONE: int = 0
const RES_TREE: int = 1
const RES_STONE: int = 2
const JOB_FARM: int = 0
const JOB_LUMBER: int = 1
const JOB_STONE: int = 2
const HOUSE_CAPACITY: int = 2

@onready var _agents: AgentSystem = $AgentSystem
@onready var _label: Label = $UI/Label
@onready var _camera: Camera2D = $Camera2D

var _target: Vector2 = Vector2.ZERO
var _world_seed: int = 912713

var _vision_radius: int = 4
var _watchtower_radius: int = 8
var _auto_watchtowers: bool = false
var _max_watchtowers: int = 20
var _watchtowers: Array[Vector2i] = []
var _explored: Dictionary = {}

var _resource_remaining: Dictionary = {}
var _harvest_tick: float = 0.0
var _ai_tick: float = 0.0
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
}

var _camp_tile: Vector2i = Vector2i.ZERO
var _house_tiles: Array[Vector2i] = []
var _settler_homes: PackedInt32Array
var _job_counts := {
	"farm": 1,
	"lumber": 0,
	"stone": 0,
}
var _job_count_labels: Dictionary = {}

const BUILDING_RECIPES := {
	"House": {"id": "house", "cost": {"lumber": 24.0, "cobblestone": 8.0}},
	"Sawmill": {"id": "sawmill", "cost": {"lumber": 35.0}},
	"Quarry": {"id": "quarry", "cost": {"lumber": 30.0}},
	"Workshop": {"id": "workshop", "cost": {"lumber": 40.0, "stone": 18.0}},
	"Storehouse": {"id": "storehouse", "cost": {"lumber": 55.0, "cobblestone": 25.0}},
}

const POP_ACTIONS := {
	"recruit": {"name": "Recruit Settler", "effect": "+1 colonist (requires available housing)", "cost": {"food": 26.0, "lumber": 10.0}},
	"house": {"name": "Build House", "effect": "+2 housing (settlers return nightly)", "cost": {"lumber": 22.0, "cobblestone": 7.0}},
}

const UPGRADE_DATA := {
	"Volume": [
		{"id": "vol_lumber_1", "name": "Timber Crews", "effect": "Tree harvest x2", "cost": {"lumber": 45.0}},
		{"id": "vol_stone_1", "name": "Heavy Picks", "effect": "Stone harvest x2", "cost": {"lumber": 35.0, "stone": 20.0}},
	],
	"Efficiency": [
		{"id": "eff_speed_1", "name": "Road Kits", "effect": "Colonist speed +80%", "cost": {"lumber": 55.0}},
		{"id": "eff_convert_1", "name": "Stone Saws", "effect": "Cobble conversion x2", "cost": {"lumber": 50.0, "stone": 40.0}},
	],
	"Specialization": [
		{"id": "spec_forestry_1", "name": "Forester Doctrine", "effect": "Sawmills +1 yield", "cost": {"lumber": 90.0, "cobblestone": 20.0}},
		{"id": "spec_masonry_1", "name": "Mason Doctrine", "effect": "Quarries +1 yield", "cost": {"lumber": 70.0, "cobblestone": 30.0}},
	],
	"Vision & Exploration": [
		{"id": "vision_1", "name": "Surveyor Lenses", "effect": "Vision radius 4 -> 7", "cost": {"lumber": 40.0}},
		{"id": "vision_2", "name": "Eagle Optics", "effect": "Vision radius 7 -> 11", "cost": {"lumber": 80.0, "cobblestone": 20.0}},
		{"id": "tower_1", "name": "Watchtower Network", "effect": "Clicks place permanent reveal towers", "cost": {"lumber": 75.0, "cobblestone": 35.0}},
		{"id": "tower_2", "name": "Cartography Guild", "effect": "Tower radius +70%", "cost": {"lumber": 120.0, "cobblestone": 70.0}},
	],
}

var _purchased_upgrades: Dictionary = {}

var _upgrade_panel: PanelContainer
var _upgrade_toggle: Button
var _panel_open: bool = false
var _drawer_width: float = 390.0

var _resource_labels: Dictionary = {}
var _building_labels: Dictionary = {}
var _hovered_agent_idx: int = -1
var _pinned_agent_idx: int = -1
var _hover_probe_radius_px: float = 12.0
var _hover_panel: PanelContainer
var _hover_title_label: Label
var _hover_body_label: RichTextLabel
var _agent_recent_actions: Dictionary = {}
var _agent_last_state: Dictionary = {}
var _settler_resource_targets: Dictionary = {}  # index -> Vector2i, cached resource tile
var _settler_job_overrides: Dictionary = {}  # index -> int, per-settler job override
var _job_btn_row: HBoxContainer

var _minimap_rect: TextureRect
var _minimap_texture: ImageTexture
var _minimap_image: Image
var _minimap_accum: float = 0.0
var _fog_reveal_accum: float = 0.0
var _minimap_scale: float = 2.6

var _upgrade_bursts: Array[Dictionary] = []
var _floating_texts: Array[Dictionary] = []
var _collect_particles: Array[Dictionary] = []
var _camera_base_pos: Vector2
var _camera_kick: Vector2 = Vector2.ZERO
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	_camera.enabled = true
	_camera_base_pos = _camera.position

	if _agents.agent_count < 1:
		_agents.agent_count = 1

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
	_clamp_job_counts()
	_sync_agent_tracking()

	_reveal_around_world(_target, 6)

	_build_resource_ui()
	_build_minimap_ui()
	_build_upgrade_ui()
	_build_hover_ui()

	queue_redraw()


func _process(delta: float) -> void:
	_sync_agent_tracking()
	_update_day_cycle(delta)
	_update_settler_targets(delta)
	_update_hovered_agent()
	_update_economy(delta)
	_update_upgrade_bursts(delta)
	_update_floating_texts(delta)
	_update_collection_particles(delta)
	_update_camera_kick(delta)
	_update_resource_ui()
	_update_hover_ui()

	_minimap_accum += delta
	if _minimap_accum >= 0.08:
		_minimap_accum = 0.0
		_update_minimap()

	_fog_reveal_accum += delta
	if _fog_reveal_accum >= 0.1:
		_fog_reveal_accum = 0.0
		var agents: PackedVector2Array = _agents.get_agent_positions()
		for i in agents.size():
			_reveal_around_world(agents[i], _vision_radius)

	var housing: int = _housing_capacity()
	var day_state: String = "Night" if _is_night() else "Day"
	_label.text = (
		"FPS: %d  |  %s  |  Settlers: %d/%d  |  Jobs F/L/S: %d/%d/%d\n"
		+ "LMB terrain set target  |  LMB settler pin  |  RMB/Esc clear pin  |  U upgrades"
	) % [
		Engine.get_frames_per_second(),
		day_state,
		_agents.get_agent_count(),
		housing,
		int(_job_counts["farm"]),
		int(_job_counts["lumber"]),
		int(_job_counts["stone"]),
	]

	queue_redraw()


func _draw() -> void:
	_draw_world_tiles()
	_draw_watchtowers()
	_draw_target()
	_draw_hover_feedback()
	_draw_upgrade_vfx()
	_draw_collection_particles()
	_draw_floating_texts()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		_pinned_agent_idx = -1
		return

	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_U:
		_toggle_upgrade_panel()
		return

	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		_pinned_agent_idx = -1
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

	for y in range(min_y, max_y + 1):
		for x in range(min_x, max_x + 1):
			var tile := Vector2i(x, y)
			var rect := Rect2(x * TILE_SIZE, y * TILE_SIZE, TILE_SIZE, TILE_SIZE)
			if not _is_explored(tile):
				draw_rect(rect, Color(0.015, 0.02, 0.03, 1.0))
				continue

			var biome: int = _biome_at(tile)
			draw_rect(rect, _biome_color(biome))

			var res_type: int = _resource_type_at(tile)
			if res_type != RES_NONE and _resource_left(tile, res_type) > 0.0:
				if res_type == RES_TREE:
					draw_circle(Vector2((x + 0.5) * TILE_SIZE, (y + 0.5) * TILE_SIZE), 3.0, Color(0.1, 0.55, 0.18, 0.95))
				elif res_type == RES_STONE:
					draw_rect(Rect2(x * TILE_SIZE + 4.0, y * TILE_SIZE + 4.0, 8.0, 8.0), Color(0.58, 0.6, 0.64, 0.95))

	# Camp and houses
	draw_rect(Rect2(_camp_tile.x * TILE_SIZE + 2, _camp_tile.y * TILE_SIZE + 2, TILE_SIZE - 4, TILE_SIZE - 4), Color(0.95, 0.73, 0.32, 0.95))
	for home in _house_tiles:
		draw_rect(Rect2(home.x * TILE_SIZE + 2, home.y * TILE_SIZE + 2, TILE_SIZE - 4, TILE_SIZE - 4), Color(0.82, 0.6, 0.34, 0.95))


func _draw_watchtowers() -> void:
	for tile in _watchtowers:
		var center := _tile_center(tile)
		draw_circle(center, 4.5, Color(0.95, 0.86, 0.2, 0.95))
		draw_arc(center, _watchtower_radius * TILE_SIZE, 0.0, TAU, 42, Color(0.95, 0.86, 0.2, 0.14), 1.2)


func _draw_target() -> void:
	draw_circle(_target, 5.0, Color(1.0, 0.2, 0.2, 0.8))
	draw_arc(_target, 10.0, 0.0, TAU, 24, Color(1.0, 0.2, 0.2, 0.5), 1.3)


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
	for p in _collect_particles:
		var alpha: float = 1.0 - clampf(float(p["t"]) / float(p["dur"]), 0.0, 1.0)
		var col: Color = p["color"]
		draw_circle(p["pos"], float(p["size"]), Color(col.r, col.g, col.b, alpha))


func _update_economy(delta: float) -> void:
	_harvest_tick += delta
	if _harvest_tick >= 0.35:
		_harvest_tick = 0.0
		_harvest_resources()

	var workshop_count: int = int(_buildings["workshop"])
	if workshop_count > 0:
		var convert_rate: float = (1.2 + workshop_count * 0.9) * _convert_mult
		var convert: float = minf(_resources["stone"], convert_rate * delta)
		_resources["stone"] -= convert
		_resources["cobblestone"] += convert

	var store_count: int = int(_buildings["storehouse"])
	if store_count > 0:
		_resources["lumber"] += (0.4 * store_count) * delta


func _update_day_cycle(delta: float) -> void:
	_day_time = fmod(_day_time + delta / _day_length_seconds, 1.0)


func _harvest_resources() -> void:
	var agents: PackedVector2Array = _agents.get_agent_positions()
	for i in agents.size():
		var pos: Vector2 = agents[i]
		var job: int = _job_for_settler(i)
		var tile := _world_to_tile(pos)

		if job == JOB_FARM:
			var biome: int = _biome_at(tile)
			var fertile: float = 0.0
			if biome == 0:
				fertile = 1.4
			elif biome == 1:
				fertile = 1.1
			elif biome == 2:
				fertile = 0.8
			if fertile > 0.0:
				var food_gain: float = fertile * (1.0 + float(_buildings["camp"]) * 0.15)
				_resources["food"] += food_gain
				_record_agent_action(i, "Farmed +%d food" % int(ceil(food_gain)))
				_spawn_collect_feedback(_tile_center(tile), "+%d food" % int(ceil(food_gain)), Color(0.95, 0.8, 0.34, 1.0))
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

		var mined: float = minf(left, amount)
		_set_resource_left(tile, left - mined)

		var center := _tile_center(tile)
		if res_type == RES_TREE:
			_resources["lumber"] += mined
			_record_agent_action(i, "Chopped +%d lumber" % int(ceil(mined)))
			_spawn_collect_feedback(center, "+%d lumber" % int(ceil(mined)), Color(0.22, 0.9, 0.34, 1.0))
		else:
			_resources["stone"] += mined
			_record_agent_action(i, "Mined +%d stone" % int(ceil(mined)))
			_spawn_collect_feedback(center, "+%d stone" % int(ceil(mined)), Color(0.8, 0.86, 0.95, 1.0))


func _build_resource_ui() -> void:
	var ui_layer: CanvasLayer = $UI
	var bar := PanelContainer.new()
	bar.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	bar.position = Vector2(12.0, -58.0)
	bar.size = Vector2(460.0, 48.0)
	ui_layer.add_child(bar)

	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.05, 0.08, 0.12, 0.9)
	bg.border_width_left = 1
	bg.border_width_top = 1
	bg.border_width_right = 1
	bg.border_width_bottom = 1
	bg.border_color = Color(0.36, 0.52, 0.63, 0.9)
	bg.corner_radius_top_left = 8
	bg.corner_radius_top_right = 8
	bg.corner_radius_bottom_left = 8
	bg.corner_radius_bottom_right = 8
	bar.add_theme_stylebox_override("panel", bg)

	var row := HBoxContainer.new()
	row.position = Vector2(8.0, 8.0)
	row.size = Vector2(444.0, 32.0)
	row.add_theme_constant_override("separation", 12)
	bar.add_child(row)

	_add_resource_widget(row, "L", "lumber", Color(0.22, 0.84, 0.34, 1.0))
	_add_resource_widget(row, "S", "stone", Color(0.74, 0.8, 0.88, 1.0))
	_add_resource_widget(row, "C", "cobblestone", Color(0.68, 0.72, 0.78, 1.0))
	_add_resource_widget(row, "F", "food", Color(0.95, 0.8, 0.32, 1.0))


func _add_resource_widget(parent: HBoxContainer, icon_text: String, key: String, color: Color) -> void:
	var box := HBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	parent.add_child(box)

	var icon_bg := ColorRect.new()
	icon_bg.color = color
	icon_bg.custom_minimum_size = Vector2(18.0, 18.0)
	box.add_child(icon_bg)

	var icon := Label.new()
	icon.text = icon_text
	icon.position = Vector2(4, 1)
	icon.modulate = Color(0.02, 0.03, 0.05, 1.0)
	icon_bg.add_child(icon)

	var lbl := Label.new()
	lbl.text = "%s: 0" % key.capitalize()
	lbl.add_theme_font_size_override("font_size", 15)
	box.add_child(lbl)
	_resource_labels[key] = lbl


func _update_resource_ui() -> void:
	for key in _resource_labels.keys():
		var lbl: Label = _resource_labels[key]
		lbl.text = "%s: %d" % [String(key).capitalize(), int(_resources[key])]
	for b_key in _building_labels.keys():
		var b_lbl: Label = _building_labels[b_key]
		b_lbl.text = "Built: %d" % int(_buildings[b_key])


func _build_hover_ui() -> void:
	var ui_layer: CanvasLayer = $UI
	_hover_panel = PanelContainer.new()
	_hover_panel.size = Vector2(280.0, 220.0)
	_hover_panel.visible = false
	ui_layer.add_child(_hover_panel)

	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.07, 0.1, 0.14, 0.94)
	panel_style.border_width_left = 1
	panel_style.border_width_top = 1
	panel_style.border_width_right = 1
	panel_style.border_width_bottom = 1
	panel_style.border_color = Color(0.48, 0.67, 0.8, 0.95)
	panel_style.corner_radius_top_left = 8
	panel_style.corner_radius_top_right = 8
	panel_style.corner_radius_bottom_left = 8
	panel_style.corner_radius_bottom_right = 8
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
		bstyle.corner_radius_top_left = 4
		bstyle.corner_radius_top_right = 4
		bstyle.corner_radius_bottom_left = 4
		bstyle.corner_radius_bottom_right = 4
		btn.add_theme_stylebox_override("normal", bstyle)
		var job_id: int = entry[2]
		btn.pressed.connect(Callable(self, "_set_pinned_settler_job").bind(job_id))
		_job_btn_row.add_child(btn)

	_position_hover_panel()


func _position_hover_panel() -> void:
	if _hover_panel == null:
		return
	var vp := get_viewport_rect().size
	_hover_panel.position = Vector2(vp.x - _hover_panel.size.x - 12.0, 58.0)


func _set_pinned_settler_job(job_id: int) -> void:
	if _pinned_agent_idx < 0:
		return
	if job_id < 0:
		_settler_job_overrides.erase(_pinned_agent_idx)
		_record_agent_action(_pinned_agent_idx, "Job set to Auto")
	else:
		_settler_job_overrides[_pinned_agent_idx] = job_id
		var name_map := {JOB_FARM: "Farmer", JOB_LUMBER: "Lumberjack", JOB_STONE: "Stone Miner"}
		_record_agent_action(_pinned_agent_idx, "Job set to %s" % name_map[job_id])
	# Clear cached resource target so the new job takes effect immediately
	_settler_resource_targets.erase(_pinned_agent_idx)
	_agent_last_state.erase(_pinned_agent_idx)


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
	for i in count:
		if not _agent_recent_actions.has(i):
			_agent_recent_actions[i] = []
		if not _agent_last_state.has(i):
			_agent_last_state[i] = ""
	if _pinned_agent_idx >= count:
		_pinned_agent_idx = -1


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

	var state: String = "Returning Home" if _is_night() else "Working"
	var job_name: String = "Farmer"
	if job == JOB_LUMBER:
		job_name = "Lumberjack"
	elif job == JOB_STONE:
		job_name = "Stone Miner"

	var pinned_tag: String = " (Pinned)" if i == _pinned_agent_idx else ""
	_hover_title_label.text = "Settler #%d%s" % [i, pinned_tag]
	_hover_body_label.text = (
		"State: %s\n"
		+ "Job: %s\n"
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
	bg_style.bg_color = Color(0.06, 0.09, 0.13, 0.95)
	bg_style.corner_radius_top_left = 14
	bg_style.corner_radius_bottom_left = 14
	bg_style.border_width_left = 2
	bg_style.border_width_top = 2
	bg_style.border_width_bottom = 2
	bg_style.border_color = Color(0.24, 0.65, 0.8, 0.9)
	_upgrade_panel.add_theme_stylebox_override("panel", bg_style)

	var root_margin := MarginContainer.new()
	root_margin.add_theme_constant_override("margin_left", 14)
	root_margin.add_theme_constant_override("margin_right", 14)
	root_margin.add_theme_constant_override("margin_top", 12)
	root_margin.add_theme_constant_override("margin_bottom", 12)
	_upgrade_panel.add_child(root_margin)

	var root_col := VBoxContainer.new()
	root_col.add_theme_constant_override("separation", 10)
	root_margin.add_child(root_col)

	var title := Label.new()
	title.text = "Village Growth"
	title.add_theme_font_size_override("font_size", 22)
	root_col.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "Procedural biomes, resource chains, RTS-style recipes"
	subtitle.modulate = Color(0.82, 0.89, 0.95, 0.85)
	subtitle.add_theme_font_size_override("font_size", 13)
	root_col.add_child(subtitle)

	var tabs := TabContainer.new()
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root_col.add_child(tabs)

	for cat in ["Volume", "Efficiency", "Specialization", "Vision & Exploration"]:
		var page := VBoxContainer.new()
		page.name = cat
		page.add_theme_constant_override("separation", 8)
		tabs.add_child(page)
		for item in UPGRADE_DATA[cat]:
			page.add_child(_make_upgrade_row(item))

	var building_page := VBoxContainer.new()
	building_page.name = "Buildings"
	building_page.add_theme_constant_override("separation", 8)
	tabs.add_child(building_page)
	for b_name in BUILDING_RECIPES.keys():
		building_page.add_child(_make_building_row(b_name, BUILDING_RECIPES[b_name]))

	var pop_page := VBoxContainer.new()
	pop_page.name = "Population"
	pop_page.add_theme_constant_override("separation", 8)
	tabs.add_child(pop_page)
	_build_population_tab(pop_page)

	get_viewport().size_changed.connect(_on_viewport_resized)


func _build_population_tab(page: VBoxContainer) -> void:
	page.add_child(_make_population_action_row("recruit", POP_ACTIONS["recruit"]))
	page.add_child(_make_population_action_row("house", POP_ACTIONS["house"]))

	var jobs_title := Label.new()
	jobs_title.text = "Worker Allocation"
	jobs_title.add_theme_font_size_override("font_size", 15)
	page.add_child(jobs_title)

	page.add_child(_make_job_row("farm", "Farmers"))
	page.add_child(_make_job_row("lumber", "Lumberjacks"))
	page.add_child(_make_job_row("stone", "Stone Miners"))

	_update_job_labels()


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
	var cost: Dictionary = item["cost"]

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

	var c := Label.new()
	c.text = _cost_to_string(cost)
	c.modulate = Color(0.82, 0.84, 0.9, 0.95)
	c.add_theme_font_size_override("font_size", 11)
	text_col.add_child(c)

	var buy := Button.new()
	buy.text = "Buy"
	buy.custom_minimum_size = Vector2(110.0, 34.0)
	buy.pressed.connect(_on_upgrade_pressed.bind(id, cost, buy, panel))
	row.add_child(buy)

	return panel


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
	style.bg_color = bg_color
	style.corner_radius_top_left = 10
	style.corner_radius_top_right = 10
	style.corner_radius_bottom_left = 10
	style.corner_radius_bottom_right = 10
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.border_color = Color(0.34, 0.43, 0.56, 0.9)
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


func _build_minimap_ui() -> void:
	var ui_layer: CanvasLayer = $UI
	_minimap_image = Image.create(MINIMAP_TILES, MINIMAP_TILES, false, Image.FORMAT_RGBA8)
	_minimap_texture = ImageTexture.create_from_image(_minimap_image)

	var panel := PanelContainer.new()
	panel.position = Vector2(12.0, 64.0)
	panel.size = Vector2(MINIMAP_TILES * _minimap_scale + 10.0, MINIMAP_TILES * _minimap_scale + 30.0)
	ui_layer.add_child(panel)

	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.05, 0.08, 0.11, 0.88)
	panel_style.corner_radius_top_left = 8
	panel_style.corner_radius_top_right = 8
	panel_style.corner_radius_bottom_left = 8
	panel_style.corner_radius_bottom_right = 8
	panel_style.border_width_left = 1
	panel_style.border_width_top = 1
	panel_style.border_width_right = 1
	panel_style.border_width_bottom = 1
	panel_style.border_color = Color(0.42, 0.58, 0.68, 0.9)
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
				if res_type == RES_TREE and _resource_left(tile, res_type) > 0.0:
					col = col.lerp(Color(0.14, 0.75, 0.22, 1.0), 0.45)
				elif res_type == RES_STONE and _resource_left(tile, res_type) > 0.0:
					col = col.lerp(Color(0.74, 0.8, 0.88, 1.0), 0.45)
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
		return int(_settler_job_overrides[index])
	var farm_count: int = int(_job_counts["farm"])
	var lumber_count: int = int(_job_counts["lumber"])
	if index < farm_count:
		return JOB_FARM
	if index < farm_count + lumber_count:
		return JOB_LUMBER
	return JOB_STONE


func _clamp_job_counts() -> void:
	var settlers: int = _agents.get_agent_count()
	var farm: int = clampi(int(_job_counts["farm"]), 0, settlers)
	var lumber: int = clampi(int(_job_counts["lumber"]), 0, settlers)
	var stone: int = clampi(int(_job_counts["stone"]), 0, settlers)
	while farm + lumber + stone > settlers:
		if stone > 0:
			stone -= 1
		elif lumber > 0:
			lumber -= 1
		else:
			farm -= 1
	_job_counts["farm"] = farm
	_job_counts["lumber"] = lumber
	_job_counts["stone"] = stone
	_update_job_labels()


func _update_job_labels() -> void:
	for key in _job_count_labels.keys():
		var lbl: Label = _job_count_labels[key]
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


func _nearest_resource_tile(from_tile: Vector2i, res_type: int, max_radius: int = 26) -> Vector2i:
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
				return tile
	return from_tile


func _farm_tile_for_settler(index: int) -> Vector2i:
	var angle: float = float((index * 53) % 360) * PI / 180.0
	var radius: float = 5.0 + float((index * 13) % 7)
	return Vector2i(
		_camp_tile.x + int(round(cos(angle) * radius)),
		_camp_tile.y + int(round(sin(angle) * radius))
	)


func _update_settler_targets(delta: float) -> void:
	_ai_tick += delta
	if _ai_tick < 0.35:
		return
	_ai_tick = 0.0

	var agents: PackedVector2Array = _agents.get_agent_positions()
	var targets := PackedVector2Array()
	targets.resize(agents.size())

	for i in agents.size():
		var state_tag: String = ""
		if _is_night():
			targets[i] = _home_center_for_settler(i)
			state_tag = "night_home"
			if String(_agent_last_state.get(i, "")) != state_tag:
				_agent_last_state[i] = state_tag
				_settler_resource_targets.erase(i)
				_record_agent_action(i, "Returning to home")
			continue

		var pos: Vector2 = agents[i]
		var tile := _world_to_tile(pos)
		var job: int = _job_for_settler(i)

		if job == JOB_FARM:
			targets[i] = _tile_center(_farm_tile_for_settler(i))
			state_tag = "day_farm"
		else:
			var res_type: int = RES_TREE if job == JOB_LUMBER else RES_STONE
			var cached: Vector2i = _settler_resource_targets.get(i, Vector2i(-9999, -9999))
			var need_new: bool = false
			if cached == Vector2i(-9999, -9999):
				need_new = true
			elif _resource_left(cached, res_type) <= 0.0:
				need_new = true
			elif tile.distance_to(cached) <= 1.5:
				# Arrived — find next tile
				need_new = true
			if need_new:
				cached = _nearest_resource_tile(tile, res_type)
				_settler_resource_targets[i] = cached
			targets[i] = _tile_center(cached)
			state_tag = "day_lumber" if job == JOB_LUMBER else "day_stone"

		if String(_agent_last_state.get(i, "")) != state_tag:
			_agent_last_state[i] = state_tag
			if state_tag == "day_farm":
				_record_agent_action(i, "Assigned to farming")
			elif state_tag == "day_lumber":
				_record_agent_action(i, "Assigned to lumber")
			else:
				_record_agent_action(i, "Assigned to mining")

	_agents.set_agent_targets(targets)


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


func _on_upgrade_pressed(id: String, cost: Dictionary, buy_button: Button, row_panel: PanelContainer) -> void:
	if _purchased_upgrades.has(id):
		return
	if not _can_afford(cost):
		_pulse_row(row_panel, Color(0.42, 0.18, 0.18, 0.95))
		return

	_spend_cost(cost)
	_purchased_upgrades[id] = true
	_apply_upgrade_effect(id)
	buy_button.disabled = true
	buy_button.text = "Purchased"
	_spawn_upgrade_burst(_target, _upgrade_color_for(id))
	_spawn_floating_text(_target, _upgrade_label_for(id), _upgrade_color_for(id))
	_kick_camera(7.0)
	_pulse_row(row_panel, Color(0.16, 0.34, 0.22, 0.96))


func _on_building_pressed(id: String, cost: Dictionary, row_panel: PanelContainer) -> void:
	if not _can_afford(cost):
		_pulse_row(row_panel, Color(0.42, 0.18, 0.18, 0.95))
		return
	_spend_cost(cost)
	_buildings[id] = int(_buildings[id]) + 1
	if id == "house":
		_place_house_near_target()
		_recompute_homes()
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
		_spawn_floating_text(_target, "+2 Housing", Color(0.95, 0.87, 0.45, 1.0))
		_spawn_upgrade_burst(_target, Color(0.95, 0.87, 0.45, 1.0))
		_kick_camera(5.0)
		_pulse_row(row_panel, Color(0.3, 0.27, 0.14, 0.96))


func _change_job_count(job_key: String, delta: int) -> void:
	var val: int = int(_job_counts[job_key]) + delta
	if delta > 0:
		var total_assigned: int = int(_job_counts["farm"]) + int(_job_counts["lumber"]) + int(_job_counts["stone"])
		if total_assigned >= _agents.get_agent_count():
			return
	_job_counts[job_key] = maxi(0, val)
	_clamp_job_counts()


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
		"vision_1":
			_vision_radius = 7
		"vision_2":
			_vision_radius = 11
		"tower_1":
			_auto_watchtowers = true
			_add_watchtower_at_world(_target)
		"tower_2":
			_watchtower_radius = 14
			for w in _watchtowers:
				_reveal_around_tile(w, _watchtower_radius)
		"vol_lumber_1":
			_tree_yield_mult *= 2.0
		"vol_stone_1":
			_stone_yield_mult *= 2.0
		"eff_speed_1":
			_agents.tiles_per_second *= 1.8
		"eff_convert_1":
			_convert_mult *= 2.0
		"spec_forestry_1":
			_buildings["sawmill"] = int(_buildings["sawmill"]) + 1
		"spec_masonry_1":
			_buildings["quarry"] = int(_buildings["quarry"]) + 1
		_:
			pass


func _can_afford(cost: Dictionary) -> bool:
	for key in cost.keys():
		if _resources[key] < float(cost[key]):
			return false
	return true


func _spend_cost(cost: Dictionary) -> void:
	for key in cost.keys():
		_resources[key] -= float(cost[key])


func _cost_to_string(cost: Dictionary) -> String:
	var parts: Array[String] = []
	for key in ["food", "lumber", "stone", "cobblestone"]:
		if cost.has(key):
			parts.append("%d %s" % [int(cost[key]), String(key)])
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
		_:
			return ""


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
			_explored[_tile_key(t)] = true


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
	if biome == 1:
		return RES_TREE if r < 0.58 else RES_NONE
	if biome == 0:
		if r < 0.18:
			return RES_TREE
		if r > 0.93:
			return RES_STONE
		return RES_NONE
	if biome == 2:
		if r < 0.22:
			return RES_TREE
		if r < 0.62:
			return RES_STONE
		return RES_NONE
	if biome == 3:
		if r < 0.68:
			return RES_STONE
		if r > 0.96:
			return RES_TREE
		return RES_NONE
	if biome == 4:
		return RES_TREE if r < 0.2 else RES_NONE
	return RES_NONE


func _resource_initial_amount(tile: Vector2i, res_type: int) -> float:
	var r: float = _rand01(tile.x, tile.y, _world_seed + 991)
	if res_type == RES_TREE:
		return 4.0 + floor(r * 7.0)
	if res_type == RES_STONE:
		return 5.0 + floor(r * 9.0)
	return 0.0


func _resource_left(tile: Vector2i, res_type: int) -> float:
	var key: String = _tile_key(tile)
	if _resource_remaining.has(key):
		return float(_resource_remaining[key])
	return _resource_initial_amount(tile, res_type)


func _set_resource_left(tile: Vector2i, value: float) -> void:
	_resource_remaining[_tile_key(tile)] = maxf(0.0, value)


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


func _kick_camera(amount: float) -> void:
	var dir := Vector2(_rng.randf_range(-1.0, 1.0), _rng.randf_range(-1.0, 1.0)).normalized()
	_camera_kick += dir * amount


func _update_camera_kick(delta: float) -> void:
	if _camera_kick.length_squared() < 0.0001:
		_camera.position = _camera_base_pos
		_camera_kick = Vector2.ZERO
		return
	_camera_kick = _camera_kick.move_toward(Vector2.ZERO, 35.0 * delta)
	_camera.position = _camera_base_pos + _camera_kick


func _upgrade_color_for(id: String) -> Color:
	if id.begins_with("vision") or id.begins_with("tower"):
		return Color(0.95, 0.87, 0.2, 1.0)
	if id.begins_with("eff"):
		return Color(0.4, 1.0, 0.65, 1.0)
	if id.begins_with("vol"):
		return Color(0.35, 0.85, 1.0, 1.0)
	return Color(0.95, 0.55, 1.0, 1.0)


func _upgrade_label_for(id: String) -> String:
	match id:
		"vision_1":
			return "+Vision Radius"
		"vision_2":
			return "++Vision Radius"
		"tower_1":
			return "+Watchtower Network"
		"tower_2":
			return "+Tower Range"
		_:
			return "Upgrade Purchased"
