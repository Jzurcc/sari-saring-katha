class_name MayariCardHUD
extends CanvasLayer

## Compact top-left icon strip displaying rotated diamond emblems for all currently
## active Neighborhood Events, Today's Visitors, and Reyna Mayari Moon Cards, paired with a [C] keycap.
## Pressing C opens the full Calendar & Events overlay.

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
	## Compiled signature ambient effect from DiamondFXLibrary
	var fx_kind: String = "prism_pulse"
	var fx_phase: float = 0.0
	var anim_time: float = 0.0

	func _draw() -> void:
		var c := size * 0.5
		var r := minf(size.x, size.y) * 0.43
		var t := anim_time + fx_phase

		if fx_kind != "":
			DiamondFXLibrary.draw_pre_fx(self, fx_kind, c, r, accent, accent_bright, t)

		var outer := _diamond_pts(c, r)
		draw_colored_polygon(outer, Color(0.05, 0.04, 0.035, 0.94))
		draw_polyline(_closed_pts(outer), accent_bright, 2.6, true)
		var inner := _diamond_pts(c, r * 0.80)
		draw_colored_polygon(inner, fill_color)

		if fx_kind != "":
			DiamondFXLibrary.draw_inner_fx(self, fx_kind, c, r, accent, accent_bright, t)

		if radial_progress > 0.002:
			_draw_clockwise_sweep(c, r * 1.35, inner, clampf(radial_progress, 0.0, 1.0))
		draw_polyline(_closed_pts(inner), Color(accent.r, accent.g, accent.b, 0.68), 1.3, true)

		if fx_kind != "":
			DiamondFXLibrary.draw_post_fx(self, fx_kind, c, r, outer, accent, accent_bright, t)

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
var _toast_layer: CanvasLayer = null
var _toast_root: Control = null
var _all_diamonds: Array[MiniDiamondIcon] = []
var _blessing_diamonds: Array[MiniDiamondIcon] = []
var _last_blessing_progress: float = -1.0
var _anim_time: float = 0.0
var _morning_banner: VBoxContainer = null
var _morning_tween: Tween = null

func _ready() -> void:
	layer = 40
	_build_ui()
	EventBus.mayari_card_changed.connect(func(_id): _refresh_icons())
	EventBus.morning_mayari_cards_announced.connect(_on_morning_cards_announced)
	EventBus.radio_card_announced.connect(_on_radio_card_announced)
	EventBus.sto_nino_blessing_changed.connect(_refresh_icons)
	EventBus.restock_catalog_refresh.connect(_refresh_icons)
	EventBus.day_started.connect(func(_d): _refresh_icons())
	if is_instance_valid(StoreEventManager):
		StoreEventManager.events_changed.connect(func(_ev): _refresh_icons())
	_refresh_icons()

func _process(delta: float) -> void:
	if _all_diamonds.is_empty():
		return
	_anim_time += delta
	var b_prog := StoryManager.get_sto_nino_blessing_progress() if not _blessing_diamonds.is_empty() else 0.0
	for d in _all_diamonds:
		if is_instance_valid(d):
			d.anim_time = _anim_time
			if d in _blessing_diamonds:
				d.radial_progress = b_prog
			d.queue_redraw()
	if not _blessing_diamonds.is_empty():
		_last_blessing_progress = b_prog

func _get_fx_for_id(id_str: String) -> String:
	return DiamondFXLibrary.fx_kind_for_id(id_str)

func _build_ui() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)

	_row = HBoxContainer.new()
	_row.anchor_left = 0.0
	_row.anchor_right = 0.0
	_row.anchor_top = 0.5
	_row.anchor_bottom = 0.5
	_row.grow_horizontal = Control.GROW_DIRECTION_END
	_row.grow_vertical = Control.GROW_DIRECTION_BOTH
	_row.offset_left = 22.0
	_row.offset_top = 0.0
	_row.offset_bottom = 0.0
	_row.add_theme_constant_override("separation", 10)
	_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_row)

	# Dedicated layer-100 host for 1:1 top-center card toasts routed through TopBannerQueue
	_toast_layer = CanvasLayer.new()
	_toast_layer.layer = 100
	add_child(_toast_layer)
	_toast_root = Control.new()
	_toast_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_toast_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast_layer.add_child(_toast_root)

