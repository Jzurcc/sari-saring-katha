class_name LoadSlotsOverlay
extends Control

## Modernized Slotted Save & Backup Browser (game-ui-design compliant).
## Supports two modes:
##   - Mode.LOAD:     Browse 3 slots, load a slot's active progress OR restore any of its rolling backups, or delete a slot.
##   - Mode.NEW_GAME: Pick an empty slot (or confirm overwriting an occupied slot) for a fresh run.
##
## Features 90% title-safe framing, Espresso & Antique Gold styling, progressive master/detail disclosure,
## keyboard/gamepad navigation (Up/Down, Enter/Space, Esc), and inline overwrite/delete confirmation.

enum Mode { LOAD, NEW_GAME }

signal load_slot_requested(slot_id: int)
signal load_backup_requested(slot_id: int, backup_path: String)
signal new_game_slot_requested(slot_id: int)
signal slot_deleted(slot_id: int)
signal closed

const COL_BACKDROP := Color(0.032, 0.026, 0.022, 0.86)
const COL_FRAME_BG := Color(0.058, 0.050, 0.044, 0.97)
const COL_CARD_BG := Color(0.092, 0.080, 0.070, 0.96)
const COL_CARD_SEL := Color(0.145, 0.120, 0.088, 0.98)
const COL_CARD_EMPTY := Color(0.072, 0.064, 0.056, 0.85)
const COL_GOLD := Color(0.835, 0.624, 0.278, 1.0)
const COL_GOLD_BRIGHT := Color(1.0, 0.875, 0.56, 1.0)
const COL_CREAM := Color(1.0, 0.945, 0.85, 1.0)
const COL_CREAM_MUTED := Color(0.86, 0.79, 0.69, 0.85)
const COL_POS := Color(0.56, 0.94, 0.52, 1.0)
const COL_DANGER := Color(0.88, 0.36, 0.32, 1.0)

var _mode: Mode = Mode.LOAD
var _selected_slot: int = 1
var _active_snapshot_tab: String = "manual" # "manual" | "backups"
var _slot_summaries: Dictionary = {} # slot_id -> Dictionary
var _slot_buttons: Dictionary = {}   # slot_id -> PanelContainer

var _frame: PanelContainer
var _title_lbl: Label
var _subtitle_lbl: Label
var _slots_list: VBoxContainer
var _detail_host: VBoxContainer
var _confirm_banner: PanelContainer
var _confirm_lbl: Label
var _confirm_yes_btn: Button
var _confirm_no_btn: Button
var _pending_confirm_action: Callable

var _sfx_click: AudioStream = preload("res://Audio/SFX/ui_sfx_4.mp3")
var _sfx_hover: AudioStream = preload("res://Audio/SFX/ui_sfx_12.mp3")
var _sfx_player: AudioStreamPlayer


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false

	_sfx_player = AudioStreamPlayer.new()
	_sfx_player.bus = "SFX"
	add_child(_sfx_player)

	_build_ui()


func open(mode: Mode = Mode.LOAD) -> void:
	_mode = mode
	_hide_inline_confirm()
	_refresh_summaries()

	if _mode == Mode.NEW_GAME:
		_title_lbl.text = "Choose a Save Slot"
		_subtitle_lbl.text = "Pick an empty slot for a new tindahan, or select an existing slot to overwrite."
		_selected_slot = SaveManager.get_first_empty_slot()
	else:
		_title_lbl.text = "Load Store Progress"
		_subtitle_lbl.text = "Load a slot's latest progress, or roll back to any saved checkpoint backup."
		_selected_slot = SaveManager.get_active_slot()
		if not SaveManager.has_slot_save(_selected_slot):
			for s in range(1, SaveManager.MAX_SLOTS + 1):
				if SaveManager.has_slot_save(s):
					_selected_slot = s
					break

	_rebuild_slot_cards()
	_rebuild_detail_panel()

	visible = true
	modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 1.0, 0.18).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func close() -> void:
	if not visible:
		return
	_hide_inline_confirm()
	visible = false
	closed.emit()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			get_viewport().set_input_as_handled()
			if _confirm_banner.visible:
				_hide_inline_confirm()
			else:
				_play_click()
				close()
		elif event.keycode == KEY_UP or event.keycode == KEY_W:
			get_viewport().set_input_as_handled()
			_select_slot(wrapi(_selected_slot - 1, 1, SaveManager.MAX_SLOTS + 1))
		elif event.keycode == KEY_DOWN or event.keycode == KEY_S:
			get_viewport().set_input_as_handled()
			_select_slot(wrapi(_selected_slot + 1, 1, SaveManager.MAX_SLOTS + 1))
		elif event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER:
			get_viewport().set_input_as_handled()
			if _confirm_banner.visible:
				_confirm_yes_btn.pressed.emit()
			else:
				_trigger_primary_action()


