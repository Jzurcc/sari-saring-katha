extends Control

## Modernized Persona-inspired kinetic Pause Menu.
## Sweeps in an angled Dark Warm Espresso sash with an Antique Gold slash on the left,
## staggered Fredoka menu items with a gliding ◆ diamond & playful hover tilt,
## and a live "Store Snapshot" + Controls card on the right.

@onready var buttons = $Buttons
@onready var options_overlay : Control = $OptionsOverlay

const PESO_ICON: Texture2D = preload("res://Assets/ui/peso_icon.png")

const COL_ESPRESSO := Color(0.055, 0.045, 0.038, 0.94)
const COL_SURFACE := Color(0.105, 0.088, 0.075, 0.96)
const COL_CARD := Color(0.135, 0.114, 0.096, 0.94)
const COL_GOLD := Color(0.86, 0.67, 0.32, 1.0)
const COL_GOLD_BRIGHT := Color(1.0, 0.89, 0.58, 1.0)
const COL_CREAM := Color(1.0, 0.95, 0.86, 1.0)
const COL_CREAM_MUTED := Color(0.82, 0.76, 0.67, 0.88)
const COL_BORDER_SUBTLE := Color(0.42, 0.31, 0.18, 0.55)
const COL_POSITIVE := Color(0.56, 0.90, 0.56, 1.0)
const COL_CORAL := Color(0.94, 0.48, 0.44, 1.0)

var _sfx_click   : AudioStream = preload("res://Audio/SFX/ui_sfx_4.mp3")
var _sfx_confirm : AudioStream = preload("res://Audio/SFX/ui_sfx_9.mp3")
var _sfx_hover   : AudioStream = preload("res://Audio/SFX/ui_sfx_12.mp3")
var _ui_player   : AudioStreamPlayer

const DUCK_AMOUNT: float = -6.0
const MUFFLE_CUTOFF: float = 1500.0
const NORMAL_CUTOFF: float = 20500.0
const FADE_DURATION: float = 0.4

var _previous_mouse_mode: Input.MouseMode = Input.MOUSE_MODE_CAPTURED
var _previous_clock_running: bool = false
var _previous_dialogic_paused: bool = false

var _dim_bg: ColorRect
var _sash: _DiagonalSash
var _pause_hdr: VBoxContainer
var _hover_diamond: Label
var _snapshot_panel: PanelContainer
var _snap_day_lbl: Label
var _snap_meta_lbl: Label
var _snap_money_lbl: Label
var _stat_sales_val: Label
var _stat_served_val: Label
var _stat_ledger_val: Label
var _stat_fridge_val: Label

var _btn_tweens: Dictionary = {}
var _diamond_tween: Tween = null
var _entrance_tween: Tween = null
var _save_flash_tween: Tween = null


class _DiagonalSash extends Control:
	## Persona-style angled dark espresso ribbon with an antique-gold diagonal edge slash.
	func _draw() -> void:
		var w := size.x
		var h := size.y
		if w <= 1.0 or h <= 1.0:
			return
		var top_x := w * 0.44
		var bot_x := w * 0.33

		# Main angled dark espresso sash
		var body_pts := PackedVector2Array([
			Vector2(0.0, 0.0),
			Vector2(top_x, 0.0),
			Vector2(bot_x, h),
			Vector2(0.0, h),
		])
		draw_colored_polygon(body_pts, Color(0.055, 0.044, 0.036, 0.94))

		# Subtle warm inner diagonal accent stripe
		var inner_pts := PackedVector2Array([
			Vector2(top_x - 22.0, 0.0),
			Vector2(top_x - 10.0, 0.0),
			Vector2(bot_x - 10.0, h),
			Vector2(bot_x - 22.0, h),
		])
		draw_colored_polygon(inner_pts, Color(0.86, 0.67, 0.32, 0.14))

		# Crisp antique-gold outer slash line
		draw_line(Vector2(top_x, 0.0), Vector2(bot_x, h), Color(0.86, 0.67, 0.32, 0.92), 4.0, true)


func _ready() -> void:
	process_mode = PROCESS_MODE_ALWAYS
	add_to_group("pause_menu")

	_ui_player = AudioStreamPlayer.new()
	_ui_player.bus = "SFX"
	add_child(_ui_player)

	options_overlay.hide()
	options_overlay.closed.connect(_on_options_closed)

	# Replace legacy flat backdrop with our kinetic dim + diagonal sash
	var old_bg := get_node_or_null("Background") as CanvasItem
	if old_bg:
		old_bg.visible = false

	_build_modern_chrome()
	_restyle_buttons()

	hide()


