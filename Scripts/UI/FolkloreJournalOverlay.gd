class_name FolkloreJournalOverlay
extends CanvasLayer

## Lola's Folklore Scrapbook / Journal (Diegetic Two-Page Spiral Notebook UI).
## Press [J] to toggle. Uses Assets/ui/journal_ui.png (2180x1460) with aspect-locked
## layout matching NotebookUI.gd, curled-corner page flips, NO./DATE ink entries,
## sticky-note neighbor bookmark tabs, hidden/discovered favorites, 3-Arc/6-Chapter
## progress, and progressively unlocked Philippine folklore field notes with ??? redactions.

const FolkloreCatalogScript := preload("res://Scripts/Progression/FolkloreCatalog.gd")

const JOURNAL_TEX_PATH := "res://Assets/ui/journal_ui.png"
const INK_FONT_PATH := "res://Assets/Fonts/Inder/Inder-Regular.ttf"
const BOLD_FONT_PATH := "res://Assets/Fonts/Balete Trial/BaleteTrial-Bold.ttf"
const JOURNAL_ASPECT := 2180.0 / 1460.0

# Diegetic ink palette (matches NotebookUI.gd)
const INK_DARK := Color(0.14, 0.16, 0.28, 0.95)       # Ballpoint blue-black ink
const INK_HEADER := Color(0.24, 0.16, 0.10, 0.96)     # Deep sepia ink
const INK_GOLD := Color(0.62, 0.38, 0.08, 0.98)       # Warm ochre / amber ink
const INK_RED := Color(0.70, 0.13, 0.11, 0.96)        # Red margin / stamp ink
const INK_GREEN := Color(0.16, 0.48, 0.22, 0.96)      # Unlocked perk green ink
const INK_MUTED := Color(0.38, 0.34, 0.29, 0.78)      # Soft pencil gray
const COL_REDACTED_BG := Color(0.13, 0.11, 0.10, 0.92)
const COL_REDACTED_TXT := Color(0.82, 0.76, 0.65, 0.92)

var is_open: bool = false
var _selected_idx: int = 0
var _neighbors: Array[CustomerData] = []
var _prev_mouse_mode: Input.MouseMode = Input.MOUSE_MODE_CAPTURED

var _ink_font: Font
var _bold_font: FontVariation

var _root: Control
var _book_rect: TextureRect
var _close_btn: Button
var _next_btn: Button
var _prev_btn: Button
var _no_lbl: Label
var _date_lbl: Label
var _footer_right_lbl: Label
var _left_scroll: ScrollContainer
var _right_scroll: ScrollContainer
var _left_page: VBoxContainer
var _right_page: VBoxContainer
var _tabs_scroll: ScrollContainer
var _tabs_col: VBoxContainer


func _ready() -> void:
	layer = 35
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("folklore_journal_overlay")

	_ink_font = load(INK_FONT_PATH) if ResourceLoader.exists(INK_FONT_PATH) else UIStyle.FONT_INDER
	_bold_font = FontVariation.new()
	_bold_font.base_font = load(BOLD_FONT_PATH) if ResourceLoader.exists(BOLD_FONT_PATH) else _ink_font
	_bold_font.variation_embolden = 0.25

	_build_ui()
	visible = false


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.is_echo():
		if is_open:
			if event.keycode == KEY_ESCAPE or event.keycode == KEY_J:
				get_viewport().set_input_as_handled()
				close_journal()
			elif event.keycode == KEY_RIGHT:
				get_viewport().set_input_as_handled()
				_step_neighbor(1)
			elif event.keycode == KEY_LEFT:
				get_viewport().set_input_as_handled()
				_step_neighbor(-1)
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
	call_deferred("_on_book_resized")


func close_journal() -> void:
	if not is_open:
		return
	is_open = false
	visible = false
	Input.mouse_mode = _prev_mouse_mode
	EventBus.request_sfx.emit("drop")
	EventBus.journal_toggled.emit(false)


func _step_neighbor(dir: int) -> void:
	if _neighbors.size() <= 1:
		return
	var next_idx := clampi(_selected_idx + dir, 0, _neighbors.size() - 1)
	if next_idx == _selected_idx:
		return
	_selected_idx = next_idx
	EventBus.request_sfx.emit("interact")
	_refresh_all()
	_play_page_flip_fx(dir)


