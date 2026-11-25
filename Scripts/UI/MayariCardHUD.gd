class_name MayariCardHUD
extends CanvasLayer

## Compact top-left icon strip displaying rotated diamond emblems for all currently
## active Neighborhood Events and Reyna Mayari Moon Cards, paired with a [K] keycap.
## Pressing K opens the full Hades-styled Neighborhood Events overlay.

const HadesEmblem = preload("res://Scripts/UI/HadesDiamondEmblem.gd")
const COL_EVENT := Color(0.95, 0.65, 0.24, 1.0)
const COL_EVENT_BRIGHT := Color(1.0, 0.84, 0.48, 1.0)
const COL_FAVOR := Color(0.835, 0.624, 0.278, 1.0)
const COL_FAVOR_BRIGHT := Color(1.0, 0.875, 0.56, 1.0)
const COL_CHILL := Color(0.84, 0.37, 0.36, 1.0)
const COL_CHILL_BRIGHT := Color(0.96, 0.58, 0.54, 1.0)

class MiniDiamondIcon extends Control:
	var accent: Color = Color(0.835, 0.624, 0.278, 1.0)
	var accent_bright: Color = Color(1.0, 0.875, 0.56, 1.0)
	var fill_color: Color = Color(0.12, 0.09, 0.06, 0.95)
	## 0.0 = fresh (no overlay), 1.0 = fully elapsed (clockwise dark radial sweep)
	var radial_progress: float = 0.0

	func _draw() -> void:
		var c := size * 0.5
		var r := minf(size.x, size.y) * 0.45
		var outer := _diamond_pts(c, r)
		draw_colored_polygon(outer, Color(0.05, 0.04, 0.035, 0.94))
		draw_polyline(_closed_pts(outer), accent_bright, 2.5, true)
		var inner := _diamond_pts(c, r * 0.80)
		draw_colored_polygon(inner, fill_color)
		if radial_progress > 0.002:
			_draw_clockwise_sweep(c, r * 1.35, inner, clampf(radial_progress, 0.0, 1.0))
		draw_polyline(_closed_pts(inner), Color(accent.r, accent.g, accent.b, 0.65), 1.3, true)

	func _draw_clockwise_sweep(center: Vector2, sweep_r: float, clip_poly: PackedVector2Array, frac: float) -> void:
		if frac >= 0.998:
			draw_colored_polygon(clip_poly, Color(0.02, 0.015, 0.015, 0.60))
			return
		var start_a := -PI * 0.5
		var end_a := start_a + frac * TAU
		var steps := maxi(4, int(ceilf(frac * 28.0)))
		var wedge := PackedVector2Array()
		wedge.append(center)
		for i in range(steps + 1):
			var a := lerpf(start_a, end_a, float(i) / float(steps))
			wedge.append(center + Vector2(cos(a), sin(a)) * sweep_r)
		var clipped := Geometry2D.intersect_polygons(clip_poly, wedge)
		for poly in clipped:
			if poly.size() >= 3:
				draw_colored_polygon(poly, Color(0.02, 0.015, 0.015, 0.60))

	func _diamond_pts(center: Vector2, radius: float) -> PackedVector2Array:
		return PackedVector2Array([
			center + Vector2(0.0, -radius),
			center + Vector2(radius, 0.0),
			center + Vector2(0.0, radius),
			center + Vector2(-radius, 0.0),
		])

	func _closed_pts(pts: PackedVector2Array) -> PackedVector2Array:
		var closed := PackedVector2Array(pts)
		closed.append(pts[0])
		return closed

var _root: Control
var _row: HBoxContainer
var _blessing_diamonds: Array[MiniDiamondIcon] = []
var _last_blessing_progress: float = -1.0
var _bold_font: FontVariation
var _morning_banner: VBoxContainer = null
var _morning_tween: Tween = null

func _ready() -> void:
	layer = 40
	_bold_font = FontVariation.new()
	_bold_font.base_font = UIStyle.FONT_INDER
	_bold_font.variation_embolden = 0.65
	_build_ui()
	EventBus.mayari_card_changed.connect(func(_id): _refresh_icons())
	EventBus.morning_mayari_cards_announced.connect(_show_morning_card_banner)
	EventBus.sto_nino_blessing_changed.connect(_refresh_icons)
	EventBus.day_started.connect(func(_d): _refresh_icons())
	if is_instance_valid(StoreEventManager):
		StoreEventManager.events_changed.connect(func(_ev): _refresh_icons())
	_refresh_icons()