func _build_modern_chrome() -> void:
	# Soft dim over the live paused 3D storefront
	_dim_bg = ColorRect.new()
	_dim_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_dim_bg.color = Color(0.03, 0.024, 0.02, 0.56)
	_dim_bg.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_dim_bg)
	move_child(_dim_bg, 0)

	# Persona-style diagonal sash on the left
	_sash = _DiagonalSash.new()
	_sash.set_anchors_preset(Control.PRESET_FULL_RECT)
	_sash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_sash)
	move_child(_sash, 1)

	# Left Pause Header above the menu buttons
	_pause_hdr = VBoxContainer.new()
	_pause_hdr.anchor_left = 0.0
	_pause_hdr.anchor_top = 0.22
	_pause_hdr.offset_left = 84.0
	_pause_hdr.offset_right = 440.0
	_pause_hdr.add_theme_constant_override("separation", 2)
	_pause_hdr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_pause_hdr)
	move_child(_pause_hdr, buttons.get_index())

	var p_title := Label.new()
	p_title.text = "Paused"
	p_title.add_theme_font_override("font", UIStyle.FONT_FREDOKA_BOLD)
	p_title.add_theme_font_size_override("font_size", 22)
	p_title.add_theme_color_override("font_color", COL_GOLD_BRIGHT)
	_pause_hdr.add_child(p_title)

	var p_sub := Label.new()
	p_sub.text = "Sari-Saring Katha"
	p_sub.add_theme_font_override("font", UIStyle.FONT_FREDOKA_LIGHT)
	p_sub.add_theme_font_size_override("font_size", 14)
	p_sub.add_theme_color_override("font_color", COL_CREAM_MUTED)
	_pause_hdr.add_child(p_sub)

	# Gliding antique-gold diamond beside active menu option
	_hover_diamond = Label.new()
	_hover_diamond.text = "◆"
	_hover_diamond.add_theme_font_override("font", UIStyle.FONT_FREDOKA_REG)
	_hover_diamond.add_theme_font_size_override("font_size", 20)
	_hover_diamond.add_theme_color_override("font_color", COL_GOLD_BRIGHT)
	_hover_diamond.add_theme_color_override("font_outline_color", Color(0.14, 0.08, 0.04, 0.92))
	_hover_diamond.add_theme_constant_override("outline_size", 3)
	_hover_diamond.modulate.a = 0.0
	_hover_diamond.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_hover_diamond)
	move_child(_hover_diamond, options_overlay.get_index())

	# Right-Side "Store Snapshot" + Controls Card
	_snapshot_panel = PanelContainer.new()
	_snapshot_panel.anchor_left = 1.0
	_snapshot_panel.anchor_right = 1.0
	_snapshot_panel.anchor_top = 0.5
	_snapshot_panel.anchor_bottom = 0.5
	_snapshot_panel.offset_left = -456.0
	_snapshot_panel.offset_right = -56.0
	_snapshot_panel.offset_top = -230.0
	_snapshot_panel.offset_bottom = 230.0
	var st := UIStyle.create_flat_stylebox(COL_ESPRESSO, 14, 22, 18)
	st.border_color = COL_GOLD
	st.set_border_width_all(2)
	st.shadow_color = Color(0.0, 0.0, 0.0, 0.55)
	st.shadow_size = 16
	_snapshot_panel.add_theme_stylebox_override("panel", st)
	add_child(_snapshot_panel)
	move_child(_snapshot_panel, options_overlay.get_index())

	var sv := VBoxContainer.new()
	sv.add_theme_constant_override("separation", 14)
	_snapshot_panel.add_child(sv)

	# Snapshot Header: Day/Time + Wallet
	var hdr_row := HBoxContainer.new()
	hdr_row.add_theme_constant_override("separation", 10)
	sv.add_child(hdr_row)

	var day_col := VBoxContainer.new()
	day_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	day_col.add_theme_constant_override("separation", 2)
	hdr_row.add_child(day_col)

	_snap_day_lbl = Label.new()
	_snap_day_lbl.text = "Day 1 · 6:00 AM"
	_snap_day_lbl.add_theme_font_override("font", UIStyle.FONT_FREDOKA_SEMIBOLD)
	_snap_day_lbl.add_theme_font_size_override("font_size", 22)
	_snap_day_lbl.add_theme_color_override("font_color", COL_CREAM)
	day_col.add_child(_snap_day_lbl)

	_snap_meta_lbl = Label.new()
	_snap_meta_lbl.text = "Store Tier 1 · Player Lv. 1"
	_snap_meta_lbl.add_theme_font_override("font", UIStyle.FONT_FREDOKA_LIGHT)
	_snap_meta_lbl.add_theme_font_size_override("font_size", 14)
	_snap_meta_lbl.add_theme_color_override("font_color", COL_GOLD_BRIGHT)
	day_col.add_child(_snap_meta_lbl)

	var money_pill := PanelContainer.new()
	money_pill.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var mp_st := UIStyle.create_flat_stylebox(COL_CARD, 8, 10, 6)
	mp_st.border_color = COL_BORDER_SUBTLE
	mp_st.set_border_width_all(1)
	money_pill.add_theme_stylebox_override("panel", mp_st)
	hdr_row.add_child(money_pill)

	var mp_row := HBoxContainer.new()
	mp_row.add_theme_constant_override("separation", 6)
	money_pill.add_child(mp_row)

	var p_ic := TextureRect.new()
	p_ic.texture = PESO_ICON
	p_ic.custom_minimum_size = Vector2(22, 22)
	p_ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	p_ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	p_ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	mp_row.add_child(p_ic)

	_snap_money_lbl = Label.new()
	_snap_money_lbl.text = "0.00"
	_snap_money_lbl.add_theme_font_override("font", UIStyle.FONT_FREDOKA_SEMIBOLD)
	_snap_money_lbl.add_theme_font_size_override("font_size", 18)
	_snap_money_lbl.add_theme_color_override("font_color", COL_CREAM)
	mp_row.add_child(_snap_money_lbl)

	# 2x2 Today's Stats Grid
	var stats_grid := GridContainer.new()
	stats_grid.columns = 2
	stats_grid.add_theme_constant_override("h_separation", 10)
	stats_grid.add_theme_constant_override("v_separation", 10)
	sv.add_child(stats_grid)

	_stat_sales_val = _make_stat_tile(stats_grid, "Sales Today", "₱0.00", COL_POSITIVE)
	_stat_served_val = _make_stat_tile(stats_grid, "Served Today", "0", COL_CREAM)
	_stat_ledger_val = _make_stat_tile(stats_grid, "Silver Ledger", "₱0 / ₱2000", COL_GOLD_BRIGHT)
	_stat_fridge_val = _make_stat_tile(stats_grid, "Fridge Status", "Chilled", COL_POSITIVE)

	# Divider
	var sep := ColorRect.new()
	sep.custom_minimum_size = Vector2(0, 1)
	sep.color = COL_BORDER_SUBTLE
	sv.add_child(sep)

	# Compact Controls Quick-Reference
	var ctrl_hdr := Label.new()
	ctrl_hdr.text = "Store Shortcuts"
	ctrl_hdr.add_theme_font_override("font", UIStyle.FONT_FREDOKA_MED)
	ctrl_hdr.add_theme_font_size_override("font_size", 15)
	ctrl_hdr.add_theme_color_override("font_color", COL_GOLD_BRIGHT)
	sv.add_child(ctrl_hdr)

	var keys_grid := GridContainer.new()
	keys_grid.columns = 2
	keys_grid.add_theme_constant_override("h_separation", 12)
	keys_grid.add_theme_constant_override("v_separation", 8)
	sv.add_child(keys_grid)

	var shortcuts: Array[Array] = [
		["Alt", "Price Lens"],
		["L", "Price Ledger"],
		["U", "Store Upgrades"],
		["K", "Today's Events"],
		["J", "Folklore Journal"],
		["N", "Utang Notebook"],
		["Tab", "Nokia Phone"],
		["Esc", "Resume"],
	]
	for sc in shortcuts:
		keys_grid.add_child(_make_key_row(str(sc[0]), str(sc[1])))


