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
const IC_CHECKBOX_ON: Texture2D = preload("res://Assets/ui/mingcute_checkbox-fill.png")
const IC_CHECKBOX_OFF: Texture2D = preload("res://Assets/ui/carbon_checkbox.png")

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
	1: "Identity & Regional Origins",
	2: "Traditional Beliefs, Customs & Taboos",
	3: "Appearance, Traits & Encounters",
	4: "Etymology & Historical Roots",
	5: "Lesser-Known Variations & Rare Trivia",
	6: "Living Tradition & Modern Legacy",
}

var is_open: bool = false
var _prev_mouse_mode: Input.MouseMode = Input.MOUSE_MODE_CAPTURED

var _all_neighbors: Array[CustomerData] = []
var _selected_path: String = ""
var _selected_rank_tab: int = 1 # 1..6

var _reg_font: Font
var _bold_font: FontVariation

# Core layout nodes
var _root: Control
var _safe_margin: MarginContainer
var _rail_panel: PanelContainer
var _progress_lbl: Label
var _progress_bar: ProgressBar
var _roster_scroll: ScrollContainer
var _roster_vbox: VBoxContainer
var _roster_cards: Dictionary = {} # path -> Button

# Right workspace nodes
var _hero_panel: PanelContainer
var _hero_box: HBoxContainer
var _rank_track_box: VBoxContainer
var _rank_buttons: Array[Button] = []
var _reader_panel: PanelContainer
var _reader_holder: MarginContainer

# Lightbox overlay for inspecting Portrait or Landscape journal art at full size
var _lightbox_bg: ColorRect
var _lightbox_tex_rect: TextureRect

