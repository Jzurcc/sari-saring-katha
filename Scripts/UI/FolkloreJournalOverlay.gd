class_name FolkloreJournalOverlay
extends CanvasLayer

## Karimlan Neighbor & Folklore Archive ([J]).
## Non-diegetic, UX-focused Compendium & Confidant Progression overlay designed around
## progressive disclosure, 5% title-safe margins, keyboard/controller navigation,
## long-form multi-paragraph rank reading, and adaptive Portrait / Landscape illustrations.

const FolkloreCatalogScript := preload("res://Scripts/Progression/FolkloreCatalog.gd")

const IC_AWARD: Texture2D = preload("res://Assets/ui/icons/award.png")
const IC_SPARKLES: Texture2D = preload("res://Assets/ui/icons/sparkles.png")
const IC_USERS: Texture2D = preload("res://Assets/ui/icons/users.png")
const IC_HEART: Texture2D = preload("res://Assets/ui/icons/heart-handshake.png")

# Palette: Cohesive Borderless Dark Warm Espresso + Antique Gold + Crisp Cream
const COL_BACKDROP := Color(0.048, 0.040, 0.035, 0.96)
const COL_SURFACE := Color(0.098, 0.084, 0.072, 0.96)
const COL_PANEL := Color(0.122, 0.105, 0.090, 0.96)
const COL_CARD := Color(0.145, 0.124, 0.106, 0.95)
const COL_CARD_HOVER := Color(0.185, 0.158, 0.132, 0.98)
const COL_CARD_ACTIVE := Color(0.225, 0.180, 0.122, 0.98)
const COL_GOLD := Color(0.86, 0.67, 0.32, 1.0)
const COL_GOLD_BRIGHT := Color(1.0, 0.89, 0.58, 1.0)
const COL_CREAM := Color(0.99, 0.95, 0.87, 1.0)
const COL_BODY := Color(0.94, 0.90, 0.83, 0.96)
const COL_MUTED := Color(0.76, 0.70, 0.62, 0.90)
const COL_LOCKED := Color(0.54, 0.49, 0.43, 0.78)
const COL_BORDER := Color(0.42, 0.31, 0.18, 0.55)
const COL_POSITIVE := Color(0.56, 0.90, 0.56, 1.0)
const COL_ACCENT_RED := Color(0.92, 0.48, 0.42, 1.0)
const COL_SILHOUETTE := Color(0.04, 0.035, 0.03, 0.96)

const ROMAN_NUMERALS: Array[String] = ["", "I", "II", "III", "IV", "V", "VI"]

const RANK_CHAPTER_HEADINGS: Dictionary = {
	1: "Regional Origin & First Sightings",
	2: "Traditional Beliefs, Offerings & Taboos",
	3: "Archival Depiction & Field Study",
	4: "Historical & Cultural Roots",
	5: "Rare Folklore Trivia & Local Accounts",
	6: "Confidant Epilogue & Personal Bond",
}

enum RosterFilter { ALL, MET, UNREAD }

var is_open: bool = false
var _prev_mouse_mode: Input.MouseMode = Input.MOUSE_MODE_CAPTURED

var _all_neighbors: Array[CustomerData] = []
var _filtered_neighbors: Array[CustomerData] = []
var _active_filter: RosterFilter = RosterFilter.ALL
var _selected_path: String = ""
var _selected_rank_tab: int = 1 # 1..6

var _reg_font: Font
var _bold_font: FontVariation

# Core layout nodes
var _root: Control
var _safe_margin: MarginContainer
var _progress_lbl: Label
var _progress_bar: ProgressBar
var _filter_buttons: Dictionary = {} # RosterFilter -> Button
var _roster_scroll: ScrollContainer
var _roster_vbox: VBoxContainer
var _roster_cards: Dictionary = {} # path -> Button

# Right workspace nodes
var _hero_panel: PanelContainer
var _hero_box: HBoxContainer
var _rank_track_box: HBoxContainer
var _rank_buttons: Array[Button] = []
var _reader_panel: PanelContainer
var _reader_holder: MarginContainer

# Lightbox overlay for inspecting Portrait or Landscape journal art at full size
var _lightbox_bg: ColorRect
var _lightbox_tex_rect: TextureRect
var _lightbox_title_lbl: Label
var _lightbox_caption_lbl: Label


func _ready() -> void:
	layer = 55
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("folklore_journal_overlay")

	_reg_font = UIStyle.FONT_INDER
	_bold_font = FontVariation.new()
	_bold_font.base_font = _reg_font
	_bold_font.variation_embolden = 0.55

	_build_ui()
	get_viewport().size_changed.connect(_sync_safe_margins)
	visible = false


func _process(_delta: float) -> void:
	if is_open and Input.get_mouse_mode() != Input.MOUSE_MODE_VISIBLE:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.is_echo()):
		return
	var ke := event as InputEventKey
	if is_open:
		if is_instance_valid(_lightbox_bg) and _lightbox_bg.visible:
			if ke.keycode == KEY_ESCAPE or ke.keycode == KEY_SPACE or ke.keycode == KEY_ENTER:
				get_viewport().set_input_as_handled()
				_close_lightbox()
			return

		match ke.keycode:
			KEY_ESCAPE, KEY_J:
				get_viewport().set_input_as_handled()
				close_journal()
			KEY_UP, KEY_W:
				get_viewport().set_input_as_handled()
				_step_neighbor(-1)
			KEY_DOWN, KEY_S:
				get_viewport().set_input_as_handled()
				_step_neighbor(1)
			KEY_LEFT, KEY_A, KEY_Q:
				get_viewport().set_input_as_handled()
				_select_rank_tab(clampi(_selected_rank_tab - 1, 1, 6))
			KEY_RIGHT, KEY_D, KEY_E:
				get_viewport().set_input_as_handled()
				_select_rank_tab(clampi(_selected_rank_tab + 1, 1, 6))
			KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6:
				get_viewport().set_input_as_handled()
				_select_rank_tab(ke.keycode - KEY_0)
		return

	# Open journal with J when no blocking overlay/dialogue is active
	if ke.keycode == KEY_J:
		if Dialogic.current_timeline != null:
			return
		if not get_tree().get_nodes_in_group("storefront_canvas_active").is_empty():
			return
		if not get_tree().get_nodes_in_group("minigame_overlay_active").is_empty():
			return
		for u_ov in get_tree().get_nodes_in_group("upgrade_tree_overlay"):
			if u_ov.get("is_open"):
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
	_close_lightbox()
	_sync_safe_margins()
	_collect_neighbors()

	if focus_character_path != "":
		_active_filter = RosterFilter.ALL
		_selected_path = focus_character_path
		_sync_default_rank_for_selected()
	elif _selected_path == "" and not _all_neighbors.is_empty():
		_selected_path = _all_neighbors[0].resource_path
		_sync_default_rank_for_selected()

	EventBus.request_sfx.emit("tab_switch")
	EventBus.journal_toggled.emit(true)
	_refresh_all()

	_root.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(_root, "modulate:a", 1.0, 0.16).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func close_journal() -> void:
	if not is_open:
		return
	_close_lightbox()
	is_open = false
	visible = false
	Input.mouse_mode = _prev_mouse_mode
	EventBus.request_sfx.emit("drop")
	EventBus.journal_toggled.emit(false)