func _event_sigil(event_id: String) -> String:
	match event_id:
		"barangay_liga": return "◈"
		"brownout_notice": return "⚡"
		"payday_friday": return "₱"
		"summer_heat": return "☀"
		"typhoon_warning": return "〰"
		_: return "✦"

func _refresh_icons() -> void:
	_all_diamonds.clear()
	_blessing_diamonds.clear()
	_last_blessing_progress = -1.0
	for child in _row.get_children():
		_row.remove_child(child)
		child.queue_free()

	const MAX_PER_COL := 7
	var col_1 := VBoxContainer.new()
	col_1.alignment = BoxContainer.ALIGNMENT_CENTER
	col_1.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	col_1.add_theme_constant_override("separation", 10)
	col_1.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_row.add_child(col_1)

	var col_2: VBoxContainer = null
	var count := 0

	var get_target_col := func() -> VBoxContainer:
		if count < MAX_PER_COL:
			return col_1
		if col_2 == null:
			col_2 = VBoxContainer.new()
			col_2.alignment = BoxContainer.ALIGNMENT_CENTER
			col_2.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			col_2.add_theme_constant_override("separation", 10)
			col_2.mouse_filter = Control.MOUSE_FILTER_IGNORE
			_row.add_child(col_2)
		return col_2

	# 1. Active Neighborhood Events
	if is_instance_valid(StoreEventManager):
		for ev in StoreEventManager.get_active_events():
			var pe: Dictionary = HadesEmblem.palette("event")
			_add_diamond(_event_sigil(ev.event_id), pe["accent"], pe["bright"], 0.0, ev.get_icon_path(), get_target_col.call(), _get_fx_for_id(ev.event_id), DiamondFXLibrary.fx_phase_for_id(ev.event_id))
			count += 1

	# 1B. Radio-Revealed Today's Visitors
	if is_instance_valid(StoryManager):
		for vis in StoryManager.get_revealed_expected_regulars():
			var pv: Dictionary = HadesEmblem.palette("event")
			var vis_key := "visitor_" + vis.character_name
			_add_diamond("!", pv["accent"], pv["bright"], 0.0, "res://Assets/ui/icons/user-round-exclamation-point.png", get_target_col.call(), _get_fx_for_id(vis_key), DiamondFXLibrary.fx_phase_for_id(vis_key))
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
			_add_diamond(str(card.get("sigil", "☽")), acc, acc_b, 0.0, str(card.get("icon", "")), get_target_col.call(), _get_fx_for_id(mid), DiamondFXLibrary.fx_phase_for_id(mid))
			count += 1

	# 3. Active Sto. Niño Blessings (with clockwise radial sweep when timed)
	var b_progress := StoryManager.get_sto_nino_blessing_progress()
	var pb: Dictionary = HadesEmblem.palette("blessing")
	for b_id in StoryManager.active_blessing_cards:
		var b_card := MayariCardRegistry.get_card(b_id)
		if not b_card.is_empty():
			var bless_key := "blessing_" + b_id
			var d := _add_diamond(str(b_card.get("sigil", "✦")), pb["accent"], pb["bright"], b_progress, str(b_card.get("icon", "")), get_target_col.call(), _get_fx_for_id(bless_key), DiamondFXLibrary.fx_phase_for_id(bless_key))
			_blessing_diamonds.append(d)
			count += 1
	if not _blessing_diamonds.is_empty():
		_last_blessing_progress = b_progress

	if count == 0:
		_row.visible = false
		return

	# Compact [C] keycap pill right beside the active event icons
	var key_panel := PanelContainer.new()
	key_panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	key_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ks := UIStyle.create_flat_stylebox(Color(0.06, 0.052, 0.046, 0.88), 6, 10, 4)
	ks.border_color = Color(0.86, 0.66, 0.30, 0.82)
	ks.set_border_width_all(1)
	key_panel.add_theme_stylebox_override("panel", ks)
	var key_lbl := Label.new()
	key_lbl.text = "C"
	key_lbl.add_theme_font_override("font", UIStyle.FONT_FREDOKA_MED)
	key_lbl.add_theme_font_size_override("font_size", 16)
	key_lbl.add_theme_color_override("font_color", Color(1.0, 0.93, 0.78, 1.0))
	key_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	key_panel.add_child(key_lbl)
	_row.add_child(key_panel)

	_row.visible = true
	_row.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(_row, "modulate:a", 1.0, 0.25).set_trans(Tween.TRANS_SINE)


