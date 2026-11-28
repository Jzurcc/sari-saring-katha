class_name LoadSlotsOverlay
extends Control

## Centered, single-panel 1–2 step Save Slot & History modal over a darkened backdrop.
##   - Step 1 (Slots):   3 side-by-side portrait cards; click a card to load (or start new) immediately.
##   - Step 2 (History): Optional in-place view for Manual Saves & Auto-Backups on a slot.

enum Mode { LOAD, NEW_GAME }

signal load_slot_requested(slot_id: int)
signal load_backup_requested(slot_id: int, backup_path: String)
signal new_game_slot_requested(slot_id: int)
signal slot_deleted(slot_id: int)
signal closed

const COL_BACKDROP := Color(0.018, 0.014, 0.010, 0.80)
const COL_FRAME_BG := Color(0.058, 0.050, 0.044, 0.98)
const COL_CARD_BG := Color(0.095, 0.082, 0.072, 0.96)
const COL_CARD_SEL := Color(0.148, 0.122, 0.088, 0.99)
const COL_CARD_EMPTY := Color(0.074, 0.065, 0.056, 0.88)
const COL_GOLD := Color(0.835, 0.624, 0.278, 1.0)
const COL_GOLD_BRIGHT := Color(1.0, 0.875, 0.56, 1.0)
const COL_CREAM := Color(1.0, 0.945, 0.85, 1.0)
const COL_CREAM_MUTED := Color(0.86, 0.79, 0.69, 0.82)
const COL_POS := Color(0.56, 0.94, 0.52, 1.0)
const COL_DANGER := Color(0.88, 0.36, 0.32, 1.0)

const ICON_CLOSE := "res://Assets/ui/icons/x.png"
const ICON_BACKUPS := "res://Assets/ui/icons/history.png"
const ICON_DELETE := "res://Assets/ui/icons/trash-2.png"

const HadesEmblem = preload("res://Scripts/UI/HadesDiamondEmblem.gd")

var _mode: Mode = Mode.LOAD
var _selected_slot: int = 1
var _history_slot: int = -1 # -1 = Step 1 (Slots), >= 1 = Step 2 (Slot History)
var _active_snapshot_tab: String = "manual" # "manual" | "backups"
var _slot_summaries: Dictionary = {}

var _frame: PanelContainer
var _back_btn: Button
var _title_lbl: Label
var _content_host: VBoxContainer
var _confirm_banner: PanelContainer
var _confirm_lbl: Label
var _confirm_yes_btn: Button
var _confirm_no_btn: Button
var _pending_confirm_action: Callable

var _sfx_click: AudioStream = preload("res://Audio/SFX/ui_sfx_4.mp3")
var _sfx_hover: AudioStream = preload("res://Audio/SFX/ui_sfx_12.mp3")
var _sfx_player: AudioStreamPlayer


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false

	_sfx_player = AudioStreamPlayer.new()
	_sfx_player.bus = "SFX"
	add_child(_sfx_player)

	_build_ui()


func open(mode: Mode = Mode.LOAD) -> void:
	_mode = mode
	_history_slot = -1
	_hide_inline_confirm()
	_refresh_summaries()

	if _mode == Mode.NEW_GAME:
		_selected_slot = SaveManager.get_first_empty_slot()
	else:
		_selected_slot = SaveManager.get_active_slot()
		if not SaveManager.has_slot_save(_selected_slot):
			for s in range(1, SaveManager.MAX_SLOTS + 1):
				if SaveManager.has_slot_save(s):
					_selected_slot = s
					break

	_rebuild_view()

	visible = true
	modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 1.0, 0.16).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


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
			elif _history_slot > 0:
				_play_click()
				_history_slot = -1
				_rebuild_view()
			else:
				_play_click()
				close()
		elif _history_slot < 0 and (event.keycode == KEY_LEFT or event.keycode == KEY_A):
			get_viewport().set_input_as_handled()
			_select_slot(wrapi(_selected_slot - 1, 1, SaveManager.MAX_SLOTS + 1))
		elif _history_slot < 0 and (event.keycode == KEY_RIGHT or event.keycode == KEY_D):
			get_viewport().set_input_as_handled()
			_select_slot(wrapi(_selected_slot + 1, 1, SaveManager.MAX_SLOTS + 1))
		elif event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER:
			get_viewport().set_input_as_handled()
			if _confirm_banner.visible:
				_confirm_yes_btn.pressed.emit()
			elif _history_slot < 0:
				_activate_slot(_selected_slot)


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
	_rebuild_view()