# =============================================================================
# DATA & NAVIGATION
# =============================================================================

func _collect_neighbors() -> void:
	_all_neighbors.clear()
	if is_instance_valid(StoryManager):
		for c in StoryManager.available_characters:
			if c != null:
				_all_neighbors.append(c)


func _apply_roster_filter() -> void:
	_filtered_neighbors.clear()
	for c in _all_neighbors:
		var path := c.resource_path
		match _active_filter:
			RosterFilter.MET:
				if CharacterProgressionManager.has_encountered(path):
					_filtered_neighbors.append(c)
			RosterFilter.UNREAD:
				if CharacterProgressionManager.has_unread_journal(path):
					_filtered_neighbors.append(c)
			_:
				_filtered_neighbors.append(c)

	if not _filtered_neighbors.is_empty():
		var found := false
		for c in _filtered_neighbors:
			if c.resource_path == _selected_path:
				found = true
				break
		if not found:
			_selected_path = _filtered_neighbors[0].resource_path
			_sync_default_rank_for_selected()


func _get_selected_customer() -> CustomerData:
	for c in _all_neighbors:
		if c.resource_path == _selected_path:
			return c
	return _all_neighbors[0] if not _all_neighbors.is_empty() else null


func _sync_default_rank_for_selected() -> void:
	if _selected_path == "":
		_selected_rank_tab = 1
		return
	var r := CharacterProgressionManager.get_rep_rank(_selected_path)
	_selected_rank_tab = clampi(maxi(1, r), 1, 6)


func _step_neighbor(delta: int) -> void:
	if _filtered_neighbors.is_empty():
		return
	var cur_i := 0
	for i in range(_filtered_neighbors.size()):
		if _filtered_neighbors[i].resource_path == _selected_path:
			cur_i = i
			break
	var next_i := posmod(cur_i + delta, _filtered_neighbors.size())
	if next_i == cur_i and _filtered_neighbors.size() <= 1:
		return
	_select_neighbor(_filtered_neighbors[next_i].resource_path)


func _select_neighbor(path: String) -> void:
	if path == "" or path == _selected_path:
		return
	_selected_path = path
	_sync_default_rank_for_selected()
	EventBus.request_sfx.emit("tab_switch")
	_refresh_all()
	_animate_reader_fade()


func _select_rank_tab(rank_idx: int) -> void:
	var clamped := clampi(rank_idx, 1, 6)
	if clamped == _selected_rank_tab:
		return
	_selected_rank_tab = clamped
	EventBus.request_sfx.emit("interact")
	_rebuild_rank_track()
	_rebuild_reader()
	_animate_reader_fade()


func _set_filter(f: RosterFilter) -> void:
	if _active_filter == f:
		return
	_active_filter = f
	EventBus.request_sfx.emit("tab_switch")
	_refresh_all()


func _animate_reader_fade() -> void:
	if not is_instance_valid(_reader_holder):
		return
	_reader_holder.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(_reader_holder, "modulate:a", 1.0, 0.14).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


# =============================================================================
# SHELL CONSTRUCTION (5% Safe Zone, 3-Zone Responsive Layout)
# =============================================================================

func _sync_safe_margins() -> void:
	if not is_instance_valid(_safe_margin):
		return
	var vp := get_viewport().get_visible_rect().size
	var mx := maxi(32, int(roundf(vp.x * 0.045)))
	var my := maxi(24, int(roundf(vp.y * 0.042)))
	_safe_margin.add_theme_constant_override("margin_left", mx)
	_safe_margin.add_theme_constant_override("margin_right", mx)
	_safe_margin.add_theme_constant_override("margin_top", my)
	_safe_margin.add_theme_constant_override("margin_bottom", my)


func _build_ui() -> void:
	_root = Control.new()
	_root.name = "FolkloreArchiveRoot"
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_root)

	var backdrop := ColorRect.new()
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.color = COL_BACKDROP
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.add_child(backdrop)

	_safe_margin = MarginContainer.new()
	_safe_margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(_safe_margin)

	var outer_vbox := VBoxContainer.new()
	outer_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	outer_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	outer_vbox.add_theme_constant_override("separation", 14)
	_safe_margin.add_child(outer_vbox)

	# ─── 1. TOP HEADER BAR ───
	outer_vbox.add_child(_build_top_bar())

	# ─── 2. MAIN SPLIT: ROSTER RAIL (29%) + DOSSIER WORKSPACE (71%) ───
	var body_split := HBoxContainer.new()
	body_split.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body_split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body_split.add_theme_constant_override("separation", 16)
	outer_vbox.add_child(body_split)

	# Left Rail: Neighbor Roster
	var rail_panel := PanelContainer.new()
	rail_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rail_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	rail_panel.size_flags_stretch_ratio = 0.29
	rail_panel.add_theme_stylebox_override("panel", _make_box_style(COL_SURFACE, COL_BORDER, 14, 12, 12))
	body_split.add_child(rail_panel)

	_roster_scroll = ScrollContainer.new()
	_roster_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_roster_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_roster_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_style_scrollbar(_roster_scroll)
	rail_panel.add_child(_roster_scroll)

	_roster_vbox = VBoxContainer.new()
	_roster_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_roster_vbox.add_theme_constant_override("separation", 8)
	_roster_scroll.add_child(_roster_vbox)

	# Right Workspace: Hero Profile + 6-Rank Progression Track + Adaptive Lore Reader
	var right_col := VBoxContainer.new()
	right_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_col.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right_col.size_flags_stretch_ratio = 0.71
	right_col.add_theme_constant_override("separation", 12)
	body_split.add_child(right_col)

	_hero_panel = PanelContainer.new()
	_hero_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_hero_panel.add_theme_stylebox_override("panel", _make_box_style(COL_PANEL, COL_BORDER, 14, 18, 14))
	right_col.add_child(_hero_panel)

	_hero_box = HBoxContainer.new()
	_hero_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_hero_box.add_theme_constant_override("separation", 18)
	_hero_panel.add_child(_hero_box)

	_rank_track_box = HBoxContainer.new()
	_rank_track_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_rank_track_box.add_theme_constant_override("separation", 8)
	right_col.add_child(_rank_track_box)

	_reader_panel = PanelContainer.new()
	_reader_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_reader_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_reader_panel.add_theme_stylebox_override("panel", _make_box_style(COL_SURFACE, COL_BORDER, 14, 0, 0))
	right_col.add_child(_reader_panel)

	_reader_holder = MarginContainer.new()
	_reader_holder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_reader_holder.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_reader_holder.add_theme_constant_override("margin_left", 22)
	_reader_holder.add_theme_constant_override("margin_right", 22)
	_reader_holder.add_theme_constant_override("margin_top", 18)
	_reader_holder.add_theme_constant_override("margin_bottom", 18)
	_reader_panel.add_child(_reader_holder)

	# ─── 3. BOTTOM INPUT LEGEND BAR ───
	outer_vbox.add_child(_build_bottom_legend())

	# ─── 4. FULL-SCREEN ART LIGHTBOX (Portrait & Landscape Safe) ───
	_build_lightbox()


