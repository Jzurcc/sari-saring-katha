extends Control

## Diegetic spiral-bound Utang (Loan) Ledger UI using Assets/ui/ledger_ui.png.
## Aligns every header, pending loan, repayment cross-off, active debt, and crossed-off
## settled entry directly onto the 18 printed horizontal ruled lines per page, with
## real multi-page flipping on the top-right (Next) and bottom-right (Previous) curled corners.

signal notebook_closed

const LEDGER_TEX_PATH := "res://Assets/ui/ledger_ui.png"
const INK_FONT_PATH := "res://Assets/Fonts/Inder/Inder-Regular.ttf"
const BOLD_FONT_PATH := "res://Assets/Fonts/Balete Trial/BaleteTrial-Bold.ttf"

const LEDGER_ASPECT := 1504.0 / 1776.0
## Measured normalized ruled-line coordinates on Assets/ui/ledger_ui.png (1504x1776)
const MARGIN_LEFT_ANCHOR := 0.288
const MARGIN_RIGHT_ANCHOR := 0.908
const HEADER_LINE_TOP := 0.1326
const ROWS_TOP_ANCHOR := 0.1746
const ROWS_BOTTOM_ANCHOR := 0.8913
const ROWS_PER_PAGE := 18
const RULED_LINE_STEP := (ROWS_BOTTOM_ANCHOR - ROWS_TOP_ANCHOR) / float(ROWS_PER_PAGE)

const INK_DARK := Color(0.14, 0.16, 0.28, 0.95) # Ballpoint blue-black ink
const INK_RED := Color(0.70, 0.13, 0.11, 0.96) # Red accounting ink
const INK_GREEN := Color(0.16, 0.48, 0.22, 0.96) # Paid / repayment ink
const INK_MUTED := Color(0.36, 0.33, 0.30, 0.72) # Soft pencil gray
const INK_SETTLED := Color(0.34, 0.32, 0.30, 0.58) # Faded crossed-off ink
const INK_HEADER := Color(0.24, 0.16, 0.10, 0.96) # Deep sepia ink

var _ink_font: Font
var _bold_font: FontVariation
var _page_rect: TextureRect
var _close_btn: Button
var _next_page_btn: Button
var _prev_page_btn: Button
var _no_lbl: Label
var _date_lbl: Label
var _header_total_lbl: Label
var _rows_vbox: VBoxContainer
var _page_footer_lbl: Label
var _line_h: float = 34.0

var _current_page: int = 0
var _total_pages: int = 1
var _all_row_specs: Array[Dictionary] = []


func _ready() -> void:
	# Remove legacy template children from NotebookUI.tscn so we render cleanly on ledger_ui.png
	for child in get_children():
		child.queue_free()

	_ink_font = load(INK_FONT_PATH) if ResourceLoader.exists(INK_FONT_PATH) else UIStyle.FONT_INDER
	_bold_font = FontVariation.new()
	_bold_font.base_font = load(BOLD_FONT_PATH) if ResourceLoader.exists(BOLD_FONT_PATH) else _ink_font
	_bold_font.variation_embolden = 0.25

	_build_ui()
	_rebuild_and_render()