func _collect_neighbors() -> void:
	_neighbors.clear()
	if is_instance_valid(StoryManager):
		for c in StoryManager.available_characters:
			if c != null:
				_neighbors.append(c)


func _refresh_all() -> void:
	_rebuild_tabs()
	_rebuild_spread()
	_sync_header_date()
	if is_instance_valid(_next_btn):
		_next_btn.disabled = (_selected_idx >= _neighbors.size() - 1)
	if is_instance_valid(_prev_btn):
		_prev_btn.disabled = (_selected_idx <= 0)
	if is_instance_valid(_footer_right_lbl):
		_footer_right_lbl.text = "Entry %d of %d" % [_selected_idx + 1, maxi(1, _neighbors.size())]


func _sync_header_date() -> void:
	var day_val := StoryManager.day if is_instance_valid(StoryManager) else 1
	var total_idx := maxi(0, day_val - 1)
	@warning_ignore("integer_division")
	var months_elapsed := total_idx / 31
	var day_in_month := (total_idx % 31) + 1
	var month_num := ((7 + months_elapsed) % 12) + 1 # August = 8
	@warning_ignore("integer_division")
	var year_short := (2013 + (7 + months_elapsed) / 12) % 100
	if is_instance_valid(_no_lbl):
		_no_lbl.text = "%02d" % (_selected_idx + 1)
	if is_instance_valid(_date_lbl):
		_date_lbl.text = "%02d  %02d  %02d" % [month_num, day_in_month, year_short]


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
		btn.custom_minimum_size = Vector2(142, 34)
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.focus_mode = Control.FOCUS_NONE
		btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		btn.add_theme_font_override("font", _ink_font)
		btn.add_theme_font_size_override("font_size", 13)

		var selected := (i == _selected_idx)
		var bg := Color(0.97, 0.92, 0.80, 0.98) if selected else Color(0.22, 0.17, 0.13, 0.92)
		var hov_bg := Color(0.99, 0.95, 0.86, 1.0) if selected else Color(0.32, 0.24, 0.18, 0.96)
		var fg := INK_HEADER if selected else (Color(1.0, 0.88, 0.48) if unread else Color(0.90, 0.84, 0.74))

		var st := StyleBoxFlat.new()
		st.bg_color = bg
		st.corner_radius_top_right = 7
		st.corner_radius_bottom_right = 7
		st.corner_radius_top_left = 2
		st.corner_radius_bottom_left = 2
		st.content_margin_left = 10
		st.content_margin_right = 8
		st.content_margin_top = 4
		st.content_margin_bottom = 4
		st.border_width_top = 1
		st.border_width_right = 2
		st.border_width_bottom = 1
		st.border_width_left = 0 if selected else 1
		st.border_color = INK_GOLD if selected else Color(0.48, 0.37, 0.25, 0.72)
		st.shadow_color = Color(0.0, 0.0, 0.0, 0.35)
		st.shadow_size = 4

		var st_hov: StyleBoxFlat = st.duplicate()
		st_hov.bg_color = hov_bg

		btn.add_theme_stylebox_override("normal", st)
		btn.add_theme_stylebox_override("hover", st_hov)
		btn.add_theme_stylebox_override("pressed", st)
		btn.add_theme_color_override("font_color", fg)
		btn.add_theme_color_override("font_hover_color", fg)
		var idx := i
		btn.pressed.connect(func():
			var dir := 1 if idx >= _selected_idx else -1
			_selected_idx = idx
			EventBus.request_sfx.emit("tab_switch")
			_refresh_all()
			_play_page_flip_fx(dir)
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

	if is_instance_valid(_left_scroll):
		_left_scroll.scroll_vertical = 0
	if is_instance_valid(_right_scroll):
		_right_scroll.scroll_vertical = 0

	var met := CharacterProgressionManager.has_encountered(cpath)
	var rank := CharacterProgressionManager.get_rep_rank(cpath)
	var prog := CharacterProgressionManager.get_rep_rank_progress(cpath)
	var entry: Dictionary = FolkloreCatalogScript.get_entry(clean_id)

	# ─── LEFT PAGE: Neighbor Profile, Rep Meter, Favorites & 3-Arc/6-Ch Tracker ───
	var top_row := HBoxContainer.new()
	top_row.add_theme_constant_override("separation", 14)
	_left_page.add_child(top_row)

	# Polaroid Portrait Frame taped onto the lined page (blacked-out silhouette until met)
	var polaroid := PanelContainer.new()
	polaroid.custom_minimum_size = Vector2(104, 116)
	var pol_st := UIStyle.create_flat_stylebox(Color(0.99, 0.97, 0.93, 0.98), 3, 7, 7)
	pol_st.content_margin_bottom = 16
	pol_st.border_color = Color(0.62, 0.54, 0.42, 0.85)
	pol_st.set_border_width_all(1)
	pol_st.shadow_color = Color(0.0, 0.0, 0.0, 0.22)
	pol_st.shadow_size = 5
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
	id_col.add_theme_constant_override("separation", 3)
	top_row.add_child(id_col)

	var name_lbl := Label.new()
	name_lbl.text = (c.character_name if c.character_name != "" else clean_id.capitalize()) if met else "???"
	name_lbl.add_theme_font_override("font", _bold_font)
	name_lbl.add_theme_font_size_override("font_size", 24)
	name_lbl.add_theme_color_override("font_color", INK_HEADER)
	id_col.add_child(name_lbl)

	var creature_lbl := Label.new()
	creature_lbl.text = str(entry.get("creature", "???")) if met else "Folklore Entity: ???"
	creature_lbl.add_theme_font_override("font", _ink_font)
	creature_lbl.add_theme_font_size_override("font_size", 14)
	creature_lbl.add_theme_color_override("font_color", INK_RED if met else INK_MUTED)
	id_col.add_child(creature_lbl)

	var rank_lbl := Label.new()
	rank_lbl.text = "Rank %d / 6 — %s" % [rank, CharacterProgressionManager.get_rep_rank_title(rank)]
	rank_lbl.add_theme_font_override("font", _bold_font)
	rank_lbl.add_theme_font_size_override("font_size", 14)
	rank_lbl.add_theme_color_override("font_color", INK_DARK)
	id_col.add_child(rank_lbl)

	var rep_bar := ProgressBar.new()
	rep_bar.custom_minimum_size = Vector2(0, 10)
	rep_bar.max_value = 100.0
	rep_bar.value = float(prog["ratio"]) * 100.0
	rep_bar.show_percentage = false
	var rb_bg := UIStyle.create_flat_stylebox(Color(0.76, 0.69, 0.56, 0.72), 5, 0, 0)
	var rb_fill := UIStyle.create_flat_stylebox(Color(0.76, 0.48, 0.12, 0.95), 5, 0, 0)
	rep_bar.add_theme_stylebox_override("background", rb_bg)
	rep_bar.add_theme_stylebox_override("fill", rb_fill)
	id_col.add_child(rep_bar)

	var rep_num := Label.new()
	rep_num.text = ("MAX RANK REACHED" if bool(prog["is_max"]) else ("%d / %d Rep to next rank" % [int(prog["current"]), int(prog["needed"])])) if met else "Meet this neighbor to start earning Rep"
	rep_num.add_theme_font_override("font", _ink_font)
	rep_num.add_theme_font_size_override("font_size", 12)
	rep_num.add_theme_color_override("font_color", INK_MUTED)
	id_col.add_child(rep_num)

	_add_ink_divider(_left_page)
	_add_section_header(_left_page, "FAVORITE CATEGORIES (Serve to Discover)")
	var fav_row := HFlowContainer.new()
	fav_row.add_theme_constant_override("h_separation", 8)
	fav_row.add_theme_constant_override("v_separation", 6)
	_left_page.add_child(fav_row)
	var favs: Array[String] = c.get_favorite_categories()
	if favs.is_empty():
		var none_lbl := Label.new()
		none_lbl.text = "No known favorites"
		none_lbl.add_theme_font_override("font", _ink_font)
		none_lbl.add_theme_font_size_override("font_size", 14)
		none_lbl.add_theme_color_override("font_color", INK_MUTED)
		fav_row.add_child(none_lbl)
	else:
		for cat in favs:
			var discovered := CharacterProgressionManager.is_favorite_discovered(cpath, cat)
			var pill := PanelContainer.new()
			var pst := UIStyle.create_flat_stylebox(Color(0.88, 0.76, 0.46, 0.34) if discovered else COL_REDACTED_BG, 5, 10, 4)
			pst.border_color = INK_GOLD if discovered else Color(0.28, 0.24, 0.20, 0.9)
			pst.set_border_width_all(1)
			pill.add_theme_stylebox_override("panel", pst)
			var plbl := Label.new()
			plbl.text = StoryManager.get_category_display_name(cat) if discovered else "???"
			plbl.add_theme_font_override("font", _bold_font if discovered else _ink_font)
			plbl.add_theme_font_size_override("font_size", 13)
			plbl.add_theme_color_override("font_color", INK_HEADER if discovered else COL_REDACTED_TXT)
			pill.add_child(plbl)
			fav_row.add_child(pill)

	_add_ink_divider(_left_page)
	_add_section_header(_left_page, "REPUTATION PERKS")
	var perk_lines: Array[Dictionary] = [
		{"req": 3, "text": "Rank 3: +1 Price Tolerance on Favorites"},
		{"req": 5, "text": "Rank 5: +10% Scaling Cash Tip Bonus"},
		{"req": 6, "text": "Rank 6: +1 Global Tolerance & Confidant Seal"},
	]
	for p in perk_lines:
		var unlocked := rank >= int(p["req"])
		var pl := Label.new()
		pl.text = ("✓ " + str(p["text"])) if unlocked else ("■ ???  (Unlock at Rank %d)" % int(p["req"]))
		pl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		pl.add_theme_font_override("font", _ink_font)
		pl.add_theme_font_size_override("font_size", 14)
		pl.add_theme_color_override("font_color", INK_GREEN if unlocked else INK_MUTED)
		_left_page.add_child(pl)

	_add_ink_divider(_left_page)
	_add_section_header(_left_page, "STORY PROGRESS  (3 ARCS • 6 CHAPTERS)")
	var cur_ch := CharacterProgressionManager.get_chapter(cpath)
	for arc_i in range(3):
		var c1 := arc_i * 2 + 1
		var c2 := arc_i * 2 + 2
		var done1 := cur_ch >= c1
		var done2 := cur_ch >= c2
		var a_lbl := Label.new()
		a_lbl.text = "Arc %d:   %s Ch.%d     %s Ch.%d" % [
			arc_i + 1,
			"●" if done1 else "○", c1,
			"●" if done2 else "○", c2
		]
		a_lbl.add_theme_font_override("font", _ink_font)
		a_lbl.add_theme_font_size_override("font_size", 14)
		a_lbl.add_theme_color_override("font_color", INK_DARK if (done1 or done2) else INK_MUTED)
		_left_page.add_child(a_lbl)

	# ─── RIGHT PAGE: Real-Life Philippine Folklore Field Notes (Progressive ??? Unlocks) ───
	_add_folklore_block(_right_page, "Rank 1 — Regional Origin", str(entry.get("rank1_origin", "")), rank >= 1, 1)
	_add_folklore_block(_right_page, "Rank 2 — Traditional Beliefs & Taboos", str(entry.get("rank2_taboos", "")), rank >= 2, 2)

	# Rank 3: Real-Life Creature Depiction / Illustration + Caption & Source!
	_add_depiction_block(_right_page, entry, rank >= 3)

	_add_folklore_block(_right_page, "Rank 4 — Historical & Real-World Origins", str(entry.get("rank4_history", "")), rank >= 4, 4)
	_add_folklore_block(_right_page, "Rank 5 — Rare Folklore Trivia", str(entry.get("rank5_trivia", "")), rank >= 5, 5)
	_add_folklore_block(_right_page, "Rank 6 — Confidant Seal & Epilogue", str(entry.get("rank6_epilogue", "")), rank >= 6, 6)


func _add_ink_divider(parent: VBoxContainer) -> void:
	var line := ColorRect.new()
	line.custom_minimum_size = Vector2(0, 1)
	line.color = Color(0.54, 0.42, 0.30, 0.35)
	parent.add_child(line)


func _add_section_header(parent: VBoxContainer, text: String) -> void:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_override("font", _bold_font)
	lbl.add_theme_font_size_override("font_size", 13)
	lbl.add_theme_color_override("font_color", INK_GOLD)
	parent.add_child(lbl)


func _add_folklore_block(parent: VBoxContainer, heading: String, body: String, unlocked: bool, req_rank: int) -> void:
	var box := PanelContainer.new()
	# Unlocked entries sit almost transparently over the ruled notebook paper;
	# locked entries look like dark ink redaction bars!
	var st := UIStyle.create_flat_stylebox(Color(0.96, 0.91, 0.80, 0.28) if unlocked else COL_REDACTED_BG, 5, 9, 6)
	st.border_color = Color(0.62, 0.48, 0.30, 0.38) if unlocked else Color(0.26, 0.22, 0.18, 0.92)
	st.set_border_width_all(1)
	box.add_theme_stylebox_override("panel", st)
	parent.add_child(box)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 2)
	box.add_child(v)

	var h := Label.new()
	h.text = heading if unlocked else ("██████  ???  (Unlock at Rank %d)" % req_rank)
	h.add_theme_font_override("font", _bold_font if unlocked else _ink_font)
	h.add_theme_font_size_override("font_size", 13)
	h.add_theme_color_override("font_color", INK_HEADER if unlocked else COL_REDACTED_TXT)
	v.add_child(h)

	if unlocked:
		var b := Label.new()
		b.text = body
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		b.add_theme_font_override("font", _ink_font)
		b.add_theme_font_size_override("font_size", 13)
		b.add_theme_color_override("font_color", INK_DARK)
		v.add_child(b)