func _build_ui() -> void:
	# Full-screen darkened backdrop
	var backdrop := ColorRect.new()
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.color = COL_BACKDROP
	backdrop.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			if _confirm_banner.visible:
				_hide_inline_confirm()
			else:
				_play_click()
				close()
	)
	add_child(backdrop)

	# True full-screen CenterContainer so the modal always sits dead-center
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)

	_frame = PanelContainer.new()
	_frame.custom_minimum_size = Vector2(960, 0)
	_frame.mouse_filter = Control.MOUSE_FILTER_STOP
	var f_st := UIStyle.create_flat_stylebox(COL_FRAME_BG, 16, 34, 28)
	f_st.border_color = Color(COL_GOLD.r, COL_GOLD.g, COL_GOLD.b, 0.85)
	f_st.set_border_width_all(2)
	f_st.shadow_color = Color(0.0, 0.0, 0.0, 0.82)
	f_st.shadow_size = 38
	_frame.add_theme_stylebox_override("panel", f_st)
	center.add_child(_frame)

	var root_vb := VBoxContainer.new()
	root_vb.add_theme_constant_override("separation", 18)
	_frame.add_child(root_vb)

	# ── Header Row ────────────────────────────────────────────────────────
	var hdr := HBoxContainer.new()
	hdr.add_theme_constant_override("separation", 12)
	root_vb.add_child(hdr)

	_back_btn = Button.new()
	_back_btn.text = "← Slots"
	_back_btn.visible = false
	_back_btn.custom_minimum_size = Vector2(104, 42)
	_back_btn.focus_mode = Control.FOCUS_NONE
	_back_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	UIStyle.style_button(_back_btn, Color(0.15, 0.12, 0.10, 0.95), COL_CREAM, 16.0, 8)
	_back_btn.pressed.connect(func():
		_play_click()
		_hide_inline_confirm()
		_history_slot = -1
		_rebuild_view()
	)
	hdr.add_child(_back_btn)

	_title_lbl = Label.new()
	_title_lbl.text = "Load Game"
	_title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title_lbl.add_theme_font_override("font", UIStyle.FONT_FREDOKA_BOLD)
	_title_lbl.add_theme_font_size_override("font_size", 34)
	_title_lbl.add_theme_color_override("font_color", COL_GOLD_BRIGHT)
	hdr.add_child(_title_lbl)

	var close_btn := Button.new()
	close_btn.custom_minimum_size = Vector2(42, 42)
	close_btn.focus_mode = Control.FOCUS_NONE
	close_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	close_btn.tooltip_text = "Close"
	var close_tex := HadesEmblem.load_lucide_icon(ICON_CLOSE)
	if close_tex != null:
		close_btn.icon = close_tex
		close_btn.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		close_btn.expand_icon = true
	else:
		close_btn.text = "×"
	UIStyle.style_button(close_btn, Color(0.15, 0.12, 0.10, 0.95), COL_CREAM, 18.0, 8)
	close_btn.add_theme_color_override("icon_normal_color", COL_CREAM_MUTED)
	close_btn.add_theme_color_override("icon_hover_color", COL_GOLD_BRIGHT)
	close_btn.add_theme_color_override("icon_pressed_color", COL_CREAM)
	close_btn.pressed.connect(func():
		_play_click()
		close()
	)
	hdr.add_child(close_btn)

	var sep := ColorRect.new()
	sep.custom_minimum_size = Vector2(0, 1)
	sep.color = Color(COL_GOLD.r, COL_GOLD.g, COL_GOLD.b, 0.30)
	root_vb.add_child(sep)

	# ── Dynamic Content Host ──────────────────────────────────────────────
	_content_host = VBoxContainer.new()
	_content_host.add_theme_constant_override("separation", 12)
	root_vb.add_child(_content_host)

	# ── Inline Confirmation Banner (Overwrite / Delete / Restore) ─────────
	_confirm_banner = PanelContainer.new()
	_confirm_banner.visible = false
	var cb_st := UIStyle.create_flat_stylebox(Color(0.22, 0.09, 0.08, 0.96), 10, 16, 12)
	cb_st.border_color = COL_DANGER
	cb_st.set_border_width_all(2)
	_confirm_banner.add_theme_stylebox_override("panel", cb_st)
	root_vb.add_child(_confirm_banner)

	var cb_row := HBoxContainer.new()
	cb_row.add_theme_constant_override("separation", 10)
	_confirm_banner.add_child(cb_row)

	_confirm_lbl = Label.new()
	_confirm_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_confirm_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_confirm_lbl.add_theme_font_override("font", UIStyle.FONT_FREDOKA_SEMIBOLD)
	_confirm_lbl.add_theme_font_size_override("font_size", 15)
	_confirm_lbl.add_theme_color_override("font_color", COL_CREAM)
	cb_row.add_child(_confirm_lbl)

	_confirm_no_btn = Button.new()
	_confirm_no_btn.text = "Cancel"
	_confirm_no_btn.custom_minimum_size = Vector2(88, 36)
	_confirm_no_btn.focus_mode = Control.FOCUS_NONE
	_confirm_no_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	UIStyle.style_button(_confirm_no_btn, Color(0.18, 0.15, 0.12, 0.95), COL_CREAM, 14.0, 8)
	_confirm_no_btn.pressed.connect(func():
		_play_click()
		_hide_inline_confirm()
	)
	cb_row.add_child(_confirm_no_btn)

	_confirm_yes_btn = Button.new()
	_confirm_yes_btn.text = "Confirm"
	_confirm_yes_btn.custom_minimum_size = Vector2(104, 36)
	_confirm_yes_btn.focus_mode = Control.FOCUS_NONE
	_confirm_yes_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	UIStyle.style_button(_confirm_yes_btn, Color(0.68, 0.22, 0.20, 0.98), Color.WHITE, 14.0, 8)
	_confirm_yes_btn.pressed.connect(func():
		_play_click()
		var act := _pending_confirm_action
		_hide_inline_confirm()
		if act.is_valid():
			act.call()
	)
	cb_row.add_child(_confirm_yes_btn)