func _build_ui() -> void:
	# Dimmed clickable backdrop (clicking outside closes the notebook)
	var backdrop := ColorRect.new()
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.color = Color(0.03, 0.025, 0.02, 0.72)
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	backdrop.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and ev.pressed and (ev as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
			_on_close_button_pressed()
	)
	add_child(backdrop)

	# Aspect-locked notebook page container
	var aspect := AspectRatioContainer.new()
	aspect.anchor_left = 0.0
	aspect.anchor_right = 1.0
	aspect.anchor_top = 0.040
	aspect.anchor_bottom = 0.960
	aspect.ratio = LEDGER_ASPECT
	aspect.stretch_mode = AspectRatioContainer.STRETCH_FIT
	aspect.alignment_horizontal = AspectRatioContainer.ALIGNMENT_CENTER
	aspect.alignment_vertical = AspectRatioContainer.ALIGNMENT_CENTER
	aspect.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(aspect)

	_page_rect = TextureRect.new()
	if ResourceLoader.exists(LEDGER_TEX_PATH):
		_page_rect.texture = load(LEDGER_TEX_PATH)
	_page_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_page_rect.stretch_mode = TextureRect.STRETCH_SCALE
	_page_rect.mouse_filter = Control.MOUSE_FILTER_STOP
	_page_rect.resized.connect(_on_page_resized)
	aspect.add_child(_page_rect)

	# Top-right printed "NO." (page number) and "DATE / /" ink entries
	_no_lbl = Label.new()
	_no_lbl.anchor_left = 0.735
	_no_lbl.anchor_right = 0.875
	_no_lbl.anchor_top = 0.060
	_no_lbl.anchor_bottom = 0.090
	_no_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_no_lbl.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	_no_lbl.add_theme_font_override("font", _ink_font)
	_no_lbl.add_theme_font_size_override("font_size", 18)
	_no_lbl.add_theme_color_override("font_color", INK_DARK)
	_no_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_page_rect.add_child(_no_lbl)

	_date_lbl = Label.new()
	_date_lbl.anchor_left = 0.728
	_date_lbl.anchor_right = 0.892
	_date_lbl.anchor_top = 0.093
	_date_lbl.anchor_bottom = 0.124
	_date_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_date_lbl.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	_date_lbl.add_theme_font_override("font", _ink_font)
	_date_lbl.add_theme_font_size_override("font_size", 17)
	_date_lbl.add_theme_color_override("font_color", INK_DARK)
	_date_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_page_rect.add_child(_date_lbl)

	# First ruled line: "LISTA NG UTANG" title on left, Total Owed on right
	var header_row := HBoxContainer.new()
	header_row.anchor_left = MARGIN_LEFT_ANCHOR
	header_row.anchor_right = MARGIN_RIGHT_ANCHOR
	header_row.anchor_top = HEADER_LINE_TOP
	header_row.anchor_bottom = ROWS_TOP_ANCHOR
	header_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_page_rect.add_child(header_row)

	var title_lbl := Label.new()
	title_lbl.text = "LISTAHAN NG UTANG"
	title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_lbl.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	title_lbl.add_theme_font_override("font", _bold_font)
	title_lbl.add_theme_font_size_override("font_size", 22)
	title_lbl.add_theme_color_override("font_color", INK_HEADER)
	title_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header_row.add_child(title_lbl)

	_header_total_lbl = Label.new()
	_header_total_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_header_total_lbl.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	_header_total_lbl.add_theme_font_override("font", _bold_font)
	_header_total_lbl.add_theme_font_size_override("font_size", 21)
	_header_total_lbl.add_theme_color_override("font_color", INK_RED)
	_header_total_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header_row.add_child(_header_total_lbl)

	# Ruled rows container (exact 18 ruled lines per page — no scrollbars)
	_rows_vbox = VBoxContainer.new()
	_rows_vbox.anchor_left = MARGIN_LEFT_ANCHOR
	_rows_vbox.anchor_right = MARGIN_RIGHT_ANCHOR
	_rows_vbox.anchor_top = ROWS_TOP_ANCHOR
	_rows_vbox.anchor_bottom = ROWS_BOTTOM_ANCHOR
	_rows_vbox.add_theme_constant_override("separation", 0)
	_rows_vbox.clip_contents = true
	_page_rect.add_child(_rows_vbox)

	# Subtle bottom-center page indicator on bottom margin
	_page_footer_lbl = Label.new()
	_page_footer_lbl.anchor_left = MARGIN_LEFT_ANCHOR
	_page_footer_lbl.anchor_right = 0.85
	_page_footer_lbl.anchor_top = 0.905
	_page_footer_lbl.anchor_bottom = 0.948
	_page_footer_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_page_footer_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_page_footer_lbl.add_theme_font_override("font", _ink_font)
	_page_footer_lbl.add_theme_font_size_override("font_size", 14)
	_page_footer_lbl.add_theme_color_override("font_color", INK_MUTED)
	_page_footer_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_page_rect.add_child(_page_footer_lbl)

	# Top-right curled corner inside notebook -> Previous Page icon
	_prev_page_btn = _make_corner_flip_button("↩", "Previous Page (Left Arrow)")
	_prev_page_btn.anchor_left = 0.880
	_prev_page_btn.anchor_right = 0.966
	_prev_page_btn.anchor_top = 0.016
	_prev_page_btn.anchor_bottom = 0.096
	_prev_page_btn.pressed.connect(_on_prev_page_pressed)
	_page_rect.add_child(_prev_page_btn)

	# Bottom-right curled corner inside notebook -> Next Page icon
	_next_page_btn = _make_corner_flip_button("↪", "Next Page (Right Arrow)")
	_next_page_btn.anchor_left = 0.880
	_next_page_btn.anchor_right = 0.966
	_next_page_btn.anchor_top = 0.884
	_next_page_btn.anchor_bottom = 0.964
	_next_page_btn.pressed.connect(_on_next_page_pressed)
	_page_rect.add_child(_next_page_btn)

	# Rounded-corner "✕" Close button positioned OUTSIDE the notebook at its top-right
	_close_btn = Button.new()
	_close_btn.text = "✕"
	_close_btn.tooltip_text = "Close Ledger (Esc)"
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
	_close_btn.pressed.connect(_on_close_button_pressed)
	add_child(_close_btn)

	_sync_header_date()
	call_deferred("_on_page_resized")