func _make_stat_tile(parent: GridContainer, label_txt: String, val_txt: String, val_col: Color) -> Label:
	var card := PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var cst := UIStyle.create_flat_stylebox(COL_CARD, 8, 12, 8)
	cst.border_color = COL_BORDER_SUBTLE
	cst.set_border_width_all(1)
	card.add_theme_stylebox_override("panel", cst)
	parent.add_child(card)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 2)
	card.add_child(vb)

	var l := Label.new()
	l.text = label_txt
	l.add_theme_font_override("font", UIStyle.FONT_FREDOKA_LIGHT)
	l.add_theme_font_size_override("font_size", 12)
	l.add_theme_color_override("font_color", COL_CREAM_MUTED)
	vb.add_child(l)

	var v := Label.new()
	v.text = val_txt
	v.add_theme_font_override("font", UIStyle.FONT_FREDOKA_SEMIBOLD)
	v.add_theme_font_size_override("font_size", 17)
	v.add_theme_color_override("font_color", val_col)
	vb.add_child(v)
	return v


func _make_key_row(key_txt: String, desc_txt: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 8)

	var cap := PanelContainer.new()
	cap.custom_minimum_size = Vector2(44, 24)
	var kst := UIStyle.create_flat_stylebox(COL_SURFACE, 5, 6, 2)
	kst.border_color = COL_GOLD
	kst.set_border_width_all(1)
	cap.add_theme_stylebox_override("panel", kst)
	row.add_child(cap)

	var kl := Label.new()
	kl.text = key_txt
	kl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	kl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	kl.add_theme_font_override("font", UIStyle.FONT_FREDOKA_MED)
	kl.add_theme_font_size_override("font_size", 12)
	kl.add_theme_color_override("font_color", COL_GOLD_BRIGHT)
	cap.add_child(kl)

	var dl := Label.new()
	dl.text = desc_txt
	dl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	dl.add_theme_font_override("font", UIStyle.FONT_FREDOKA_REG)
	dl.add_theme_font_size_override("font_size", 13)
	dl.add_theme_color_override("font_color", COL_CREAM)
	row.add_child(dl)
	return row