func _build_top_bar() -> Control:
	var bar := HBoxContainer.new()
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.alignment = BoxContainer.ALIGNMENT_CENTER
	bar.add_theme_constant_override("separation", 16)

	var icon_rect := TextureRect.new()
	icon_rect.texture = IC_AWARD
	icon_rect.custom_minimum_size = Vector2(32, 32)
	icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon_rect.modulate = COL_GOLD_BRIGHT
	icon_rect.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bar.add_child(icon_rect)

	var title_col := VBoxContainer.new()
	title_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_col.add_theme_constant_override("separation", 3)
	bar.add_child(title_col)

	var title_lbl := _make_label("KARIMLAN NEIGHBOR & FOLKLORE ARCHIVE", 25, COL_CREAM, true)
	title_col.add_child(title_lbl)

	var prog_row := HBoxContainer.new()
	prog_row.add_theme_constant_override("separation", 12)
	title_col.add_child(prog_row)

	_progress_lbl = _make_label("Neighbors Met: 0 / 0   •   Folklore Unlocked: 0 / 0", 15, COL_MUTED, false)
	prog_row.add_child(_progress_lbl)

	_progress_bar = ProgressBar.new()
	_progress_bar.custom_minimum_size = Vector2(96, 10)
	_progress_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_progress_bar.max_value = 100.0
	_progress_bar.show_percentage = false
	_progress_bar.add_theme_stylebox_override("background", UIStyle.create_flat_stylebox(Color(0.22, 0.18, 0.14, 0.85), 5, 0, 0))
	_progress_bar.add_theme_stylebox_override("fill", UIStyle.create_flat_stylebox(COL_GOLD, 5, 0, 0))
	prog_row.add_child(_progress_bar)

	# Filter buttons (48px minimum touch target height)
	var filter_row := HBoxContainer.new()
	filter_row.add_theme_constant_override("separation", 8)
	bar.add_child(filter_row)

	var filters: Array[Dictionary] = [
		{"id": RosterFilter.ALL, "label": "All"},
		{"id": RosterFilter.MET, "label": "Met"},
		{"id": RosterFilter.UNREAD, "label": "★ Unread"},
	]
	for f in filters:
		var fb := Button.new()
		fb.text = str(f["label"])
		fb.custom_minimum_size = Vector2(88, 48)
		fb.focus_mode = Control.FOCUS_NONE
		fb.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		fb.add_theme_font_override("font", _bold_font)
		fb.add_theme_font_size_override("font_size", 16)
		var fid: RosterFilter = f["id"]
		fb.pressed.connect(func(): _set_filter(fid))
		filter_row.add_child(fb)
		_filter_buttons[fid] = fb

	# 48x48 Close button
	var close_btn := Button.new()
	close_btn.text = "✕"
	close_btn.tooltip_text = "Close Archive (J / Esc)"
	close_btn.custom_minimum_size = Vector2(48, 48)
	close_btn.focus_mode = Control.FOCUS_NONE
	close_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	close_btn.add_theme_font_override("font", _bold_font)
	close_btn.add_theme_font_size_override("font_size", 20)
	_apply_button_theme(close_btn, false, true)
	close_btn.pressed.connect(close_journal)
	bar.add_child(close_btn)

	return bar


func _build_bottom_legend() -> Control:
	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 22)

	var hints: Array[Array] = [
		["↑ / ↓", "Select Neighbor"],
		["← / →", "Switch Rank Chapter"],
		["1 – 6", "Jump to Rank"],
		["J / Esc", "Close Archive"],
	]
	for h in hints:
		var item := HBoxContainer.new()
		item.add_theme_constant_override("separation", 7)
		var cap := PanelContainer.new()
		cap.add_theme_stylebox_override("panel", _make_box_style(Color(0.18, 0.15, 0.12, 0.95), COL_BORDER, 6, 8, 3))
		cap.add_child(_make_label(str(h[0]), 14, COL_GOLD_BRIGHT, true))
		item.add_child(cap)
		item.add_child(_make_label(str(h[1]), 15, COL_MUTED, false))
		row.add_child(item)

	return row


func _build_lightbox() -> void:
	_lightbox_bg = ColorRect.new()
	_lightbox_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_lightbox_bg.color = Color(0.02, 0.015, 0.012, 0.92)
	_lightbox_bg.visible = false
	_lightbox_bg.mouse_filter = Control.MOUSE_FILTER_STOP
	_lightbox_bg.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and ev.pressed and (ev as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
			_close_lightbox()
	)
	_root.add_child(_lightbox_bg)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 64)
	margin.add_theme_constant_override("margin_right", 64)
	margin.add_theme_constant_override("margin_top", 44)
	margin.add_theme_constant_override("margin_bottom", 44)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_lightbox_bg.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 12)
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(vbox)

	var hdr := HBoxContainer.new()
	hdr.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_child(hdr)

	_lightbox_title_lbl = _make_label("", 22, COL_GOLD_BRIGHT, true)
	_lightbox_title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hdr.add_child(_lightbox_title_lbl)

	var close_lb := Button.new()
	close_lb.text = "✕ Close"
	close_lb.custom_minimum_size = Vector2(96, 48)
	close_lb.focus_mode = Control.FOCUS_NONE
	close_lb.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	close_lb.add_theme_font_override("font", _bold_font)
	close_lb.add_theme_font_size_override("font_size", 16)
	_apply_button_theme(close_lb, false, true)
	close_lb.pressed.connect(_close_lightbox)
	hdr.add_child(close_lb)

	_lightbox_tex_rect = TextureRect.new()
	_lightbox_tex_rect.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_lightbox_tex_rect.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_lightbox_tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_lightbox_tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_lightbox_tex_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(_lightbox_tex_rect)

	_lightbox_caption_lbl = _make_label("", 16, COL_CREAM, false)
	_lightbox_caption_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_lightbox_caption_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(_lightbox_caption_lbl)


