class_name FolkloreJournalOverlay
extends CanvasLayer

## Lola's Folklore Scrapbook / Journal (Two-Page Diegetic Notebook UI).
## Press [J] to toggle. Displays each neighbor's 6-Rank Reputation, hidden/discovered
## favorite categories, 3-Arc / 6-Chapter story tracker, and progressively unlocked
## real-life Philippine folklore field notes (with blacked-out ??? redactions and a
## Rank 3 Real-Life Creature Depiction + caption & source).

const FolkloreCatalogScript := preload("res://Scripts/Progression/FolkloreCatalog.gd")

const COL_PARCHMENT := Color(0.95, 0.91, 0.82, 1.0)
const COL_PARCHMENT_DARK := Color(0.89, 0.83, 0.72, 1.0)
const COL_INK := Color(0.18, 0.14, 0.11, 1.0)
const COL_INK_MUTED := Color(0.42, 0.35, 0.28, 1.0)
const COL_GOLD := Color(0.76, 0.54, 0.14, 1.0)
const COL_REDACTED_BG := Color(0.14, 0.12, 0.11, 0.94)
const COL_REDACTED_TXT := Color(0.72, 0.66, 0.56, 0.88)

var is_open: bool = false
var _selected_idx: int = 0
var _neighbors: Array[CustomerData] = []
var _prev_mouse_mode: Input.MouseMode = Input.MOUSE_MODE_CAPTURED

var _root: Control
var _tabs_col: VBoxContainer
var _left_page: VBoxContainer
var _right_page: VBoxContainer


func _ready() -> void:
	layer = 35
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("folklore_journal_overlay")
	_build_ui()
	visible = false


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.is_echo():
		if is_open:
			if event.keycode == KEY_ESCAPE or event.keycode == KEY_J:
				get_viewport().set_input_as_handled()
				close_journal()
			return
		# Open journal with J (only when no other modal/dialogue/minigame is active)
		if event.keycode == KEY_J:
			if Dialogic.current_timeline != null:
				return
			if not get_tree().get_nodes_in_group("storefront_canvas_active").is_empty():
				return
			if not get_tree().get_nodes_in_group("minigame_overlay_active").is_empty():
				return
			get_viewport().set_input_as_handled()
			open_journal()


func open_journal(focus_character_path: String = "") -> void:
	if is_open:
		return
	_prev_mouse_mode = Input.mouse_mode
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	is_open = true
	visible = true
	_collect_neighbors()
	if focus_character_path != "":
		for i in range(_neighbors.size()):
			if _neighbors[i].resource_path == focus_character_path:
				_selected_idx = i
				break
	_selected_idx = clampi(_selected_idx, 0, maxi(0, _neighbors.size() - 1))
	EventBus.request_sfx.emit("tab_switch")
	EventBus.journal_toggled.emit(true)
	_refresh_all()


func close_journal() -> void:
	if not is_open:
		return
	is_open = false
	visible = false
	Input.mouse_mode = _prev_mouse_mode
	EventBus.request_sfx.emit("drop")
	EventBus.journal_toggled.emit(false)


func _collect_neighbors() -> void:
	_neighbors.clear()
	if is_instance_valid(StoryManager):
		for c in StoryManager.available_characters:
			if c != null:
				_neighbors.append(c)


func _refresh_all() -> void:
	_rebuild_tabs()
	_rebuild_spread()


func _rebuild_tabs() -> void:
	for ch in _tabs_col.get_children():
		ch.queue_free()

	for i in range(_neighbors.size()):
		var c: CustomerData = _neighbors[i]
		var met := CharacterProgressionManager.has_encountered(c.resource_path)
		var unread := CharacterProgressionManager.has_unread_journal(c.resource_path)
		var btn := Button.new()
		var display_label := (c.character_name if c.character_name != "" else c.get_clean_id().capitalize()) if met else "???"
		if unread:
			display_label = "● " + display_label
		btn.text = display_label
		btn.custom_minimum_size = Vector2(150, 38)
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.focus_mode = Control.FOCUS_NONE
		btn.add_theme_font_override("font", UIStyle.FONT_INDER)
		btn.add_theme_font_size_override("font_size", 14)

		var selected := (i == _selected_idx)
		var bg := Color(0.95, 0.90, 0.78, 1.0) if selected else Color(0.24, 0.19, 0.15, 0.95)
		var fg := COL_INK if selected else (Color(1.0, 0.88, 0.48) if unread else Color(0.86, 0.80, 0.70))
		var st := UIStyle.create_flat_stylebox(bg, 6, 10, 6)
		st.border_color = COL_GOLD if selected else Color(0.45, 0.35, 0.24, 0.7)
		st.set_border_width_all(1)
		btn.add_theme_stylebox_override("normal", st)
		btn.add_theme_stylebox_override("hover", st)
		btn.add_theme_stylebox_override("pressed", st)
		btn.add_theme_color_override("font_color", fg)
		btn.add_theme_color_override("font_hover_color", fg)
		var idx := i
		btn.pressed.connect(func():
			_selected_idx = idx
			EventBus.request_sfx.emit("tab_switch")
			_refresh_all()
		)
		_tabs_col.add_child(btn)