# External link confirmation modal
var _link_confirm_bg: ColorRect
var _link_confirm_url_lbl: Label
var _pending_external_url: String = ""


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
	var is_journal_toggle := event.is_action_pressed("toggle_journal") if InputMap.has_action("toggle_journal") else (ke.keycode == KEY_J)
	if is_open:
		if is_instance_valid(_link_confirm_bg) and _link_confirm_bg.visible:
			if ke.keycode == KEY_ESCAPE:
				get_viewport().set_input_as_handled()
				_close_link_confirm()
			elif ke.keycode == KEY_ENTER or ke.keycode == KEY_KP_ENTER:
				get_viewport().set_input_as_handled()
				_confirm_open_external_link()
			return
		if is_instance_valid(_lightbox_bg) and _lightbox_bg.visible:
			if ke.keycode == KEY_ESCAPE or ke.keycode == KEY_SPACE or ke.keycode == KEY_ENTER:
				get_viewport().set_input_as_handled()
				_close_lightbox()
			return

		if ke.keycode == KEY_ESCAPE or is_journal_toggle:
			get_viewport().set_input_as_handled()
			close_journal()
			return

		match ke.keycode:
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

	# Open journal with bound key (default J) when no blocking overlay/dialogue is active
	if is_journal_toggle:
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
	_close_link_confirm()
	_sync_safe_margins()
	_collect_neighbors()

	if focus_character_path != "":
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
	_close_link_confirm()
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
	if _all_neighbors.is_empty():
		return
	var cur_i := 0
	for i in range(_all_neighbors.size()):
		if _all_neighbors[i].resource_path == _selected_path:
			cur_i = i
			break
	var next_i := posmod(cur_i + delta, _all_neighbors.size())
	if next_i == cur_i and _all_neighbors.size() <= 1:
		return
	_select_neighbor(_all_neighbors[next_i].resource_path)


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

	# Left Rail: Fixed-width Neighbor Roster (generous width, never squished)
	_rail_panel = PanelContainer.new()
	_rail_panel.size_flags_horizontal = Control.SIZE_FILL
	_rail_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_rail_panel.custom_minimum_size = Vector2(355, 0)
	_rail_panel.add_theme_stylebox_override("panel", _make_box_style(COL_SURFACE, COL_BORDER, 14, 12, 12))
	body_split.add_child(_rail_panel)

	_roster_scroll = ScrollContainer.new()
	_roster_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_roster_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_roster_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_style_scrollbar(_roster_scroll)
	_rail_panel.add_child(_roster_scroll)

	_roster_vbox = VBoxContainer.new()
	_roster_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_roster_vbox.add_theme_constant_override("separation", 8)
	_roster_scroll.add_child(_roster_vbox)

	# Right Workspace: Prominent Progression Panel + 6-Rank Track + Compact Folklore Reader
	var right_col := VBoxContainer.new()
	right_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_col.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right_col.clip_contents = true
	right_col.add_theme_constant_override("separation", 12)
	body_split.add_child(right_col)

	_hero_panel = PanelContainer.new()
	_hero_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_hero_panel.add_theme_stylebox_override("panel", _make_box_style(COL_PANEL, COL_BORDER, 14, 16, 12))
	right_col.add_child(_hero_panel)

	_hero_box = HBoxContainer.new()
	_hero_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_hero_box.add_theme_constant_override("separation", 16)
	_hero_panel.add_child(_hero_box)

	# Bottom Split: Tall Editorial Folklore Reader (Left) + Vertical Ranks I-VI Column (Right)
	var bottom_split := HBoxContainer.new()
	bottom_split.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bottom_split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	bottom_split.add_theme_constant_override("separation", 12)
	right_col.add_child(bottom_split)

	_reader_panel = PanelContainer.new()
	_reader_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_reader_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_reader_panel.add_theme_stylebox_override("panel", _make_box_style(COL_SURFACE, COL_BORDER, 14, 0, 0))
	bottom_split.add_child(_reader_panel)

	_reader_holder = MarginContainer.new()
	_reader_holder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_reader_holder.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_reader_holder.add_theme_constant_override("margin_left", 22)
	_reader_holder.add_theme_constant_override("margin_right", 22)
	_reader_holder.add_theme_constant_override("margin_top", 18)
	_reader_holder.add_theme_constant_override("margin_bottom", 18)
	_reader_panel.add_child(_reader_holder)

	_rank_track_box = VBoxContainer.new()
	_rank_track_box.size_flags_horizontal = Control.SIZE_FILL
	_rank_track_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_rank_track_box.custom_minimum_size = Vector2(182, 0)
	_rank_track_box.add_theme_constant_override("separation", 8)
	bottom_split.add_child(_rank_track_box)

	# ─── 3. BOTTOM INPUT LEGEND BAR ───
	outer_vbox.add_child(_build_bottom_legend())

	# ─── 4. FULL-SCREEN ART LIGHTBOX (Portrait & Landscape Safe) ───
	_build_lightbox()

	# ─── 5. EXTERNAL LINK CONFIRMATION MODAL ───
	_build_link_confirm_modal()


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
	hdr.alignment = BoxContainer.ALIGNMENT_END
	vbox.add_child(hdr)

	var close_lb := Button.new()
	close_lb.text = "✕"
	close_lb.tooltip_text = "Close (Esc)"
	close_lb.custom_minimum_size = Vector2(48, 48)
	close_lb.focus_mode = Control.FOCUS_NONE
	close_lb.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	close_lb.add_theme_font_override("font", _bold_font)
	close_lb.add_theme_font_size_override("font_size", 20)
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