func _process(_delta: float) -> void:
	if _blessing_diamonds.is_empty():
		return
	var p := StoryManager.get_sto_nino_blessing_progress()
	if absf(p - _last_blessing_progress) >= 0.004:
		_last_blessing_progress = p
		for d in _blessing_diamonds:
			if is_instance_valid(d):
				d.radial_progress = p
				d.queue_redraw()

func _build_ui() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)

	_row = HBoxContainer.new()
	_row.anchor_left = 0.0
	_row.anchor_top = 1.0
	_row.anchor_bottom = 1.0
	_row.offset_left = 24.0
	_row.offset_top = -86.0
	_row.offset_bottom = -22.0
	_row.add_theme_constant_override("separation", 10)
	_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_row)

func _event_sigil(event_id: String) -> String:
	match event_id:
		"barangay_liga": return "◈"
		"brownout_notice": return "⚡"
		"payday_friday": return "₱"
		"summer_heat": return "☀"
		"typhoon_warning": return "〰"
		_: return "✦"

func _refresh_icons() -> void:
	_blessing_diamonds.clear()
	_last_blessing_progress = -1.0
	for child in _row.get_children():
		_row.remove_child(child)
		child.queue_free()

	var count := 0

	# 1. Active Neighborhood Events
	if is_instance_valid(StoreEventManager):
		for ev in StoreEventManager.get_active_events():
			var pe: Dictionary = HadesEmblem.palette("event")
			_add_diamond(_event_sigil(ev.event_id), pe["accent"], pe["bright"])
			count += 1

	# 2. Active Reyna Mayari Moon Card(s)
	var mayari_ids: Array[String] = StoryManager.active_mayari_cards
	if mayari_ids.is_empty() and StoryManager.active_mayari_card != "":
		mayari_ids = [StoryManager.active_mayari_card]
	for mid in mayari_ids:
		var card := MayariCardRegistry.get_card(mid)
		if not card.is_empty():
			var is_fav := MayariCardRegistry.is_favor(mid)
			var pc: Dictionary = HadesEmblem.palette("favor" if is_fav else "chill")
			var acc: Color = pc["accent"]
			var acc_b: Color = pc["bright"]
			_add_diamond(str(card.get("sigil", "☽")), acc, acc_b)
			count += 1

	# 3. Active Sto. Niño Blessings (with clockwise radial sweep when timed)
	var b_progress := StoryManager.get_sto_nino_blessing_progress()
	var pb: Dictionary = HadesEmblem.palette("blessing")
	for b_id in StoryManager.active_blessing_cards:
		var b_card := MayariCardRegistry.get_card(b_id)
		if not b_card.is_empty():
			var d := _add_diamond(str(b_card.get("sigil", "✦")), pb["accent"], pb["bright"], b_progress)
			_blessing_diamonds.append(d)
			count += 1
	if not _blessing_diamonds.is_empty():
		_last_blessing_progress = b_progress

	if count == 0:
		_row.visible = false
		return

	# Compact [K] keycap pill right beside the active event icons
	var key_panel := PanelContainer.new()
	key_panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	key_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ks := UIStyle.create_flat_stylebox(Color(0.06, 0.052, 0.046, 0.86), 6, 10, 4)
	ks.border_color = Color(0.86, 0.66, 0.30, 0.78)
	ks.set_border_width_all(1)
	key_panel.add_theme_stylebox_override("panel", ks)
	var key_lbl := Label.new()
	key_lbl.text = "C"
	key_lbl.add_theme_font_override("font", UIStyle.FONT_INDER)
	key_lbl.add_theme_font_size_override("font_size", 16)
	key_lbl.add_theme_color_override("font_color", Color(1.0, 0.93, 0.78, 1.0))
	key_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	key_panel.add_child(key_lbl)
	_row.add_child(key_panel)

	_row.visible = true
	_row.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(_row, "modulate:a", 1.0, 0.25).set_trans(Tween.TRANS_SINE)