func _rebuild_spread() -> void:
	for ch in _left_page.get_children():
		ch.queue_free()
	for ch in _right_page.get_children():
		ch.queue_free()

	if _neighbors.is_empty():
		return
	var c: CustomerData = _neighbors[_selected_idx]
	var cpath := c.resource_path
	var clean_id := c.get_clean_id()
	CharacterProgressionManager.mark_journal_read(cpath)

	var met := CharacterProgressionManager.has_encountered(cpath)
	var rank := CharacterProgressionManager.get_rep_rank(cpath)
	var prog := CharacterProgressionManager.get_rep_rank_progress(cpath)
	var entry: Dictionary = FolkloreCatalogScript.get_entry(clean_id)

	# ─── LEFT PAGE: Neighbor Profile, Rep Meter, Favorites & 3-Arc/6-Ch Tracker ───
	var top_row := HBoxContainer.new()
	top_row.add_theme_constant_override("separation", 16)
	_left_page.add_child(top_row)

	# Polaroid Portrait Frame (blacked-out silhouette until met)
	var polaroid := PanelContainer.new()
	polaroid.custom_minimum_size = Vector2(118, 130)
	var pol_st := UIStyle.create_flat_stylebox(Color(0.99, 0.97, 0.93, 1.0), 4, 8, 8)
	pol_st.border_color = Color(0.68, 0.60, 0.48, 0.9)
	pol_st.set_border_width_all(1)
	pol_st.shadow_color = Color(0, 0, 0, 0.20)
	pol_st.shadow_size = 6
	polaroid.add_theme_stylebox_override("panel", pol_st)
	top_row.add_child(polaroid)

	var portrait_rect := TextureRect.new()
	var p_path := str(entry.get("portrait", ""))
	if p_path != "" and ResourceLoader.exists(p_path):
		portrait_rect.texture = load(p_path)
	portrait_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait_rect.modulate = Color.WHITE if met else Color(0.08, 0.07, 0.06, 0.92)
	polaroid.add_child(portrait_rect)

	var id_col := VBoxContainer.new()
	id_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	id_col.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	id_col.add_theme_constant_override("separation", 4)
	top_row.add_child(id_col)

	var name_lbl := Label.new()
	name_lbl.text = (c.character_name if c.character_name != "" else clean_id.capitalize()) if met else "???"
	name_lbl.add_theme_font_override("font", UIStyle.FONT_INDER)
	name_lbl.add_theme_font_size_override("font_size", 26)
	name_lbl.add_theme_color_override("font_color", COL_INK)
	id_col.add_child(name_lbl)

	var creature_lbl := Label.new()
	creature_lbl.text = str(entry.get("creature", "???")) if met else "Folklore Entity: ???"
	creature_lbl.add_theme_font_override("font", UIStyle.FONT_INDER)
	creature_lbl.add_theme_font_size_override("font_size", 15)
	creature_lbl.add_theme_color_override("font_color", COL_GOLD if met else COL_INK_MUTED)
	id_col.add_child(creature_lbl)

	var rank_lbl := Label.new()
	rank_lbl.text = "Reputation: Rank %d / 6 — %s" % [rank, CharacterProgressionManager.get_rep_rank_title(rank)]
	rank_lbl.add_theme_font_override("font", UIStyle.FONT_INDER)
	rank_lbl.add_theme_font_size_override("font_size", 15)
	rank_lbl.add_theme_color_override("font_color", COL_INK)
	id_col.add_child(rank_lbl)

	var rep_bar := ProgressBar.new()
	rep_bar.custom_minimum_size = Vector2(0, 12)
	rep_bar.max_value = 100.0
	rep_bar.value = float(prog["ratio"]) * 100.0
	rep_bar.show_percentage = false
	var rb_bg := UIStyle.create_flat_stylebox(Color(0.76, 0.70, 0.58, 1.0), 6, 0, 0)
	var rb_fill := UIStyle.create_flat_stylebox(Color(0.84, 0.58, 0.16, 1.0), 6, 0, 0)
	rep_bar.add_theme_stylebox_override("background", rb_bg)
	rep_bar.add_theme_stylebox_override("fill", rb_fill)
	id_col.add_child(rep_bar)

	var rep_num := Label.new()
	rep_num.text = ("MAX RANK REACHED" if bool(prog["is_max"]) else ("%d / %d Rep to next rank" % [int(prog["current"]), int(prog["needed"])])) if met else "Meet this neighbor to start earning Rep"
	rep_num.add_theme_font_override("font", UIStyle.FONT_INDER)
	rep_num.add_theme_font_size_override("font_size", 12)
	rep_num.add_theme_color_override("font_color", COL_INK_MUTED)
	id_col.add_child(rep_num)

	_add_section_header(_left_page, "FAVORITE CATEGORIES (Serve to Discover)")
	var fav_row := HBoxContainer.new()
	fav_row.add_theme_constant_override("separation", 8)
	_left_page.add_child(fav_row)
	var favs: Array[String] = c.get_favorite_categories()
	if favs.is_empty():
		var none_lbl := Label.new()
		none_lbl.text = "No known favorites"
		none_lbl.add_theme_font_override("font", UIStyle.FONT_INDER)
		none_lbl.add_theme_font_size_override("font_size", 14)
		none_lbl.add_theme_color_override("font_color", COL_INK_MUTED)
		fav_row.add_child(none_lbl)
	else:
		for cat in favs:
			var discovered := CharacterProgressionManager.is_favorite_discovered(cpath, cat)
			var pill := PanelContainer.new()
			var pst := UIStyle.create_flat_stylebox(Color(0.88, 0.74, 0.42, 0.45) if discovered else COL_REDACTED_BG, 6, 10, 5)
			pst.border_color = COL_GOLD if discovered else Color(0.3, 0.25, 0.2, 0.8)
			pst.set_border_width_all(1)
			pill.add_theme_stylebox_override("panel", pst)
			var plbl := Label.new()
			plbl.text = StoryManager.get_category_display_name(cat) if discovered else "???"
			plbl.add_theme_font_override("font", UIStyle.FONT_INDER)
			plbl.add_theme_font_size_override("font_size", 14)
			plbl.add_theme_color_override("font_color", COL_INK if discovered else COL_REDACTED_TXT)
			pill.add_child(plbl)
			fav_row.add_child(pill)

	_add_section_header(_left_page, "REPUTATION PERKS")
	var perk_lines: Array[Dictionary] = [
		{"req": 3, "text": "Rank 3: +1 Price Tolerance on Favorite Categories"},
		{"req": 5, "text": "Rank 5: +10% Scaling Cash Tip Bonus"},
		{"req": 6, "text": "Rank 6: +1 Global Price Tolerance & Confidant Seal"},
	]
	for p in perk_lines:
		var unlocked := rank >= int(p["req"])
		var pl := Label.new()
		pl.text = ("✓ " + str(p["text"])) if unlocked else ("■ ??? (Unlock at Rank %d)" % int(p["req"]))
		pl.add_theme_font_override("font", UIStyle.FONT_INDER)
		pl.add_theme_font_size_override("font_size", 14)
		pl.add_theme_color_override("font_color", Color(0.18, 0.46, 0.22) if unlocked else COL_INK_MUTED)
		_left_page.add_child(pl)

	_add_section_header(_left_page, "STORY PROGRESS (3 ARCS • 6 CHAPTERS)")
	var cur_ch := CharacterProgressionManager.get_chapter(cpath)
	for arc_i in range(3):
		var c1 := arc_i * 2 + 1
		var c2 := arc_i * 2 + 2
		var done1 := cur_ch >= c1
		var done2 := cur_ch >= c2
		var a_lbl := Label.new()
		a_lbl.text = "Arc %d:  %s Ch.%d   %s Ch.%d" % [
			arc_i + 1,
			"●" if done1 else "○", c1,
			"●" if done2 else "○", c2
		]
		a_lbl.add_theme_font_override("font", UIStyle.FONT_INDER)
		a_lbl.add_theme_font_size_override("font_size", 14)
		a_lbl.add_theme_color_override("font_color", COL_INK if (done1 or done2) else COL_INK_MUTED)
		_left_page.add_child(a_lbl)

	# ─── RIGHT PAGE: Real-Life Philippine Folklore Field Notes (Progressive ??? Unlocks) ───
	var r_title := Label.new()
	r_title.text = "REAL-LIFE FOLKLORE FIELD NOTES"
	r_title.add_theme_font_override("font", UIStyle.FONT_INDER)
	r_title.add_theme_font_size_override("font_size", 18)
	r_title.add_theme_color_override("font_color", COL_GOLD)
	_right_page.add_child(r_title)

	_add_folklore_block(_right_page, "Rank 1 — Regional Origin", str(entry.get("rank1_origin", "")), rank >= 1, 1)
	_add_folklore_block(_right_page, "Rank 2 — Traditional Beliefs & Taboos", str(entry.get("rank2_taboos", "")), rank >= 2, 2)

	# Rank 3: Real-Life Creature Depiction / Illustration + Caption & Source!
	_add_depiction_block(_right_page, entry, rank >= 3)

	_add_folklore_block(_right_page, "Rank 4 — Historical & Real-World Origins", str(entry.get("rank4_history", "")), rank >= 4, 4)
	_add_folklore_block(_right_page, "Rank 5 — Rare Folklore Trivia", str(entry.get("rank5_trivia", "")), rank >= 5, 5)
	_add_folklore_block(_right_page, "Rank 6 — Confidant Seal & Epilogue", str(entry.get("rank6_epilogue", "")), rank >= 6, 6)