func _open_lightbox(tex: Texture2D, _title: String = "", _caption: String = "") -> void:
	if tex == null or not is_instance_valid(_lightbox_bg):
		return
	_lightbox_tex_rect.texture = tex
	_lightbox_bg.visible = true
	_lightbox_bg.modulate.a = 0.0
	_lightbox_tex_rect.scale = Vector2(0.94, 0.94)
	_lightbox_tex_rect.pivot_offset = _lightbox_tex_rect.size * 0.5
	var tw := create_tween().set_parallel(true)
	tw.tween_property(_lightbox_bg, "modulate:a", 1.0, 0.16).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_property(_lightbox_tex_rect, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	EventBus.request_sfx.emit("interact")


func _close_lightbox() -> void:
	if is_instance_valid(_lightbox_bg) and _lightbox_bg.visible:
		_lightbox_bg.visible = false
		EventBus.request_sfx.emit("drop")


func _build_link_confirm_modal() -> void:
	_link_confirm_bg = ColorRect.new()
	_link_confirm_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_link_confirm_bg.color = Color(0.02, 0.015, 0.012, 0.78)
	_link_confirm_bg.visible = false
	_link_confirm_bg.mouse_filter = Control.MOUSE_FILTER_STOP
	_link_confirm_bg.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and ev.pressed and (ev as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
			_close_link_confirm()
	)
	_root.add_child(_link_confirm_bg)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_link_confirm_bg.add_child(center)

	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(520, 0)
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	var st := _make_box_style(COL_PANEL, COL_GOLD, 16, 28, 24)
	st.set_border_width_all(2)
	card.add_theme_stylebox_override("panel", st)
	center.add_child(card)

	var v := VBoxContainer.new()
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 14)
	card.add_child(v)

	var hdr := _make_label("Open External Link?", 22, COL_GOLD_BRIGHT, true)
	hdr.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(hdr)

	var msg := _make_label("This link will open an external website in your browser. Do you want to continue?", 17, COL_CREAM, false)
	msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	msg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	msg.add_theme_constant_override("line_spacing", 4)
	v.add_child(msg)

	_link_confirm_url_lbl = _make_label("", 14, COL_MUTED, false)
	_link_confirm_url_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_link_confirm_url_lbl.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	v.add_child(_link_confirm_url_lbl)

	var btn_row := HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_row.add_theme_constant_override("separation", 12)
	v.add_child(btn_row)

	var cancel_btn := Button.new()
	cancel_btn.text = "Cancel"
	cancel_btn.custom_minimum_size = Vector2(140, 48)
	cancel_btn.focus_mode = Control.FOCUS_NONE
	cancel_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	cancel_btn.add_theme_font_override("font", _bold_font)
	cancel_btn.add_theme_font_size_override("font_size", 16)
	_apply_button_theme(cancel_btn, false, false)
	cancel_btn.pressed.connect(_close_link_confirm)
	btn_row.add_child(cancel_btn)

	var open_btn := Button.new()
	open_btn.text = "Open Link ↗"
	open_btn.custom_minimum_size = Vector2(160, 48)
	open_btn.focus_mode = Control.FOCUS_NONE
	open_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	open_btn.add_theme_font_override("font", _bold_font)
	open_btn.add_theme_font_size_override("font_size", 16)
	_apply_button_theme(open_btn, true, false)
	open_btn.pressed.connect(_confirm_open_external_link)
	btn_row.add_child(open_btn)


func _open_link_confirm(url: String) -> void:
	if url.is_empty() or not is_instance_valid(_link_confirm_bg):
		return
	_pending_external_url = url
	_link_confirm_url_lbl.text = url
	_link_confirm_bg.visible = true
	_link_confirm_bg.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(_link_confirm_bg, "modulate:a", 1.0, 0.14).set_trans(Tween.TRANS_SINE)
	EventBus.request_sfx.emit("interact")


func _close_link_confirm() -> void:
	_pending_external_url = ""
	if is_instance_valid(_link_confirm_bg) and _link_confirm_bg.visible:
		_link_confirm_bg.visible = false
		EventBus.request_sfx.emit("drop")


func _confirm_open_external_link() -> void:
	var target := _pending_external_url
	_close_link_confirm()
	if not target.is_empty():
		OS.shell_open(target)


# =============================================================================
# REFRESH & RENDERING
# =============================================================================

func _refresh_all() -> void:
	var selected := _get_selected_customer()
	if selected != null and CharacterProgressionManager.has_unread_journal(selected.resource_path):
		CharacterProgressionManager.mark_journal_read(selected.resource_path)

	_refresh_header_stats()
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