func _open_lightbox(tex: Texture2D, title: String, caption: String) -> void:
	if tex == null or not is_instance_valid(_lightbox_bg):
		return
	_lightbox_tex_rect.texture = tex
	_lightbox_title_lbl.text = title
	_lightbox_caption_lbl.text = caption
	_lightbox_bg.visible = true
	EventBus.request_sfx.emit("interact")


func _close_lightbox() -> void:
	if is_instance_valid(_lightbox_bg) and _lightbox_bg.visible:
		_lightbox_bg.visible = false
		EventBus.request_sfx.emit("drop")


# =============================================================================
# REFRESH & RENDERING
# =============================================================================

func _refresh_all() -> void:
	_apply_roster_filter()
	var selected := _get_selected_customer()
	if selected != null and CharacterProgressionManager.has_unread_journal(selected.resource_path):
		CharacterProgressionManager.mark_journal_read(selected.resource_path)

	_refresh_header_stats()
	_refresh_filter_buttons()
	_rebuild_roster()
	_rebuild_hero_banner()
	_rebuild_rank_track()
	_rebuild_reader()


func _refresh_header_stats() -> void:
	var met_count := 0
	var unlocked_ranks := 0
	var total_neighbors := _all_neighbors.size()
	for c in _all_neighbors:
		if CharacterProgressionManager.has_encountered(c.resource_path):
			met_count += 1
		unlocked_ranks += CharacterProgressionManager.get_rep_rank(c.resource_path)
	var max_ranks := maxi(1, total_neighbors * 6)
	if is_instance_valid(_progress_lbl):
		_progress_lbl.text = "Neighbors Met: %d / %d   •   Folklore Ranks Unlocked: %d / %d" % [
			met_count, total_neighbors, unlocked_ranks, total_neighbors * 6
		]
	if is_instance_valid(_progress_bar):
		_progress_bar.value = (float(unlocked_ranks) / float(max_ranks)) * 100.0


func _refresh_filter_buttons() -> void:
	var unread_total := 0
	var met_total := 0
	for c in _all_neighbors:
		if CharacterProgressionManager.has_encountered(c.resource_path):
			met_total += 1
		if CharacterProgressionManager.has_unread_journal(c.resource_path):
			unread_total += 1

	for fid in _filter_buttons.keys():
		var btn: Button = _filter_buttons[fid]
		match fid:
			RosterFilter.ALL:
				btn.text = "All (%d)" % _all_neighbors.size()
			RosterFilter.MET:
				btn.text = "Met (%d)" % met_total
			RosterFilter.UNREAD:
				btn.text = "★ New (%d)" % unread_total
		_apply_button_theme(btn, _active_filter == fid, false)


func _rebuild_roster() -> void:
	for ch in _roster_vbox.get_children():
		ch.queue_free()
	_roster_cards.clear()

	if _filtered_neighbors.is_empty():
		var empty_lbl := _make_label("No neighbors match this filter yet.", 16, COL_MUTED, false)
		empty_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_roster_vbox.add_child(empty_lbl)
		return

	for c in _filtered_neighbors:
		var path := c.resource_path
		var met := CharacterProgressionManager.has_encountered(path)
		var rank := CharacterProgressionManager.get_rep_rank(path)
		var unread := CharacterProgressionManager.has_unread_journal(path)
		var entry: Dictionary = FolkloreCatalogScript.get_entry(c.get_clean_id())
		var selected := (path == _selected_path)

		var card_btn := Button.new()
		card_btn.custom_minimum_size = Vector2(0, 68)
		card_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card_btn.focus_mode = Control.FOCUS_NONE
		card_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		_apply_button_theme(card_btn, selected, false)
		card_btn.pressed.connect(func(): _select_neighbor(path))

		var row := HBoxContainer.new()
		row.set_anchors_preset(Control.PRESET_FULL_RECT)
		row.offset_left = 10
		row.offset_right = -10
		row.offset_top = 6
		row.offset_bottom = -6
		row.add_theme_constant_override("separation", 12)
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card_btn.add_child(row)

		# Avatar badge
		var avatar_tex := _resolve_portrait_texture(c, entry)
		var av := _build_avatar_frame(avatar_tex, Vector2(48, 48), not met, rank >= 6)
		av.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(av)

		# Name + Creature subtitle
		var name_col := VBoxContainer.new()
		name_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_col.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		name_col.add_theme_constant_override("separation", 2)
		name_col.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(name_col)

		var disp_name := (c.character_name if c.character_name != "" else c.get_clean_id().capitalize()) if met else "Unmet Neighbor"
		var nl := _make_label(disp_name, 17, COL_GOLD_BRIGHT if selected else (COL_CREAM if met else COL_LOCKED), true)
		nl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		name_col.add_child(nl)

		var sub_txt := str(entry.get("creature", "Barangay Regular")) if met else "Serve at store to meet"
		var sl := _make_label(sub_txt, 14, COL_MUTED if met else COL_LOCKED, false)
		sl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		name_col.add_child(sl)

		# Right side: Unread badge + 6-diamond rank pips (color + shape + text)
		var right_meta := VBoxContainer.new()
		right_meta.alignment = BoxContainer.ALIGNMENT_CENTER
		right_meta.add_theme_constant_override("separation", 3)
		right_meta.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(right_meta)

		if unread:
			var new_lbl := _make_label("★ NEW", 14, COL_GOLD_BRIGHT, true)
			new_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			right_meta.add_child(new_lbl)
		else:
			var r_lbl := _make_label("R%d / 6" % rank if met else "Locked", 14, COL_GOLD if rank >= 6 else COL_MUTED, rank >= 6)
			r_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			right_meta.add_child(r_lbl)

		var pips := ""
		for ri in range(1, 7):
			pips += "◆" if rank >= ri else "◇"
		var pip_lbl := _make_label(pips, 14, COL_GOLD_BRIGHT if rank > 0 else COL_LOCKED, false)
		pip_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		right_meta.add_child(pip_lbl)

		_roster_vbox.add_child(card_btn)
		_roster_cards[path] = card_btn