func _restyle_buttons() -> void:
	# Anchor buttons cleanly on the left inside the diagonal sash
	buttons.anchor_left = 0.0
	buttons.anchor_right = 0.0
	buttons.anchor_top = 0.32
	buttons.anchor_bottom = 0.32
	buttons.offset_left = 84.0
	buttons.offset_right = 440.0
	buttons.offset_top = 0.0
	buttons.offset_bottom = 360.0
	buttons.add_theme_constant_override("separation", 12)

	var title_case_map := {
		"Resume": "Resume",
		"Settings": "Settings",
		"SaveGame": "Save Game",
		"MainMenu": "Main Menu",
		"Exit": "Exit",
	}

	for child in buttons.get_children():
		if not (child is Button):
			continue
		var btn := child as Button
		if title_case_map.has(btn.name):
			btn.text = title_case_map[btn.name]
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		btn.add_theme_font_override("font", UIStyle.FONT_FREDOKA_SEMIBOLD)
		btn.add_theme_font_size_override("font_size", 46)
		btn.add_theme_color_override("font_color", Color(0.98, 0.91, 0.78, 0.94))
		btn.add_theme_color_override("font_outline_color", Color(0.18, 0.10, 0.04, 0.92))
		btn.add_theme_constant_override("outline_size", 4)
		btn.mouse_entered.connect(_on_btn_hover.bind(btn))
		btn.mouse_exited.connect(_on_btn_unhover.bind(btn))
		btn.focus_entered.connect(_on_btn_hover.bind(btn))
		btn.focus_exited.connect(_on_btn_unhover.bind(btn))


func _on_btn_hover(btn: Button) -> void:
	_play_hover()
	btn.add_theme_color_override("font_color", Color(1.0, 0.99, 0.94, 1.0))
	btn.add_theme_color_override("font_outline_color", Color(0.86, 0.62, 0.20, 0.95))
	btn.add_theme_constant_override("outline_size", 3)
	btn.pivot_offset = Vector2(0.0, btn.size.y * 0.5)
	_tween_btn(btn, Vector2(1.07, 1.07), -1.6)
	call_deferred("_move_diamond_to", btn)


func _on_btn_unhover(btn: Button) -> void:
	btn.add_theme_color_override("font_color", Color(0.98, 0.91, 0.78, 0.94))
	btn.add_theme_color_override("font_outline_color", Color(0.18, 0.10, 0.04, 0.92))
	btn.add_theme_constant_override("outline_size", 4)
	_tween_btn(btn, Vector2.ONE, 0.0)