func _show_morning_card_banner(card_ids: Array) -> void:
	if not is_instance_valid(_root) or card_ids.is_empty():
		return
	if _morning_tween and _morning_tween.is_valid():
		_morning_tween.kill()
	if is_instance_valid(_morning_banner):
		_morning_banner.queue_free()

	_morning_banner = VBoxContainer.new()
	_morning_banner.add_theme_constant_override("separation", 10)
	_morning_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_morning_banner.anchor_left = 0.5
	_morning_banner.anchor_right = 0.5
	_morning_banner.anchor_top = 0.0
	_morning_banner.anchor_bottom = 0.0
	_morning_banner.offset_left = -350.0
	_morning_banner.offset_right = 350.0
	_morning_banner.offset_top = -180.0
	_morning_banner.modulate.a = 0.0
	_root.add_child(_morning_banner)

	var built_count := 0
	for cid in card_ids:
		var c_data := MayariCardRegistry.get_card(str(cid))
		if c_data.is_empty():
			continue
		_morning_banner.add_child(_build_moon_card_toast(c_data))
		built_count += 1

	if built_count == 0:
		_morning_banner.queue_free()
		_morning_banner = null
		return

	EventBus.request_sfx.emit("interact")
	await get_tree().process_frame
	if not is_instance_valid(_morning_banner):
		return

	var banner_h := maxf(_morning_banner.get_combined_minimum_size().y, 130.0)
	_morning_banner.offset_top = -banner_h - 24.0
	_morning_banner.offset_bottom = -24.0

	_morning_tween = create_tween()
	# Slide down cleanly into view at top-center
	_morning_tween.tween_property(_morning_banner, "offset_top", 26.0, 0.42).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_morning_tween.parallel().tween_property(_morning_banner, "offset_bottom", 26.0 + banner_h, 0.42).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_morning_tween.parallel().tween_property(_morning_banner, "modulate:a", 1.0, 0.24).set_trans(Tween.TRANS_SINE)
	# Hold so the player reads the Favor/Omen card
	_morning_tween.tween_interval(3.6)
	# Animate smoothly back UP off the top edge
	_morning_tween.tween_property(_morning_banner, "offset_top", -banner_h - 36.0, 0.44).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	_morning_tween.parallel().tween_property(_morning_banner, "offset_bottom", -36.0, 0.44).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	_morning_tween.parallel().tween_property(_morning_banner, "modulate:a", 0.0, 0.34).set_trans(Tween.TRANS_SINE)
	_morning_tween.tween_callback(func():
		if is_instance_valid(_morning_banner):
			_morning_banner.queue_free()
			_morning_banner = null
	)