func _add_section_header(parent: VBoxContainer, text: String) -> void:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_override("font", UIStyle.FONT_INDER)
	lbl.add_theme_font_size_override("font_size", 13)
	lbl.add_theme_color_override("font_color", COL_GOLD)
	parent.add_child(lbl)


func _add_folklore_block(parent: VBoxContainer, heading: String, body: String, unlocked: bool, req_rank: int) -> void:
	var box := PanelContainer.new()
	var st := UIStyle.create_flat_stylebox(Color(0.91, 0.86, 0.75, 0.85) if unlocked else COL_REDACTED_BG, 6, 10, 7)
	st.border_color = Color(0.72, 0.62, 0.45, 0.6) if unlocked else Color(0.28, 0.24, 0.20, 0.9)
	st.set_border_width_all(1)
	box.add_theme_stylebox_override("panel", st)
	parent.add_child(box)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 2)
	box.add_child(v)

	var h := Label.new()
	h.text = heading if unlocked else ("██████  ???  (Unlock at Rank %d)" % req_rank)
	h.add_theme_font_override("font", UIStyle.FONT_INDER)
	h.add_theme_font_size_override("font_size", 13)
	h.add_theme_color_override("font_color", COL_GOLD if unlocked else COL_REDACTED_TXT)
	v.add_child(h)

	if unlocked:
		var b := Label.new()
		b.text = body
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		b.add_theme_font_override("font", UIStyle.FONT_INDER)
		b.add_theme_font_size_override("font_size", 13)
		b.add_theme_color_override("font_color", COL_INK)
		v.add_child(b)