func _add_depiction_block(parent: VBoxContainer, entry: Dictionary, unlocked: bool) -> void:
	var box := PanelContainer.new()
	var st := UIStyle.create_flat_stylebox(Color(0.95, 0.89, 0.76, 0.52) if unlocked else COL_REDACTED_BG, 6, 10, 8)
	st.border_color = INK_GOLD if unlocked else Color(0.30, 0.25, 0.20, 0.95)
	st.set_border_width_all(2 if unlocked else 1)
	box.add_theme_stylebox_override("panel", st)
	parent.add_child(box)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 5)
	box.add_child(v)

	if not unlocked:
		var lock_lbl := Label.new()
		lock_lbl.text = "██████  REAL-LIFE DEPICTION: ???  ██████\nReach Reputation Rank 3 (Regular) to reveal archival illustration & source."
		lock_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lock_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		lock_lbl.add_theme_font_override("font", _ink_font)
		lock_lbl.add_theme_font_size_override("font_size", 12)
		lock_lbl.add_theme_color_override("font_color", COL_REDACTED_TXT)
		v.add_child(lock_lbl)
		return

	var title := Label.new()
	title.text = "Rank 3 — " + str(entry.get("rank3_depiction_title", "Archival Depiction"))
	title.add_theme_font_override("font", _bold_font)
	title.add_theme_font_size_override("font_size", 14)
	title.add_theme_color_override("font_color", INK_RED)
	v.add_child(title)

	# Image frame (renders custom real-life art if provided)
	var dep_path := str(entry.get("rank3_depiction_path", ""))
	if dep_path != "" and ResourceLoader.exists(dep_path):
		var img := TextureRect.new()
		img.texture = load(dep_path)
		img.custom_minimum_size = Vector2(0, 118)
		img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		v.add_child(img)

	var cap := Label.new()
	cap.text = str(entry.get("rank3_depiction_caption", ""))
	cap.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	cap.add_theme_font_override("font", _ink_font)
	cap.add_theme_font_size_override("font_size", 13)
	cap.add_theme_color_override("font_color", INK_DARK)
	v.add_child(cap)

	var src := Label.new()
	src.text = str(entry.get("rank3_depiction_source", ""))
	src.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	src.add_theme_font_override("font", _ink_font)
	src.add_theme_font_size_override("font_size", 11)
	src.add_theme_color_override("font_color", INK_MUTED)
	v.add_child(src)