func _on_morning_cards_announced(card_ids: Array) -> void:
	if card_ids.is_empty():
		return
	var copy := card_ids.duplicate()
	TopBannerQueue.enqueue(_play_morning_cards_toast.bind(copy))


func _on_radio_card_announced(payload: Dictionary) -> void:
	if payload.is_empty():
		return
	TopBannerQueue.enqueue(_play_radio_card_toast.bind(payload))


func _play_morning_cards_toast(card_ids: Array) -> void:
	var cards: Array[PanelContainer] = []
	var last_accent := Color(1.0, 0.78, 0.16, 1.0)
	var vp_size := get_viewport().get_visible_rect().size
	var unified := TopBannerQueue.get_unified_card_size(vp_size)
	for cid in card_ids:
		var c_data := MayariCardRegistry.get_card(str(cid))
		if c_data.is_empty():
			continue
		var is_fav := str(c_data.get("kind", "")) == MayariCardRegistry.KIND_FAVOR
		var kind_str := "favor" if is_fav else "omen"
		last_accent = HadesEmblem.palette(kind_str)["accent"]
		cards.append(_build_unified_card_toast(
			str(c_data.get("title", "Moon Card")),
			str(c_data.get("sigil", "☽")),
			str(c_data.get("description_rich", c_data.get("description", ""))),
			c_data.get("stats", []),
			kind_str,
			str(c_data.get("icon", "")),
			str(cid),
			unified
		))
	if cards.is_empty():
		TopBannerQueue.complete()
		return
	_present_card_toast_stack(cards, last_accent, 3.6)


func _play_radio_card_toast(payload: Dictionary) -> void:
	var vp_size := get_viewport().get_visible_rect().size
	var unified := TopBannerQueue.get_unified_card_size(vp_size)
	var ptype := str(payload.get("type", ""))
	var cards: Array[PanelContainer] = []
	var accent: Color = HadesEmblem.palette("event")["accent"]

	if ptype == "event":
		var ev: StoreEventData = payload.get("event", null)
		if ev != null:
			var desc_rich := ev.description
			if ev.has_target_items():
				var target_names := PackedStringArray()
				for cat in ev.affected_categories:
					target_names.append(_category_display(cat))
				if target_names.is_empty():
					for it in ev.affected_items:
						if it:
							target_names.append(it.item_name)
				desc_rich = "%s Neighbors are actively seeking [b]%s[/b] today." % [ev.description, _format_natural_list(target_names)]
			cards.append(_build_unified_card_toast(
				ev.event_name,
				_event_sigil(ev.event_id),
				desc_rich,
				ev.build_stat_rows(),
				"event",
				ev.get_icon_path(),
				ev.event_id,
				unified
			))
	elif ptype == "visitor":
		var vis: CustomerData = payload.get("visitor", null)
		if vis != null:
			var desc_rich := "Papa Ulap spotted [b]%s[/b] heading toward your store today." % vis.character_name
			var stats: Array = [{"label": "Spawn Chance:", "value": "+120%", "tone": "pos"}]
			cards.append(_build_unified_card_toast(
				"Visitor: %s" % vis.character_name,
				"!",
				desc_rich,
				stats,
				"event",
				"res://Assets/ui/icons/user-round-exclamation-point.png",
				"visitor_" + vis.character_name,
				unified
			))

	if cards.is_empty():
		TopBannerQueue.complete()
		return
	_present_card_toast_stack(cards, accent, 3.6)