func _rebuild_hero_banner() -> void:
	for ch in _hero_box.get_children():
		ch.queue_free()

	var c := _get_selected_customer()
	if c == null:
		return

	var cpath := c.resource_path
	var met := CharacterProgressionManager.has_encountered(cpath)
	var rank := CharacterProgressionManager.get_rep_rank(cpath)
	var prog := CharacterProgressionManager.get_rep_rank_progress(cpath)
	var entry: Dictionary = FolkloreCatalogScript.get_entry(c.get_clean_id())

	# 1) Left Portrait Frame (92x92)
	var portrait_tex := _resolve_portrait_texture(c, entry)
	var p_frame := _build_avatar_frame(portrait_tex, Vector2(92, 92), not met, rank >= 6)
	p_frame.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_hero_box.add_child(p_frame)

	# 2) Center Identity & Reputation Bar
	var mid_col := VBoxContainer.new()
	mid_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mid_col.size_flags_stretch_ratio = 0.48
	mid_col.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	mid_col.add_theme_constant_override("separation", 6)
	_hero_box.add_child(mid_col)

	var title_row := HBoxContainer.new()
	title_row.add_theme_constant_override("separation", 10)
	mid_col.add_child(title_row)

	var disp_name := (c.character_name if c.character_name != "" else c.get_clean_id().capitalize()) if met else "??? (Unmet Neighbor)"
	title_row.add_child(_make_label(disp_name, 26, COL_CREAM, true))

	if rank >= 6:
		var seal_pill := PanelContainer.new()
		seal_pill.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		seal_pill.add_theme_stylebox_override("panel", _make_box_style(Color(0.32, 0.22, 0.08, 0.96), COL_GOLD_BRIGHT, 8, 10, 3))
		seal_pill.add_child(_make_label("★ CONFIDANT", 14, COL_GOLD_BRIGHT, true))
		title_row.add_child(seal_pill)

	var folklore_line := "%s   •   %s" % [
		str(entry.get("creature", "Neighbor")) if met else "Unknown Folklore Origin",
		str(entry.get("region", "Karimlan")) if met else "Meet at store to identify"
	]
	mid_col.add_child(_make_label(folklore_line, 16, COL_GOLD if met else COL_LOCKED, false))

	# Reputation progress bar + exact numbers
	var rep_hdr := HBoxContainer.new()
	rep_hdr.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mid_col.add_child(rep_hdr)

	var rank_title := CharacterProgressionManager.get_rep_rank_title(rank)
	var rank_txt := "Rank %d / 6 — %s" % [rank, rank_title]
	var rl := _make_label(rank_txt, 16, COL_CREAM, true)
	rl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rep_hdr.add_child(rl)

	var rep_status := "MAX RANK" if bool(prog["is_max"]) else ("%d / %d Rep" % [int(prog["current"]), int(prog["needed"])])
	if not met:
		rep_status = "0 Rep"
	rep_hdr.add_child(_make_label(rep_status, 15, COL_GOLD_BRIGHT if bool(prog["is_max"]) else COL_MUTED, false))

	var rep_bar := ProgressBar.new()
	rep_bar.custom_minimum_size = Vector2(0, 12)
	rep_bar.max_value = 100.0
	rep_bar.value = float(prog["ratio"]) * 100.0 if met else 0.0
	rep_bar.show_percentage = false
	rep_bar.add_theme_stylebox_override("background", UIStyle.create_flat_stylebox(Color(0.06, 0.05, 0.04, 0.92), 6, 0, 0))
	rep_bar.add_theme_stylebox_override("fill", UIStyle.create_flat_stylebox(COL_GOLD, 6, 0, 0))
	mid_col.add_child(rep_bar)

	# Subtle divider
	var vsep := VSeparator.new()
	var vs_st := StyleBoxFlat.new()
	vs_st.bg_color = COL_BORDER
	vs_st.content_margin_left = 1
	vs_st.content_margin_right = 1
	vsep.add_theme_stylebox_override("separator", vs_st)
	_hero_box.add_child(vsep)

	# 3) Right Gameplay Dossier (Favorites + Story Arcs + Active Perks)
	var right_meta := VBoxContainer.new()
	right_meta.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_meta.size_flags_stretch_ratio = 0.52
	right_meta.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	right_meta.add_theme_constant_override("separation", 7)
	_hero_box.add_child(right_meta)

	# Favorites row
	var fav_row := HFlowContainer.new()
	fav_row.add_theme_constant_override("h_separation", 6)
	fav_row.add_theme_constant_override("v_separation", 6)
	right_meta.add_child(fav_row)

	var fav_lbl := _make_label("Favorites:", 15, COL_MUTED, true)
	fav_row.add_child(fav_lbl)

	var favs: Array[String] = c.get_favorite_categories()
	if favs.is_empty():
		fav_row.add_child(_make_badge("None", COL_CARD, COL_BORDER, COL_MUTED))
	else:
		for cat in favs:
			if CharacterProgressionManager.is_favorite_discovered(cpath, cat):
				fav_row.add_child(_make_badge("★ " + StoryManager.get_category_display_name(cat), Color(0.24, 0.18, 0.09, 0.95), COL_GOLD, COL_GOLD_BRIGHT))
			else:
				fav_row.add_child(_make_badge("? Undiscovered", COL_CARD, COL_BORDER, COL_LOCKED))

	# Perks summary row
	var perks_row := HFlowContainer.new()
	perks_row.add_theme_constant_override("h_separation", 6)
	perks_row.add_theme_constant_override("v_separation", 6)
	right_meta.add_child(perks_row)

	perks_row.add_child(_make_label("Perks:", 15, COL_MUTED, true))
	var perk_defs: Array[Dictionary] = [
		{"req": 3, "short": "+1 Fav Price Tol."},
		{"req": 5, "short": "+10% Cash Tip"},
		{"req": 6, "short": "+1 Global Tol."},
	]
	for p in perk_defs:
		var req := int(p["req"])
		if rank >= req:
			perks_row.add_child(_make_badge("✓ " + str(p["short"]), Color(0.12, 0.24, 0.14, 0.94), COL_POSITIVE, COL_POSITIVE))
		else:
			perks_row.add_child(_make_badge("🔒 R%d %s" % [req, str(p["short"])], COL_CARD, COL_BORDER, COL_LOCKED))

	# Story Arcs tracker
	var cur_ch := CharacterProgressionManager.get_chapter(cpath)
	var arc_str_parts: Array[String] = []
	for arc_i in range(3):
		var c1 := arc_i * 2 + 1
		var c2 := arc_i * 2 + 2
		arc_str_parts.append("Arc %d %s%s" % [
			arc_i + 1,
			"●" if cur_ch >= c1 else "○",
			"●" if cur_ch >= c2 else "○"
		])
	right_meta.add_child(_make_label("Story Chapters:   " + "    •    ".join(arc_str_parts), 15, COL_BODY if met else COL_LOCKED, false))