func _make_corner_flip_button(glyph: String, tip: String) -> Button:
	var btn := Button.new()
	btn.text = glyph
	btn.tooltip_text = tip
	btn.focus_mode = Control.FOCUS_NONE
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var empty := StyleBoxEmpty.new()
	btn.add_theme_stylebox_override("normal", empty)
	btn.add_theme_stylebox_override("hover", empty)
	btn.add_theme_stylebox_override("pressed", empty)
	btn.add_theme_stylebox_override("disabled", empty)
	btn.add_theme_font_override("font", _bold_font)
	btn.add_theme_font_size_override("font_size", 24)
	btn.add_theme_color_override("font_color", Color(0.28, 0.18, 0.11, 0.88))
	btn.add_theme_color_override("font_hover_color", INK_RED)
	btn.add_theme_color_override("font_disabled_color", Color(0.36, 0.30, 0.24, 0.24))
	return btn


func _sync_header_date() -> void:
	var total_idx := maxi(0, StoryManager.day - 1)
	@warning_ignore("integer_division")
	var months_elapsed := total_idx / 31
	var day_in_month := (total_idx % 31) + 1
	var month_num := ((7 + months_elapsed) % 12) + 1 # August = 8
	@warning_ignore("integer_division")
	var year_short := (2013 + (7 + months_elapsed) / 12) % 100
	if is_instance_valid(_no_lbl):
		_no_lbl.text = "%02d" % (_current_page + 1)
	if is_instance_valid(_date_lbl):
		_date_lbl.text = "%02d  %02d  %02d" % [month_num, day_in_month, year_short]


func _on_page_resized() -> void:
	if not is_instance_valid(_page_rect):
		return
	var h := _page_rect.size.y
	if h <= 10.0:
		return
	_line_h = h * RULED_LINE_STEP
	if is_instance_valid(_rows_vbox):
		for child in _rows_vbox.get_children():
			if child is Control:
				(child as Control).custom_minimum_size.y = _line_h

	# Keep the external rounded "✕" close button positioned right outside the top-right of the notebook
	if is_instance_valid(_close_btn):
		var pr := _page_rect.get_global_rect()
		var vp := get_viewport().get_visible_rect().size
		var bx := minf(pr.end.x + 14.0, vp.x - _close_btn.size.x - 10.0)
		var by := maxf(pr.position.y + 4.0, 10.0)
		_close_btn.global_position = Vector2(bx, by)


func _make_ruled_row(highlight_bg: Color = Color(0, 0, 0, 0)) -> PanelContainer:
	var row_wrap := PanelContainer.new()
	row_wrap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row_wrap.custom_minimum_size = Vector2(0.0, _line_h)
	var st := StyleBoxFlat.new()
	st.bg_color = highlight_bg
	st.content_margin_left = 6
	st.content_margin_right = 6
	st.content_margin_top = 0
	st.content_margin_bottom = 2
	st.set_corner_radius_all(3)
	row_wrap.add_theme_stylebox_override("panel", st)
	return row_wrap