func _add_depiction_block(parent: VBoxContainer, entry: Dictionary, unlocked: bool) -> void:
	var box := PanelContainer.new()
	var st := UIStyle.create_flat_stylebox(Color(0.88, 0.82, 0.70, 0.95) if unlocked else COL_REDACTED_BG, 8, 12, 10)
	st.border_color = COL_GOLD if unlocked else Color(0.32, 0.27, 0.22, 0.95)
	st.set_border_width_all(2 if unlocked else 1)
	box.add_theme_stylebox_override("panel", st)
	parent.add_child(box)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	box.add_child(v)

	if not unlocked:
		var lock_lbl := Label.new()
		lock_lbl.text = "██████  REAL-LIFE DEPICTION: ???  ██████\nReach Reputation Rank 3 (Regular) to reveal archival illustration & source."
		lock_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lock_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		lock_lbl.add_theme_font_override("font", UIStyle.FONT_INDER)
		lock_lbl.add_theme_font_size_override("font_size", 13)
		lock_lbl.add_theme_color_override("font_color", COL_REDACTED_TXT)
		v.add_child(lock_lbl)
		return

	var title := Label.new()
	title.text = "Rank 3 — " + str(entry.get("rank3_depiction_title", "Archival Depiction"))
	title.add_theme_font_override("font", UIStyle.FONT_INDER)
	title.add_theme_font_size_override("font_size", 14)
	title.add_theme_color_override("font_color", COL_GOLD)
	v.add_child(title)

	# Image frame (renders custom real-life art if provided, or clean archival plate)
	var dep_path := str(entry.get("rank3_depiction_path", ""))
	if dep_path != "" and ResourceLoader.exists(dep_path):
		var img := TextureRect.new()
		img.texture = load(dep_path)
		img.custom_minimum_size = Vector2(0, 120)
		img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		v.add_child(img)

	var cap := Label.new()
	cap.text = str(entry.get("rank3_depiction_caption", ""))
	cap.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	cap.add_theme_font_override("font", UIStyle.FONT_INDER)
	cap.add_theme_font_size_override("font_size", 13)
	cap.add_theme_color_override("font_color", COL_INK)
	v.add_child(cap)

	var src := Label.new()
	src.text = str(entry.get("rank3_depiction_source", ""))
	src.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	src.add_theme_font_override("font", UIStyle.FONT_INDER)
	src.add_theme_font_size_override("font_size", 11)
	src.add_theme_color_override("font_color", COL_INK_MUTED)
	v.add_child(src)