func _present_card_toast_stack(cards: Array[PanelContainer], bar_accent: Color, hold_sec: float) -> void:
	if not is_inside_tree() or not is_instance_valid(_toast_root):
		for c in cards:
			c.queue_free()
		TopBannerQueue.complete()
		return
	if _morning_tween and _morning_tween.is_valid():
		_morning_tween.kill()
	if is_instance_valid(_morning_banner):
		_morning_banner.queue_free()

	var vp_size := get_viewport().get_visible_rect().size
	var unified := TopBannerQueue.get_unified_card_size(vp_size)
	var half_w := unified.x * 0.5

	_morning_banner = VBoxContainer.new()
	_morning_banner.add_theme_constant_override("separation", 10)
	_morning_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_morning_banner.anchor_left = 0.5
	_morning_banner.anchor_right = 0.5
	_morning_banner.anchor_top = 0.0
	_morning_banner.anchor_bottom = 0.0
	_morning_banner.offset_left = -half_w
	_morning_banner.offset_right = half_w
	_morning_banner.offset_top = -220.0
	_morning_banner.modulate.a = 0.0
	_toast_root.add_child(_morning_banner)

	for c in cards:
		_morning_banner.add_child(c)

	var timer_bar := TopBannerQueue.attach_timer_bar(cards[cards.size() - 1], bar_accent)

	EventBus.request_sfx.emit("interact")
	await get_tree().process_frame
	if not is_instance_valid(_morning_banner):
		TopBannerQueue.complete()
		return

	var banner_h := maxf(_morning_banner.get_combined_minimum_size().y, unified.y)
	var target_y := TopBannerQueue.get_safe_top_y(vp_size.y)
	_morning_banner.offset_top = -banner_h - 24.0
	_morning_banner.offset_bottom = -24.0

	var pending := TopBannerQueue.get_pending_count()
	var eff_hold := 2.7 if pending >= 1 else hold_sec
	TopBannerQueue.start_timer_bar(self, timer_bar, eff_hold)

	_morning_tween = create_tween()
	_morning_tween.tween_property(_morning_banner, "offset_top", target_y, 0.40).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_morning_tween.parallel().tween_property(_morning_banner, "offset_bottom", target_y + banner_h, 0.40).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_morning_tween.parallel().tween_property(_morning_banner, "modulate:a", 1.0, 0.22).set_trans(Tween.TRANS_SINE)
	_morning_tween.tween_interval(eff_hold)
	_morning_tween.tween_property(_morning_banner, "offset_top", -banner_h - 36.0, 0.40).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	_morning_tween.parallel().tween_property(_morning_banner, "offset_bottom", -36.0, 0.40).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	_morning_tween.parallel().tween_property(_morning_banner, "modulate:a", 0.0, 0.30).set_trans(Tween.TRANS_SINE)
	_morning_tween.tween_callback(func():
		if is_instance_valid(_morning_banner):
			_morning_banner.queue_free()
			_morning_banner = null
		TopBannerQueue.complete()
	)


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


func _format_natural_list(names: PackedStringArray) -> String:
	var count := names.size()
	if count == 0:
		return "Featured Stock"
	if count == 1:
		return names[0]
	if count == 2:
		return "%s and %s" % [names[0], names[1]]
	var leading := PackedStringArray()
	for i in range(count - 1):
		leading.append(names[i])
	return "%s, and %s" % [", ".join(leading), names[count - 1]]