func _rebuild_rank_track() -> void:
	for ch in _rank_track_box.get_children():
		ch.queue_free()
	_rank_buttons.clear()

	var c := _get_selected_customer()
	var rank := CharacterProgressionManager.get_rep_rank(c.resource_path) if c != null else 0

	for r in range(1, 7):
		var unlocked := rank >= r
		var active := (_selected_rank_tab == r)
		var has_perk := (r == 3 or r == 5 or r == 6)

		var btn := Button.new()
		btn.custom_minimum_size = Vector2(0, 56)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.focus_mode = Control.FOCUS_NONE
		btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		_apply_rank_tab_theme(btn, active, unlocked)
		var r_idx := r
		btn.pressed.connect(func(): _select_rank_tab(r_idx))

		var vb := VBoxContainer.new()
		vb.set_anchors_preset(Control.PRESET_FULL_RECT)
		vb.alignment = BoxContainer.ALIGNMENT_CENTER
		vb.add_theme_constant_override("separation", 1)
		vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
		btn.add_child(vb)

		var status_glyph := "✓" if unlocked else "🔒"
		var perk_tag := " ★" if has_perk else ""
		var top_txt := "%s  Rank %s%s" % [status_glyph, ROMAN_NUMERALS[r], perk_tag]
		var top_col := COL_GOLD_BRIGHT if active else (COL_CREAM if unlocked else COL_LOCKED)
		var l1 := _make_label(top_txt, 15, top_col, true)
		l1.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vb.add_child(l1)

		var sub_txt := CharacterProgressionManager.get_rep_rank_title(r) if unlocked else ("%d Rep" % CharacterProgressionManager.REP_RANK_THRESHOLDS[r])
		var l2 := _make_label(sub_txt, 14, COL_MUTED if unlocked else COL_LOCKED, false)
		l2.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vb.add_child(l2)

		_rank_track_box.add_child(btn)
		_rank_buttons.append(btn)


# =============================================================================
# ADAPTIVE LONG-FORM FOLKLORE READER (Supports BOTH Portrait & Landscape Art!)
# =============================================================================

func _rebuild_reader() -> void:
	for ch in _reader_holder.get_children():
		ch.queue_free()

	var c := _get_selected_customer()
	if c == null:
		return

	var cpath := c.resource_path
	var rank := CharacterProgressionManager.get_rep_rank(cpath)
	var total_rep := CharacterProgressionManager.get_rep(cpath)
	var entry: Dictionary = FolkloreCatalogScript.get_entry(c.get_clean_id())
	var r := _selected_rank_tab
	var unlocked := rank >= r

	if not unlocked:
		_reader_holder.add_child(_build_locked_rank_view(r, total_rep))
		return

	var rank_data := _resolve_rank_content(entry, r)
	var has_media: bool = bool(rank_data["has_media"])
	var orientation: String = str(rank_data["orientation"])

	# PORTRAIT ILLUSTRATION -> Side-by-Side Editorial Split (Left Vertical Art Plate + Right Scrolling Essay)
	if has_media and orientation == "portrait":
		var split := HBoxContainer.new()
		split.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		split.size_flags_vertical = Control.SIZE_EXPAND_FILL
		split.add_theme_constant_override("separation", 22)
		_reader_holder.add_child(split)

		var art_plate := _build_media_plate(rank_data, true)
		art_plate.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		art_plate.size_flags_vertical = Control.SIZE_EXPAND_FILL
		art_plate.size_flags_stretch_ratio = 0.36
		split.add_child(art_plate)

		var text_scroll := ScrollContainer.new()
		text_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		text_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
		text_scroll.size_flags_stretch_ratio = 0.64
		text_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		_style_scrollbar(text_scroll)
		split.add_child(text_scroll)

		var essay_col := _build_essay_column(r, rank_data, true)
		text_scroll.add_child(essay_col)
		return

	# LANDSCAPE ILLUSTRATION OR TEXT-ONLY -> Smooth Single-Column Editorial Scroll
	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_style_scrollbar(scroll)
	_reader_holder.add_child(scroll)

	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 16)
	scroll.add_child(col)

	col.add_child(_build_rank_heading_block(r, rank_data))

	if has_media:
		var wide_plate := _build_media_plate(rank_data, false)
		col.add_child(wide_plate)

	col.add_child(_build_body_paragraphs(rank_data, has_media))


func _resolve_rank_content(entry: Dictionary, r: int) -> Dictionary:
	var heading := str(RANK_CHAPTER_HEADINGS.get(r, "Folklore Notes"))
	var body := ""
	var media_path := str(entry.get("rank%d_depiction_path" % r, ""))
	var media_title := str(entry.get("rank%d_depiction_title" % r, ""))
	var media_caption := str(entry.get("rank%d_depiction_caption" % r, ""))
	var media_source := str(entry.get("rank%d_depiction_source" % r, ""))
	var explicit_orient := str(entry.get("rank%d_depiction_orientation" % r, "")).to_lower()

	match r:
		1:
			body = str(entry.get("rank1_origin", ""))
		2:
			body = str(entry.get("rank2_taboos", ""))
		3:
			if media_title != "":
				heading = media_title
			body = str(entry.get("rank3_body", ""))
			if body == "":
				body = media_caption
		4:
			body = str(entry.get("rank4_history", ""))
		5:
			body = str(entry.get("rank5_trivia", ""))
		6:
			body = str(entry.get("rank6_epilogue", ""))

	var tex: Texture2D = null
	if media_path != "" and ResourceLoader.exists(media_path):
		tex = load(media_path) as Texture2D

	var has_media := (r == 3) or (tex != null) or (explicit_orient != "")
	var orientation := "landscape"
	if tex != null and tex.get_height() > 0:
		var aspect := float(tex.get_width()) / float(tex.get_height())
		orientation = "portrait" if aspect < 0.95 else "landscape"
	elif explicit_orient == "portrait" or explicit_orient == "landscape":
		orientation = explicit_orient

	return {
		"heading": heading,
		"body": body,
		"has_media": has_media,
		"tex": tex,
		"orientation": orientation,
		"media_title": media_title if media_title != "" else heading,
		"media_caption": media_caption,
		"media_source": media_source,
	}


