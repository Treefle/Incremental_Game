class_name WeaponEditorPanel
extends PanelContainer

signal save_requested(record: Dictionary)
signal closed_requested

var _records: Array[Dictionary] = []
var _selected_index: int = -1
var _picking_field: String = ""

var _record_list: ItemList
var _weapon_id_spin: SpinBox
var _weapon_name_edit: LineEdit
var _attack_kind_option: OptionButton
var _range_spin: SpinBox
var _damage_spin: SpinBox
var _cooldown_spin: SpinBox
var _defense_spin: SpinBox
var _aoe_radius_spin: SpinBox
var _projectile_speed_spin: SpinBox
var _trail_color_picker: ColorPickerButton
var _trail_width_spin: SpinBox
var _icon_path_edit: LineEdit
var _projectile_path_edit: LineEdit
var _sound_path_edit: LineEdit
var _preview_texture: TextureRect
var _preview_label: Label
var _resource_path_label: Label
var _file_dialog: FileDialog


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	offset_left = 48.0
	offset_top = 48.0
	offset_right = -48.0
	offset_bottom = -48.0
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	_build_ui()


func set_weapon_records(records: Array[Dictionary]) -> void:
	_records = []
	for rec in records:
		_records.append(rec.duplicate(true))
	_records.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.get("weapon_id", 0)) < int(b.get("weapon_id", 0)))
	_refresh_record_list()
	if not _records.is_empty():
		_select_record(0)
	else:
		_selected_index = -1
		_clear_fields()


func _build_ui() -> void:
	var root: HBoxContainer = HBoxContainer.new()
	add_child(root)
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.offset_left = 12.0
	root.offset_top = 12.0
	root.offset_right = -12.0
	root.offset_bottom = -12.0

	var left: VBoxContainer = VBoxContainer.new()
	left.custom_minimum_size = Vector2(230.0, 0.0)
	root.add_child(left)

	var title: Label = Label.new()
	title.text = "Weapon Catalog"
	title.add_theme_font_size_override("font_size", 18)
	left.add_child(title)

	_record_list = ItemList.new()
	_record_list.select_mode = ItemList.SELECT_SINGLE
	_record_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_record_list.item_selected.connect(_select_record)
	left.add_child(_record_list)

	var new_btn: Button = Button.new()
	new_btn.text = "New Weapon"
	new_btn.pressed.connect(_on_new_weapon_pressed)
	left.add_child(new_btn)

	var right: ScrollContainer = ScrollContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(right)

	var form: VBoxContainer = VBoxContainer.new()
	form.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	form.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_child(form)

	var header: Label = Label.new()
	header.text = "Weapon Editor"
	header.add_theme_font_size_override("font_size", 22)
	form.add_child(header)

	_weapon_id_spin = _add_spin(form, "Weapon ID", 0.0, 9999.0, 1.0, 0.0)
	_weapon_name_edit = _add_line(form, "Weapon Name")

	_attack_kind_option = OptionButton.new()
	_attack_kind_option.add_item("Melee", 0)
	_attack_kind_option.add_item("Ranged", 1)
	_attack_kind_option.add_item("AoE", 2)
	_add_row(form, "Attack Type", _attack_kind_option)

	_range_spin = _add_spin(form, "Range", 1.0, 256.0, 0.5, 34.0)
	_damage_spin = _add_spin(form, "Damage", 0.1, 20.0, 0.05, 1.0)
	_cooldown_spin = _add_spin(form, "Cooldown", 0.1, 10.0, 0.05, 1.4)
	_defense_spin = _add_spin(form, "Defense", 0.1, 5.0, 0.05, 1.0)
	_aoe_radius_spin = _add_spin(form, "AoE Radius", 0.0, 128.0, 0.5, 0.0)
	_projectile_speed_spin = _add_spin(form, "Projectile Speed", 0.0, 2000.0, 1.0, 380.0)

	_trail_color_picker = ColorPickerButton.new()
	_trail_color_picker.color = Color(0.82, 0.76, 0.42, 1.0)
	_add_row(form, "Trail Color", _trail_color_picker)
	_trail_width_spin = _add_spin(form, "Trail Width", 0.5, 8.0, 0.1, 2.2)

	_icon_path_edit = _add_resource_path_row(form, "Icon Texture", "icon_path")
	_projectile_path_edit = _add_resource_path_row(form, "Projectile Texture", "projectile_path")
	_sound_path_edit = _add_resource_path_row(form, "Attack Sound", "sound_path")

	_resource_path_label = Label.new()
	_resource_path_label.text = "Source: (new)"
	form.add_child(_resource_path_label)

	_preview_texture = TextureRect.new()
	_preview_texture.custom_minimum_size = Vector2(96.0, 96.0)
	_preview_texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_preview_texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	form.add_child(_preview_texture)

	_preview_label = Label.new()
	_preview_label.text = "Preview: no icon selected"
	form.add_child(_preview_label)

	var actions: HBoxContainer = HBoxContainer.new()
	form.add_child(actions)

	var save_btn: Button = Button.new()
	save_btn.text = "Save Weapon"
	save_btn.pressed.connect(_on_save_pressed)
	actions.add_child(save_btn)

	var close_btn: Button = Button.new()
	close_btn.text = "Close"
	close_btn.pressed.connect(func() -> void:
		visible = false
		emit_signal("closed_requested")
	)
	actions.add_child(close_btn)

	_file_dialog = FileDialog.new()
	_file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	_file_dialog.access = FileDialog.ACCESS_RESOURCES
	_file_dialog.file_selected.connect(_on_file_selected)
	add_child(_file_dialog)


