class_name RepRankUpHUD
extends CanvasLayer

## Top-center celebration toast whenever a neighbor reaches a new Reputation Rank.
## Routed through TopBannerQueue (FIFO) with Dark Warm Espresso + 4px accent bar,
## framed portrait medallion, Fredoka weights, [J] keycap chip, and draining timer bar.

const FolkloreCatalogScript := preload("res://Scripts/Progression/FolkloreCatalog.gd")
const ACCENT_REP := Color(0.56, 0.88, 0.48, 1.0)
const COL_GOLD_BRIGHT := Color(1.0, 0.88, 0.52, 1.0)

var _root: Control
var _active_banner: Control = null
var _tween: Tween = null


func _ready() -> void:
	layer = 100
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
	panel.custom_minimum_size = Vector2(560, 0)
	panel.modulate.a = 0.0
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := TopBannerQueue.create_banner_style(ACCENT_REP, 22, 14)
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
		var p_frame := PanelContainer.new()
		p_frame.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		p_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var pf_st := UIStyle.create_flat_stylebox(Color(0.12, 0.10, 0.08, 0.96), 10, 3, 3)
		pf_st.border_color = Color(TopBannerQueue.COL_GOLD.r, TopBannerQueue.COL_GOLD.g, TopBannerQueue.COL_GOLD.b, 0.85)
		pf_st.set_border_width_all(2)
		p_frame.add_theme_stylebox_override("panel", pf_st)
		hbox.add_child(p_frame)

		var portrait_rect := TextureRect.new()
		portrait_rect.texture = load(portrait_path)
		portrait_rect.custom_minimum_size = Vector2(64, 64)
		portrait_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		portrait_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		portrait_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		p_frame.add_child(portrait_rect)

	var vcol := VBoxContainer.new()
	vcol.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vcol.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	vcol.add_theme_constant_override("separation", 3)
	vcol.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_child(vcol)

	var eyebrow := Label.new()
	eyebrow.text = "✦ Reputation Rank Up"
	eyebrow.add_theme_font_override("font", UIStyle.FONT_FREDOKA_SEMIBOLD)
	eyebrow.add_theme_font_size_override("font_size", 15)
	eyebrow.add_theme_color_override("font_color", COL_GOLD_BRIGHT)
	eyebrow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vcol.add_child(eyebrow)

	var title := Label.new()
	var cname := c_data.character_name if c_data.character_name != "" else c_data.get_clean_id().capitalize()
	var rtitle := CharacterProgressionManager.get_rep_rank_title(new_rank)
	title.text = "%s — Rank %d: %s" % [cname, new_rank, rtitle]
	title.add_theme_font_override("font", UIStyle.FONT_FREDOKA_SEMIBOLD)
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", TopBannerQueue.COL_CREAM)
	title.add_theme_color_override("font_outline_color", TopBannerQueue.COL_OUTLINE)
	title.add_theme_constant_override("outline_size", 3)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vcol.add_child(title)

	var perk_row := HBoxContainer.new()
	perk_row.add_theme_constant_override("separation", 8)
	perk_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vcol.add_child(perk_row)

	var perk := Label.new()
	perk.text = CharacterProgressionManager.get_rep_rank_perk_summary(new_rank)
	perk.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	perk.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	perk.add_theme_font_override("font", UIStyle.FONT_FREDOKA_REG)
	perk.add_theme_font_size_override("font_size", 15)
	perk.add_theme_color_override("font_color", Color(0.68, 0.94, 0.62))
	perk.mouse_filter = Control.MOUSE_FILTER_IGNORE
	perk_row.add_child(perk)

	var keycap := TopBannerQueue.create_keycap_pill("J")
	perk_row.add_child(keycap)

	var j_lbl := Label.new()
	j_lbl.text = "Journal"
	j_lbl.add_theme_font_override("font", UIStyle.FONT_FREDOKA_MED)
	j_lbl.add_theme_font_size_override("font_size", 14)
	j_lbl.add_theme_color_override("font_color", TopBannerQueue.COL_CREAM_MUTED)
	j_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	perk_row.add_child(j_lbl)

	var timer_bar := TopBannerQueue.attach_timer_bar(panel, ACCENT_REP)

	EventBus.request_sfx.emit("purchase")

	panel.reset_size()
	await get_tree().process_frame
	await get_tree().process_frame
	if not is_inside_tree() or not is_instance_valid(panel):
		TopBannerQueue.complete()
		return
	panel.reset_size()

	var vp_size := get_viewport().get_visible_rect().size
	var target_y := TopBannerQueue.get_safe_top_y(vp_size.y)
	panel.position = Vector2((vp_size.x - panel.size.x) * 0.5, -panel.size.y - 14.0)
	panel.pivot_offset = panel.size * 0.5
	panel.scale = Vector2(0.90, 0.90)

	var hold_sec := 2.8 if TopBannerQueue.get_pending_count() >= 1 else 3.4
	TopBannerQueue.start_timer_bar(self, timer_bar, hold_sec)

	_tween = create_tween()
	_tween.tween_property(panel, "modulate:a", 1.0, 0.22).set_trans(Tween.TRANS_SINE)
	_tween.parallel().tween_property(panel, "scale", Vector2(1.03, 1.03), 0.26).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tween.parallel().tween_property(panel, "position:y", target_y, 0.30).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tween.tween_property(panel, "scale", Vector2.ONE, 0.14).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_tween.tween_interval(hold_sec)
	_tween.tween_property(panel, "position:y", -panel.size.y - 16.0, 0.30).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	_tween.parallel().tween_property(panel, "modulate:a", 0.0, 0.24).set_trans(Tween.TRANS_SINE)
	_tween.tween_callback(func():
		if is_instance_valid(panel):
			panel.queue_free()
		if _active_banner == panel:
			_active_banner = null
		TopBannerQueue.complete()
	)
