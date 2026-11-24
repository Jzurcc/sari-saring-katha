extends CanvasLayer

## Sleek Level-Up & Next-Tier Unlock fanfare banner (no diamonds or triangles!).
## Displays the unlocked Player Level / Tier, Uncle Mario upgrade cost with peso icon,
## and staggered preview tiles of every newly unlocked product for that tier.

const PESO_ICON: Texture2D = preload("res://Assets/ui/peso_icon.png")

const COL_BG := Color(0.068, 0.058, 0.050, 0.94)
const COL_GOLD := Color(0.90, 0.74, 0.38, 1.0)
const COL_GOLD_BRIGHT := Color(1.0, 0.91, 0.64, 1.0)
const COL_CREAM := Color(1.0, 0.95, 0.84, 1.0)
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
	_banner.custom_minimum_size = Vector2(460, 0)
	var style := UIStyle.create_flat_stylebox(COL_BG, 14, 24, 16)
	style.border_color = Color(COL_GOLD.r, COL_GOLD.g, COL_GOLD.b, 0.78)
	style.set_border_width_all(2)
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.60)
	style.shadow_size = 20
	style.shadow_offset = Vector2(0, 8)
	_banner.add_theme_stylebox_override("panel", style)
	control.add_child(_banner)

	var col := VBoxContainer.new()
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 10)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_banner.add_child(col)

	# Centered header row
	var hdr := VBoxContainer.new()
	hdr.alignment = BoxContainer.ALIGNMENT_CENTER
	hdr.add_theme_constant_override("separation", 2)
	hdr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(hdr)

	_eyebrow_lbl = Label.new()
	_eyebrow_lbl.text = "★  PLAYER LEVEL 2  ·  TIER 2 UNLOCKED  ★"
	_eyebrow_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_eyebrow_lbl.add_theme_font_override("font", _bold_font)
	_eyebrow_lbl.add_theme_font_size_override("font_size", 12)
	_eyebrow_lbl.add_theme_color_override("font_color", COL_GOLD)
	_eyebrow_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hdr.add_child(_eyebrow_lbl)

	_title_lbl = Label.new()
	_title_lbl.text = "NEW UPGRADE AVAILABLE"
	_title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_lbl.add_theme_font_override("font", _bold_font)
	_title_lbl.add_theme_font_size_override("font_size", 21)
	_title_lbl.add_theme_color_override("font_color", COL_CREAM)
	_title_lbl.add_theme_color_override("font_outline_color", COL_OUTLINE)
	_title_lbl.add_theme_constant_override("outline_size", 3)
	_title_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hdr.add_child(_title_lbl)

	# Subtitle + Peso cost pill inline
	var sub_row := HBoxContainer.new()
	sub_row.alignment = BoxContainer.ALIGNMENT_CENTER
	sub_row.add_theme_constant_override("separation", 10)
	sub_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hdr.add_child(sub_row)

	_sub_lbl = Label.new()
	_sub_lbl.text = "Call Uncle Mario on the phone!"
	_sub_lbl.add_theme_font_override("font", UIStyle.FONT_INDER)
	_sub_lbl.add_theme_font_size_override("font_size", 13)
	_sub_lbl.add_theme_color_override("font_color", COL_CREAM_MUTED)
	_sub_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sub_row.add_child(_sub_lbl)

	var price_pill := PanelContainer.new()
	price_pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ps := UIStyle.create_flat_stylebox(Color(0.22, 0.17, 0.09, 0.92), 8, 8, 2)
	ps.border_color = Color(COL_GOLD_BRIGHT.r, COL_GOLD_BRIGHT.g, COL_GOLD_BRIGHT.b, 0.72)
	ps.set_border_width_all(1)
	price_pill.add_theme_stylebox_override("panel", ps)
	sub_row.add_child(price_pill)

	var p_row := HBoxContainer.new()
	p_row.alignment = BoxContainer.ALIGNMENT_CENTER
	p_row.add_theme_constant_override("separation", 4)
	p_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	price_pill.add_child(p_row)

	var coin := TextureRect.new()
	coin.texture = PESO_ICON
	coin.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	coin.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	coin.custom_minimum_size = Vector2(14, 14)
	coin.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	coin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p_row.add_child(coin)

	_price_lbl = Label.new()
	_price_lbl.text = "80"
	_price_lbl.add_theme_font_override("font", _bold_font)
	_price_lbl.add_theme_font_size_override("font_size", 14)
	_price_lbl.add_theme_color_override("font_color", COL_GOLD_BRIGHT)
	_price_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p_row.add_child(_price_lbl)

	# Centered row of next-tier item preview tiles
	_items_row = HBoxContainer.new()
	_items_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_items_row.add_theme_constant_override("separation", 10)
	_items_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(_items_row)