func _add_row(parent: VBoxContainer, label_text: String, control: Control) -> void:
	var row: HBoxContainer = HBoxContainer.new()
	parent.add_child(row)
	var label: Label = Label.new()
	label.text = label_text
	label.custom_minimum_size = Vector2(150.0, 0.0)
	row.add_child(label)
	control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(control)


func _add_spin(parent: VBoxContainer, label: String, min_val: float, max_val: float, step: float, initial: float) -> SpinBox:
	var spin: SpinBox = SpinBox.new()
	spin.min_value = min_val
	spin.max_value = max_val
	spin.step = step
	spin.value = initial
	_add_row(parent, label, spin)
	return spin


func _add_line(parent: VBoxContainer, label: String) -> LineEdit:
	var le: LineEdit = LineEdit.new()
	_add_row(parent, label, le)
	return le


func _add_resource_path_row(parent: VBoxContainer, label: String, field_name: String) -> LineEdit:
	var row: HBoxContainer = HBoxContainer.new()
	parent.add_child(row)
	var name_label: Label = Label.new()
	name_label.text = label
	name_label.custom_minimum_size = Vector2(150.0, 0.0)
	row.add_child(name_label)
	var path_edit: LineEdit = LineEdit.new()
	path_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(path_edit)
	var pick_btn: Button = Button.new()
	pick_btn.text = "..."
	pick_btn.pressed.connect(func() -> void:
		_open_file_dialog_for(field_name)
	)
	row.add_child(pick_btn)
	return path_edit


func _refresh_record_list() -> void:
	_record_list.clear()
	for rec in _records:
		var id: int = int(rec.get("weapon_id", 0))
		var nm: String = String(rec.get("weapon_name", "Weapon"))
		_record_list.add_item("%d - %s" % [id, nm])