func _tween_btn(btn: Button, target_scale: Vector2, target_rot_deg: float) -> void:
	var prev: Tween = _btn_tweens.get(btn)
	if prev and prev.is_valid():
		prev.kill()
	var tw := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS).set_parallel(true)
	tw.tween_property(btn, "scale", target_scale, 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(btn, "rotation_degrees", target_rot_deg, 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_btn_tweens[btn] = tw


func _move_diamond_to(btn: Button) -> void:
	if not is_instance_valid(btn) or not is_instance_valid(_hover_diamond) or not btn.is_visible_in_tree():
		return
	var r := btn.get_global_rect()
	var pos := Vector2(r.position.x - 32.0, r.position.y + r.size.y * 0.5 - 14.0)
	if _diamond_tween and _diamond_tween.is_valid():
		_diamond_tween.kill()
	_diamond_tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS).set_parallel(true)
	_diamond_tween.tween_property(_hover_diamond, "global_position", pos, 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_diamond_tween.tween_property(_hover_diamond, "modulate:a", 1.0, 0.12)


func _refresh_snapshot() -> void:
	var time_str := ""
	if is_instance_valid(StoryManager) and StoryManager.clock and StoryManager.clock.has_method("get_formatted_time"):
		time_str = StoryManager.clock.get_formatted_time()
	var day_num := StoryManager.day if is_instance_valid(StoryManager) else 1
	_snap_day_lbl.text = ("Day %d · %s" % [day_num, time_str]) if time_str != "" else ("Day %d" % day_num)
	if is_instance_valid(StoryManager):
		_snap_meta_lbl.text = "Store Tier %d · Player Lv. %d" % [StoryManager.current_tier, StoryManager.player_level]

		var ds := StoryManager.ensure_daily_stats()
		var sales := float(ds.get("cash_sales", 0.0)) + float(ds.get("tips_earned", 0.0))
		var served := int(ds.get("buyers_served", 0))
		_stat_sales_val.text = "₱%.2f" % sales
		_stat_served_val.text = "%d" % served

		if StoryManager.is_tally_cleared():
			_stat_ledger_val.text = "Sealed ✓"
			_stat_ledger_val.add_theme_color_override("font_color", COL_POSITIVE)
		else:
			_stat_ledger_val.text = "₱%.0f / ₱%.0f" % [StoryManager.tally_total_paid, StoryManager.TALLY_GOAL]
			_stat_ledger_val.add_theme_color_override("font_color", COL_GOLD_BRIGHT)

		if StoryManager.is_fridge_warm:
			_stat_fridge_val.text = "Warm (-20%)"
			_stat_fridge_val.add_theme_color_override("font_color", COL_CORAL)
		else:
			_stat_fridge_val.text = "Chilled"
			_stat_fridge_val.add_theme_color_override("font_color", COL_POSITIVE)

	var gm_nodes := get_tree().get_nodes_in_group("game_manager")
	var money_val := float(gm_nodes[0].money) if not gm_nodes.is_empty() else 0.0
	_snap_money_lbl.text = "%.2f" % money_val


func _play_pause_entrance() -> void:
	if _entrance_tween and _entrance_tween.is_valid():
		_entrance_tween.kill()

	_dim_bg.modulate.a = 0.0
	_sash.position.x = -520.0
	_pause_hdr.modulate.a = 0.0
	_pause_hdr.position.x = 44.0
	_snapshot_panel.modulate.a = 0.0
	var snap_rest_x := _snapshot_panel.offset_left
	_snapshot_panel.offset_left = snap_rest_x + 60.0
	_snapshot_panel.offset_right = -56.0 + 60.0

	_entrance_tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS).set_parallel(true)
	_entrance_tween.tween_property(_dim_bg, "modulate:a", 1.0, 0.18).set_trans(Tween.TRANS_SINE)
	_entrance_tween.tween_property(_sash, "position:x", 0.0, 0.24).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	_entrance_tween.tween_property(_pause_hdr, "modulate:a", 1.0, 0.20).set_delay(0.05)
	_entrance_tween.tween_property(_pause_hdr, "position:x", 84.0, 0.24).set_delay(0.05).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_entrance_tween.tween_property(_snapshot_panel, "modulate:a", 1.0, 0.22).set_delay(0.06)
	_entrance_tween.tween_property(_snapshot_panel, "offset_left", snap_rest_x, 0.26).set_delay(0.06).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_entrance_tween.tween_property(_snapshot_panel, "offset_right", -56.0, 0.26).set_delay(0.06).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	var idx := 0
	for child in buttons.get_children():
		if child is Button and child.visible:
			child.modulate.a = 0.0
			child.scale = Vector2(0.88, 0.88)
			var tw := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS).set_parallel(true)
			var d := 0.04 + idx * 0.035
			tw.tween_property(child, "modulate:a", 1.0, 0.16).set_delay(d)
			tw.tween_property(child, "scale", Vector2.ONE, 0.22).set_delay(d).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			idx += 1