func _load_journal_texture() -> Texture2D:
	if ResourceLoader.exists(JOURNAL_TEX_PATH):
		var tex := load(JOURNAL_TEX_PATH) as Texture2D
		if tex != null:
			return tex
	# Fallback for unimported PNG during dev
	var abs_path := ProjectSettings.globalize_path(JOURNAL_TEX_PATH)
	if FileAccess.file_exists(abs_path):
		var img := Image.load_from_file(abs_path)
		if img != null and not img.is_empty():
			return ImageTexture.create_from_image(img)
	return null


func _make_corner_flip_button(glyph: String, tip: String) -> Button:
	var btn := Button.new()
	btn.text = glyph
	btn.tooltip_text = tip
	btn.focus_mode = Control.FOCUS_NONE
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var norm := UIStyle.create_flat_stylebox(Color(0.95, 0.88, 0.74, 0.0), 10, 0, 0)
	var hov := UIStyle.create_flat_stylebox(Color(0.85, 0.72, 0.50, 0.34), 10, 0, 0)
	hov.border_color = Color(0.45, 0.28, 0.14, 0.55)
	hov.set_border_width_all(1)
	var dis := UIStyle.create_flat_stylebox(Color(0, 0, 0, 0), 10, 0, 0)
	btn.add_theme_stylebox_override("normal", norm)
	btn.add_theme_stylebox_override("hover", hov)
	btn.add_theme_stylebox_override("pressed", hov)
	btn.add_theme_stylebox_override("disabled", dis)
	btn.add_theme_font_override("font", _bold_font)
	btn.add_theme_font_size_override("font_size", 22)
	btn.add_theme_color_override("font_color", Color(0.28, 0.18, 0.11, 0.88))
	btn.add_theme_color_override("font_hover_color", INK_RED)
	btn.add_theme_color_override("font_disabled_color", Color(0.36, 0.30, 0.24, 0.24))
	return btn


