class_name EventsOverlay
extends CanvasLayer

## Dedicated Neighborhood Events overlay (Hotkey: K).
## Displays all active Neighborhood Events and Reyna Mayari Moon Cards in the same
## Hades-inspired warm espresso & antique gold card language as MayariTallyOverlay.

const COL_ESPRESSO_DEEP := Color(0.055, 0.048, 0.042, 0.96)
const COL_GOLD := Color(0.835, 0.624, 0.278, 1.0)
const COL_GOLD_BRIGHT := Color(1.0, 0.875, 0.56, 1.0)
const COL_EVENT := Color(0.95, 0.65, 0.24, 1.0)
const COL_EVENT_BRIGHT := Color(1.0, 0.84, 0.48, 1.0)
const COL_CHILL := Color(0.84, 0.37, 0.36, 1.0)
const COL_CHILL_SOFT := Color(0.95, 0.58, 0.54, 1.0)
const COL_CREAM := Color(1.0, 0.922, 0.792, 1.0)
const COL_CREAM_MUTED := Color(0.82, 0.75, 0.64, 0.84)
const COL_BROWN_BORDER := Color(0.482, 0.306, 0.102, 0.9)
const COL_STAT_POS := Color(0.56, 0.92, 0.52, 1.0)
const COL_STAT_NEG := Color(0.96, 0.48, 0.45, 1.0)
const COL_BOLD_CREAM := "#FFF6E5"
const HadesEmblem = preload("res://Scripts/UI/HadesDiamondEmblem.gd")

var is_open: bool = false
var _previous_mouse_mode: Input.MouseMode = Input.MOUSE_MODE_CAPTURED
var _bold_font: FontVariation

var _root: Control
var _backdrop: ColorRect
var _banner: PanelContainer
var _frame: PanelContainer
var _count_lbl: Label
var _cards_vbox: VBoxContainer

func _ready() -> void:
	layer = 55
	process_mode = Node.PROCESS_MODE_ALWAYS
	_bold_font = FontVariation.new()
	_bold_font.base_font = UIStyle.FONT_INDER
	_bold_font.variation_embolden = 0.65
	_build_ui()
	hide()
	EventBus.events_overlay_toggled.connect(_on_toggled)