func _build_rank_heading_block(r: int, rank_data: Dictionary) -> Control:
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 6)

	var top_row := HBoxContainer.new()
	top_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_row.add_theme_constant_override("separation", 10)
	v.add_child(top_row)

	var pill_txt := "RANK %s  •  %s" % [ROMAN_NUMERALS[r], CharacterProgressionManager.get_rep_rank_title(r).to_upper()]
	top_row.add_child(_make_badge(pill_txt, Color(0.24, 0.18, 0.09, 0.96), COL_GOLD, COL_GOLD_BRIGHT))

	if r == 3 or r == 5 or r == 6:
		var perk_txt := "★ Perk Active: " + CharacterProgressionManager.get_rep_rank_perk_summary(r)
		top_row.add_child(_make_badge(perk_txt, Color(0.12, 0.24, 0.14, 0.94), COL_POSITIVE, COL_POSITIVE))

	var h_lbl := _make_label(str(rank_data["heading"]), 24, COL_CREAM, true)
	h_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(h_lbl)

	var rule := ColorRect.new()
	rule.custom_minimum_size = Vector2(0, 1)
	rule.color = COL_BORDER
	v.add_child(rule)

	return v


func _build_essay_column(r: int, rank_data: Dictionary, include_caption: bool) -> VBoxContainer:
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 14)
	col.add_child(_build_rank_heading_block(r, rank_data))
	col.add_child(_build_body_paragraphs(rank_data, include_caption))
	return col


func _build_body_paragraphs(rank_data: Dictionary, show_caption_callout: bool) -> Control:
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 14)

	var body_txt := str(rank_data["body"]).strip_edges()
	if body_txt != "":
		var body_lbl := _make_label(body_txt, 18, COL_BODY, false)
		body_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		body_lbl.add_theme_constant_override("line_spacing", 6)
		v.add_child(body_lbl)

	var cap_txt := str(rank_data["media_caption"]).strip_edges()
	var src_txt := str(rank_data["media_source"]).strip_edges()
	if show_caption_callout and (cap_txt != "" or src_txt != ""):
		var callout := PanelContainer.new()
		callout.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		callout.add_theme_stylebox_override("panel", _make_box_style(COL_PANEL, COL_BORDER, 10, 14, 12))
		var cv := VBoxContainer.new()
		cv.add_theme_constant_override("separation", 6)
		callout.add_child(cv)
		if cap_txt != "":
			var cl := _make_label(cap_txt, 16, COL_CREAM, false)
			cl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			cl.add_theme_constant_override("line_spacing", 4)
			cv.add_child(cl)
		if src_txt != "":
			var sl := _make_label(src_txt, 14, COL_MUTED, false)
			sl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			cv.add_child(sl)
		v.add_child(callout)

	return v


func _build_media_plate(rank_data: Dictionary, is_portrait: bool) -> Control:
	var frame := PanelContainer.new()
	frame.add_theme_stylebox_override("panel", _make_box_style(Color(0.07, 0.06, 0.05, 0.96), COL_GOLD, 12, 12, 12))

	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 8)
	frame.add_child(vbox)

	var tex: Texture2D = rank_data["tex"]
	var title_str := str(rank_data["media_title"])
	var cap_str := str(rank_data["media_caption"])

	if tex != null:
		var art_holder := Control.new()
		art_holder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if is_portrait:
			art_holder.size_flags_vertical = Control.SIZE_EXPAND_FILL
		else:
			# Responsive landscape viewport height (~28% of screen height)
			var vp_h := get_viewport().get_visible_rect().size.y
			art_holder.custom_minimum_size = Vector2(0, clampf(vp_h * 0.28, 160.0, 320.0))
		vbox.add_child(art_holder)

		var img := TextureRect.new()
		img.set_anchors_preset(Control.PRESET_FULL_RECT)
		img.texture = tex
		img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		art_holder.add_child(img)

		var zoom_btn := Button.new()
		zoom_btn.text = "🔍 Inspect"
		zoom_btn.custom_minimum_size = Vector2(96, 48)
		zoom_btn.anchor_left = 1.0
		zoom_btn.anchor_right = 1.0
		zoom_btn.anchor_top = 1.0
		zoom_btn.anchor_bottom = 1.0
		zoom_btn.offset_left = -104
		zoom_btn.offset_top = -52
		zoom_btn.offset_right = -4
		zoom_btn.offset_bottom = -4
		zoom_btn.focus_mode = Control.FOCUS_NONE
		zoom_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		zoom_btn.add_theme_font_override("font", _bold_font)
		zoom_btn.add_theme_font_size_override("font_size", 15)
		_apply_button_theme(zoom_btn, false, false)
		zoom_btn.pressed.connect(func(): _open_lightbox(tex, title_str, cap_str))
		art_holder.add_child(zoom_btn)
	else:
		# Styled Portrait or Landscape placeholder plate when artwork file isn't added yet
		var ph := PanelContainer.new()
		ph.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if is_portrait:
			ph.size_flags_vertical = Control.SIZE_EXPAND_FILL
		else:
			var vp_h := get_viewport().get_visible_rect().size.y
			ph.custom_minimum_size = Vector2(0, clampf(vp_h * 0.24, 140.0, 260.0))
		ph.add_theme_stylebox_override("panel", _make_box_style(Color(0.11, 0.095, 0.08, 0.90), COL_BORDER, 8, 16, 16))
		vbox.add_child(ph)

		var pv := VBoxContainer.new()
		pv.alignment = BoxContainer.ALIGNMENT_CENTER
		pv.add_theme_constant_override("separation", 6)
		ph.add_child(pv)

		var orient_tag := "PORTRAIT ARCHIVAL PLATE" if is_portrait else "LANDSCAPE ARCHIVAL PLATE"
		var l_tag := _make_label("✦  " + orient_tag + "  ✦", 15, COL_GOLD, true)
		l_tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		pv.add_child(l_tag)

		var l_sub := _make_label(title_str + "\n(Illustration Placeholder)", 16, COL_MUTED, false)
		l_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l_sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		pv.add_child(l_sub)

	var orient_badge := _make_label(
		"Portrait Format" if is_portrait else "Landscape Format",
		14,
		COL_MUTED,
		false
	)
	orient_badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	vbox.add_child(orient_badge)

	return frame


