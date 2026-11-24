class_name PendingDebtHUD
extends CanvasLayer

## Persistent top-left HUD pill (underneath MoneyContainer) reminding the player
## whenever one or more Utang (credit) sales need to be recorded in the Loan Notebook.

const COL_BG := Color(0.082, 0.068, 0.052, 0.92)
const COL_GOLD := Color(0.95, 0.78, 0.34, 1.0)
const COL_GOLD_BRIGHT := Color(1.0, 0.92, 0.62, 1.0)
const COL_CREAM := Color(1.0, 0.95, 0.84, 1.0)
const COL_CREAM_MUTED := Color(0.84, 0.76, 0.64, 0.88)

var _bold_font: FontVariation
var _pill: PanelContainer
var _pill_style: StyleBoxFlat
var _icon_lbl: Label
var _title_lbl: Label
var _sub_lbl: Label
var _vis_tween: Tween = null
var _pulse_tween: Tween = null
var _is_shown: bool = false
var _last_count: int = 0

func _ready() -> void:
	layer = 40
	_bold_font = FontVariation.new()
	_bold_font.base_font = UIStyle.FONT_INDER
	_bold_font.variation_embolden = 0.65
	_build_ui()
	StoryManager.pending_debts_changed.connect(_refresh)
	EventBus.day_started.connect(func(_d): _refresh())
	_refresh(true)

func _build_ui() -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	_pill = PanelContainer.new()
	_pill.position = Vector2(24.0, 74.0)
	_pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pill_style = UIStyle.create_flat_stylebox(COL_BG, 10, 14, 8)
	_pill_style.border_color = COL_GOLD
	_pill_style.border_width_left = 3
	_pill_style.border_width_top = 1
	_pill_style.border_width_right = 1
	_pill_style.border_width_bottom = 1
	_pill_style.shadow_color = Color(0.0, 0.0, 0.0, 0.45)
	_pill_style.shadow_size = 12
	_pill_style.shadow_offset = Vector2(0, 4)
	_pill.add_theme_stylebox_override("panel", _pill_style)
	_pill.visible = false
	_pill.modulate.a = 0.0
	root.add_child(_pill)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 10)
	hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pill.add_child(hbox)

	var dot_bg := PanelContainer.new()
	dot_bg.custom_minimum_size = Vector2(28, 28)
	dot_bg.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	dot_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ds := UIStyle.create_flat_stylebox(Color(0.95, 0.78, 0.34, 0.22), 999, 0, 0)
	ds.border_color = COL_GOLD_BRIGHT
	ds.set_border_width_all(1)
	dot_bg.add_theme_stylebox_override("panel", ds)
	hbox.add_child(dot_bg)

	_icon_lbl = Label.new()
	_icon_lbl.text = "!"
	_icon_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_icon_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_icon_lbl.add_theme_font_override("font", _bold_font)
	_icon_lbl.add_theme_font_size_override("font_size", 17)
	_icon_lbl.add_theme_color_override("font_color", COL_GOLD_BRIGHT)
	_icon_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dot_bg.add_child(_icon_lbl)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 0)
	col.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_child(col)

	_title_lbl = Label.new()
	_title_lbl.text = "Record Utang"
	_title_lbl.add_theme_font_override("font", _bold_font)
	_title_lbl.add_theme_font_size_override("font_size", 15)
	_title_lbl.add_theme_color_override("font_color", COL_GOLD_BRIGHT)
	_title_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(_title_lbl)

	_sub_lbl = Label.new()
	_sub_lbl.text = "Log in Loan Notebook"
	_sub_lbl.add_theme_font_override("font", UIStyle.FONT_INDER)
	_sub_lbl.add_theme_font_size_override("font_size", 12)
	_sub_lbl.add_theme_color_override("font_color", COL_CREAM_MUTED)
	_sub_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(_sub_lbl)

func _refresh(immediate: bool = false) -> void:
	var count := StoryManager.pending_debts.size()
	if count <= 0:
		_last_count = 0
		_hide_pill(immediate)
		return

	_title_lbl.text = "Record Utang (%d)" % count if count > 1 else "Record Utang"
	_sub_lbl.text = "Log %d unpaid loans in Notebook" % count if count > 1 else "Log unpaid loan in Notebook"

	if not _is_shown:
		_show_pill(immediate)
	elif count > _last_count:
		_pop_attention()
	_last_count = count

func _show_pill(immediate: bool) -> void:
	_is_shown = true
	if _vis_tween and _vis_tween.is_valid():
		_vis_tween.kill()
	_pill.visible = true
	if immediate:
		_pill.position = Vector2(24.0, 74.0)
		_pill.modulate.a = 1.0
		_pill.scale = Vector2.ONE
		_start_border_pulse()
		return

	_pill.position = Vector2(-20.0, 74.0)
	_pill.modulate.a = 0.0
	_pill.scale = Vector2(0.92, 0.92)
	_vis_tween = create_tween().set_parallel(true)
	_vis_tween.tween_property(_pill, "position:x", 24.0, 0.34).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_vis_tween.tween_property(_pill, "modulate:a", 1.0, 0.22).set_trans(Tween.TRANS_SINE)
	_vis_tween.tween_property(_pill, "scale", Vector2.ONE, 0.30).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_start_border_pulse()

func _hide_pill(immediate: bool) -> void:
	_stop_border_pulse()
	if not _is_shown and not _pill.visible:
		return
	_is_shown = false
	if _vis_tween and _vis_tween.is_valid():
		_vis_tween.kill()
	if immediate:
		_pill.visible = false
		_pill.modulate.a = 0.0
		return
	_vis_tween = create_tween().set_parallel(true)
	_vis_tween.tween_property(_pill, "position:x", -16.0, 0.24).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	_vis_tween.tween_property(_pill, "modulate:a", 0.0, 0.22).set_trans(Tween.TRANS_SINE)
	_vis_tween.chain().tween_callback(func():
		if not _is_shown:
			_pill.visible = false
	)

func _pop_attention() -> void:
	_pill.pivot_offset = _pill.size * 0.5
	var tw := create_tween()
	tw.tween_property(_pill, "scale", Vector2(1.07, 1.07), 0.10).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(_pill, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _start_border_pulse() -> void:
	if _pulse_tween and _pulse_tween.is_valid():
		return
	_pulse_tween = create_tween().set_loops()
	_pulse_tween.tween_property(_pill_style, "border_color", COL_GOLD_BRIGHT, 0.85).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_pulse_tween.tween_property(_pill_style, "border_color", Color(COL_GOLD.r, COL_GOLD.g, COL_GOLD.b, 0.45), 0.85).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func _stop_border_pulse() -> void:
	if _pulse_tween and _pulse_tween.is_valid():
		_pulse_tween.kill()
	_pulse_tween = null