func _show_inline_confirm(msg: String, confirm_label: String, on_confirm: Callable) -> void:
	_confirm_lbl.text = msg
	_confirm_yes_btn.text = confirm_label
	_pending_confirm_action = on_confirm
	_confirm_banner.visible = true


func _hide_inline_confirm() -> void:
	if is_instance_valid(_confirm_banner):
		_confirm_banner.visible = false
	_pending_confirm_action = Callable()


func _rebuild_view() -> void:
	for child in _content_host.get_children():
		child.queue_free()

	if _history_slot > 0:
		_back_btn.visible = true
		_title_lbl.text = "Slot %d Backups" % _history_slot
		_build_history_step(_history_slot)
	else:
		_back_btn.visible = false
		_title_lbl.text = "New Game" if _mode == Mode.NEW_GAME else "Load Game"
		_build_slots_step()


func _build_slots_step() -> void:
	var cards_row := HBoxContainer.new()
	cards_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cards_row.add_theme_constant_override("separation", 20)
	_content_host.add_child(cards_row)

	var backup_tex := HadesEmblem.load_lucide_icon(ICON_BACKUPS)
	var delete_tex := HadesEmblem.load_lucide_icon(ICON_DELETE)

	for s in range(1, SaveManager.MAX_SLOTS + 1):
		var info: Dictionary = _slot_summaries.get(s, {"slot_id": s, "exists": false})
		var is_sel := (s == _selected_slot)
		var exists := bool(info.get("exists", false))

		var card := PanelContainer.new()
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.custom_minimum_size = Vector2(284, 380)
		card.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

		var bg := COL_CARD_SEL if is_sel else (COL_CARD_BG if exists else COL_CARD_EMPTY)
		var st := UIStyle.create_flat_stylebox(bg, 14, 22, 22)
		st.border_color = COL_GOLD_BRIGHT if is_sel else Color(COL_GOLD.r, COL_GOLD.g, COL_GOLD.b, 0.36 if exists else 0.18)
		st.border_width_top = 4 if is_sel else 1
		st.border_width_left = 2 if is_sel else 1
		st.border_width_right = 2 if is_sel else 1
		st.border_width_bottom = 2 if is_sel else 1
		card.add_theme_stylebox_override("panel", st)

		card.mouse_entered.connect(func():
			if _selected_slot != s:
				_selected_slot = s
				_play_hover()
				_rebuild_view()
		)
		card.gui_input.connect(func(ev: InputEvent):
			if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
				_selected_slot = s
				_activate_slot(s)
		)
		cards_row.add_child(card)

		var vb := VBoxContainer.new()
		vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vb.add_theme_constant_override("separation", 12)
		card.add_child(vb)

		# Card Header: Slot N + Last Played
		var top_line := HBoxContainer.new()
		top_line.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vb.add_child(top_line)

		var slot_lbl := Label.new()
		slot_lbl.text = "Slot %d" % s
		slot_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		slot_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot_lbl.add_theme_font_override("font", UIStyle.FONT_FREDOKA_BOLD)
		slot_lbl.add_theme_font_size_override("font_size", 24)
		slot_lbl.add_theme_color_override("font_color", COL_GOLD_BRIGHT if is_sel else COL_CREAM)
		top_line.add_child(slot_lbl)

		if exists and bool(info.get("is_active", false)):
			var active_lbl := Label.new()
			active_lbl.text = "Last Played"
			active_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			active_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
			active_lbl.add_theme_font_override("font", UIStyle.FONT_FREDOKA_SEMIBOLD)
			active_lbl.add_theme_font_size_override("font_size", 14)
			active_lbl.add_theme_color_override("font_color", COL_POS)
			top_line.add_child(active_lbl)

		var div := ColorRect.new()
		div.custom_minimum_size = Vector2(0, 1)
		div.mouse_filter = Control.MOUSE_FILTER_IGNORE
		div.color = Color(COL_GOLD.r, COL_GOLD.g, COL_GOLD.b, 0.28 if exists else 0.14)
		vb.add_child(div)

		if exists:
			var day_n := int(info.get("day", 1))
			var lv_n := int(info.get("player_level", 1))
			var money_f := float(info.get("money", 0.0))
			var paid := float(info.get("tally_paid", 0.0))
			var goal := maxf(1.0, float(info.get("tally_goal", 3000.0)))
			var pct := clampf(paid / goal, 0.0, 1.0)
			var ledger_txt := "Ledger Sealed" if pct >= 0.999 else ("Ledger %.0f%%" % (pct * 100.0))

			var day_lbl := Label.new()
			day_lbl.text = "Day %d" % day_n
			day_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			day_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
			day_lbl.add_theme_font_override("font", UIStyle.FONT_FREDOKA_BOLD)
			day_lbl.add_theme_font_size_override("font_size", 40)
			day_lbl.add_theme_color_override("font_color", COL_GOLD_BRIGHT)
			vb.add_child(day_lbl)

			var stats_vb := VBoxContainer.new()
			stats_vb.size_flags_vertical = Control.SIZE_EXPAND_FILL
			stats_vb.alignment = BoxContainer.ALIGNMENT_CENTER
			stats_vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
			stats_vb.add_theme_constant_override("separation", 6)
			vb.add_child(stats_vb)

			var cash_lbl := Label.new()
			cash_lbl.text = "₱%.0f  ·  Lv. %d" % [money_f, lv_n]
			cash_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			cash_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
			cash_lbl.add_theme_font_override("font", UIStyle.FONT_FREDOKA_SEMIBOLD)
			cash_lbl.add_theme_font_size_override("font_size", 20)
			cash_lbl.add_theme_color_override("font_color", COL_CREAM)
			stats_vb.add_child(cash_lbl)

			var ledger_lbl := Label.new()
			ledger_lbl.text = ledger_txt
			ledger_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			ledger_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
			ledger_lbl.add_theme_font_override("font", UIStyle.FONT_FREDOKA_REG)
			ledger_lbl.add_theme_font_size_override("font_size", 16)
			ledger_lbl.add_theme_color_override("font_color", COL_POS if pct >= 0.999 else COL_CREAM_MUTED)
			stats_vb.add_child(ledger_lbl)

			var ts := _format_timestamp(str(info.get("last_save_time", "")))
			if not ts.is_empty():
				var ts_lbl := Label.new()
				ts_lbl.text = ts
				ts_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				ts_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
				ts_lbl.add_theme_font_override("font", UIStyle.FONT_FREDOKA_REG)
				ts_lbl.add_theme_font_size_override("font_size", 14)
				ts_lbl.add_theme_color_override("font_color", Color(COL_CREAM_MUTED.r, COL_CREAM_MUTED.g, COL_CREAM_MUTED.b, 0.62))
				stats_vb.add_child(ts_lbl)

			# Bottom Action Buttons with Lucide icons
			var actions := HBoxContainer.new()
			actions.add_theme_constant_override("separation", 10)
			vb.add_child(actions)

			if _mode == Mode.LOAD:
				var manuals := SaveManager.list_slot_manual_saves(s)
				var backups := SaveManager.list_slot_backups(s)
				if not manuals.is_empty() or not backups.is_empty():
					var hist_btn := Button.new()
					hist_btn.text = "Backups"
					if backup_tex != null:
						hist_btn.icon = backup_tex
						hist_btn.expand_icon = true
						hist_btn.add_theme_constant_override("h_separation", 6)
					hist_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
					hist_btn.custom_minimum_size = Vector2(0, 40)
					hist_btn.focus_mode = Control.FOCUS_NONE
					hist_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
					UIStyle.style_button(hist_btn, Color(0.16, 0.14, 0.11, 0.94), COL_GOLD_BRIGHT, 15.0, 8)
					hist_btn.add_theme_color_override("icon_normal_color", COL_GOLD_BRIGHT)
					hist_btn.add_theme_color_override("icon_hover_color", COL_GOLD_BRIGHT)
					hist_btn.pressed.connect(func():
						_play_click()
						_hide_inline_confirm()
						_selected_slot = s
						_history_slot = s
						_active_snapshot_tab = "manual" if not manuals.is_empty() else "backups"
						_rebuild_view()
					)
					actions.add_child(hist_btn)

			var del_btn := Button.new()
			del_btn.text = "Delete"
			if delete_tex != null:
				del_btn.icon = delete_tex
				del_btn.expand_icon = true
				del_btn.add_theme_constant_override("h_separation", 6)
			del_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			del_btn.custom_minimum_size = Vector2(0, 40)
			del_btn.focus_mode = Control.FOCUS_NONE
			del_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
			var del_col := Color(1.0, 0.68, 0.64, 1.0)
			UIStyle.style_button(del_btn, Color(0.20, 0.10, 0.10, 0.92), del_col, 15.0, 8)
			del_btn.add_theme_color_override("icon_normal_color", del_col)
			del_btn.add_theme_color_override("icon_hover_color", Color.WHITE)
			del_btn.pressed.connect(func():
				_play_click()
				_show_inline_confirm(
					"Delete Slot %d and its backups?" % s,
					"Delete",
					func():
						SaveManager.delete_slot(s)
						slot_deleted.emit(s)
						_refresh_summaries()
						_rebuild_view()
				)
			)
			actions.add_child(del_btn)
		else:
			var empty_box := VBoxContainer.new()
			empty_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
			empty_box.alignment = BoxContainer.ALIGNMENT_CENTER
			empty_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
			empty_box.add_theme_constant_override("separation", 8)
			vb.add_child(empty_box)

			var plus_lbl := Label.new()
			plus_lbl.text = "+"
			plus_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			plus_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
			plus_lbl.add_theme_font_override("font", UIStyle.FONT_FREDOKA_BOLD)
			plus_lbl.add_theme_font_size_override("font_size", 48)
			plus_lbl.add_theme_color_override("font_color", COL_GOLD if is_sel else Color(COL_CREAM_MUTED.r, COL_CREAM_MUTED.g, COL_CREAM_MUTED.b, 0.42))
			empty_box.add_child(plus_lbl)

			var empty_lbl := Label.new()
			empty_lbl.text = "Empty"
			empty_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			empty_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
			empty_lbl.add_theme_font_override("font", UIStyle.FONT_FREDOKA_REG)
			empty_lbl.add_theme_font_size_override("font_size", 19)
			empty_lbl.add_theme_color_override("font_color", COL_CREAM_MUTED if is_sel else Color(COL_CREAM_MUTED.r, COL_CREAM_MUTED.g, COL_CREAM_MUTED.b, 0.52))
			empty_box.add_child(empty_lbl)


