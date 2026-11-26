extends CanvasLayer

## Clean, celebratory Level-Up banner ("You Leveled Up!").
## Displays the level-up prize money pill beside the title and gently bobbing
## previews of newly unlocked items below, with a longer hold and slow graceful exit.

const PESO_ICON: Texture2D = preload("res://Assets/ui/peso_icon.png")

const COL_BG := Color(0.068, 0.058, 0.050, 0.94)
const COL_GOLD := Color(0.90, 0.74, 0.38, 1.0)
const COL_GOLD_BRIGHT := Color(1.0, 0.91, 0.64, 1.0)
const COL_PRIZE_GREEN := Color(0.62, 0.96, 0.66, 1.0)
const COL_CREAM := Color(1.0, 0.95, 0.84, 1.0)
const COL_CREAM_MUTED := Color(0.86, 0.80, 0.70, 0.92)
const COL_OUTLINE := Color(0.06, 0.045, 0.03, 0.95)

@onready var control: Control = $Control

var sfx_player: AudioStreamPlayer
var stream_notification = preload("res://Audio/SFX/ui_sfx_7.mp3")

var _bold_font: FontVariation
var _banner: PanelContainer
var _title_lbl: Label
var _prize_pill: PanelContainer
var _prize_lbl: Label
var _items_row: HBoxContainer
var _anim_tween: Tween = null
var _bob_tweens: Array[Tween] = []
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
	_banner.custom_minimum_size = Vector2(420, 0)
	var style := UIStyle.create_flat_stylebox(COL_BG, 14, 26, 18)
	style.border_color = Color(COL_GOLD.r, COL_GOLD.g, COL_GOLD.b, 0.82)
	style.set_border_width_all(2)
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.60)
	style.shadow_size = 20
	style.shadow_offset = Vector2(0, 8)
	_banner.add_theme_stylebox_override("panel", style)
	control.add_child(_banner)

	var col := VBoxContainer.new()
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 12)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_banner.add_child(col)

	# Clean single-line header: "You Leveled Up!" + Prize Money pill on the side
	var top_row := HBoxContainer.new()
	top_row.alignment = BoxContainer.ALIGNMENT_CENTER
	top_row.add_theme_constant_override("separation", 14)
	top_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(top_row)

	_title_lbl = Label.new()
	_title_lbl.text = "You Leveled Up!"
	_title_lbl.add_theme_font_override("font", _bold_font)
	_title_lbl.add_theme_font_size_override("font_size", 28)
	_title_lbl.add_theme_color_override("font_color", COL_GOLD_BRIGHT)
	_title_lbl.add_theme_color_override("font_outline_color", COL_OUTLINE)
	_title_lbl.add_theme_constant_override("outline_size", 4)
	_title_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_row.add_child(_title_lbl)

	_prize_pill = PanelContainer.new()
	_prize_pill.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_prize_pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ps := UIStyle.create_flat_stylebox(Color(0.12, 0.22, 0.14, 0.94), 10, 12, 4)
	ps.border_color = Color(COL_PRIZE_GREEN.r, COL_PRIZE_GREEN.g, COL_PRIZE_GREEN.b, 0.78)
	ps.set_border_width_all(1)
	_prize_pill.add_theme_stylebox_override("panel", ps)
	top_row.add_child(_prize_pill)

	var p_row := HBoxContainer.new()
	p_row.alignment = BoxContainer.ALIGNMENT_CENTER
	p_row.add_theme_constant_override("separation", 5)
	p_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_prize_pill.add_child(p_row)

	var coin := TextureRect.new()
	coin.texture = PESO_ICON
	coin.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	coin.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	coin.custom_minimum_size = Vector2(18, 18)
	coin.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	coin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p_row.add_child(coin)

	_prize_lbl = Label.new()
	_prize_lbl.text = "+₱50"
	_prize_lbl.add_theme_font_override("font", _bold_font)
	_prize_lbl.add_theme_font_size_override("font_size", 18)
	_prize_lbl.add_theme_color_override("font_color", COL_PRIZE_GREEN)
	_prize_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p_row.add_child(_prize_lbl)

	# Centered row of gently bobbing unlocked item previews
	_items_row = HBoxContainer.new()
	_items_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_items_row.add_theme_constant_override("separation", 14)
	_items_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(_items_row)