func _play_click() -> void:
	if is_instance_valid(_sfx_player):
		_sfx_player.stream = _sfx_click
		_sfx_player.play()


func _play_hover() -> void:
	if is_instance_valid(_sfx_player):
		_sfx_player.stream = _sfx_hover
		_sfx_player.play()


func _refresh_summaries() -> void:
	_slot_summaries.clear()
	for s in range(1, SaveManager.MAX_SLOTS + 1):
		_slot_summaries[s] = SaveManager.get_slot_summary(s)


func _select_slot(slot_id: int) -> void:
	var clamped := clampi(slot_id, 1, SaveManager.MAX_SLOTS)
	if clamped == _selected_slot:
		return
	_selected_slot = clamped
	_play_hover()
	_hide_inline_confirm()
	_rebuild_slot_cards()
	_rebuild_detail_panel()


func _build_ui() -> void:
	# Dark dimmed backdrop
	var backdrop := ColorRect.new()
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.color = COL_BACKDROP
	add_child(backdrop)

	# 90% Title-Safe Main Frame (0.08..0.92)
	_frame = PanelContainer.new()
	_frame.anchor_left = 0.08
	_frame.anchor_right = 0.92
	_frame.anchor_top = 0.08
	_frame.anchor_bottom = 0.92
	var f_st := UIStyle.create_flat_stylebox(COL_FRAME_BG, 14, 28, 22)
	f_st.border_color = Color(COL_GOLD.r, COL_GOLD.g, COL_GOLD.b, 0.85)
	f_st.set_border_width_all(2)
	f_st.shadow_color = Color(0.0, 0.0, 0.0, 0.72)
	f_st.shadow_size = 28
	_frame.add_theme_stylebox_override("panel", f_st)
	add_child(_frame)

	var root_vb := VBoxContainer.new()
	root_vb.add_theme_constant_override("separation", 16)
	_frame.add_child(root_vb)

	# ── Header Row ────────────────────────────────────────────────────────
	var hdr := HBoxContainer.new()
	hdr.add_theme_constant_override("separation", 12)
	root_vb.add_child(hdr)

	var title_col := VBoxContainer.new()
	title_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_col.add_theme_constant_override("separation", 2)
	hdr.add_child(title_col)

	_title_lbl = Label.new()
	_title_lbl.text = "Load Store Progress"
	_title_lbl.add_theme_font_override("font", UIStyle.FONT_FREDOKA_BOLD)
	_title_lbl.add_theme_font_size_override("font_size", 32)
	_title_lbl.add_theme_color_override("font_color", COL_GOLD_BRIGHT)
	title_col.add_child(_title_lbl)

	_subtitle_lbl = Label.new()
	_subtitle_lbl.text = "Load a slot's latest progress, or roll back to a saved backup."
	_subtitle_lbl.add_theme_font_override("font", UIStyle.FONT_FREDOKA_REG)
	_subtitle_lbl.add_theme_font_size_override("font_size", 16)
	_subtitle_lbl.add_theme_color_override("font_color", COL_CREAM_MUTED)
	title_col.add_child(_subtitle_lbl)

	var close_btn := Button.new()
	close_btn.text = "Back  [Esc]"
	close_btn.custom_minimum_size = Vector2(132, 42)
	close_btn.focus_mode = Control.FOCUS_NONE
	close_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	UIStyle.style_button(close_btn, Color(0.16, 0.13, 0.10, 0.95), COL_CREAM, 16.0, 8)
	close_btn.pressed.connect(func():
		_play_click()
		close()
	)
	hdr.add_child(close_btn)

	var sep := ColorRect.new()
	sep.custom_minimum_size = Vector2(0, 1)
	sep.color = Color(COL_GOLD.r, COL_GOLD.g, COL_GOLD.b, 0.35)
	root_vb.add_child(sep)

	# ── Master / Detail Split Body ────────────────────────────────────────
	var split := HBoxContainer.new()
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	split.add_theme_constant_override("separation", 22)
	root_vb.add_child(split)

	# Left Column: 3 Save Slots
	var left_col := VBoxContainer.new()
	left_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_col.size_flags_stretch_ratio = 0.44
	left_col.add_theme_constant_override("separation", 12)
	split.add_child(left_col)

	var left_hdr := Label.new()
	left_hdr.text = "SAVE SLOTS"
	left_hdr.add_theme_font_override("font", UIStyle.FONT_FREDOKA_SEMIBOLD)
	left_hdr.add_theme_font_size_override("font_size", 15)
	left_hdr.add_theme_color_override("font_color", COL_GOLD)
	left_col.add_child(left_hdr)

	_slots_list = VBoxContainer.new()
	_slots_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_slots_list.add_theme_constant_override("separation", 12)
	left_col.add_child(_slots_list)

	# Right Column: Selected Slot Detail + Rolling Backups
	var right_panel := PanelContainer.new()
	right_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_panel.size_flags_stretch_ratio = 0.56
	var rp_st := UIStyle.create_flat_stylebox(Color(0.075, 0.065, 0.056, 0.96), 12, 20, 18)
	rp_st.border_color = Color(COL_GOLD.r, COL_GOLD.g, COL_GOLD.b, 0.42)
	rp_st.set_border_width_all(1)
	right_panel.add_theme_stylebox_override("panel", rp_st)
	split.add_child(right_panel)

	_detail_host = VBoxContainer.new()
	_detail_host.add_theme_constant_override("separation", 14)
	right_panel.add_child(_detail_host)

	# ── Inline Confirmation Banner (Hidden until Delete / Overwrite) ──────
	_confirm_banner = PanelContainer.new()
	_confirm_banner.visible = false
	var cb_st := UIStyle.create_flat_stylebox(Color(0.22, 0.09, 0.08, 0.96), 10, 18, 12)
	cb_st.border_color = COL_DANGER
	cb_st.set_border_width_all(2)
	_confirm_banner.add_theme_stylebox_override("panel", cb_st)
	root_vb.add_child(_confirm_banner)

	var cb_row := HBoxContainer.new()
	cb_row.add_theme_constant_override("separation", 12)
	_confirm_banner.add_child(cb_row)

	_confirm_lbl = Label.new()
	_confirm_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_confirm_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_confirm_lbl.add_theme_font_override("font", UIStyle.FONT_FREDOKA_SEMIBOLD)
	_confirm_lbl.add_theme_font_size_override("font_size", 16)
	_confirm_lbl.add_theme_color_override("font_color", COL_CREAM)
	cb_row.add_child(_confirm_lbl)

	_confirm_no_btn = Button.new()
	_confirm_no_btn.text = "Cancel"
	_confirm_no_btn.custom_minimum_size = Vector2(100, 38)
	_confirm_no_btn.focus_mode = Control.FOCUS_NONE
	_confirm_no_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	UIStyle.style_button(_confirm_no_btn, Color(0.18, 0.15, 0.12, 0.95), COL_CREAM, 15.0, 8)
	_confirm_no_btn.pressed.connect(func():
		_play_click()
		_hide_inline_confirm()
	)
	cb_row.add_child(_confirm_no_btn)

	_confirm_yes_btn = Button.new()
	_confirm_yes_btn.text = "Confirm"
	_confirm_yes_btn.custom_minimum_size = Vector2(118, 38)
	_confirm_yes_btn.focus_mode = Control.FOCUS_NONE
	_confirm_yes_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	UIStyle.style_button(_confirm_yes_btn, Color(0.68, 0.22, 0.20, 0.98), Color.WHITE, 15.0, 8)
	_confirm_yes_btn.pressed.connect(func():
		_play_click()
		var act := _pending_confirm_action
		_hide_inline_confirm()
		if act.is_valid():
			act.call()
	)
	cb_row.add_child(_confirm_yes_btn)

	# ── Footer Controls Hint ──────────────────────────────────────────────
	var foot := Label.new()
	foot.text = "↑ / ↓ Select Slot   ·   Enter Confirm   ·   Esc Back"
	foot.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	foot.add_theme_font_override("font", UIStyle.FONT_FREDOKA_REG)
	foot.add_theme_font_size_override("font_size", 14)
	foot.add_theme_color_override("font_color", Color(COL_CREAM_MUTED.r, COL_CREAM_MUTED.g, COL_CREAM_MUTED.b, 0.65))
	root_vb.add_child(foot)