func _play_page_flip_fx(dir: int) -> void:
	for sc in [_left_scroll, _right_scroll]:
		if not is_instance_valid(sc):
			continue
		sc.modulate.a = 0.0
		var tw := create_tween()
		tw.tween_property(sc, "modulate:a", 1.0, 0.16).set_trans(Tween.TRANS_SINE)


func _on_book_resized() -> void:
	if not is_instance_valid(_book_rect):
		return
	var br := _book_rect.get_global_rect()
	if br.size.x <= 10.0 or br.size.y <= 10.0:
		return
	var vp := get_viewport().get_visible_rect().size

	# Position external rounded "✕" close button outside top-right of the notebook
	if is_instance_valid(_close_btn):
		var bx := minf(br.end.x + 14.0, vp.x - _close_btn.size.x - 10.0)
		var by := maxf(br.position.y + 4.0, 10.0)
		_close_btn.global_position = Vector2(bx, by)

	# Position sticky-note bookmark tabs cleanly along the right outer edge of the notebook
	if is_instance_valid(_tabs_scroll):
		var tab_w := 148.0
		var tx := minf(br.end.x - 4.0, vp.x - tab_w - 6.0)
		var ty := br.position.y + 62.0
		var th := maxf(200.0, br.size.y - 78.0)
		_tabs_scroll.global_position = Vector2(tx, ty)
		_tabs_scroll.size = Vector2(tab_w, th)