func _build_ui() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_root)

	_backdrop = ColorRect.new()
	_backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	_backdrop.color = Color(0.035, 0.028, 0.024, 0.76)
	_root.add_child(_backdrop)

	# Top wide Hades-style banner
	_banner = PanelContainer.new()
	_banner.anchor_left = 0.14
	_banner.anchor_right = 0.86
	_banner.anchor_top = 0.045
	_banner.anchor_bottom = 0.165
	var b_style := UIStyle.create_flat_stylebox(COL_ESPRESSO_DEEP, 6, 30, 10)
	b_style.border_color = COL_GOLD
	b_style.set_border_width_all(2)
	b_style.shadow_color = Color(0.0, 0.0, 0.0, 0.55)
	b_style.shadow_size = 16
	_banner.add_theme_stylebox_override("panel", b_style)
	_root.add_child(_banner)

	var bv := VBoxContainer.new()
	bv.alignment = BoxContainer.ALIGNMENT_CENTER
	bv.add_theme_constant_override("separation", 4)
	_banner.add_child(bv)

	var title_row := HBoxContainer.new()
	bv.add_child(title_row)

	var left_pad := Control.new()
	left_pad.custom_minimum_size = Vector2(140, 0)
	title_row.add_child(left_pad)

	var title_lbl := Label.new()
	title_lbl.text = "N E I G H B O R H O O D   E V E N T S"
	title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_lbl.add_theme_font_override("font", UIStyle.FONT_INDER)
	title_lbl.add_theme_font_size_override("font_size", 30)
	title_lbl.add_theme_color_override("font_color", COL_CREAM)
	title_lbl.add_theme_color_override("font_outline_color", COL_BROWN_BORDER)
	title_lbl.add_theme_constant_override("outline_size", 4)
	title_row.add_child(title_lbl)

	var right_h := HBoxContainer.new()
	right_h.custom_minimum_size = Vector2(140, 0)
	right_h.alignment = BoxContainer.ALIGNMENT_END
	right_h.add_theme_constant_override("separation", 10)
	title_row.add_child(right_h)

	_count_lbl = Label.new()
	_count_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_count_lbl.add_theme_font_override("font", UIStyle.FONT_INDER)
	_count_lbl.add_theme_font_size_override("font_size", 16)
	_count_lbl.add_theme_color_override("font_color", COL_GOLD_BRIGHT)
	right_h.add_child(_count_lbl)

	var close_btn := Button.new()
	close_btn.text = "✕"
	close_btn.custom_minimum_size = Vector2(36, 36)
	close_btn.focus_mode = Control.FOCUS_NONE
	close_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	close_btn.add_theme_font_override("font", _bold_font)
	close_btn.add_theme_font_size_override("font_size", 18)
	var cs := UIStyle.create_flat_stylebox(Color(0.22, 0.14, 0.12, 0.9), 6, 6, 2)
	cs.border_color = COL_GOLD
	cs.set_border_width_all(1)
	close_btn.add_theme_stylebox_override("normal", cs)
	close_btn.add_theme_stylebox_override("hover", cs)
	close_btn.add_theme_stylebox_override("pressed", cs)
	close_btn.add_theme_color_override("font_color", COL_CREAM)
	close_btn.pressed.connect(close_overlay)
	right_h.add_child(close_btn)

	var sub_lbl := Label.new()
	sub_lbl.text = "Active conditions, rumors, and lunar omens across Karimlan today.  (Press K or Esc to close)"
	sub_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub_lbl.add_theme_font_override("font", UIStyle.FONT_INDER)
	sub_lbl.add_theme_font_size_override("font_size", 15)
	sub_lbl.add_theme_color_override("font_color", COL_CREAM_MUTED)
	bv.add_child(sub_lbl)

	# Centered Hades frame
	_frame = PanelContainer.new()
	_frame.anchor_left = 0.17
	_frame.anchor_right = 0.83
	_frame.anchor_top = 0.19
	_frame.anchor_bottom = 0.90
	var f_style := UIStyle.create_flat_stylebox(Color(0.058, 0.052, 0.046, 0.95), 8, 26, 20)
	f_style.border_color = Color(0.835, 0.624, 0.278, 0.78)
	f_style.set_border_width_all(2)
	f_style.shadow_color = Color(0.0, 0.0, 0.0, 0.6)
	f_style.shadow_size = 20
	_frame.add_theme_stylebox_override("panel", f_style)
	_root.add_child(_frame)

	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	_frame.add_child(scroll)

	_cards_vbox = VBoxContainer.new()
	_cards_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_cards_vbox.add_theme_constant_override("separation", 14)
	scroll.add_child(_cards_vbox)

func _on_toggled(opened: bool) -> void:
	if opened:
		if is_open:
			close_overlay()
		else:
			open_overlay()
	else:
		close_overlay()

func open_overlay() -> void:
	if is_open:
		return
	is_open = true
	_previous_mouse_mode = Input.mouse_mode
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if is_instance_valid(AudioManager):
		AudioManager.play_sfx("tab_switch")
	_populate_cards()
	show()
	_backdrop.modulate.a = 0.0
	_frame.modulate.a = 0.0
	_banner.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(_backdrop, "modulate:a", 1.0, 0.18).set_trans(Tween.TRANS_SINE)
	tw.parallel().tween_property(_banner, "modulate:a", 1.0, 0.22).set_trans(Tween.TRANS_SINE)
	tw.parallel().tween_property(_frame, "modulate:a", 1.0, 0.24).set_trans(Tween.TRANS_SINE)

func close_overlay() -> void:
	if not is_open:
		return
	is_open = false
	hide()
	Input.mouse_mode = _previous_mouse_mode
	if is_instance_valid(AudioManager):
		AudioManager.play_sfx("drop")

func _unhandled_input(event: InputEvent) -> void:
	if not is_open:
		return
	if event.is_action_pressed("ui_cancel") or (event is InputEventKey and event.pressed and not event.echo and (event.physical_keycode == KEY_K or event.keycode == KEY_K)):
		close_overlay()
		get_viewport().set_input_as_handled()