func _build_moon_card_toast(c_data: Dictionary) -> PanelContainer:
	var is_fav := str(c_data.get("kind", "")) == MayariCardRegistry.KIND_FAVOR
	var pal: Dictionary = HadesEmblem.palette("favor" if is_fav else "omen")
	var accent: Color = pal["accent"]
	var accent_bright: Color = pal["bright"]
	var row_bg: Color = pal["bg"]
	var tag: String = str(pal["tag"])

	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(700, 128)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := UIStyle.create_flat_stylebox(row_bg, 8, 16, 10)
	style.content_margin_right = 20
	style.border_color = Color(accent.r, accent.g, accent.b, 0.85)
	style.border_width_left = 4
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.65)
	style.shadow_size = 18
	style.shadow_offset = Vector2(0, 6)
	card.add_theme_stylebox_override("panel", style)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 52)
	hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(hbox)

	var emblem := HadesEmblem.new()
	emblem.custom_minimum_size = Vector2(84, 84)
	emblem.size_flags_vertical = Control.SIZE_EXPAND_FILL
	emblem.accent = accent
	emblem.accent_bright = accent_bright
	emblem.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_child(emblem)

	var sigil_lbl := Label.new()
	sigil_lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
	sigil_lbl.text = str(c_data.get("sigil", "☽"))
	sigil_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sigil_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	sigil_lbl.add_theme_font_size_override("font_size", 34)
	sigil_lbl.add_theme_color_override("font_color", accent_bright)
	sigil_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	emblem.add_child(sigil_lbl)

	var text_col := VBoxContainer.new()
	text_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_col.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	text_col.add_theme_constant_override("separation", 3)
	text_col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_child(text_col)

	var top_line := HBoxContainer.new()
	top_line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text_col.add_child(top_line)

	var title_lbl := Label.new()
	title_lbl.text = str(c_data.get("title", "Moon Card"))
	title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_lbl.add_theme_font_override("font", _bold_font)
	title_lbl.add_theme_font_size_override("font_size", 23)
	title_lbl.add_theme_color_override("font_color", accent_bright)
	title_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_line.add_child(title_lbl)

	var tag_lbl := Label.new()
	tag_lbl.text = tag
	tag_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	tag_lbl.add_theme_font_override("font", _bold_font)
	tag_lbl.add_theme_font_size_override("font_size", 18)
	tag_lbl.add_theme_color_override("font_color", accent_bright)
	tag_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_line.add_child(tag_lbl)

	var desc_rt := RichTextLabel.new()
	desc_rt.bbcode_enabled = true
	desc_rt.fit_content = true
	desc_rt.scroll_active = false
	desc_rt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_rt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	desc_rt.add_theme_font_override("normal_font", UIStyle.FONT_INDER)
	desc_rt.add_theme_font_override("bold_font", _bold_font)
	desc_rt.add_theme_font_size_override("normal_font_size", 16)
	desc_rt.add_theme_font_size_override("bold_font_size", 16)
	desc_rt.add_theme_color_override("default_color", Color(0.92, 0.86, 0.74, 0.90))
	var raw_desc := str(c_data.get("description_rich", c_data.get("description", "")))
	desc_rt.text = raw_desc.replace("[b]", "[b][color=#FFF6E5]").replace("[/b]", "[/color][/b]")
	text_col.add_child(desc_rt)

	var stats: Array = c_data.get("stats", [])
	if not stats.is_empty():
		var stats_box := VBoxContainer.new()
		stats_box.add_theme_constant_override("separation", 2)
		stats_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		text_col.add_child(stats_box)
		for st in stats:
			var stat_dict: Dictionary = st
			var s_row := HBoxContainer.new()
			s_row.add_theme_constant_override("separation", 12)
			s_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
			stats_box.add_child(s_row)

			var s_name := Label.new()
			s_name.text = "▸ " + str(stat_dict.get("label", ""))
			s_name.custom_minimum_size = Vector2(280, 0)
			s_name.add_theme_font_override("font", UIStyle.FONT_INDER)
			s_name.add_theme_font_size_override("font_size", 15)
			s_name.add_theme_color_override("font_color", Color(1.0, 0.92, 0.79, 1.0))
			s_name.mouse_filter = Control.MOUSE_FILTER_IGNORE
			s_row.add_child(s_name)

			var s_val := Label.new()
			s_val.text = str(stat_dict.get("value", ""))
			s_val.add_theme_font_override("font", _bold_font)
			s_val.add_theme_font_size_override("font_size", 16)
			var tone := str(stat_dict.get("tone", "pos"))
			var val_col := Color(0.56, 0.92, 0.52, 1.0) if tone == "pos" else (Color(0.96, 0.48, 0.45, 1.0) if tone == "neg" else Color(1.0, 0.875, 0.56, 1.0))
			s_val.add_theme_color_override("font_color", val_col)
			s_val.mouse_filter = Control.MOUSE_FILTER_IGNORE
			s_row.add_child(s_val)

	return card

func _add_diamond(sigil: String, accent: Color, accent_bright: Color, progress: float = 0.0) -> MiniDiamondIcon:
	var d := MiniDiamondIcon.new()
	d.custom_minimum_size = Vector2(62, 62)
	d.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	d.mouse_filter = Control.MOUSE_FILTER_IGNORE
	d.accent = accent
	d.accent_bright = accent_bright
	d.fill_color = Color(accent.r * 0.28, accent.g * 0.21, accent.b * 0.14, 0.95)
	d.radial_progress = progress
	_row.add_child(d)

	var lbl := Label.new()
	lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
	lbl.text = sigil
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 26)
	lbl.add_theme_color_override("font_color", accent_bright)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	d.add_child(lbl)
	return d