func _build_ui() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_root)

	# Dimmed clickable backdrop (clicking outside the notebook closes it)
	var backdrop := ColorRect.new()
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.color = Color(0.03, 0.025, 0.02, 0.74)
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	backdrop.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and ev.pressed and (ev as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
			close_journal()
	)
	_root.add_child(backdrop)

	# Aspect-locked two-page spiral notebook container (leaves room on right for tabs)
	var aspect := AspectRatioContainer.new()
	aspect.anchor_left = 0.025
	aspect.anchor_right = 0.875
	aspect.anchor_top = 0.045
	aspect.anchor_bottom = 0.955
	aspect.ratio = JOURNAL_ASPECT
	aspect.stretch_mode = AspectRatioContainer.STRETCH_FIT
	aspect.alignment_horizontal = AspectRatioContainer.ALIGNMENT_CENTER
	aspect.alignment_vertical = AspectRatioContainer.ALIGNMENT_CENTER
	aspect.mouse_filter = Control.MOUSE_FILTER_PASS
	_root.add_child(aspect)

	_book_rect = TextureRect.new()
	_book_rect.texture = _load_journal_texture()
	_book_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_book_rect.stretch_mode = TextureRect.STRETCH_SCALE
	_book_rect.mouse_filter = Control.MOUSE_FILTER_STOP
	_book_rect.resized.connect(_on_book_resized)
	aspect.add_child(_book_rect)

	# Top-right printed "NO." and "DATE / /" ink entries on the right page
	_no_lbl = Label.new()
	_no_lbl.anchor_left = 0.855
	_no_lbl.anchor_right = 0.935
	_no_lbl.anchor_top = 0.058
	_no_lbl.anchor_bottom = 0.090
	_no_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_no_lbl.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	_no_lbl.add_theme_font_override("font", _ink_font)
	_no_lbl.add_theme_font_size_override("font_size", 16)
	_no_lbl.add_theme_color_override("font_color", INK_DARK)
	_no_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_book_rect.add_child(_no_lbl)

	_date_lbl = Label.new()
	_date_lbl.anchor_left = 0.855
	_date_lbl.anchor_right = 0.935
	_date_lbl.anchor_top = 0.094
	_date_lbl.anchor_bottom = 0.126
	_date_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_date_lbl.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	_date_lbl.add_theme_font_override("font", _ink_font)
	_date_lbl.add_theme_font_size_override("font_size", 14)
	_date_lbl.add_theme_color_override("font_color", INK_DARK)
	_date_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_book_rect.add_child(_date_lbl)

	# Left Page Top Header ("LOLA'S FOLKLORE SCRAPBOOK")
	var left_hdr := Label.new()
	left_hdr.text = "LOLA'S FOLKLORE SCRAPBOOK"
	left_hdr.anchor_left = 0.098
	left_hdr.anchor_right = 0.448
	left_hdr.anchor_top = 0.068
	left_hdr.anchor_bottom = 0.112
	left_hdr.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	left_hdr.add_theme_font_override("font", _bold_font)
	left_hdr.add_theme_font_size_override("font_size", 16)
	left_hdr.add_theme_color_override("font_color", INK_HEADER)
	left_hdr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_book_rect.add_child(left_hdr)

	# Left Page Scrollable Body (inside left red margin, clear of center spiral rings)
	_left_scroll = ScrollContainer.new()
	_left_scroll.anchor_left = 0.098
	_left_scroll.anchor_right = 0.448
	_left_scroll.anchor_top = 0.124
	_left_scroll.anchor_bottom = 0.910
	_left_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_book_rect.add_child(_left_scroll)

	_left_page = VBoxContainer.new()
	_left_page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_left_page.add_theme_constant_override("separation", 8)
	_left_scroll.add_child(_left_page)

	# Right Page Top Header ("FOLKLORE FIELD NOTES") cleanly left of NO./DATE
	var right_hdr := Label.new()
	right_hdr.text = "FOLKLORE FIELD NOTES"
	right_hdr.anchor_left = 0.598
	right_hdr.anchor_right = 0.818
	right_hdr.anchor_top = 0.068
	right_hdr.anchor_bottom = 0.112
	right_hdr.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	right_hdr.add_theme_font_override("font", _bold_font)
	right_hdr.add_theme_font_size_override("font_size", 16)
	right_hdr.add_theme_color_override("font_color", INK_HEADER)
	right_hdr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_book_rect.add_child(right_hdr)

	# Right Page Scrollable Body (inside right red margin, below NO./DATE, clear of curls)
	_right_scroll = ScrollContainer.new()
	_right_scroll.anchor_left = 0.598
	_right_scroll.anchor_right = 0.936
	_right_scroll.anchor_top = 0.142
	_right_scroll.anchor_bottom = 0.888
	_right_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_book_rect.add_child(_right_scroll)

	_right_page = VBoxContainer.new()
	_right_page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_right_page.add_theme_constant_override("separation", 7)
	_right_scroll.add_child(_right_page)

	# Subtle bottom-margin footers
	var footer_left := Label.new()
	footer_left.text = "Press [J] or Esc to close   •   ← / → to flip"
	footer_left.anchor_left = 0.098
	footer_left.anchor_right = 0.448
	footer_left.anchor_top = 0.916
	footer_left.anchor_bottom = 0.952
	footer_left.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	footer_left.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	footer_left.add_theme_font_override("font", _ink_font)
	footer_left.add_theme_font_size_override("font_size", 12)
	footer_left.add_theme_color_override("font_color", INK_MUTED)
	footer_left.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_book_rect.add_child(footer_left)

	_footer_right_lbl = Label.new()
	_footer_right_lbl.anchor_left = 0.598
	_footer_right_lbl.anchor_right = 0.890
	_footer_right_lbl.anchor_top = 0.916
	_footer_right_lbl.anchor_bottom = 0.952
	_footer_right_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_footer_right_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_footer_right_lbl.add_theme_font_override("font", _ink_font)
	_footer_right_lbl.add_theme_font_size_override("font_size", 12)
	_footer_right_lbl.add_theme_color_override("font_color", INK_MUTED)
	_footer_right_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_book_rect.add_child(_footer_right_lbl)

	# Top-right curled corner -> Next Neighbor
	_next_btn = _make_corner_flip_button("↪", "Next Neighbor (Right Arrow)")
	_next_btn.anchor_left = 0.922
	_next_btn.anchor_right = 0.976
	_next_btn.anchor_top = 0.016
	_next_btn.anchor_bottom = 0.094
	_next_btn.pressed.connect(func(): _step_neighbor(1))
	_book_rect.add_child(_next_btn)

	# Bottom-right curled corner -> Previous Neighbor
	_prev_btn = _make_corner_flip_button("↩", "Previous Neighbor (Left Arrow)")
	_prev_btn.anchor_left = 0.908
	_prev_btn.anchor_right = 0.974
	_prev_btn.anchor_top = 0.876
	_prev_btn.anchor_bottom = 0.960
	_prev_btn.pressed.connect(func(): _step_neighbor(-1))
	_book_rect.add_child(_prev_btn)

	# External rounded "✕" Close button outside top-right of the notebook (matches NotebookUI.gd)
	_close_btn = Button.new()
	_close_btn.text = "✕"
	_close_btn.tooltip_text = "Close Journal (J / Esc)"
	_close_btn.custom_minimum_size = Vector2(46, 46)
	_close_btn.size = Vector2(46, 46)
	_close_btn.z_index = 20
	_close_btn.focus_mode = Control.FOCUS_NONE
	_close_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var cs := UIStyle.create_flat_stylebox(Color(0.09, 0.075, 0.06, 0.94), 12, 0, 0)
	cs.border_color = Color(0.835, 0.624, 0.278, 0.85)
	cs.set_border_width_all(2)
	cs.shadow_color = Color(0.0, 0.0, 0.0, 0.55)
	cs.shadow_size = 10
	var ch: StyleBoxFlat = cs.duplicate()
	ch.bg_color = Color(0.24, 0.14, 0.12, 0.98)
	ch.border_color = Color(1.0, 0.875, 0.56, 1.0)
	_close_btn.add_theme_stylebox_override("normal", cs)
	_close_btn.add_theme_stylebox_override("hover", ch)
	_close_btn.add_theme_stylebox_override("pressed", cs)
	_close_btn.add_theme_font_override("font", _bold_font)
	_close_btn.add_theme_font_size_override("font_size", 22)
	_close_btn.add_theme_color_override("font_color", Color(1.0, 0.93, 0.80, 1.0))
	_close_btn.add_theme_color_override("font_hover_color", Color.WHITE)
	_close_btn.pressed.connect(close_journal)
	_root.add_child(_close_btn)

	# Sticky-Note Character Bookmark Tabs positioned along the right outer edge
	_tabs_scroll = ScrollContainer.new()
	_tabs_scroll.z_index = 10
	_tabs_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_root.add_child(_tabs_scroll)

	_tabs_col = VBoxContainer.new()
	_tabs_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_tabs_col.add_theme_constant_override("separation", 4)
	_tabs_scroll.add_child(_tabs_col)