func _rebuild_and_render() -> void:
	_all_row_specs.clear()

	# 1. Pending repaid utang (click anywhere on the line to cross off in red ink)
	if StoryManager.has_pending_repayments():
		_all_row_specs.append({"type": "section", "text": "Repaid — click line to cross off", "color": Color(INK_RED.r, INK_RED.g, INK_RED.b, 0.80), "bg": Color(0, 0, 0, 0)})
		for i in range(StoryManager.pending_repayments.size()):
			var entry: Dictionary = StoryManager.pending_repayments[i]
			_all_row_specs.append({
				"type": "pending_repay",
				"index": i,
				"path": str(entry.get("customer_path", "")),
				"amount": float(entry.get("amount", 0.0)),
			})
		_all_row_specs.append({"type": "spacer"})

	# 2. Active unpaid utang entries
	var active_count := 0
	for path in StoryManager.customer_debts.keys():
		var amount := float(StoryManager.customer_debts[path])
		if amount > 0.0:
			active_count += 1
			_all_row_specs.append({
				"type": "active_debt",
				"path": str(path),
				"amount": amount,
			})

	# 3. Pending new utang (diegetic faint pencil lines right BELOW the last active utang)
	if StoryManager.has_pending_debts():
		if active_count > 0:
			_all_row_specs.append({"type": "spacer"})
		_all_row_specs.append({"type": "section", "text": "To record — click line to write in ink", "color": INK_MUTED, "bg": Color(0, 0, 0, 0)})
		for i in range(StoryManager.pending_debts.size()):
			var entry: Dictionary = StoryManager.pending_debts[i]
			_all_row_specs.append({
				"type": "pending_debt",
				"index": i,
				"path": str(entry.get("customer_path", "")),
				"amount": float(entry.get("amount", 0.0)),
			})
		active_count += StoryManager.pending_debts.size()

	# 4. Crossed-off (settled) utang history
	if not StoryManager.settled_debts_log.is_empty():
		if active_count > 0:
			_all_row_specs.append({"type": "spacer"})
		_all_row_specs.append({"type": "section", "text": "Paid & Crossed Off", "color": INK_MUTED, "bg": Color(0, 0, 0, 0)})
		for s_entry in StoryManager.settled_debts_log:
			_all_row_specs.append({
				"type": "settled_debt",
				"name": str(s_entry.get("customer_name", "Neighbor")),
				"amount": float(s_entry.get("amount", 0.0)),
			})

	if _all_row_specs.is_empty():
		_all_row_specs.append({"type": "empty"})

	_total_pages = maxi(1, int(ceilf(float(_all_row_specs.size()) / float(ROWS_PER_PAGE))))
	_current_page = clampi(_current_page, 0, _total_pages - 1)
	_render_current_page()


func _render_current_page() -> void:
	if not is_instance_valid(_rows_vbox):
		return
	for child in _rows_vbox.get_children():
		_rows_vbox.remove_child(child)
		child.queue_free()

	_sync_header_date()

	var total_recorded := 0.0
	for path in StoryManager.customer_debts.keys():
		var amt := float(StoryManager.customer_debts[path])
		if amt > 0.0:
			total_recorded += amt
	if is_instance_valid(_header_total_lbl):
		_header_total_lbl.text = "Total: ₱%.2f" % total_recorded if total_recorded > 0.0 else "All Clear"

	var start_idx := _current_page * ROWS_PER_PAGE
	var end_idx := mini(_all_row_specs.size(), start_idx + ROWS_PER_PAGE)
	for idx in range(start_idx, end_idx):
		var spec: Dictionary = _all_row_specs[idx]
		_rows_vbox.add_child(_build_row_from_spec(spec))

	if is_instance_valid(_next_page_btn):
		_next_page_btn.disabled = (_current_page >= _total_pages - 1)
	if is_instance_valid(_prev_page_btn):
		_prev_page_btn.disabled = (_current_page <= 0)
	if is_instance_valid(_page_footer_lbl):
		_page_footer_lbl.text = "Page %d of %d" % [_current_page + 1, _total_pages] if _total_pages > 1 else ""

	call_deferred("_on_page_resized")


func _resolve_customer_name(path: String) -> String:
	if path != "" and ResourceLoader.exists(path):
		var data := load(path) as CustomerData
		if data and data.character_name != "":
			return data.character_name
	return "Neighbor"