func _on_upgrade_available(new_tier: int, cost: float, items: Array[ItemData]) -> void:
	_session_id += 1
	var my_session := _session_id

	_eyebrow_lbl.text = "★  PLAYER LEVEL %d  ·  TIER %d UNLOCKED  ★" % [StoryManager.player_level, new_tier]
	_title_lbl.text = "NEW PRODUCTS & UPGRADES"
	_price_lbl.text = "%d" % int(roundf(cost))
	_sub_lbl.text = "Call Uncle Mario to stock Tier %d!" % new_tier

	for child in _items_row.get_children():
		_items_row.remove_child(child)
		child.queue_free()

	var tiles: Array[PanelContainer] = []
	for item in items:
		if not item or not item.can_be_sold:
			continue
		if "/sachetcontainers/" in item.resource_path:
			continue
		var tile := PanelContainer.new()
		tile.custom_minimum_size = Vector2(74, 78)
		tile.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var ts := UIStyle.create_flat_stylebox(Color(0.11, 0.095, 0.078, 0.94), 8, 6, 6)
		ts.border_color = Color(COL_GOLD.r, COL_GOLD.g, COL_GOLD.b, 0.58)
		ts.set_border_width_all(1)
		tile.add_theme_stylebox_override("panel", ts)

		var tv := VBoxContainer.new()
		tv.alignment = BoxContainer.ALIGNMENT_CENTER
		tv.add_theme_constant_override("separation", 3)
		tv.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tile.add_child(tv)

		var tex := TextureRect.new()
		tex.texture = item.texture
		tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tex.custom_minimum_size = Vector2(44, 44)
		tex.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tv.add_child(tex)

		var nm := Label.new()
		nm.text = item.item_name
		nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		nm.clip_text = true
		nm.custom_minimum_size = Vector2(62, 0)
		nm.add_theme_font_override("font", UIStyle.FONT_INDER)
		nm.add_theme_font_size_override("font_size", 10)
		nm.add_theme_color_override("font_color", COL_CREAM_MUTED)
		nm.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tv.add_child(nm)

		tile.scale = Vector2(0.76, 0.76)
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
	_banner.size = Vector2.ZERO
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

	for i in range(tiles.size()):
		var t := tiles[i]
		t.pivot_offset = t.size * 0.5
		var t_tw := create_tween()
		t_tw.tween_interval(0.14 + i * 0.06)
		t_tw.tween_property(t, "modulate:a", 1.0, 0.18).set_trans(Tween.TRANS_SINE)
		t_tw.parallel().tween_property(t, "scale", Vector2.ONE, 0.24).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	await get_tree().create_timer(3.6).timeout
	if is_inside_tree() and my_session == _session_id:
		_on_close_pressed()

func _on_close_pressed() -> void:
	if not control.visible:
		return
	if _anim_tween and _anim_tween.is_valid():
		_anim_tween.kill()
	_anim_tween = create_tween().set_parallel(true)
	_anim_tween.tween_property(_banner, "modulate:a", 0.0, 0.24).set_trans(Tween.TRANS_SINE)
	_anim_tween.tween_property(_banner, "position:y", -_banner.size.y - 16.0, 0.30).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	await _anim_tween.finished
	if is_inside_tree():
		control.visible = false
