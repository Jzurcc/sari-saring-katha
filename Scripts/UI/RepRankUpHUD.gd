class_name RepRankUpHUD
extends CanvasLayer

## Sleek top-center celebration toast whenever a neighbor reaches a new Reputation Rank.

const FolkloreCatalogScript := preload("res://Scripts/Progression/FolkloreCatalog.gd")

var _root: Control
var _active_banner: Control = null
var _tween: Tween = null


func _ready() -> void:
	layer = 38
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
	_show_rank_up_toast(c_data, new_rank)


func _show_rank_up_toast(c_data: CustomerData, new_rank: int) -> void:
	if _tween and _tween.is_valid():
		_tween.kill()
	if is_instance_valid(_active_banner):
		_active_banner.queue_free()

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(560, 108)
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.anchor_top = 0.0
	panel.anchor_bottom = 0.0
	panel.offset_left = -280
	panel.offset_right = 280
	panel.offset_top = -130
	panel.offset_bottom = -22
	panel.modulate.a = 0.0
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := UIStyle.create_flat_stylebox(Color(0.09, 0.075, 0.06, 0.96), 10, 18, 12)
	style.border_color = Color(0.95, 0.76, 0.34, 0.95)
	style.border_width_left = 4
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.shadow_color = Color(0, 0, 0, 0.65)
	style.shadow_size = 16
	style.shadow_offset = Vector2(0, 6)
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
		var tr := TextureRect.new()
		tr.texture = load(portrait_path)
		tr.custom_minimum_size = Vector2(72, 72)
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tr.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		hbox.add_child(tr)

	var vcol := VBoxContainer.new()
	vcol.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vcol.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	vcol.add_theme_constant_override("separation", 2)
	hbox.add_child(vcol)

	var eyebrow := Label.new()
	eyebrow.text = "REPUTATION RANK UP!"
	eyebrow.add_theme_font_override("font", UIStyle.FONT_INDER)
	eyebrow.add_theme_font_size_override("font_size", 13)
	eyebrow.add_theme_color_override("font_color", Color(0.98, 0.82, 0.40))
	vcol.add_child(eyebrow)

	var title := Label.new()
	var cname := c_data.character_name if c_data.character_name != "" else c_data.get_clean_id().capitalize()
	var rtitle := CharacterProgressionManager.get_rep_rank_title(new_rank)
	title.text = "%s — Rank %d: %s" % [cname, new_rank, rtitle]
	title.add_theme_font_override("font", UIStyle.FONT_INDER)
	title.add_theme_font_size_override("font_size", 21)
	title.add_theme_color_override("font_color", Color(1.0, 0.96, 0.86))
	vcol.add_child(title)

	var perk := Label.new()
	perk.text = "%s  •  Press [J] for Journal" % CharacterProgressionManager.get_rep_rank_perk_summary(new_rank)
	perk.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	perk.add_theme_font_override("font", UIStyle.FONT_INDER)
	perk.add_theme_font_size_override("font_size", 14)
	perk.add_theme_color_override("font_color", Color(0.68, 0.94, 0.62))
	vcol.add_child(perk)

	EventBus.request_sfx.emit("purchase")
	_tween = create_tween()
	_tween.tween_property(panel, "offset_top", 24.0, 0.36).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tween.parallel().tween_property(panel, "offset_bottom", 132.0, 0.36).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tween.parallel().tween_property(panel, "modulate:a", 1.0, 0.22)
	_tween.tween_interval(3.4)
	_tween.tween_property(panel, "offset_top", -130.0, 0.38).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	_tween.parallel().tween_property(panel, "offset_bottom", -22.0, 0.38).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	_tween.parallel().tween_property(panel, "modulate:a", 0.0, 0.30)
	_tween.tween_callback(func():
		if is_instance_valid(panel):
			panel.queue_free()
		if _active_banner == panel:
			_active_banner = null
	)