func _rebuild_roster() -> void:
	for ch in _roster_vbox.get_children():
		ch.queue_free()
	_roster_cards.clear()

	for c in _all_neighbors:
		var path := c.resource_path
		var met := CharacterProgressionManager.has_encountered(path)
		var rank := CharacterProgressionManager.get_rep_rank(path)
		var unread := CharacterProgressionManager.has_unread_journal(path)
		var entry: Dictionary = FolkloreCatalogScript.get_entry(c.get_clean_id())
		var selected := (path == _selected_path)

		var card_btn := Button.new()
		card_btn.custom_minimum_size = Vector2(0, 76)
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
		var av := _build_avatar_frame(avatar_tex, Vector2(52, 52), not met, rank >= 6)
		av.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(av)

		# Name + Creature subtitle + Star pips (larger, cleaner typography)
		var name_col := VBoxContainer.new()
		name_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_col.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		name_col.add_theme_constant_override("separation", 2)
		name_col.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(name_col)

		var top_line := HBoxContainer.new()
		top_line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		top_line.add_theme_constant_override("separation", 6)
		top_line.mouse_filter = Control.MOUSE_FILTER_IGNORE
		name_col.add_child(top_line)

		var disp_name := (c.character_name if c.character_name != "" else c.get_clean_id().capitalize()) if met else "???"
		var nl := _make_label(disp_name, 20, COL_GOLD_BRIGHT if selected else (COL_CREAM if met else COL_LOCKED), true)
		nl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		nl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		top_line.add_child(nl)

		if unread:
			top_line.add_child(_make_label("★ NEW", 14, COL_GOLD_BRIGHT, true))

		var sub_row := HBoxContainer.new()
		sub_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		sub_row.add_theme_constant_override("separation", 8)
		sub_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		name_col.add_child(sub_row)

		var sub_txt := str(entry.get("creature", "Neighbor")) if met else "Unmet"
		var sl := _make_label(sub_txt, 16, COL_MUTED if met else COL_LOCKED, false)
		sl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		sl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		sub_row.add_child(sl)

		var stars := ""
		for ri in range(1, 7):
			stars += "★" if rank >= ri else "☆"
		var star_lbl := _make_label(stars, 16, COL_GOLD_BRIGHT if rank > 0 else COL_LOCKED, false)
		sub_row.add_child(star_lbl)

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

	# 1) Left Column (38%): Compact Portrait + Identity + Reputation + Favorites
	var left_prog := VBoxContainer.new()
	left_prog.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_prog.size_flags_stretch_ratio = 0.38
	left_prog.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	left_prog.add_theme_constant_override("separation", 8)
	_hero_box.add_child(left_prog)

	var id_row := HBoxContainer.new()
	id_row.add_theme_constant_override("separation", 12)
	left_prog.add_child(id_row)

	var portrait_tex := _resolve_portrait_texture(c, entry)
	var p_frame := _build_avatar_frame(portrait_tex, Vector2(78, 78), not met, rank >= 6)
	p_frame.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	id_row.add_child(p_frame)

	var mid_col := VBoxContainer.new()
	mid_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mid_col.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	mid_col.add_theme_constant_override("separation", 3)
	id_row.add_child(mid_col)

	var title_row := HBoxContainer.new()
	title_row.add_theme_constant_override("separation", 8)
	mid_col.add_child(title_row)

	var disp_name := (c.character_name if c.character_name != "" else c.get_clean_id().capitalize()) if met else "??? (Unmet Neighbor)"
	title_row.add_child(_make_label(disp_name, 24, COL_CREAM, true))

	if rank >= 6:
		var seal_pill := PanelContainer.new()
		seal_pill.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		seal_pill.add_theme_stylebox_override("panel", _make_box_style(Color(0.32, 0.22, 0.08, 0.96), COL_GOLD_BRIGHT, 8, 8, 2))
		seal_pill.add_child(_make_label("★ CONFIDANT", 14, COL_GOLD_BRIGHT, true))
		title_row.add_child(seal_pill)

	var folklore_line := "%s  •  %s" % [
		str(entry.get("creature", "Neighbor")) if met else "Unknown",
		str(entry.get("region", "Karimlan")) if met else "Meet at store"
	]
	var fl_lbl := _make_label(folklore_line, 14, COL_GOLD if met else COL_LOCKED, false)
	fl_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	mid_col.add_child(fl_lbl)

	# Reputation progress bar
	var rep_hdr := HBoxContainer.new()
	rep_hdr.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mid_col.add_child(rep_hdr)

	var rank_title := CharacterProgressionManager.get_rep_rank_title(rank)
	var rl := _make_label("Rank %d / 6 — %s" % [rank, rank_title], 15, COL_CREAM, true)
	rl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rep_hdr.add_child(rl)

	var rep_status := "MAX" if bool(prog["is_max"]) else ("%d / %d Rep" % [int(prog["current"]), int(prog["needed"])])
	if not met:
		rep_status = "0 Rep"
	rep_hdr.add_child(_make_label(rep_status, 14, COL_GOLD_BRIGHT if bool(prog["is_max"]) else COL_MUTED, false))

	var rep_bar := ProgressBar.new()
	rep_bar.custom_minimum_size = Vector2(0, 9)
	rep_bar.max_value = 100.0
	rep_bar.value = float(prog["ratio"]) * 100.0 if met else 0.0
	rep_bar.show_percentage = false
	rep_bar.add_theme_stylebox_override("background", UIStyle.create_flat_stylebox(Color(0.06, 0.05, 0.04, 0.92), 5, 0, 0))
	rep_bar.add_theme_stylebox_override("fill", UIStyle.create_flat_stylebox(COL_GOLD, 5, 0, 0))
	mid_col.add_child(rep_bar)

	# Favorites row
	var fav_row := HFlowContainer.new()
	fav_row.add_theme_constant_override("h_separation", 6)
	fav_row.add_theme_constant_override("v_separation", 4)
	left_prog.add_child(fav_row)

	fav_row.add_child(_make_label("Favorites:", 14, COL_MUTED, true))
	var favs: Array[String] = c.get_favorite_categories()
	if favs.is_empty():
		fav_row.add_child(_make_badge("None", COL_CARD, COL_BORDER, COL_MUTED))
	else:
		for cat in favs:
			if CharacterProgressionManager.is_favorite_discovered(cpath, cat):
				fav_row.add_child(_make_badge("★ " + StoryManager.get_category_display_name(cat), Color(0.24, 0.18, 0.09, 0.95), COL_GOLD, COL_GOLD_BRIGHT))
			else:
				fav_row.add_child(_make_badge("? Undiscovered", COL_CARD, COL_BORDER, COL_LOCKED))

	# Subtle divider
	var vsep := VSeparator.new()
	var vs_st := StyleBoxFlat.new()
	vs_st.bg_color = COL_BORDER
	vs_st.content_margin_left = 1
	vs_st.content_margin_right = 1
	vsep.add_theme_stylebox_override("separator", vs_st)
	_hero_box.add_child(vsep)

	# 2) Right Combined Progression Area (62%): Story Progression + Reputation Perks side-by-side
	var prog_split := HBoxContainer.new()
	prog_split.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	prog_split.size_flags_stretch_ratio = 0.62
	prog_split.add_theme_constant_override("separation", 14)
	_hero_box.add_child(prog_split)

	# 2a) Story Arcs & Chapters (62% of right area, compact 142px height)
	var story_col := VBoxContainer.new()
	story_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	story_col.size_flags_stretch_ratio = 0.62
	story_col.add_theme_constant_override("separation", 5)
	prog_split.add_child(story_col)

	var total_ch := c.chapters.size()
	var cur_ch := CharacterProgressionManager.get_chapter(cpath)
	var story_hdr := HBoxContainer.new()
	story_hdr.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	story_col.add_child(story_hdr)

	var sh_lbl := _make_label("STORY PROGRESSION", 17, COL_GOLD, true)
	sh_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	story_hdr.add_child(sh_lbl)
	story_hdr.add_child(_make_label("%d / %d" % [mini(cur_ch, total_ch), total_ch], 16, COL_MUTED, false))

	var story_scroll := ScrollContainer.new()
	story_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	story_scroll.custom_minimum_size = Vector2(0, 146)
	story_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_style_scrollbar(story_scroll)
	story_col.add_child(story_scroll)

	var arcs_vbox := VBoxContainer.new()
	arcs_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	arcs_vbox.add_theme_constant_override("separation", 6)
	story_scroll.add_child(arcs_vbox)

	var num_arcs := maxi(1, ceili(float(total_ch) / 3.0))
	for arc_i in range(num_arcs):
		var arc_title := c.get_arc_name(arc_i)
		if arc_title == "":
			arc_title = "Arc %d" % (arc_i + 1)
		var arc_lbl := _make_label(arc_title, 17, COL_GOLD_BRIGHT, true)
		arc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		arcs_vbox.add_child(arc_lbl)

		var ch_start := arc_i * 3
		var ch_end := mini(total_ch, ch_start + 3)
		for ch_idx in range(ch_start, ch_end):
			var done := cur_ch > ch_idx
			var ch_name := c.get_chapter_name(ch_idx)
			if ch_name == "":
				ch_name = "Chapter %d" % (ch_idx + 1)
			var ch_txt := "Chapter %d: %s" % [ch_idx + 1, ch_name if (done or ch_idx == cur_ch) else "???"]
			var ch_lbl := _make_label(ch_txt, 16, COL_CREAM if done else (COL_MUTED if ch_idx == cur_ch else COL_LOCKED), done)
			ch_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			ch_lbl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
			arcs_vbox.add_child(ch_lbl)

	# Divider between Story & Perks
	var vsep2 := VSeparator.new()
	vsep2.add_theme_stylebox_override("separator", vs_st)
	prog_split.add_child(vsep2)

	# 2b) Reputation Perks (38% of right area, 1 perk per row)
	var perks_col := VBoxContainer.new()
	perks_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	perks_col.size_flags_stretch_ratio = 0.38
	perks_col.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	perks_col.add_theme_constant_override("separation", 8)
	prog_split.add_child(perks_col)

	perks_col.add_child(_make_label("REPUTATION PERKS", 14, COL_GOLD, true))
	var perk_defs: Array[Dictionary] = [
		{"req": 3, "label": "+1 Fav Price Tolerance"},
		{"req": 5, "label": "+10% Cash Tip Bonus"},
		{"req": 6, "label": "+1 Global Price Tolerance"},
	]
	for p in perk_defs:
		var req := int(p["req"])
		var unlocked_p := rank >= req
		var p_txt := ("✓ R%d: %s" % [req, str(p["label"])]) if unlocked_p else ("🔒 R%d: %s" % [req, str(p["label"])])
		var p_lbl := _make_label(p_txt, 14, COL_POSITIVE if unlocked_p else COL_LOCKED, unlocked_p)
		p_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		perks_col.add_child(p_lbl)


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
		btn.custom_minimum_size = Vector2(0, 52)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.size_flags_vertical = Control.SIZE_EXPAND_FILL
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
		art_plate.size_flags_stretch_ratio = 0.30
		split.add_child(art_plate)

		var text_scroll := ScrollContainer.new()
		text_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		text_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
		text_scroll.size_flags_stretch_ratio = 0.70
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
	var media_url := str(entry.get("rank%d_depiction_url" % r, ""))
	var explicit_orient := str(entry.get("rank%d_depiction_orientation" % r, "")).to_lower()

	match r:
		1:
			body = str(entry.get("rank1_origin", ""))
		2:
			body = str(entry.get("rank2_taboos", ""))
		3:
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
		"media_url": media_url,
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
		var perk_txt := "★ " + CharacterProgressionManager.get_rep_rank_perk_summary(r)
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
		var body_lbl := _make_label(body_txt, 23, COL_BODY, false)
		body_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		body_lbl.add_theme_constant_override("line_spacing", 8)
		v.add_child(body_lbl)

	var src_txt := str(rank_data["media_source"]).strip_edges()
	var url_txt := str(rank_data.get("media_url", "")).strip_edges()
	if show_caption_callout and src_txt != "":
		var callout := PanelContainer.new()
		callout.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		callout.add_theme_stylebox_override("panel", _make_box_style(COL_PANEL, COL_BORDER, 10, 14, 10))
		var cv := VBoxContainer.new()
		cv.add_theme_constant_override("separation", 4)
		callout.add_child(cv)
		if url_txt != "":
			var link := LinkButton.new()
			link.text = src_txt + " ↗"
			link.uri = ""
			link.underline = LinkButton.UNDERLINE_MODE_ON_HOVER
			link.tooltip_text = url_txt
			link.focus_mode = Control.FOCUS_NONE
			link.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
			link.add_theme_font_override("font", _reg_font)
			link.add_theme_font_size_override("font_size", 15)
			link.add_theme_color_override("font_color", COL_GOLD)
			link.add_theme_color_override("font_hover_color", COL_GOLD_BRIGHT)
			link.add_theme_color_override("font_pressed_color", COL_CREAM)
			var captured_url := url_txt
			link.pressed.connect(func(): _open_link_confirm(captured_url))
			cv.add_child(link)
		else:
			var sl := _make_label(src_txt, 14, COL_MUTED, false)
			sl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			cv.add_child(sl)
		v.add_child(callout)

	return v


