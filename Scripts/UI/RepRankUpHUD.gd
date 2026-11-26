class_name RepRankUpHUD
extends CanvasLayer

## Top-center celebration toast whenever a neighbor reaches a new Reputation Rank.
## Routed through TopBannerQueue (FIFO) with shared warm espresso visual shell.

const FolkloreCatalogScript := preload("res://Scripts/Progression/FolkloreCatalog.gd")

var _root: Control
var _bold_font: FontVariation
var _active_banner: Control = null
var _tween: Tween = null


func _ready() -> void:
	layer = 100
	_bold_font = FontVariation.new()
	_bold_font.base_font = UIStyle.FONT_INDER
	_bold_font.variation_embolden = 0.65

	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	EventBus.reputation_changed.connect(_on_reputation_changed)


func _on_reputation_changed(character_path: String, _new_rep: int, _delta: int, new_rank: int, ranked_up: bool) -> void:
	if not ranked_up or new_rank < 2:
		return
	var c_data: CustomerData = StoryManager._get_character_data(character_path)
	if c_data == null:
		return
	TopBannerQueue.enqueue(_show_rank_up_toast.bind(c_data, new_rank))


func _show_rank_up_toast(c_data: CustomerData, new_rank: int) -> void:
	if not is_inside_tree():
		TopBannerQueue.complete()
		return
	if _tween and _tween.is_valid():
		_tween.kill()
	if is_instance_valid(_active_banner):
		_active_banner.queue_free()

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(540, 0)
	panel.modulate.a = 0.0
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := TopBannerQueue.create_banner_style(Color(0.68, 0.88, 0.46, 1.0), 22, 14)
	panel.add_theme_stylebox_override("panel", style)
	_root.add_child(panel)
	_active_banner = panel

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 16)
	hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(hbox)

	var entry: Dictionary = FolkloreCatalogScript.get_entry(c_data.get_clean_id())
	var portrait_path: String = str(entry.get("portrait", ""))
	if portrait_path != "" and ResourceLoader.exists(portrait_path):
		var portrait_rect := TextureRect.new()
		portrait_rect.texture = load(portrait_path)
		portrait_rect.custom_minimum_size = Vector2(68, 68)
		portrait_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		portrait_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		portrait_rect.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		portrait_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hbox.add_child(portrait_rect)

	var vcol := VBoxContainer.new()
	vcol.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vcol.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	vcol.add_theme_constant_override("separation", 3)
	vcol.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_child(vcol)

	var eyebrow := Label.new()
	eyebrow.text = "REPUTATION RANK UP!"
	eyebrow.add_theme_font_override("font", _bold_font)
	eyebrow.add_theme_font_size_override("font_size", 13)
	eyebrow.add_theme_color_override("font_color", Color(0.98, 0.84, 0.42))
	eyebrow.add_theme_color_override("font_outline_color", TopBannerQueue.COL_OUTLINE)
	eyebrow.add_theme_constant_override("outline_size", 3)
	eyebrow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vcol.add_child(eyebrow)

	var title := Label.new()
	var cname := c_data.character_name if c_data.character_name != "" else c_data.get_clean_id().capitalize()
	var rtitle := CharacterProgressionManager.get_rep_rank_title(new_rank)
	title.text = "%s — Rank %d: %s" % [cname, new_rank, rtitle]
	title.add_theme_font_override("font", _bold_font)
	title.add_theme_font_size_override("font_size", 21)
	title.add_theme_color_override("font_color", TopBannerQueue.COL_CREAM)
	title.add_theme_color_override("font_outline_color", TopBannerQueue.COL_OUTLINE)
	title.add_theme_constant_override("outline_size", 4)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vcol.add_child(title)

	var perk := Label.new()
	perk.text = "%s  •  Press [J] for Journal" % CharacterProgressionManager.get_rep_rank_perk_summary(new_rank)
	perk.custom_minimum_size = Vector2(420, 0)
	perk.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	perk.add_theme_font_override("font", UIStyle.FONT_INDER)
	perk.add_theme_font_size_override("font_size", 14)
	perk.add_theme_color_override("font_color", Color(0.68, 0.94, 0.62))
	perk.add_theme_color_override("font_outline_color", TopBannerQueue.COL_OUTLINE)
	perk.add_theme_constant_override("outline_size", 3)
	perk.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vcol.add_child(perk)

	EventBus.request_sfx.emit("purchase")

	panel.reset_size()
	await get_tree().process_frame
	await get_tree().process_frame
	if not is_inside_tree() or not is_instance_valid(panel):
		TopBannerQueue.complete()
		return
	panel.reset_size()

	var vp_width := get_viewport().get_visible_rect().size.x
	panel.position = Vector2((vp_width - panel.size.x) * 0.5, -panel.size.y - 14.0)
	panel.pivot_offset = panel.size * 0.5
	panel.scale = Vector2(0.88, 0.88)

	_tween = create_tween()
	_tween.tween_property(panel, "modulate:a", 1.0, 0.22).set_trans(Tween.TRANS_SINE)
	_tween.parallel().tween_property(panel, "scale", Vector2(1.03, 1.03), 0.26).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tween.parallel().tween_property(panel, "position:y", 24.0, 0.30).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tween.tween_property(panel, "scale", Vector2.ONE, 0.14).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_tween.tween_interval(3.3)
	_tween.tween_property(panel, "position:y", -panel.size.y - 16.0, 0.30).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	_tween.parallel().tween_property(panel, "modulate:a", 0.0, 0.24).set_trans(Tween.TRANS_SINE)
	_tween.tween_callback(func():
		if is_instance_valid(panel):
			panel.queue_free()
		if _active_banner == panel:
			_active_banner = null
		TopBannerQueue.complete()
	)