func pause() -> void:
	_refresh_snapshot()
	show()
	get_tree().paused = true
	_previous_mouse_mode = Input.mouse_mode
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	if has_node("/root/StoryManager"):
		_previous_clock_running = StoryManager.is_clock_running
		StoryManager.is_clock_running = false

	if has_node("/root/Dialogic"):
		_previous_dialogic_paused = Dialogic.paused
		Dialogic.paused = true

	_duck_audio(true)
	_play_confirm()
	_play_pause_entrance()

	buttons.get_node("Resume").grab_focus()


func resume() -> void:
	hide()
	get_tree().paused = false
	Input.mouse_mode = _previous_mouse_mode

	if has_node("/root/StoryManager"):
		StoryManager.is_clock_running = _previous_clock_running

	if has_node("/root/Dialogic"):
		Dialogic.paused = _previous_dialogic_paused

	_duck_audio(false)


func _on_resume_pressed() -> void:
	_play_click()
	resume()


func _on_settings_pressed() -> void:
	_play_click()
	options_overlay.open()
	_update_menu_interaction(false)


func _on_options_closed() -> void:
	_update_menu_interaction(true)
	buttons.get_node("Settings").grab_focus()


func _on_main_menu_pressed() -> void:
	_play_confirm()
	get_tree().paused = false

	_duck_audio(false)

	if has_node("/root/StoryManager"):
		StoryManager.is_clock_running = true

	if has_node("/root/Dialogic"):
		Dialogic.paused = false
		if Dialogic.current_timeline != null:
			SaveManager.is_quitting = true
			Dialogic.end_timeline()

	if has_node("/root/SceneTransition"):
		SaveManager.force_save()
		SceneTransition.change_scene("res://Scenes/MainMenu.tscn")
	else:
		SaveManager.force_save()
		get_tree().change_scene_to_file("res://Scenes/MainMenu.tscn")


func _on_save_game_pressed() -> void:
	_play_confirm()
	SaveManager.force_save()
	var save_btn := buttons.get_node_or_null("SaveGame") as Button
	if is_instance_valid(save_btn):
		if _save_flash_tween and _save_flash_tween.is_valid():
			_save_flash_tween.kill()
		save_btn.text = "Saved ✓"
		save_btn.add_theme_color_override("font_color", COL_POSITIVE)
		_save_flash_tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		_save_flash_tween.tween_interval(1.4)
		_save_flash_tween.tween_callback(func():
			if is_instance_valid(save_btn):
				save_btn.text = "Save Game"
				save_btn.add_theme_color_override("font_color", Color(0.98, 0.91, 0.78, 0.94))
		)


func _on_exit_pressed() -> void:
	_play_confirm()
	SaveManager.force_save()
	get_tree().quit()


func _update_menu_interaction(enabled: bool) -> void:
	var mode = Control.MOUSE_FILTER_STOP if enabled else Control.MOUSE_FILTER_IGNORE
	buttons.mouse_filter = mode
	for child in buttons.get_children():
		if child is Control:
			child.mouse_filter = mode


func _duck_audio(enable: bool) -> void:
	var music_idx = AudioServer.get_bus_index("Music")
	if music_idx < 0:
		return

	var amp = AudioServer.get_bus_effect(music_idx, 0)
	var lpf = AudioServer.get_bus_effect(music_idx, 1)

	var target_amp = DUCK_AMOUNT if enable else 0.0
	var target_lpf = MUFFLE_CUTOFF if enable else NORMAL_CUTOFF

	var tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS).set_parallel(true)
	if amp is AudioEffectAmplify:
		tween.tween_property(amp, "volume_db", target_amp, FADE_DURATION)
	if lpf is AudioEffectLowPassFilter:
		tween.tween_property(lpf, "cutoff_hz", target_lpf, FADE_DURATION)


func _play_click() -> void:
	_ui_player.stream = _sfx_click
	_ui_player.play()

func _play_confirm() -> void:
	_ui_player.stream = _sfx_confirm
	_ui_player.play()

func _play_hover() -> void:
	_ui_player.stream = _sfx_hover
	_ui_player.play()


func _input(event: InputEvent) -> void:
	if (event.is_action_pressed("ui_cancel") or (event is InputEventKey and event.keycode == KEY_ESCAPE and event.pressed)):
		if visible:
			get_viewport().set_input_as_handled()
			if options_overlay.visible:
				options_overlay.close()
			else:
				_play_confirm()
				resume()