func _select_record(index: int) -> void:
	if index < 0 or index >= _records.size():
		return
	_selected_index = index
	var rec: Dictionary = _records[index]
	_weapon_id_spin.value = float(rec.get("weapon_id", 0))
	_weapon_name_edit.text = String(rec.get("weapon_name", ""))
	_attack_kind_option.select(clampi(int(rec.get("attack_kind", 0)), 0, 2))
	_range_spin.value = float(rec.get("range", 34.0))
	_damage_spin.value = float(rec.get("damage", 1.0))
	_cooldown_spin.value = float(rec.get("cooldown", 1.4))
	_defense_spin.value = float(rec.get("defense", 1.0))
	_aoe_radius_spin.value = float(rec.get("aoe_radius", 0.0))
	_projectile_speed_spin.value = float(rec.get("projectile_speed", 380.0))
	_trail_color_picker.color = rec.get("trail_color", Color(0.82, 0.76, 0.42, 1.0))
	_trail_width_spin.value = float(rec.get("trail_width", 2.2))
	_icon_path_edit.text = String(rec.get("icon_path", ""))
	_projectile_path_edit.text = String(rec.get("projectile_path", ""))
	_sound_path_edit.text = String(rec.get("sound_path", ""))
	_resource_path_label.text = "Source: %s" % String(rec.get("resource_path", "(new)"))
	_update_preview_from_path(_icon_path_edit.text)


func _clear_fields() -> void:
	_weapon_id_spin.value = 0
	_weapon_name_edit.text = ""
	_attack_kind_option.select(0)
	_range_spin.value = 34.0
	_damage_spin.value = 1.0
	_cooldown_spin.value = 1.4
	_defense_spin.value = 1.0
	_aoe_radius_spin.value = 0.0
	_projectile_speed_spin.value = 380.0
	_trail_color_picker.color = Color(0.82, 0.76, 0.42, 1.0)
	_trail_width_spin.value = 2.2
	_icon_path_edit.text = ""
	_projectile_path_edit.text = ""
	_sound_path_edit.text = ""
	_resource_path_label.text = "Source: (new)"
	_preview_texture.texture = null
	_preview_label.text = "Preview: no icon selected"


func _on_new_weapon_pressed() -> void:
	_selected_index = -1
	_clear_fields()


func _on_save_pressed() -> void:
	var rec := {
		"weapon_id": int(_weapon_id_spin.value),
		"weapon_name": _weapon_name_edit.text.strip_edges(),
		"attack_kind": _attack_kind_option.get_selected_id(),
		"range": float(_range_spin.value),
		"damage": float(_damage_spin.value),
		"cooldown": float(_cooldown_spin.value),
		"defense": float(_defense_spin.value),
		"aoe_radius": float(_aoe_radius_spin.value),
		"projectile_speed": float(_projectile_speed_spin.value),
		"trail_color": _trail_color_picker.color,
		"trail_width": float(_trail_width_spin.value),
		"icon_path": _icon_path_edit.text.strip_edges(),
		"projectile_path": _projectile_path_edit.text.strip_edges(),
		"sound_path": _sound_path_edit.text.strip_edges(),
	}
	if String(rec["weapon_name"]).is_empty():
		rec["weapon_name"] = "Weapon %d" % int(rec["weapon_id"])
	emit_signal("save_requested", rec)


func _open_file_dialog_for(field_name: String) -> void:
	_picking_field = field_name
	_file_dialog.filters.clear()
	match field_name:
		"icon_path", "projectile_path":
			_file_dialog.filters.append("*.png, *.jpg, *.jpeg, *.webp ; Image")
		"sound_path":
			_file_dialog.filters.append("*.wav, *.ogg, *.mp3 ; Audio")
	_file_dialog.popup_centered_ratio(0.65)


func _on_file_selected(path: String) -> void:
	match _picking_field:
		"icon_path":
			_icon_path_edit.text = path
			_update_preview_from_path(path)
		"projectile_path":
			_projectile_path_edit.text = path
		"sound_path":
			_sound_path_edit.text = path
	_picking_field = ""


func _update_preview_from_path(path: String) -> void:
	if path.is_empty():
		_preview_texture.texture = null
		_preview_label.text = "Preview: no icon selected"
		return
	var tex: Texture2D = load(path)
	if tex == null:
		_preview_texture.texture = null
		_preview_label.text = "Preview: failed to load %s" % path
		return
	_preview_texture.texture = tex
	_preview_label.text = "Preview: %s" % path