func _build_row_from_spec(spec: Dictionary) -> Control:
	var rtype := str(spec.get("type", ""))
	match rtype:
		"spacer":
			return _make_ruled_row()
		"empty":
			var empty_row := _make_ruled_row()
			var empty_lbl := Label.new()
			empty_lbl.text = "No unpaid utang on record."
			empty_lbl.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
			empty_lbl.add_theme_font_override("font", _ink_font)
			empty_lbl.add_theme_font_size_override("font_size", 20)
			empty_lbl.add_theme_color_override("font_color", INK_MUTED)
			empty_row.add_child(empty_lbl)
			return empty_row
		"section":
			var s_row := _make_ruled_row(spec.get("bg", Color(0, 0, 0, 0)))
			var s_lbl := Label.new()
			s_lbl.text = str(spec.get("text", ""))
			s_lbl.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
			s_lbl.add_theme_font_override("font", _bold_font)
			s_lbl.add_theme_font_size_override("font_size", 17)
			s_lbl.add_theme_color_override("font_color", spec.get("color", INK_HEADER))
			s_row.add_child(s_lbl)
			return s_row
		"pending_debt":
			var char_name := _resolve_customer_name(str(spec.get("path", "")))
			var amount := float(spec.get("amount", 0.0))
			var idx := int(spec.get("index", 0))
			var row_wrap := _make_ruled_row(Color(0, 0, 0, 0))
			row_wrap.mouse_filter = Control.MOUSE_FILTER_STOP
			row_wrap.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
			row_wrap.tooltip_text = "Click to write %s's utang in ink" % char_name
			var st_ref: StyleBoxFlat = row_wrap.get_theme_stylebox("panel")

			var hbox := HBoxContainer.new()
			hbox.add_theme_constant_override("separation", 10)
			hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
			row_wrap.add_child(hbox)

			var pencil_col := Color(0.28, 0.26, 0.25, 0.56)
			var pencil_amt_col := Color(0.68, 0.22, 0.18, 0.58)
			var name_lbl := Label.new()
			name_lbl.text = char_name
			name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			name_lbl.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
			name_lbl.add_theme_font_override("font", _ink_font)
			name_lbl.add_theme_font_size_override("font_size", 21)
			name_lbl.add_theme_color_override("font_color", pencil_col)
			name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
			hbox.add_child(name_lbl)

			var hint_lbl := Label.new()
			hint_lbl.text = "✎ Write"
			hint_lbl.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
			hint_lbl.add_theme_font_override("font", _ink_font)
			hint_lbl.add_theme_font_size_override("font_size", 15)
			hint_lbl.add_theme_color_override("font_color", Color(0.42, 0.34, 0.24, 0.72))
			hint_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
			hbox.add_child(hint_lbl)

			var amt_lbl := Label.new()
			amt_lbl.text = "₱%.2f" % amount
			amt_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			amt_lbl.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
			amt_lbl.add_theme_font_override("font", _bold_font)
			amt_lbl.add_theme_font_size_override("font_size", 20)
			amt_lbl.add_theme_color_override("font_color", pencil_amt_col)
			amt_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
			hbox.add_child(amt_lbl)

			row_wrap.mouse_entered.connect(func():
				st_ref.bg_color = Color(0.84, 0.74, 0.54, 0.22)
				name_lbl.add_theme_color_override("font_color", INK_DARK)
				amt_lbl.add_theme_color_override("font_color", INK_RED)
				hint_lbl.add_theme_color_override("font_color", INK_DARK)
			)
			row_wrap.mouse_exited.connect(func():
				st_ref.bg_color = Color(0, 0, 0, 0)
				name_lbl.add_theme_color_override("font_color", pencil_col)
				amt_lbl.add_theme_color_override("font_color", pencil_amt_col)
				hint_lbl.add_theme_color_override("font_color", Color(0.42, 0.34, 0.24, 0.72))
			)
			row_wrap.gui_input.connect(func(ev: InputEvent):
				if ev is InputEventMouseButton and ev.pressed and (ev as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
					_on_add_loan_pressed(idx)
			)
			return row_wrap
		"pending_repay":
			var char_name := _resolve_customer_name(str(spec.get("path", "")))
			var amount := float(spec.get("amount", 0.0))
			var idx := int(spec.get("index", 0))
			var row_wrap := _make_ruled_row(Color(0, 0, 0, 0))
			row_wrap.mouse_filter = Control.MOUSE_FILTER_STOP
			row_wrap.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
			row_wrap.tooltip_text = "Click to cross off %s's repaid utang" % char_name
			var st_ref: StyleBoxFlat = row_wrap.get_theme_stylebox("panel")

			var overlay_holder := Control.new()
			overlay_holder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			overlay_holder.size_flags_vertical = Control.SIZE_EXPAND_FILL
			overlay_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
			row_wrap.add_child(overlay_holder)

			var hbox := HBoxContainer.new()
			hbox.set_anchors_preset(Control.PRESET_FULL_RECT)
			hbox.add_theme_constant_override("separation", 10)
			hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
			overlay_holder.add_child(hbox)

			var name_lbl := Label.new()
			name_lbl.text = char_name
			name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			name_lbl.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
			name_lbl.add_theme_font_override("font", _ink_font)
			name_lbl.add_theme_font_size_override("font_size", 21)
			name_lbl.add_theme_color_override("font_color", INK_DARK)
			name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
			hbox.add_child(name_lbl)

			var hint_lbl := Label.new()
			hint_lbl.text = "✎ Cross off"
			hint_lbl.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
			hint_lbl.add_theme_font_override("font", _ink_font)
			hint_lbl.add_theme_font_size_override("font_size", 15)
			hint_lbl.add_theme_color_override("font_color", Color(INK_RED.r, INK_RED.g, INK_RED.b, 0.72))
			hint_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
			hbox.add_child(hint_lbl)

			var amt_lbl := Label.new()
			amt_lbl.text = "₱%.2f" % amount
			amt_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			amt_lbl.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
			amt_lbl.add_theme_font_override("font", _bold_font)
			amt_lbl.add_theme_font_size_override("font_size", 20)
			amt_lbl.add_theme_color_override("font_color", INK_GREEN)
			amt_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
			hbox.add_child(amt_lbl)

			# Live red-pen strikethrough preview when hovering the repaid line
			var hover_strike := ColorRect.new()
			hover_strike.color = Color(INK_RED.r, INK_RED.g, INK_RED.b, 0.65)
			hover_strike.anchor_left = 0.0
			hover_strike.anchor_right = 1.0
			hover_strike.anchor_top = 0.56
			hover_strike.anchor_bottom = 0.56
			hover_strike.offset_top = -1.0
			hover_strike.offset_bottom = 1.5
			hover_strike.visible = false
			hover_strike.mouse_filter = Control.MOUSE_FILTER_IGNORE
			overlay_holder.add_child(hover_strike)

			row_wrap.mouse_entered.connect(func():
				st_ref.bg_color = Color(0.86, 0.76, 0.60, 0.22)
				hover_strike.visible = true
				hint_lbl.add_theme_color_override("font_color", INK_RED)
			)
			row_wrap.mouse_exited.connect(func():
				st_ref.bg_color = Color(0, 0, 0, 0)
				hover_strike.visible = false
				hint_lbl.add_theme_color_override("font_color", Color(INK_RED.r, INK_RED.g, INK_RED.b, 0.72))
			)
			row_wrap.gui_input.connect(func(ev: InputEvent):
				if ev is InputEventMouseButton and ev.pressed and (ev as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
					_on_cross_off_pressed(idx)
			)
			return row_wrap
		"active_debt":
			var char_name := _resolve_customer_name(str(spec.get("path", "")))
			var amount := float(spec.get("amount", 0.0))
			var row_wrap := _make_ruled_row()
			var hbox := HBoxContainer.new()
			row_wrap.add_child(hbox)

			var name_lbl := Label.new()
			name_lbl.text = char_name
			name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			name_lbl.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
			name_lbl.add_theme_font_override("font", _ink_font)
			name_lbl.add_theme_font_size_override("font_size", 21)
			name_lbl.add_theme_color_override("font_color", INK_DARK)
			hbox.add_child(name_lbl)

			var amt_lbl := Label.new()
			amt_lbl.text = "₱%.2f" % amount
			amt_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			amt_lbl.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
			amt_lbl.add_theme_font_override("font", _bold_font)
			amt_lbl.add_theme_font_size_override("font_size", 20)
			amt_lbl.add_theme_color_override("font_color", INK_RED)
			hbox.add_child(amt_lbl)
			return row_wrap
		"settled_debt":
			var row_wrap := _make_ruled_row()
			var overlay_holder := Control.new()
			overlay_holder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			overlay_holder.size_flags_vertical = Control.SIZE_EXPAND_FILL
			row_wrap.add_child(overlay_holder)

			var hbox := HBoxContainer.new()
			hbox.set_anchors_preset(Control.PRESET_FULL_RECT)
			hbox.add_theme_constant_override("separation", 10)
			overlay_holder.add_child(hbox)

			var name_lbl := Label.new()
			name_lbl.text = str(spec.get("name", "Neighbor"))
			name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			name_lbl.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
			name_lbl.add_theme_font_override("font", _ink_font)
			name_lbl.add_theme_font_size_override("font_size", 20)
			name_lbl.add_theme_color_override("font_color", INK_SETTLED)
			hbox.add_child(name_lbl)

			var paid_lbl := Label.new()
			paid_lbl.text = "Paid  ₱%.2f" % float(spec.get("amount", 0.0))
			paid_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			paid_lbl.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
			paid_lbl.add_theme_font_override("font", _bold_font)
			paid_lbl.add_theme_font_size_override("font_size", 18)
			paid_lbl.add_theme_color_override("font_color", Color(INK_GREEN.r, INK_GREEN.g, INK_GREEN.b, 0.72))
			hbox.add_child(paid_lbl)

			# Crisp red-ink strikethrough line across the crossed-off name & amount
			var strike := ColorRect.new()
			strike.color = Color(INK_RED.r, INK_RED.g, INK_RED.b, 0.75)
			strike.anchor_left = 0.0
			strike.anchor_right = 1.0
			strike.anchor_top = 0.56
			strike.anchor_bottom = 0.56
			strike.offset_top = -1.0
			strike.offset_bottom = 1.5
			strike.mouse_filter = Control.MOUSE_FILTER_IGNORE
			overlay_holder.add_child(strike)
			return row_wrap
		_:
			return _make_ruled_row()


func _make_action_stamp_btn(label_txt: String, bg: Color, hov_bg: Color) -> Button:
	var btn := Button.new()
	btn.text = label_txt
	btn.focus_mode = Control.FOCUS_NONE
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var bs := UIStyle.create_flat_stylebox(bg, 5, 10, 2)
	bs.border_color = bg.darkened(0.45)
	bs.set_border_width_all(1)
	var bh: StyleBoxFlat = bs.duplicate()
	bh.bg_color = hov_bg
	btn.add_theme_stylebox_override("normal", bs)
	btn.add_theme_stylebox_override("hover", bh)
	btn.add_theme_stylebox_override("pressed", bs)
	btn.add_theme_font_override("font", _bold_font)
	btn.add_theme_font_size_override("font_size", 14)
	btn.add_theme_color_override("font_color", Color(1.0, 0.97, 0.90, 1.0))
	return btn


func _play_page_flip_fx(dir: int) -> void:
	AudioManager.play_sfx("interact")
	if not is_instance_valid(_rows_vbox):
		return
	_rows_vbox.modulate.a = 0.0
	var start_x := _rows_vbox.position.x
	_rows_vbox.position.x = start_x + (14.0 if dir > 0 else -14.0)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(_rows_vbox, "modulate:a", 1.0, 0.16).set_trans(Tween.TRANS_SINE)
	tw.tween_property(_rows_vbox, "position:x", start_x, 0.18).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func _on_next_page_pressed() -> void:
	if _current_page < _total_pages - 1:
		_current_page += 1
		_render_current_page()
		_play_page_flip_fx(1)


func _on_prev_page_pressed() -> void:
	if _current_page > 0:
		_current_page -= 1
		_render_current_page()
		_play_page_flip_fx(-1)


func _input(event: InputEvent) -> void:
	if not visible:
		return
	var is_esc: bool = event.is_action_pressed("ui_cancel") or (event is InputEventKey and event.pressed and not event.echo and (event.physical_keycode == KEY_ESCAPE or event.keycode == KEY_ESCAPE))
	if is_esc:
		_on_close_button_pressed()
		get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_RIGHT:
			_on_next_page_pressed()
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_LEFT:
			_on_prev_page_pressed()
			get_viewport().set_input_as_handled()


func _on_add_loan_pressed(index: int) -> void:
	AudioManager.play_sfx("interact")
	StoryManager.commit_pending_debt(index)
	_rebuild_and_render()


func _on_cross_off_pressed(index: int) -> void:
	AudioManager.play_sfx("purchase")
	StoryManager.commit_pending_repayment(index)
	_rebuild_and_render()


func _on_close_button_pressed() -> void:
	notebook_closed.emit()
	queue_free()
