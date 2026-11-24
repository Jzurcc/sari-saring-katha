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

var _row: HBoxContainer
var _blessing_diamonds: Array[MiniDiamondIcon] = []
var _last_blessing_progress: float = -1.0

func _ready() -> void:
	layer = 40
	_build_ui()
	EventBus.mayari_card_changed.connect(func(_id): _refresh_icons())
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
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	_row = HBoxContainer.new()
	_row.anchor_left = 0.0
	_row.anchor_top = 1.0
	_row.anchor_bottom = 1.0
	_row.offset_left = 24.0
	_row.offset_top = -86.0
	_row.offset_bottom = -22.0
	_row.add_theme_constant_override("separation", 10)
	_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_row)

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
	key_lbl.text = "K"
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