func _build_media_plate(rank_data: Dictionary, is_portrait: bool) -> Control:
	var frame := PanelContainer.new()
	var normal_st := _make_box_style(Color(0.07, 0.06, 0.05, 0.96), COL_GOLD, 12, 10, 10)
	var hover_st := _make_box_style(Color(0.10, 0.085, 0.07, 0.98), COL_GOLD_BRIGHT, 12, 10, 10)
	hover_st.set_border_width_all(2)
	frame.add_theme_stylebox_override("panel", normal_st)

	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 6)
	frame.add_child(vbox)

	var tex: Texture2D = rank_data["tex"]
	var title_str := str(rank_data["media_title"])
	var cap_str := str(rank_data["media_caption"])

	if tex != null:
		var art_btn := Button.new()
		art_btn.flat = true
		art_btn.focus_mode = Control.FOCUS_NONE
		art_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		art_btn.tooltip_text = "Click to zoom"
		art_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if is_portrait:
			art_btn.size_flags_vertical = Control.SIZE_EXPAND_FILL
		else:
			var vp_h := get_viewport().get_visible_rect().size.y
			art_btn.custom_minimum_size = Vector2(0, clampf(vp_h * 0.24, 150.0, 260.0))
		var empty_st := StyleBoxEmpty.new()
		art_btn.add_theme_stylebox_override("normal", empty_st)
		art_btn.add_theme_stylebox_override("hover", empty_st)
		art_btn.add_theme_stylebox_override("pressed", empty_st)
		art_btn.mouse_entered.connect(func(): frame.add_theme_stylebox_override("panel", hover_st))
		art_btn.mouse_exited.connect(func(): frame.add_theme_stylebox_override("panel", normal_st))
		art_btn.pressed.connect(func(): _open_lightbox(tex, title_str, cap_str))
		vbox.add_child(art_btn)

		var img := TextureRect.new()
		img.set_anchors_preset(Control.PRESET_FULL_RECT)
		img.texture = tex
		img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		img.mouse_filter = Control.MOUSE_FILTER_IGNORE
		art_btn.add_child(img)

		var hint := _make_label("Click to zoom", 14, COL_MUTED, false)
		hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vbox.add_child(hint)
	else:
		# Styled Portrait or Landscape placeholder plate when artwork file isn't added yet
		var ph := PanelContainer.new()
		ph.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if is_portrait:
			ph.size_flags_vertical = Control.SIZE_EXPAND_FILL
		else:
			var vp_h := get_viewport().get_visible_rect().size.y
			ph.custom_minimum_size = Vector2(0, clampf(vp_h * 0.22, 140.0, 240.0))
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