func _populate_cards() -> void:
	for child in _cards_vbox.get_children():
		_cards_vbox.remove_child(child)
		child.queue_free()

	var total_active := 0

	# 1. Active Neighborhood Events
	if is_instance_valid(StoreEventManager):
		for ev in StoreEventManager.get_active_events():
			_cards_vbox.add_child(_build_neighborhood_event_card(ev))
			total_active += 1

	# 2. Active Reyna Mayari Moon Card (treated as an active event too!)
	if StoryManager.active_mayari_card != "":
		var card := MayariCardRegistry.get_card(StoryManager.active_mayari_card)
		if not card.is_empty():
			_cards_vbox.add_child(_build_mayari_event_card(card))
			total_active += 1

	_count_lbl.text = "Day %d · %d Active" % [StoryManager.day, total_active]

	if total_active == 0:
		var empty_box := PanelContainer.new()
		empty_box.custom_minimum_size = Vector2(0, 140)
		var es := UIStyle.create_flat_stylebox(Color(0.088, 0.078, 0.068, 0.92), 8, 24, 24)
		es.border_color = Color(0.482, 0.306, 0.102, 0.65)
		es.set_border_width_all(1)
		empty_box.add_theme_stylebox_override("panel", es)
		var empty_lbl := Label.new()
		empty_lbl.text = "Karimlan is quiet today.\n\nNo active Neighborhood Events or lunar omens right now."
		empty_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		empty_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		empty_lbl.add_theme_font_override("font", UIStyle.FONT_INDER)
		empty_lbl.add_theme_font_size_override("font_size", 19)
		empty_lbl.add_theme_color_override("font_color", COL_CREAM_MUTED)
		empty_box.add_child(empty_lbl)
		_cards_vbox.add_child(empty_box)

func _category_display(cat: String) -> String:
	match cat.to_lower():
		"bottle": return "Beverages"
		"snack": return "Snacks"
		"can": return "Canned Goods"
		"cigarette": return "Cigarettes"
		"candy": return "Candies"
		"pack": return "Noodles"
		"sachet": return "Sachets"
		"frozen": return "Frozen"
		_: return cat.capitalize()

func _event_sigil(event_id: String) -> String:
	match event_id:
		"barangay_liga": return "◈"
		"brownout_notice": return "⚡"
		"payday_friday": return "₱"
		"summer_heat": return "☀"
		"typhoon_warning": return "〰"
		_: return "✦"

func _build_neighborhood_event_card(ev: StoreEventData) -> PanelContainer:
	var target_names: PackedStringArray = []
	for cat in ev.affected_categories:
		target_names.append(_category_display(cat))
	if target_names.is_empty():
		for it in ev.affected_items:
			if it:
				target_names.append(it.item_name)
	var targets_str := ", ".join(target_names) if not target_names.is_empty() else "Featured Stock"
	var desc_rich := "%s Neighbors are actively seeking [b]%s[/b] today." % [ev.description, targets_str]
	var demand_pct := int(roundf((ev.demand_multiplier - 1.0) * 100.0))
	var stats: Array = [
		{"label": "%s Demand:" % targets_str, "value": "+%d%%" % demand_pct, "tone": "pos"},
		{"label": "%s Price Tolerance:" % targets_str, "value": "+%d" % ev.tolerance_offset, "tone": "pos"},
	]
	return _build_hades_card(ev.event_name, _event_sigil(ev.event_id), desc_rich, stats, "event")

func _build_mayari_event_card(c_data: Dictionary) -> PanelContainer:
	var is_fav := str(c_data.get("kind", "")) == MayariCardRegistry.KIND_FAVOR
	var desc_rich := str(c_data.get("description_rich", c_data.get("description", "")))
	var stats: Array = c_data.get("stats", [])
	return _build_hades_card(
		str(c_data.get("title", "Moon Card")),
		str(c_data.get("sigil", "☽")),
		desc_rich,
		stats,
		"favor" if is_fav else "chill"
	)