func _build_ui() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_root)

	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.03, 0.024, 0.02, 0.78)
	_root.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(center)

	var outer_hbox := HBoxContainer.new()
	outer_hbox.add_theme_constant_override("separation", 6)
	center.add_child(outer_hbox)

	# Open Leather Notebook Cover
	var cover := PanelContainer.new()
	cover.custom_minimum_size = Vector2(960, 620)
	var cov_st := UIStyle.create_flat_stylebox(Color(0.24, 0.16, 0.11, 0.98), 14, 14, 14)
	cov_st.border_color = Color(0.82, 0.62, 0.28, 0.90)
	cov_st.set_border_width_all(2)
	cov_st.shadow_color = Color(0, 0, 0, 0.65)
	cov_st.shadow_size = 24
	cover.add_theme_stylebox_override("panel", cov_st)
	outer_hbox.add_child(cover)

	var spread_v := VBoxContainer.new()
	spread_v.add_theme_constant_override("separation", 8)
	cover.add_child(spread_v)

	# Notebook Top Bar
	var topbar := HBoxContainer.new()
	spread_v.add_child(topbar)
	var book_title := Label.new()
	book_title.text = "Lola's Folklore Scrapbook   (Press J or Esc to close)"
	book_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	book_title.add_theme_font_override("font", UIStyle.FONT_INDER)
	book_title.add_theme_font_size_override("font_size", 18)
	book_title.add_theme_color_override("font_color", Color(1.0, 0.92, 0.74))
	topbar.add_child(book_title)

	var close_btn := Button.new()
	close_btn.text = "✕"
	close_btn.focus_mode = Control.FOCUS_NONE
	close_btn.custom_minimum_size = Vector2(34, 34)
	close_btn.pressed.connect(close_journal)
	topbar.add_child(close_btn)

	# Two Parchment Pages Side-by-Side
	var pages := HBoxContainer.new()
	pages.size_flags_vertical = Control.SIZE_EXPAND_FILL
	pages.add_theme_constant_override("separation", 10)
	spread_v.add_child(pages)

	var left_panel := PanelContainer.new()
	left_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var lp_st := UIStyle.create_flat_stylebox(COL_PARCHMENT, 8, 18, 16)
	lp_st.border_color = Color(0.68, 0.58, 0.44, 0.75)
	lp_st.set_border_width_all(1)
	left_panel.add_theme_stylebox_override("panel", lp_st)
	pages.add_child(left_panel)

	var left_scroll := ScrollContainer.new()
	left_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left_panel.add_child(left_scroll)
	_left_page = VBoxContainer.new()
	_left_page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_left_page.add_theme_constant_override("separation", 10)
	left_scroll.add_child(_left_page)

	var right_panel := PanelContainer.new()
	right_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var rp_st := UIStyle.create_flat_stylebox(COL_PARCHMENT_DARK, 8, 18, 16)
	rp_st.border_color = Color(0.68, 0.58, 0.44, 0.75)
	rp_st.set_border_width_all(1)
	right_panel.add_theme_stylebox_override("panel", rp_st)
	pages.add_child(right_panel)

	var right_scroll := ScrollContainer.new()
	right_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right_panel.add_child(right_scroll)
	_right_page = VBoxContainer.new()
	_right_page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_right_page.add_theme_constant_override("separation", 8)
	right_scroll.add_child(_right_page)

	# Right-Edge Character Bookmark Tabs
	var tab_scroll := ScrollContainer.new()
	tab_scroll.custom_minimum_size = Vector2(160, 620)
	outer_hbox.add_child(tab_scroll)
	_tabs_col = VBoxContainer.new()
	_tabs_col.add_theme_constant_override("separation", 5)
	tab_scroll.add_child(_tabs_col)