func _show_inline_confirm(msg: String, confirm_label: String, on_confirm: Callable) -> void:
	_confirm_lbl.text = msg
	_confirm_yes_btn.text = confirm_label
	_pending_confirm_action = on_confirm
	_confirm_banner.visible = true


func _hide_inline_confirm() -> void:
	if is_instance_valid(_confirm_banner):
		_confirm_banner.visible = false
	_pending_confirm_action = Callable()


func _rebuild_slot_cards() -> void:
	for child in _slots_list.get_children():
		child.queue_free()
	_slot_buttons.clear()

	for s in range(1, SaveManager.MAX_SLOTS + 1):
		var info: Dictionary = _slot_summaries.get(s, {"slot_id": s, "exists": false})
		var is_sel := (s == _selected_slot)
		var exists := bool(info.get("exists", false))

		var card := PanelContainer.new()
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.size_flags_vertical = Control.SIZE_EXPAND_FILL
		card.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

		var bg := COL_CARD_SEL if is_sel else (COL_CARD_BG if exists else COL_CARD_EMPTY)
		var st := UIStyle.create_flat_stylebox(bg, 10, 16, 12)
		st.border_color = COL_GOLD_BRIGHT if is_sel else Color(COL_GOLD.r, COL_GOLD.g, COL_GOLD.b, 0.36 if exists else 0.18)
		st.border_width_left = 5 if is_sel else 2
		st.border_width_top = 2 if is_sel else 1
		st.border_width_right = 2 if is_sel else 1
		st.border_width_bottom = 2 if is_sel else 1
		card.add_theme_stylebox_override("panel", st)

		card.gui_input.connect(func(ev: InputEvent):
			if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
				_select_slot(s)
		)
		_slots_list.add_child(card)
		_slot_buttons[s] = card

		var vb := VBoxContainer.new()
		vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vb.add_theme_constant_override("separation", 6)
		card.add_child(vb)

		var top_row := HBoxContainer.new()
		top_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vb.add_child(top_row)

		var slot_lbl := Label.new()
		slot_lbl.text = "SLOT %d" % s
		slot_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		slot_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot_lbl.add_theme_font_override("font", UIStyle.FONT_FREDOKA_BOLD)
		slot_lbl.add_theme_font_size_override("font_size", 20)
		slot_lbl.add_theme_color_override("font_color", COL_GOLD_BRIGHT if is_sel else COL_CREAM)
		top_row.add_child(slot_lbl)

		if exists:
			var badge_txt := "LAST PLAYED" if bool(info.get("is_active", false)) else ("%d BACKUPS" % int(info.get("backup_count", 0)))
			var badge := Label.new()
			badge.text = badge_txt
			badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
			badge.add_theme_font_override("font", UIStyle.FONT_FREDOKA_SEMIBOLD)
			badge.add_theme_font_size_override("font_size", 12)
			badge.add_theme_color_override("font_color", COL_POS if bool(info.get("is_active", false)) else COL_GOLD)
			top_row.add_child(badge)

			var stats_lbl := Label.new()
			var day_n := int(info.get("day", 1))
			var lv_n := int(info.get("player_level", 1))
			var money_f := float(info.get("money", 0.0))
			stats_lbl.text = "Day %d  ·  Lv. %d  ·  ₱%.0f" % [day_n, lv_n, money_f]
			stats_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
			stats_lbl.add_theme_font_override("font", UIStyle.FONT_FREDOKA_SEMIBOLD)
			stats_lbl.add_theme_font_size_override("font_size", 17)
			stats_lbl.add_theme_color_override("font_color", COL_CREAM)
			vb.add_child(stats_lbl)

			var paid := float(info.get("tally_paid", 0.0))
			var goal := maxf(1.0, float(info.get("tally_goal", 2000.0)))
			var pct := clampf(paid / goal, 0.0, 1.0)
			var ledger_lbl := Label.new()
			ledger_lbl.text = "Silver Ledger: SEALED" if pct >= 0.999 else ("Silver Ledger: ₱%.0f / ₱%.0f (%.0f%%)" % [paid, goal, pct * 100.0])
			ledger_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
			ledger_lbl.add_theme_font_override("font", UIStyle.FONT_FREDOKA_REG)
			ledger_lbl.add_theme_font_size_override("font_size", 14)
			ledger_lbl.add_theme_color_override("font_color", COL_POS if pct >= 0.999 else COL_CREAM_MUTED)
			vb.add_child(ledger_lbl)

			var ts_lbl := Label.new()
			ts_lbl.text = "%s  ·  %s" % [str(info.get("save_label", "Saved")), _format_timestamp(str(info.get("last_save_time", "")))]
			ts_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
			ts_lbl.add_theme_font_override("font", UIStyle.FONT_FREDOKA_REG)
			ts_lbl.add_theme_font_size_override("font_size", 13)
			ts_lbl.add_theme_color_override("font_color", Color(COL_CREAM_MUTED.r, COL_CREAM_MUTED.g, COL_CREAM_MUTED.b, 0.72))
			vb.add_child(ts_lbl)
		else:
			var empty_lbl := Label.new()
			empty_lbl.text = "Empty Slot — Ready for a new tindahan"
			empty_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
			empty_lbl.add_theme_font_override("font", UIStyle.FONT_FREDOKA_REG)
			empty_lbl.add_theme_font_size_override("font_size", 16)
			empty_lbl.add_theme_color_override("font_color", Color(COL_CREAM_MUTED.r, COL_CREAM_MUTED.g, COL_CREAM_MUTED.b, 0.58))
			vb.add_child(empty_lbl)


