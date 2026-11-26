extends CanvasLayer

## Clean, celebratory Level-Up banner ("You Leveled Up!").
## Displays the level-up prize money pill beside the title and gently bobbing
## previews of newly unlocked items below, with a longer hold and slow graceful exit.

const Juice := preload("res://Scripts/UI/Minigames/MinigameJuice.gd")
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
	var style := TopBannerQueue.create_banner_style(COL_GOLD, 26, 18)
	_banner.add_theme_stylebox_override("panel", style)
	control.add_child(_banner)

	var col := VBoxContainer.new()
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 12)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_banner.add_child(col)

	# Clean centered "You Leveled Up!" header (level-up cash bonus is shown passively in the money delta)
	_title_lbl = Label.new()
	_title_lbl.text = "You Leveled Up!"
	_title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_lbl.add_theme_font_override("font", _bold_font)
	_title_lbl.add_theme_font_size_override("font_size", 32)
	_title_lbl.add_theme_color_override("font_color", COL_GOLD_BRIGHT)
	_title_lbl.add_theme_color_override("font_outline_color", COL_OUTLINE)
	_title_lbl.add_theme_constant_override("outline_size", 5)
	_title_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(_title_lbl)

	# Centered row of gently swaying unlocked item previews
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


func _on_upgrade_available(new_tier: int, cost: float, items: Array[ItemData]) -> void:
	var items_copy: Array[ItemData] = items.duplicate()
	TopBannerQueue.enqueue(_play_level_up_banner.bind(new_tier, cost, items_copy))


func _play_level_up_banner(_new_tier: int, _cost: float, items: Array[ItemData]) -> void:
	if not is_inside_tree():
		TopBannerQueue.complete()
		return
	_session_id += 1
	var my_session := _session_id
	_kill_bob_tweens()

	_title_lbl.text = "You Leveled Up!"

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
		holder.alignment = BoxContainer.ALIGNMENT_BEGIN
		holder.custom_minimum_size = Vector2(108, 114)
		holder.add_theme_constant_override("separation", 4)
		holder.mouse_filter = Control.MOUSE_FILTER_IGNORE

		# Fixed-size slot so the TextureRect can sway smoothly around its center
		var icon_slot := Control.new()
		icon_slot.custom_minimum_size = Vector2(74, 74)
		icon_slot.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		icon_slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		holder.add_child(icon_slot)

		var tex := TextureRect.new()
		tex.texture = item.texture
		tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tex.position = Vector2(4, 4)
		tex.size = Vector2(66, 66)
		tex.pivot_offset = Vector2(33, 33)
		tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon_slot.add_child(tex)

		var nm := Label.new()
		nm.text = item.item_name
		nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		nm.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		nm.max_lines_visible = 2
		nm.custom_minimum_size = Vector2(104, 0)
		nm.add_theme_font_override("font", UIStyle.FONT_INDER)
		nm.add_theme_font_size_override("font_size", 13)
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
	_banner.reset_size()
	await get_tree().process_frame
	await get_tree().process_frame
	if not is_inside_tree() or my_session != _session_id:
		TopBannerQueue.complete()
		return
	_banner.reset_size()

	var vp_width := get_viewport().get_visible_rect().size.x
	_banner.position = Vector2((vp_width - _banner.size.x) * 0.5, -_banner.size.y - 16.0)
	_banner.pivot_offset = _banner.size * 0.5
	_banner.scale = Vector2(0.80, 0.80)

	if _anim_tween and _anim_tween.is_valid():
		_anim_tween.kill()
	_anim_tween = create_tween().set_parallel(true)
	_anim_tween.tween_property(_banner, "modulate:a", 1.0, 0.24).set_trans(Tween.TRANS_SINE)
	_anim_tween.tween_property(_banner, "scale", Vector2(1.06, 1.06), 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_anim_tween.tween_property(_banner, "position:y", 26.0, 0.36).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_anim_tween.chain().tween_property(_banner, "scale", Vector2.ONE, 0.16).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

	# Celebratory gold sparkle bursts on both sides of the banner + gentle title pulse
	var bx := (vp_width - _banner.size.x) * 0.5
	var by := 26.0 + _banner.size.y * 0.5
	Juice.spawn_burst(control, Vector2(bx + 18.0, by), COL_GOLD_BRIGHT, 12, 120.0)
	Juice.spawn_burst(control, Vector2(bx + _banner.size.x - 18.0, by), COL_GOLD_BRIGHT, 12, 120.0)
	_title_lbl.pivot_offset = _title_lbl.size * 0.5
	var pulse_tw := create_tween().set_loops()
	pulse_tw.tween_property(_title_lbl, "scale", Vector2(1.045, 1.045), 0.75).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	pulse_tw.tween_property(_title_lbl, "scale", Vector2.ONE, 0.75).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_bob_tweens.append(pulse_tw)

	# Staggered entrance + continuous gentle sway on each item icon
	for i in range(item_holders.size()):
		var h := item_holders[i]
		var icon := item_icons[i]
		var sway_dir := 1.0 if (i % 2 == 0) else -1.0
		h.pivot_offset = h.size * 0.5
		var enter_tw := create_tween()
		enter_tw.tween_interval(0.14 + i * 0.07)
		enter_tw.tween_property(h, "modulate:a", 1.0, 0.22).set_trans(Tween.TRANS_SINE)
		enter_tw.parallel().tween_property(h, "scale", Vector2.ONE, 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		enter_tw.tween_callback(func():
			if not is_instance_valid(icon) or my_session != _session_id:
				return
			icon.rotation = -0.11 * sway_dir
			var sway_tw := create_tween().set_loops()
			sway_tw.tween_property(icon, "rotation", 0.11 * sway_dir, 0.85).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
			sway_tw.tween_property(icon, "rotation", -0.11 * sway_dir, 0.85).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
			_bob_tweens.append(sway_tw)
		)

	# Longer hold so the player can admire the newly unlocked items
	await get_tree().create_timer(5.5).timeout
	if is_inside_tree() and my_session == _session_id:
		_on_close_pressed()


func _on_close_pressed() -> void:
	if not control.visible:
		TopBannerQueue.complete()
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
	TopBannerQueue.complete()