func _kill_bob_tweens() -> void:
	for tw in _bob_tweens:
		if tw and tw.is_valid():
			tw.kill()
	_bob_tweens.clear()


func _on_upgrade_available(_new_tier: int, _cost: float, items: Array[ItemData]) -> void:
	_session_id += 1
	var my_session := _session_id
	_kill_bob_tweens()

	_title_lbl.text = "You Leveled Up!"
	var bonus := StoryManager.last_level_up_bonus
	if bonus <= 0.0:
		bonus = StoryManager.get_level_up_money_reward(StoryManager.player_level)
	_prize_lbl.text = "+₱%d" % int(roundf(bonus))
	_prize_pill.visible = bonus > 0.0

	for child in _items_row.get_children():
		_items_row.remove_child(child)
		child.queue_free()

	var item_icons: Array[TextureRect] = []
	var item_holders: Array[VBoxContainer] = []
	for item in items:
		if not item or not item.can_be_sold:
			continue
		if "/sachetcontainers/" in item.resource_path:
			continue

		var holder := VBoxContainer.new()
		holder.alignment = BoxContainer.ALIGNMENT_CENTER
		holder.custom_minimum_size = Vector2(78, 86)
		holder.add_theme_constant_override("separation", 4)
		holder.mouse_filter = Control.MOUSE_FILTER_IGNORE

		# Fixed-height slot so the TextureRect can bob smoothly inside it
		var icon_slot := Control.new()
		icon_slot.custom_minimum_size = Vector2(58, 58)
		icon_slot.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		icon_slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		holder.add_child(icon_slot)

		var tex := TextureRect.new()
		tex.texture = item.texture
		tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tex.position = Vector2(4, 4)
		tex.size = Vector2(50, 50)
		tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon_slot.add_child(tex)

		var nm := Label.new()
		nm.text = item.item_name
		nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		nm.clip_text = true
		nm.custom_minimum_size = Vector2(74, 0)
		nm.add_theme_font_override("font", UIStyle.FONT_INDER)
		nm.add_theme_font_size_override("font_size", 12)
		nm.add_theme_color_override("font_color", COL_CREAM_MUTED)
		nm.mouse_filter = Control.MOUSE_FILTER_IGNORE
		holder.add_child(nm)

		holder.scale = Vector2(0.78, 0.78)
		holder.modulate.a = 0.0
		_items_row.add_child(holder)
		item_holders.append(holder)
		item_icons.append(tex)

	_items_row.visible = not item_holders.is_empty()

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
	_anim_tween.tween_property(_banner, "modulate:a", 1.0, 0.28).set_trans(Tween.TRANS_SINE)
	_anim_tween.tween_property(_banner, "scale", Vector2.ONE, 0.36).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_anim_tween.tween_property(_banner, "position:y", 26.0, 0.40).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	# Staggered entrance + continuous smooth bobbing on each item icon
	for i in range(item_holders.size()):
		var h := item_holders[i]
		var icon := item_icons[i]
		h.pivot_offset = h.size * 0.5
		var enter_tw := create_tween()
		enter_tw.tween_interval(0.14 + i * 0.07)
		enter_tw.tween_property(h, "modulate:a", 1.0, 0.22).set_trans(Tween.TRANS_SINE)
		enter_tw.parallel().tween_property(h, "scale", Vector2.ONE, 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		enter_tw.tween_callback(func():
			if not is_instance_valid(icon) or my_session != _session_id:
				return
			var bob_tw := create_tween().set_loops()
			bob_tw.tween_property(icon, "position:y", 0.0, 0.65).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
			bob_tw.tween_property(icon, "position:y", 8.0, 0.65).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
			_bob_tweens.append(bob_tw)
		)

	# Longer hold so the player can admire the newly unlocked items
	await get_tree().create_timer(5.5).timeout
	if is_inside_tree() and my_session == _session_id:
		_on_close_pressed()


func _on_close_pressed() -> void:
	if not control.visible:
		return
	if _anim_tween and _anim_tween.is_valid():
		_anim_tween.kill()
	# Slower, smoother exit fade & upward glide
	_anim_tween = create_tween().set_parallel(true)
	_anim_tween.tween_property(_banner, "modulate:a", 0.0, 0.78).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_anim_tween.tween_property(_banner, "position:y", -_banner.size.y - 18.0, 0.88).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	await _anim_tween.finished
	_kill_bob_tweens()
	if is_inside_tree():
		control.visible = false