func _rebuild_detail_panel() -> void:
	for child in _detail_host.get_children():
		child.queue_free()

	var info: Dictionary = _slot_summaries.get(_selected_slot, {"slot_id": _selected_slot, "exists": false})
	var exists := bool(info.get("exists", false))

	var hdr := Label.new()
	hdr.text = "SLOT %d — %s" % [_selected_slot, "ACTIVE PROGRESS" if exists else "EMPTY SLOT"]
	hdr.add_theme_font_override("font", UIStyle.FONT_FREDOKA_BOLD)
	hdr.add_theme_font_size_override("font_size", 22)
	hdr.add_theme_color_override("font_color", COL_GOLD_BRIGHT)
	_detail_host.add_child(hdr)

	# ── Primary Action Card ───────────────────────────────────────────────
	var action_card := PanelContainer.new()
	var ac_st := UIStyle.create_flat_stylebox(Color(0.11, 0.095, 0.080, 0.96), 10, 16, 14)
	ac_st.border_color = Color(COL_GOLD.r, COL_GOLD.g, COL_GOLD.b, 0.50)
	ac_st.set_border_width_all(1)
	action_card.add_theme_stylebox_override("panel", ac_st)
	_detail_host.add_child(action_card)

	var ac_vb := VBoxContainer.new()
	ac_vb.add_theme_constant_override("separation", 10)
	action_card.add_child(ac_vb)

	if exists:
		var day_n := int(info.get("day", 1))
		var tier_n := int(info.get("current_tier", 1))
		var lv_n := int(info.get("player_level", 1))
		var money_f := float(info.get("money", 0.0))
		var arcs_n := int(info.get("completed_arcs", 0))
		var meta_lbl := Label.new()
		meta_lbl.text = "Day %d  ·  Tier %d  ·  Player Lv. %d  ·  ₱%.0f  ·  %d Stories Finished" % [day_n, tier_n, lv_n, money_f, arcs_n]
		meta_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		meta_lbl.add_theme_font_override("font", UIStyle.FONT_FREDOKA_SEMIBOLD)
		meta_lbl.add_theme_font_size_override("font_size", 16)
		meta_lbl.add_theme_color_override("font_color", COL_CREAM)
		ac_vb.add_child(meta_lbl)

		var btn_row := HBoxContainer.new()
		btn_row.add_theme_constant_override("separation", 12)
		ac_vb.add_child(btn_row)

		var primary_btn := Button.new()
		primary_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		primary_btn.custom_minimum_size = Vector2(0, 46)
		primary_btn.focus_mode = Control.FOCUS_NONE
		primary_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		if _mode == Mode.NEW_GAME:
			primary_btn.text = "Overwrite Slot %d & Start New Game" % _selected_slot
			UIStyle.style_button(primary_btn, Color(0.56, 0.24, 0.16, 0.98), Color.WHITE, 17.0, 8)
		else:
			primary_btn.text = "Load Slot %d Progress" % _selected_slot
			UIStyle.style_button(primary_btn, Color(0.42, 0.31, 0.14, 0.98), COL_GOLD_BRIGHT, 18.0, 8)
		primary_btn.pressed.connect(_trigger_primary_action)
		btn_row.add_child(primary_btn)

		var del_btn := Button.new()
		del_btn.text = "Delete"
		del_btn.custom_minimum_size = Vector2(96, 46)
		del_btn.focus_mode = Control.FOCUS_NONE
		del_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		UIStyle.style_button(del_btn, Color(0.22, 0.10, 0.10, 0.95), Color(1.0, 0.65, 0.62, 1.0), 15.0, 8)
		del_btn.pressed.connect(func():
			_play_click()
			var target := _selected_slot
			_show_inline_confirm(
				"Delete Slot %d and all of its saved backups permanently?" % target,
				"Delete Slot",
				func():
					SaveManager.delete_slot(target)
					slot_deleted.emit(target)
					_refresh_summaries()
					_rebuild_slot_cards()
					_rebuild_detail_panel()
			)
		)
		btn_row.add_child(del_btn)
	else:
		var desc := Label.new()
		desc.text = "This slot is empty. Start a fresh story behind Lola's counter here."
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc.add_theme_font_override("font", UIStyle.FONT_FREDOKA_REG)
		desc.add_theme_font_size_override("font_size", 16)
		desc.add_theme_color_override("font_color", COL_CREAM_MUTED)
		ac_vb.add_child(desc)

		var start_btn := Button.new()
		start_btn.text = "Start New Game in Slot %d" % _selected_slot
		start_btn.custom_minimum_size = Vector2(0, 48)
		start_btn.focus_mode = Control.FOCUS_NONE
		start_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		UIStyle.style_button(start_btn, Color(0.32, 0.44, 0.26, 0.98), Color.WHITE, 18.0, 8)
		start_btn.pressed.connect(_trigger_primary_action)
		ac_vb.add_child(start_btn)

	# ── Snapshots Tabs: Intentional Manual Saves vs. Rolling Auto-Backups ──
	var manuals := SaveManager.list_slot_manual_saves(_selected_slot)
	var backups := SaveManager.list_slot_backups(_selected_slot)
	if manuals.is_empty() and not backups.is_empty() and _active_snapshot_tab == "manual":
		_active_snapshot_tab = "backups"

	var tab_row := HBoxContainer.new()
	tab_row.add_theme_constant_override("separation", 10)
	_detail_host.add_child(tab_row)

	var manual_tab_btn := Button.new()
	manual_tab_btn.text = "Manual Saves (%d)" % manuals.size()
	manual_tab_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	manual_tab_btn.custom_minimum_size = Vector2(0, 36)
	manual_tab_btn.focus_mode = Control.FOCUS_NONE
	manual_tab_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var m_active := (_active_snapshot_tab == "manual")
	UIStyle.style_button(
		manual_tab_btn,
		Color(0.32, 0.24, 0.12, 0.98) if m_active else Color(0.11, 0.095, 0.082, 0.92),
		COL_GOLD_BRIGHT if m_active else COL_CREAM_MUTED,
		15.0,
		8
	)
	manual_tab_btn.pressed.connect(func():
		_play_hover()
		_active_snapshot_tab = "manual"
		_rebuild_detail_panel()
	)
	tab_row.add_child(manual_tab_btn)

	var backup_tab_btn := Button.new()
	backup_tab_btn.text = "Auto-Backups (%d)" % backups.size()
	backup_tab_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	backup_tab_btn.custom_minimum_size = Vector2(0, 36)
	backup_tab_btn.focus_mode = Control.FOCUS_NONE
	backup_tab_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var b_active := (_active_snapshot_tab == "backups")
	UIStyle.style_button(
		backup_tab_btn,
		Color(0.32, 0.24, 0.12, 0.98) if b_active else Color(0.11, 0.095, 0.082, 0.92),
		COL_GOLD_BRIGHT if b_active else COL_CREAM_MUTED,
		15.0,
		8
	)
	backup_tab_btn.pressed.connect(func():
		_play_hover()
		_active_snapshot_tab = "backups"
		_rebuild_detail_panel()
	)
	tab_row.add_child(backup_tab_btn)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_detail_host.add_child(scroll)

	var snap_list := VBoxContainer.new()
	snap_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	snap_list.add_theme_constant_override("separation", 8)
	scroll.add_child(snap_list)

	var active_entries: Array[Dictionary] = manuals if m_active else backups
	if active_entries.is_empty():
		var empty_lbl := Label.new()
		if m_active:
			empty_lbl.text = "No intentional saves in Slot %d yet. Click 'Save Game' in the Pause Menu anytime to pin a reloadable save here." % _selected_slot
		else:
			empty_lbl.text = "No auto-backups yet. Rolling backups are saved automatically at the start of each new day and on Tier upgrades."
		empty_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		empty_lbl.add_theme_font_override("font", UIStyle.FONT_FREDOKA_REG)
		empty_lbl.add_theme_font_size_override("font_size", 14)
		empty_lbl.add_theme_color_override("font_color", Color(COL_CREAM_MUTED.r, COL_CREAM_MUTED.g, COL_CREAM_MUTED.b, 0.65))
		snap_list.add_child(empty_lbl)
	else:
		for entry in active_entries:
			var row_panel := PanelContainer.new()
			row_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			var r_st := UIStyle.create_flat_stylebox(Color(0.095, 0.084, 0.072, 0.94), 8, 14, 10)
			r_st.border_color = Color(COL_GOLD.r, COL_GOLD.g, COL_GOLD.b, 0.42 if m_active else 0.26)
			r_st.set_border_width_all(1)
			row_panel.add_theme_stylebox_override("panel", r_st)
			snap_list.add_child(row_panel)

			var hbox := HBoxContainer.new()
			hbox.add_theme_constant_override("separation", 10)
			row_panel.add_child(hbox)

			var info_col := VBoxContainer.new()
			info_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			info_col.add_theme_constant_override("separation", 2)
			hbox.add_child(info_col)

			var e_title := Label.new()
			e_title.text = "%s  ·  ₱%.0f" % [str(entry.get("save_label", "Save")), float(entry.get("money", 0.0))]
			e_title.add_theme_font_override("font", UIStyle.FONT_FREDOKA_SEMIBOLD)
			e_title.add_theme_font_size_override("font_size", 15)
			e_title.add_theme_color_override("font_color", COL_CREAM)
			info_col.add_child(e_title)

			var e_sub := Label.new()
			var e_paid := float(entry.get("tally_paid", 0.0))
			var e_goal := maxf(1.0, float(entry.get("tally_goal", 2000.0)))
			e_sub.text = "Day %d  ·  Lv. %d  ·  Ledger %.0f%%  ·  %s" % [
				int(entry.get("day", 1)),
				int(entry.get("player_level", 1)),
				clampf((e_paid / e_goal) * 100.0, 0.0, 100.0),
				_format_timestamp(str(entry.get("last_save_time", ""))),
			]
			e_sub.add_theme_font_override("font", UIStyle.FONT_FREDOKA_REG)
			e_sub.add_theme_font_size_override("font_size", 13)
			e_sub.add_theme_color_override("font_color", COL_CREAM_MUTED)
			info_col.add_child(e_sub)

			var e_path := str(entry.get("path", ""))
			var e_lbl := str(entry.get("save_label", "Save"))
			var load_btn := Button.new()
			load_btn.text = "Load Save" if m_active else "Restore"
			load_btn.custom_minimum_size = Vector2(108, 36)
			load_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			load_btn.focus_mode = Control.FOCUS_NONE
			load_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
			UIStyle.style_button(load_btn, Color(0.22, 0.18, 0.12, 0.96), COL_GOLD_BRIGHT, 14.0, 7)
			load_btn.pressed.connect(func():
				_play_click()
				var target_slot := _selected_slot
				_show_inline_confirm(
					"Load '%s' into Slot %d? Active progress in Slot %d will roll back to this point." % [e_lbl, target_slot, target_slot],
					"Load Save",
					func():
						visible = false
						load_backup_requested.emit(target_slot, e_path)
				)
			)
			hbox.add_child(load_btn)

			if m_active:
				var rm_btn := Button.new()
				rm_btn.text = "×"
				rm_btn.tooltip_text = "Delete this manual save"
				rm_btn.custom_minimum_size = Vector2(36, 36)
				rm_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
				rm_btn.focus_mode = Control.FOCUS_NONE
				rm_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
				UIStyle.style_button(rm_btn, Color(0.22, 0.10, 0.10, 0.92), Color(1.0, 0.65, 0.62, 1.0), 16.0, 7)
				rm_btn.pressed.connect(func():
					_play_click()
					_show_inline_confirm(
						"Delete manual save '%s' from Slot %d?" % [e_lbl, _selected_slot],
						"Delete",
						func():
							SaveManager.delete_snapshot_file(e_path)
							_refresh_summaries()
							_rebuild_slot_cards()
							_rebuild_detail_panel()
					)
				)
				hbox.add_child(rm_btn)


func _trigger_primary_action() -> void:
	_play_click()
	var info: Dictionary = _slot_summaries.get(_selected_slot, {"exists": false})
	var exists := bool(info.get("exists", false))

	if _mode == Mode.NEW_GAME:
		if exists:
			var target := _selected_slot
			_show_inline_confirm(
				"Overwrite Slot %d (Day %d) with a brand-new game?" % [target, int(info.get("day", 1))],
				"Start New Game",
				func():
					visible = false
					new_game_slot_requested.emit(target)
			)
		else:
			visible = false
			new_game_slot_requested.emit(_selected_slot)
	else:
		if exists:
			visible = false
			load_slot_requested.emit(_selected_slot)
		else:
			visible = false
			new_game_slot_requested.emit(_selected_slot)


func _format_timestamp(iso_str: String) -> String:
	if iso_str.is_empty():
		return "Unknown time"
	var parts := iso_str.split("T")
	if parts.size() >= 2:
		return "%s %s" % [parts[0], parts[1].substr(0, 5)]
	return iso_str
