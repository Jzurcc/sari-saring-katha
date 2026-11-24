extends CanvasLayer

## Hades-inspired Upgrade Available fanfare banner.
## Replaces the plain rectangle with a warm espresso & antique gold banner featuring
## a smooth anti-aliased HadesDiamondEmblem, crisp typography, and staggered item tiles.

const HadesEmblem = preload("res://Scripts/UI/HadesDiamondEmblem.gd")

const COL_BG := Color(0.062, 0.054, 0.046, 0.96)
const COL_GOLD := Color(1.0, 0.78, 0.16, 1.0)
const COL_GOLD_BRIGHT := Color(1.0, 0.90, 0.48, 1.0)
const COL_CREAM := Color(1.0, 0.94, 0.82, 1.0)
const COL_CREAM_MUTED := Color(0.84, 0.78, 0.68, 0.90)
const COL_OUTLINE := Color(0.06, 0.045, 0.03, 0.95)

@onready var control: Control = $Control

var sfx_player: AudioStreamPlayer
var stream_notification = preload("res://Audio/SFX/ui_sfx_7.mp3")

var _bold_font: FontVariation
var _banner: PanelContainer
var _eyebrow_lbl: Label
var _title_lbl: Label
var _sub_lbl: Label
var _price_lbl: Label
var _items_row: HBoxContainer
var _anim_tween: Tween = null
var _session_id: int = 0

func _ready() -> void:
	layer = 100
	_bold_font = FontVariation.new()
	_bold_font.base_font = UIStyle.FONT_INDER
	_bold_font.variation_embolden = 0.65

	# Hide legacy scene children so the Hades banner owns the layout cleanly
	for child in control.get_children():
		if child is CanvasItem:
			(child as CanvasItem).visible = false
	control.visible = false
	control.mouse_filter = Control.MOUSE_FILTER_IGNORE

	_build_banner()

	EventBus.upgrade_available.connect(_on_upgrade_available)
	sfx_player = AudioStreamPlayer.new()
	add_child(sfx_player)
	sfx_player.stream = stream_notification

func _build_banner() -> void:
	_banner = PanelContainer.new()
	_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_banner.custom_minimum_size = Vector2(560, 0)
	var style := UIStyle.create_flat_stylebox(COL_BG, 8, 18, 14)
	style.border_color = COL_GOLD
	style.border_width_left = 4
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.62)
	style.shadow_size = 18
	style.shadow_offset = Vector2(0, 6)
	_banner.add_theme_stylebox_override("panel", style)
	control.add_child(_banner)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 18)
	hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_banner.add_child(hbox)

	# Left Hades diamond emblem with smooth wide gold triangle
	var emblem := HadesEmblem.new()
	emblem.custom_minimum_size = Vector2(88, 88)
	emblem.size_flags_vertical = Control.SIZE_EXPAND_FILL
	emblem.accent = COL_GOLD
	emblem.accent_bright = COL_GOLD_BRIGHT
	emblem.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_child(emblem)

	var sigil := Label.new()
	sigil.set_anchors_preset(Control.PRESET_FULL_RECT)
	sigil.text = "★"
	sigil.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sigil.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	sigil.add_theme_font_size_override("font_size", 34)
	sigil.add_theme_color_override("font_color", COL_GOLD_BRIGHT)
	sigil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	emblem.add_child(sigil)

	# Right content column
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	col.add_theme_constant_override("separation", 6)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_child(col)

	var top_row := HBoxContainer.new()
	top_row.add_theme_constant_override("separation", 10)
	top_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(top_row)

	var title_col := VBoxContainer.new()
	title_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_col.add_theme_constant_override("separation", 1)
	title_col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_row.add_child(title_col)

	_eyebrow_lbl = Label.new()
	_eyebrow_lbl.text = "N E W   U N L O C K"
	_eyebrow_lbl.add_theme_font_override("font", UIStyle.FONT_INDER)
	_eyebrow_lbl.add_theme_font_size_override("font_size", 12)
	_eyebrow_lbl.add_theme_color_override("font_color", COL_GOLD)
	_eyebrow_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_col.add_child(_eyebrow_lbl)

	_title_lbl = Label.new()
	_title_lbl.text = "UPGRADE AVAILABLE"
	_title_lbl.add_theme_font_override("font", _bold_font)
	_title_lbl.add_theme_font_size_override("font_size", 22)
	_title_lbl.add_theme_color_override("font_color", COL_CREAM)
	_title_lbl.add_theme_color_override("font_outline_color", COL_OUTLINE)
	_title_lbl.add_theme_constant_override("outline_size", 3)
	_title_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_col.add_child(_title_lbl)

	# Right-aligned gold price pill
	var price_pill := PanelContainer.new()
	price_pill.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	price_pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ps := UIStyle.create_flat_stylebox(Color(0.24, 0.18, 0.08, 0.92), 6, 10, 4)
	ps.border_color = COL_GOLD_BRIGHT
	ps.set_border_width_all(1)
	price_pill.add_theme_stylebox_override("panel", ps)
	top_row.add_child(price_pill)

	_price_lbl = Label.new()
	_price_lbl.text = "₱80"
	_price_lbl.add_theme_font_override("font", _bold_font)
	_price_lbl.add_theme_font_size_override("font_size", 18)
	_price_lbl.add_theme_color_override("font_color", COL_GOLD_BRIGHT)
	_price_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	price_pill.add_child(_price_lbl)

	_sub_lbl = Label.new()
	_sub_lbl.text = "Uncle Mario is calling on the phone!"
	_sub_lbl.add_theme_font_override("font", UIStyle.FONT_INDER)
	_sub_lbl.add_theme_font_size_override("font_size", 14)
	_sub_lbl.add_theme_color_override("font_color", COL_CREAM_MUTED)
	_sub_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(_sub_lbl)

	_items_row = HBoxContainer.new()
	_items_row.add_theme_constant_override("separation", 8)
	_items_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(_items_row)