func _build_locked_rank_view(r: int, current_rep: int) -> Control:
	var center := CenterContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL

	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", _make_box_style(COL_PANEL, COL_BORDER, 14, 28, 24))
	center.add_child(card)

	var v := VBoxContainer.new()
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 10)
	card.add_child(v)

	var lock_hdr := _make_label(
		"🔒  Rank %s — %s (Locked)" % [ROMAN_NUMERALS[r], CharacterProgressionManager.get_rep_rank_title(r)],
		22,
		COL_GOLD_BRIGHT,
		true
	)
	lock_hdr.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(lock_hdr)

	var chapter_lbl := _make_label("Chapter Topic: " + str(RANK_CHAPTER_HEADINGS.get(r, "Folklore Notes")), 17, COL_CREAM, false)
	chapter_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(chapter_lbl)

	var req_rep := CharacterProgressionManager.REP_RANK_THRESHOLDS[r]
	var rem_rep := maxi(0, req_rep - current_rep)
	var req_str := "Meet this neighbor at the store to unlock Rank I." if r <= 1 else (
		"Requires %d Total Reputation (%d more Rep needed)." % [req_rep, rem_rep]
	)
	var req_lbl := _make_label(req_str, 16, COL_MUTED, false)
	req_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(req_lbl)

	var perk_txt := CharacterProgressionManager.get_rep_rank_perk_summary(r)
	var perk_badge := _make_badge("Reward: " + perk_txt, Color(0.18, 0.14, 0.09, 0.96), COL_GOLD, COL_GOLD_BRIGHT)
	perk_badge.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(perk_badge)

	return center


# =============================================================================
# VISUAL & STYLE HELPERS
# =============================================================================

func _resolve_portrait_texture(c: CustomerData, entry: Dictionary) -> Texture2D:
	var p_path := str(entry.get("portrait", ""))
	if p_path != "" and ResourceLoader.exists(p_path):
		return load(p_path) as Texture2D
	if c != null and c.sprite_texture != null:
		return c.sprite_texture
	return null


func _build_avatar_frame(tex: Texture2D, sz: Vector2, is_locked: bool, is_confidant: bool) -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = sz
	var border_col := COL_GOLD_BRIGHT if is_confidant else (COL_LOCKED if is_locked else COL_GOLD)
	panel.add_theme_stylebox_override("panel", _make_box_style(Color(0.08, 0.065, 0.055, 0.98), border_col, 12, 4, 4))

	var holder := Control.new()
	holder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	holder.size_flags_vertical = Control.SIZE_EXPAND_FILL
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(holder)

	if tex != null:
		var tr := TextureRect.new()
		tr.set_anchors_preset(Control.PRESET_FULL_RECT)
		tr.texture = tex
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tr.modulate = COL_SILHOUETTE if is_locked else Color.WHITE
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		holder.add_child(tr)

	if is_locked:
		var q := _make_label("?", 24, COL_GOLD_BRIGHT, true)
		q.set_anchors_preset(Control.PRESET_FULL_RECT)
		q.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		q.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		holder.add_child(q)

	return panel


func _make_label(txt: String, fsize: int, col: Color, bold: bool) -> Label:
	var lbl := Label.new()
	lbl.text = txt
	lbl.add_theme_font_override("font", _bold_font if bold else _reg_font)
	lbl.add_theme_font_size_override("font_size", maxi(14, fsize))
	lbl.add_theme_color_override("font_color", col)
	lbl.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.65))
	lbl.add_theme_constant_override("shadow_offset_x", 1)
	lbl.add_theme_constant_override("shadow_offset_y", 1)
	return lbl


func _make_badge(txt: String, bg: Color, border: Color, fg: Color) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", _make_box_style(bg, border, 8, 10, 4))
	p.add_child(_make_label(txt, 14, fg, true))
	return p


func _make_box_style(bg: Color, border: Color, radius: int, pad_x: int, pad_y: int) -> StyleBoxFlat:
	var st := StyleBoxFlat.new()
	st.bg_color = bg
	st.border_color = border
	st.set_border_width_all(1)
	st.set_corner_radius_all(radius)
	st.content_margin_left = pad_x
	st.content_margin_right = pad_x
	st.content_margin_top = pad_y
	st.content_margin_bottom = pad_y
	return st


func _apply_button_theme(btn: Button, active: bool, is_danger: bool) -> void:
	var bg := COL_CARD_ACTIVE if active else COL_CARD
	var border := COL_GOLD_BRIGHT if active else COL_BORDER
	var st := _make_box_style(bg, border, 10, 12, 8)
	st.set_border_width_all(2 if active else 1)

	var hov := st.duplicate() as StyleBoxFlat
	hov.bg_color = Color(0.28, 0.14, 0.13, 0.98) if is_danger else COL_CARD_HOVER
	hov.border_color = COL_ACCENT_RED if is_danger else COL_GOLD_BRIGHT

	var prs := st.duplicate() as StyleBoxFlat
	prs.bg_color = bg.darkened(0.15)

	btn.add_theme_stylebox_override("normal", st)
	btn.add_theme_stylebox_override("hover", hov)
	btn.add_theme_stylebox_override("pressed", prs)
	btn.add_theme_color_override("font_color", COL_GOLD_BRIGHT if active else COL_CREAM)
	btn.add_theme_color_override("font_hover_color", Color.WHITE)


func _apply_rank_tab_theme(btn: Button, active: bool, unlocked: bool) -> void:
	var bg := COL_CARD_ACTIVE if active else (COL_CARD if unlocked else Color(0.09, 0.078, 0.068, 0.88))
	var border := COL_GOLD_BRIGHT if active else (COL_GOLD if unlocked else COL_BORDER)
	var st := _make_box_style(bg, border, 10, 8, 6)
	st.set_border_width_all(2 if active else 1)

	var hov := st.duplicate() as StyleBoxFlat
	hov.bg_color = COL_CARD_HOVER if unlocked else Color(0.13, 0.11, 0.095, 0.94)
	hov.border_color = COL_GOLD_BRIGHT if unlocked else COL_MUTED

	btn.add_theme_stylebox_override("normal", st)
	btn.add_theme_stylebox_override("hover", hov)
	btn.add_theme_stylebox_override("pressed", st)


func _style_scrollbar(sc: ScrollContainer) -> void:
	var vbar := sc.get_v_scroll_bar()
	if not is_instance_valid(vbar):
		return
	vbar.custom_minimum_size.x = 8
	var grab := UIStyle.create_flat_stylebox(Color(0.86, 0.67, 0.32, 0.55), 4, 0, 0)
	var grab_h := UIStyle.create_flat_stylebox(Color(1.0, 0.89, 0.58, 0.85), 4, 0, 0)
	var trk := UIStyle.create_flat_stylebox(Color(0.06, 0.05, 0.04, 0.50), 4, 0, 0)
	vbar.add_theme_stylebox_override("grabber", grab)
	vbar.add_theme_stylebox_override("grabber_highlight", grab_h)
	vbar.add_theme_stylebox_override("grabber_pressed", grab_h)
	vbar.add_theme_stylebox_override("scroll", trk)