func _build_history_step(slot_id: int) -> void:
	var manuals := SaveManager.list_slot_manual_saves(slot_id)
	var backups := SaveManager.list_slot_backups(slot_id)
	var m_active := (_active_snapshot_tab == "manual")

	var tab_row := HBoxContainer.new()
	tab_row.add_theme_constant_override("separation", 10)
	_content_host.add_child(tab_row)

	var manual_btn := Button.new()
	manual_btn.text = "Manual Saves (%d)" % manuals.size()
	manual_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	manual_btn.custom_minimum_size = Vector2(0, 36)
	manual_btn.focus_mode = Control.FOCUS_NONE
	manual_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	UIStyle.style_button(
		manual_btn,
		Color(0.30, 0.22, 0.11, 0.98) if m_active else Color(0.11, 0.095, 0.082, 0.92),
		COL_GOLD_BRIGHT if m_active else COL_CREAM_MUTED,
		15.0,
		8
	)
	manual_btn.pressed.connect(func():
		_play_hover()
		_active_snapshot_tab = "manual"
		_rebuild_view()
	)
	tab_row.add_child(manual_btn)

	var backup_btn := Button.new()
	backup_btn.text = "Auto-Backups (%d)" % backups.size()
	backup_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	backup_btn.custom_minimum_size = Vector2(0, 36)
	backup_btn.focus_mode = Control.FOCUS_NONE
	backup_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	UIStyle.style_button(
		backup_btn,
		Color(0.30, 0.22, 0.11, 0.98) if not m_active else Color(0.11, 0.095, 0.082, 0.92),
		COL_GOLD_BRIGHT if not m_active else COL_CREAM_MUTED,
		15.0,
		8
	)
	backup_btn.pressed.connect(func():
		_play_hover()
		_active_snapshot_tab = "backups"
		_rebuild_view()
	)
	tab_row.add_child(backup_btn)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 320)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_content_host.add_child(scroll)

	var snap_list := VBoxContainer.new()
	snap_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	snap_list.add_theme_constant_override("separation", 8)
	scroll.add_child(snap_list)

	var entries: Array[Dictionary] = manuals if m_active else backups
	if entries.is_empty():
		var none_lbl := Label.new()
		none_lbl.text = "No saves yet."
		none_lbl.add_theme_font_override("font", UIStyle.FONT_FREDOKA_REG)
		none_lbl.add_theme_font_size_override("font_size", 15)
		none_lbl.add_theme_color_override("font_color", Color(COL_CREAM_MUTED.r, COL_CREAM_MUTED.g, COL_CREAM_MUTED.b, 0.60))
		snap_list.add_child(none_lbl)
		return

	for entry in entries:
		var row_panel := PanelContainer.new()
		row_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var r_st := UIStyle.create_flat_stylebox(COL_CARD_BG, 8, 14, 10)
		r_st.border_color = Color(COL_GOLD.r, COL_GOLD.g, COL_GOLD.b, 0.32)
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

		var e_lbl := str(entry.get("save_label", "Save"))
		var e_title := Label.new()
		e_title.text = "%s  ·  ₱%.0f" % [e_lbl, float(entry.get("money", 0.0))]
		e_title.add_theme_font_override("font", UIStyle.FONT_FREDOKA_SEMIBOLD)
		e_title.add_theme_font_size_override("font_size", 15)
		e_title.add_theme_color_override("font_color", COL_CREAM)
		info_col.add_child(e_title)

		var e_sub := Label.new()
		e_sub.text = "Day %d  ·  Lv. %d  ·  %s" % [
			int(entry.get("day", 1)),
			int(entry.get("player_level", 1)),
			_format_timestamp(str(entry.get("last_save_time", ""))),
		]
		e_sub.add_theme_font_override("font", UIStyle.FONT_FREDOKA_REG)
		e_sub.add_theme_font_size_override("font_size", 13)
		e_sub.add_theme_color_override("font_color", COL_CREAM_MUTED)
		info_col.add_child(e_sub)

		var e_path := str(entry.get("path", ""))
		var load_btn := Button.new()
		load_btn.text = "Load" if m_active else "Restore"
		load_btn.custom_minimum_size = Vector2(86, 34)
		load_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		load_btn.focus_mode = Control.FOCUS_NONE
		load_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		UIStyle.style_button(load_btn, Color(0.24, 0.19, 0.12, 0.96), COL_GOLD_BRIGHT, 14.0, 7)
		load_btn.pressed.connect(func():
			_play_click()
			_show_inline_confirm(
				"Load '%s' into Slot %d?" % [e_lbl, slot_id],
				"Load",
				func():
					visible = false
					load_backup_requested.emit(slot_id, e_path)
			)
		)
		hbox.add_child(load_btn)

		if m_active:
			var rm_btn := Button.new()
			var del_tex_row := HadesEmblem.load_lucide_icon(ICON_DELETE)
			if del_tex_row != null:
				rm_btn.icon = del_tex_row
				rm_btn.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
				rm_btn.expand_icon = true
			else:
				rm_btn.text = "×"
			rm_btn.tooltip_text = "Delete"
			rm_btn.custom_minimum_size = Vector2(38, 38)
			rm_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			rm_btn.focus_mode = Control.FOCUS_NONE
			rm_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
			var rm_col := Color(1.0, 0.65, 0.62, 1.0)
			UIStyle.style_button(rm_btn, Color(0.22, 0.10, 0.10, 0.92), rm_col, 16.0, 7)
			rm_btn.add_theme_color_override("icon_normal_color", rm_col)
			rm_btn.add_theme_color_override("icon_hover_color", Color.WHITE)
			rm_btn.pressed.connect(func():
				_play_click()
				_show_inline_confirm(
					"Delete '%s' from Slot %d?" % [e_lbl, slot_id],
					"Delete",
					func():
						SaveManager.delete_snapshot_file(e_path)
						_refresh_summaries()
						_rebuild_view()
				)
			)
			hbox.add_child(rm_btn)


func _activate_slot(slot_id: int) -> void:
	_play_click()
	var info: Dictionary = _slot_summaries.get(slot_id, {"exists": false})
	var exists := bool(info.get("exists", false))

	if _mode == Mode.NEW_GAME:
		if exists:
			_show_inline_confirm(
				"Overwrite Slot %d (Day %d)?" % [slot_id, int(info.get("day", 1))],
				"Overwrite",
				func():
					visible = false
					new_game_slot_requested.emit(slot_id)
			)
		else:
			visible = false
			new_game_slot_requested.emit(slot_id)
	else:
		if exists:
			visible = false
			load_slot_requested.emit(slot_id)
		else:
			visible = false
			new_game_slot_requested.emit(slot_id)


func _format_timestamp(iso_str: String) -> String:
	if iso_str.is_empty():
		return ""
	var parts := iso_str.split("T")
	if parts.size() >= 2:
		return "%s %s" % [parts[0], parts[1].substr(0, 5)]
	return iso_str