func _build_unified_card_toast(title: String, sigil: String, desc_rich: String, stats: Array, kind: String, icon_path: String, fx_id: String, unified_size: Vector2) -> PanelContainer:
	var pal: Dictionary = HadesEmblem.palette(kind)
	var accent: Color = pal["accent"]
	var accent_bright: Color = pal["bright"]
	var row_bg: Color = pal["bg"]
	var tag: String = str(pal["tag"]).capitalize()

	var card := PanelContainer.new()
	card.custom_minimum_size = unified_size
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := UIStyle.create_flat_stylebox(row_bg, 8, 16, 10)
	style.content_margin_right = 20
	style.border_color = Color(accent.r, accent.g, accent.b, 0.86)
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
	emblem.custom_minimum_size = Vector2(88, 88)
	emblem.size_flags_vertical = Control.SIZE_EXPAND_FILL
	emblem.accent = accent
	emblem.accent_bright = accent_bright
	emblem.set_fx_from_id(fx_id if fx_id != "" else title)
	emblem.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_child(emblem)

	HadesEmblem.populate_emblem_glyph(emblem, icon_path, sigil, accent_bright, 36.0, 36)

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
	title_lbl.text = title
	title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_lbl.add_theme_font_override("font", UIStyle.FONT_FREDOKA_SEMIBOLD)
	title_lbl.add_theme_font_size_override("font_size", 24)
	title_lbl.add_theme_color_override("font_color", accent_bright)
	title_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_line.add_child(title_lbl)

	var tag_lbl := Label.new()
	tag_lbl.text = tag
	tag_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	tag_lbl.add_theme_font_override("font", UIStyle.FONT_FREDOKA_SEMIBOLD)
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
	desc_rt.add_theme_font_override("normal_font", UIStyle.FONT_FREDOKA_REG)
	desc_rt.add_theme_font_override("bold_font", UIStyle.FONT_FREDOKA_SEMIBOLD)
	desc_rt.add_theme_font_size_override("normal_font_size", 17)
	desc_rt.add_theme_font_size_override("bold_font_size", 17)
	desc_rt.add_theme_color_override("default_color", Color(0.92, 0.86, 0.74, 0.90))
	desc_rt.text = desc_rich.replace("[b]", "[b][color=#FFF6E5]").replace("[/b]", "[/color][/b]")
	text_col.add_child(desc_rt)

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
			s_name.custom_minimum_size = Vector2(345, 0)
			s_name.add_theme_font_override("font", UIStyle.FONT_FREDOKA_REG)
			s_name.add_theme_font_size_override("font_size", 16)
			s_name.add_theme_color_override("font_color", Color(1.0, 0.92, 0.79, 1.0))
			s_name.mouse_filter = Control.MOUSE_FILTER_IGNORE
			s_row.add_child(s_name)

			var s_val := Label.new()
			s_val.text = str(stat_dict.get("value", ""))
			s_val.add_theme_font_override("font", UIStyle.FONT_FREDOKA_SEMIBOLD)
			s_val.add_theme_font_size_override("font_size", 17)
			var tone := str(stat_dict.get("tone", "pos"))
			var val_col := Color(0.56, 0.92, 0.52, 1.0) if tone == "pos" else (Color(0.96, 0.48, 0.45, 1.0) if tone == "neg" else Color(1.0, 0.875, 0.56, 1.0))
			s_val.add_theme_color_override("font_color", val_col)
			s_val.mouse_filter = Control.MOUSE_FILTER_IGNORE
			s_row.add_child(s_val)

	return card

func _add_diamond(sigil: String, accent: Color, accent_bright: Color, progress: float = 0.0, icon_path: String = "", target_parent: Control = null, fx_kind: String = "pulse_glow", fx_phase: float = 0.0) -> MiniDiamondIcon:
	var d := MiniDiamondIcon.new()
	d.custom_minimum_size = Vector2(74, 74)
	d.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	d.mouse_filter = Control.MOUSE_FILTER_IGNORE
	d.accent = accent
	d.accent_bright = accent_bright
	d.fill_color = Color(accent.r * 0.28, accent.g * 0.21, accent.b * 0.14, 0.95)
	d.radial_progress = progress
	d.fx_kind = fx_kind
	d.fx_phase = fx_phase
	(target_parent if target_parent != null else _row).add_child(d)
	_all_diamonds.append(d)

	HadesEmblem.populate_emblem_glyph(d, icon_path, sigil, accent_bright, 28.0, 30)
	return d