func _on_upgrade_available(new_tier: int, cost: float, items: Array[ItemData]) -> void:
	_session_id += 1
	var my_session := _session_id

	_eyebrow_lbl.text = "T I E R   %d   U N L O C K E D" % new_tier
	_title_lbl.text = "NEW UPGRADE AVAILABLE"
	_price_lbl.text = "₱%d" % int(roundf(cost))
	_sub_lbl.text = "Answer the phone to call Uncle Mario!"

	for child in _items_row.get_children():
		_items_row.remove_child(child)
		child.queue_free()

	var tiles: Array[PanelContainer] = []
	for item in items:
		if not item or not item.can_be_sold:
			continue
		var tile := PanelContainer.new()
		tile.custom_minimum_size = Vector2(54, 54)
		tile.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var ts := UIStyle.create_flat_stylebox(Color(0.12, 0.10, 0.08, 0.95), 6, 5, 5)
		ts.border_color = Color(COL_GOLD.r, COL_GOLD.g, COL_GOLD.b, 0.65)
		ts.set_border_width_all(1)
		tile.add_theme_stylebox_override("panel", ts)

		var tex := TextureRect.new()
		tex.texture = item.texture
		tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tex.custom_minimum_size = Vector2(42, 42)
		tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tile.add_child(tex)

		tile.scale = Vector2(0.7, 0.7)
		tile.modulate.a = 0.0
		_items_row.add_child(tile)
		tiles.append(tile)

	_items_row.visible = not tiles.is_empty()

	sfx_player.play()
	var cam = get_viewport().get_camera_3d()
	if cam:
		var spawn_pos = cam.global_position + (-cam.global_transform.basis.z * 2.5)
		VisualEffectManager.spawn_rank_up_fanfare(spawn_pos)

	control.visible = true
	_banner.modulate.a = 0.0
	await get_tree().process_frame
	await get_tree().process_frame
	if not is_inside_tree() or my_session != _session_id:
		return

	var vp_width := get_viewport().get_visible_rect().size.x
	_banner.position = Vector2((vp_width - _banner.size.x) * 0.5, -_banner.size.y - 12.0)
	_banner.pivot_offset = _banner.size * 0.5
	_banner.scale = Vector2(0.92, 0.92)

	if _anim_tween and _anim_tween.is_valid():
		_anim_tween.kill()
	_anim_tween = create_tween().set_parallel(true)
	_anim_tween.tween_property(_banner, "modulate:a", 1.0, 0.24).set_trans(Tween.TRANS_SINE)
	_anim_tween.tween_property(_banner, "scale", Vector2.ONE, 0.34).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_anim_tween.tween_property(_banner, "position:y", 24.0, 0.36).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	# Staggered item tile pops
	for i in range(tiles.size()):
		var t := tiles[i]
		t.pivot_offset = t.size * 0.5
		var t_tw := create_tween()
		t_tw.tween_interval(0.16 + i * 0.06)
		t_tw.tween_property(t, "modulate:a", 1.0, 0.18).set_trans(Tween.TRANS_SINE)
		t_tw.parallel().tween_property(t, "scale", Vector2.ONE, 0.24).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	await get_tree().create_timer(3.2).timeout
	if is_inside_tree() and my_session == _session_id:
		_on_close_pressed()

func _on_close_pressed() -> void:
	if not control.visible:
		return
	if _anim_tween and _anim_tween.is_valid():
		_anim_tween.kill()
	_anim_tween = create_tween().set_parallel(true)
	_anim_tween.tween_property(_banner, "modulate:a", 0.0, 0.24).set_trans(Tween.TRANS_SINE)
	_anim_tween.tween_property(_banner, "position:y", -_banner.size.y - 16.0, 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	await _anim_tween.finished
	if is_inside_tree():
		control.visible = false