func _build_hades_card(title: String, sigil: String, desc_rich: String, stats: Array, kind: String) -> PanelContainer:
	var pal: Dictionary = HadesEmblem.palette(kind)
	var accent: Color = pal["accent"]
	var accent_bright: Color = pal["bright"]
	var row_bg: Color = pal["bg"]
	var tag: String = str(pal["tag"])

	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(0, 146)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var style := UIStyle.create_flat_stylebox(row_bg, 6, 16, 12)
	style.border_color = Color(accent.r, accent.g, accent.b, 0.78)
	style.border_width_left = 4
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.45)
	style.shadow_size = 10
	style.shadow_offset = Vector2(0, 4)
	card.add_theme_stylebox_override("panel", style)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 20)
	card.add_child(hbox)

	var emblem := HadesEmblem.new()
	emblem.custom_minimum_size = Vector2(122, 122)
	emblem.size_flags_vertical = Control.SIZE_EXPAND_FILL
	emblem.accent = accent
	emblem.accent_bright = accent_bright
	hbox.add_child(emblem)

	var sigil_lbl := Label.new()
	sigil_lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
	sigil_lbl.text = sigil
	sigil_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sigil_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	sigil_lbl.add_theme_font_size_override("font_size", 42)
	sigil_lbl.add_theme_color_override("font_color", accent_bright)
	emblem.add_child(sigil_lbl)

	var text_col := VBoxContainer.new()
	text_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_col.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	text_col.add_theme_constant_override("separation", 4)
	hbox.add_child(text_col)

	var top_line := HBoxContainer.new()
	text_col.add_child(top_line)

	var title_lbl := Label.new()
	title_lbl.text = title.to_upper()
	title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_lbl.add_theme_font_override("font", UIStyle.FONT_INDER)
	title_lbl.add_theme_font_size_override("font_size", 24)
	title_lbl.add_theme_color_override("font_color", accent_bright)
	top_line.add_child(title_lbl)

	var tag_lbl := Label.new()
	tag_lbl.text = tag
	tag_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	tag_lbl.add_theme_font_override("font", _bold_font)
	tag_lbl.add_theme_font_size_override("font_size", 22)
	tag_lbl.add_theme_color_override("font_color", accent_bright)
	top_line.add_child(tag_lbl)

	var desc_rt := RichTextLabel.new()
	desc_rt.bbcode_enabled = true
	desc_rt.fit_content = true
	desc_rt.scroll_active = false
	desc_rt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_rt.add_theme_font_override("normal_font", UIStyle.FONT_INDER)
	desc_rt.add_theme_font_override("bold_font", _bold_font)
	desc_rt.add_theme_font_size_override("normal_font_size", 16)
	desc_rt.add_theme_font_size_override("bold_font_size", 16)
	desc_rt.add_theme_color_override("default_color", COL_CREAM_MUTED)
	desc_rt.text = desc_rich.replace("[b]", "[b][color=%s]" % COL_BOLD_CREAM).replace("[/b]", "[/color][/b]")
	text_col.add_child(desc_rt)

	var stats_box := VBoxContainer.new()
	stats_box.add_theme_constant_override("separation", 2)
	text_col.add_child(stats_box)
	for st in stats:
		var stat_dict: Dictionary = st
		var s_row := HBoxContainer.new()
		s_row.add_theme_constant_override("separation", 12)
		stats_box.add_child(s_row)

		var s_name := Label.new()
		s_name.text = "▸ " + str(stat_dict.get("label", ""))
		s_name.custom_minimum_size = Vector2(300, 0)
		s_name.add_theme_font_override("font", UIStyle.FONT_INDER)
		s_name.add_theme_font_size_override("font_size", 17)
		s_name.add_theme_color_override("font_color", COL_CREAM)
		s_row.add_child(s_name)

		var s_val := Label.new()
		s_val.text = str(stat_dict.get("value", ""))
		s_val.add_theme_font_override("font", _bold_font)
		s_val.add_theme_font_size_override("font_size", 18)
		var tone := str(stat_dict.get("tone", "pos"))
		var val_col := COL_STAT_POS if tone == "pos" else (COL_STAT_NEG if tone == "neg" else COL_GOLD_BRIGHT)
		s_val.add_theme_color_override("font_color", val_col)
		s_row.add_child(s_val)

	return card
